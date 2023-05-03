--
-- XXDOINV_PLM_ITEM_GEN_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:39:40 PM (QP5 v5.362) */

CREATE OR REPLACE PACKAGE BODY APPS."XXDOINV_PLM_ITEM_GEN_PKG"
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
      ****************************************************************************
      Modification history:
     *****************************************************************************
         NAME:        xxdoinv_plm_item_gen_pkg
         PURPOSE:      MIAN PROCEDURE CONTROL_PROC

         REVISIONS:
         Version        Date        Author           Description
         ---------  ----------  ---------------  ------------------------------------
         1.0         9/11/2014     INFOSYS       1. Created this package body.
         1.1         12/3/2015     INFOSYS       2. Modified for CRs
         1.2         19/3/2015     INFOSYS       3. Variable Initializations
         1.3         19/3/2015     INFOSYS       4. Defects fixes
         1.4         24/3/2015     INFOSYS       5. Price List issue fix
         1.5         27/3/2015     INFOSYS       6. Fix for retired items.
         1.6         30/3/2015     INFOSYS       7. Fix for cost items, price and UPC Code.
         1.7         07/4/2015     INFOSYS       8. Change Request Price List and Lead Time.
         1.8         12/4/2015     INFOSYS       9. Change Request Sourcing Rules.
         1.9         17/4/2015     INFOSYS      10. CR B-Grade (and Sample) SKU Format.
         1.10        20/4/2015     INFOSYS      11. Fix for Defect # 536
         1.11        24/4/2015     INFOSYS      12. Fix for B-Grade items. To avoid appending BG for Style, as it already comes from RMS (Ref. Version 1.9).
         1.12        11/5/2015     INFOSYS      13. Reprocessing Items - Cost and PLM Errors
         1.13        12/5/2015     INFOSYS      14. Sourcing rule fix and SM to production change
         1.14        02/6/2015     INFOSYS      15. fixes for defects 1976 and 1993
         1.15        04/6/2015     INFOSYS      16. production line changes
         1.16        16/6/2015     INFOSYS      17. Souring rule dates and lead time Defect #2553
         1.17        16/6/2015     INFOSYS      18. Custom Items Enhancement #2555
         1.18        29/7/2015     INFOSYS      19. UPC Cross Ref for BGrade Items #2804
         1.19        05/8/2015     INFOSYS      20. Modified the sourcing rule effective dates while populating XXDO_SOURCING_RULE_STG.
         1.20        12/8/2015     INFOSYS      21. Modified to populate Description while creating Categories.
         1.21        14/8/2015     INFOSYS      22. Modified to create UPC Cross References for child organizations.
                                                    Commented calls to INV_ITEM_CATEGORY_PUB.CREATE_VALID_CATEGORY.
         1.22        26/8/2015     INFOSYS      23. Modified for Flex PLM CR on Transit Lead Times for carry overs in Lead Time Orgs(JP5).
                                                    Addressed performance issues.
         1.23        03/9/2015     INFOSYS      24. CR after CRP4.
         1.24        17/9/2015     INFOSYS      25. Fix for Defects - 2837 , 2914 , 2952
         1.25        23/9/2015     INFOSYS      26. Fix for Defects - 3139 , 3076
         1.26        23/9/2015     INFOSYS      27. Performance Improvement
         1.27        30/9/2015     INFOSYS      28. Defect ID 3281
         1.28        08/10/2015    INFOSYS      29. Defect ID 3041
         1.29        27/10/2015    INFOSYS      30. CR154
         1.30        24/11/2015    INFOSYS      31. Defect 693
         1.31        10/05/2016    INFOSYS      32. CCR Sample Items, Color Code, Sample in PROD , org active based on lookup
         1.32        14/06/2016    INFOSYS      33. Generate UPCs at FLR and add SKUs to Pricelist
         1.33        20/07/2016    INFOSYS      34. Considering the values from lookup for supplier site code
         1.34        07/09/2016    INFOSYS      35. Exclude the records for 'HIERARCHY_UPDATE' and Perfromance changes
         1.35        09/09/2016    INFOSYS      36. Dropped In Current Season Flag Updationg
         1.36        09/28/2016    INFOSYS      37. Adding Precedence to Price List Lines
         1.37        10/21/2016    INFOSYS      38. Attribute28 to store Item Type B-GRADE will be marked as BGRADE going forward
         1.38        12/12/2016    INFOSYS      39. Restrict making items planned form re-processing when item is in different status
         1.39        12/12/2016    INFOSYS      40. fixed for mutiple buyer id and if style comes directly in production then it should not be active
         1.40        02/26/2017    INFOSYS      41. NRF Changes
         1.41        02/26/2017    INFOSYS      42. Planned Status Template to be applied for orgs and pricelist not be updated when sent in same season
         1.42        04/18/2017    INFOSYS      43. Intro date to be populated
         1.43        05/24/2017    INFOSYS      44. CCR0006286 Enhancement for Licensee Products to not generating UPCs
         1.44        05/24/2017    INFOSYS      45. CCR0006254 -EBS-MDM-Account for Truck Ship Method for processing lead time on the item master
         1.45        06/24/2017    INFOSYS      46. CCR0005995 -PLM:Create new Attribute  Sample FOB on Cost sheet and have it Flow to EBS
         1.46        08/10/2017    Viswanathan  Fix for Defect 677 for CCR0005995
         1.47        12/05/2017    INFOSYS      47. CCR0006856 EBS-MDM- Send a flag to EBS to disable auto UPC generation for UGG licensed
         1.48        12/15/2017    INFOSYS      48. CCR0006848 - ATS Date
         1.49        07/25/2019    GJensen      49. CCR0008035 - ATS Date/Intro Date for child org
         1.50        02/14/2020    Tejaswi      50. CCR0007487 - Pricelist Updates within the same season for US-Wholesale and US-Retail
		 1.51        09/03/2020    Showkath     51. CCR0008684 - POP items tracked in inventory and need to be expensed and it should not costed
    *********************************************************************
    *********************************************************************/
   gv_package_name                    VARCHAR2 (200)
                                                := 'xxdoinv_plm_item_gen_pkg';
   gv_currproc                        VARCHAR2 (1000)    := NULL;
   gv_sqlstat                         VARCHAR2 (2000)    := NULL;
   gv_reterror                        VARCHAR2 (2000)    := NULL;
   gv_retcode                         VARCHAR2 (2000)    := NULL;
   gn_userid                          NUMBER       := apps.fnd_global.user_id;
   gn_resp_id                         NUMBER       := apps.fnd_global.resp_id;
   gn_app_id                          NUMBER  := apps.fnd_global.prog_appl_id;
   gn_conc_request_id                 NUMBER
                                           := apps.fnd_global.conc_request_id;
   g_num_login_id                     NUMBER           := fnd_global.login_id;
   gn_wsale_pricelist_id              NUMBER;
   gn_rtl_pricelist_id                NUMBER;
   gd_begin_date                      DATE;
   gd_end_date                        DATE;
   gn_master_orgid                    NUMBER;
   gn_master_org_code                 VARCHAR2 (200)
                        := apps.fnd_profile.VALUE ('XXDO: ORGANIZATION CODE');
   gv_default_template                VARCHAR2 (100)
                          := fnd_profile.VALUE ('INV: Item Default Template');
   gv_op_name                         VARCHAR2 (1000);
   gv_op_key                          VARCHAR2 (1000);
   gv_debug_enable                    VARCHAR2 (30)
                      := NVL (fnd_profile.VALUE ('XXDO_PLM_ITEM_DEBUG'), 'N');
   gn_japan_con_rate                  NUMBER;
   gv_price_list_flag                 VARCHAR2 (30)      := 'Y';
   g_num_batch_count                  NUMBER
               := NVL (fnd_profile.VALUE ('XXDO_PLM_ITEM_IMPORT_BATCH'), 500);
   --w.r.t Version 1.34
   g_tab_temp_req                     tabtype_request_id;
   gv_pricing_logic                   VARCHAR2 (30)      := 'N';
   -- W.r.t version 1.7
   gv_sku_flag                        VARCHAR2 (100);    -- W.r.t version 1.7
   gn_record_id                       NUMBER;           -- W.r.t version 1.12
   gv_plm_style                       VARCHAR2 (100);   -- W.r.t version 1.12
   gv_color_code                      VARCHAR2 (100);   -- W.r.t version 1.12
   gv_season                          VARCHAR2 (100);   -- W.r.t version 1.12
   gn_plm_rec_id                      NUMBER;           -- W.r.t version 1.12
   gv_colorway_state                  VARCHAR2 (100);
   -- START : Added for 1.22.
   gv_inventory_set_name     CONSTANT VARCHAR2 (30)      := 'Inventory';
   gn_inventory_set_id                NUMBER             := NULL;
   gn_inventory_structure_id          NUMBER             := NULL;
   gv_om_sales_set_name      CONSTANT VARCHAR2 (30)    := 'OM Sales Category';
   gn_om_sales_set_id                 NUMBER             := NULL;
   gn_om_sales_structure_id           NUMBER             := NULL;
   gv_prod_line_set_name     CONSTANT VARCHAR2 (30)      := 'PRODUCTION_LINE';
   gn_prod_line_set_id                NUMBER             := NULL;
   gn_prod_line_structure_id          NUMBER             := NULL;
   gv_tariff_code_set_name   CONSTANT VARCHAR2 (30)      := 'TARRIF CODE';
   gn_tariff_code_set_id              NUMBER             := NULL;
   gn_tariff_code_structure_id        NUMBER             := NULL;
   gn_region_set_name        CONSTANT VARCHAR2 (30)      := 'REGION';
   gn_region_set_id                   NUMBER             := NULL;
   gn_region_structure_id             NUMBER             := NULL;
   gn_item_type_set_name     CONSTANT VARCHAR2 (30)      := 'ITEM_TYPE';
   gn_item_type_set_id                NUMBER             := NULL;
   gn_item_type_structure_id          NUMBER             := NULL;
   gn_collection_set_name    CONSTANT VARCHAR2 (30)      := 'COLLECTION';
   gn_collection_set_id               NUMBER             := NULL;
   gn_collection_structure_id         NUMBER             := NULL;
   gn_proj_type_set_name     CONSTANT VARCHAR2 (30)      := 'PROJECT_TYPE';
   gn_proj_type_set_id                NUMBER             := NULL;
   gn_proj_type_structure_id          NUMBER             := NULL;
   gn_po_item_set_name       CONSTANT VARCHAR2 (30)     := 'PO Item Category';
   gn_po_item_set_id                  NUMBER             := NULL;
   gn_po_item_structure_id            NUMBER             := NULL;
   gn_qr_set_name            CONSTANT VARCHAR2 (30)      := 'QR';
   gn_qr_set_id                       NUMBER             := NULL;
   gn_qr_structure_id                 NUMBER             := NULL;
   gn_mst_season_set_name    CONSTANT VARCHAR2 (30)      := 'MASTER_SEASON';
   gn_mst_season_set_id               NUMBER             := NULL;
   gn_mst_season_structure_id         NUMBER             := NULL;
   gn_cat_process_id                  NUMBER             := 1;
   gn_cat_process_count               NUMBER             := 1;
   gn_cat_process_flag                VARCHAR2 (200)     := 'N';
   gn_cat_process_works               NUMBER             := 1;
   gn_tot_records_procs               NUMBER             := 1;
   gv_reprocess                       VARCHAR2 (200)     := NULL;
   gv_style_intro_date                VARCHAR2 (200)     := NULL;
                                                         --w.r.t Version 1.42
   gv_licensees                       VARCHAR2 (200)     := 'N';
                                                         --w.r.t Version 1.43

   --W.r.t Version 1.42

   -- END : Added for 1.22.
   PROCEDURE msg (pv_msg VARCHAR2, pn_level NUMBER := 1000)
   IS
   BEGIN
      IF gv_debug_enable = 'Y'
      THEN
         apps.fnd_file.put_line (apps.fnd_file.LOG, pv_msg);
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         apps.fnd_file.put_line (apps.fnd_file.LOG,
                                 'Error In msg procedure' || SQLERRM
                                );
   END;

   FUNCTION get_tq_vendor_from_site (pv_vendor_site IN VARCHAR2)
      RETURN VARCHAR2
   IS
      v_vendor   VARCHAR2 (240);
   BEGIN
      SELECT DISTINCT description
                 INTO v_vendor
                 FROM fnd_lookup_values
                WHERE lookup_type = 'XXD_PO_TQ_SITES'
                  AND meaning = pv_vendor_site
                  AND LANGUAGE = 'US'
                  AND enabled_flag = 'Y'
                  AND NVL (start_date_active, TRUNC (SYSDATE - 1)) >=
                                  NVL (start_date_active, TRUNC (SYSDATE - 1))
                  AND NVL (end_date_active, TRUNC (SYSDATE + 1)) <=
                                    NVL (end_date_active, TRUNC (SYSDATE + 1));

      RETURN v_vendor;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         RETURN NULL;
   END;

-- ***********************************************************************************
-- Procedure/Function Name  :  wait_for_request
--
-- Description              :  The purpose of this procedure is to make the
--                             parent request to wait untill unless child
--                             request completes
--
-- parameters               :  in_num_parent_req_id  in : Parent Request Id
--
-- Return/Exit              :  N/A
--
--
-- DEVELOPMENT and MAINTENANCE HISTORY
--
-- date          author             Version  Description
-- ------------  -----------------  -------  --------------------------------
-- 2009/08/03    Infosys            12.0.0    Initial Version
-- ***************************************************************************
   PROCEDURE wait_for_request (in_num_parent_req_id IN NUMBER)
   AS
------------------------------
--Local Variable Declaration--
------------------------------
      ln_count                NUMBER         := 0;
      ln_num_intvl            NUMBER         := 5;
      ln_data_set_id          NUMBER         := NULL;
      ln_num_max_wait         NUMBER         := 120000;
      lv_chr_phase            VARCHAR2 (250) := NULL;
      lv_chr_status           VARCHAR2 (250) := NULL;
      lv_chr_dev_phase        VARCHAR2 (250) := NULL;
      lv_chr_dev_status       VARCHAR2 (250) := NULL;
      lv_chr_msg              VARCHAR2 (250) := NULL;
      lb_bol_request_status   BOOLEAN;
---------------
--Begin Block--
---------------
   BEGIN
      --Wait for request to complete
      lb_bol_request_status :=
         fnd_concurrent.wait_for_request (in_num_parent_req_id,
                                          ln_num_intvl,
                                          ln_num_max_wait,
                                          lv_chr_phase,
                                          lv_chr_status,
                                          lv_chr_dev_phase,
                                          lv_chr_dev_status,
                                          lv_chr_msg
                                         );

      IF    UPPER (lv_chr_dev_status) = 'WARNING'
         OR UPPER (lv_chr_dev_status) = 'ERROR'
      THEN
         fnd_file.put_line
                         (fnd_file.LOG,
                             'Error in submitting the request, request_id = '
                          || in_num_parent_req_id
                         );
         fnd_file.put_line (fnd_file.LOG,
                            'Error,lv_chr_phase =' || lv_chr_phase
                           );
         fnd_file.put_line (fnd_file.LOG,
                            'Error,lv_chr_status =' || lv_chr_status
                           );
         fnd_file.put_line (fnd_file.LOG,
                            'Error,lv_chr_dev_status =' || lv_chr_dev_status
                           );
         fnd_file.put_line (fnd_file.LOG, 'Error,lv_chr_msg =' || lv_chr_msg);
      ELSE
         fnd_file.put_line (fnd_file.LOG, 'Request completed');
         fnd_file.put_line (fnd_file.LOG,
                            'request_id = ' || in_num_parent_req_id
                           );
         fnd_file.put_line (fnd_file.LOG, 'lv_chr_msg =' || lv_chr_msg);
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG, 'Error:' || SQLERRM);
   END wait_for_request;

   -- START : Added for 1.22.
   /*************************************************************************
    * Procedure/Function Name  :  GET_CATEGORY_SET_DETAILS
    *
    * Description              :  The purpose of this procedure is to fetch category set details.
    * INPUT Parameters : pv_cat_set_name    IN       VARCHAR2
    *
    * OUTPUT Parameters : pn_cat_set_id     OUT      NUMBER,
    *                     pn_structure_id   OUT      NUMBER
    *
    * DEVELOPMENT and MAINTENANCE HISTORY
    *
    * DATE          AUTHOR             Version  Description
    * ------------  -----------------  -------  ------------------------------
    * 9/1/2015     INFOSYS            1.0    Initial Version
    *************************************************************************/
   PROCEDURE get_category_set_details (
      pv_cat_set_name   IN       VARCHAR2,
      pn_cat_set_id     OUT      NUMBER,
      pn_structure_id   OUT      NUMBER
   )
   IS
   /***************************************************************************
   Retrieving category id and structure id for 'OM sales' category.
   ****************************************************************************/
   BEGIN
      SELECT category_set_id, structure_id
        INTO pn_cat_set_id, pn_structure_id
        FROM mtl_category_sets
       WHERE UPPER (category_set_name) = UPPER (pv_cat_set_name);
   EXCEPTION
      WHEN OTHERS
      THEN
         pn_cat_set_id := NULL;
         pn_structure_id := NULL;
         fnd_file.put_line
                     (fnd_file.LOG,
                         'Error while retrieving details for Category Set : '
                      || pv_cat_set_name
                     );
         fnd_file.put_line (fnd_file.LOG,
                               'Error Code : '
                            || SQLCODE
                            || '. Error Message : '
                            || SQLERRM
                           );
   END get_category_set_details;

   -- END : Added for 1.22.

   -- ***************************************************************************
-- Procedure/Function Name  :  get_batch_id
--
-- Description              :  The purpose of this function is to get batch id
--                             for the child org records.
--
-- parameters               :  -
--
-- Return/Exit              :  NUMBER
--
--
-- DEVELOPMENT and MAINTENANCE HISTORY
--
-- date          author             Version  Description
-- ------------  -----------------  -------  --------------------------------
-- ***************************************************************************
   FUNCTION get_batch_id
      RETURN NUMBER
   AS
-----------------------
--Declaration section--
-----------------------
      ln_batch_id   NUMBER := 0;
---------------
--Begin Block--
---------------
   BEGIN
      BEGIN
         SELECT mtl_system_items_intf_sets_s.NEXTVAL
           INTO ln_batch_id
           FROM DUAL;
      EXCEPTION
         WHEN OTHERS
         THEN
            fnd_file.put_line
               (fnd_file.LOG,
                   'Exception occurred while getting sequence nextvalue for batch id :: '
                || SQLERRM
               );
            ln_batch_id := 1;
      END;

      IF ln_batch_id IS NULL OR ln_batch_id = 0
      THEN
         ln_batch_id := 1;
      END IF;

      RETURN ln_batch_id;
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG,
                            'Exception in Function get_batch_id :: '
                            || SQLERRM
                           );
         ln_batch_id := 1;
         RETURN ln_batch_id;
   END get_batch_id;

   --START W.r.t Version 1.1
   /*************************************************************************
    * Procedure/Function Name  :  get_conc_code_combn
    *
    * Description              :  The purpose of this procedure to fetch the
    *                             Cost of Goods Account and Sales account
    * INPUT Parameters : pn_code_combn_id
   *                   pv_brand
    *
    * OUTPUT Parameters: xn_new_ccid
    *
    * DEVELOPMENT and MAINTENANCE HISTORY
    *
    * date          author             Version  Description
    * ------------  -----------------  -------  ------------------------------
    * 12/3/2015     INFOSYS            1.0.1    Initial Version
    *************************************************************************/
   PROCEDURE get_conc_code_combn (
      pn_code_combn_id   IN       NUMBER,
      pv_brand           IN       VARCHAR2,
      xn_new_ccid        OUT      NUMBER
   )
   IS
      CURSOR get_conc_code_combn_c
      IS
         SELECT segment1, NVL (pv_brand, segment2), segment3, segment4,
                segment5, segment6, segment7, segment8
           FROM gl_code_combinations
          WHERE code_combination_id = pn_code_combn_id;

      lc_conc_code_combn   VARCHAR2 (100);
      l_n_segments         NUMBER                    := 8;
      l_delim              VARCHAR2 (1)              := '.';
      l_segment_array      fnd_flex_ext.segmentarray;
      ln_coa_id            NUMBER;
      l_concat_segs        VARCHAR2 (32000);
   BEGIN
      --msg ('pn_code_combn_id(1) ' || pn_code_combn_id);
      --msg ('pv_brand(1) ' || pv_brand);
      OPEN get_conc_code_combn_c;

      FETCH get_conc_code_combn_c
       INTO l_segment_array (1), l_segment_array (2), l_segment_array (3),
            l_segment_array (4), l_segment_array (5), l_segment_array (6),
            l_segment_array (7), l_segment_array (8);

      CLOSE get_conc_code_combn_c;

      --RETURN lc_conc_code_combn;
      -- msg ('l_segment_array(1)   ' || l_segment_array (1));
      -- msg ('l_segment_array(2)   ' || l_segment_array (2));
      -- msg ('l_segment_array(3)   ' || l_segment_array (3));
      SELECT chart_of_accounts_id
        INTO ln_coa_id
        FROM gl_sets_of_books
       WHERE set_of_books_id = fnd_profile.VALUE ('GL_SET_OF_BKS_ID');

      msg ('ln_coa_id    ' || ln_coa_id);
      l_concat_segs :=
         fnd_flex_ext.concatenate_segments (l_n_segments,
                                            l_segment_array,
                                            l_delim
                                           );
      msg ('Concatinated Segments   ' || l_concat_segs);
      xn_new_ccid :=
         fnd_flex_ext.get_ccid ('SQLGL',
                                'GL#',
                                ln_coa_id,
                                TO_CHAR (SYSDATE, 'DD-MON-YYYY'),
                                l_concat_segs
                               );
      msg ('New CCID Segments   ' || xn_new_ccid);

      IF xn_new_ccid = 0
      THEN
         xn_new_ccid := pn_code_combn_id;
      END IF;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         fnd_file.put_line (fnd_file.LOG,
                            'No data from get_conc_code_combn   ' || SQLERRM
                           );
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG,
                               'Unknown error in get_conc_code_combn   '
                            || SQLERRM
                           );
   END get_conc_code_combn;                       --   --End W.r.t Version 1.1

   /*************************************************************************
    * Procedure/Function Name  :  SUBMIT_COST_IMPORT_PROC
    *
    * Description              :  The purpose of this procedure to submit the
    *                             cost import program
    * INPUT Parameters : pv_cost_type
    *
    * OUTPUT Parameters: pv_retcode
    *                    pv_reterror
    *
    * DEVELOPMENT and MAINTENANCE HISTORY
    *
    * date          author             Version  Description
    * ------------  -----------------  -------  ------------------------------
    * 9/11/2014     INFOSYS            1.0.1    Initial Version
    *************************************************************************/
   PROCEDURE submit_cost_import_proc (
      pv_cost_type   IN       VARCHAR2,
      pv_reterror    OUT      VARCHAR2,
      pv_retcode     OUT      VARCHAR2
   )
   IS
      l_req_id       NUMBER;
      l_phase        VARCHAR2 (100);
      l_status       VARCHAR2 (30);
      l_dev_phase    VARCHAR2 (100);
      l_dev_status   VARCHAR2 (100);
      l_wait_req     BOOLEAN;
      l_message      VARCHAR2 (2000);
   BEGIN
      -- msg (' fnd_global.user_id COst' || fnd_global.user_id);
      --  msg (' fnd_global.resp_id Cost ' || fnd_global.resp_id);
      --  msg (' fnd_global.resp_appl_id Cost ' || fnd_global.resp_appl_id);
      fnd_global.apps_initialize (user_id           => fnd_global.user_id,
                                  resp_id           => fnd_global.resp_id,
                                  --'20420',
                                  resp_appl_id      => fnd_global.resp_appl_id
                                 );
      COMMIT;
      l_req_id :=
         fnd_request.submit_request (application      => 'BOM',
                                     program          => 'CSTPCIMP',
                                     argument1        => 1,
                                     -- Import Cost Option (Import item costs,resource rates, and overhead rates)
                                     argument2        => 2,
                                     -- (Mode to Run )Remove and replace cost information
                                     argument3        => 2,
                                     -- Group Id option (All)
                                     argument4        => NULL,     -- Group ID
                                     argument5        => NULL,        -- Dummy
                                     argument6        => pv_cost_type,
                                     -- Cost Type
                                     argument7        => 1,
                                     -- Delete Successful rows
                                     start_time       => SYSDATE,
                                     sub_request      => FALSE
                                    );
      COMMIT;

      IF l_req_id = 0
      THEN
         pv_retcode := 2;
         pv_reterror := fnd_message.get;
         fnd_file.put_line
                       (fnd_file.LOG,
                           'Unable to submit Cost Import concurrent program '
                        || pv_reterror
                       );
      ELSE
         COMMIT;
         fnd_file.put_line
                (fnd_file.LOG,
                    'Cost Import concurrent request submitted successfully. '
                 || SQLERRM
                );
         l_wait_req :=
            fnd_concurrent.wait_for_request (request_id      => l_req_id,
                                             INTERVAL        => 1,
                                             phase           => l_phase,
                                             status          => l_status,
                                             dev_phase       => l_dev_phase,
                                             dev_status      => l_dev_status,
                                             MESSAGE         => l_message
                                            );

         IF l_dev_phase = 'COMPLETE' AND l_dev_status = 'NORMAL'
         THEN
            --msg (   'Cost Import concurrent request with the request id '
            --     || l_req_id
            --     || ' completed with NORMAL status.'
            --    );
            NULL;
         ELSE
            pv_retcode := 2;
            fnd_file.put_line
                    (fnd_file.LOG,
                        'Cost Import concurrent request with the request id '
                     || l_req_id
                     || ' did not complete with NORMAL status.'
                    );
         END IF;
      -- End of if to check if the status is normal and phase is complete
      END IF;                        -- End of if to check if request ID is 0.

      COMMIT;
      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         pv_retcode := 2;
         pv_reterror :=
               'Error in Cost Import '
            || DBMS_UTILITY.format_error_stack ()
            || DBMS_UTILITY.format_error_backtrace ();
         fnd_file.put_line (fnd_file.LOG, pv_reterror);
   END submit_cost_import_proc;

   /*************************************************************************
    * Procedure/Function Name  :  INSERT_INTO_COST_INTERFACE
    *
    * Description              :  The purpose of this procedure to insert
    *                             cost data into cost interface table.
    * INPUT Parameters : pn_item_id
    *
    * OUTPUT Parameters: pv_reterror
    *                    pv_retcode
    *
    * DEVELOPMENT and MAINTENANCE HISTORY
    *
    * date          author             Version  Description
    * ------------  -----------------  -------  ------------------------------
    * 9/11/2014     INFOSYS            1.0.1    Initial Version
    *************************************************************************/
   PROCEDURE insert_into_cost_interface (
      pn_item_id    IN       VARCHAR2,
      pv_reterror   OUT      VARCHAR2,
      pv_retcode    OUT      VARCHAR2
   )
   IS
      CURSOR csr_fob_cost_item
      IS
         SELECT   inventory_item_id, msi.organization_id, xps.*
             FROM xxdo.xxdo_plm_itemast_stg xps,
                  mtl_system_items_b msi,
                  mtl_parameters mp,
                  fnd_lookup_values_vl flv
            WHERE msi.inventory_item_id = xps.item_id
              AND mp.organization_id = msi.organization_id
              AND flv.lookup_code = mp.organization_code
              AND lookup_type = 'COST_TYPE_POPULATE'
              AND projectedcost IS NOT NULL
              AND status_flag = 'S'
              AND NVL (flv.enabled_flag, 'Y') = 'Y'
              AND xps.stg_request_id = gn_conc_request_id
         ORDER BY cost_type;

      CURSOR csr_land_cost_item
      IS
         SELECT   inventory_item_id, msi.organization_id, xps.*
             FROM xxdo.xxdo_plm_itemast_stg xps,
                  mtl_system_items_b msi,
                  mtl_parameters mp,
                  fnd_lookup_values_vl flv
            WHERE inventory_item_id = xps.item_id
              AND mp.organization_id = msi.organization_id
              AND flv.lookup_code = mp.organization_code
              AND lookup_type = 'COST_TYPE_POPULATE'
              AND landedcost IS NOT NULL
              AND status_flag = 'S'
              AND xps.stg_request_id = gn_conc_request_id
              AND NVL (flv.enabled_flag, 'Y') = 'Y'
         ORDER BY cost_type;

      ln_cost_element_id   NUMBER;
      ln_process_flag      NUMBER          := 1;
      inv_item_id          NUMBER;
      inv_org_id           VARCHAR2 (30);
      v_factory_cost       NUMBER;
      l_price              NUMBER;
      l_cost_err_msg       VARCHAR2 (4000);
      l_cost_err_code      VARCHAR2 (4000);
      l_err_msg            VARCHAR2 (4000);
      lv_season            VARCHAR2 (4000) := NULL;
      ln_cost_id           NUMBER;
      ln_cost_count        NUMBER          := 0;
      lv_cost_type         VARCHAR2 (4000) := NULL;
   BEGIN
      SELECT cc.cost_element_id
        INTO ln_cost_element_id
        FROM cst_cost_elements cc
       WHERE UPPER (cc.cost_element) = 'MATERIAL';

      ln_cost_count := 0;

      FOR rec_fob_cost IN csr_fob_cost_item
      LOOP
         l_price := 0;
         ln_cost_count := ln_cost_count + 1;

         IF ln_cost_count = 1
         THEN
            lv_cost_type := rec_fob_cost.cost_type;
         END IF;

         INSERT INTO cst_item_cst_dtls_interface
                     (inventory_item_id,
                      organization_id,
                      -- resource_code,
                      usage_rate_or_amount, cost_element_id,
                      cost_type, process_flag,
                      last_update_date, last_updated_by, creation_date,
                      created_by, based_on_rollup_flag, inventory_asset_flag,
                      shrinkage_rate, lot_size
                     )
              VALUES (rec_fob_cost.inventory_item_id,
                      rec_fob_cost.organization_id,
                      -- 'MATERIAL',
                      rec_fob_cost.projectedcost, ln_cost_element_id,
                      rec_fob_cost.cost_type || '-FOB', ln_process_flag,
                      SYSDATE, 1, SYSDATE,
                      fnd_global.user_id, 1, 1,
                      0, 1
                     );

         COMMIT;

         IF lv_cost_type <> rec_fob_cost.cost_type
         THEN
            submit_cost_import_proc (lv_cost_type || '-FOB',
                                     pv_reterror,
                                     pv_retcode
                                    );
            lv_cost_type := rec_fob_cost.cost_type;
         END IF;
      END LOOP;

      IF ln_cost_count <> 0
      THEN
         submit_cost_import_proc (lv_cost_type || '-FOB',
                                  pv_reterror,
                                  pv_retcode
                                 );
      END IF;

      ln_cost_count := 0;

      FOR rec_land_cost IN csr_land_cost_item
      LOOP
         ln_cost_count := ln_cost_count + 1;

         IF ln_cost_count = 1
         THEN
            lv_cost_type := rec_land_cost.cost_type;
         END IF;

         INSERT INTO cst_item_cst_dtls_interface
                     (inventory_item_id,
                      organization_id,
                      -- resource_code,
                      usage_rate_or_amount, cost_element_id,
                      cost_type, process_flag,
                      last_update_date, last_updated_by, creation_date,
                      created_by, based_on_rollup_flag, inventory_asset_flag,
                      shrinkage_rate, lot_size
                     )
              VALUES (rec_land_cost.inventory_item_id,
                      rec_land_cost.organization_id,
                      --'MATERIAL',
                      rec_land_cost.landedcost, ln_cost_element_id,
                      rec_land_cost.cost_type || '-LD', ln_process_flag,
                      SYSDATE, 1, SYSDATE,
                      fnd_global.user_id, 1, 1,
                      0, 1
                     );

         COMMIT;

         IF lv_cost_type <> rec_land_cost.cost_type
         THEN
            submit_cost_import_proc (lv_cost_type || '-LD',
                                     pv_reterror,
                                     pv_retcode
                                    );
            lv_cost_type := rec_land_cost.cost_type;
         END IF;
      END LOOP;

      IF ln_cost_count <> 0
      THEN
         submit_cost_import_proc (lv_cost_type || '-LD',
                                  pv_reterror,
                                  pv_retcode
                                 );
      END IF;

      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         pv_retcode := SQLCODE;
         pv_reterror := SQLERRM;
         fnd_file.put_line
            (fnd_file.LOG,
                'OTHERS Exception in  insert_into_cost_interface procedure -'
             || DBMS_UTILITY.format_error_stack ()
             || DBMS_UTILITY.format_error_backtrace ()
            );
   END insert_into_cost_interface;

   /*************************************************************************
    * Procedure/Function Name  :  submit_category_import
    *
    * Description              :  The purpose of this procedure to launch
    *                             category import program
    * INPUT Parameters : pv_requestid
    *                    pv_upload_rec_flag
    *                    pv_delete_rec_flag
    * OUTPUT Parameters: pn_req_id
    *                    pv_reterror
    *                    pv_retcode
    * DEVELOPMENT and MAINTENANCE HISTORY
    *
    * date          author             Version  Description
    * ------------  -----------------  -------  ------------------------------
    * 9/20/2015     INFOSYS            1.0.1    Initial Version
    *************************************************************************/
   PROCEDURE submit_category_import (
      pv_requestid         IN       VARCHAR2,
      pv_upload_rec_flag   IN       VARCHAR2,
      pv_delete_rec_flag   IN       VARCHAR2,
      pn_req_id            OUT      NUMBER,
      pv_reterror          OUT      VARCHAR2,
      pv_retcode           OUT      VARCHAR2
   )
   IS
      ln_requestid         NUMBER         := 0;
      lv_phasecode         VARCHAR2 (100) := NULL;
      lv_statuscode        VARCHAR2 (100) := NULL;
      lv_devphase          VARCHAR2 (100) := NULL;
      lv_devstatus         VARCHAR2 (100) := NULL;
      lv_returnmsg         VARCHAR2 (200) := NULL;
      lb_concreqcallstat   BOOLEAN        := FALSE;
      ln_resp_id           NUMBER;
      ln_appln_id          NUMBER;
      econcreqsuberr       EXCEPTION;
      ln_req_count         NUMBER;                       --W.r.t Version 1.27
   BEGIN
      ln_requestid :=
         apps.fnd_request.submit_request
                              (application      => 'INV',
                               program          => 'INV_ITEM_CAT_ASSIGN_OI',
                               description      => '',
                               start_time       => TO_CHAR
                                                       (SYSDATE,
                                                        'DD-MON-YY HH24:MI:SS'
                                                       ),
                               sub_request      => FALSE,
                               argument1        => pv_requestid,
                               argument2        => pv_upload_rec_flag,
                               argument3        => pv_delete_rec_flag
                              );
      COMMIT;

      BEGIN
         ln_req_count := TO_NUMBER (pv_requestid);       --W.r.t Version 1.27
      EXCEPTION
         WHEN OTHERS
         THEN
            fnd_file.put_line (fnd_file.LOG,
                               ' Unable to convert to number ' || SQLERRM
                              );
            ln_req_count := 0;
      END;

      IF ln_requestid = 0
      THEN
         RAISE econcreqsuberr;
      ELSE
         pn_req_id := ln_requestid;
         g_tab_temp_req (ln_req_count).request_id := pn_req_id;
      -- LOOP
      /*
          lb_concreqcallstat :=
             apps.fnd_concurrent.wait_for_request
                                     (ln_requestid,
                                      5  -- wait 5 seconds between db checks
                                       ,
                                      0,
                                      lv_phasecode,
                                      lv_statuscode,
                                      lv_devphase,
                                      lv_devstatus,
                                      lv_returnmsg
                                     );
                                     */
      -- EXIT WHEN lv_devphase = 'COMPLETE';
      -- END LOOP;
      END IF;

      IF lv_devphase = 'COMPLETE' AND lv_devstatus = 'NORMAL'
      THEN
         NULL;
      ELSE
         fnd_file.put_line
            (fnd_file.LOG,
                'Category Assignment concurrent request with the request id '
             || ln_requestid
             || ' did not complete with NORMAL status.'
            );
      END IF;
   EXCEPTION
      WHEN econcreqsuberr
      THEN
         pv_retcode := 'Warning';
         pv_reterror := 'Error in conc.req submission at ' || SQLCODE;
      WHEN OTHERS
      THEN
         pv_retcode := SQLCODE;
         pv_reterror := SQLERRM;
   END submit_category_import;

   --End W.r.t Version 1.26

   /*************************************************************************
   * Procedure/Function Name  :  SEND_ERROR_REPORT
   *
   * Description              :  The purpose of this procedure to send
   *                             item error report.
   * INPUT Parameters : pn_item_id
   *
   * OUTPUT Parameters: pv_reterror
   *                    pv_retcode
   *
   * DEVELOPMENT and MAINTENANCE HISTORY
   *
   * date          author             Version  Description
   * ------------  -----------------  -------  ------------------------------
   * 5/18/2015     INFOSYS            1.0.1    Initial Version
   *************************************************************************/

   --Start W.r.t Version 1.12
   PROCEDURE send_error_report (
      pn_request_id   IN       NUMBER,
      pv_reterror     OUT      VARCHAR2,
      pv_retcode      OUT      VARCHAR2
   )
   IS
      l_req_id        NUMBER;
      l_phase         VARCHAR2 (100);
      l_status        VARCHAR2 (30);
      l_dev_phase     VARCHAR2 (100);
      l_dev_status    VARCHAR2 (100);
      l_wait_req      BOOLEAN;
      l_message       VARCHAR2 (2000);
      ln_request_id   NUMBER          := pn_request_id;
   BEGIN
      -- msg (' Report fnd_global.user_id ' || fnd_global.user_id);
      --  msg (' Report fnd_global.resp_id ' || fnd_global.resp_id);
      --  msg (   ' Report fnd_global.resp_appl_id '
      --  || fnd_global.resp_appl_id
      --  );
      -- msg (   ' fnd_global.resp_appl_id '
      --   || ln_request_id
      --  );
      fnd_global.apps_initialize (user_id           => fnd_global.user_id,
                                  resp_id           => fnd_global.resp_id,
                                  resp_appl_id      => fnd_global.resp_appl_id
                                 );
      COMMIT;
      l_req_id :=
         fnd_request.submit_request (application      => 'XXDO',
                                     program          => 'XXDO_FLEXPLM_ITEM_ERROR_REP',
                                     argument1        => ln_request_id,
                                     --argument2        => ln_request_id,
                                     start_time       => SYSDATE,
                                     sub_request      => FALSE
                                    );
      COMMIT;

      IF l_req_id = 0
      THEN
         pv_retcode := 2;
         pv_reterror := fnd_message.get;
         msg ('Unable to submit Error Report program ' || pv_reterror);
      ELSE
         COMMIT;
         msg (   'Error Report  concurrent request submitted successfully. '
              || SQLERRM
             );
         l_wait_req :=
            fnd_concurrent.wait_for_request (request_id      => l_req_id,
                                             INTERVAL        => 1,
                                             phase           => l_phase,
                                             status          => l_status,
                                             dev_phase       => l_dev_phase,
                                             dev_status      => l_dev_status,
                                             MESSAGE         => l_message
                                            );

         IF l_dev_phase = 'COMPLETE' AND l_dev_status = 'NORMAL'
         THEN
            msg (   'Error Report  concurrent request with the request id '
                 || l_req_id
                 || ' completed with NORMAL status.'
                );
         ELSE
            pv_retcode := 2;
            msg (   'Error Report concurrent request with the request id '
                 || l_req_id
                 || ' did not complete with NORMAL status.'
                );
         END IF;
      -- End of if to check if the status is normal and phase is complete
      END IF;                        -- End of if to check if request ID is 0.

      COMMIT;
      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         pv_retcode := 2;
         pv_reterror :=
               'Error in send_error_report '
            || DBMS_UTILITY.format_error_stack ()
            || DBMS_UTILITY.format_error_backtrace ();
         msg (pv_reterror);
   END send_error_report;

   --End W.r.t Version 1.12
   /*************************************************************************
      * Procedure/Function Name  :  validate_lookup_val
      *
      * Description              :  The purpose of this procedure to create
      *                             value to the lookup.
      * INPUT Parameters : pv_lookup_type
      *                    pv_lookup_code
      *                    pv_lookup_mean
      * OUTPUT Parameters: pv_retcode
      *                    pv_reterror
      *
      * DEVELOPMENT and MAINTENANCE HISTORY
      *
      * date          author             Version  Description
      * ------------  -----------------  -------  ------------------------------
      * 9/11/2014     INFOSYS            1.0.1    Initial Version
      *************************************************************************/
   PROCEDURE validate_lookup_val (
      pv_lookup_type   IN       VARCHAR2,
      pv_lookup_code   IN       VARCHAR2,
      pv_lookup_mean   IN       VARCHAR2,
      pv_reterror      OUT      VARCHAR2,
      pv_retcode       OUT      VARCHAR2,
      pv_final_code    OUT      VARCHAR2
   )
   IS
      CURSOR get_lookup_details
      IS
         SELECT ltype.application_id, ltype.customization_level,
                ltype.creation_date, ltype.created_by,
                ltype.last_update_date, ltype.last_updated_by,
                ltype.last_update_login, tl.lookup_type,
                tl.security_group_id, tl.view_application_id, tl.description,
                tl.meaning
           FROM fnd_lookup_types_tl tl, fnd_lookup_types ltype
          WHERE ltype.lookup_type = pv_lookup_type
            AND ltype.lookup_type = tl.lookup_type
            AND LANGUAGE = 'US';

      l_rowid          VARCHAR2 (100) := 0;
      lv_exists        VARCHAR2 (1)   := 'Y';
      lv_lookup_code   VARCHAR2 (30)  := NULL;
   BEGIN
      BEGIN
         SELECT lookup_code
           INTO pv_final_code
           FROM fnd_lookup_values
          WHERE lookup_type = pv_lookup_type
            AND UPPER (lookup_code) = UPPER (pv_lookup_code)
            AND LANGUAGE = 'US'
            AND enabled_flag = 'Y'
            AND NVL (start_date_active, TRUNC (SYSDATE - 1)) >=
                                  NVL (start_date_active, TRUNC (SYSDATE - 1))
            AND NVL (end_date_active, TRUNC (SYSDATE + 1)) <=
                                    NVL (end_date_active, TRUNC (SYSDATE + 1));
      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            lv_exists := 'N';
         WHEN OTHERS
         THEN
            lv_exists := NULL;
            fnd_file.put_line
                            (fnd_file.LOG,
                                'Error in Fetching Lookup Code in lookup :: '
                             || pv_lookup_type
                             || ' :: '
                             || SQLERRM
                            );
      END;

      IF lv_exists = 'N'
      THEN
         FOR i IN get_lookup_details
         LOOP
            l_rowid := NULL;

            BEGIN
               fnd_lookup_values_pkg.insert_row
                             (x_rowid                    => l_rowid,
                              x_lookup_type              => i.lookup_type,
                              x_security_group_id        => i.security_group_id,
                              x_view_application_id      => i.view_application_id,
                              x_lookup_code              => pv_lookup_code,
                              x_tag                      => NULL,
                              x_attribute_category       => NULL,
                              x_attribute1               => NULL,
                              x_attribute2               => NULL,
                              x_attribute3               => NULL,
                              x_attribute4               => NULL,
                              x_enabled_flag             => 'Y',
                              x_start_date_active        => TO_DATE
                                                               ('01-JAN-1950',
                                                                'DD-MON-YYYY'
                                                               ),
                              x_end_date_active          => NULL,
                              x_territory_code           => NULL,
                              x_attribute5               => NULL,
                              x_attribute6               => NULL,
                              x_attribute7               => NULL,
                              x_attribute8               => NULL,
                              x_attribute9               => NULL,
                              x_attribute10              => NULL,
                              x_attribute11              => NULL,
                              x_attribute12              => NULL,
                              x_attribute13              => NULL,
                              x_attribute14              => NULL,
                              x_attribute15              => NULL,
                              x_meaning                  => pv_lookup_mean,
                              x_description              => pv_lookup_code,
                              -- NULL,
                              x_creation_date            => SYSDATE,
                              x_created_by               => i.created_by,
                              x_last_update_date         => i.last_update_date,
                              x_last_updated_by          => i.last_updated_by,
                              x_last_update_login        => i.last_update_login
                             );
               COMMIT;
               --msg (pv_lookup_code || ' has been loaded');
               pv_final_code := pv_lookup_code;
            EXCEPTION
               WHEN OTHERS
               THEN
                  fnd_file.put_line
                                  (fnd_file.LOG,
                                      'validate_lookup_val Inner Exception: '
                                   || SQLERRM
                                  );
            END;
         END LOOP;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         pv_retcode := SQLCODE;
         pv_reterror := SQLERRM;
         fnd_file.put_line (fnd_file.LOG,
                               'Exception occured in validate_lookup_val : '
                            || SQLERRM
                           );
   END validate_lookup_val;

     /*************************************************************************
   * Procedure/Function Name  :  ASSIGN_CATEGORY
   *
   * Description              :  The purpose of this procedure to assign
   *                             category to Item.
   * INPUT Parameters : pn_batchid
   *                    pv_segment1
   *                    pv_segment2
   *                    pv_segment3
   *                    pv_segment5
   *                    pn_item_id
   *                    pn_organizationid
   *                    pv_colorwaystatus
   * OUTPUT Parameters: pv_retcode
   *                    pv_reterror
   *
   * DEVELOPMENT and MAINTENANCE HISTORY
   *
   * date          author             Version  Description
   * ------------  -----------------  -------  ------------------------------
   * 9/11/2014     INFOSYS            1.0.1    Initial Version
   *************************************************************************/
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
   )
   /*************************************************************************************
     procedure to assign inventory items to product family categories
    ***********************************************************************************/
   IS
      lv_pn               VARCHAR2 (240)
                                     := gv_package_name || '.assign_category';
      ln_stylecatid       NUMBER          := NULL;
      ln_cat_set_id       NUMBER          := NULL;
      ln_struc_id         NUMBER          := NULL;
      ln_count            NUMBER          := NULL;
      ln_oldcatid         NUMBER          := NULL;
      ln_newcat_id        NUMBER          := NULL;
      lv_style            VARCHAR2 (40);
      lv_firstchar        VARCHAR2 (1);
      lv_lastchar         VARCHAR2 (2);
      ln_masterorg        NUMBER;
      ln_organizationid   NUMBER          := gn_master_orgid;
      pv_errcode          VARCHAR2 (1000);
      pv_error            VARCHAR2 (1000);
      lv_return_status    VARCHAR2 (1000);
      lv_error_message    VARCHAR2 (3000);
      lv_error_code       VARCHAR2 (1000);
      x_msg_count         NUMBER;
      x_msg_data          VARCHAR2 (3000);
      ln_msg_count        NUMBER;
      lv_msg_data         VARCHAR2 (3000);
      ln_msg_index_out    VARCHAR2 (3000);
      ln_error_code       NUMBER;
   BEGIN
      lv_error_message := NULL;
      x_msg_count := 0;
      ln_msg_count := 0;
      lv_msg_data := NULL;

       /* -- Commented for 1.22.
      ***************************************************************************
       Retrieving category id and structure id for 'OM sales' category.
      ****************************************************************************
      BEGIN
         SELECT category_set_id, structure_id
           INTO ln_cat_set_id, ln_struc_id
           FROM apps.mtl_category_sets
          WHERE UPPER (category_set_name) = UPPER (pv_cat_set);
      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            pv_retcode := SQLCODE;
            pv_reterror :=
                        pv_cat_set || ' Category set Not Present ' || SQLERRM;
         WHEN OTHERS
         THEN
            pv_retcode := SQLCODE;
            pv_reterror :=
                  'Error Occured while retrieving category set id and structure id for Styles category set '
               || SQLERRM;
      END;
      */
       -- Commented for 1.22.

      /****************************************************************************
       Retrieving category id for all categories
       **************************************************************************/
      --msg (pv_segment1 || ' : ' || pv_segment2 || ' : ' || pv_segment3);
      BEGIN
         IF pv_cat_set = 'OM Sales Category'
         THEN
            ln_cat_set_id := gn_om_sales_set_id;           -- Added for 1.22.
            ln_struc_id := gn_om_sales_structure_id;       -- Added for 1.22.

            SELECT category_id
              INTO ln_newcat_id
              FROM apps.mtl_categories_b
             WHERE segment1 = pv_segment1         --UPPER (TRIM (pv_segment1))
               AND structure_id = ln_struc_id
               AND NVL (enabled_flag, 'Y') = 'Y';
         ELSIF pv_cat_set = 'PRODUCTION_LINE'
         THEN
            ln_cat_set_id := gn_prod_line_set_id;          -- Added for 1.22.
            ln_struc_id := gn_prod_line_structure_id;      -- Added for 1.22.

            SELECT category_id
              INTO ln_newcat_id
              FROM apps.mtl_categories_b
             WHERE segment1 = pv_segment1         --UPPER (TRIM (pv_segment1))
               AND segment2 = pv_segment2         --UPPER (TRIM (pv_segment2))
               AND segment3 = pv_segment3         --UPPER (TRIM (pv_segment3))
               AND structure_id = ln_struc_id
               AND NVL (enabled_flag, 'Y') = 'Y';
         ELSIF pv_cat_set = 'TARRIF CODE'
         THEN
            ln_cat_set_id := gn_tariff_code_set_id;        -- Added for 1.22.
            ln_struc_id := gn_tariff_code_structure_id;    -- Added for 1.22.

            SELECT category_id
              INTO ln_newcat_id
              FROM apps.mtl_categories_b
             WHERE segment1 = pv_segment1         --UPPER (TRIM (pv_segment1))
               AND segment2 = pv_segment2         --UPPER (TRIM (pv_segment2))
               AND segment3 = pv_segment3   --'N'         --UPPER (TRIM ('N'))
               AND structure_id = ln_struc_id
               AND NVL (enabled_flag, 'Y') = 'Y';
         ELSIF pv_cat_set = 'REGION'
         THEN
            ln_cat_set_id := gn_region_set_id;             -- Added for 1.22.
            ln_struc_id := gn_region_structure_id;         -- Added for 1.22.

            SELECT category_id
              INTO ln_newcat_id
              FROM apps.mtl_categories_b
             WHERE segment1 = pv_segment1         --UPPER (TRIM (pv_segment1))
               AND segment2 = pv_segment2         --UPPER (TRIM (pv_segment2))
               AND segment3 = pv_segment3         --UPPER (TRIM (pv_segment3))
               AND segment4 = pv_segment4         --UPPER (TRIM (pv_segment4))
               AND structure_id = ln_struc_id
               AND NVL (enabled_flag, 'Y') = 'Y';
         ELSIF pv_cat_set = 'ITEM_TYPE'
         THEN
            ln_cat_set_id := gn_item_type_set_id;          -- Added for 1.22.
            ln_struc_id := gn_item_type_structure_id;      -- Added for 1.22.

            SELECT category_id
              INTO ln_newcat_id
              FROM apps.mtl_categories_b
             WHERE segment1 = pv_segment1         --UPPER (TRIM (pv_segment1))
               AND segment2 = pv_segment2         --UPPER (TRIM (pv_segment2))
               AND structure_id = ln_struc_id
               AND NVL (enabled_flag, 'Y') = 'Y';
         ELSIF pv_cat_set = 'COLLECTION'
         THEN
            ln_cat_set_id := gn_collection_set_id;         -- Added for 1.22.
            ln_struc_id := gn_collection_structure_id;     -- Added for 1.22.

            SELECT category_id
              INTO ln_newcat_id
              FROM apps.mtl_categories_b
             WHERE segment1 = pv_segment1         --UPPER (TRIM (pv_segment1))
               AND segment2 = pv_segment2         --UPPER (TRIM (pv_segment2))
               AND structure_id = ln_struc_id
               AND NVL (enabled_flag, 'Y') = 'Y';
         ELSIF pv_cat_set = 'PROJECT_TYPE'
         THEN
            ln_cat_set_id := gn_proj_type_set_id;          -- Added for 1.22.
            ln_struc_id := gn_proj_type_structure_id;      -- Added for 1.22.

            SELECT category_id
              INTO ln_newcat_id
              FROM apps.mtl_categories_b
             WHERE segment1 = pv_segment1         --UPPER (TRIM (pv_segment1))
               AND segment2 = pv_segment2         --UPPER (TRIM (pv_segment2))
               AND structure_id = ln_struc_id
               AND NVL (enabled_flag, 'Y') = 'Y';
         ELSIF pv_cat_set = 'PO Item Category'
         THEN
            ln_cat_set_id := gn_po_item_set_id;            -- Added for 1.22.
            ln_struc_id := gn_po_item_structure_id;        -- Added for 1.22.

            SELECT category_id
              INTO ln_newcat_id
              FROM apps.mtl_categories_b
             WHERE segment1 = pv_segment1         --UPPER (TRIM (pv_segment1))
               AND segment2 = pv_segment2         --UPPER (TRIM (pv_segment2))
               AND segment3 = pv_segment3         --UPPER (TRIM (pv_segment3))
               AND structure_id = ln_struc_id
               AND NVL (enabled_flag, 'Y') = 'Y';
         ELSIF pv_cat_set = 'QR'
         THEN
            ln_cat_set_id := gn_qr_set_id;                 -- Added for 1.22.
            ln_struc_id := gn_qr_structure_id;             -- Added for 1.22.

            SELECT category_id
              INTO ln_newcat_id
              FROM apps.mtl_categories_b
             WHERE segment1 = pv_segment1         --UPPER (TRIM (pv_segment1))
               AND structure_id = ln_struc_id
               AND NVL (enabled_flag, 'Y') = 'Y';
         END IF;
      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            ln_newcat_id := 0;
            pv_errcode := SQLCODE;
            pv_error :=
                  'Category Id Not present'
               || 'For Style '
               || lv_style
               || ' '
               || SQLERRM;
         -- START : Added for 1.23.
         WHEN TOO_MANY_ROWS
         THEN
            ln_newcat_id := 0;
            pv_errcode := SQLCODE;
            pv_error :=
                  'Multiple Categories exists for Style : '
               || gv_plm_style
               || '. '
               || SQLERRM;
         -- END : Added for 1.23.
         WHEN OTHERS
         THEN
            pv_retcode := SQLCODE;
            pv_reterror :=
                  'Exception occured while retreiving Category id in Assign Style Category'
               || ' Category Id Not present'
               || 'For Style '
               || lv_style
               || ' '
               || SQLERRM;
      END;

      /*****************************************************************************************
      Retrieving old category assigned to style category
      ****************************************************************************************/
      BEGIN
         SELECT category_id
           INTO ln_oldcatid
           FROM apps.mtl_item_categories
          WHERE inventory_item_id = pn_item_id
            AND organization_id = ln_organizationid
            AND category_set_id = ln_cat_set_id;         -- Modified for 1.22.

         /*   AND category_set_id =
                          (SELECT category_set_id
                             FROM apps.mtl_category_sets
                            WHERE UPPER (category_set_name) = UPPER (pv_cat_set)); */
         -- Commented for 1.22.
         IF ln_oldcatid <> ln_newcat_id AND ln_newcat_id <> 0
         THEN
            --Start W.r.t version 1.26
            gn_cat_process_count := gn_cat_process_count + 1;

            IF gn_cat_process_count > gn_cat_process_works
            THEN
               gn_cat_process_id := gn_cat_process_id + 1;
               gn_cat_process_count := 1;
            END IF;

            BEGIN
               INSERT INTO apps.mtl_item_categories_interface
                           (inventory_item_id, organization_id,
                            category_set_id, category_id, old_category_id,
                            last_update_date, last_updated_by,
                            creation_date, created_by, process_flag,
                            transaction_type, set_process_id
                           )
                    VALUES (pn_item_id, ln_organizationid,
                            ln_cat_set_id, ln_newcat_id, ln_oldcatid,
                            SYSDATE, gn_userid,
                            SYSDATE, gn_userid, 1,
                            'UPDATE', gn_cat_process_id
                           );

               COMMIT;
            --End W.r.t version 1.26

            --Commented As part of 1.26
            /*
                       inv_item_category_pub.update_category_assignment
                                             (p_api_version            => 1.0,
                                              p_init_msg_list          => fnd_api.g_false,
                                              p_commit                 => fnd_api.g_true,
                                              x_return_status          => lv_return_status,
                                              x_errorcode              => lv_error_code,
                                              x_msg_count              => ln_msg_count,
                                              x_msg_data               => lv_msg_data,
                                              p_category_id            => ln_newcat_id,
                                              p_category_set_id        => ln_cat_set_id,
                                              p_inventory_item_id      => pn_item_id,
                                              p_organization_id        => ln_organizationid,
                                              p_old_category_id        => ln_oldcatid
                                             );

                       IF lv_return_status <> fnd_api.g_ret_sts_success
                       THEN
                          FOR i IN 1 .. ln_msg_count
                          LOOP
                             apps.fnd_msg_pub.get
                                                 (p_msg_index          => i,
                                                  p_encoded            => fnd_api.g_false,
                                                  p_data               => lv_msg_data,
                                                  p_msg_index_out      => ln_msg_index_out
                                                 );

                             IF lv_error_message IS NULL
                             THEN
                                lv_error_message := SUBSTR (lv_msg_data, 1, 250);
                             ELSE
                                lv_error_message :=
                                   SUBSTR (   SUBSTR (lv_error_message, 1, 1000)
                                           || ' /'
                                           || SUBSTR (lv_msg_data, 1, 250),
                                           1,
                                           1000
                                          );
                             END IF;
                          END LOOP;

                          fnd_msg_pub.delete_msg ();
                          pv_retcode := SQLCODE;
                          pv_reterror := lv_error_message;
                          fnd_file.put_line
                             (fnd_file.LOG,
                              SUBSTR
                                 (   'API update_category_assignment Error ln_newcat_id : '
                                  || ln_newcat_id
                                  || ' \ '
                                  || pv_cat_set
                                  || ' \ '
                                  || lv_error_message,
                                  1,
                                  900
                                 )
                             );
                       --ELSE
                       --   msg (   'Created Category Assiginment from Item id : '
                       --        || pn_item_id
                       --        || ' Successfully'
                       --       );
                       END IF;
                       */
            -- Commenting End w.r.t Version 1.26
            EXCEPTION
               WHEN OTHERS
               THEN
                  fnd_file.put_line
                     (fnd_file.LOG,
                      SUBSTR
                         (   'Error Occured while inserting mtl_item_categories_interface  : '
                          || pn_item_id
                          || ' \ '
                          || ln_organizationid
                          || '  '
                          || pv_cat_set
                          || ' \ '
                          || SQLERRM,
                          1,
                          900
                         )
                     );
            END;
         --ELSE
         --   msg (   'Created Item is already Assigined to Item id : '
         --        || pn_item_id
         --       );
         END IF;
      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            BEGIN
               --Start W.r.t Version 1.26
               gn_cat_process_count := gn_cat_process_count + 1;

               IF gn_cat_process_count > gn_cat_process_works
               THEN
                  gn_cat_process_id := gn_cat_process_id + 1;
                  gn_cat_process_count := 1;
               END IF;

               INSERT INTO apps.mtl_item_categories_interface
                           (inventory_item_id, organization_id,
                            category_set_id, category_id, old_category_id,
                            last_update_date, last_updated_by, creation_date,
                            created_by, process_flag, transaction_type,
                            set_process_id
                           )
                    VALUES (pn_item_id, ln_organizationid,
                            ln_cat_set_id, ln_newcat_id, NULL,
                            SYSDATE, gn_userid, SYSDATE,
                            gn_userid, 1, 'CREATE',
                            gn_cat_process_id
                           );

               COMMIT;
            --End W.r.t Version 1.26

            /* Commenting--W.r.t Version 1.26
               inv_item_category_pub.create_category_assignment
                                      (p_api_version            => 1,
                                       p_init_msg_list          => fnd_api.g_false,
                                       p_commit                 => fnd_api.g_false,
                                       x_return_status          => lv_return_status,
                                       x_errorcode              => ln_error_code,
                                       x_msg_count              => ln_msg_count,
                                       x_msg_data               => lv_msg_data,
                                       p_category_id            => ln_newcat_id,
                                       p_category_set_id        => ln_cat_set_id,
                                       p_inventory_item_id      => pn_item_id,
                                       p_organization_id        => ln_organizationid
                                      );

               IF lv_return_status <> fnd_api.g_ret_sts_success
               THEN
                  FOR i IN 1 .. ln_msg_count
                  LOOP
                     apps.fnd_msg_pub.get
                                         (p_msg_index          => i,
                                          p_encoded            => fnd_api.g_false,
                                          p_data               => x_msg_data,
                                          p_msg_index_out      => ln_msg_index_out
                                         );

                     IF lv_error_message IS NULL
                     THEN
                        lv_error_message := SUBSTR (x_msg_data, 1, 250);
                     ELSE
                        lv_error_message :=
                           SUBSTR (   lv_error_message
                                   || ' /'
                                   || ln_newcat_id
                                   || ' / '
                                   || SUBSTR (x_msg_data, 1, 250),
                                   1,
                                   1000
                                  );
                     END IF;
                  END LOOP;

                  pv_retcode := SQLCODE;
                  pv_reterror := lv_error_message;
                      --  fnd_file.put_line
                        --      (fnd_file.LOG,
                        --       SUBSTR (   'API create_category_assignment Caegory : '
                  --                     || pv_cat_set
                      --                 || ' Error '
                      --                 || lv_error_message,
                      --                 1,
                      --                 900
                      --                )
                      --        );
                  fnd_msg_pub.delete_msg ();
               --ELSE
               --   msg (   'Created Category Assiginment from Item id : '
               --        || pn_item_id
               --        || ' Successfully'
               --       );
               END IF;


            */
            EXCEPTION
               WHEN OTHERS
               THEN
                  fnd_file.put_line
                     (fnd_file.LOG,
                      SUBSTR
                         (   'Error Occured while inserting mtl_item_categories_interface  : '
                          || pn_item_id
                          || ' \ '
                          || ln_organizationid
                          || '  '
                          || pv_cat_set
                          || ' \ '
                          || SQLERRM,
                          1,
                          900
                         )
                     );
            --Commenting--W.r.t Version 1.26
            END;
      END;
   EXCEPTION
      WHEN OTHERS
      THEN
         pv_retcode := SQLCODE;
         pv_reterror := SQLERRM;
   END assign_category;

   /*************************************************************************
    * Procedure/Function Name  :  assign_multi_mem_category
    *
    * Description              :  The purpose of this procedure to assign
    *                             category to Item.
    * INPUT Parameters : pn_batchid
    *                    pv_style
    *                    pv_color
    *                    pv_size
    *                    pn_organizationid
    *                     pv_colorwaystatus
    * OUTPUT Parameters: pv_retcode
    *                    pv_reterror
    *
    * DEVELOPMENT and MAINTENANCE HISTORY
    *
    * date          author             Version  Description
    * ------------  -----------------  -------  ------------------------------
    * 9/11/2014     INFOSYS            1.0.1    Initial Version
    *************************************************************************/
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
   )
   /*************************************************************************************
     procedure to assign inventory items to tariff category
    *************************************************************************************/
   IS
      lv_pn               VARCHAR2 (240)
                           := gv_package_name || '.assign_multi_mem_category';
      eusererror          EXCEPTION;
      ln_ncatid           NUMBER          := NULL;
      ln_cat_set_id       NUMBER          := NULL;
      ln_struc_id         NUMBER          := NULL;
      ln_count            NUMBER          := NULL;
      ln_oldcatid         NUMBER          := NULL;
      ln_masterorg        NUMBER;
      ln_organizationid   NUMBER          := gn_master_orgid;
      pv_errcode          VARCHAR2 (1000);
      pv_error            VARCHAR2 (1000);
      lv_return_status    VARCHAR2 (1000);
      lv_error_message    VARCHAR2 (3000);
      lv_error_code       VARCHAR2 (1000);
      x_msg_count         NUMBER;
      x_msg_data          VARCHAR2 (3000);
      ln_msg_count        NUMBER;
      lv_msg_data         VARCHAR2 (3000);
      ln_msg_index_out    VARCHAR2 (3000);
      ln_error_code       NUMBER;
      ln_tarif_cat_cret   NUMBER          := 0;
   BEGIN
--***************************************************************************
--  Retrieving category id and structure id for 'Tariff' and 'Region' category.
-- *************************************************************************
      lv_error_message := NULL;
      x_msg_count := 0;
      ln_msg_count := 0;

      /* -- START : Commented for 1.22.
      BEGIN
         ln_struc_id := NULL;
         ln_tarif_cat_cret := 0;                                       -- 1.3

         SELECT category_set_id, structure_id
           INTO ln_cat_set_id, ln_struc_id
           FROM apps.mtl_category_sets
          WHERE UPPER (category_set_name) = UPPER (pv_cat_set);

      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            pv_retcode := SQLCODE;
            pv_reterror :=
                         pv_cat_set || 'category set NOT PRESENT ' || SQLERRM;
         WHEN OTHERS
         THEN
            pv_retcode := SQLCODE;
            pv_reterror :=
                  'Error Occured while retrieving category set id and structure id for category set '
               || pv_cat_set
               || SQLERRM;
      END;
      */
      -- END : Commented for 1.22.

      --msg (   'Assign Multi Cat '
      --     || pv_cat_set
      --     || ' segment1 '
      --     || pv_segment1
      --     || 'segment2 '
      --     || pv_segment2
      --     || ' segment3 '
      --     || pv_segment3
      --     || 'segment4 '
      --     || pv_segment4
      --     || 'segment5 '
      --     || pv_segment5
      --    );

      --********************************************************************
--Retrieving category id for category
--********************************************************************
      BEGIN
         IF pv_cat_set = 'TARRIF CODE'
         THEN
            ln_cat_set_id := gn_tariff_code_set_id;        -- Added for 1.22.
            ln_struc_id := gn_tariff_code_structure_id;    -- Added for 1.22.

            SELECT category_id
              INTO ln_ncatid
              FROM apps.mtl_categories_b
             WHERE segment1 = pv_segment1
               AND segment3 = pv_segment2
               AND segment4 = pv_segment3
               AND structure_id = ln_struc_id
               AND NVL (enabled_flag, 'Y') = 'Y';
         ELSIF pv_cat_set = 'REGION'
         THEN
            ln_cat_set_id := gn_region_set_id;             -- Added for 1.22.
            ln_struc_id := gn_region_structure_id;         -- Added for 1.22.

            SELECT category_id
              INTO ln_ncatid
              FROM apps.mtl_categories_b
             WHERE segment1 = pv_segment1
               AND segment2 = pv_segment2
               AND segment3 = pv_segment3
               AND segment4 = pv_segment4
               AND structure_id = ln_struc_id
               AND NVL (enabled_flag, 'Y') = 'Y';
         ELSIF pv_cat_set = 'MASTER_SEASON'
         THEN
            ln_cat_set_id := gn_mst_season_set_id;         -- Added for 1.22.
            ln_struc_id := gn_mst_season_structure_id;     -- Added for 1.22.

            SELECT category_id
              INTO ln_ncatid
              FROM apps.mtl_categories_b
             WHERE segment1 = pv_segment1
               AND segment2 = pv_segment2
               AND segment3 = pv_segment3
               AND segment4 = pv_segment4                  --W.r.t version 1.1
               AND segment5 = pv_segment5                  --W.r.t version 1.1
               AND structure_id = ln_struc_id
               AND NVL (enabled_flag, 'Y') = 'Y';
         ELSIF pv_cat_set = 'PRODUCTION_LINE'             --W.r.t version 1.10
         THEN
            ln_cat_set_id := gn_prod_line_set_id;          -- Added for 1.22.
            ln_struc_id := gn_prod_line_structure_id;      -- Added for 1.22.

            SELECT category_id
              INTO ln_ncatid
              FROM apps.mtl_categories_b
             WHERE segment1 = pv_segment1
               AND segment2 = pv_segment2
               AND segment3 = pv_segment3
               AND structure_id = ln_struc_id
               AND NVL (enabled_flag, 'Y') = 'Y';         --W.r.t version 1.10
         END IF;
      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            ln_ncatid := 0;
            pv_errcode := SQLCODE;
            pv_error := 'Category Id Not present ' || SQLERRM;
         -- START : Added for 1.23.
         WHEN TOO_MANY_ROWS
         THEN
            ln_ncatid := 0;
            pv_errcode := SQLCODE;
            pv_error :=
                  'Multiple categories found for Style : '
               || gv_plm_style
               || '. '
               || SQLERRM;
         -- END : Added for 1.23.
         WHEN OTHERS
         THEN
            pv_retcode := SQLCODE;
            pv_reterror :=
                  'Exception occured while retreiving Category id in Assign : '
               || pv_cat_set
               || SQLERRM;
      END;

      msg (   ' Mutli Category pv_cat_set '
           || pv_cat_set
           || ' Segment1 '
           || pv_segment1
           || ' Segment2 '
           || pv_segment2
           || ' Segment3 '
           || pv_segment3
          );

      ---- For Tariff Category code ---------------1.3
      IF    pv_cat_set = 'TARRIF CODE'
         OR pv_cat_set = 'PRODUCTION_LINE'               -- W.r.t Version 1.15
      THEN
         /*****************************************************************************************
           Retrieving old category assigned to TARRIF category
           ****************************************************************************************/
         BEGIN
            SELECT category_id
              INTO ln_oldcatid
              FROM apps.mtl_item_categories
             WHERE inventory_item_id = pn_item_id
               AND organization_id = pn_organizationid
               AND category_set_id = ln_cat_set_id;      -- Modified for 1.22.

            /* AND category_set_id =
                        (SELECT category_set_id
                           FROM apps.mtl_category_sets
                          WHERE UPPER (category_set_name) = UPPER (pv_cat_set)); */
            -- Commented for 1.22.
            msg (   ' Mutli Category pv_cat_set '
                 || pv_cat_set
                 || ' ln_oldcatid '
                 || ln_oldcatid
                 || ' ln_ncatid '
                 || ln_ncatid
                 || ' Oganization '
                 || pn_organizationid
                 || ' pn_item_id '
                 || pn_item_id
                );

            IF ln_oldcatid <> ln_ncatid AND ln_ncatid <> 0
            THEN
               BEGIN
                  ln_tarif_cat_cret := 1;
                  --W.r.t Version 1.26
                  ln_tarif_cat_cret := 1;
                  gn_cat_process_count := gn_cat_process_count + 1;

                  IF gn_cat_process_count > gn_cat_process_works
                  THEN
                     gn_cat_process_id := gn_cat_process_id + 1;
                     gn_cat_process_count := 1;
                  END IF;

                  INSERT INTO apps.mtl_item_categories_interface
                              (inventory_item_id, organization_id,
                               category_set_id, category_id, old_category_id,
                               last_update_date, last_updated_by,
                               creation_date, created_by, process_flag,
                               transaction_type, set_process_id
                              )
                       VALUES (pn_item_id, pn_organizationid,
                               ln_cat_set_id, ln_ncatid, ln_oldcatid,
                               SYSDATE, gn_userid,
                               SYSDATE, gn_userid, 1,
                               'UPDATE', gn_cat_process_id
                              );

                  --W.r.t Version 1.26
                  COMMIT;
               /* -- Commenting W.r.t Version 1.26
                  inv_item_category_pub.update_category_assignment
                                     (p_api_version            => 1.0,
                                      p_init_msg_list          => fnd_api.g_false,
                                      p_commit                 => fnd_api.g_true,
                                      x_return_status          => lv_return_status,
                                      x_errorcode              => lv_error_code,
                                      x_msg_count              => ln_msg_count,
                                      x_msg_data               => lv_msg_data,
                                      p_category_id            => ln_ncatid,
                                      p_category_set_id        => ln_cat_set_id,
                                      p_inventory_item_id      => pn_item_id,
                                      p_organization_id        => pn_organizationid,
                                      p_old_category_id        => ln_oldcatid
                                     );

                  IF lv_return_status <> fnd_api.g_ret_sts_success
                  THEN
                     FOR i IN 1 .. ln_msg_count
                     LOOP
                        apps.fnd_msg_pub.get
                                         (p_msg_index          => i,
                                          p_encoded            => fnd_api.g_false,
                                          p_data               => x_msg_data,
                                          p_msg_index_out      => ln_msg_index_out
                                         );

                        IF lv_error_message IS NULL
                        THEN
                           lv_error_message := SUBSTR (x_msg_data, 1, 250);
                        ELSE
                           lv_error_message :=
                              SUBSTR (   lv_error_message
                                      || ' /'
                                      || SUBSTR (x_msg_data, 1, 250),
                                      1,
                                      1000
                                     );
                        END IF;
                     END LOOP;

                     fnd_msg_pub.delete_msg ();
                     pv_retcode := SQLCODE;
                     pv_reterror := lv_error_message;
                     fnd_file.put_line
                        (fnd_file.LOG,
                         SUBSTR
                            (   'API update_category_assignment Error FOR TARIFF CODE: '
                             || ' ln_ncatid '
                             || ln_ncatid
                             || ' \ '
                             || lv_error_message,
                             1,
                             900
                            )
                        );
                  --ELSE
                  --   msg (   'Created Category Assiginment from Item id : '
                  --        || pn_item_id
                  --        || ' Successfully'
                  --       );
                  END IF;


                  */
               --End COmmenting W.r.t Version 1.26
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     fnd_file.put_line
                        (fnd_file.LOG,
                         SUBSTR
                            (   'Error Occured while inserting mtl_item_categories_interface  : '
                             || pn_item_id
                             || ' \ '
                             || pn_organizationid
                             || '  '
                             || pv_cat_set
                             || ' \ '
                             || SQLERRM,
                             1,
                             900
                            )
                        );
               END;
            ELSE
               -- msg (   'Created Item is already Assigined to Item id : '
               --      || pn_item_id
               --     );
               ln_tarif_cat_cret := 1;
            END IF;
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               ln_oldcatid := NULL;
         END;
      END IF;                                    -- pv_cat_set = 'TARRIF CODE'

      ---- For Tariff Category code ---------------1.3

      --********************************************************
--Retrieving old category assigned to item category
--********************************************************
      IF ln_ncatid <> 0 AND ln_tarif_cat_cret = 0
      THEN
         BEGIN
            BEGIN
               --Start W.r.t Version 1.26
               gn_cat_process_count := gn_cat_process_count + 1;

               IF gn_cat_process_count > gn_cat_process_works
               THEN
                  gn_cat_process_id := gn_cat_process_id + 1;
                  gn_cat_process_count := 1;
               END IF;

               INSERT INTO apps.mtl_item_categories_interface
                           (inventory_item_id, organization_id,
                            category_set_id, category_id, old_category_id,
                            last_update_date, last_updated_by, creation_date,
                            created_by, process_flag, transaction_type,
                            set_process_id
                           )
                    VALUES (pn_item_id, pn_organizationid,
                            ln_cat_set_id, ln_ncatid, NULL,
                            SYSDATE, gn_userid, SYSDATE,
                            gn_userid, 1, 'CREATE',
                            gn_cat_process_id
                           );

               COMMIT;
            --Start W.r.t Version 1.26

            /* -- Start Commenting W.r.t Version 1.26
               inv_item_category_pub.create_category_assignment
                                      (p_api_version            => 1,
                                       p_init_msg_list          => fnd_api.g_false,
                                       p_commit                 => fnd_api.g_false,
                                       x_return_status          => lv_return_status,
                                       x_errorcode              => ln_error_code,
                                       x_msg_count              => ln_msg_count,
                                       x_msg_data               => lv_msg_data,
                                       p_category_id            => ln_ncatid,
                                       p_category_set_id        => ln_cat_set_id,
                                       p_inventory_item_id      => pn_item_id,
                                       p_organization_id        => pn_organizationid
                                      );

               IF lv_return_status <> fnd_api.g_ret_sts_success
               THEN
                  FOR i IN 1 .. ln_msg_count
                  LOOP
                     apps.fnd_msg_pub.get
                                         (p_msg_index          => i,
                                          p_encoded            => fnd_api.g_false,
                                          p_data               => x_msg_data,
                                          p_msg_index_out      => ln_msg_index_out
                                         );

                     IF lv_error_message IS NULL
                     THEN
                        lv_error_message := SUBSTR (x_msg_data, 1, 250);
                     ELSE
                        lv_error_message :=
                           SUBSTR (   lv_error_message
                                   || ' /'
                                   || SUBSTR (x_msg_data, 1, 250),
                                   1,
                                   2000
                                  );
                     END IF;
                  END LOOP;

                  fnd_msg_pub.delete_msg ();
                  pv_retcode := SQLCODE;
                  pv_reterror := lv_error_message;
                  fnd_file.put_line
                        (fnd_file.LOG,
                         SUBSTR (   'API create_category_assignment Error : '
                                 || lv_error_message,
                                 1,
                                 900
                                )
                        );
               --ELSE
               --   msg (   'Created Category Assiginment from Item id : '
               --        || pn_item_id
               --        || ' Successfully'
               --       );
               END IF;

               */
            -- End Commenting W.r.t Version 1.26
            EXCEPTION
               WHEN OTHERS
               THEN
                  fnd_file.put_line
                     (fnd_file.LOG,
                      SUBSTR
                         (   'Error Occured while inserting mtl_item_categories_interface  : '
                          || pn_item_id
                          || ' \ '
                          || pn_organizationid
                          || '  '
                          || pv_cat_set
                          || ' \ '
                          || SQLERRM,
                          1,
                          900
                         )
                     );
            END;
         END;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         pv_retcode := SQLCODE;
         pv_reterror :=
                     'others exception in Assign Tariff Category ' || SQLERRM;
   END assign_multi_mem_category;

   /*************************************************************************
    * Procedure/Function Name  :  ASSIGN_INVENTORY_CATEGORY
    *
    * Description              :  The purpose of this procedure to assign
    *                             inventory category to Item.
    * INPUT Parameters : pn_batchid
    *                    pv_brand
    *                    pv_division
    *                    pv_sub_group
    *                    pv_class
    *                    pv_sub_class
    *                    pv_master_style
    *                    pv_style
    *                    pv_colorway
    *                    pn_organizationid
    *                    pv_introseason
    *                    pv_colorwaystatus
    *                    pv_size
    *                    pn_item_id
    * OUTPUT Parameters: pv_retcode
    *                    pv_reterror
    *
    * DEVELOPMENT and MAINTENANCE HISTORY
    *
    * date          author             Version  Description
    * ------------  -----------------  -------  ------------------------------
    * 9/11/2014     INFOSYS            1.0.1    Initial Version
    *************************************************************************/
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
   )
--**************************************************************************
--procedure to assign inventory items to inventory category
--**************************************************************************
   IS
      lv_pn               VARCHAR2 (240)
                           := gv_package_name || '.ASSIGN_INVENTORY_CATEGORY';
      eusererror          EXCEPTION;
      ln_invcatid         NUMBER          := NULL;
      ln_cat_set_id       NUMBER          := NULL;
      ln_struc_id         NUMBER          := NULL;
      ln_count            NUMBER          := NULL;
      ln_oldcatid         NUMBER          := NULL;
      ln_masterorg        NUMBER;
      ln_default_cat_id   NUMBER;
      lv_old_segment1     VARCHAR2 (400);
      lv_old_segment5     VARCHAR2 (400);
      lv_new_segment1     VARCHAR2 (400);
      lv_new_segment2     VARCHAR2 (400);
      lv_new_segment3     VARCHAR2 (400);
      lv_new_segment4     VARCHAR2 (400);
      lv_new_segment5     VARCHAR2 (400);
      lv_new_segment6     VARCHAR2 (400);
      lv_new_segment7     VARCHAR2 (400);
      lv_new_segment8     VARCHAR2 (400);
      ln_mod_inv_cat      VARCHAR2 (400);
      ln_invcatid1        NUMBER;
      ln_organizationid   NUMBER          := gn_master_orgid;
      lv_errcode          VARCHAR2 (1000);
      lv_error            VARCHAR2 (1000);
      pv_errcode          VARCHAR2 (1000);
      pv_error            VARCHAR2 (1000);
      lv_return_status    VARCHAR2 (1000);
      lv_error_message    VARCHAR2 (3000);
      lv_error_code       VARCHAR2 (1000);
      x_msg_count         NUMBER;
      x_msg_data          VARCHAR2 (3000);
      ln_msg_count        NUMBER;
      lv_msg_data         VARCHAR2 (3000);
      ln_msg_index_out    VARCHAR2 (3000);
      lv_attr_style       VARCHAR2 (1000);
      ln_error_code       NUMBER;
   BEGIN
      x_msg_count := 0;
      ln_msg_count := 0;
      lv_error_message := NULL;
      lv_attr_style := pv_size;                          --W.r.t Version 1.32
      /* -- START : Commented for 1.22.
      --***************************************************************************
       --Retrieving category id and structure id for 'inventory' category.
      --****************************************************************************
            BEGIN
               SELECT category_set_id, structure_id, default_category_id
                 INTO ln_cat_set_id, ln_struc_id, ln_default_cat_id
                 FROM apps.mtl_category_sets
                WHERE UPPER (category_set_name) = 'INVENTORY';
            EXCEPTION
               WHEN NO_DATA_FOUND
               THEN
                  pv_retcode := SQLCODE;
                  pv_reterror := 'Inventory category set Not present' || SQLERRM;
               WHEN OTHERS
               THEN
                  pv_retcode := SQLCODE;
                  pv_reterror :=
                        'Error Occured while retrieving category set id and structure id for Inventory category set '
                     || SQLERRM;
            END;
      */
      -- END : Commented for 1.22.
      ln_cat_set_id := gn_inventory_set_id;                -- Added for 1.22.
      ln_struc_id := gn_inventory_structure_id;            -- Added for 1.22.

--****************************************************************************
--Retrieving category id for 'inventory' category
--***************************************************************************
      BEGIN
         SELECT category_id, segment1, segment2,
                segment3, segment4, segment5,
                segment6, segment7, segment8
           INTO ln_invcatid, lv_new_segment1, lv_new_segment2,
                lv_new_segment3, lv_new_segment4, lv_new_segment5,
                lv_new_segment6, lv_new_segment7, lv_new_segment8
           FROM apps.mtl_categories_b
          WHERE segment1 = pv_brand                  --UPPER (TRIM (pv_brand))
            AND segment2 = pv_division            --UPPER (TRIM (pv_division))
            AND segment3 = pv_sub_group          --UPPER (TRIM (pv_sub_group))
            AND segment4 = pv_class                  --UPPER (TRIM (pv_class))
            AND segment5 = pv_sub_class          --UPPER (TRIM (pv_sub_class))
            AND segment6 = pv_master_style    --UPPER (TRIM (pv_master_style))
            AND segment7 = pv_style                  --UPPER (TRIM (pv_style))
            AND segment8 = pv_colorway           -- UPPER (TRIM (pv_colorway))
            AND structure_id = ln_struc_id
            AND NVL (enabled_flag, 'Y') = 'Y';
      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            ln_invcatid := 0;
            pv_errcode := SQLCODE;
            pv_error := ' Inventory Category Id Not present ' || SQLERRM;
         -- BEGIN : Added for 1.23.
         WHEN TOO_MANY_ROWS
         THEN
            ln_invcatid := 0;
            pv_errcode := SQLCODE;
            pv_error :=
                  'Multiple Inventory category codes found for style : '
               || gv_plm_style
               || '. '
               || SQLERRM;
         -- END : Added for 1.23.
         WHEN OTHERS
         THEN
            ln_invcatid := 0;
            pv_retcode := SQLCODE;
            pv_reterror :=
                  'Exception occured while retreiving Category id in Assign pf Category'
               || SQLERRM;
      END;

      /*****************************************************************************************
      Retrieving old category assigned to item category
      ****************************************************************************************/
      BEGIN
         SELECT category_id
           INTO ln_oldcatid
           FROM apps.mtl_item_categories
          WHERE inventory_item_id = pn_item_id
            AND organization_id = ln_organizationid
            AND category_set_id = ln_cat_set_id;

         IF ln_oldcatid <> ln_invcatid AND ln_invcatid <> 0
         THEN
            BEGIN
               --Start W.r.t Version 1.26
               gn_cat_process_count := gn_cat_process_count + 1;

               IF gn_cat_process_count > gn_cat_process_works
               THEN
                  gn_cat_process_id := gn_cat_process_id + 1;
                  gn_cat_process_count := 1;
               END IF;

               INSERT INTO apps.mtl_item_categories_interface
                           (inventory_item_id, organization_id,
                            category_set_id, category_id, old_category_id,
                            last_update_date, last_updated_by, creation_date,
                            created_by, process_flag, transaction_type,
                            set_process_id
                           )
                    VALUES (pn_item_id, ln_organizationid,
                            ln_cat_set_id, ln_invcatid, ln_oldcatid,
                            SYSDATE, gn_userid, SYSDATE,
                            gn_userid, 1, 'UPDATE',
                            gn_cat_process_id
                           );

               COMMIT;
            --End W.r.t Version 1.26

            --Start Commenting W.r.t Version 1.26
            /*

               inv_item_category_pub.update_category_assignment
                                     (p_api_version            => 1.0,
                                      p_init_msg_list          => fnd_api.g_false,
                                      p_commit                 => fnd_api.g_true,
                                      x_return_status          => lv_return_status,
                                      x_errorcode              => lv_error_code,
                                      x_msg_count              => ln_msg_count,
                                      x_msg_data               => lv_msg_data,
                                      p_category_id            => ln_invcatid,
                                      p_category_set_id        => ln_cat_set_id,
                                      p_inventory_item_id      => pn_item_id,
                                      p_organization_id        => ln_organizationid,
                                      p_old_category_id        => ln_oldcatid
                                     );

               IF lv_return_status <> fnd_api.g_ret_sts_success
               THEN
                  FOR i IN 1 .. ln_msg_count
                  LOOP
                     apps.fnd_msg_pub.get
                                         (p_msg_index          => i,
                                          p_encoded            => fnd_api.g_false,
                                          p_data               => x_msg_data,
                                          p_msg_index_out      => ln_msg_index_out
                                         );

                     IF lv_error_message IS NULL
                     THEN
                        lv_error_message := SUBSTR (x_msg_data, 1, 250);
                     ELSE
                        lv_error_message :=
                           SUBSTR (   lv_error_message
                                   || ' /'
                                   || SUBSTR (x_msg_data, 1, 250),
                                   1,
                                   1000
                                  );
                     END IF;
                  END LOOP;

                  fnd_msg_pub.delete_msg ();
                  pv_retcode := SQLCODE;
                  pv_reterror := lv_error_message;
                  fnd_file.put_line (fnd_file.LOG,
                                     SUBSTR ('API Error : '
                                             || lv_error_message,
                                             1,
                                             900
                                            )
                                    );
               --ELSE
               --   msg ((   'Created Category Assiginment from Item id : '
               --         || pn_item_id
               --         || ' Successfully'
               ---        )
               --       );
               END IF;

                   */
            --W.r.t Version 1.26
            EXCEPTION
               WHEN OTHERS
               THEN
                  fnd_file.put_line
                     (fnd_file.LOG,
                      SUBSTR
                         (   'Error Occured while inserting mtl_item_categories_interface  : '
                          || pn_item_id
                          || ' \ '
                          || ln_organizationid
                          || '  '
                          || 'Inventory Category'
                          || ' \ '
                          || SQLERRM,
                          1,
                          900
                         )
                     );
            END;
         --ELSE
         --   msg ((   'Created Item is already Assigined to Item id : '
         --         || pn_item_id
         --        )
         --       );
         END IF;
      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            BEGIN
               --Start W.r.t Version 1.26
               gn_cat_process_count := gn_cat_process_count + 1;

               IF gn_cat_process_count > gn_cat_process_works
               THEN
                  gn_cat_process_id := gn_cat_process_id + 1;
                  gn_cat_process_count := 1;
               END IF;

               INSERT INTO apps.mtl_item_categories_interface
                           (inventory_item_id, organization_id,
                            category_set_id, category_id, old_category_id,
                            last_update_date, last_updated_by, creation_date,
                            created_by, process_flag, transaction_type,
                            set_process_id
                           )
                    VALUES (pn_item_id, ln_organizationid,
                            ln_cat_set_id, ln_invcatid, NULL,
                            SYSDATE, gn_userid, SYSDATE,
                            gn_userid, 1, 'CREATE',
                            gn_cat_process_id
                           );

               COMMIT;
            --End W.r.t Version 1.26

            --Start Commenting W.r.t Version 1.26
            /*
               inv_item_category_pub.create_category_assignment
                                      (p_api_version            => 1,
                                       p_init_msg_list          => fnd_api.g_false,
                                       p_commit                 => fnd_api.g_false,
                                       x_return_status          => lv_return_status,
                                       x_errorcode              => ln_error_code,
                                       x_msg_count              => ln_msg_count,
                                       x_msg_data               => lv_msg_data,
                                       p_category_id            => ln_invcatid,
                                       p_category_set_id        => ln_cat_set_id,
                                       p_inventory_item_id      => pn_item_id,
                                       p_organization_id        => ln_organizationid
                                      );

               IF lv_return_status <> fnd_api.g_ret_sts_success
               THEN
                  FOR i IN 1 .. ln_msg_count
                  LOOP
                     apps.fnd_msg_pub.get
                                         (p_msg_index          => i,
                                          p_encoded            => fnd_api.g_false,
                                          p_data               => x_msg_data,
                                          p_msg_index_out      => ln_msg_index_out
                                         );

                     IF lv_error_message IS NULL
                     THEN
                        lv_error_message := SUBSTR (x_msg_data, 1, 250);
                     ELSE
                        lv_error_message :=
                           SUBSTR (   lv_error_message
                                   || ' /'
                                   || SUBSTR (x_msg_data, 1, 250),
                                   1,
                                   2000
                                  );
                     END IF;
                  END LOOP;

                  fnd_msg_pub.delete_msg ();
                  pv_retcode := SQLCODE;
                  pv_reterror := lv_error_message;
                  fnd_file.put_line (fnd_file.LOG,
                                     SUBSTR ('API Error : '
                                             || lv_error_message,
                                             1,
                                             900
                                            )
                                    );
               --ELSE
               --   msg (   ' Created Category Assiginment from Item id : '
               --        || pn_item_id
               --        || ' Successfully'
               --       );
               END IF;
               */
            --End Commenting W.r.t Version 1.26
            EXCEPTION
               WHEN OTHERS
               THEN
                  pv_retcode := SQLCODE;
                  pv_reterror :=
                        'Begin others exception in Assign Inventory Category '
                     || SQLERRM;
            END;
      END;

      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         pv_retcode := SQLCODE;
         pv_reterror :=
               'Unexpected error occured while inserting Inventory Category '
            || SQLERRM;
   END assign_inventory_category;

   /*************************************************************************
   * Procedure/Function Name  :  CREATE_INVENTORY_CATEGORY
   * Description              :  The purpose of this procedure to create
   *                             inventory category.
   * INPUT Parameters : pn_batchid
   *                    pv_brand
   *                    pv_gender
   *                    pv_prodsubgroup
   *                    pv_class
   *                    pv_sub_class
   *                    pv_master_style
   *                    pv_style
   *                    pv_colorway
   * OUTPUT Parameters: pv_retcode
   *                    pv_reterror
   * DEVELOPMENT and MAINTENANCE HISTORY
   *
   * date          author             Version  Description
   * ------------  -----------------  -------  ------------------------------
   * 9/11/2014     INFOSYS            1.0.1    Initial Version
   *************************************************************************/
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
   )
   /*************************************************************************************
     procedure to create inventory category in which
      segment1 = brand
      segment2 = division
      segemnt3 = Department
      segemnt4 = Class
      segment5 = sub group
      segment6 = Master style
      segment7 = style
      segment8 = style Option
    *************************************************************************************/
   IS
      lv_pn               VARCHAR2 (240)
                           := gv_package_name || '.create_inventory_category';
      ln_inventorycatid   NUMBER;
      lv_category         apps.inv_item_category_pub.category_rec_type;
      lv_ret_status       VARCHAR2 (1);
      lv_error_code       NUMBER;
      x_msg_count         NUMBER;
      lv_msg_data         VARCHAR2 (2000);
      ln_category_id      VARCHAR2 (40);
      ln_cat_set_id       NUMBER;
      ln_structure_id     NUMBER;
      lv_message          VARCHAR2 (2000);
      ln_msg_count        NUMBER;
   BEGIN
      x_msg_count := 0;
      ln_msg_count := 0;
      /* -- START : Commented for 1.22.
            BEGIN
               SELECT category_set_id, structure_id
                 INTO ln_cat_set_id, ln_structure_id
                 FROM apps.mtl_category_sets
                WHERE UPPER (category_set_name) = 'INVENTORY';
            EXCEPTION
               WHEN NO_DATA_FOUND
               THEN
                  pv_retcode := 'Inventory category set not present ' || SQLCODE;
                  pv_reterror := SQLERRM;
               WHEN OTHERS
               THEN
                  pv_retcode := SQLCODE;
                  pv_reterror :=
                        'Error Occured while retrieving category set id and structure id for Inventory category set '
                     || SQLERRM;
            END;
      */
      -- END : Commented for 1.22.
      ln_cat_set_id := gn_inventory_set_id;                -- Added for 1.22.
      ln_structure_id := gn_inventory_structure_id;        -- Added for 1.22.
      ln_inventorycatid := NULL;

      BEGIN
         SELECT category_id
           INTO ln_inventorycatid
           FROM apps.mtl_categories_b
          WHERE segment1 = pv_brand                  --UPPER (TRIM (pv_brand))
            AND segment2 = pv_gender                --UPPER (TRIM (pv_gender))
            AND segment3 = pv_prodsubgroup    --UPPER (TRIM (pv_prodsubgroup))
            AND segment4 = pv_class                  --UPPER (TRIM (pv_class))
            AND segment5 = pv_sub_class          --UPPER (TRIM (pv_sub_class))
            AND segment6 = pv_master_style    --UPPER (TRIM (pv_master_style))
            AND segment7 = pv_style_name             --UPPER (TRIM (pv_style))
            AND segment8 = pv_colorway            --UPPER (TRIM (pv_colorway))
            AND structure_id = ln_structure_id
            AND NVL (enabled_flag, 'Y') = 'Y';
      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            BEGIN
               lv_category.structure_id := ln_structure_id;
               lv_category.segment1 := pv_brand;
               lv_category.segment2 := pv_gender;
               lv_category.segment3 := pv_prodsubgroup;
               lv_category.segment4 := pv_class;
               lv_category.segment5 := pv_sub_class;
               lv_category.segment6 := pv_master_style;
               lv_category.segment7 := pv_style_name;
               lv_category.segment8 := pv_colorway;
               -- Start
               lv_category.start_date_active := SYSDATE;
               lv_category.description :=
                     pv_brand
                  || '.'
                  || pv_gender
                  || '.'
                  || pv_prodsubgroup
                  || '.'
                  || pv_class
                  || '.'
                  || pv_sub_class
                  || '.'
                  || pv_master_style
                  || '.'
                  || pv_style_name
                  || '.'
                  || pv_colorway;
               lv_category.attribute_category := 'Item Categories';
               lv_category.attribute5 := pv_sub_division;
               lv_category.attribute6 := pv_detail_silhouette;
               lv_category.attribute7 := pv_style;
               lv_category.attribute8 := pv_clrway;
               -- End
               lv_category.summary_flag := 'N';
               lv_category.enabled_flag := 'Y';
               /************************************************************
               calling API to create inventory category
               **************************************************************/
               apps.inv_item_category_pub.create_category
                                      (p_api_version        => 1.0,
                                       p_init_msg_list      => apps.fnd_api.g_true,
                                       x_return_status      => lv_ret_status,
                                       x_errorcode          => lv_error_code,
                                       x_msg_count          => ln_msg_count,
                                       x_msg_data           => lv_msg_data,
                                       p_category_rec       => lv_category,
                                       x_category_id        => ln_category_id
                                      );

               IF (lv_ret_status <> apps.wsh_util_core.g_ret_sts_success)
               THEN
                  FOR i IN 1 .. ln_msg_count
                  LOOP
                     lv_message := apps.fnd_msg_pub.get (i, 'F');
                     lv_message := REPLACE (lv_msg_data, CHR (0), ' ');
                     fnd_file.put_line
                        (fnd_file.LOG,
                         SUBSTR
                               (   'Inside create_inventory_category Error  '
                                || lv_message,
                                1,
                                900
                               )
                        );
                  END LOOP;

                  pv_retcode := SQLCODE;
                  pv_reterror := lv_message;
                  apps.fnd_msg_pub.delete_msg ();
               END IF;

               ln_msg_count := 0;
            /* -- START : Commented for 1.21.
                            ***********************************************************
                             calling API to create valid categories
                           ***************************************************************
                           apps.inv_item_category_pub.create_valid_category
                                                 (p_api_version             => 1.0,
                                                  p_init_msg_list           => apps.fnd_api.g_false,
                                                  p_commit                  => apps.fnd_api.g_true,
                                                  x_return_status           => lv_ret_status,
                                                  x_errorcode               => lv_error_code,
                                                  x_msg_count               => ln_msg_count,
                                                  x_msg_data                => lv_msg_data,
                                                  p_category_set_id         => ln_cat_set_id,
                                                  p_category_id             => ln_category_id,
                                                  p_parent_category_id      => NULL
                                                 );

                           IF (lv_ret_status <> apps.wsh_util_core.g_ret_sts_success)
                           THEN
                              COMMIT;

                              FOR i IN 1 .. ln_msg_count
                              LOOP
                                 lv_message := apps.fnd_msg_pub.get (i, 'F');
                                 lv_message :=
                                    SUBSTR (REPLACE (lv_msg_data, CHR (0), ' '), 1, 2000);
                              END LOOP;

                              pv_retcode := SQLCODE;
                              pv_reterror := lv_message;
                              apps.fnd_msg_pub.delete_msg ();
                           END IF;
            */
            -- END : Commented for 1.21.
            EXCEPTION
               WHEN OTHERS
               THEN
                  pv_retcode := SQLCODE;
                  pv_reterror := 'Error in ' || lv_pn || '  ' || SQLERRM;
            END;
         -- BEGIN : Added for 1.23.
         WHEN TOO_MANY_ROWS
         THEN
            ln_inventorycatid := NULL;
            pv_retcode := SQLCODE;
            pv_reterror :=
                  'Multiple categories found for the style : '
               || gv_plm_style
               || ' : '
               || SQLERRM;
         -- END : Added for 1.23.
         WHEN OTHERS
         THEN
            ln_inventorycatid := NULL;                     -- Added for 1.23.
            pv_retcode := SQLCODE;
            pv_reterror := 'Error in ' || lv_pn || '  ' || SQLERRM;
      END;

      IF ln_inventorycatid IS NOT NULL AND pv_clrway IS NOT NULL
      THEN
         BEGIN
            lv_category.category_id := ln_inventorycatid;
            lv_category.attribute_category := 'Item Categories';
            lv_category.attribute5 := pv_sub_division;
            lv_category.attribute6 := pv_detail_silhouette;
            lv_category.attribute7 := pv_style;
            lv_category.attribute8 := pv_clrway;
            apps.inv_item_category_pub.update_category
                                     (p_api_version        => 1.0,
                                      p_init_msg_list      => apps.fnd_api.g_true,
                                      p_commit             => apps.fnd_api.g_true,
                                      x_return_status      => lv_ret_status,
                                      x_errorcode          => lv_error_code,
                                      x_msg_count          => ln_msg_count,
                                      x_msg_data           => lv_msg_data,
                                      p_category_rec       => lv_category
                                     );

            IF (lv_ret_status <> apps.wsh_util_core.g_ret_sts_success)
            THEN
               FOR i IN 1 .. ln_msg_count
               LOOP
                  lv_message := apps.fnd_msg_pub.get (i, 'F');
                  lv_message := REPLACE (lv_msg_data, CHR (0), ' ');
                  fnd_file.put_line
                                (fnd_file.LOG,
                                 SUBSTR (   'Inside update_category Error  '
                                         || lv_message,
                                         1,
                                         900
                                        )
                                );
               END LOOP;

               pv_retcode := SQLCODE;
               pv_reterror := lv_message;
               apps.fnd_msg_pub.delete_msg ();
            END IF;
         EXCEPTION
            WHEN OTHERS
            THEN
               fnd_file.put_line
                            (fnd_file.LOG,
                                'Error while Updating Inventory Category :: '
                             || SQLERRM
                            );
         END;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line
                       (fnd_file.LOG,
                           'Error in Create Inventory Category Procedure :: '
                        || SQLERRM
                       );
   END create_inventory_category;

   /*******************************************************************************
   * Procedure/Function Name :      CREATE_CATEGORY
   *
   * Description              :     The purpose of this procedure to create categories.
   * INPUT Parameters         :     pv_segment1
   *                                pv_segment2
   *                                pv_segment3
   *                                pv_segment4
   *                                pv_segment5
   *                                pv_category_set
   * OUTPUT Parameters        :     pv_retcode
   *                                pv_reterror
   *
   * DEVELOPMENT and MAINTENANCE HISTORY
   *
   * date          author             Version  Description
   * ------------  -----------------  -------  ------------------------------
   * 9/11/2014     INFOSYS            1.0.1    Initial Version
   *************************************************************************/
   PROCEDURE create_category (
      pv_segment1             VARCHAR2,
      pv_segment2             VARCHAR2,
      pv_segment3             VARCHAR2,
      pv_segment4             VARCHAR2,
      pv_segment5             VARCHAR2,
      pv_category_set         VARCHAR2,
      pv_retcode        OUT   VARCHAR2,
      pv_reterror       OUT   VARCHAR2
   )
   IS
      lv_pn             VARCHAR2 (240)
                                     := gv_package_name || '.create_category';
      ln_stylecatid     NUMBER;
      lv_category       apps.inv_item_category_pub.category_rec_type;
      lv_ret_status     VARCHAR2 (1);
      lv_error_code     NUMBER;
      x_msg_count       NUMBER;
      ln_cat_set_id     NUMBER;
      ln_cat_struc_id   NUMBER;
      lv_msg_data       VARCHAR2 (2000);
      lv_message        VARCHAR2 (2000);
      ln_category_id    NUMBER;
      lv_segment1       VARCHAR2 (500)                         := pv_segment1;
      lv_segment2       VARCHAR2 (500)                         := pv_segment2;
      lv_segment3       VARCHAR2 (500)                         := pv_segment3;
      lv_segment4       VARCHAR2 (500)                         := pv_segment4;
      lv_segment5       VARCHAR2 (500)                         := pv_segment5;
      ln_msg_count      NUMBER;
   BEGIN
      x_msg_count := 0;
      ln_msg_count := 0;

      /* -- START : Commented for 1.22.
      BEGIN
         SELECT category_set_id, structure_id
           INTO ln_cat_set_id, ln_cat_struc_id
           FROM apps.mtl_category_sets
          WHERE UPPER (category_set_name) = UPPER (pv_category_set);
      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            pv_retcode := SQLCODE;
            pv_reterror := 'Styles category set not present ' || SQLERRM;
         WHEN OTHERS
         THEN
            pv_retcode := SQLCODE;
            pv_reterror :=
                  'Error Occured while retrieving category set id and structure id for Styles category set '
               || SQLERRM;
      END;
      */
      -- END : Commented for 1.22.

      --**********************************************************
-- code to verify whether category exists in the category set
--**********************************************************--msg (   pv_category_set--     || ':'--     || ' segment1 : '--     || lv_segment1--     || ' segment2 :'--     || lv_segment2--     || ' segment3 :'--     || lv_segment3--    );
      BEGIN
         IF pv_category_set = 'OM Sales Category'
         THEN
            lv_category.segment1 := lv_segment1;
            lv_category.description := lv_segment1;
            ln_cat_struc_id := gn_om_sales_structure_id;   -- Added for 1.22.

            SELECT category_id
              INTO ln_category_id
              FROM apps.mtl_categories_b
             WHERE segment1 = lv_segment1         --UPPER (TRIM (lv_segment1))
               AND structure_id = ln_cat_struc_id
               AND NVL (enabled_flag, 'Y') = 'Y';
         ELSIF pv_category_set = 'PRODUCTION_LINE'
         THEN
            lv_category.segment1 := lv_segment1;
            lv_category.segment2 := lv_segment2;
            lv_category.segment3 := lv_segment3;
            lv_category.description :=
                      lv_segment1 || '.' || lv_segment2 || '.' || lv_segment3;
            -- Added for 1.20.
            ln_cat_struc_id := gn_prod_line_structure_id;  -- Added for 1.22.

            SELECT category_id
              INTO ln_category_id
              FROM apps.mtl_categories_b
             WHERE segment1 = lv_segment1         --UPPER (TRIM (lv_segment1))
               AND segment2 = lv_segment2         --UPPER (TRIM (lv_segment2))
               AND segment3 = lv_segment3         --UPPER (TRIM (lv_segment3))
               AND structure_id = ln_cat_struc_id
               AND NVL (enabled_flag, 'Y') = 'Y';
         ELSIF pv_category_set = 'MASTER_SEASON'
         THEN
            lv_category.segment1 := lv_segment1;
            lv_category.segment2 := lv_segment2;
            lv_category.segment3 := lv_segment3;
            lv_category.segment4 := lv_segment4;
            lv_category.segment5 := lv_segment5;
            lv_category.description :=
                  lv_segment1
               || '.'
               || lv_segment2
               || '.'
               || lv_segment3
               || '.'
               || lv_segment4
               || '.'
               || lv_segment5;                              -- Added for 1.20.
            ln_cat_struc_id := gn_mst_season_structure_id;  -- Added for 1.22.

            SELECT category_id
              INTO ln_category_id
              FROM apps.mtl_categories_b
             WHERE segment1 = lv_segment1
               AND segment2 = lv_segment2
               AND segment3 = lv_segment3
               AND segment4 = lv_segment4
               AND segment5 = lv_segment5
               AND structure_id = ln_cat_struc_id
               AND NVL (enabled_flag, 'Y') = 'Y';
         ELSIF pv_category_set = 'TARRIF CODE'
         THEN
            lv_category.segment1 := lv_segment1;
            lv_category.segment3 := lv_segment2;
            lv_category.segment4 := lv_segment3;
            lv_category.description :=
                      lv_segment1 || '.' || lv_segment2 || '.' || lv_segment3;
            -- Added for 1.20.
            ln_cat_struc_id := gn_tariff_code_structure_id;

            -- Added for 1.22.
            SELECT category_id
              INTO ln_category_id
              FROM apps.mtl_categories_b
             WHERE segment1 = lv_segment1
               AND segment3 = lv_segment2
               AND segment4 = lv_segment3
               AND structure_id = ln_cat_struc_id
               AND NVL (enabled_flag, 'Y') = 'Y';
         ELSIF pv_category_set = 'REGION'
         THEN
            lv_category.segment1 := lv_segment1;
            lv_category.segment2 := lv_segment2;
            lv_category.segment3 := lv_segment3;
            lv_category.segment4 := lv_segment4;
            lv_category.description :=
                  lv_segment1
               || '.'
               || lv_segment2
               || '.'
               || lv_segment3
               || '.'
               || lv_segment4;                              -- Added for 1.20.
            ln_cat_struc_id := gn_region_structure_id;      -- Added for 1.22.

            SELECT category_id
              INTO ln_category_id
              FROM apps.mtl_categories_b
             WHERE segment1 = lv_segment1         --UPPER (TRIM (lv_segment1))
               AND segment2 = lv_segment2         --UPPER (TRIM (lv_segment2))
               AND segment3 = lv_segment3         --UPPER (TRIM (lv_segment3))
               AND segment4 = lv_segment4         --UPPER (TRIM (lv_segment4))
               AND structure_id = ln_cat_struc_id
               AND NVL (enabled_flag, 'Y') = 'Y';
         ELSIF pv_category_set = 'ITEM_TYPE'
         THEN
            lv_category.segment1 := lv_segment1;
            lv_category.segment2 := lv_segment2;
            lv_category.description := lv_segment1 || '.' || lv_segment2;
            -- Added for 1.20.
            ln_cat_struc_id := gn_item_type_structure_id;  -- Added for 1.22.

            SELECT category_id
              INTO ln_category_id
              FROM apps.mtl_categories_b
             WHERE segment1 = lv_segment1         --UPPER (TRIM (lv_segment1))
               AND segment2 = lv_segment2         --UPPER (TRIM (lv_segment2))
               AND structure_id = ln_cat_struc_id
               AND NVL (enabled_flag, 'Y') = 'Y';
         ELSIF pv_category_set = 'COLLECTION'
         THEN
            lv_category.segment1 := lv_segment1;
            lv_category.segment2 := lv_segment2;
            lv_category.description := lv_segment1 || '.' || lv_segment2;
            -- Added for 1.20.
            ln_cat_struc_id := gn_collection_structure_id; -- Added for 1.22.

            SELECT category_id
              INTO ln_category_id
              FROM apps.mtl_categories_b
             WHERE segment1 = lv_segment1         --UPPER (TRIM (lv_segment1))
               AND segment2 = lv_segment2         --UPPER (TRIM (lv_segment2))
               AND structure_id = ln_cat_struc_id
               AND NVL (enabled_flag, 'Y') = 'Y';
         ELSIF pv_category_set = 'PROJECT_TYPE'
         THEN
            lv_category.segment1 := lv_segment1;
            lv_category.segment2 := lv_segment2;
            lv_category.description := lv_segment1 || '.' || lv_segment2;
            -- Added for 1.20.
            ln_cat_struc_id := gn_proj_type_structure_id;  -- Added for 1.22.

            SELECT category_id
              INTO ln_category_id
              FROM apps.mtl_categories_b
             WHERE segment1 = lv_segment1         --UPPER (TRIM (lv_segment1))
               AND segment2 = lv_segment2         --UPPER (TRIM (lv_segment2))
               AND structure_id = ln_cat_struc_id
               AND NVL (enabled_flag, 'Y') = 'Y';
         ELSIF pv_category_set = 'PO Item Category'
         THEN
            lv_category.segment1 := lv_segment1;
            lv_category.segment2 := lv_segment2;
            lv_category.segment3 := lv_segment3;
            lv_category.description :=
                      lv_segment1 || '.' || lv_segment2 || '.' || lv_segment3;
            -- Added for 1.20.
            ln_cat_struc_id := gn_po_item_structure_id;    -- Added for 1.22.

            SELECT category_id
              INTO ln_category_id
              FROM apps.mtl_categories_b
             WHERE segment1 = lv_segment1         --UPPER (TRIM (lv_segment1))
               AND segment2 = lv_segment2         --UPPER (TRIM (lv_segment2))
               AND segment3 = lv_segment3         --UPPER (TRIM (lv_segment3))
               AND structure_id = ln_cat_struc_id
               AND NVL (enabled_flag, 'Y') = 'Y';
         ELSIF pv_category_set = 'QR'
         THEN
            lv_category.segment1 := lv_segment1;
            lv_category.description := lv_segment1;        -- Added for 1.20.
            ln_cat_struc_id := gn_qr_structure_id;         -- Added for 1.22.

            SELECT category_id
              INTO ln_category_id
              FROM apps.mtl_categories_b
             WHERE segment1 = lv_segment1         --UPPER (TRIM (lv_segment1))
               AND structure_id = ln_cat_struc_id
               AND NVL (enabled_flag, 'Y') = 'Y';
         END IF;
      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            BEGIN
               --msg (   ' Cre '
               --     || pv_category_set
               --     || ':'
               --     || ' segment1 : '
               --     || lv_segment1
               --     || ' segment2 :'
               --     || lv_segment2
               --     || ' segment3 :'
               --     || lv_segment3
               --    );
               --lv_category.description := lv_segment1
               --                           || '.' ||
               --                           lv_segment2
               --                           || '.' ||
               --                           lv_segment3;
               lv_category.structure_id := ln_cat_struc_id;
               lv_category.summary_flag := 'N';
               lv_category.enabled_flag := 'Y';
               /***************************************************************
                calling API to create category
                ****************************************************************/
               apps.inv_item_category_pub.create_category
                                     (p_api_version        => '1.0',
                                      p_init_msg_list      => apps.fnd_api.g_true,
                                      p_commit             => apps.fnd_api.g_false,
                                      x_return_status      => lv_ret_status,
                                      x_errorcode          => lv_error_code,
                                      x_msg_count          => ln_msg_count,
                                      x_msg_data           => lv_msg_data,
                                      p_category_rec       => lv_category,
                                      x_category_id        => ln_category_id
                                     );
               COMMIT;

               IF (lv_ret_status <> apps.wsh_util_core.g_ret_sts_success)
               THEN
                  FOR i IN 1 .. ln_msg_count
                  LOOP
                     lv_message := apps.fnd_msg_pub.get (i, 'F');
                     lv_message :=
                           SUBSTR (REPLACE (lv_msg_data, CHR (0), ' '), 2000);
                  END LOOP;

                  fnd_file.put_line (fnd_file.LOG,
                                     SUBSTR (   ' Error in create_category  '
                                             || lv_message,
                                             1,
                                             900
                                            )
                                    );
                  pv_retcode := SQLCODE;
                  pv_reterror := lv_message;
                  apps.fnd_msg_pub.delete_msg ();
               END IF;

               ln_msg_count := 0;
               /* START : Commented for 1.21.
                              ****************************************************
                               calling API to create valid categories
                               ****************************************************
                              apps.inv_item_category_pub.create_valid_category
                                                    (p_api_version             => '1.0',
                                                     p_init_msg_list           => apps.fnd_api.g_false,
                                                     p_commit                  => apps.fnd_api.g_true,
                                                     x_return_status           => lv_ret_status,
                                                     x_errorcode               => lv_error_code,
                                                     x_msg_count               => ln_msg_count,
                                                     x_msg_data                => lv_msg_data,
                                                     p_category_set_id         => ln_cat_set_id,
                                                     p_category_id             => ln_category_id,
                                                     p_parent_category_id      => NULL
                                                    );

                              IF (lv_ret_status <> apps.wsh_util_core.g_ret_sts_success)
                              THEN
                                 FOR i IN 1 .. ln_msg_count
                                 LOOP
                                    lv_message := apps.fnd_msg_pub.get (i, 'F');
                                    lv_message :=
                                          SUBSTR (REPLACE (lv_msg_data, CHR (0), ' '), 2000);
                                 END LOOP;

                                 fnd_file.put_line
                                              (fnd_file.LOG,
                                               SUBSTR (   ' Error in create_valid_category '
                                                       || pv_category_set
                                                       || ' / '
                                                       || lv_message,
                                                       1,
                                                       900
                                                      )
                                              );
                                 pv_retcode := SQLCODE;
                                 pv_reterror := lv_message;
                              END IF;
               */
               -- END : Commented for 1.21.
               apps.fnd_msg_pub.delete_msg ();
            EXCEPTION
               WHEN OTHERS
               THEN
                  pv_retcode := SQLCODE;
                  pv_reterror := 'Error in' || lv_pn || SQLERRM;
            END;
         -- START : Added for 1.23.
         WHEN TOO_MANY_ROWS
         THEN
            pv_retcode := SQLCODE;
            pv_reterror :=
                  'Multiple categories found for the style : '
               || gv_plm_style
               || ' in '
               || lv_pn
               || SQLERRM;
         -- END : Added for 1.23.
         WHEN OTHERS
         THEN
            pv_retcode := SQLCODE;
            pv_reterror := 'Error in' || lv_pn || SQLERRM;
      END;
   END create_category;

   /*******************************************************************************
    * Procedure/Function Name :      CREATE_PRICE
    *
    * Description              :  The purpose of this procedure to create item line for
    *                             price list.
    * INPUT Parameters         :  pv_style
    *                             pv_pricelistid
    *                             pv_uom
    *                             pv_price
    *                             pn_respid
    *                             pn_applid
    * OUTPUT Parameters        :  pv_retcode
    *                             pv_reterror
    *
    * DEVELOPMENT and MAINTENANCE HISTORY
    *
    * Date          Author             Version  Description
    * ------------  -----------------  -------  ------------------------------
    * 10-NOV-2014     INFOSYS            1.0.1    Initial Version
    *************************************************************************/
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
   )
   IS
      lv_pn                       VARCHAR2 (240)
                                        := gv_package_name || '.create_price';
      ln_price                    NUMBER;
      lv_return_status            VARCHAR2 (1)                        := NULL;
      x_msg_count                 NUMBER                                 := 0;
      x_return_status             VARCHAR2 (1)                        := NULL;
      ln_line_id                  NUMBER;
      x_msg_data                  VARCHAR2 (4000);
      lv_error_message            VARCHAR2 (4000);
      ld_begin_date               DATE;
      ld_end_date                 DATE;
      lv_structure_code           VARCHAR2 (100)
                                               := 'PRICELIST_ITEM_CATEGORIES';
      l_price_list_rec            qp_price_list_pub.price_list_rec_type;
      l_price_list_val_rec        qp_price_list_pub.price_list_val_rec_type;
      l_price_list_line_tbl       qp_price_list_pub.price_list_line_tbl_type;
      l_price_list_line_val_tbl   qp_price_list_pub.price_list_line_val_tbl_type;
      l_qualifiers_tbl            qp_qualifier_rules_pub.qualifiers_tbl_type;
      l_qualifiers_val_tbl        qp_qualifier_rules_pub.qualifiers_val_tbl_type;
      l_pricing_attr_tbl          qp_price_list_pub.pricing_attr_tbl_type;
      l_pricing_attr_val_tbl      qp_price_list_pub.pricing_attr_val_tbl_type;
      x_price_list_rec            qp_price_list_pub.price_list_rec_type;
      x_price_list_val_rec        qp_price_list_pub.price_list_val_rec_type;
      x_price_list_line_tbl       qp_price_list_pub.price_list_line_tbl_type;
      x_price_list_line_val_tbl   qp_price_list_pub.price_list_line_val_tbl_type;
      x_qualifiers_tbl            qp_qualifier_rules_pub.qualifiers_tbl_type;
      x_qualifiers_val_tbl        qp_qualifier_rules_pub.qualifiers_val_tbl_type;
      x_pricing_attr_tbl          qp_price_list_pub.pricing_attr_tbl_type;
      x_pricing_attr_val_tbl      qp_price_list_pub.pricing_attr_val_tbl_type;
      k                           NUMBER                                 := 1;
      j                           NUMBER                                 := 1;
      ln_category_id              NUMBER                              := NULL;
      ln_sys_resp_id              NUMBER           := apps.fnd_global.resp_id;
      -- W.r.t version 1.4
      ln_sys_appl_id              NUMBER           := apps.fnd_global.resp_id;
      ln_msg_count                NUMBER                                 := 0;
   -- W.r.t version 1.4
   BEGIN
      lv_error_message := NULL;
      --msg (   'After Entering create_price :: '
      --     || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
      --    );
      x_return_status := NULL;
      x_msg_count := 0;
      x_msg_data := NULL;
      pv_retcode := NULL;
      pv_reterror := NULL;
      l_price_list_rec.list_header_id := pv_pricelistid;
      l_price_list_rec.list_type_code := 'PRL';
      l_price_list_line_tbl (1).list_line_type_code := 'PLL';
      l_price_list_line_tbl (1).list_header_id := pv_pricelistid;

      IF pv_mode = 'CREATE'
      THEN
         l_price_list_line_tbl (1).operation := qp_globals.g_opr_create;
         l_price_list_line_tbl (1).list_line_id := fnd_api.g_miss_num;
         l_price_list_line_tbl (1).attribute1 := pv_brand;
         l_price_list_line_tbl (1).attribute2 := pv_current_season;
         l_pricing_attr_tbl (1).operation := qp_globals.g_opr_create;
         l_pricing_attr_tbl (1).pricing_attribute_id := fnd_api.g_miss_num;
         l_pricing_attr_tbl (1).list_line_id := fnd_api.g_miss_num;
         l_pricing_attr_tbl (1).excluder_flag := 'N';
         l_pricing_attr_tbl (1).attribute_grouping_no := 1;
         l_pricing_attr_tbl (1).price_list_line_index := 1;
      ELSE
         l_price_list_line_tbl (1).operation := apps.qp_globals.g_opr_update;
         l_price_list_line_tbl (1).list_line_id := pv_list_line_id;
         l_pricing_attr_tbl (1).operation := apps.qp_globals.g_opr_update;
         l_pricing_attr_tbl (1).pricing_attribute_id := pv_pricing_attr_id;
         l_pricing_attr_tbl (1).list_line_id := pv_list_line_id;
      END IF;

      --Start W.r.t version 1.4
      BEGIN
         SELECT responsibility_id, application_id
           INTO ln_sys_resp_id, ln_sys_appl_id
           FROM fnd_responsibility
          WHERE responsibility_key =
                                apps.fnd_profile.VALUE ('XXDO_SYS_ADMIN_RESP');
      --'SYSTEM_ADMINISTRATOR';
      EXCEPTION
         WHEN OTHERS
         THEN
            ln_sys_resp_id := apps.fnd_global.resp_id;
            ln_sys_appl_id := apps.fnd_global.prog_appl_id;
      END;

      apps.fnd_global.apps_initialize
                                 (apps.fnd_global.user_id,
                                  ln_sys_resp_id,
                                  ln_sys_appl_id
                                                --apps.fnd_global.prog_appl_id
                                 );
      --End W.r.t version 1.4
      l_price_list_line_tbl (1).operand := pn_price;
      l_price_list_line_tbl (1).arithmetic_operator := 'UNIT_PRICE';
      l_price_list_line_tbl (1).start_date_active := pv_begin_date;
      l_price_list_line_tbl (1).end_date_active := pv_end_date;
      l_price_list_line_tbl (1).organization_id := pn_org_id;
      l_pricing_attr_tbl (1).product_attribute_context := 'ITEM';

      IF gv_sku_flag = 'Y'
      THEN
         l_pricing_attr_tbl (1).product_attribute := 'PRICING_ATTRIBUTE1';
         l_price_list_line_tbl (1).product_precedence := 220;
      -- W.r.t version 1.36
      ELSE
         l_pricing_attr_tbl (1).product_attribute := 'PRICING_ATTRIBUTE2';
         l_price_list_line_tbl (1).product_precedence := 290;
      -- W.r.t version 1.36
      END IF;

      l_pricing_attr_tbl (1).product_attr_value := pv_item_id;
      l_pricing_attr_tbl (1).product_uom_code := pv_uom;
      qp_price_list_pub.process_price_list
                       (p_api_version_number           => 1,
                        p_init_msg_list                => fnd_api.g_true,
                        p_return_values                => fnd_api.g_false,
                        p_commit                       => fnd_api.g_false,
                        x_return_status                => x_return_status,
                        x_msg_count                    => ln_msg_count,
                        x_msg_data                     => x_msg_data,
                        p_price_list_rec               => l_price_list_rec,
                        p_price_list_line_tbl          => l_price_list_line_tbl,
                        p_pricing_attr_tbl             => l_pricing_attr_tbl,
                        x_price_list_rec               => x_price_list_rec,
                        x_price_list_val_rec           => x_price_list_val_rec,
                        x_price_list_line_tbl          => x_price_list_line_tbl,
                        x_qualifiers_tbl               => x_qualifiers_tbl,
                        x_qualifiers_val_tbl           => x_qualifiers_val_tbl,
                        x_pricing_attr_tbl             => x_pricing_attr_tbl,
                        x_pricing_attr_val_tbl         => x_pricing_attr_val_tbl,
                        x_price_list_line_val_tbl      => x_price_list_line_val_tbl
                       );

      /*IF x_price_list_line_tbl.COUNT > 0
      THEN
         FOR k IN 1 .. x_price_list_line_tbl.COUNT
         LOOP
            msg (('Return Status : '
                  || x_price_list_line_tbl (k).return_status
                 )
                );
            msg (('List Line id : ' || x_price_list_line_tbl (k).list_line_id
                 )
                );
         END LOOP;
      END IF;*/
      IF x_return_status = fnd_api.g_ret_sts_success
      THEN
         COMMIT;
      --msg (('Item loaded successfully into the price list')); --- Till Here
      ELSE
         fnd_file.put_line (fnd_file.LOG,
                            ('Error While Loading Item in Price List')
                           );

         FOR k IN 1 .. ln_msg_count
         LOOP
            x_msg_data := oe_msg_pub.get (p_msg_index      => k,
                                          p_encoded        => 'F');
            lv_error_message :=
               SUBSTR (   'Error in API While Loading Item in Price List : '
                       || k
                       || ' is : '
                       || x_msg_data,
                       0,
                       1000
                      );
            fnd_file.put_line
                         (fnd_file.LOG,
                          SUBSTR (   'Error While Loading Item in Price List'
                                  || lv_error_message,
                                  1,
                                  900
                                 )
                         );
         END LOOP;

         pv_retcode := 2;
         pv_reterror := SUBSTR (lv_error_message, 0, 1000);
      END IF;

      fnd_file.put_line (fnd_file.LOG,
                            'Before Leaving create_price :: '
                         || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                        );
   EXCEPTION
      WHEN OTHERS
      THEN
         pv_retcode := SQLCODE;
         pv_reterror := SQLERRM;
   END create_price;

   /*******************************************************************************
   * Procedure/Function Name :      validate_valueset
   *
   * Description              :  The purpose of this procedure to maintain the value set
   *                             values.
   * INPUT Parameters         :  pv_segment1
   *                             pv_value_set
   *                             pv_description
   * OUTPUT Parameters        :  pv_retcode
   *                             pv_reterror
   *
   * DEVELOPMENT and MAINTENANCE HISTORY
   *
   * Date          Author             Version  Description
   * ------------  -----------------  -------  ------------------------------
   * 10-NOV-2014     INFOSYS            1.0.1    Initial Version
   *************************************************************************/
   PROCEDURE validate_valueset (
      pv_segment1            VARCHAR2,
      pv_value_set           VARCHAR2,
      pv_description         VARCHAR2,
      pv_retcode       OUT   VARCHAR2,
      pv_reterror      OUT   VARCHAR2,
      pv_final_value   OUT   VARCHAR2
   )
   /***********************************************************************************
     procedure to create flex value for flex value set 'do_styles_cat' which
     internally is used as style for product family and style categories
    ***********************************************************************************/
   IS
      lv_pn                    VARCHAR2 (240)
                                   := gv_package_name || '.validate_valueset';
      ln_styleflexvalueid      NUMBER;
      ln_styleflexvaluesetid   NUMBER;
      lv_row_id                VARCHAR2 (100);
      ln_description           VARCHAR2 (1000);
      lv_flex_values           fnd_flex_values_vl%ROWTYPE;
      lv_flex_value            VARCHAR2 (150)               := NULL;
      lv_description           VARCHAR2 (1000);
   BEGIN
--****************************************
-- code for to get flex value set id
--****************************************
      BEGIN
         SELECT flex_value_set_id
           INTO ln_styleflexvaluesetid
           FROM apps.fnd_flex_value_sets
          WHERE UPPER (flex_value_set_name) = UPPER (pv_value_set);
      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            pv_retcode := SQLCODE;
            pv_reterror :=
                        pv_value_set || ' flex value not present ' || SQLERRM;
         WHEN OTHERS
         THEN
            pv_retcode := SQLCODE;
            pv_reterror :=
                  ' Error occurred while fetching flex value set id for value set '
               || pv_value_set
               || ' '
               || SQLERRM;
      END;

-- msg (' pv_value_set ' || pv_value_set || ' pv_segment1 ' || pv_segment1);
--************************************************
-- code to verify whether the style already exists
--*************************************************
      pv_final_value := NULL;

      BEGIN
         SELECT flex_value
           INTO pv_final_value
           FROM apps.fnd_flex_values_vl
          WHERE flex_value_set_id = ln_styleflexvaluesetid
            AND flex_value = TRIM (pv_segment1)
            AND NVL (enabled_flag, 'Y') = 'Y';
      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            pv_final_value := NULL;

            BEGIN
               SELECT flex_value
                 INTO pv_final_value
                 FROM apps.fnd_flex_values_vl
                WHERE flex_value_set_id = ln_styleflexvaluesetid
                  AND flex_value = TO_CHAR (TRIM (UPPER (pv_segment1)))
                  AND NVL (enabled_flag, 'Y') = 'Y';
            EXCEPTION
               WHEN NO_DATA_FOUND
               THEN
                  BEGIN
                     SELECT apps.fnd_flex_values_s.NEXTVAL
                       INTO ln_styleflexvalueid
                       FROM DUAL;

--********************************************
-- Inserting values to value set
--*****************************************
                     apps.fnd_flex_values_pkg.insert_row
                            (x_rowid                           => lv_row_id,
                             x_flex_value_id                   => ln_styleflexvalueid,
                             x_attribute_sort_order            => NULL,
                             x_flex_value_set_id               => ln_styleflexvaluesetid,
                             x_flex_value                      => UPPER
                                                                     (TRIM
                                                                         (pv_segment1
                                                                         )
                                                                     ),
                             x_enabled_flag                    => 'Y',
                             x_summary_flag                    => 'N',
                             x_start_date_active               => NULL,
                             x_end_date_active                 => NULL,
                             x_parent_flex_value_low           => NULL,
                             x_parent_flex_value_high          => NULL,
                             x_structured_hierarchy_level      => NULL,
                             x_hierarchy_level                 => NULL,
                             x_compiled_value_attributes       => NULL,
                             x_value_category                  => NULL,
                             x_attribute1                      => NULL,
                             x_attribute2                      => NULL,
                             x_attribute3                      => NULL,
                             x_attribute4                      => NULL,
                             x_attribute5                      => NULL,
                             x_attribute6                      => NULL,
                             x_attribute7                      => NULL,
                             x_attribute8                      => NULL,
                             x_attribute9                      => NULL,
                             x_attribute10                     => NULL,
                             x_attribute11                     => NULL,
                             x_attribute12                     => NULL,
                             x_attribute13                     => NULL,
                             x_attribute14                     => NULL,
                             x_attribute15                     => NULL,
                             x_attribute16                     => NULL,
                             x_attribute17                     => NULL,
                             x_attribute18                     => NULL,
                             x_attribute19                     => NULL,
                             x_attribute20                     => NULL,
                             x_attribute21                     => NULL,
                             x_attribute22                     => NULL,
                             x_attribute23                     => NULL,
                             x_attribute24                     => NULL,
                             x_attribute25                     => NULL,
                             x_attribute26                     => NULL,
                             x_attribute27                     => NULL,
                             x_attribute28                     => NULL,
                             x_attribute29                     => NULL,
                             x_attribute30                     => NULL,
                             x_attribute31                     => NULL,
                             x_attribute32                     => NULL,
                             x_attribute33                     => NULL,
                             x_attribute34                     => NULL,
                             x_attribute35                     => NULL,
                             x_attribute36                     => NULL,
                             x_attribute37                     => NULL,
                             x_attribute38                     => NULL,
                             x_attribute39                     => NULL,
                             x_attribute40                     => NULL,
                             x_attribute41                     => NULL,
                             x_attribute42                     => NULL,
                             x_attribute43                     => NULL,
                             x_attribute44                     => NULL,
                             x_attribute45                     => NULL,
                             x_attribute46                     => NULL,
                             x_attribute47                     => NULL,
                             x_attribute48                     => NULL,
                             x_attribute49                     => NULL,
                             x_attribute50                     => NULL,
                             x_flex_value_meaning              => UPPER
                                                                     (TRIM
                                                                         (pv_segment1
                                                                         )
                                                                     ),
                             x_description                     => pv_description,
                             -- lv_description,
                             x_creation_date                   => SYSDATE,
                             x_created_by                      => gn_userid,
                             x_last_update_date                => SYSDATE,
                             x_last_updated_by                 => gn_userid,
                             x_last_update_login               => apps.fnd_global.login_id
                            );
                     COMMIT;
                     pv_final_value := UPPER (TRIM (pv_segment1));
                     msg (' pv_final_value ' || pv_final_value);
                  EXCEPTION
                     WHEN OTHERS
                     THEN
                        pv_final_value := NULL;
                        pv_retcode := SQLCODE;
                        pv_reterror :=
                              'Error In validate_valueset while Creating value set '
                           || pv_value_set
                           || ' when other exception : '
                           || SQLERRM;
                        fnd_file.put_line (fnd_file.LOG, pv_reterror);
                  END;
               WHEN OTHERS
               THEN
                  pv_final_value := NULL;
                  pv_retcode := SQLCODE;
                  pv_reterror :=
                        'Error In Fetching Validation Value in Upper Case :: '
                     || SQLERRM;
            END;
         WHEN OTHERS
         THEN
            pv_final_value := NULL;
            pv_retcode := SQLCODE;
            pv_reterror := 'Error In fetching Flex Value :: ' || SQLERRM;
      END;
   END validate_valueset;

   /*************************************************************************
    * Procedure/Function Name  :  create_mtl_cross_reference
    * Description              :  This is used to create cross references.
    * INPUT Parameters :
    * OUTPUT Parameters: pv_retcode
    *                    pv_reterror
    * DEVELOPMENT and MAINTENANCE HISTORY
    *
    * date          author             Version  Description
    * ------------  -----------------  -------  ------------------------------
    * 10-NOV-2014     INFOSYS            1.0.1    Initial Version
    *************************************************************************/
   PROCEDURE create_mtl_cross_reference (
      pv_retcode    OUT   VARCHAR2,
      pv_reterror   OUT   VARCHAR2
   )
   IS
      ln_item_id          NUMBER;
      ln_org_id           NUMBER;
      ln_upc_value        VARCHAR2 (100);
      lv_exists           VARCHAR2 (1);
      ln_reference_type   VARCHAR2 (100);
      ln_reference_id     NUMBER;
      lv_upc              VARCHAR2 (100);
      ln_inv_id           NUMBER         := '-9999';

      CURSOR cross_reference_cur
      IS
         SELECT   msib1.inventory_item_id
 --    , organization_id                               -- Commented for 1.21.
                                         ,
                  mp.organization_id                    -- Modified for 1.21.
                                    ,
                  msib1.attribute11 upc_code,                          -- 1.6
                                             --      msib1.attribute13 upc_code, -- 1.6
                                             stg.*
             FROM xxdo.xxdo_plm_itemast_stg stg,
                  mtl_system_items_b msib1,
                  mtl_parameters mp                         -- Added for 1.21.
            WHERE stg.status_flag = 'S'
              AND msib1.inventory_item_id = stg.item_id
              --  AND msib1.organization_id = gn_master_orgid             -- Commented for 1.21.
              AND msib1.organization_id = mp.organization_id
              -- Modified for 1.21.
              --  START : Added for 1.21.
              AND (   mp.organization_id = gn_master_orgid
                   OR (    mp.organization_id <> gn_master_orgid
                       AND mp.attribute13 = '2'
                      )
                  )
              --  END : Added for 1.21.
              --  AND UPPER (stg.inventory_type) <> 'GENERIC'
              AND stg.stg_request_id = gn_conc_request_id
              -- AND UPPER (msib1.inventory_item_status_code) = 'ACTIVE'  -- W.r.t Version 1.32.
              AND UPPER (msib1.inventory_item_status_code) IN
                                                        ('ACTIVE', 'PLANNED')
              AND NOT EXISTS (
        --   SELECT mr.inventory_item_id                -- Commented for 1.21.
                     SELECT 1                            -- Modified for 1.21.
                       FROM apps.mtl_system_items_b msib,
                            apps.mtl_cross_references mr
                      WHERE msib.inventory_item_id = mr.inventory_item_id
                        AND msib.organization_id = mr.organization_id
                        -- Added for 1.21.
                        --  AND msib.organization_id = gn_master_orgid     -- Commented for 1.21.
                        AND msib.organization_id = mp.organization_id
                        -- Modified for 1.21.
                        AND msib.inventory_item_id = stg.item_id
                        AND msib.organization_id = msib1.organization_id
                        AND mr.cross_reference_type = 'UPC Cross Reference')
         ORDER BY item_id;
   BEGIN
      BEGIN
         SELECT cross_reference_type
           INTO ln_reference_type
           FROM apps.mtl_cross_reference_types
          WHERE cross_reference_type = 'UPC Cross Reference';
      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            pv_retcode := SQLCODE;
            pv_reterror := 'UPC Cross Reference does not exist ' || SQLERRM;
         WHEN OTHERS
         THEN
            pv_retcode := SQLCODE;
            pv_reterror :=
               'Error occured while fetching cross reference type '
               || SQLERRM;
      END;

      FOR items_cr_rec IN cross_reference_cur
      LOOP
         lv_upc := NULL;
         lv_upc := items_cr_rec.upc_code;

         IF lv_upc IS NOT NULL
         THEN
            BEGIN
               apps.mtl_cross_references_pkg.insert_row
                          (p_source_system_id            => NULL,
                           p_start_date_active           => NULL,
                           p_end_date_active             => NULL,
                           p_object_version_number       => 1,
                           p_uom_code                    => NULL,
                           p_revision_id                 => NULL,
                           p_epc_gtin_serial             => 0,
                           p_inventory_item_id           => items_cr_rec.item_id,
                           --   p_organization_id             => NULL,                -- Commented for 1.21.
                           p_organization_id             => items_cr_rec.organization_id,
                           -- Modified for 1.21.
                           p_cross_reference_type        => ln_reference_type,
                           p_cross_reference             => LPAD (lv_upc,
                                                                  14,
                                                                  0
                                                                 ),
                           p_org_independent_flag        => 'Y',
                           p_request_id                  => NULL,
                           p_attribute1                  => NULL,
                           p_attribute2                  => NULL,
                           p_attribute3                  => NULL,
                           p_attribute4                  => NULL,
                           p_attribute5                  => NULL,
                           p_attribute6                  => NULL,
                           p_attribute7                  => NULL,
                           p_attribute8                  => NULL,
                           p_attribute9                  => NULL,
                           p_attribute10                 => NULL,
                           p_attribute11                 => NULL,
                           p_attribute12                 => NULL,
                           p_attribute13                 => NULL,
                           p_attribute14                 => NULL,
                           p_attribute15                 => NULL,
                           p_attribute_category          => NULL,
                           p_description                 => NULL,
                           p_creation_date               => SYSDATE,
                           p_created_by                  => fnd_global.user_id,
                           p_last_update_date            => SYSDATE,
                           p_last_updated_by             => fnd_global.user_id,
                           p_last_update_login           => fnd_global.login_id,
                           p_program_application_id      => NULL,
                           p_program_id                  => NULL,
                           p_program_update_date         => NULL,
                           x_cross_reference_id          => ln_reference_id
                          );
               COMMIT;
            EXCEPTION
               WHEN OTHERS
               THEN
                  pv_retcode := SQLCODE;
                  pv_reterror :=
                        'Error occured while calling create reference program for Item '
                     || items_cr_rec.item_id
                     || SQLERRM;
            END;
         END IF;
      END LOOP;
   EXCEPTION
      WHEN OTHERS
      THEN
         pv_retcode := SQLCODE;
         pv_reterror :=
               'Exception occured while fetching item id in cross reference program '
            || SQLERRM;
   END;

   /*************************************************************************
   * Procedure/Function Name  :  staging_table_purging
   *
   * Description              :  This procedure is used for purging staging tables
   * INPUT Parameters :
   * OUTPUT Parameters: pv_reterror
   *                    pv_retcode
   *
   * DEVELOPMENT and MAINTENANCE HISTORY
   *
   * date          author             Version  Description
   * ------------  -----------------  -------  ------------------------------
   * 10-NOV-2014     INFOSYS            1.0.1    Initial Version
   *************************************************************************/
   PROCEDURE staging_table_purging (
      pv_reterror   OUT   VARCHAR2,
      pv_retcode    OUT   VARCHAR2
   )
   IS
      ln_err_days        NUMBER := 20;
      ln_purg_days       NUMBER := 2;
      ld_new_purg_date   DATE;
      ld_purg_date       DATE;
      ld_img_prg_date    DATE;
      PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN
      ld_purg_date :=
         TRUNC
            (  SYSDATE
             - NVL
                  (apps.fnd_profile.VALUE ('XXDO_PLM_STG_DATA_RETENTION_DAYS'),
                   0
                  )
            );
      ld_img_prg_date := TRUNC (SYSDATE - NVL (ln_err_days, 20));
      ld_new_purg_date := TRUNC (SYSDATE - NVL (ln_purg_days, 2));

      --W.r.t Version 1.25
      BEGIN
         INSERT INTO xxdo.xxdo_plm_itemast_stg_img xpsi
                     (seq_num, parent_record_id, batch_id, style,
                      master_style, scale_code_id, color_code, colorway,
                      size_val, size_scale_id, inventory_type, brand, CLASS,
                      sub_class, gender, projectedcost, landedcost,
                      purchase_cost, templateid, styledescription,
                      currentseason, begin_date, end_date, uom, cost_type,
                      country_code, factory, RANK, lead_time, user_id,
                      retail_price, wholesale_price, colorwaystatus, org_id,
                      org_code, item_id, item_number, item_status,
                      stg_request_id, status_flag, upc, buyer_id,
                      description, itemstatus, uom_code,
                      stg_transaction_type, error_message, tariff,
                      project_type, collection, item_type, supplier,
                      production_line, product_group, detail_silhouette,
                      sub_division, life_cycle, vendor_id, vendor_site_id,
                      po_item_cat_id, sourcing_flag, user_item_type,
                      creation_date, last_updated_date, created_by,
                      updated_by, purchasing_start_date, purchasing_end_date,
                      tariff_country_code, style_name)
            (SELECT seq_num, parent_record_id, batch_id, style, master_style,
                    scale_code_id, color_code, colorway, size_val,
                    size_scale_id, inventory_type, brand, CLASS, sub_class,
                    gender, projectedcost, landedcost, purchase_cost,
                    templateid, styledescription, currentseason, begin_date,
                    end_date, uom, cost_type, country_code, factory, RANK,
                    lead_time, user_id, retail_price, wholesale_price,
                    colorwaystatus, org_id, org_code, item_id, item_number,
                    item_status, stg_request_id, status_flag, upc, buyer_id,
                    description, itemstatus, uom_code, stg_transaction_type,
                    error_message, tariff, project_type, collection,
                    item_type, supplier, production_line, product_group,
                    detail_silhouette, sub_division, life_cycle, vendor_id,
                    vendor_site_id, po_item_cat_id, sourcing_flag,
                    user_item_type, creation_date, last_updated_date,
                    created_by, updated_by, purchasing_start_date,
                    purchasing_end_date, tariff_country_code, style_name
               FROM xxdo.xxdo_plm_itemast_stg xps
              WHERE TRUNC (creation_date) <= ld_new_purg_date
                AND NOT EXISTS (
                       SELECT 1
                         FROM xxdo.xxdo_plm_itemast_stg_img xpsi
                        WHERE xps.seq_num = xpsi.seq_num
                          AND xps.parent_record_id = xpsi.parent_record_id));
      EXCEPTION
         WHEN OTHERS
         THEN
            pv_retcode := 2;
            pv_reterror :=
               SUBSTR
                  (   'Exception Occured while Inserting data from xxdo.xxdo_plm_itemast_stg_img table:'
                   || SQLERRM,
                   1,
                   1999
                  );
      END;

      COMMIT;

      --  END  W.r.t Version 1.25
      BEGIN
         DELETE FROM xxdo.xxdo_plm_itemast_stg
               WHERE TRUNC (creation_date) <= ld_new_purg_date;
      EXCEPTION
         WHEN OTHERS
         THEN
            pv_retcode := 2;
            pv_reterror :=
               SUBSTR
                  (   'Exception Occured while deleting data from xxdo.xxdo_plm_itemast_stg  stg table:'
                   || SQLERRM,
                   1,
                   1999
                  );
      --RAISE;
      END;

      BEGIN
         INSERT INTO xxdo.xxdo_plm_staging_img
                     (record_id, style, colorway, sizing, style_description,
                      color_description, brand, product_group, division,
                      current_season, uom, wholesale_price, retail_price,
                      projected_cost, country_of_origin, tariff_code,
                      date_created, date_updated, sourcing_factory,
                      colorway_status, colorway_state, CLASS, style_name,
                      sub_class, master_style, collection, item_type,
                      inventory_type, purchase_cost, RANK, intro_date,
                      lead_time, landed_cost, production_line,
                      classification, supplier, begin_date, end_date,
                      project_type, benefit, planning_material_1,
                      planning_material_2, planning_material_3, plm_function,
                      lifecycle, marketing_initiatives, detail_silhouette,
                      oracle_status, request_id, attribute1,
                      purchasing_start_date, purchasing_end_date,
                      colorway_lifecycle, tariff_country_code)
            SELECT record_id, style, colorway, sizing, style_description,
                   color_description, brand, product_group, division,
                   current_season, uom, wholesale_price, retail_price,
                   projected_cost, country_of_origin, tariff_code,
                   date_created, date_updated, sourcing_factory,
                   colorway_status, colorway_state, CLASS, style_name,
                   sub_class, master_style, collection, item_type,
                   inventory_type, purchase_cost, RANK, intro_date,
                   lead_time, landed_cost, production_line, classification,
                   supplier, begin_date, end_date, project_type, benefit,
                   planning_material_1, planning_material_2,
                   planning_material_3, plm_function, lifecycle,
                   marketing_initiatives, detail_silhouette, oracle_status,
                   request_id, attribute1, purchasing_start_date,
                   purchasing_end_date, colorway_lifecycle,
                   tariff_country_code
              FROM xxdo.xxdo_plm_staging
             WHERE oracle_status = 'N' AND request_id IS NULL;
      -- Added for 1.23.
      EXCEPTION
         WHEN OTHERS
         THEN
            fnd_file.put_line
                             (fnd_file.LOG,
                              'Unable to create a image of plm staging table'
                             );
      END;

      BEGIN
         DELETE FROM xxdo.xxdo_plm_ora_errors
               WHERE TRUNC (creation_date) <= ld_purg_date;
      EXCEPTION
         WHEN OTHERS
         THEN
            pv_retcode := 2;
            pv_reterror :=
               SUBSTR
                  (   'Exception Occured while deleting data from xxdo.xxdo_plm_ora_errors table:'
                   || SQLERRM,
                   1,
                   1999
                  );
      -- RAISE;
      END;

      BEGIN
         DELETE FROM xxdo.xxdo_plm_staging_img
               WHERE TRUNC (date_created) <= ld_img_prg_date;
      EXCEPTION
         WHEN OTHERS
         THEN
            pv_retcode := 2;
            pv_reterror :=
               SUBSTR
                  (   'Exception Occured while deleting data from xxdo.XXDO_PLM_STAGING_IMG table:'
                   || SQLERRM,
                   1,
                   1999
                  );
      END;

      --  Start  W.r.t Version 1.25
      BEGIN
         DELETE FROM xxdo.xxdo_plm_itemast_stg_img
               WHERE TRUNC (creation_date) <= ld_img_prg_date;
      EXCEPTION
         WHEN OTHERS
         THEN
            pv_retcode := 2;
            pv_reterror :=
               SUBSTR
                  (   'Exception Occured while deleting data from xxdo.xxdo_plm_itemast_stg_img table:'
                   || SQLERRM,
                   1,
                   1999
                  );
      END;

      --  END  W.r.t Version 1.25
      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         pv_retcode := 2;
         pv_reterror :=
            SUBSTR (   'Exception Occured In staging_table_purging Proc'
                    || SQLERRM,
                    1,
                    1999
                   );
   -- RAISE;
   END staging_table_purging;

   /*************************************************************************
   * Procedure/Function Name  :  pre_process_validation
   *
   * Description              :  This procedure will create categories.
   * INPUT Parameters :
   *                    pv_brand_v
   *                    pv_style_v
   * OUTPUT Parameters: pv_retcode
   *                    pv_reterror
   *
   * DEVELOPMENT and MAINTENANCE HISTORY
   *
   * date          author             Version  Description
   * ------------  -----------------  -------  ------------------------------
   * 10-NOV-2014     INFOSYS            1.0.1    Initial Version
   *************************************************************************/
   PROCEDURE pre_process_validation (
      pv_brand_v    IN       VARCHAR2,
      pv_style_v    IN       VARCHAR2,
      pv_reterror   OUT      VARCHAR2,
      pv_retcode    OUT      VARCHAR2
   )
   IS
      CURSOR csr_pros_cat
      IS
         SELECT xps.*,
                DECODE (INSTR (xps.tariff_code, '/', 1),
                        0, REPLACE (xps.tariff_code, '.', ''),
                        REPLACE (SUBSTR (xps.tariff_code,
                                         1,
                                         INSTR (xps.tariff_code, '/', 1) - 1
                                        ),
                                 '.',
                                 ''
                                )
                       ) tariff
           FROM xxdo.xxdo_plm_staging xps
          WHERE request_id = gn_conc_request_id
            AND oracle_status = 'N'
            AND UPPER (xps.style) = UPPER (NVL (TRIM (pv_style_v), style))
            AND UPPER (xps.brand) = UPPER (NVL (TRIM (pv_brand_v), brand));

      CURSOR csr_region_cat (pn_record_id NUMBER)
      IS
         SELECT *
           FROM xxdo.xxdo_plm_region_stg xpr
          WHERE request_id = gn_conc_request_id
            AND parent_record_id = pn_record_id;

      CURSOR csr_size_cat (pn_record_id NUMBER)           -- W.r.t Version 1.1
      IS
         SELECT *
           FROM xxdo.xxdo_plm_size_stg xps
          WHERE xps.request_id = gn_conc_request_id
            AND parent_record_id = pn_record_id
            AND UPPER (item_type) IN ('SAMPLE')
            AND ROWNUM <= 1
         UNION
         SELECT *
           FROM xxdo.xxdo_plm_size_stg xps
          WHERE request_id = gn_conc_request_id
            AND parent_record_id = pn_record_id
            AND UPPER (item_type) IN ('B-GRADE')
            AND ROWNUM <= 1;

      ln_flexvalueid          VARCHAR2 (2);
      ln_catid                NUMBER;
      ln_wsale_pricelist_id   NUMBER;
      ln_sampprice            NUMBER;
      ln_price                NUMBER;
      ln_rtl_pricelist_id     NUMBER;
      lv_error_message        VARCHAR2 (3000);
      lv_pn                   VARCHAR2 (100)  := 'pre_process_validation';
      -- Start
      lv_brand                VARCHAR2 (150)  := NULL;
      lv_division             VARCHAR2 (150)  := NULL;
      lv_division1            VARCHAR2 (150)  := NULL;
      lv_product_group        VARCHAR2 (150)  := NULL;
      lv_class                VARCHAR2 (150)  := NULL;
      lv_sub_class            VARCHAR2 (150)  := NULL;
      lv_master_style         VARCHAR2 (150)  := NULL;
      lv_style_desc           VARCHAR2 (150)  := NULL;
      lv_style_option         VARCHAR2 (150)  := NULL;
      lv_style                VARCHAR2 (150)  := NULL;
      lv_curr_season          VARCHAR2 (150)  := NULL;
      lv_supp_ascp            VARCHAR2 (150)  := NULL;
      lv_src_factory          VARCHAR2 (150)  := NULL;
      lv_prod_line            VARCHAR2 (150)  := NULL;
      lv_tariff               VARCHAR2 (150)  := NULL;
      lv_current_season       VARCHAR2 (150)  := NULL;
      lv_project_type         VARCHAR2 (150)  := NULL;
      lv_collection           VARCHAR2 (150)  := NULL;
      lv_item_type            VARCHAR2 (150)  := NULL;
      lv_region_name          VARCHAR2 (150)  := NULL;
      lv_colorway_status      VARCHAR2 (150)  := NULL;
      lv_sub_division         VARCHAR2 (150)  := NULL;
      lv_detail_silhouette    VARCHAR2 (150)  := NULL;
      lv_user_item_type       VARCHAR2 (150)  := NULL;     --W.r.t Version 1.1
      lv_colour_code          VARCHAR2 (150)  := NULL;     --W.r.t Version 1.1
      lv_inv_item_type        VARCHAR2 (150)  := NULL;     --W.r.t Version 1.1
      lv_style_name           VARCHAR2 (150)  := NULL;     --W.r.t Version 1.9
   -- End
   BEGIN
      msg (   ' Procedure pre_process_validation starts at '
           || TO_CHAR (SYSDATE, 'DD-MM-YYYY HH24:MI:SS')
          );

      --Brand Validation
      FOR rec_pros_cat IN csr_pros_cat
      LOOP
         gv_retcode := NULL;
         gv_reterror := NULL;
         lv_division := NULL;
         lv_division1 := NULL;
         lv_brand := NULL;
         lv_product_group := NULL;
         lv_class := NULL;
         lv_sub_class := NULL;
         lv_master_style := NULL;
         lv_style_desc := NULL;
         lv_style_option := NULL;
         lv_sub_division := NULL;
         lv_detail_silhouette := NULL;
         lv_tariff := NULL;                              -- W.r.t Version 1.2
         lv_current_season := NULL;                      -- W.r.t Version 1.2
         lv_project_type := NULL;                        -- W.r.t Version 1.2
         lv_collection := NULL;                          -- W.r.t Version 1.2
         lv_item_type := NULL;                           -- W.r.t Version 1.2
         lv_region_name := NULL;                         -- W.r.t Version 1.2
         lv_colorway_status := NULL;                     -- W.r.t Version 1.2
         lv_user_item_type := NULL;                      -- W.r.t Version 1.2
         lv_colour_code := NULL;                         -- W.r.t Version 1.2
         lv_inv_item_type := NULL;                       -- W.r.t Version 1.2
         lv_style_name := NULL;                          -- W.r.t Version 1.9
         gv_plm_style := rec_pros_cat.style;                     --W.r.t 1.12
         gv_color_code := rec_pros_cat.colorway;                 --W.r.t 1.12
         gv_season := rec_pros_cat.current_season;               --W.r.t 1.12
         gn_plm_rec_id := rec_pros_cat.record_id;                --W.r.t 1.14
         gv_colorway_state := UPPER (rec_pros_cat.colorway_state);

         --W.r.t 1.14
         IF rec_pros_cat.brand IS NULL
         THEN
            gv_retcode := 2;
            gv_reterror :=
               SUBSTR
                  (   'Error Occured While updating PLM staging Table With Error When Brand Is Null'
                   || SQLERRM,
                   1,
                   1999
                  );
         END IF;

         IF rec_pros_cat.current_season IS NOT NULL        --W.r.t Version 1.6
         THEN
            BEGIN
               UPDATE xxdo.xxdo_plm_staging
                  SET attribute1 = rec_pros_cat.current_season
                WHERE record_id = rec_pros_cat.record_id;

               COMMIT;
            EXCEPTION
               WHEN OTHERS
               THEN
                  fnd_file.put_line
                     (fnd_file.LOG,
                         'Error in Updating attribute1 with Current Season :: '
                      || SQLERRM
                     );
            END;
         ELSE
            gv_reterror := ' current season column should not be blank ';
         END IF;                                           --W.r.t Version 1.6

         IF gv_retcode IS NOT NULL OR gv_reterror IS NOT NULL
         THEN
            lv_error_message :=
                           SUBSTR ('Error occurred ' || gv_reterror, 1, 1999);
            log_error_exception
                               (pv_procedure_name      => lv_pn,
                                pv_plm_row_id          => rec_pros_cat.record_id,
                                pv_style               => rec_pros_cat.style,
                                pv_color               => rec_pros_cat.colorway,
                                pv_brand               => rec_pros_cat.brand,
                                pv_gender              => rec_pros_cat.division,
                                pv_sub_group           => rec_pros_cat.sub_group,
                                pv_class               => rec_pros_cat.CLASS,
                                pv_sub_class           => rec_pros_cat.sub_class,
                                pv_master_style        => rec_pros_cat.master_style,
                                pv_reterror            => lv_error_message,
                                pv_error_code          => 'REPORT',
                                pv_error_type          => 'SYSTEM'
                               );
         END IF;

         IF    rec_pros_cat.brand IS NULL
            OR rec_pros_cat.division IS NULL
            OR rec_pros_cat.product_group IS NULL
            OR rec_pros_cat.CLASS IS NULL
            OR rec_pros_cat.sub_class IS NULL
            OR rec_pros_cat.master_style IS NULL
            OR rec_pros_cat.style IS NULL
            OR rec_pros_cat.style_name IS NULL                          -- 1.1
            OR rec_pros_cat.color_description IS NULL
         THEN
            gv_retcode := 2;
            gv_reterror :=
               SUBSTR
                  (   'One Of The Inventory Category segment doesnt has no value '
                   || SQLERRM,
                   1,
                   1999
                  );
         ELSE
            BEGIN
               -- Commented As DO_BRANDS_V is not independant value set.. Its table value set
               --validate_valueset (UPPER (rec_pros_cat.brand),
               --                   'DO_BRANDS_V',
               --                   rec_pros_cat.brand,
               --                   gv_retcode,
               --                   gv_reterror
               --                  );
               IF rec_pros_cat.colorway IS NOT NULL
               THEN
                  validate_valueset
                             (rec_pros_cat.colorway,
                              'DO_COLOR_CODE',
                              rec_pros_cat.color_description,
                              gv_retcode,
                              gv_reterror,
                              lv_division -- l_division is kept as dummy value
                             );
               END IF;

               IF rec_pros_cat.style IS NOT NULL
               THEN
                  validate_valueset
                             (rec_pros_cat.style,
                              'DO_STYLE_NUM',
                              rec_pros_cat.style,
                              gv_retcode,
                              gv_reterror,
                              lv_division -- l_division is kept as dummy value
                             );
               END IF;

               IF rec_pros_cat.brand IS NOT NULL
               THEN
                  validate_lookup_val ('DO_BRANDS',
                                       rec_pros_cat.brand,
                                       rec_pros_cat.brand,
                                       gv_retcode,
                                       gv_reterror,
                                       lv_brand
                                      );
               END IF;

               IF rec_pros_cat.division IS NOT NULL
               THEN
                  validate_valueset (rec_pros_cat.division,
                                     'DO_DIVISION_CAT',
                                     rec_pros_cat.division,
                                     gv_retcode,
                                     gv_reterror,
                                     lv_division
                                    );
               END IF;

               IF rec_pros_cat.product_group IS NOT NULL
               THEN
                  validate_valueset (rec_pros_cat.product_group,
                                     'DO_DEPARTMENT_CAT',
                                     rec_pros_cat.product_group,
                                     gv_retcode,
                                     gv_reterror,
                                     lv_product_group
                                    );
               END IF;

               IF rec_pros_cat.CLASS IS NOT NULL
               THEN
                  validate_valueset (rec_pros_cat.CLASS,
                                     'DO_CLASS_CAT',
                                     rec_pros_cat.CLASS,
                                     gv_retcode,
                                     gv_reterror,
                                     lv_class
                                    );
               END IF;

               IF rec_pros_cat.sub_class IS NOT NULL
               THEN
                  validate_valueset (rec_pros_cat.sub_class,
                                     'DO_SUBCLASS_CAT',
                                     rec_pros_cat.sub_class,
                                     gv_retcode,
                                     gv_reterror,
                                     lv_sub_class
                                    );
               END IF;

               IF rec_pros_cat.master_style IS NOT NULL
               THEN
                  validate_valueset (rec_pros_cat.master_style,
                                     'DO_MASTER_STYLE_CAT',
                                     rec_pros_cat.master_style,
                                     gv_retcode,
                                     gv_reterror,
                                     lv_master_style
                                    );
               END IF;

               IF rec_pros_cat.sub_group IS NOT NULL
               THEN
                  validate_valueset (rec_pros_cat.sub_group,
                                     'DO_SUB_DIVISION',
                                     rec_pros_cat.sub_group,
                                     gv_retcode,
                                     gv_reterror,
                                     lv_sub_division
                                    );
               END IF;

               IF rec_pros_cat.detail_silhouette IS NOT NULL
               THEN
                  validate_valueset (rec_pros_cat.detail_silhouette,
                                     'DO_DETAIL_SILHOUETTE',
                                     rec_pros_cat.detail_silhouette,
                                     gv_retcode,
                                     gv_reterror,
                                     lv_detail_silhouette
                                    );
               END IF;

               IF rec_pros_cat.color_description IS NOT NULL
               THEN
                  --START W.r.t version 1.1
                  FOR rec_size_cat IN csr_size_cat (rec_pros_cat.record_id)
                  LOOP
                     lv_colour_code := rec_pros_cat.color_description;

                     IF UPPER (rec_size_cat.item_type) = 'SAMPLE'
                     THEN
                        --lv_colour_code := lv_colour_code || '-S';  --W.r.t version 1.32
                        validate_valueset (lv_colour_code,
                                           'DO_STYLEOPTION_CAT',
                                           rec_pros_cat.color_description,
                                           gv_retcode,
                                           gv_reterror,
                                           lv_style_option
                                          );

                        IF UPPER (rec_pros_cat.product_group) <> 'FOOTWEAR'
                        THEN
                           lv_style_name := 'SS' || rec_pros_cat.style_name;
                           validate_valueset
                                          (lv_style_name, -- W.r.t version 1.1
                                           'DO_STYLE_CAT',
                                           lv_style_name, -- W.r.t version 1.1
                                           gv_retcode,
                                           gv_reterror,
                                           lv_style_desc
                                          );

                           BEGIN
                              validate_valueset    --start w.r.t Version 1.34
                                             ('SS' || rec_pros_cat.style,
                                              'DO_STYLES_CAT',
                                              rec_pros_cat.style_description,
                                              gv_retcode,
                                              gv_reterror,
                                              lv_division1
                                             );       --End w.r.t Version 1.34
                              validate_valueset
                                 ('SS' || rec_pros_cat.style,
                                  'DO_STYLE_NUM',
                                  rec_pros_cat.style,
                                  gv_retcode,
                                  gv_reterror,
                                  lv_division1
                                          -- l_division is kept as dummy value
                                 );
                           EXCEPTION
                              WHEN OTHERS
                              THEN
                                 NULL;
                           END;

                           create_inventory_category (lv_brand,
                                                      lv_division,
                                                      lv_product_group,
                                                      lv_class,
                                                      lv_sub_class,
                                                      lv_master_style,
                                                      lv_style_desc,
                                                      lv_style_option,
                                                      rec_pros_cat.colorway,
                                                      lv_sub_division,
                                                      lv_detail_silhouette,

                                                         --rec_pros_cat.style, --W.r.t Version 1.32
                                                         'SS'
                                                      || rec_pros_cat.style,
                                                      --W.r.t Version 1.32
                                                      -- 1.1
                                                      gv_retcode,
                                                      gv_reterror
                                                     );
                           create_category (lv_style_desc,
                                            NULL,
                                            NULL,
                                            NULL,
                                            NULL,
                                            'OM Sales Category',
                                            gv_retcode,
                                            gv_reterror
                                           );
                           create_category ('Trade',
                                            lv_class,
                                            --rec_pros_cat.CLASS,
                                            --rec_pros_cat.style, W.r.t version 1.1
                                            lv_style_desc, --W.r.t version 1.1
                                            NULL,
                                            NULL,
                                            'PO Item Category',
                                            gv_retcode,
                                            gv_reterror
                                           );
                        ELSIF UPPER (rec_pros_cat.product_group) = 'FOOTWEAR'
                        THEN
                           lv_style_name := 'SL' || rec_pros_cat.style_name;
                           validate_valueset
                                          (lv_style_name, -- W.r.t version 1.1
                                           'DO_STYLE_CAT',
                                           lv_style_name, -- W.r.t version 1.1
                                           gv_retcode,
                                           gv_reterror,
                                           lv_style_desc
                                          );

                           BEGIN
                              validate_valueset    --start w.r.t Version 1.34
                                             ('SL' || rec_pros_cat.style,
                                              'DO_STYLES_CAT',
                                              rec_pros_cat.style_description,
                                              gv_retcode,
                                              gv_reterror,
                                              lv_division1
                                             );       --End w.r.t Version 1.34
                              validate_valueset
                                 ('SL' || rec_pros_cat.style,
                                  'DO_STYLE_NUM',
                                  rec_pros_cat.style,
                                  gv_retcode,
                                  gv_reterror,
                                  lv_division1
                                          -- l_division is kept as dummy value
                                 );
                           EXCEPTION
                              WHEN OTHERS
                              THEN
                                 NULL;
                           END;

                           create_inventory_category (lv_brand,
                                                      lv_division,
                                                      lv_product_group,
                                                      lv_class,
                                                      lv_sub_class,
                                                      lv_master_style,
                                                      lv_style_desc,
                                                      lv_style_option,
                                                      rec_pros_cat.colorway,
                                                      lv_sub_division,
                                                      lv_detail_silhouette,

                                                         -- rec_pros_cat.style, -- W.r.t version 1.32
                                                         'SL'
                                                      || rec_pros_cat.style,
                                                      -- W.r.t version 1.32
                                                      -- 1.1
                                                      gv_retcode,
                                                      gv_reterror
                                                     );
                           create_category (lv_style_desc,
                                            NULL,
                                            NULL,
                                            NULL,
                                            NULL,
                                            'OM Sales Category',
                                            gv_retcode,
                                            gv_reterror
                                           );
                           create_category ('Trade',
                                            lv_class,
                                            -- rec_pros_cat.CLASS,
                                            --rec_pros_cat.style, W.r.t version 1.1
                                            lv_style_desc, --W.r.t version 1.1
                                            NULL,
                                            NULL,
                                            'PO Item Category',
                                            gv_retcode,
                                            gv_reterror
                                           );
                           lv_style_name := 'SR' || rec_pros_cat.style_name;
                           validate_valueset (lv_style_name,

                                              -- W.r.t version 1.1
                                              'DO_STYLE_CAT',
                                              lv_style_name,
                                              -- W.r.t version 1.1
                                              gv_retcode,
                                              gv_reterror,
                                              lv_style_desc
                                             );

                           BEGIN
                              validate_valueset    --start w.r.t Version 1.34
                                             ('SR' || rec_pros_cat.style,
                                              'DO_STYLES_CAT',
                                              rec_pros_cat.style_description,
                                              gv_retcode,
                                              gv_reterror,
                                              lv_division1
                                             );       --End w.r.t Version 1.34
                              validate_valueset
                                 ('SR' || rec_pros_cat.style,
                                  'DO_STYLE_NUM',
                                  rec_pros_cat.style,
                                  gv_retcode,
                                  gv_reterror,
                                  lv_division1
                                          -- l_division is kept as dummy value
                                 );
                           EXCEPTION
                              WHEN OTHERS
                              THEN
                                 NULL;
                           END;

                           create_inventory_category (lv_brand,
                                                      lv_division,
                                                      lv_product_group,
                                                      lv_class,
                                                      lv_sub_class,
                                                      lv_master_style,
                                                      lv_style_desc,
                                                      lv_style_option,
                                                      rec_pros_cat.colorway,
                                                      lv_sub_division,
                                                      lv_detail_silhouette,

                                                         --rec_pros_cat.style, --W.r.t version 1.32
                                                         'SR'
                                                      || rec_pros_cat.style,
                                                      --W.r.t version 1.32
                                                      -- 1.1
                                                      gv_retcode,
                                                      gv_reterror
                                                     );
                           create_category (lv_style_desc,
                                            NULL,
                                            NULL,
                                            NULL,
                                            NULL,
                                            'OM Sales Category',
                                            gv_retcode,
                                            gv_reterror
                                           );
                           create_category ('Trade',
                                            lv_class,
                                            --rec_pros_cat.CLASS,
                                            --rec_pros_cat.style, W.r.t version 1.1
                                            lv_style_desc, --W.r.t version 1.1
                                            NULL,
                                            NULL,
                                            'PO Item Category',
                                            gv_retcode,
                                            gv_reterror
                                           );
                           lv_style_name := 'SS' || rec_pros_cat.style_name;
                           validate_valueset (lv_style_name,

                                              -- W.r.t version 1.1
                                              'DO_STYLE_CAT',
                                              lv_style_name,
                                              -- W.r.t version 1.1
                                              gv_retcode,
                                              gv_reterror,
                                              lv_style_desc
                                             );
                           create_inventory_category (lv_brand,
                                                      lv_division,
                                                      lv_product_group,
                                                      lv_class,
                                                      lv_sub_class,
                                                      lv_master_style,
                                                      lv_style_desc,
                                                      lv_style_option,
                                                      rec_pros_cat.colorway,
                                                      lv_sub_division,
                                                      lv_detail_silhouette,

                                                         --rec_pros_cat.style,  W.r.t version 1.32
                                                         'SS'
                                                      || rec_pros_cat.style,
                                                      --W.r.t version 1.32
                                                      -- 1.1
                                                      gv_retcode,
                                                      gv_reterror
                                                     );
                           create_category (lv_style_desc,
                                            NULL,
                                            NULL,
                                            NULL,
                                            NULL,
                                            'OM Sales Category',
                                            gv_retcode,
                                            gv_reterror
                                           );
                           create_category ('Trade',
                                            lv_class,
                                            --rec_pros_cat.CLASS,
                                            --rec_pros_cat.style, W.r.t version 1.1
                                            lv_style_desc, --W.r.t version 1.1
                                            NULL,
                                            NULL,
                                            'PO Item Category',
                                            gv_retcode,
                                            gv_reterror
                                           );
                        END IF;
                     ELSIF UPPER (rec_size_cat.item_type) = 'B-GRADE'
                     THEN
                        --lv_colour_code := lv_colour_code || '-B';  --W.r.t version 1.32
                        validate_valueset (lv_colour_code,
                                           'DO_STYLEOPTION_CAT',
                                           rec_pros_cat.color_description,
                                           gv_retcode,
                                           gv_reterror,
                                           lv_style_option
                                          );
                        --lv_style_name := 'BG' || rec_pros_cat.style_name; --W.r.t 1.11
                        lv_style_name := rec_pros_cat.style_name; --W.r.t 1.11
                        validate_valueset (lv_style_name, -- W.r.t version 1.1
                                           'DO_STYLE_CAT',
                                           lv_style_name, -- W.r.t version 1.1
                                           gv_retcode,
                                           gv_reterror,
                                           lv_style_desc
                                          );

                        BEGIN
                           validate_valueset       --start w.r.t Version 1.34
                                             (rec_pros_cat.style,
                                              'DO_STYLES_CAT',
                                              rec_pros_cat.style_description,
                                              gv_retcode,
                                              gv_reterror,
                                              lv_division1
                                             );       --End w.r.t Version 1.34
                           validate_valueset
                              (rec_pros_cat.style,
                               'DO_STYLE_NUM',
                               rec_pros_cat.style,
                               gv_retcode,
                               gv_reterror,
                               lv_division1
                                          -- l_division is kept as dummy value
                              );
                        EXCEPTION
                           WHEN OTHERS
                           THEN
                              NULL;
                        END;

                        create_inventory_category (lv_brand,
                                                   lv_division,
                                                   lv_product_group,
                                                   lv_class,
                                                   lv_sub_class,
                                                   lv_master_style,
                                                   lv_style_desc,
                                                   lv_style_option,
                                                   rec_pros_cat.colorway,
                                                   lv_sub_division,
                                                   lv_detail_silhouette,
                                                   rec_pros_cat.style,  -- 1.1
                                                   gv_retcode,
                                                   gv_reterror
                                                  );
                        create_category (lv_style_desc,
                                         NULL,
                                         NULL,
                                         NULL,
                                         NULL,
                                         'OM Sales Category',
                                         gv_retcode,
                                         gv_reterror
                                        );
                        create_category ('Trade',
                                         lv_class,
                                         --rec_pros_cat.CLASS,
                                         --rec_pros_cat.style, W.r.t version 1.1
                                         lv_style_desc,    --W.r.t version 1.1
                                         NULL,
                                         NULL,
                                         'PO Item Category',
                                         gv_retcode,
                                         gv_reterror
                                        );
                     END IF;
                  END LOOP;

                  lv_style_name := rec_pros_cat.style_name;
                  validate_valueset (lv_style_name,

                                     -- W.r.t version 1.1
                                     'DO_STYLE_CAT',
                                     lv_style_name,
                                     -- W.r.t version 1.1
                                     gv_retcode,
                                     gv_reterror,
                                     lv_style_desc
                                    );

                  --End W.r.t Version 1.9
                  BEGIN
                     validate_valueset             --start w.r.t Version 1.34
                                             ('SS' || rec_pros_cat.style,
                                              'DO_STYLES_CAT',
                                              rec_pros_cat.style_description,
                                              gv_retcode,
                                              gv_reterror,
                                              lv_division1
                                             );       --End w.r.t Version 1.34
                     validate_valueset
                             ('SS' || rec_pros_cat.style,
                              'DO_STYLE_NUM',
                              rec_pros_cat.style,
                              gv_retcode,
                              gv_reterror,
                              lv_division1
                                          -- l_division is kept as dummy value
                             );
                  EXCEPTION
                     WHEN OTHERS
                     THEN
                        NULL;
                  END;

                  --End W.r.t version 1.1
                  lv_colour_code := rec_pros_cat.color_description;
                  validate_valueset (lv_colour_code,
                                     'DO_STYLEOPTION_CAT',
                                     rec_pros_cat.color_description,
                                     gv_retcode,
                                     gv_reterror,
                                     lv_style_option
                                    );
               END IF;

               BEGIN
                  UPDATE xxdo.xxdo_plm_staging
                     SET brand = lv_brand,
                         division = lv_division,
                         product_group = lv_product_group,
                         CLASS = lv_class,
                         sub_class = lv_sub_class,
                         master_style = lv_master_style,
                         color_description = lv_style_option,
                         sub_group = lv_sub_division,
                         detail_silhouette = lv_detail_silhouette,
                         style_name = lv_style_desc        --W.r.t Version 1.1
                   WHERE record_id = rec_pros_cat.record_id;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     fnd_file.put_line
                        (fnd_file.LOG,
                            'Error in Updating Inv Cat Values to Stg Table :: '
                         || SQLERRM
                        );
               END;

               COMMIT;
               create_inventory_category (lv_brand,
                                          lv_division,
                                          lv_product_group,
                                          lv_class,
                                          lv_sub_class,
                                          lv_master_style,
                                          lv_style_desc,
                                          lv_style_option,
                                          rec_pros_cat.colorway,
                                          lv_sub_division,
                                          lv_detail_silhouette,
                                          rec_pros_cat.style,           -- 1.1
                                          gv_retcode,
                                          gv_reterror
                                         );
            EXCEPTION
               WHEN OTHERS
               THEN
                  gv_retcode := SQLCODE;
                  gv_reterror :=
                     SUBSTR
                        (   'Exception in create inventory category for style'
                         || rec_pros_cat.master_style
                         || ' '
                         || SQLERRM,
                         1,
                         1999
                        );
            END;
         END IF;

         IF gv_retcode IS NOT NULL OR gv_reterror IS NOT NULL
         THEN
            lv_error_message :=
               SUBSTR (   'Error occured While creating inventory category'
                       || gv_reterror,
                       1,
                       1999
                      );
            log_error_exception (pv_procedure_name      => lv_pn,
                                 pv_plm_row_id          => rec_pros_cat.record_id,
                                 pv_style               => rec_pros_cat.style,
                                 pv_color               => rec_pros_cat.colorway,
                                 pv_brand               => rec_pros_cat.brand,
                                 pv_gender              => rec_pros_cat.division,
                                 pv_sub_group           => rec_pros_cat.sub_group,
                                 pv_class               => rec_pros_cat.CLASS,
                                 pv_sub_class           => rec_pros_cat.sub_class,
                                 pv_master_style        => rec_pros_cat.master_style,
                                 pv_reterror            => lv_error_message,
                                 pv_error_code          => 'REPORT',
                                 pv_error_type          => 'SYSTEM'
                                );
            gv_retcode := 1;
            gv_reterror :=
               SUBSTR (   'Error in create inventory category for style'
                       || rec_pros_cat.master_style
                       || ' '
                       || SQLERRM,
                       1,
                       1999
                      );
            COMMIT;
         END IF;

-----------------------------------------------------------
--Creating OM sales Category
-----------------------------------------------------------
         gv_retcode := NULL;
         gv_reterror := NULL;

         --IF rec_pros_cat.style IS NOT NULL
         IF rec_pros_cat.style_name IS NOT NULL
         THEN
            BEGIN
               validate_valueset (rec_pros_cat.style_name, --W.r.t version 1.1
                                  'DO_STYLE_CAT',
                                  rec_pros_cat.style_name, --W.r.t version 1.1
                                  gv_retcode,
                                  gv_reterror,
                                  lv_style
                                 );
               create_category (lv_style,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                'OM Sales Category',
                                gv_retcode,
                                gv_reterror
                               );
            EXCEPTION
               WHEN OTHERS
               THEN
                  gv_reterror :=
                     SUBSTR
                        (   'Exception occurred While creating OM Sales Category Line category'
                         || SQLERRM,
                         1,
                         1999
                        );
            END;
         END IF;

         IF gv_retcode IS NOT NULL OR gv_reterror IS NOT NULL
         THEN
            lv_error_message :=
               SUBSTR
                  (   'Error occurred while creating OM Sales Category category'
                   || gv_reterror,
                   1,
                   1999
                  );
            log_error_exception (pv_procedure_name      => lv_pn,
                                 pv_plm_row_id          => rec_pros_cat.record_id,
                                 pv_style               => rec_pros_cat.style,
                                 pv_color               => rec_pros_cat.colorway,
                                 pv_brand               => rec_pros_cat.brand,
                                 pv_gender              => rec_pros_cat.division,
                                 pv_sub_group           => rec_pros_cat.sub_group,
                                 pv_class               => rec_pros_cat.CLASS,
                                 pv_sub_class           => rec_pros_cat.sub_class,
                                 pv_master_style        => rec_pros_cat.master_style,
                                 pv_reterror            => lv_error_message,
                                 pv_error_code          => 'REPORT',
                                 pv_error_type          => 'SYSTEM'
                                );
            COMMIT;
         END IF;

-----------------------------------------------------------
--Creating QR Category
-----------------------------------------------------------
/*
         IF rec_pros_cat.colorway_state = 'ILR'
         THEN
            BEGIN
               gv_retcode := NULL;
               gv_reterror := NULL;

               IF rec_pros_cat.current_season IS NOT NULL
               THEN
                  validate_valueset (rec_pros_cat.current_season,

                                     -- UPPER (rec_pros_cat.current_season),
                                     'DO_SEASONS',
                                     rec_pros_cat.current_season,
                                     gv_retcode,
                                     gv_reterror,
                                     lv_curr_season
                                    );
               END IF;

               create_category (lv_curr_season,
                                --UPPER (rec_pros_cat.current_season),
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                'QR',
                                gv_retcode,
                                gv_reterror
                               );

               BEGIN
                  UPDATE xxdo.xxdo_plm_staging
                     SET attribute1 = rec_pros_cat.current_season,
                         current_season = lv_curr_season
                   WHERE record_id = rec_pros_cat.record_id;

                  COMMIT;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     msg ('Error in Updating Current Season :: ' || SQLERRM);
               END;

               IF gv_retcode IS NOT NULL OR gv_reterror IS NOT NULL
               THEN
                  lv_error_message :=
                     SUBSTR
                        (   'Error occurred While creating QR Category category'
                         || gv_reterror,
                         1,
                         1999
                        );
                  log_error_exception
                                (pv_procedure_name      => lv_pn,
                                 pv_plm_row_id          => rec_pros_cat.record_id,
                                 pv_style               => rec_pros_cat.style,
                                 pv_color               => rec_pros_cat.colorway,
                                 pv_brand               => rec_pros_cat.brand,
                                 pv_gender              => rec_pros_cat.division,
                                 pv_sub_group           => rec_pros_cat.sub_group,
                                 pv_class               => rec_pros_cat.CLASS,
                                 pv_sub_class           => rec_pros_cat.sub_class,
                                 pv_master_style        => rec_pros_cat.master_style,
                                 pv_reterror            => lv_error_message,
                                 pv_error_code          => 'REPORT',
                                 pv_error_type          => 'SYSTEM'
                                );
                  COMMIT;
               END IF;
            EXCEPTION
               WHEN OTHERS
               THEN
                  gv_reterror := SQLERRM;
                  lv_error_message :=
                     SUBSTR
                        (   'Error occurred While creating QR Category Line category'
                         || gv_reterror,
                         1,
                         1999
                        );
                  log_error_exception
                                (pv_procedure_name      => lv_pn,
                                 pv_plm_row_id          => rec_pros_cat.record_id,
                                 pv_style               => rec_pros_cat.style,
                                 pv_color               => rec_pros_cat.colorway,
                                 pv_brand               => rec_pros_cat.brand,
                                 pv_gender              => rec_pros_cat.division,
                                 pv_sub_group           => rec_pros_cat.sub_group,
                                 pv_class               => rec_pros_cat.CLASS,
                                 pv_sub_class           => rec_pros_cat.sub_class,
                                 pv_master_style        => rec_pros_cat.master_style,
                                 pv_reterror            => lv_error_message,
                                 pv_error_code          => 'REPORT',
                                 pv_error_type          => 'SYSTEM'
                                );
                  COMMIT;
            END;
         END IF;
*/
-----------------------------------------------------------
--Creating PRODUCTION_LINE
------------------------------------------------------------
         IF     rec_pros_cat.supplier IS NOT NULL
            AND rec_pros_cat.production_line IS NOT NULL
            AND rec_pros_cat.sourcing_factory IS NOT NULL
         THEN
            lv_supp_ascp := NULL;
            lv_src_factory := NULL;

            IF INSTR (rec_pros_cat.sourcing_factory, '-') > 0
            THEN
               BEGIN
                  /*
                     SELECT SUBSTR (rec_pros_cat.supplier,
                                    1,
                                    INSTR (rec_pros_cat.supplier, '-') - 1
                                   ),
                            SUBSTR (rec_pros_cat.supplier,
                                    INSTR (rec_pros_cat.supplier, '-') + 1,
                                    LENGTH (rec_pros_cat.supplier)
                                   )
                       INTO lv_supp_ascp,
                            lv_src_factory
                       FROM DUAL;
                       */
                  SELECT SUBSTR (rec_pros_cat.sourcing_factory,
                                 1,
                                 INSTR (rec_pros_cat.sourcing_factory, '-')
                                 - 1
                                ),
                         rec_pros_cat.sourcing_factory
                    INTO lv_supp_ascp,
                         lv_src_factory
                    FROM DUAL;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     fnd_file.put_line
                        (fnd_file.LOG,
                            'Error in Splitting Sourcing and Sourcing Factory :: '
                         || SQLERRM
                        );
               END;

               BEGIN
                  gv_retcode := NULL;
                  gv_reterror := NULL;
                  validate_valueset (lv_supp_ascp,
                                     'DO_SUPPLIER_ASCP',
                                     lv_supp_ascp,
                                     gv_retcode,
                                     gv_reterror,
                                     lv_supp_ascp
                                    );
                  validate_valueset (lv_src_factory,
                                     'DO_FACTORY_ASCP',
                                     lv_src_factory,
                                     gv_retcode,
                                     gv_reterror,
                                     lv_src_factory
                                    );
                  validate_valueset
                                 (TRIM (SUBSTR (rec_pros_cat.production_line,
                                                0,
                                                40
                                               )
                                       ),

                                  --W.r.t version 1.1

                                  --rec_pros_cat.production_line, - -W.r.t version 1.1
                                  'DO_LINE_ASCP',
                                  rec_pros_cat.production_line,
                                  gv_retcode,
                                  gv_reterror,
                                  lv_prod_line
                                 );

                  BEGIN
                     UPDATE xxdo.xxdo_plm_staging
                        SET supplier = lv_supp_ascp,
                            sourcing_factory = lv_src_factory,
                            production_line = lv_prod_line
                      WHERE record_id = rec_pros_cat.record_id;
                  EXCEPTION
                     WHEN OTHERS
                     THEN
                        fnd_file.put_line
                           (fnd_file.LOG,
                               'Error in Updating Supplier Values to Stg Table :: '
                            || SQLERRM
                           );
                  END;

                  COMMIT;

                  IF gv_retcode IS NOT NULL OR gv_reterror IS NOT NULL
                  THEN
                     lv_error_message :=
                        SUBSTR
                           (   'Error occurred While validating valuset Production Line category'
                            || gv_reterror,
                            1,
                            1999
                           );
                     log_error_exception
                                (pv_procedure_name      => lv_pn,
                                 pv_plm_row_id          => rec_pros_cat.record_id,
                                 pv_style               => rec_pros_cat.style,
                                 pv_color               => rec_pros_cat.colorway,
                                 pv_brand               => rec_pros_cat.brand,
                                 pv_gender              => rec_pros_cat.division,
                                 pv_sub_group           => rec_pros_cat.sub_group,
                                 pv_class               => rec_pros_cat.CLASS,
                                 pv_sub_class           => rec_pros_cat.sub_class,
                                 pv_master_style        => rec_pros_cat.master_style,
                                 pv_reterror            => lv_error_message,
                                 pv_error_code          => 'REPORT',
                                 pv_error_type          => 'SYSTEM'
                                );
                  END IF;

                  gv_retcode := NULL;
                  gv_reterror := NULL;
                  create_category (lv_supp_ascp,
                                   lv_src_factory,
                                   lv_prod_line,
                                   NULL,
                                   NULL,
                                   'PRODUCTION_LINE',
                                   gv_retcode,
                                   gv_reterror
                                  );

                  IF gv_retcode IS NOT NULL OR gv_reterror IS NOT NULL
                  THEN
                     lv_error_message :=
                        SUBSTR
                           (   'Error occurred While creating Production Line category'
                            || gv_reterror,
                            1,
                            1999
                           );
                     log_error_exception
                                (pv_procedure_name      => lv_pn,
                                 pv_plm_row_id          => rec_pros_cat.record_id,
                                 pv_style               => rec_pros_cat.style,
                                 pv_color               => rec_pros_cat.colorway,
                                 pv_brand               => rec_pros_cat.brand,
                                 pv_gender              => rec_pros_cat.division,
                                 pv_sub_group           => rec_pros_cat.sub_group,
                                 pv_class               => rec_pros_cat.CLASS,
                                 pv_sub_class           => rec_pros_cat.sub_class,
                                 pv_master_style        => rec_pros_cat.master_style,
                                 pv_reterror            => lv_error_message,
                                 pv_error_code          => 'REPORT',
                                 pv_error_type          => 'SYSTEM'
                                );
                  END IF;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     gv_retcode := SQLCODE;
                     gv_reterror := SQLERRM;
                     lv_error_message :=
                        SUBSTR
                           (   'Error occurred While creating Production Line category'
                            || gv_retcode
                            || ' : '
                            || gv_reterror,
                            1,
                            1999
                           );
                     log_error_exception
                                (pv_procedure_name      => lv_pn,
                                 pv_plm_row_id          => rec_pros_cat.record_id,
                                 pv_style               => rec_pros_cat.style,
                                 pv_color               => rec_pros_cat.colorway,
                                 pv_brand               => rec_pros_cat.brand,
                                 pv_gender              => rec_pros_cat.division,
                                 pv_sub_group           => rec_pros_cat.sub_group,
                                 pv_class               => rec_pros_cat.CLASS,
                                 pv_sub_class           => rec_pros_cat.sub_class,
                                 pv_master_style        => rec_pros_cat.master_style,
                                 pv_reterror            => lv_error_message,
                                 pv_error_code          => 'REPORT',
                                 pv_error_type          => 'SYSTEM'
                                );
                     COMMIT;
               END;
            ELSE
               BEGIN
                  SELECT rec_pros_cat.sourcing_factory
                    INTO lv_src_factory
                    FROM DUAL;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     fnd_file.put_line
                        (fnd_file.LOG,
                            'Error in Splitting Sourcing and Sourcing Factory :: '
                         || SQLERRM
                        );
               END;

               BEGIN
                  gv_retcode := NULL;
                  gv_reterror := NULL;
                  validate_valueset (lv_src_factory,
                                     'DO_FACTORY_ASCP',
                                     lv_src_factory,
                                     gv_retcode,
                                     gv_reterror,
                                     lv_src_factory
                                    );
                  validate_valueset
                                 (TRIM (SUBSTR (rec_pros_cat.production_line,
                                                0,
                                                40
                                               )
                                       ),

                                  -- W.r.t Version 1.1

                                  --rec_pros_cat.production_line,
                                  'DO_LINE_ASCP',
                                  rec_pros_cat.production_line,
                                  gv_retcode,
                                  gv_reterror,
                                  lv_prod_line
                                 );

                  BEGIN
                     UPDATE xxdo.xxdo_plm_staging
                        SET supplier = lv_src_factory,
                            production_line = lv_prod_line
                      WHERE record_id = rec_pros_cat.record_id;
                  EXCEPTION
                     WHEN OTHERS
                     THEN
                        fnd_file.put_line
                           (fnd_file.LOG,
                               'Error in Updating Supplier Values to Stg Table :: '
                            || SQLERRM
                           );
                  END;

                  COMMIT;

                  IF gv_retcode IS NOT NULL OR gv_reterror IS NOT NULL
                  THEN
                     lv_error_message :=
                        SUBSTR
                           (   'Error occurred While validating valuset Production Line category'
                            || gv_reterror,
                            1,
                            1999
                           );
                     log_error_exception
                                (pv_procedure_name      => lv_pn,
                                 pv_plm_row_id          => rec_pros_cat.record_id,
                                 pv_style               => rec_pros_cat.style,
                                 pv_color               => rec_pros_cat.colorway,
                                 pv_brand               => rec_pros_cat.brand,
                                 pv_gender              => rec_pros_cat.division,
                                 pv_sub_group           => rec_pros_cat.sub_group,
                                 pv_class               => rec_pros_cat.CLASS,
                                 pv_sub_class           => rec_pros_cat.sub_class,
                                 pv_master_style        => rec_pros_cat.master_style,
                                 pv_reterror            => lv_error_message,
                                 pv_error_code          => 'REPORT',
                                 pv_error_type          => 'SYSTEM'
                                );
                  END IF;

                  gv_retcode := NULL;
                  gv_reterror := NULL;
                  create_category (lv_supp_ascp,
                                   lv_src_factory,
                                   lv_prod_line,
                                   NULL,
                                   NULL,
                                   'PRODUCTION_LINE',
                                   gv_retcode,
                                   gv_reterror
                                  );

                  IF gv_retcode IS NOT NULL OR gv_reterror IS NOT NULL
                  THEN
                     lv_error_message :=
                        SUBSTR
                           (   'Error occurred While creating Production Line category'
                            || gv_reterror,
                            1,
                            1999
                           );
                     log_error_exception
                                (pv_procedure_name      => lv_pn,
                                 pv_plm_row_id          => rec_pros_cat.record_id,
                                 pv_style               => rec_pros_cat.style,
                                 pv_color               => rec_pros_cat.colorway,
                                 pv_brand               => rec_pros_cat.brand,
                                 pv_gender              => rec_pros_cat.division,
                                 pv_sub_group           => rec_pros_cat.sub_group,
                                 pv_class               => rec_pros_cat.CLASS,
                                 pv_sub_class           => rec_pros_cat.sub_class,
                                 pv_master_style        => rec_pros_cat.master_style,
                                 pv_reterror            => lv_error_message,
                                 pv_error_code          => 'REPORT',
                                 pv_error_type          => 'SYSTEM'
                                );
                  END IF;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     gv_retcode := SQLCODE;
                     gv_reterror := SQLERRM;
                     lv_error_message :=
                        SUBSTR
                           (   'Error occurred While creating Production Line category'
                            || gv_retcode
                            || ' : '
                            || gv_reterror,
                            1,
                            1999
                           );
                     log_error_exception
                                (pv_procedure_name      => lv_pn,
                                 pv_plm_row_id          => rec_pros_cat.record_id,
                                 pv_style               => rec_pros_cat.style,
                                 pv_color               => rec_pros_cat.colorway,
                                 pv_brand               => rec_pros_cat.brand,
                                 pv_gender              => rec_pros_cat.division,
                                 pv_sub_group           => rec_pros_cat.sub_group,
                                 pv_class               => rec_pros_cat.CLASS,
                                 pv_sub_class           => rec_pros_cat.sub_class,
                                 pv_master_style        => rec_pros_cat.master_style,
                                 pv_reterror            => lv_error_message,
                                 pv_error_code          => 'REPORT',
                                 pv_error_type          => 'SYSTEM'
                                );
                     COMMIT;
               END;
            END IF;
         END IF;

-----------------------------------------------------------
--Creating TARIFF CODE
------------------------------------------------------------
         IF rec_pros_cat.tariff IS NOT NULL
         THEN
            BEGIN
               gv_retcode := NULL;
               gv_reterror := NULL;
               -- Commenting as this is Table Value set based on Lookup
               --validate_valueset (rec_pros_cat.tariff,
               --                   'WSH_COMMODITY_CLASSIFICATION',
               --                   rec_pros_cat.tariff_code,
               --                   gv_retcode,
               --                   gv_reterror,
               --                   lv_tariff
               --                  );
               validate_lookup_val ('WSH_COMMODITY_CLASSIFICATION',
                                    rec_pros_cat.tariff,
                                    rec_pros_cat.tariff_code,
                                    gv_retcode,
                                    gv_reterror,
                                    lv_tariff
                                   );
               create_category (lv_tariff,              --rec_pros_cat.tariff,
                                rec_pros_cat.tariff_country_code,
                                'N',
                                NULL,
                                NULL,
                                'TARRIF CODE',
                                gv_retcode,
                                gv_reterror
                               );

               BEGIN
                  UPDATE xxdo.xxdo_plm_staging
                     SET tariff_code = lv_tariff
                   WHERE record_id = rec_pros_cat.record_id;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     fnd_file.put_line
                        (fnd_file.LOG,
                            'Error in Updating Tariff Values to Stg Table :: '
                         || SQLERRM
                        );
               END;

               COMMIT;

               IF gv_retcode IS NOT NULL OR gv_reterror IS NOT NULL
               THEN
                  lv_error_message :=
                     SUBSTR
                        (   'Error occurred While creating TARRIF CODE category'
                         || gv_retcode
                         || ' : '
                         || gv_reterror,
                         1,
                         1999
                        );
                  log_error_exception
                                (pv_procedure_name      => lv_pn,
                                 pv_plm_row_id          => rec_pros_cat.record_id,
                                 pv_style               => rec_pros_cat.style,
                                 pv_brand               => rec_pros_cat.brand,
                                 pv_color               => rec_pros_cat.colorway,
                                 pv_gender              => rec_pros_cat.division,
                                 pv_sub_group           => rec_pros_cat.sub_group,
                                 pv_class               => rec_pros_cat.CLASS,
                                 pv_sub_class           => rec_pros_cat.sub_class,
                                 pv_master_style        => rec_pros_cat.master_style,
                                 pv_reterror            => lv_error_message,
                                 pv_error_code          => 'REPORT',
                                 pv_error_type          => 'SYSTEM'
                                );
                  COMMIT;
               END IF;
            EXCEPTION
               WHEN OTHERS
               THEN
                  gv_reterror := SQLERRM;
                  gv_retcode := SQLCODE;
                  lv_error_message :=
                     SUBSTR
                        (   'Error occurred While creating TARRIF CODE category'
                         || gv_retcode
                         || ' : '
                         || gv_reterror,
                         1,
                         1999
                        );
                  log_error_exception
                                (pv_procedure_name      => lv_pn,
                                 pv_plm_row_id          => rec_pros_cat.record_id,
                                 pv_style               => rec_pros_cat.style,
                                 pv_color               => rec_pros_cat.colorway,
                                 pv_brand               => rec_pros_cat.brand,
                                 pv_gender              => rec_pros_cat.division,
                                 pv_sub_group           => rec_pros_cat.sub_group,
                                 pv_class               => rec_pros_cat.CLASS,
                                 pv_sub_class           => rec_pros_cat.sub_class,
                                 pv_master_style        => rec_pros_cat.master_style,
                                 pv_reterror            => lv_error_message,
                                 pv_error_code          => 'REPORT',
                                 pv_error_type          => 'SYSTEM'
                                );
                  COMMIT;
            END;
         END IF;

-----------------------------------------------------------
--Creating MASTER_SEASON
------------------------------------------------------------
         BEGIN
            gv_retcode := NULL;
            gv_reterror := NULL;
            validate_valueset (rec_pros_cat.current_season,
                               'DO_SEASONS',
                               rec_pros_cat.current_season,
                               gv_retcode,
                               gv_reterror,
                               lv_current_season
                              );
            create_category (lv_current_season,
                             rec_pros_cat.begin_date,
                             rec_pros_cat.end_date,
                             lv_brand,
                             'SALES',
                             'MASTER_SEASON',
                             gv_retcode,
                             gv_reterror
                            );
            create_category (lv_current_season,
                             rec_pros_cat.purchasing_start_date,
                             rec_pros_cat.purchasing_end_date,
                             lv_brand,
                             'PURCHASING',
                             'MASTER_SEASON',
                             gv_retcode,
                             gv_reterror
                            );

            BEGIN
               UPDATE xxdo.xxdo_plm_staging
                  SET attribute1 = rec_pros_cat.current_season,
                      current_season = lv_current_season
                WHERE record_id = rec_pros_cat.record_id;

               COMMIT;
            EXCEPTION
               WHEN OTHERS
               THEN
                  fnd_file.put_line
                                   (fnd_file.LOG,
                                       'Error in Updating Current Season :: '
                                    || SQLERRM
                                   );
            END;

            IF gv_retcode IS NOT NULL OR gv_reterror IS NOT NULL
            THEN
               lv_error_message :=
                  SUBSTR
                     (   'Error occurred While creating MASTER_SEASON category'
                      || gv_retcode
                      || ' : '
                      || gv_reterror,
                      1,
                      1999
                     );
               log_error_exception
                                (pv_procedure_name      => lv_pn,
                                 pv_plm_row_id          => rec_pros_cat.record_id,
                                 pv_style               => rec_pros_cat.style,
                                 pv_color               => rec_pros_cat.colorway,
                                 pv_brand               => rec_pros_cat.brand,
                                 pv_gender              => rec_pros_cat.division,
                                 pv_sub_group           => rec_pros_cat.sub_group,
                                 pv_class               => rec_pros_cat.CLASS,
                                 pv_sub_class           => rec_pros_cat.sub_class,
                                 pv_master_style        => rec_pros_cat.master_style,
                                 pv_reterror            => lv_error_message,
                                 pv_error_code          => 'REPORT',
                                 pv_error_type          => 'SYSTEM'
                                );
               COMMIT;
            END IF;
         EXCEPTION
            WHEN OTHERS
            THEN
               gv_reterror := SQLERRM;
               gv_retcode := SQLCODE;
               lv_error_message :=
                  SUBSTR
                     (   'Error occurred While creating MASTER_SEASON category'
                      || gv_retcode
                      || ' : '
                      || gv_reterror,
                      1,
                      1999
                     );
               log_error_exception
                                (pv_procedure_name      => lv_pn,
                                 pv_plm_row_id          => rec_pros_cat.record_id,
                                 pv_style               => rec_pros_cat.style,
                                 pv_color               => rec_pros_cat.colorway,
                                 pv_brand               => rec_pros_cat.brand,
                                 pv_gender              => rec_pros_cat.division,
                                 pv_sub_group           => rec_pros_cat.sub_group,
                                 pv_class               => rec_pros_cat.CLASS,
                                 pv_sub_class           => rec_pros_cat.sub_class,
                                 pv_master_style        => rec_pros_cat.master_style,
                                 pv_reterror            => lv_error_message,
                                 pv_error_code          => 'REPORT',
                                 pv_error_type          => 'SYSTEM'
                                );
               COMMIT;
         END;

-----------------------------------------------------------
--Creating PROJECT_TYPE
------------------------------------------------------------
         gv_retcode := NULL;
         gv_reterror := NULL;

         IF rec_pros_cat.project_type IS NOT NULL
         THEN
            BEGIN
               validate_valueset (rec_pros_cat.project_type,
                                  'DO_PROJECT',
                                  rec_pros_cat.project_type,
                                  gv_retcode,
                                  gv_reterror,
                                  lv_project_type
                                 );
               create_category (lv_project_type,
                                lv_current_season,
                                --UPPER (rec_pros_cat.current_season),  -- Current Season should be populated in Upper Case
                                NULL,
                                NULL,
                                NULL,
                                'PROJECT_TYPE',
                                gv_retcode,
                                gv_reterror
                               );

               BEGIN
                  UPDATE xxdo.xxdo_plm_staging
                     SET project_type = lv_project_type
                   WHERE record_id = rec_pros_cat.record_id;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     fnd_file.put_line
                        (fnd_file.LOG,
                            'Error in Updating Proj Type Values to Stg Table :: '
                         || SQLERRM
                        );
                     COMMIT;
               END;
            EXCEPTION
               WHEN OTHERS
               THEN
                  gv_reterror :=
                     SUBSTR
                        (   'Exception occurred While creating PROJECT_TYPE category'
                         || SQLCODE
                         || ' : '
                         || SQLERRM,
                         1,
                         1999
                        );
            END;
         END IF;

         IF gv_retcode IS NOT NULL OR gv_reterror IS NOT NULL
         THEN
            lv_error_message :=
               SUBSTR
                   (   'Error occurred While creating PROJECT_TYPE category'
                    || gv_retcode
                    || ' : '
                    || gv_reterror,
                    1,
                    1999
                   );
            log_error_exception (pv_procedure_name      => lv_pn,
                                 pv_plm_row_id          => rec_pros_cat.record_id,
                                 pv_style               => rec_pros_cat.style,
                                 pv_color               => rec_pros_cat.colorway,
                                 pv_brand               => rec_pros_cat.brand,
                                 pv_gender              => rec_pros_cat.division,
                                 pv_sub_group           => rec_pros_cat.sub_group,
                                 pv_class               => rec_pros_cat.CLASS,
                                 pv_sub_class           => rec_pros_cat.sub_class,
                                 pv_master_style        => rec_pros_cat.master_style,
                                 pv_reterror            => lv_error_message,
                                 pv_error_code          => 'REPORT',
                                 pv_error_type          => 'SYSTEM'
                                );
            COMMIT;
         END IF;

-----------------------------------------------------------
--Creating COLLECTION
------------------------------------------------------------
         BEGIN
            gv_retcode := NULL;
            gv_reterror := NULL;

            IF rec_pros_cat.collection IS NOT NULL
            THEN
               validate_valueset (rec_pros_cat.collection,
                                  'DO_COLLECTION',
                                  rec_pros_cat.collection,
                                  gv_retcode,
                                  gv_reterror,
                                  lv_collection
                                 );
               create_category (lv_collection,
                                lv_current_season,
                                --UPPER (rec_pros_cat.current_season),
                                NULL,
                                NULL,
                                NULL,
                                'COLLECTION',
                                gv_retcode,
                                gv_reterror
                               );

               BEGIN
                  UPDATE xxdo.xxdo_plm_staging
                     SET collection = lv_collection
                   WHERE record_id = rec_pros_cat.record_id;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     fnd_file.put_line
                        (fnd_file.LOG,
                            'Error in Updating Collection Values to Stg Table :: '
                         || SQLERRM
                        );
               END;

               COMMIT;
            ELSIF     rec_pros_cat.collection IS NULL
                  AND UPPER (rec_pros_cat.colorway_state) = 'PRODUCTION'
            THEN
               gv_reterror := ' No value found for Collection ';
            END IF;
         EXCEPTION
            WHEN OTHERS
            THEN
               gv_reterror :=
                  SUBSTR
                     (   ' Exception occurred While creating COLLECTION category'
                      || SQLCODE
                      || ' : '
                      || SQLERRM,
                      1,
                      1999
                     );
         END;

         IF gv_retcode IS NOT NULL OR gv_reterror IS NOT NULL
         THEN
            lv_error_message :=
               SUBSTR
                    (   ' Error occurred While creating COLLECTION category'
                     || gv_retcode
                     || ' : '
                     || gv_reterror,
                     1,
                     1999
                    );
            log_error_exception (pv_procedure_name      => lv_pn,
                                 pv_plm_row_id          => rec_pros_cat.record_id,
                                 pv_style               => rec_pros_cat.style,
                                 pv_color               => rec_pros_cat.colorway,
                                 pv_brand               => rec_pros_cat.brand,
                                 pv_gender              => rec_pros_cat.division,
                                 pv_sub_group           => rec_pros_cat.sub_group,
                                 pv_class               => rec_pros_cat.CLASS,
                                 pv_sub_class           => rec_pros_cat.sub_class,
                                 pv_master_style        => rec_pros_cat.master_style,
                                 pv_reterror            => lv_error_message,
                                 pv_error_code          => 'REPORT',
                                 pv_error_type          => 'SYSTEM'
                                );
            COMMIT;
         END IF;

-----------------------------------------------------------
--Creating ITEM_TYPE
------------------------------------------------------------
         BEGIN
            gv_retcode := NULL;
            gv_reterror := NULL;

            IF rec_pros_cat.item_type IS NOT NULL
            THEN
               validate_valueset (rec_pros_cat.item_type,
                                  'DO_ITEM_INV',
                                  rec_pros_cat.item_type,
                                  gv_retcode,
                                  gv_reterror,
                                  lv_item_type
                                 );
               create_category (lv_item_type,
                                lv_current_season,
                                --UPPER(rec_pros_cat.current_season),
                                NULL,
                                NULL,
                                NULL,
                                'ITEM_TYPE',
                                gv_retcode,
                                gv_reterror
                               );

               BEGIN
                  UPDATE xxdo.xxdo_plm_staging
                     SET item_type = lv_item_type
                   WHERE record_id = rec_pros_cat.record_id;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     fnd_file.put_line
                           (fnd_file.LOG,
                               'Error in Updating Item Type to Stg Table :: '
                            || SQLERRM
                           );
               END;

               COMMIT;
            END IF;
         EXCEPTION
            WHEN OTHERS
            THEN
               gv_reterror :=
                  SUBSTR
                     (   'Exception occurred While creating ITEM TYPE category'
                      || SQLCODE
                      || ' : '
                      || SQLERRM,
                      1,
                      1999
                     );
         END;

         IF gv_retcode IS NOT NULL OR gv_reterror IS NOT NULL
         THEN
            lv_error_message :=
               SUBSTR
                     (   ' Error occurred While creating ITEM_TYPE category'
                      || gv_reterror,
                      1,
                      1999
                     );
            log_error_exception (pv_procedure_name      => lv_pn,
                                 pv_plm_row_id          => rec_pros_cat.record_id,
                                 pv_style               => rec_pros_cat.style,
                                 pv_color               => rec_pros_cat.colorway,
                                 pv_brand               => rec_pros_cat.brand,
                                 pv_gender              => rec_pros_cat.division,
                                 pv_sub_group           => rec_pros_cat.sub_group,
                                 pv_class               => rec_pros_cat.CLASS,
                                 pv_sub_class           => rec_pros_cat.sub_class,
                                 pv_master_style        => rec_pros_cat.master_style,
                                 pv_reterror            => lv_error_message,
                                 pv_error_code          => 'REPORT',
                                 pv_error_type          => 'SYSTEM'
                                );
            COMMIT;
         END IF;

-----------------------------------------------------------
--Creating PO Item Category
------------------------------------------------------------
         BEGIN
            gv_retcode := NULL;
            gv_reterror := NULL;
            --IF rec_pros_cat.item_type IS NOT NULL
            --THEN
            --   validate_valueset (rec_pros_cat.item_type,
            --                      'DO_PO_ITEM_TYPE',
            --                      rec_pros_cat.item_type,
            --                      gv_retcode,
            --                      gv_reterror,
            --                      lv_item_type
            --                     );
            --END IF;

            --validate_valueset (rec_pros_cat.CLASS,
            --                   'DO_PO_ITEM_MAJOR_CATEGORY',
            --                   rec_pros_cat.CLASS,
            --                   gv_retcode,
            --                   gv_reterror
            --                  );
            --validate_valueset (rec_pros_cat.style,
            --                   'DO_PO_ITEM_MINOR_CATEGORY',
            --                   rec_pros_cat.style,
            --                   gv_retcode,
            --                   gv_reterror
            --                  );
            /*
                 validate_valueset
                         (rec_pros_cat.style, --UPPER (rec_pros_cat.style), --W.r.t version 1.1
                          'DO_STYLE_CAT',
                          rec_pros_cat.style_description, --rec_pros_cat.style_description,
                          gv_retcode,
                          gv_reterror,
                          lv_style
                         );
                     */
            create_category ('Trade',
                             lv_class,
                             --rec_pros_cat.CLASS,
                             --rec_pros_cat.style, W.r.t version 1.1
                             lv_style_desc,                --W.r.t version 1.1
                             NULL,
                             NULL,
                             'PO Item Category',
                             gv_retcode,
                             gv_reterror
                            );
         EXCEPTION
            WHEN OTHERS
            THEN
               gv_reterror :=
                  SUBSTR
                     (   ' Exception occurred While creating PO Item category '
                      || SQLCODE
                      || ' : '
                      || SQLERRM,
                      1,
                      1999
                     );
         END;

         IF gv_retcode IS NOT NULL OR gv_reterror IS NOT NULL
         THEN
            lv_error_message :=
               SUBSTR (   'Error occurred While creating stlye category'
                       || gv_reterror,
                       1,
                       1999
                      );
            log_error_exception (pv_procedure_name      => lv_pn,
                                 pv_plm_row_id          => rec_pros_cat.record_id,
                                 pv_style               => rec_pros_cat.style,
                                 pv_color               => rec_pros_cat.colorway,
                                 pv_brand               => rec_pros_cat.brand,
                                 pv_gender              => rec_pros_cat.division,
                                 pv_sub_group           => rec_pros_cat.sub_group,
                                 pv_class               => rec_pros_cat.CLASS,
                                 pv_sub_class           => rec_pros_cat.sub_class,
                                 pv_master_style        => rec_pros_cat.master_style,
                                 pv_reterror            => lv_error_message,
                                 pv_error_code          => 'REPORT',
                                 pv_error_type          => 'SYSTEM'
                                );
            COMMIT;
         END IF;

-----------------------------------------------------------
--Creating REGION
------------------------------------------------------------
         FOR rec_region_cat IN csr_region_cat (rec_pros_cat.record_id)
         LOOP
            BEGIN
               gv_retcode := NULL;
               gv_reterror := NULL;

               IF rec_region_cat.region_name IS NOT NULL
               THEN
                  validate_valueset (rec_region_cat.region_name,

                                     --UPPER (rec_region_cat.region_name),
                                     'DO_REGION',
                                     rec_region_cat.region_name,
                                     gv_retcode,
                                     gv_reterror,
                                     lv_region_name
                                    );
               END IF;

               IF rec_region_cat.colorway_status IS NOT NULL
               THEN
                  validate_valueset (rec_region_cat.colorway_status,

                                     -- UPPER (rec_region_cat.colorway_status),
                                     'DO_REGION_STATUS',
                                     rec_region_cat.colorway_status,
                                     gv_retcode,
                                     gv_reterror,
                                     lv_colorway_status
                                    );
               END IF;

               create_category (lv_region_name,
                                -- UPPER (rec_region_cat.region_name),
                                lv_colorway_status,
                                -- UPPER (rec_region_cat.colorway_status),
                                UPPER (rec_region_cat.intro_date),
                                lv_current_season,
                                --UPPER (rec_pros_cat.current_season),
                                NULL,
                                'REGION',
                                gv_retcode,
                                gv_reterror
                               );

               BEGIN
                  UPDATE xxdo.xxdo_plm_region_stg
                     SET colorway_status = lv_colorway_status,
                         region_name = lv_region_name
                   WHERE parent_record_id = rec_pros_cat.record_id;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     fnd_file.put_line
                        (fnd_file.LOG,
                            'Error in Updating Region Values to Reg Stg Table :: '
                         || SQLERRM
                        );
               END;

               COMMIT;

               IF gv_retcode IS NOT NULL OR gv_reterror IS NOT NULL
               THEN
                  lv_error_message :=
                     SUBSTR
                         (   'Error occurred While creating REGION category'
                          || gv_reterror,
                          1,
                          1999
                         );
                  log_error_exception
                                (pv_procedure_name      => lv_pn,
                                 pv_plm_row_id          => rec_pros_cat.record_id,
                                 pv_style               => rec_pros_cat.style,
                                 pv_color               => rec_pros_cat.colorway,
                                 pv_brand               => rec_pros_cat.brand,
                                 pv_gender              => rec_pros_cat.division,
                                 pv_sub_group           => rec_pros_cat.sub_group,
                                 pv_class               => rec_pros_cat.CLASS,
                                 pv_sub_class           => rec_pros_cat.sub_class,
                                 pv_master_style        => rec_pros_cat.master_style,
                                 pv_reterror            => lv_error_message,
                                 pv_error_code          => 'REPORT',
                                 pv_error_type          => 'SYSTEM'
                                );
                  COMMIT;
               END IF;
            EXCEPTION
               WHEN OTHERS
               THEN
                  gv_reterror := SQLERRM;
                  gv_retcode := SQLCODE;
                  lv_error_message :=
                     SUBSTR
                         (   'Error occurred While creating REGION category'
                          || gv_retcode
                          || ' : '
                          || gv_reterror,
                          1,
                          1999
                         );
                  log_error_exception
                                (pv_procedure_name      => lv_pn,
                                 pv_plm_row_id          => rec_pros_cat.record_id,
                                 pv_style               => rec_pros_cat.style,
                                 pv_color               => rec_pros_cat.colorway,
                                 pv_brand               => rec_pros_cat.brand,
                                 pv_gender              => rec_pros_cat.division,
                                 pv_sub_group           => rec_pros_cat.sub_group,
                                 pv_class               => rec_pros_cat.CLASS,
                                 pv_sub_class           => rec_pros_cat.sub_class,
                                 pv_master_style        => rec_pros_cat.master_style,
                                 pv_reterror            => lv_error_message,
                                 pv_error_code          => 'REPORT',
                                 pv_error_type          => 'SYSTEM'
                                );
                  COMMIT;
            END;
         END LOOP;
      END LOOP;
   EXCEPTION
      WHEN OTHERS
      THEN
         pv_retcode := SQLCODE;
         pv_reterror := SQLERRM;
         fnd_file.put_line
               (fnd_file.LOG,
                   'Unknown Exception Occurred In pre_process_validation :: '
                || SQLERRM
               );
   END pre_process_validation;

   /********************************************************************
   * PROCEDURE        : plm_insert_msii_stg                            *
   * PURPOSE          : This procedure deals with the creation         *
   *                     of items  in master item                      *
   * INPUT Parameters : pv_item_number                                 *
   *                    pv_item_desc                                   *
   *                    pv_primary_uom                                 *
   *                    pv_dimension_uom                               *
   *                    pv_org_code                                    *
   *                    pn_orgn_id                                     *
   *                    pv_record_status                               *
   * OUTPUT Parameters: xv_err_code                                    *
   *                    xv_err_msg                                     *
   *                    xn_item_id                                     *
   *                                                                   *
   * Author  Date         Ver    Description                           *
   * ------- --------    ------  -----------------------------------   *
   * Infosys 20-NOV-14     1.00    creates items in master org       *
   *                                                                   *
   ********************************************************************/
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
      pv_nrf_color_code                VARCHAR2,          --W.r.t version 1.40
      pv_nrf_description               VARCHAR2,
      pv_nrf_size_code                 VARCHAR2,
      pv_nrf_size_description          VARCHAR2,
      pv_intro_date                    VARCHAR2,
      pv_tq_sourcing_name              VARCHAR2,
      pv_disable_auto_upc              VARCHAR2,          --W.r.t version 1.47
      pv_ats_date                      VARCHAR2,          --W.r.t version 1.48
      pv_retcode                 OUT   VARCHAR2,
      pv_reterror                OUT   VARCHAR2
   )
   IS
      lv_upc        VARCHAR2 (200) := NULL;
      lv_colorway   VARCHAR2 (200) := NULL;
   BEGIN
      --IF pv_inv_type <> 'GENERIC'
      --THEN
      --   BEGIN
      --      lv_upc := TO_CHAR (apps.do_get_next_upc ());
      --   EXCEPTION
      --      WHEN OTHERS
      --      THEN
      --         lv_upc := NULL;
      --   END;
      --END IF;
      lv_colorway := pv_colorway;

      IF UPPER (pv_inv_type) = 'SAMPLE'             --start W.r.t version 1.1
      THEN
         --lv_colorway := pv_colorway || '-S';
         lv_colorway := pv_colorway;                    -- W.r.t version 1.31
      ELSIF UPPER (pv_inv_type) = 'BGRADE'
      THEN
         lv_colorway := pv_colorway;                    -- W.r.t version 1.31
      -- lv_colorway := pv_colorway || '-B';
      END IF;                                          --End W.r.t version 1.1

      INSERT INTO xxdo.xxdo_plm_itemast_stg
                  (seq_num, parent_record_id,
                   cost_type, batch_id, style, master_style,
                   scale_code_id, color_code, colorway, sub_group,
                   size_val, inventory_type, brand, product_group,
                   CLASS, sub_class, region, gender,
                   projectedcost, landedcost,
                   templateid, styledescription, currentseason,
                   uom, country_code, factory, RANK, status_flag,
                   colorwaystatus, tariff, upc, item_number,
                   purchase_cost,
                   wholesale_price, retail_price,
                   project_type, collection, item_type, supplier,
                   production_line, buyer_id, item_status,
                   size_scale_id, detail_silhouette, sub_division,
                   begin_date, end_date, lead_time,
                   life_cycle, sourcing_flag, vendor_id,
                   vendor_site_id, po_item_cat_id, user_item_type,
                   creation_date, last_updated_date, created_by, updated_by,
                   stg_request_id, purchasing_start_date,
                   purchasing_end_date, tariff_country_code,
                   style_name, nrf_color_code, nrf_description,
                   nrf_size_code, nrf_size_description, intro_date,
                   tq_sourcing_name, disable_auto_upc, ats_date
                  )
           VALUES (xxdo.xxdo_plm_itemast_stg_seq.NEXTVAL, pn_record_id,
                   pv_cost_type, pn_batch_id, pv_style, pv_master_style,
                   pn_scale_code_id, pv_color, lv_colorway, pv_subgroup,
                   pv_size, pv_inv_type, pv_brand, pv_product_group,
                   pv_class, pv_subclass, pv_region, pv_gender,
                   ROUND (pn_projectedcost, 2), ROUND (pn_landedcost, 2),
                   pv_templateid, pv_styledescription, pv_currentseason,
                   pv_uom, pv_contry_code, pv_factory, pv_rank, 'P',
                   pv_colorwaystatus, pn_tarrif, lv_upc, pv_item_number,
                   ROUND (pn_purchase_cost, 2),
                   ROUND (pn_wholesale_price, 2), ROUND (pn_retail_price, 2),
                   pv_project_type, pv_collection, pv_item_type, pv_supplier,
                   pv_production_line, pn_buyer_id, pv_item_status,
                   pv_size_scale_id, pv_detail_silhouette, pv_sub_division,
                   pv_begin_date, pv_end_date, pv_lead_time,
                   UPPER (pv_lifecycle),                  --W.r.t Version 1.23
                                        pv_sourcing_flag, pn_vendor_id,
                   pn_vendor_site_id, pn_po_item_cat_id, pv_user_item_type,
                   SYSDATE, SYSDATE, gn_userid, gn_userid,
                   gn_conc_request_id, pv_purchasing_start_date,
                   pv_purchasing_end_date, pv_tariff_country_code,
                   pv_style_name, pv_nrf_color_code, pv_nrf_description,
                   pv_nrf_size_code, pv_nrf_size_description, pv_intro_date,
                   pv_tq_sourcing_name, pv_disable_auto_upc, pv_ats_date
                  );

      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         pv_retcode := SQLCODE;
         pv_reterror :=
            SUBSTR (   'Error in plm_insert_msii_stg for item: '
                    || pv_style
                    || '-'
                    || pv_color
                    || '-'
                    || pv_size
                    || ' '
                    || SQLERRM,
                    1,
                    1999
                   );
         fnd_file.put_line (fnd_file.LOG, pv_reterror);
   END plm_insert_msii_stg;

-- ***************************************************************************
-- Procedure/Function Name  :  import_items
--
-- Description              :  The purpose of this procedure is to Import the
--                             Items from MTL_SYSTEM_ITEMS_INTERFACE standard
--                             oracle table and import the corresponding
--                             category information from
--                             MTL_ITEM_CATEGORIES_INTERFACE standard oracle
--                             table into PIM for the given organization code.
--
-- parameters               :  in_num_org_id          in : Organization Id
--                             in_num_set_process_id  in : Set Process Id
--                             out_chr_status         out :Procedure status
--
-- Return/Exit              :  N/A
--
-- DEVELOPMENT and MAINTENANCE HISTORY
--
-- date          author             Version  Description
-- ------------  -----------------  -------  --------------------------------
-- ***************************************************************************
   PROCEDURE import_items (
      in_num_org_id           IN       NUMBER,
      in_num_set_process_id   IN       NUMBER,
      in_txn_type             IN       VARCHAR2,
      out_chr_status          OUT      VARCHAR2,
      in_req_cnt              IN       NUMBER
   )
   AS
      ln_request_id      NUMBER := 0;
      ln_txn_type_code   NUMBER := 0;
      ln_user_id         NUMBER;
   BEGIN
      IF in_txn_type = 'CREATE'
      THEN
         ln_txn_type_code := 1;
      ELSIF in_txn_type = 'UPDATE'
      THEN
         ln_txn_type_code := 2;
      END IF;

      IF in_num_org_id = gn_master_orgid
      THEN
         UPDATE mtl_system_items_interface
            SET process_flag = 1
          -- transaction_type = in_txn_type --W.r.t 1.2 Fix for process flag 3 records
         WHERE  process_flag = 0
            AND organization_id = gn_master_orgid
            AND set_process_id = in_num_set_process_id;
      ELSE
         UPDATE mtl_system_items_interface msii
            SET process_flag = 1
          --  transaction_type = in_txn_type --W.r.t 1.2 Fix for process flag 3 records
         WHERE  process_flag = 0
            AND organization_id <> gn_master_orgid
            AND set_process_id = in_num_set_process_id
            AND EXISTS (
                   SELECT 1
                     FROM mtl_system_items_b msib
                    WHERE msib.segment1 = msii.item_number
                      AND msib.organization_id = gn_master_orgid);
      END IF;

      COMMIT;

      BEGIN
         BEGIN
            SELECT user_id
              INTO ln_user_id
              FROM fnd_user
             WHERE user_name = fnd_profile.VALUE ('XXDO_ADMIN_USER');
         EXCEPTION
            WHEN OTHERS
            THEN
               fnd_file.put_line (fnd_file.LOG,
                                  'Error in selecting BATCH ' || SQLERRM
                                 );
               out_chr_status := 'E';
         END;

         fnd_global.apps_initialize (ln_user_id,
                                     fnd_global.resp_id,
                                     fnd_global.resp_appl_id
                                    );
         ln_request_id :=
            fnd_request.submit_request (application      => 'INV',
                                        --Application Short Name
                                        program          => 'INCOIN',
                                        --Program Short Name
                                        sub_request      => FALSE,
                                        --No Sub Request
                                        argument1        => in_num_org_id,
                                        --organization_id
                                        argument2        => 0,
                                        --all organization, 0-indicates 'No'
                                        argument3        => 1,
                                        --validate items, 1-indicates 'Yes'
                                        argument4        => 1,
                                        --process items, 1-indicates 'Yes'
                                        argument5        => 1,
                                        --delete processed row, 0-indicates 'No',1-indicates 'Yes'
                                        argument6        => in_num_set_process_id,
                                        --set process id
                                        argument7        => ln_txn_type_code,
                                        --transaction type, 3-indicates 'SYNC'
                                        argument8        => 0
                                                          --gather status 'No'
                                       );
         COMMIT;                   -- Commiting the standard request submitted
      EXCEPTION
         WHEN OTHERS
         THEN
            fnd_file.put_line
                     (fnd_file.LOG,
                         'Exception while submitting Import Item Program :: '
                      || SQLERRM
                     );
            out_chr_status := 'E';                              --Error Status
      END;

      g_tab_temp_req (in_req_cnt).request_id := ln_request_id;

      IF ln_request_id = 0 OR ln_request_id IS NULL
      THEN
         fnd_file.put_line
                       (fnd_file.LOG,
                           'Error in submitting the request,ln_request_id = '
                        || ln_request_id
                       );
         out_chr_status := 'E';                                 --Error Status
      ELSE
         out_chr_status := 'S';
         COMMIT;
      END IF;

      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG,
                            'Exception in import_item block :: ' || SQLERRM
                           );
         out_chr_status := 'E';                                 --Error Status
   END import_items;

-- ***************************************************************************
-- Procedure/Function Name  :  xxdo_import_items
--
-- Description              :  The purpose of this procedure is to import
--                             items, UDAs
--
-- parameters               :  xn_retcd,xv_errbuf  out
--
-- Return/Exit              :  N/A
--
--
-- DEVELOPMENT and MAINTENANCE HISTORY
--
-- date          author             Version  Description
-- ------------  -----------------  -------  --------------------------------
-- 2013/06/12    Infosys            12.0.0    Initial Version
-- ***************************************************************************
   PROCEDURE xxdo_import_items (xn_retcode OUT NUMBER, xv_errbuf OUT VARCHAR2)
   AS
--------------------------------------
--        Declaration section        --
      lc_status2                   VARCHAR2 (10);
      lc_status3                   VARCHAR2 (10);
      lc_status4                   VARCHAR2 (10);
      lc_status5                   VARCHAR2 (10);
      lc_status6                   VARCHAR2 (10);
---------------------------------------
      ln_num_ci_count              NUMBER              := 0;
      lv_txn_type                  VARCHAR2 (20)       := NULL;
      ln_msi_record_count          NUMBER              := 0;
      ln_total_assign_complete     NUMBER              := 0;
      ln_total_validation_failed   NUMBER              := 0;
      ln_total_import_failed       NUMBER              := 0;
      ln_total_import_succeded     NUMBER              := 0;
      lv_error_code                NUMBER              := 0;
      lv_err_msg                   VARCHAR2 (4000)     := NULL;
      l_num_catalog_grp_id         NUMBER              := 0;
      l_req_count                  NUMBER              := 0;
      l_event_key                  VARCHAR2 (50)       := NULL;
      l_attributes                 wf_parameter_list_t;

--------------------------------------------------------
-- Getting distinct organization_id and set_process_id--
--------------------------------------------------------
      CURSOR cur_get_org_id_set_process_id (in_num_flag IN NUMBER)
      IS
         SELECT DISTINCT msii.set_process_id, msii.organization_id,
                         transaction_type
                    FROM mtl_system_items_interface msii
                   WHERE msii.confirm_status IN ('CN', 'CM')
                     AND msii.process_flag = 0
                     AND (   (    in_num_flag = 1
                              AND msii.organization_id = gn_master_orgid
                             )
                          OR (    in_num_flag = 2
                              AND msii.organization_id <> gn_master_orgid
                             )
                         );
-----------------------
--Begin Block Started--
-----------------------
   BEGIN
      --Calling import_item_categories procedure for importing Master Items
      l_req_count := 0;
      g_tab_temp_req.DELETE;

      FOR rec_get_org_id_set_process_id IN cur_get_org_id_set_process_id (1)
      LOOP
         l_req_count := l_req_count + 1;

         IF UPPER (rec_get_org_id_set_process_id.transaction_type) = 'CREATE'
         THEN
            lv_txn_type := 'CREATE';
         ELSE
            lv_txn_type := 'UPDATE';
         END IF;

         import_items (gn_master_orgid,
                       rec_get_org_id_set_process_id.set_process_id,
                       lv_txn_type,
                       lc_status2,
                       l_req_count
                      );
      END LOOP;

      IF g_tab_temp_req.COUNT > 0
      THEN
         FOR i IN g_tab_temp_req.FIRST .. g_tab_temp_req.LAST
         LOOP
            wait_for_request (g_tab_temp_req (i).request_id);
         END LOOP;
      END IF;

      BEGIN
         ln_msi_record_count := 0;
         gv_op_name := 'Getting count of Processed Master Org Items import';

         SELECT COUNT (1)
           INTO ln_msi_record_count
           FROM mtl_system_items_interface
          WHERE process_flag = 3
            AND organization_id = gn_master_orgid
            AND request_id > gn_conc_request_id;
      EXCEPTION
         WHEN OTHERS
         THEN
            ln_msi_record_count := 0;
      END;

      IF ln_msi_record_count > 0
      THEN
         UPDATE mtl_system_items_interface m1
            SET process_flag = 3
          WHERE request_id > gn_conc_request_id
            AND organization_id <> gn_master_orgid
            AND EXISTS (
                   SELECT 1
                     FROM mtl_system_items_interface m2
                    WHERE m1.segment1 = m2.segment1
                      AND m2.organization_id = gn_master_orgid
                      AND m1.process_flag = 3
                      AND m2.request_id > gn_conc_request_id);

         COMMIT;
      END IF;

      l_req_count := 0;
      g_tab_temp_req.DELETE;

      FOR rec_get_org_id_set_process_id IN cur_get_org_id_set_process_id (2)
      LOOP
         l_req_count := l_req_count + 1;

         IF UPPER (rec_get_org_id_set_process_id.transaction_type) = 'CREATE'
         THEN
            lv_txn_type := 'CREATE';
         ELSE
            lv_txn_type := 'UPDATE';
         END IF;

         import_items (rec_get_org_id_set_process_id.organization_id,
                       rec_get_org_id_set_process_id.set_process_id,
                       lv_txn_type,
                       lc_status3,
                       l_req_count
                      );

         IF lc_status3 = 'E'                                    --Error Status
         THEN
            xn_retcode := '1';
         END IF;
      END LOOP;

      IF g_tab_temp_req.COUNT > 0
      THEN
         FOR i IN g_tab_temp_req.FIRST .. g_tab_temp_req.LAST
         LOOP
            wait_for_request (g_tab_temp_req (i).request_id);
         END LOOP;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG,
                               'Error in Procedure xxdo_import_items :: '
                            || SQLERRM
                           );
   END xxdo_import_items;

--***************************************************************************
-- Procedure Name  :  xxdo_validate_and_batch
--
-- Description    :  This procedure will update batch to Items Interface table
--
-- DEVELOPMENT and MAINTENANCE HISTORY
--
-- date          author             Version  Description
-- ------------  -----------------  -------  --------------------------------
-- 06/12/2013    Infosys            12.0.0
--***************************************************************************
   PROCEDURE xxdo_validate_and_batch (
      out_chr_errbuff   OUT   VARCHAR2,
      out_num_retcode   OUT   VARCHAR2
   )
   IS
      CURSOR cur_get_master_items
      IS
         SELECT organization_code, inventory_item_id, organization_id,
                row_id, txn_type
           FROM (SELECT   msii.organization_code, NULL inventory_item_id,
                          msii.organization_id, msii.ROWID row_id,
                          'CREATE' txn_type
                     FROM mtl_system_items_interface msii
                    WHERE msii.process_flag = 0
                      AND msii.organization_id = gn_master_orgid
                      AND NOT EXISTS (
                             SELECT NULL
                               FROM mtl_system_items_b msi
                              WHERE msi.segment1 = msii.segment1
                                AND msi.organization_id = gn_master_orgid)
                 UNION ALL
                 SELECT   msii.organization_code, msib.inventory_item_id,
                          msii.organization_id, msii.ROWID row_id,
                          'UPDATE' txn_type
                     FROM mtl_system_items_interface msii,
                          mtl_system_items_b msib
                    WHERE msii.process_flag = 0
                      AND msii.organization_id = gn_master_orgid
                      AND msii.segment1 = msib.segment1
                      AND msib.organization_id = gn_master_orgid
                 ORDER BY txn_type ASC);

      rec_new_master_items_import   cur_get_master_items%ROWTYPE;

      CURSOR cur_get_child_items
      IS
         SELECT segment1, organization_code, inventory_item_id,
                organization_id, primary_uom_code, row_id, txn_type
           FROM (SELECT   msii.segment1, msii.organization_code,
                          NULL inventory_item_id, msii.organization_id,
                          msii.primary_uom_code, msii.ROWID row_id,
                          'CREATE' txn_type
                     FROM mtl_system_items_interface msii
                    WHERE msii.process_flag = 0
                      AND msii.organization_id <> gn_master_orgid
                      AND NOT EXISTS (
                             SELECT NULL
                               FROM mtl_system_items_b msi
                              WHERE msi.segment1 = msii.segment1
                                AND msi.organization_id = msii.organization_id)
                 UNION ALL
                 SELECT   msib.segment1, msii.organization_code,
                          msib.inventory_item_id, msii.organization_id,
                          msii.primary_uom_code, msii.ROWID row_id,
                          'UPDATE' txn_type
                     FROM mtl_system_items_interface msii,
                          mtl_system_items_b msib
                    WHERE msii.process_flag = 0
                      AND msii.organization_id <> gn_master_orgid
                      AND msii.segment1 = msib.segment1
                      AND msii.organization_id = msib.organization_id
                 ORDER BY organization_id, txn_type);

      rec_item_update               cur_get_child_items%ROWTYPE;

      TYPE string_array IS TABLE OF VARCHAR2 (2000)
         INDEX BY BINARY_INTEGER;

      TYPE number_array IS TABLE OF NUMBER
         INDEX BY BINARY_INTEGER;

      TYPE rowid_array IS TABLE OF ROWID
         INDEX BY BINARY_INTEGER;

      TYPE tabtype_records IS RECORD (
         organization_code   string_array,
         organization_id     number_array,
         inventory_item_id   number_array,
         segment1            string_array,
         primary_uom_code    string_array,
         row_id              rowid_array
      );

      rec_new_master_items_import   tabtype_records;
      rec_item_update               tabtype_records;
      ln_first_update_rec           NUMBER                         := 0;
      ln_count                      NUMBER                         := 0;
      lc_status1                    VARCHAR2 (1)                   := 'S';
      l_chr_organization_code       VARCHAR2 (10)                  := NULL;
      l_chr_rowid                   VARCHAR2 (3200)                := NULL;
      ln_batch_id                   NUMBER                         := 0;
      ln_loop_count                 NUMBER                         := 0;
--------------------------------
--Getting the Maximum Batch_id--
--------------------------------
   BEGIN
      BEGIN
         SELECT mtl_system_items_intf_sets_s.NEXTVAL
           INTO ln_batch_id
           FROM DUAL;
      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            ln_batch_id := 1;
         WHEN OTHERS
         THEN
            fnd_file.put_line
               (fnd_file.LOG,
                   'Error in getting the MAX(batch_id) from EGO_IMPORT_BATCHES_B table :: '
                || SQLERRM
               );
            ln_batch_id := 1;
      END;

      IF ln_batch_id >= 1
      THEN
         fnd_file.put_line
            (fnd_file.LOG,
                '****Starting Creating Batches for Master Org for Transaction Type Started at :: '
             || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
            );

         FOR rec_new_master_items_import IN cur_get_master_items
         LOOP
            out_num_retcode := '0';

            IF (    rec_new_master_items_import.txn_type = 'UPDATE'
                AND ln_first_update_rec = 0
               )
            THEN
               ln_loop_count := 0;
               ln_first_update_rec := ln_first_update_rec + 1;

               BEGIN
                  -- Changed the logic to get the correct batch_id
                  SELECT mtl_system_items_intf_sets_s.NEXTVAL
                    INTO ln_batch_id
                    FROM DUAL;
               EXCEPTION
                  WHEN NO_DATA_FOUND
                  THEN
                     ln_batch_id := 1;
                  WHEN OTHERS
                  THEN
                     fnd_file.put_line
                        (fnd_file.LOG,
                            'Error in getting the MAX(batch_id) from EGO_IMPORT_BATCHES_B table :: '
                         || SQLERRM
                        );
                     ln_batch_id := 1;
               END;
            END IF;

            IF rec_new_master_items_import.txn_type = 'CREATE'
            THEN
               BEGIN
                  UPDATE mtl_system_items_interface
                     SET set_process_id = ln_batch_id,
                         last_updated_by = gn_userid,
                         last_update_login = g_num_login_id,
                         last_update_date = SYSDATE,
                         confirm_status = 'CN',
                         transaction_type = 'CREATE'
                   WHERE ROWID = rec_new_master_items_import.row_id;
               EXCEPTION
                  WHEN NO_DATA_FOUND
                  THEN
                     NULL;
                  WHEN OTHERS
                  THEN
                     fnd_file.put_line
                        (fnd_file.LOG,
                            'Error in updating batch_id to MTL_SYSTEM_ITEMS_INTERFACE table :: '
                         || SQLERRM
                        );
               END;
            ELSIF rec_new_master_items_import.txn_type = 'UPDATE'
            THEN
               BEGIN
                  UPDATE mtl_system_items_interface
                     SET set_process_id = ln_batch_id,
                         last_updated_by = gn_userid,
                         last_update_login = g_num_login_id,
                         last_update_date = SYSDATE,
                         transaction_type = 'UPDATE',
                         confirm_status = 'CM'
                   WHERE ROWID = rec_new_master_items_import.row_id;
               EXCEPTION
                  WHEN NO_DATA_FOUND
                  THEN
                     NULL;
                  WHEN OTHERS
                  THEN
                     fnd_file.put_line
                        (fnd_file.LOG,
                            'Error in updating batch_id to MTL_SYSTEM_ITEMS_INTERFACE table :: '
                         || SQLERRM
                        );
               END;
            END IF;

--------------------------------------------------------------
--Updating the above created batch id to UDA Interface table--
--------------------------------------------------------------
            ln_loop_count := ln_loop_count + 1;

            IF ln_loop_count >= g_num_batch_count
            THEN
               ln_loop_count := 0;
               COMMIT;

               SELECT mtl_system_items_intf_sets_s.NEXTVAL
                 INTO ln_batch_id
                 FROM DUAL;
            END IF;
         END LOOP;
      END IF;

      COMMIT;                                -- Commit all the updated records
      ln_loop_count := 0;
      ln_batch_id := get_batch_id;
----------------------------------------------------------------------
-- Updating child items, whose master item is successfully imported --
----------------------------------------------------------------------
      l_chr_organization_code := '-xx';
      ln_first_update_rec := 0;

      FOR rec_item_update IN cur_get_child_items
      LOOP
         IF (   ((l_chr_organization_code <> rec_item_update.organization_code
                 )
          --                 OR (l_chr_batch_name <> rec_item_update.txn_type)
                )
             OR (MOD (ln_loop_count, g_num_batch_count) = 0)
            )
         THEN
            ln_batch_id := get_batch_id;
            l_chr_organization_code := rec_item_update.organization_code;
         END IF;

         IF rec_item_update.txn_type = 'CREATE'
         THEN
            BEGIN
               UPDATE mtl_system_items_interface
                  SET set_process_id = ln_batch_id,
                      confirm_status = 'CN',
                      last_updated_by = gn_userid,
                      last_update_login = g_num_login_id,
                      last_update_date = SYSDATE,
                      transaction_type = 'CREATE'
                WHERE ROWID = rec_item_update.row_id;
            EXCEPTION
               WHEN OTHERS
               THEN
                  fnd_file.put_line
                               (fnd_file.LOG,
                                   'Error in updating child item records :: '
                                || SQLERRM
                               );
            END;
         ELSIF rec_item_update.txn_type = 'UPDATE'
         THEN
            BEGIN
               UPDATE mtl_system_items_interface
                  SET set_process_id = ln_batch_id,
                      inventory_item_id = rec_item_update.inventory_item_id,
                      confirm_status = 'CM',
                      last_updated_by = gn_userid,
                      last_update_login = g_num_login_id,
                      last_update_date = SYSDATE,
                      transaction_type = 'UPDATE'
                WHERE ROWID = rec_item_update.row_id;
            EXCEPTION
               WHEN OTHERS
               THEN
                  fnd_file.put_line
                               (fnd_file.LOG,
                                   'Error in updating child item records :: '
                                || SQLERRM
                               );
            END;
         END IF;

         ln_loop_count := ln_loop_count + 1;

         IF MOD (ln_loop_count, g_num_batch_count) = 0
         THEN
            ln_batch_id := get_batch_id;
            COMMIT;
         END IF;
      END LOOP;

      COMMIT;                                         --Commit updated records
      fnd_file.put_line
                       (fnd_file.LOG,
                           'Processing completed: update child items, Count: '
                        || ln_loop_count
                       );
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line
              (fnd_file.LOG,
                  'Unexpected Error in Validation and Batching Procedure :: '
               || SQLERRM
              );
   END xxdo_validate_and_batch;

   /********************************************************************
   * PROCEDURE        : create_master_item                             *
   * PURPOSE          : This procedure deals with the creation         *
   *                     of items  in master org                       *
   * INPUT Parameters : pv_item_number                                 *
   *                    pv_item_desc                                   *
   *                    pv_primary_uom                                 *
   *                    pv_dimension_uom                               *
   *                    pv_org_code                                    *
   *                    pn_orgn_id                                     *
   *                    pv_record_status                               *
   * OUTPUT Parameters: xv_err_code                                    *
   *                    xv_err_msg                                     *
   *                    xn_item_id                                     *
   *                                                                   *
   * Author  Date         Ver    Description                           *
   * ------- --------    ------  -----------------------------------   *
   * Infosys 20-NOV-14     1.00    creates items in master org         *
   *                                                                   *
   ********************************************************************/
   PROCEDURE create_master_item (
      pv_item_number            IN       VARCHAR2,
      pv_item_desc              IN       VARCHAR2,
      pv_primary_uom            IN       VARCHAR2,
      pv_item_type              IN       VARCHAR2,
      pv_size_num               IN       VARCHAR2,
      pv_org_code               IN       VARCHAR2,
      pn_orgn_id                IN       NUMBER,
      pn_inv_item_id            IN       NUMBER,
      pv_buyer_code             IN       VARCHAR2,
      pv_planner_code           IN       VARCHAR2,
      pv_record_status          IN       VARCHAR2,
      pn_template_id            IN       VARCHAR2,
      pv_project_cost           IN       VARCHAR2,
      pv_style                  IN       VARCHAR2,
      pv_color_code             IN       VARCHAR2,
      pv_subdivision            IN       VARCHAR2,
      pv_det_silho              IN       VARCHAR2,
      pv_size_scale             IN       VARCHAR2,
      pv_tran_type              IN       VARCHAR2,
      pv_user_item_type         IN       VARCHAR2,
      pv_region                 IN       VARCHAR2,
      pv_brand                  IN       VARCHAR2,
      pv_department             IN       VARCHAR2,
      pv_upc                    IN       VARCHAR2,
      pv_life_cycle             IN       VARCHAR2,
      pv_scale_code_id          IN       VARCHAR2,
      pv_lead_time              IN       VARCHAR2,
      pv_current_season         IN       VARCHAR2,
      pv_drop_in_season         IN       VARCHAR2,
      -- Added by Infosys on 09Sept2016
      pv_exist_item_status      IN       VARCHAR2,
      -- Added by Infosys on 14feb2017
      pv_nrf_color_code         IN       VARCHAR2,
      pv_nrf_description        IN       VARCHAR2,
      pv_nrf_size_code          IN       VARCHAR2,
      pv_nrf_size_description   IN       VARCHAR2,
      pv_intro_season           IN       VARCHAR2,       -- W.r.t version 1.42
      pv_intro_date             IN       VARCHAR2,       -- W.r.t version 1.42
      pv_disable_auto_upc       IN       VARCHAR2,       -- W.r.t version 1.47
      pv_ats_date               IN       VARCHAR2,       -- W.r.t version 1.48
      xv_err_code               OUT      VARCHAR2,
      xv_err_msg                OUT      VARCHAR2,
      xn_item_id                OUT      NUMBER,
      pv_item_class             IN       VARCHAR2 DEFAULT NULL, -- 1.51
      pv_item_subclass          IN       VARCHAR2 DEFAULT NULL-- 1.51
   )
   AS
      x_return_status          VARCHAR2 (1);
      x_msg_count              NUMBER (10);
      x_msg_data               VARCHAR2 (1000);
      x_message_list           error_handler.error_tbl_type;
      ltab_item                ego_item_pub.item_tbl_type;
      ln_inventory_item_id     VARCHAR2 (1000)              := NULL;
      lv_pn                    VARCHAR2 (1000)              := NULL;
      ln_error_code            NUMBER;
      lv_msg_data              VARCHAR2 (1000)              := NULL;
      l_item_table             ego_item_pub.item_tbl_type;
      x_item_table             ego_item_pub.item_tbl_type;
      lv_error_message         VARCHAR2 (4000)              := NULL;
      lv_template_name         VARCHAR2 (1000)              := NULL;
      ln_template_id           NUMBER;
      lv_buyer_code            VARCHAR2 (100)               := NULL;
      ln_buyer_id              NUMBER;
      lv_lead_time             VARCHAR2 (100)               := NULL;
      lv_planner_code          VARCHAR2 (100)               := NULL;
      ln_valid_planer          VARCHAR2 (100)               := NULL;
      ln_lead_time             NUMBER;
      lv_item_status           VARCHAR2 (100);
      lv_jap_org_exists        VARCHAR2 (100);
      lv_from_curr             VARCHAR2 (100);
      lv_conv_type             VARCHAR2 (500);
      ln_project_cost          NUMBER;
      lv_confirm_status        VARCHAR2 (20)                := NULL;
      lv_upc                   VARCHAR2 (150)               := NULL;
      ln_cost_acct             NUMBER;
      ln_sales_acct            NUMBER;
      ln_cost_new_ccid         NUMBER;
      ln_sales_new_ccid        NUMBER;
      lv_current_season        VARCHAR2 (150)               := NULL;
      lv_brand_id              VARCHAR2 (150)               := NULL;
      lv_season_month          VARCHAR2 (150)               := NULL;
      lv_season_year           VARCHAR2 (150)               := NULL;
      lv_season_name           VARCHAR2 (150)               := NULL;
      lv_mat_overhead          VARCHAR2 (150)          := 'Material Overhead';
      ln_count_item_cost       NUMBER                       := -1;
      lv_item_type             VARCHAR2 (150)               := NULL;   -- 1.1
      ln_transit_days_air      NUMBER                       := 0;      -- 1.7
      ln_transit_days_ocean    NUMBER                       := 0;      -- 1.7
      lv_country               VARCHAR2 (150)               := NULL;   -- 1.7
      ln_full_lead_time        NUMBER                       := 0;      -- 1.7
      ln_cum_total_lead_time   NUMBER                       := 0;      -- 1.7
      lv_is_carry_over         VARCHAR2 (1)                 := 'N';
      -- Added for 1.22.
      lv_is_lead_time_org      VARCHAR2 (1)                 := 'N';
      -- Added for 1.22.

      -- START : Added for 1.23.
      ln_pln_fenc_days         NUMBER;
      ln_pln_fenc_code         NUMBER;
      -- END : Added for 1.23.
      ln_add_cum_lead_time     NUMBER                       := 0;     -- 1.29
      lv_org_inc_org           VARCHAR2 (150)               := 'N';
      lv_inv_item_status       VARCHAR2 (150)               := 'PLANNED';
      lv_drop_in_season        VARCHAR2 (150);
      lv_item_desc             VARCHAR2 (200);
      ld_intro_date            VARCHAR2 (200);
      lv_intro_season_date     VARCHAR2 (200)               := NULL;  -- 1.42
      lv_ats_date              VARCHAR2 (200)               := NULL;  -- 1.47
   -- Added by Infosys on 09Sept2016
     ln_pop_template_id    NUMBER:=NULL; --1.51
   BEGIN
      msg (   'After Entering create_master_item :: '
           || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
          );
      lv_item_desc := pv_item_desc;
      --1.51 changes start
      -- query to fetch POP item template
      BEGIN
      SELECT
    ffvl.attribute5 --item_template
    INTO ln_pop_template_id
FROM
    apps.fnd_flex_value_sets   fvs,
    apps.fnd_flex_values_vl    ffvl
WHERE
    fvs.flex_value_set_id = ffvl.flex_value_set_id
    AND fvs.flex_value_set_name = 'XXD_INV_POP_ITEM_TEMPLATE_VS'
    AND nvl(trunc(ffvl.start_date_active), trunc(SYSDATE)) <= trunc(SYSDATE)
    AND nvl(trunc(ffvl.end_date_active), trunc(SYSDATE)) >= trunc(SYSDATE)
    AND ffvl.enabled_flag = 'Y'
        AND  attribute1 = pv_subdivision   -- Division
            AND attribute2 = pv_department -- department
            AND attribute3 =   pv_item_class    -- class
            AND attribute4 = pv_item_subclass;      -- sub class
EXCEPTION WHEN NO_DATA_FOUND THEN
BEGIN
 SELECT
    ffvl.attribute5 --item_template
    INTO ln_pop_template_id
FROM
    apps.fnd_flex_value_sets   fvs,
    apps.fnd_flex_values_vl    ffvl
WHERE
    fvs.flex_value_set_id = ffvl.flex_value_set_id
    AND fvs.flex_value_set_name = 'XXD_INV_POP_ITEM_TEMPLATE_VS'
    AND nvl(trunc(ffvl.start_date_active), trunc(SYSDATE)) <= trunc(SYSDATE)
    AND nvl(trunc(ffvl.end_date_active), trunc(SYSDATE)) >= trunc(SYSDATE)
    AND ffvl.enabled_flag = 'Y'
        AND  attribute1 IS NULL   -- Division
            AND attribute2 = pv_department -- department
            AND attribute3 =   pv_item_class    -- class
            AND attribute4 = pv_item_subclass;      -- sub class
EXCEPTION WHEN NO_DATA_FOUND THEN
BEGIN
 SELECT
    ffvl.attribute5 --item_template
    INTO ln_pop_template_id
FROM
    apps.fnd_flex_value_sets   fvs,
    apps.fnd_flex_values_vl    ffvl
WHERE
    fvs.flex_value_set_id = ffvl.flex_value_set_id
    AND fvs.flex_value_set_name = 'XXD_INV_POP_ITEM_TEMPLATE_VS'
    AND nvl(trunc(ffvl.start_date_active), trunc(SYSDATE)) <= trunc(SYSDATE)
    AND nvl(trunc(ffvl.end_date_active), trunc(SYSDATE)) >= trunc(SYSDATE)
    AND ffvl.enabled_flag = 'Y'
        AND  attribute1 = pv_subdivision   -- Division
            AND attribute2 = pv_department -- department
            AND attribute3 IS   NULL    -- class
            AND attribute4 = pv_item_subclass;      -- sub class
            EXCEPTION WHEN NO_DATA_FOUND THEN
BEGIN
 SELECT
    ffvl.attribute5 --item_template
    INTO ln_pop_template_id
FROM
    apps.fnd_flex_value_sets   fvs,
    apps.fnd_flex_values_vl    ffvl
WHERE
    fvs.flex_value_set_id = ffvl.flex_value_set_id
    AND fvs.flex_value_set_name = 'XXD_INV_POP_ITEM_TEMPLATE_VS'
    AND nvl(trunc(ffvl.start_date_active), trunc(SYSDATE)) <= trunc(SYSDATE)
    AND nvl(trunc(ffvl.end_date_active), trunc(SYSDATE)) >= trunc(SYSDATE)
    AND ffvl.enabled_flag = 'Y'
        AND  attribute1 = pv_subdivision   -- Division
            AND attribute2 = pv_department -- department
            AND attribute3 =   pv_item_class    -- class
            AND attribute4 IS NULL;      -- sub class
EXCEPTION WHEN NO_DATA_FOUND THEN
BEGIN
 SELECT
    ffvl.attribute5 --item_template
    INTO ln_pop_template_id
FROM
    apps.fnd_flex_value_sets   fvs,
    apps.fnd_flex_values_vl    ffvl
WHERE
    fvs.flex_value_set_id = ffvl.flex_value_set_id
    AND fvs.flex_value_set_name = 'XXD_INV_POP_ITEM_TEMPLATE_VS'
    AND nvl(trunc(ffvl.start_date_active), trunc(SYSDATE)) <= trunc(SYSDATE)
    AND nvl(trunc(ffvl.end_date_active), trunc(SYSDATE)) >= trunc(SYSDATE)
    AND ffvl.enabled_flag = 'Y'
        AND  attribute1 IS NULL   -- Division
            AND attribute2 = pv_department -- department
            AND attribute3 IS NULL    -- class
            AND attribute4 = pv_item_subclass;      -- sub class
            EXCEPTION WHEN NO_DATA_FOUND THEN
BEGIN
 SELECT
    ffvl.attribute5 --item_template
    INTO ln_pop_template_id
FROM
    apps.fnd_flex_value_sets   fvs,
    apps.fnd_flex_values_vl    ffvl
WHERE
    fvs.flex_value_set_id = ffvl.flex_value_set_id
    AND fvs.flex_value_set_name = 'XXD_INV_POP_ITEM_TEMPLATE_VS'
    AND nvl(trunc(ffvl.start_date_active), trunc(SYSDATE)) <= trunc(SYSDATE)
    AND nvl(trunc(ffvl.end_date_active), trunc(SYSDATE)) >= trunc(SYSDATE)
    AND ffvl.enabled_flag = 'Y'
        AND  attribute1 IS NULL   -- Division
            AND attribute2 = pv_department -- department
            AND attribute3 = pv_item_class    -- class
            AND attribute4 IS NULL;      -- sub class
    EXCEPTION WHEN NO_DATA_FOUND THEN
BEGIN
 SELECT
    ffvl.attribute5 --item_template
    INTO ln_pop_template_id
FROM
    apps.fnd_flex_value_sets   fvs,
    apps.fnd_flex_values_vl    ffvl
WHERE
    fvs.flex_value_set_id = ffvl.flex_value_set_id
    AND fvs.flex_value_set_name = 'XXD_INV_POP_ITEM_TEMPLATE_VS'
    AND nvl(trunc(ffvl.start_date_active), trunc(SYSDATE)) <= trunc(SYSDATE)
    AND nvl(trunc(ffvl.end_date_active), trunc(SYSDATE)) >= trunc(SYSDATE)
    AND ffvl.enabled_flag = 'Y'
        AND  attribute1 = pv_subdivision   -- Division
            AND attribute2 = pv_department -- department
            AND attribute3 IS NULL    -- class
            AND attribute4 IS NULL;      -- sub class
    EXCEPTION WHEN NO_DATA_FOUND THEN
BEGIN
 SELECT
    ffvl.attribute5 --item_template
    INTO ln_pop_template_id
FROM
    apps.fnd_flex_value_sets   fvs,
    apps.fnd_flex_values_vl    ffvl
WHERE
    fvs.flex_value_set_id = ffvl.flex_value_set_id
    AND fvs.flex_value_set_name = 'XXD_INV_POP_ITEM_TEMPLATE_VS'
    AND nvl(trunc(ffvl.start_date_active), trunc(SYSDATE)) <= trunc(SYSDATE)
    AND nvl(trunc(ffvl.end_date_active), trunc(SYSDATE)) >= trunc(SYSDATE)
    AND ffvl.enabled_flag = 'Y'
        AND  attribute1 IS NULL   -- Division
            AND attribute2 = pv_department -- department
            AND attribute3 IS NULL    -- class
            AND attribute4 IS NULL;      -- sub class
EXCEPTION WHEN OTHERS THEN
ln_pop_template_id:=NULL;
END;
END;
END;
END;
END;
END;
END;
END;


--1.51 changes end
--***********************
-- FETCHING TEMPLATE ID
--************************
      IF     pv_color_code = 'CUSTOM'              -- start W.r.t Version 1.17
         AND pv_org_code = gn_master_org_code               -- Added for 1.22.
      THEN
         BEGIN
            SELECT description
              INTO lv_template_name
              FROM fnd_lookup_values_vl
             WHERE lookup_type = 'DO_ORG_TEMPLATE_ASSIGNMENT'
               AND (   attribute1 = pv_life_cycle
                    OR attribute2 = pv_life_cycle
                    OR attribute3 = pv_life_cycle
                   )
               AND attribute4 = pv_org_code
               AND tag = 'CUSTOM'
               AND NVL (enabled_flag, 'Y') = 'Y';
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               lv_template_name := NULL;
               xv_err_msg :=
                     ' Template not configured in the lookup DO_ORG_TEMPLATE_ASSIGNMENT for item '
                  || pv_item_number
                  || ' life Cycle: '
                  || pv_life_cycle
                  || ' Org Id: '
                  || pv_org_code
                  || ' Item Type: '
                  || pv_user_item_type;
               fnd_file.put_line (fnd_file.LOG, xv_err_msg);
               xv_err_code := 1;
            WHEN OTHERS
            THEN
               lv_template_name := NULL;
               xv_err_msg :=
                     ' Error while fetching Template in the lookup DO_ORG_TEMPLATE_ASSIGNMENT for Item '
                  || pv_item_number
                  || ' Org Id '
                  || pv_org_code
                  || ' pv_user_item_type '
                  || pv_user_item_type
                  || ' Error '
                  || SQLERRM;
               fnd_file.put_line (fnd_file.LOG, xv_err_msg);
               xv_err_code := 2;
         END;
      --  ELSE                       -- Commented for 1.22.
      ELSIF (   (pv_life_cycle = 'FLR' AND pv_org_code = pv_org_code
                )              --1.41 changed pv_org_code = gn_master_org_code
             OR (pv_life_cycle IN ('ILR', 'PRODUCTION'))
            )
      THEN                                               -- Modified for 1.23.
         BEGIN
            SELECT description
              INTO lv_template_name
              FROM fnd_lookup_values_vl
             WHERE lookup_type = 'DO_ORG_TEMPLATE_ASSIGNMENT'
               AND (   attribute1 = pv_life_cycle
                    OR attribute2 = pv_life_cycle
                    OR attribute3 = pv_life_cycle
                   )
               AND attribute4 = pv_org_code
               AND tag = REPLACE (pv_user_item_type, 'PURCHASED', 'PROD')
               AND NVL (enabled_flag, 'Y') = 'Y';
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               lv_template_name := NULL;
               xv_err_msg :=
                     ' Template not configured in the lookup DO_ORG_TEMPLATE_ASSIGNMENT for item '
                  || pv_item_number
                  || ' life Cycle: '
                  || pv_life_cycle
                  || ' Org Id: '
                  || pv_org_code
                  || ' Item Type: '
                  || pv_user_item_type;
               fnd_file.put_line (fnd_file.LOG, xv_err_msg);
               xv_err_code := 1;
            WHEN OTHERS
            THEN
               lv_template_name := NULL;
               xv_err_msg :=
                     ' Error while fetching Template in the lookup DO_ORG_TEMPLATE_ASSIGNMENT for Item '
                  || pv_item_number
                  || ' Org Id '
                  || pv_org_code
                  || ' pv_user_item_type '
                  || pv_user_item_type
                  || ' Error '
                  || SQLERRM;
               fnd_file.put_line (fnd_file.LOG, xv_err_msg);
               xv_err_code := 2;
         END;
      END IF;

      gv_price_list_flag := 'Y';
      IF ln_pop_template_id IS NOT NULL THEN --1.51 changes
      ln_template_id:=ln_pop_template_id; --1.51 changes
      ELSIF lv_template_name IS NOT NULL
      THEN
         IF UPPER (lv_template_name) IN
                               ('PLANNED ITEM TEMPLATE', 'GENERIC TEMPLATE')
         THEN
            gv_price_list_flag := 'N';
         END IF;

         BEGIN
            SELECT TRIM (template_id)
              INTO ln_template_id
              FROM apps.mtl_item_templates
             WHERE UPPER (template_name) = UPPER (lv_template_name);
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               xv_err_msg :=
                   ' Template ID not Found for template ' || lv_template_name;
               fnd_file.put_line (fnd_file.LOG, xv_err_msg);
               xv_err_code := 1;
            WHEN OTHERS
            THEN
               xv_err_code := 2;
               xv_err_msg :=
                     'Error while fecthing template id for template '
                  || lv_template_name
                  || SQLERRM;
         END;
      ELSE
         lv_item_status := NULL;

         BEGIN
            SELECT tag
              INTO lv_item_status
              FROM fnd_lookup_values_vl
             WHERE lookup_type = 'DO_ITM_STATUS_ASSGNMT'
               AND attribute10 = pv_user_item_type
               AND description = pv_life_cycle
               AND NVL (enabled_flag, 'Y') = 'Y';
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               lv_item_status := NULL;
               xv_err_msg :=
                  SUBSTR
                     (   xv_err_msg
                      || ' - Item status is not configured in the lookup DO_ITM_STATUS_ASSGNMT for Item type '
                      || pv_user_item_type
                      || ' life Cycle '
                      || pv_life_cycle
                      || ' Item '
                      || pv_item_number
                      || ' Org Id '
                      || pv_org_code,
                      1,
                      1000
                     );
            WHEN OTHERS
            THEN
               lv_item_status := NULL;
               xv_err_msg :=
                     'Error while fetching template in the lookup DO_ITM_STATUS_ASSGNMT for Item type '
                  || pv_user_item_type
                  || 'life Cycle '
                  || pv_life_cycle
                  || ' Item '
                  || pv_item_number
                  || ' Org Id '
                  || pv_org_code
                  || '  '
                  || SQLERRM;
         END;
      END IF;

      IF UPPER (NVL (gv_reprocess, 'N')) IN
                                       ('N', 'NO') --W.r.t Version 1.34 STARTS
      THEN
--***********************
-- FETCHING BUYER CODE
--************************
         BEGIN
            SELECT description
              INTO lv_buyer_code
              FROM fnd_lookup_values_vl
             WHERE lookup_type = 'DO_BUYER_CODE'
               AND NVL (tag, 'ALL') IN (pv_region, 'ALL')
               AND attribute1 = pv_brand
               AND UPPER (attribute2) = UPPER (pv_department)
               AND NVL (enabled_flag, 'Y') = 'Y';
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               BEGIN
                  SELECT description
                    INTO lv_buyer_code
                    FROM fnd_lookup_values_vl
                   WHERE lookup_type = 'DO_BUYER_CODE'
                     AND NVL (tag, 'ALL') IN (pv_region, 'ALL')
                     AND attribute1 = pv_brand
                     AND UPPER (attribute2) = 'ALL'
                     AND NVL (enabled_flag, 'Y') = 'Y';
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     fnd_file.put_line
                        (fnd_file.LOG,
                            'Buyer Code not configured in lookup DO_BUYER_CODE for Item '
                         || pv_item_number
                         || ' Org Id '
                         || pv_org_code
                         || ' Region '
                         || pv_region
                         || ' Brand '
                         || pv_brand
                         || SQLERRM
                        );
                     lv_buyer_code := NULL;
               END;
            WHEN OTHERS
            THEN
               fnd_file.put_line
                  (fnd_file.LOG,
                      'Error while fetching Code from lookup DO_BUYER_CODE for Item '
                   || pv_item_number
                   || ' Org Id '
                   || pv_org_code
                   || ' Region '
                   || pv_region
                   || ' Brand '
                   || pv_brand
                   || SQLERRM
                  );
               lv_buyer_code := NULL;
         END;

         IF lv_buyer_code IS NOT NULL
         THEN
            BEGIN
               SELECT pa.agent_id
                 INTO ln_buyer_id
                 FROM po_agents pa, per_all_people_f papf
                WHERE pa.agent_id = papf.person_id
                  AND UPPER (papf.full_name) = UPPER (lv_buyer_code)
                  AND papf.employee_number IS NOT NULL
                  AND TRUNC (SYSDATE) BETWEEN papf.effective_start_date
                                          AND papf.effective_end_date;
            EXCEPTION
               WHEN OTHERS
               THEN
                  BEGIN                                 -- W.r.t Version 1.39
                     SELECT pa.agent_id
                       INTO ln_buyer_id
                       FROM po_agents pa, per_all_people_f papf
                      WHERE pa.agent_id = papf.person_id
                        AND UPPER (papf.full_name) = UPPER (lv_buyer_code)
                        AND papf.employee_number IS NOT NULL
                        AND papf.person_type_id <> '9'
                        AND TRUNC (SYSDATE) BETWEEN papf.effective_start_date
                                                AND papf.effective_end_date;
                  EXCEPTION
                     WHEN OTHERS
                     THEN
                        fnd_file.put_line
                                       (fnd_file.LOG,
                                           ' Error while fetching buyer id  '
                                        || SQLERRM
                                       );
                        ln_buyer_id := NULL;
                  END;
            END;
         ELSE
            ln_buyer_id := NULL;
         END IF;

--***********************
-- FETCHING PLANNER CODE
--************************
         BEGIN
            SELECT SUBSTR (meaning, 0, 10)
              INTO lv_planner_code
              FROM fnd_lookup_values_vl
             WHERE lookup_type = 'DO_PLANNER_CODE'
               AND tag = pv_brand
               AND UPPER (description) = UPPER (pv_region)
               AND NVL (enabled_flag, 'Y') = 'Y';
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               lv_planner_code := NULL;
               fnd_file.put_line
                            (fnd_file.LOG,
                                ' Planner Code is not configured for brand  '
                             || pv_brand
                             || ' Region '
                             || pv_region
                             || SQLERRM
                            );
            WHEN OTHERS
            THEN
               fnd_file.put_line (fnd_file.LOG,
                                     ' Error while fetching Planner code  '
                                  || pv_brand
                                  || ' Region '
                                  || pv_region
                                  || SQLERRM
                                 );
               lv_planner_code := NULL;
         END;

         IF pv_org_code <> gn_master_org_code            -- w.r.t Version 1.39
         THEN
            BEGIN
               SELECT description
                 INTO ln_valid_planer
                 FROM mtl_planners
                WHERE UPPER (description) = UPPER (lv_planner_code)
                  AND organization_id = pn_orgn_id;
            EXCEPTION
               WHEN OTHERS
               THEN
                  fnd_file.put_line
                     (fnd_file.LOG,
                         ' Error while fetching planner code from  MTL_PLANNERS for Org '
                      || pn_orgn_id
                      || ' Planner Code '
                      || lv_planner_code
                      || SQLERRM
                     );
                  ln_valid_planer := NULL;
            END;
         END IF;

         IF ln_valid_planer IS NULL
         THEN
            lv_planner_code := NULL;
         ELSE
            lv_planner_code := ln_valid_planer;
         END IF;

         -- START : Added for 1.22.
         IF pv_tran_type = 'CREATE'
         THEN
            lv_is_carry_over := 'N';
         ELSE
            lv_is_carry_over := 'Y';
         END IF;

         BEGIN
            SELECT 'Y'
              INTO lv_is_lead_time_org
              FROM fnd_lookup_types flt, fnd_lookup_values flv
             WHERE flt.lookup_type = flv.lookup_type
               AND flt.lookup_type = 'DO_EXCLUDE_LEAD_TIME_CAL'
               AND LANGUAGE = USERENV ('LANG')
               AND lookup_code = pv_org_code
               AND enabled_flag = 'Y';
         EXCEPTION
            WHEN OTHERS
            THEN
               lv_is_lead_time_org := 'N';
         END;

         -- END : Added for 1.22.

         --***********************
-- FETCHING LEAD TIME
--************************
         BEGIN
            SELECT description
              INTO lv_lead_time
              FROM fnd_lookup_values_vl
             WHERE lookup_type = 'DO_POST_PROCESSING'
               AND meaning = pv_org_code
               AND NVL (enabled_flag, 'Y') = 'Y';
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               lv_lead_time := NULL;
            WHEN OTHERS
            THEN
               fnd_file.put_line
                              (fnd_file.LOG,
                                  ' Error while fetching lead time for org  '
                               || pv_org_code
                               || SQLERRM
                              );
               lv_lead_time := NULL;
         END;

         BEGIN
            ln_lead_time := TO_NUMBER (lv_lead_time);
         EXCEPTION
            WHEN OTHERS
            THEN
               fnd_file.put_line
                          (fnd_file.LOG,
                              ' Error while converting lead time to number  '
                           || SQLERRM
                          );
               ln_lead_time := NULL;
         END;

         -- START : Added for 1.22.
         IF lv_is_lead_time_org = 'Y' AND lv_is_carry_over = 'Y'
         THEN
            BEGIN
               SELECT full_lead_time
                 INTO ln_full_lead_time
                 FROM mtl_system_items_b msi, mtl_parameters mp
                WHERE msi.segment1 = pv_item_number
                  AND msi.organization_id = mp.organization_id
                  AND mp.organization_code = pv_org_code;
            EXCEPTION
               WHEN OTHERS
               THEN
                  ln_full_lead_time := 0;
            END;
         ELSE
            -- END : Added for 1.22.

            -----------------------------------------------
-- Processing Lead Time Start W.r.t Version 1.7
-----------------------------------------------
            BEGIN
               SELECT country
                 INTO lv_country
                 FROM hr_locations_all
                WHERE inventory_organization_id = pn_orgn_id;
            EXCEPTION
               WHEN NO_DATA_FOUND
               THEN
                  lv_country := NULL;
               WHEN OTHERS
               THEN
                  lv_country := NULL;
            END;

            BEGIN
               SELECT DISTINCT                           --W.r.t Version 1.25
                               attribute5, attribute6
                          INTO ln_transit_days_air, ln_transit_days_ocean
                          FROM fnd_lookup_values_vl
                         WHERE lookup_type = 'XXDO_SUPPLIER_INTRANSIT'
                           AND attribute2 = pv_buyer_code
                           AND attribute3 = lv_country
                           AND NVL (enabled_flag, 'Y') = 'Y';
            EXCEPTION
               WHEN NO_DATA_FOUND
               THEN
                  fnd_file.put_line
                     (fnd_file.LOG,
                         ' Lookup XXDO_SUPPLIER_INTRANSIT is not configured for   '
                      || pv_buyer_code
                      || ' and country '
                      || lv_country
                     );
                  ln_transit_days_air := 0;
                  ln_transit_days_ocean := 0;
               WHEN OTHERS
               THEN
                  fnd_file.put_line
                     (fnd_file.LOG,
                         ' Error while fetching days from lookup XXDO_SUPPLIER_INTRANSIT is not configured for   '
                      || pv_buyer_code
                      || ' and country '
                      || lv_country
                     );
                  ln_transit_days_air := 0;
                  ln_transit_days_ocean := 0;
            END;

            IF pv_user_item_type = 'SAMPLE'
            THEN
               --ln_full_lead_time := TO_NUMBER (pv_lead_time) + ln_transit_days_ocean; --W.r.t Version 1.16
               ln_full_lead_time :=
                                TO_NUMBER (pv_lead_time)
                                + ln_transit_days_air;
            --W.r.t Version 1.16
            ELSE
               --ln_full_lead_time := TO_NUMBER (pv_lead_time) + ln_transit_days_air;  --W.r.t Version 1.16
               BEGIN
                  ln_transit_days_ocean :=
                            get_transit_lead_time (lv_country, pv_buyer_code);
                                                   --start w.r.t Version 1.44
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     fnd_file.put_line
                        (fnd_file.LOG,
                            ' Error while fetching days from the fucntion get_transit_lead_time  '
                         || pv_buyer_code
                         || ' and country '
                         || lv_country
                        );
               END;                                 --start w.r.t Version 1.44

               ln_full_lead_time :=
                               TO_NUMBER (pv_lead_time)
                               + ln_transit_days_ocean;   --W.r.t Version 1.16
            END IF;

            ln_full_lead_time := CEIL (ln_full_lead_time * 5 / 7);
         END IF;                                            -- Added for 1.22.

----------*******************************----------
--------- CR 154 ADD CUM LEAD TIME W.r.t Version 1.29
----------*******************************----------
         BEGIN
            ln_add_cum_lead_time := 0;

            SELECT description
              INTO ln_add_cum_lead_time
              FROM fnd_lookup_values_vl
             WHERE lookup_type = 'DO_ADD_CUMM_LEAD_TIME'
               AND meaning = pv_org_code
               AND NVL (enabled_flag, 'Y') = 'Y';
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               ln_add_cum_lead_time := 0;
            WHEN OTHERS
            THEN
               ln_add_cum_lead_time := 0;
         END;

         -- End W.r.t Version 1.29
         ln_cum_total_lead_time :=
               ln_full_lead_time + NVL (ln_lead_time, 0)
               + ln_add_cum_lead_time;

         --End W.r.t Version 1.7

         --**************************************************
-- CHECKING IF ORGS IN LOOKUP  --W.r.t Version 1.27
--**************************************************
         BEGIN
            lv_jap_org_exists := 'N';
            lv_from_curr := NULL;
            lv_conv_type := NULL;

            SELECT 'Y', UPPER (tag), description
              --/ upper(description) removed upper from conv type -1.34
            INTO   lv_jap_org_exists, lv_from_curr, lv_conv_type
              FROM fnd_lookup_values_vl
             WHERE lookup_type = 'LIST_PRICE_CONVERSION'
               AND lookup_code = pv_org_code
               AND NVL (enabled_flag, 'Y') = 'Y';
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               lv_jap_org_exists := 'N';
            WHEN OTHERS
            THEN
               lv_jap_org_exists := 'N';
         END;

--***************************************************
--List price conversion --W.r.t Version 1.27
--*****************************************************
         IF lv_from_curr IS NOT NULL
         THEN
            BEGIN
               SELECT show_inverse_con_rate
                 INTO gn_japan_con_rate
                 FROM gl_daily_rates_v
                WHERE conversion_date =
                         (SELECT MAX (conversion_date)
                            FROM gl_daily_rates_v
                           WHERE from_currency =
                                    lv_from_curr
                                    --AND  UPPER(from_currency) = lv_from_curr
                             AND to_currency =
                                    'USD'
                                  --AND UPPER (conversion_type) = lv_conv_type
                             AND conversion_type = lv_conv_type)
                  --AND UPPER (from_currency) = lv_from_curr
                  AND from_currency = lv_from_curr
                  AND to_currency = 'USD'
                  --AND UPPER (conversion_type) = lv_conv_type
                  AND conversion_type = lv_conv_type
                  AND ROWNUM = 1;
            EXCEPTION
               WHEN NO_DATA_FOUND
               THEN
                  fnd_file.put_line (fnd_file.LOG,
                                     'Conversion rate not Found' || SQLERRM
                                    );
                  gn_japan_con_rate := 1;
               WHEN OTHERS
               THEN
                  fnd_file.put_line
                     (fnd_file.LOG,
                         'Error Occured while retrieving Conversion rate for JPY '
                      || SQLERRM
                     );
                  gn_japan_con_rate := 1;
            END;
         ELSE
            gn_japan_con_rate := 1;
         END IF;

         IF lv_jap_org_exists = 'Y'
         THEN
            ln_project_cost := TO_NUMBER (pv_project_cost)
                               * gn_japan_con_rate;
         ELSE
            ln_project_cost := TO_NUMBER (pv_project_cost);
         END IF;

--***************************************************
--UPC Corss reference
--***********************************************************
         lv_upc := NULL;                                   --W.rt Version 1.23

         IF pv_disable_auto_upc = 'N'                      --W.rt Version 1.43
         THEN
            IF pn_orgn_id = gn_master_orgid
            THEN
               -- IF    pv_life_cycle = 'SM' AND pv_user_item_type = 'PROD'
               IF        UPPER (pv_life_cycle) = 'PRODUCTION'
                     --AND pv_user_item_type = 'PROD'           ----W.r.t Version 1.13
                     AND UPPER (pv_user_item_type) IN
                                                 ('PROD', 'BGRADE', 'SAMPLE')
                  --W.r.t Version 1.18 *Added SAMPLE as part of 1.32
                  OR     UPPER (pv_life_cycle) IN ('FLR')
                     --AND UPPER (pv_user_item_type) = 'SAMPLE'    --W.r.t Version 1.3
                     AND UPPER (pv_user_item_type) IN
                             ('PROD', 'BGRADE', 'SAMPLE') --w.r.t Version 1.32
               THEN
                  IF lv_is_carry_over = 'Y'         --Start W.rt Version 1.23
                  THEN
                     BEGIN
                        SELECT TO_NUMBER (cross_reference)      --W.r.t UPC CR
                          --SELECT cross_reference   --W.r.t UPC CR
                        INTO   lv_upc
                          FROM mtl_cross_references
                         WHERE inventory_item_id IN (
                                  SELECT inventory_item_id
                                    FROM mtl_system_items_b
                                   WHERE segment1 = pv_item_number
                                     AND organization_id = gn_master_orgid)
                           AND organization_id = gn_master_orgid;
                     EXCEPTION
                        WHEN OTHERS
                        THEN
                           fnd_file.put_line (fnd_file.LOG,
                                              ' fetching lv_upc ' || SQLERRM
                                             );

                           BEGIN
                              SELECT attribute11
                                INTO lv_upc
                                FROM mtl_system_items_b
                               WHERE segment1 = pv_item_number
                                 AND organization_id = gn_master_orgid;
                           EXCEPTION
                              WHEN OTHERS
                              THEN
                                 fnd_file.put_line (fnd_file.LOG,
                                                       ' fetching lv_upc '
                                                    || SQLERRM
                                                   );
                                 lv_upc := NULL;
                           END;
                     END;
                  END IF;             --End lv_is_carry_over W.rt Version 1.23

                  IF lv_upc IS NULL                        --W.rt Version 1.23
                  THEN
                     BEGIN
                        lv_upc := TO_CHAR (apps.do_get_next_upc ());
                     EXCEPTION
                        WHEN OTHERS
                        THEN
                           fnd_file.put_line (fnd_file.LOG,
                                                 'UPC not generated FOR :: '
                                              || pv_item_number
                                              || ' :: '
                                              || SQLERRM
                                             );
                           lv_upc := NULL;
                     END;
                  END IF;                                         --end lv_upc
               END IF;                                     --W.rt Version 1.23
            ELSE                                             --gn_master_orgid
               BEGIN
                  --SELECT attribute13 -- W.r.t 1.6
                  SELECT attribute11                              -- W.r.t 1.6
                    INTO lv_upc
                    FROM mtl_system_items_b
                   WHERE segment1 = pv_item_number
                     AND organization_id = gn_master_orgid;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     lv_upc := NULL;
                     fnd_file.put_line
                                     (fnd_file.LOG,
                                         'Error in Fetching UPC for item :: '
                                      || pv_item_number
                                      || ' :: '
                                      || SQLERRM
                                     );
               END;
            END IF;
         END IF;                                    -- W.r.t version 1.43 Ends
      END IF;                                       -- W.r.t version 1.34 Ends

      --Start 1.49
      --If we are updatng Master org then use calculation logic for ATS Date/Intro Season Date
      IF pn_orgn_id = gn_master_orgid
      THEN
         IF pv_tran_type = 'CREATE'
         THEN
            lv_ats_date := pv_ats_date;             --w.r.t 1.47 for ATS date

            BEGIN
               lv_season_month :=
                  SUBSTR (gv_style_intro_date,
                          1,
                          INSTR (gv_style_intro_date, '/') - 1
                         );
               lv_season_year :=
                  SUBSTR (pv_current_season,
                          INSTR (pv_current_season, ' ') + 1,
                          4
                         );
               lv_season_name :=
                  SUBSTR (pv_current_season,
                          1,
                          INSTR (pv_current_season, ' ') - 1
                         );

               IF lv_season_name = 'SPRING'
                  AND lv_season_month IN (10, 11, 12)
               THEN
                  lv_season_year := lv_season_year - 1;
               END IF;

               lv_intro_season_date :=
                  TO_CHAR (TO_DATE (gv_style_intro_date || '/'
                                    || lv_season_year,
                                    'MM/DD/YYYY'
                                   ),
                           'YYYY/MM/DD'
                          );
            EXCEPTION
               WHEN OTHERS
               THEN
                  fnd_file.put_line (fnd_file.LOG,
                                        'Error in date conversion:: '
                                     || pv_item_number
                                     || ' :: '
                                     || lv_current_season
                                     || ' :: '
                                     || lv_season_month
                                     || ' :: '
                                     || lv_season_year
                                     || ' ::'
                                     || lv_season_name
                                     || ' :: '
                                     || pv_current_season
                                     || ' :: '
                                     || lv_intro_season_date
                                     || ' :: '
                                     || SQLERRM
                                    );
            END;

            --w.r.t 1.42
            lv_confirm_status := 'CN';
            lv_current_season := pv_current_season;
         --  ELSIF pv_tran_type = 'UPDTAE'
         ELSIF pv_tran_type = 'UPDATE'                --End Modified for 1.22.
         THEN
            lv_confirm_status := 'CM';
            lv_current_season := NULL;
            lv_intro_season_date := NULL;
            lv_ats_date := NULL;

            IF NVL (pv_intro_season, 'XXX') = NVL (pv_current_season, 'YYY')
            THEN
               lv_ats_date := pv_ats_date;          --w.r.t 1.47 for ATS date
            END IF;

            IF NVL (pv_intro_season, 'XXX') = NVL (pv_current_season, 'YYY')
            THEN
               BEGIN
                  lv_season_month :=
                     SUBSTR (gv_style_intro_date,
                             1,
                             INSTR (gv_style_intro_date, '/') - 1
                            );
                  lv_season_year :=
                     SUBSTR (pv_current_season,
                             INSTR (pv_current_season, ' ') + 1,
                             4
                            );
                  lv_season_name :=
                     SUBSTR (pv_current_season,
                             1,
                             INSTR (pv_current_season, ' ') - 1
                            );

                  IF     lv_season_name = 'SPRING'
                     AND lv_season_month IN (10, 11, 12)
                  THEN
                     lv_season_year := lv_season_year - 1;
                  END IF;

                  lv_intro_season_date :=
                     TO_CHAR (TO_DATE (   gv_style_intro_date
                                       || '/'
                                       || lv_season_year,
                                       'MM/DD/YYYY'
                                      ),
                              'YYYY/MM/DD'
                             );
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     fnd_file.put_line (fnd_file.LOG,
                                           'Error in date conversion:: '
                                        || pv_item_number
                                        || ' :: '
                                        || lv_current_season
                                        || ' :: '
                                        || lv_season_month
                                        || ' :: '
                                        || lv_season_year
                                        || ' ::'
                                        || lv_season_name
                                        || ' :: '
                                        || pv_current_season
                                        || ' :: '
                                        || lv_intro_season_date
                                        || ' :: '
                                        || ' :: pn_orgn_id '
                                        || pn_orgn_id
                                        || SQLERRM
                                       );
               END;                                               --w.r.t 1.42
            END IF;
         END IF;
      ELSE
--If this is not the master then we will just copy the master values. Version 1.49
         lv_current_season := pv_intro_season;
         lv_intro_season_date := pv_intro_date;
         lv_ats_date := pv_ats_date;

         IF pv_tran_type = 'CREATE'
         THEN
            lv_confirm_status := 'CN';
         ELSIF pv_tran_type = 'UPDATE'
         THEN
            lv_confirm_status := 'CM';
         END IF;
      END IF;

      --End 1.49

      --START W.r.t Version 1.1
      IF UPPER (NVL (gv_reprocess, 'N')) IN ('N', 'NO')   --W.r.t Version 1.34
      THEN
         BEGIN
            SELECT flex_value_meaning
              INTO lv_brand_id
              FROM fnd_flex_value_sets ffvs, fnd_flex_values_vl ffv
             WHERE flex_value_set_name = 'DO_GL_BRAND'
               AND ffvs.flex_value_set_id = ffv.flex_value_set_id
               AND UPPER (ffv.description) = UPPER (pv_brand);
         EXCEPTION
            WHEN OTHERS
            THEN
               fnd_file.put_line
                               (fnd_file.LOG,
                                   'Error in Fetching brand id for brand :: '
                                || pv_brand
                                || ' :: '
                                || SQLERRM
                               );
               lv_brand_id := NULL;
         END;

         BEGIN
            SELECT cost_of_sales_account, sales_account
              INTO ln_cost_acct, ln_sales_acct
              FROM mtl_parameters
             WHERE organization_code = pv_org_code;
         EXCEPTION
            WHEN OTHERS
            THEN
               fnd_file.put_line
                            (fnd_file.LOG,
                                'Error while fetching cost account for org  '
                             || pv_org_code
                             || '  '
                             || SQLERRM
                            );
         END;

         ln_sales_new_ccid := NULL;
         ln_cost_new_ccid := NULL;
         get_conc_code_combn (pn_code_combn_id      => ln_sales_acct,
                              pv_brand              => lv_brand_id,
                              xn_new_ccid           => ln_sales_new_ccid
                             );
         get_conc_code_combn (pn_code_combn_id      => ln_cost_acct,
                              pv_brand              => lv_brand_id,
                              xn_new_ccid           => ln_cost_new_ccid
                             );
         msg (   'lv_item_status : '
              || lv_item_status
              || ' pn_inv_item_id '
              || ln_cost_new_ccid
             );
      ELSE
         lv_item_desc := NULL;
      END IF;                                             --W.r.t Version 1.34

      -- 1.1
      IF    (UPPER (lv_item_status) = 'ACTIVE' AND pn_inv_item_id IS NOT NULL
            )      -- OR (pv_life_cycle = 'SM' AND ln_template_id IS NOT NULL)
         OR (pv_life_cycle = 'PRODUCTION' AND ln_template_id IS NOT NULL
            )                                             --W.r.t Version 1.13
         OR (pv_item_type = 'SAMPLE' AND pv_life_cycle = 'FLR')
      THEN
         BEGIN                                             --START W.R.T 1.31
            SELECT 'Y'
              INTO lv_org_inc_org
              FROM fnd_lookup_values_vl fn
             WHERE lookup_type = 'XXDO_ORG_LIST_INCL_COSTING'
               AND description = pv_org_code
               AND NVL (enabled_flag, 'Y') = 'Y';
         EXCEPTION
            WHEN OTHERS
            THEN
               lv_org_inc_org := 'N';
         END;

         IF lv_org_inc_org = 'Y'                              --END W.R.T 1.31
         THEN
            SELECT COUNT (1)
              INTO ln_count_item_cost
              FROM (SELECT resource_id
                      FROM bom_resources brs, cst_cost_elements cce
                     WHERE organization_id = pn_orgn_id
                       AND brs.cost_element_id = cce.cost_element_id
                       AND cost_element = lv_mat_overhead
                    MINUS
                    SELECT resource_id
                      FROM cst_item_cost_details cid, cst_cost_types cct
                     WHERE inventory_item_id = pn_inv_item_id
                       AND cid.organization_id = pn_orgn_id
                       AND cid.cost_type_id = cct.cost_type_id
                       AND cost_type = 'AvgRates');

            IF ln_count_item_cost > 0
            THEN
               xv_err_msg :=
                  SUBSTR (   xv_err_msg
                          || ' - Overhead Cost not available '
                          || ' for the Item : '
                          || pv_item_number
                          || ' Org : '
                          || pv_org_code,
                          1,
                          1000
                         );

               --lv_item_status := 'Planned';        -- start W.r.t Version 1.17 commented w.r.t version 1.38
               IF    pv_exist_item_status IS NULL
                  OR (    pv_exist_item_status = 'Planned'
                      AND pv_item_type = 'SAMPLE'
                     )
               THEN
                  lv_item_status := 'Planned';
               END IF;

               ln_template_id := NULL;                                  -- 1.1
            END IF;
         END IF;
      END IF;

      -- 1.1
      IF pv_item_type = 'SAMPLE'
      THEN
         IF SUBSTR (pv_item_number,
                    LENGTH (pv_item_number),
                    LENGTH (pv_item_number) - 1
                   ) = 'L'
         THEN
            lv_item_type := 'SAMPLE-L';
         ELSIF SUBSTR (pv_item_number,
                       LENGTH (pv_item_number),
                       LENGTH (pv_item_number) - 1
                      ) = 'R'
         THEN
            lv_item_type := 'SAMPLE-R';
         ELSE
            lv_item_type := 'SAMPLE';
         END IF;
      -- Ver 1.37 Start
      ELSIF pv_item_type = 'B-GRADE'
      THEN
         lv_item_type := 'BGRADE';
      -- Ver 1.37 End
      ELSE
         lv_item_type := pv_item_type;
      END IF;

      IF UPPER (pv_drop_in_season) = 'DROPPED'
      -- Added by Infosys on 09Sept2016(Start)  - Ver 1.35
      THEN
         lv_drop_in_season := 'Y';
      ELSE
         lv_drop_in_season := fnd_api.g_miss_char;
      END IF;              -- Added by Infosys on 09Sept2016(End)   - Ver 1.35

      --END W.r.t Version 1.1

      -- START : Added for 1.23.
      -- ln_pln_fenc_days := -999999; --1.30
      -- ln_pln_fenc_code := 1;   --1.30

      -- END : Added for 1.23.
      msg (   'Item Status is :: '
           || lv_item_status
           || ' Templ '
           || ln_template_id
           || ' item Type '
           || lv_item_type
           || 'pv_item_number'
           || pv_item_number
           || ' gv_reprocess '
           || gv_reprocess
           || ' pv_exist_item_status '
           || pv_exist_item_status
           || ' ln_count_item_cost '
           || ln_count_item_cost
           || ' pn_orgn_id '
           || pn_orgn_id
          );

      IF UPPER (NVL (gv_reprocess, 'N')) IN ('Y', 'YES')  --W.r.t Version 1.34
      THEN
         IF ln_count_item_cost = 0 AND pv_exist_item_status = 'Planned'
         THEN
            BEGIN
               INSERT INTO mtl_system_items_interface
                           (transaction_type,
                                             --description,
                                             organization_code,
                            organization_id, item_number, segment1,
                            process_flag, confirm_status, created_by,
                            creation_date, last_updated_by,
                            last_update_date, last_update_login,
                            --primary_uom_code,
                            template_id,
                                        --list_price_per_unit,
                                        inventory_item_status_code,
                            --planner_code,
                            --buyer_id,
                            --postprocessing_lead_time,
                            --full_lead_time,
                            --cumulative_total_lead_time,
                            attribute1, attribute10,
                            --attribute11,
                            attribute13, attribute16, attribute27,
                            attribute28, orderable_on_web_flag,
                            return_inspection_requirement, web_status,
                            --cost_of_sales_account,
                            --sales_account,
                            attribute30
                                  -- Added by Infosys on 09Sept2016 - Ver 1.35
                           -- ,planning_time_fence_days, --1.30
                           -- planning_time_fence_code  -- w.r.t to version 1.30.
                           )
                    VALUES (pv_tran_type,
                                         --UPPER (lv_item_desc),
                                         -- W.r.t Version 1.32
                                         pv_org_code,
                            pn_orgn_id, pv_item_number, pv_item_number,
                            0, lv_confirm_status, gn_userid,
                            SYSDATE, gn_userid,
                            SYSDATE, g_num_login_id,
                            --pv_primary_uom,
                            ln_template_id,
                                           --ROUND (ln_project_cost, 2),
                                           lv_item_status,
                            --lv_planner_code,
                            --ln_buyer_id,
                            --ln_lead_time,
                            --CEIL (ln_full_lead_time),
                            --ln_cum_total_lead_time,
                            pv_current_season, pv_scale_code_id,
                            --lv_upc,
                            --pv_upc,
                            pv_size_scale, lv_current_season, pv_size_num,
                            lv_item_type, 'N',
                            2, 'UNPUBLISHED',
                            --ln_cost_new_ccid,
                            --ln_sales_new_ccid,
                            lv_drop_in_season
                                  -- Added by Infosys on 09Sept2016 - Ver 1.35
                           --,ln_pln_fenc_days,  --1.30
                           --ln_pln_fenc_code    -- w.r.t to version 1.30
                           );

               COMMIT;
            EXCEPTION
               WHEN OTHERS
               THEN
                  xv_err_msg :=
                        ' Error in Inserting into Items Interface Table '
                     || ' for the Item : '
                     || pv_item_number
                     || ' for the Org : '
                     || pv_org_code
                     || ' :: '
                     || SQLERRM;
                  xv_err_code := 2;
                  fnd_file.put_line (fnd_file.LOG, xv_err_msg);
            END;
         END IF;
      END IF;

      IF UPPER (NVL (gv_reprocess, 'N')) IN ('N', 'NO')   --W.r.t Version 1.34
      THEN
         --IF pv_exist_item_status IS NOT NULL AND pv_life_cycle = 'FLR'
         --THEN
         --        lv_item_status :=pv_exist_item_status;
         --END IF;
         -- For Performance Tuning
         BEGIN
            INSERT INTO mtl_system_items_interface
                        (transaction_type, description, organization_code,
                         organization_id, item_number, segment1,
                         process_flag, confirm_status, created_by,
                         creation_date, last_updated_by, last_update_date,
                         last_update_login, primary_uom_code, template_id,
                         list_price_per_unit, inventory_item_status_code,
                         planner_code, buyer_id, postprocessing_lead_time,
                         full_lead_time, cumulative_total_lead_time,
                         attribute1, attribute10, attribute11,
                         attribute13, attribute16, attribute27,
                         attribute28, orderable_on_web_flag,
                         return_inspection_requirement, web_status,
                         cost_of_sales_account, sales_account,
                         attribute30, attribute20,
                         attribute21, attribute22,
                         attribute23, attribute24,
                                  -- Added by Infosys on 09Sept2016 - Ver 1.35
                         -- ,planning_time_fence_days, --1.30
                         -- planning_time_fence_code  -- w.r.t to version 1.30.
                         attribute25                      --w.r.t Version 1.47
                        )
                 VALUES (pv_tran_type, UPPER (lv_item_desc),
                                                            -- W.r.t Version 1.32
                                                            pv_org_code,
                         pn_orgn_id, pv_item_number, pv_item_number,
                         0, lv_confirm_status, gn_userid,
                         SYSDATE, gn_userid, SYSDATE,
                         g_num_login_id, pv_primary_uom, ln_template_id,
                         ROUND (ln_project_cost, 2), lv_item_status,
                         lv_planner_code, ln_buyer_id, ln_lead_time,
                         CEIL (ln_full_lead_time), ln_cum_total_lead_time,
                         pv_current_season, pv_scale_code_id, lv_upc,
                         --pv_upc,
                         pv_size_scale, lv_current_season, pv_size_num,
                         lv_item_type, 'N',
                         2, 'UNPUBLISHED',
                         ln_cost_new_ccid, ln_sales_new_ccid,
                         lv_drop_in_season, pv_nrf_color_code,
                         pv_nrf_description, pv_nrf_size_code,
                         pv_nrf_size_description, lv_intro_season_date,
                                  -- Added by Infosys on 09Sept2016 - Ver 1.35
                         --,ln_pln_fenc_days,  --1.30
                         --ln_pln_fenc_code    -- w.r.t to version 1.30
                         lv_ats_date
                        );

            COMMIT;
         EXCEPTION
            WHEN OTHERS
            THEN
               xv_err_msg :=
                     ' Error in Inserting into Items Interface Table '
                  || ' for the Item : '
                  || pv_item_number
                  || ' for the Org : '
                  || pv_org_code
                  || ' :: '
                  || SQLERRM;
               xv_err_code := 2;
               fnd_file.put_line (fnd_file.LOG, xv_err_msg);
         END;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         xv_err_msg :=
                     ' Exception Occur in create_master_item prc ' || SQLERRM;
         xv_err_code := 2;
         fnd_file.put_line (fnd_file.LOG, xv_err_msg);
   END create_master_item;

   /********************************************************************
    * PROCEDURE        : CREATE_SRC_RULE                                *
    * PURPOSE          : This procedure is for creating sourcing rules  *
    * INPUT Parameters : pv_chr_src_name                                *
    *                    pn_num_pri_org                                 *
    *                    pn_vendor_id                                   *
    *                    pn_vendor_site_id                              *
    *                    pn_rank                                        *
    * OUTPUT Parameters: pv_num_src_rule                                *
    *                    pv_err_code                                    *
    *                    pv_err_msg                                     *
    *                                                                   *
    * Author  Date         Ver    Description                           *
    * ------- --------    ------  -----------------------------------   *
    * Infosys 20-NOV-14     1.00    creates sourcing rule               *
    *                                                                   *
    ********************************************************************/
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
   )
   AS
      -- l_ variables are input and o_ variables are output to sourcing rule API
      lv_return_status           VARCHAR2 (1);
      lv_msg_count               NUMBER                                  := 0;
      lv_msg_data                VARCHAR2 (1000);
      lv_sourcing_rule_rec       mrp_sourcing_rule_pub.sourcing_rule_rec_type;
      lv_sourcing_rule_val_rec   mrp_sourcing_rule_pub.sourcing_rule_val_rec_type;
      lv_receiving_org_tbl       mrp_sourcing_rule_pub.receiving_org_tbl_type;
      lv_receiving_org_val_tbl   mrp_sourcing_rule_pub.receiving_org_val_tbl_type;
      l_shipping_org_tbl         mrp_sourcing_rule_pub.shipping_org_tbl_type;
      l_shipping_org_val_tbl     mrp_sourcing_rule_pub.shipping_org_val_tbl_type;
      o_sourcing_rule_rec        mrp_sourcing_rule_pub.sourcing_rule_rec_type;
      o_sourcing_rule_val_rec    mrp_sourcing_rule_pub.sourcing_rule_val_rec_type;
      o_receiving_org_tbl        mrp_sourcing_rule_pub.receiving_org_tbl_type;
      o_receiving_org_val_tbl    mrp_sourcing_rule_pub.receiving_org_val_tbl_type;
      o_shipping_org_tbl         mrp_sourcing_rule_pub.shipping_org_tbl_type;
      o_shipping_org_val_tbl     mrp_sourcing_rule_pub.shipping_org_val_tbl_type;
   BEGIN
      pv_err_code := NULL;
      pv_err_msg := NULL;
      fnd_message.CLEAR;
      -- Clear table type  and record variables of sourcing rule API
      lv_receiving_org_tbl := mrp_sourcing_rule_pub.g_miss_receiving_org_tbl;
      l_shipping_org_tbl := mrp_sourcing_rule_pub.g_miss_shipping_org_tbl;
      lv_sourcing_rule_rec := mrp_sourcing_rule_pub.g_miss_sourcing_rule_rec;
      lv_sourcing_rule_rec.sourcing_rule_name := pv_chr_src_name;   --SR Name
      lv_sourcing_rule_rec.description := pv_chr_src_name;
      lv_sourcing_rule_rec.organization_id := pn_num_pri_org;
      lv_sourcing_rule_rec.planning_active := 1;                   -- Active?
      lv_sourcing_rule_rec.status := 1;                  -- Update New record
      lv_sourcing_rule_rec.sourcing_rule_type := 1;        -- 1:Sourcing Rule
      lv_sourcing_rule_rec.operation := 'CREATE';
      --lv_receiving_org_tbl(1).Sr_Receipt_Id:
      lv_receiving_org_tbl (1).effective_date := pd_begin_date;
      lv_receiving_org_tbl (1).disable_date := pd_end_date;
      lv_receiving_org_tbl (1).receipt_organization_id := pn_num_pri_org;
      lv_receiving_org_tbl (1).operation := 'CREATE';     -- Create or Update
      --l_shipping_org_tbl(1).Sr_Source_Id:=228;
      l_shipping_org_tbl (1).RANK := 1;
      l_shipping_org_tbl (1).allocation_percent := 100;     -- Allocation 100
      l_shipping_org_tbl (1).source_type := 3;                    -- BUY FROM
      l_shipping_org_tbl (1).vendor_id := pn_vendor_id;
      l_shipping_org_tbl (1).vendor_site_id := pn_vendor_site_id;
      l_shipping_org_tbl (1).receiving_org_index := 1;
      l_shipping_org_tbl (1).operation := 'CREATE';
---------------------------------------------------------------------------
      msg (   'Before call PROCESS_SOURCING_RULE API :'
           || pd_begin_date
           || ' : '
           || pd_end_date
          );
      mrp_sourcing_rule_pub.process_sourcing_rule
                         (p_api_version_number         => 1.0,
                          p_init_msg_list              => fnd_api.g_true,
                          p_commit                     => fnd_api.g_true,
                          x_return_status              => lv_return_status,
                          x_msg_count                  => lv_msg_count,
                          x_msg_data                   => lv_msg_data,
                          p_sourcing_rule_rec          => lv_sourcing_rule_rec,
                          p_sourcing_rule_val_rec      => lv_sourcing_rule_val_rec,
                          p_receiving_org_tbl          => lv_receiving_org_tbl,
                          p_receiving_org_val_tbl      => lv_receiving_org_val_tbl,
                          p_shipping_org_tbl           => l_shipping_org_tbl,
                          p_shipping_org_val_tbl       => l_shipping_org_val_tbl,
                          x_sourcing_rule_rec          => o_sourcing_rule_rec,
                          x_sourcing_rule_val_rec      => o_sourcing_rule_val_rec,
                          x_receiving_org_tbl          => o_receiving_org_tbl,
                          x_receiving_org_val_tbl      => o_receiving_org_val_tbl,
                          x_shipping_org_tbl           => o_shipping_org_tbl,
                          x_shipping_org_val_tbl       => o_shipping_org_val_tbl
                         );

      IF lv_return_status = fnd_api.g_ret_sts_success
      THEN
         msg (   'Successfully created sourcing rule - '
              || pv_chr_src_name
              || ' sourcing rule id '
              || o_sourcing_rule_rec.sourcing_rule_id
             );
         pv_num_src_rule := o_sourcing_rule_rec.sourcing_rule_id;
      ELSE
         msg ('Failed to create sourcing rule - ' || pv_chr_src_name);
         msg ('Error Message count - ' || lv_msg_count);

         IF lv_msg_count > 0
         THEN
            FOR l_index IN 1 .. lv_msg_count
            LOOP
               lv_msg_data :=
                  fnd_msg_pub.get (p_msg_index      => l_index,
                                   p_encoded        => fnd_api.g_false
                                  );
               msg (SUBSTR (lv_msg_data, 1, 250));
            END LOOP;

            pv_err_code := 2;
            pv_err_msg := lv_msg_data;
         END IF;

         apps.fnd_msg_pub.delete_msg ();
         pv_num_src_rule := NULL;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         msg ('Unexpected exception in create_src_rule procedure ' || SQLERRM);
         pv_num_src_rule := NULL;
   END create_src_rule;

   /********************************************************************
   * PROCEDURE        : ITEM_SRC_ASSIGNMENT                            *
   * PURPOSE          : This procedure is for assigning sourcing       *
   *                    rules to the items                             *
   * INPUT Parameters : pv_chr_operation                               *
   *                    pn_num_assignment                              *
   *                    pn_num_item                                    *
   *                    pn_category_id                                 *
   *                    pn_category_set_id                             *
   *                    pn_org_id                                      *
   *                    pn_chr_expiration_date                         *
   *                    pn_num_src_rule_id                             *
   * OUTPUT Parameters: pv_num_src_rule                                *
   *                    pv_err_code                                    *
   *                    pv_err_msg                                     *
   *                                                                   *
   * Author  Date         Ver    Description                           *
   * ------- --------    ------  -----------------------------------   *
   * Infosys 20-NOV-14     1.00    creates sourcing rule               *
   *                                                                   *
   ********************************************************************/
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
   )
   AS
      lv_return_status                 VARCHAR2 (1);
      lv_msg_count                     NUMBER                            := 0;
      lv_msg_data                      VARCHAR2 (3000);
      lv_assignment_set_rec            mrp_src_assignment_pub.assignment_set_rec_type;
      lv_assignment_set_val_rec_type   mrp_src_assignment_pub.assignment_set_val_rec_type;
      lv_assignment_tbl                mrp_src_assignment_pub.assignment_tbl_type;
      lv_assignment_val_tbl            mrp_src_assignment_pub.assignment_val_tbl_type;
      o_assignment_set_rec             mrp_src_assignment_pub.assignment_set_rec_type;
      o_assignment_set_val_rec_type    mrp_src_assignment_pub.assignment_set_val_rec_type;
      o_assignment_tbl                 mrp_src_assignment_pub.assignment_tbl_type;
      o_assignment_val_tbl             mrp_src_assignment_pub.assignment_val_tbl_type;
      l_num_assignment_set             NUMBER                            := 1;
   BEGIN
      BEGIN
         SELECT assignment_set_id
           INTO l_num_assignment_set
           FROM mrp_assignment_sets
          WHERE assignment_set_name = 'Deckers Default Assignment Set';
      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            msg ('No Data Found in Fetching Deckers Default Assignment Set');
         WHEN OTHERS
         THEN
            msg
               (   'Error Found in Fetching Deckers Default Assignment Set :: '
                || SQLERRM
               );
      END;

      fnd_message.CLEAR;
      pv_err_code := NULL;
      pv_err_msg := NULL;
      lv_assignment_set_rec :=
                              mrp_src_assignment_pub.g_miss_assignment_set_rec;
      lv_assignment_set_val_rec_type :=
                          mrp_src_assignment_pub.g_miss_assignment_set_val_rec;
      lv_assignment_tbl := mrp_src_assignment_pub.g_miss_assignment_tbl;
      lv_assignment_val_tbl :=
                              mrp_src_assignment_pub.g_miss_assignment_val_tbl;
      lv_assignment_tbl (1).assignment_set_id := l_num_assignment_set;
      --IF pn_num_assignment IS NOT NULL
      --THEN
      --   lv_assignment_tbl (1).assignment_id := pn_num_assignment;
      -- assignment to update
      --END IF;

      -- lv_assignment_tbl (1).customer_id := pn_num_customer;         --customer
      --lv_assignment_tbl (1).ship_to_site_id := pn_num_ship_to_site_id; -- site
      lv_assignment_tbl (1).assignment_type := pn_num_assigment_type;
      -- assign  item
      lv_assignment_tbl (1).sourcing_rule_type := 1;
      -- assign to sourcing rule
      --lv_assignment_tbl (1).inventory_item_id := pn_num_item;
      -- assign to item
      lv_assignment_tbl (1).category_id := pn_category_id;
      lv_assignment_tbl (1).category_set_id := pn_category_set_id;
      lv_assignment_tbl (1).organization_id := pn_org_id;
      lv_assignment_tbl (1).sourcing_rule_id := pn_num_src_rule_id;
      lv_assignment_tbl (1).operation := pv_chr_operation;
      mrp_src_assignment_pub.process_assignment
                  (p_api_version_number          => 1.0,
                   p_init_msg_list               => fnd_api.g_false,
                   p_return_values               => fnd_api.g_false,
                   p_commit                      => fnd_api.g_true,
                   x_return_status               => lv_return_status,
                   x_msg_count                   => lv_msg_count,
                   x_msg_data                    => lv_msg_data,
                   p_assignment_set_rec          => lv_assignment_set_rec,
                   p_assignment_set_val_rec      => lv_assignment_set_val_rec_type,
                   p_assignment_tbl              => lv_assignment_tbl,
                   p_assignment_val_tbl          => lv_assignment_val_tbl,
                   x_assignment_set_rec          => o_assignment_set_rec,
                   x_assignment_set_val_rec      => o_assignment_set_val_rec_type,
                   x_assignment_tbl              => o_assignment_tbl,
                   x_assignment_val_tbl          => o_assignment_val_tbl
                  );
      msg ('API Process_Assignment status ' || lv_return_status);

      IF lv_return_status = fnd_api.g_ret_sts_success
      THEN
         msg ('Successfully Processed item assignment');
      ELSE
         msg ('Failed in Item assignment ' || lv_msg_count);
         msg ('Error message count:' || lv_msg_count);

         IF lv_msg_count > 0
         THEN
            FOR l_index IN 1 .. lv_msg_count
            LOOP
               lv_msg_data :=
                  fnd_msg_pub.get (p_msg_index      => l_index,
                                   p_encoded        => fnd_api.g_false
                                  );
               fnd_file.put_line (fnd_file.LOG, SUBSTR (lv_msg_data, 1, 250));
            END LOOP;

            pv_err_code := 2;
            pv_err_msg := lv_msg_data;
         END IF;

         apps.fnd_msg_pub.delete_msg ();
         msg ('Failed in sourcing rule item assignment');
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         pv_err_code := '2';
         pv_err_msg := 'Y';
         msg (   'Unexpected exception in item_src_assignment procedure '
              || SQLERRM
             );
   END item_src_assignment;

-- ***************************************************************************
-- Procedure :  log_error_exception
-- Description:   Logging exception and errors
-- parameters :
-- ***************************************************************************
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
      pv_error_type       IN   VARCHAR2 DEFAULT NULL,     --W.r.t Version 1.12
      pv_attribute1       IN   VARCHAR2 DEFAULT NULL,     --W.r.t Version 1.12
      pv_attribute2       IN   VARCHAR2 DEFAULT NULL      --W.r.t Version 1.12
   )
   AS
      ln_exist_cnt    NUMBER          := 0;
      lv_rep_status   VARCHAR2 (2000);
   BEGIN
      IF SUBSTR (pv_style, 0, 2) IN ('SS', 'SL', 'SR')
      THEN
         gv_plm_style := TRIM (SUBSTR (pv_style, 3, 20));
      ELSE
         gv_plm_style := pv_style;
      END IF;

      BEGIN                                         --Start W.r.t Version 1.12
         SELECT COUNT (*)
           INTO ln_exist_cnt
           FROM xxdo.xxdo_plm_ora_errors
          WHERE style = gv_plm_style          -- AND plm_rowid = gn_plm_rec_id
            AND NVL (color, 'ALL') = NVL (pv_color, 'ALL');
      END;

      IF ln_exist_cnt > 0
      THEN
         UPDATE xxdo.xxdo_plm_ora_errors
            SET verrmsg =
                   SUBSTR (verrmsg || REPLACE (pv_reterror, ',', ''), 1, 3000),
                creation_date = SYSDATE,
                request_id = gn_conc_request_id,
                attribute4 = gv_colorway_state,
                attribute1 = NULL                         --W.r.t Version 1.25
          WHERE style = gv_plm_style
            AND NVL (color, 'ALL') = NVL (pv_color, 'ALL');

         --  AND plm_rowid = gn_plm_rec_id;
         COMMIT;
      -- W.r.t Version 1.12
      ELSE
         BEGIN
            INSERT INTO xxdo.xxdo_plm_ora_errors
                        (plm_rowid, item_number,
                         style, color, size1,
                         brand, gender, current_season, master_style,
                         sub_group, request_id, verrcode,
                         creation_date,
                         verrmsg,
                         ERROR_TYPE, rep_status, attribute4
                        )
                 VALUES (NVL (pv_plm_row_id, gn_plm_rec_id), pv_item_number,
                         gv_plm_style, NVL (pv_color, 'ALL'), pv_size,
                         pv_brand, pv_gender, gv_season, pv_master_style,
                         pv_sub_group, gn_conc_request_id, pv_error_code,
                         SYSDATE,
                         --  SUBSTR (   'Error in ' || pv_procedure_name || ' '  || pv_operation_code || '  ' || pv_operation_key  || '  ' || REPLACE (pv_reterror, ',', ''), 1,3000 ),
                         SUBSTR (REPLACE (pv_reterror, ',', ''), 1, 3000),
                         pv_error_type, lv_rep_status, gv_colorway_state
                        );

            COMMIT;
         EXCEPTION
            WHEN OTHERS
            THEN
               fnd_file.put_line
                  (fnd_file.LOG,
                      ' Error occured while inserting record into error table . '
                   || SQLERRM
                  );
         END;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line
                      (fnd_file.LOG,
                          ' Error occured in procedure log_error_exception. '
                       || SQLERRM
                      );
   END log_error_exception;

   /*************************************************************************
   * Procedure/Function Name  :  control_proc
   *
   * Description              :  This is main procedure which internally calls
   *                             all procedures to create categories, price lists,
   *                             inventory items etc.
   * INPUT Parameters :
   *                    pv_brand_v
   *                    pv_style_v
   * OUTPUT Parameters: pv_retcode
   *                    pv_reterror
   *
   * DEVELOPMENT and MAINTENANCE HISTORY
   *
   * date          author             Version  Description
   * ------------  -----------------  -------  ------------------------------
   * 10-NOV-2014     INFOSYS            1.0.1    Initial Version
   *************************************************************************/
   PROCEDURE control_proc (
      pv_retcode     OUT   NUMBER,
      pv_errproc     OUT   VARCHAR2,
      pv_brand_v           VARCHAR2,
      pv_style_v           VARCHAR2,
      pv_reprocess         VARCHAR2
   )
   /**************************************************************************************
    cursor to fetch records from main staging table
    ****************************************************************************************/
   IS
      CURSOR csr_plm_data
      IS
         SELECT   stg.*,
                  DECODE (UPPER (RANK),
                          'PRIMARY', 1,
                          'SECONDARY', 2,
                          2
                         ) souc_rule,
                  NVL (siz.size_val, 'ALL') size_num,
                  UPPER
                     (   SUBSTR
                            (stg.attribute1, 0, 4)
                           -- Added UPPER case for cost type W.r.t version 1.6
                      || SUBSTR (stg.attribute1, -2)
                     ) cst_type,

                  -- current_season
                  siz.item_type inv_item_type,
                  siz.sequence_num size_sort_code, siz.nrf_size_code,

                  --w.r.t version 1.40
                  siz.nrf_size_description               --w.r.t version 1.40
             FROM xxdo.xxdo_plm_staging stg, xxdo.xxdo_plm_size_stg siz
            WHERE stg.request_id = gn_conc_request_id
              AND oracle_status = 'N'
              AND brand = NVL (pv_brand_v, brand)
              AND style = NVL (pv_style_v, style)
              AND NVL (stg.attribute4, 'XX') <> 'HIERARCHY_UPDATE'
              --w.r.t version 1.34
              AND stg.record_id = siz.parent_record_id(+)
         ORDER BY record_id, size_num;

      /*******************************************************************
       cursor to fetch the records from xxdo_plm_itemast_stg
      ********************************************************************/
      CURSOR csr_process_records
      IS
         SELECT   *
             FROM xxdo.xxdo_plm_itemast_stg
            WHERE status_flag = 'P' AND stg_request_id = gn_conc_request_id
         ORDER BY parent_record_id;

      /*******************************************************************
       cursor to fetch the records from xxdo_plm_itemast_stg  --1.8
      ********************************************************************/
      CURSOR csr_sourcing_records
      IS
         SELECT DISTINCT supplier, factory, style, color_code,
                         purchasing_start_date, purchasing_end_date, brand,
                         currentseason, tq_sourcing_name
                    FROM xxdo.xxdo_plm_itemast_stg
                   WHERE status_flag = 'S'
                     AND UPPER (NVL (life_cycle, 'XXX')) <> 'ILR'
                     AND NVL (gv_reprocess, 'N') IN
                                              ('N', 'NO') --w.r.t Version 1.34
                     AND stg_request_id = gn_conc_request_id;

      /*******************************************************************
       cursor to fetch the Child organizations
      ********************************************************************/
      CURSOR csr_child_org (pn_sequence NUMBER)
      IS
         SELECT   stg.*, RANK souc_rule, stg.size_val size_num,
                  mp.organization_id, mp.organization_code,
                  mp.attribute1 region_name
             FROM xxdo.xxdo_plm_itemast_stg stg,
                  apps.mtl_parameters mp,
                  apps.org_organization_definitions ood
            WHERE stg.stg_request_id = gn_conc_request_id
              AND mp.organization_id = ood.organization_id
              AND status_flag = 'P'
              AND attribute13 = '2'                  --Added W.r.t version 1.1
              AND mp.organization_id <> gn_master_orgid
              AND stg.seq_num = pn_sequence
         ORDER BY parent_record_id;

      /*************************************************************************************************
           cursor to fetch successfully created and updated items to assign categories
      **************************************************************************************************/
      CURSOR csr_item_cat_assign
      IS
         SELECT   stg.*,
                  DECODE (INSTR (stg.tariff, '/', 1),
                          0, REPLACE (stg.tariff, '.', ''),
                          REPLACE (SUBSTR (stg.tariff,
                                           1,
                                           INSTR (stg.tariff, '/', 1) - 1
                                          ),
                                   '.',
                                   ''
                                  )
                         ) tariff_code,
                  msib.organization_id
             FROM xxdo.xxdo_plm_itemast_stg stg, mtl_system_items_b msib
            WHERE stg.status_flag = 'S'
              AND msib.inventory_item_id = item_id
              AND msib.organization_id = gn_master_orgid
              AND NVL (gv_reprocess, 'N') IN ('N', 'NO')  --w.r.t Version 1.34
              AND stg.stg_request_id = gn_conc_request_id
         ORDER BY parent_record_id;

      /*************************************************************************************************
           cursor to fetch successfully created and updated items to assign categories W.r.t Version 1.10
      **************************************************************************************************/
      /* -- START : Commented for 1.22.
         CURSOR csr_prod_cat_assign
         IS
              SELECT   stg.*, msib.organization_id
                FROM xxdo.xxdo_plm_itemast_stg stg, mtl_system_items_b msib
               WHERE stg.status_flag = 'S'
                 AND msib.inventory_item_id = item_id
                 AND stg.stg_request_id = gn_conc_request_id
            ORDER BY parent_record_id, msib.organization_id;
      */
      -- END : Commented for 1.22.

      -- START : Modified for 1.22.
      CURSOR csr_prod_cat_assign (pn_item_id IN NUMBER)
      IS
         SELECT   stg.*, mp.organization_id
             FROM xxdo.xxdo_plm_itemast_stg stg,
                  mtl_parameters mp,
                  mtl_system_items_b msib
            WHERE stg.status_flag = 'S'
              AND msib.inventory_item_id = item_id
              AND msib.organization_id = mp.organization_id
              AND msib.inventory_item_id = pn_item_id
              AND NVL (gv_reprocess, 'N') IN ('N', 'NO')  --w.r.t Version 1.34
              AND stg.stg_request_id = gn_conc_request_id
         ORDER BY parent_record_id, mp.organization_id;

      -- END : Modified for 1.22.

      /*************************************************************************************************
       cursor to fetch organizations based on Country code
       **************************************************************************************************/
      CURSOR csr_tarif_cat_assign (pv_loc_code VARCHAR2)
      IS
         SELECT hou.organization_id, hou.NAME, hl.*
           FROM hr_all_organization_units hou,
                hr_locations hl,
                org_organization_definitions ood,
                mtl_parameters mp
          WHERE hl.location_id = hou.location_id
            AND hl.country = pv_loc_code
            AND mp.organization_id = ood.organization_id
            AND NVL (gv_reprocess, 'N') IN ('N', 'NO')    --w.r.t Version 1.34
            AND mp.attribute13 = '2'
            AND hou.organization_id = ood.organization_id
            AND ood.inventory_enabled_flag = 'Y';

      /*************************************************************************************************
       cursor to fetch data from Region Staging Table
       **************************************************************************************************/
      CURSOR csr_region_cat_assign (ln_record_id NUMBER)
      IS
         SELECT   *
             FROM xxdo.xxdo_plm_region_stg
            WHERE parent_record_id = ln_record_id
         ORDER BY parent_record_id;

      CURSOR cur_vendors (pv_supplier IN VARCHAR2, pv_supp_factory IN VARCHAR2)
      IS
         SELECT DISTINCT pv.vendor_name
                    --ood.organization_id,ood.organization_code , vendor_site_id,pv.vendor_id --W.r.t Version 1.13
         FROM            po_vendors pv,
                         po_vendor_sites_all pvs,
                         org_organization_definitions ood,
                         apps.mtl_parameters mp      --Added W.r.t version 1.1
                   WHERE pv.vendor_id = pvs.vendor_id
                     AND pvs.org_id = ood.operating_unit
                     AND mp.organization_id = ood.organization_id
                     --Added W.r.t version 1.1
                     AND mp.attribute13 = '2'        --Added W.r.t version 1.1
                     --     AND UPPER (pvs.vendor_site_code) = UPPER (pv_supplier)|| '-'|| UPPER (pv_supp_factory)
                     AND UPPER (pvs.vendor_site_code) =
                                                       UPPER (pv_supp_factory)
                     AND TRUNC (SYSDATE) BETWEEN pv.start_date_active
                                             AND NVL (pv.end_date_active,
                                                      SYSDATE + 1
                                                     );

      /*************************************************************************************************
      cursor to fetch data from Look Up Table based on supplier site code
      **************************************************************************************************/
      CURSOR plm_dual_sourcing_cur (
         p_supplier_site_code   VARCHAR2,
         p_vendor_name          VARCHAR2
      )                                            -- Added by LN from INFOSYS
      IS
         SELECT DISTINCT attribute1,                             --Vendor Name
                                    attribute2,             --Vendor Site Code
                                               attribute3             --Region
                    --ATTRIBUTE4  --Org
         FROM            fnd_lookup_values
                   WHERE lookup_type = 'XXDO_PLM_DUAL_SOURCING'
                     AND LANGUAGE = USERENV ('LANG')
                     AND enabled_flag = 'Y'
                     AND attribute1 = p_vendor_name
                     AND attribute2 = p_supplier_site_code
                     AND (    TRUNC (start_date_active) <= TRUNC (SYSDATE)
                          AND TRUNC (NVL (end_date_active, SYSDATE)) >=
                                                               TRUNC (SYSDATE)
                         );

      /*************************************************************************************************
        corsor to fetch transaction_typpe, set_process_id from apps.mtl_item_categories_interface --1.26
        **************************************************************************************************/
      CURSOR import_cat_items_cur
      IS
         SELECT   set_process_id
             FROM apps.mtl_item_categories_interface msii
            WHERE EXISTS (
                     SELECT 1
                       FROM xxdo.xxdo_plm_itemast_stg stg
                      WHERE stg.stg_request_id = gn_conc_request_id
                        AND msii.inventory_item_id = stg.item_id
                        AND status_flag = 'S')
         GROUP BY set_process_id;

        /************************
          Reprocessing Cursor -- --W.r.t Version 1.12
          **************************/
        /*
      CURSOR csr_plm_reprocess
      IS
         SELECT   *
             FROM xxdo.xxdo_plm_reprocess_stg
            WHERE rec_status = 'N'
              AND brand = NVL (pv_brand_v, brand)
              AND style = NVL (pv_style_v, style)
         ORDER BY parent_record_id;
         */
        /**************s***************
         declaring variables
         ****************************/
      lv_brand                 VARCHAR2 (200)                := NULL;
      lv_style                 VARCHAR2 (200)                := NULL;
      ln_brandflexvalueid      NUMBER (10)                   := NULL;
      ln_brandflexvaluesetid   NUMBER (10)                   := NULL;
      lv_pn                    VARCHAR2 (240)
                                         := gv_package_name || '.control_proc';
      v_def_mail_recips        apps.do_mail_utils.tbl_recips;
      ln_ret_val               NUMBER                        := 0;
      ln_instance              VARCHAR2 (100);
      ln_req_id                NUMBER;
      lv_exists                VARCHAR2 (1)                  := NULL;
      ln_masterorg_code        VARCHAR2 (10);
      ln_lastorgid             NUMBER                        := 0;
      ln_numofsizes            NUMBER                        := 0;
      ln_wsale_pricelist_id    NUMBER;
      ln_rtl_pricelist_id      NUMBER;
      ln_template_id_non_pf    NUMBER;
      ln_template_id_pur       NUMBER;
      ln_inactive_template     NUMBER;
      ln_updateid              NUMBER;
      ln_upc_code              VARCHAR2 (300);
      ln_upc_mast_org          NUMBER;
      lv_upc_code              VARCHAR2 (300);
      ln_catid                 NUMBER;
      ln_price                 NUMBER;
      ln_list_line_id          NUMBER;
      ln_pricing_attr_id       NUMBER;
      ld_start_date            DATE;
      ld_end_date              DATE;
      ln_masterorg             NUMBER;
      ln_item_count            NUMBER                        := 0;
      pv_reterror              VARCHAR2 (1000);
      ln_days                  NUMBER                        := 0;
      ln_batchid               NUMBER;
      ln_scale_code_id         NUMBER;
      lv_color                 VARCHAR2 (300);
      lv_sze                   VARCHAR2 (300);
      ln_sortseq               NUMBER;
      lv_region                VARCHAR2 (100);
      lv_gender                VARCHAR2 (300);
      lv_upccode               VARCHAR2 (400);
      ln_projectedcost         NUMBER;
      lv_templateid            VARCHAR2 (100);
      lv_style_desc            VARCHAR2 (50);
      lv_cuur_season           VARCHAR2 (50);
      lv_smu                   VARCHAR2 (10);
      lv_uom                   VARCHAR2 (100);
      ln_user_id               NUMBER;
      lv_colorway_status       VARCHAR2 (200);
      ln_tariff                NUMBER;
      lv_product_group         VARCHAR2 (300);
      lv_sub_group             VARCHAR2 (300);
      ln_err_days              NUMBER                        := 8;
      ln_count                 NUMBER                        := 0;
      ln_tot_count             NUMBER                        := 0;
      ln_gl_acct_invalid       NUMBER;
      lv_error_message         VARCHAR2 (3000);
      ln_template_id_sample    NUMBER;
      ln_template_id_generic   NUMBER;
      ln_count_create          NUMBER;
      lv_chr_src_rule_name     VARCHAR2 (100);
      lv_num_pri               VARCHAR2 (100);
      lv_num_sec               VARCHAR2 (100);
      ln_num_src_rule          NUMBER                        := NULL;
      l_item_table             ego_item_pub.item_tbl_type;
      x_item_table             ego_item_pub.item_tbl_type;
      x_return_status          VARCHAR2 (1);
      x_msg_count              NUMBER (10);
      x_msg_data               VARCHAR2 (1000);
      x_message_list           error_handler.error_tbl_type;
      ltab_item                ego_item_pub.item_tbl_type;
      ln_inventory_item_id     VARCHAR2 (1000)               := NULL;
      ln_error_code            NUMBER;
      lv_msg_data              VARCHAR2 (3000)               := NULL;
      ln_item_id               NUMBER;
      ln_rowid                 VARCHAR2 (200);
      ln_cost_type_id          NUMBER;
      ln_buyer_id              NUMBER;
      lv_item_type             VARCHAR2 (200);
      lv_item_desc             VARCHAR2 (3000);
      lv_item_number           VARCHAR2 (200);
      lv_value                 NUMBER;
      lv_flag                  VARCHAR2 (1)                  := NULL;
      ln_num_assignment        NUMBER;
      ln_num_src_assign        NUMBER;
      lv_chr_assign_oper       VARCHAR2 (100)                := NULL;
      l_chr_assignment_error   VARCHAR2 (3000);
      ln_template_id           NUMBER;
      ln_template_id_bg        NUMBER;
      lv_error_mesg            VARCHAR2 (3000);
      lv_transaction_type      VARCHAR2 (200)                := NULL;
      ln_org_item_id           NUMBER;
      lv_exist_item_status     VARCHAR2 (20);
      lv_intro_season          VARCHAR2 (20)                 := NULL;
      lv_intro_date            VARCHAR2 (20)                 := NULL;
      x_row_id                 VARCHAR2 (20);
      x_asl_id                 NUMBER;
      lv_vendor_name           VARCHAR2 (240)                := NULL;
      ln_vendor_site_id        NUMBER;
      ln_vendor_id             NUMBER;
      lv_user_item_type        VARCHAR2 (200);
      ln_cat_struc_id          NUMBER;
      ln_category_id           NUMBER;
      ln_category_set_id       NUMBER;
      ln_sou_count             NUMBER;
      lv_source_rule_flag      VARCHAR2 (20);
      ln_inv_item_cat_id       NUMBER;
      lv_item_status           VARCHAR2 (20);
      lv_planner_code          VARCHAR2 (20);
      lv_cost_org_exists       VARCHAR2 (20);
      lv_jap_org_exists        VARCHAR2 (20);
      lv_cost_type             VARCHAR2 (20);
      ln_wholesale_price       NUMBER;
      ln_fob                   NUMBER;
      ln_apov_list_count       NUMBER;
      ln_asl_count             NUMBER;
      lv_sam_item_number       VARCHAR2 (200)                := NULL;
      ln_sourc_org_count       NUMBER;
      ln_landed_cost           NUMBER;
      lv_template_name         VARCHAR2 (40)                 := NULL;
      ln_pur_cost              NUMBER;                    -- W.r.t version 1.3
      ln_inv_resp_id           NUMBER;                    -- W.r.t version 1.4
      ln_inv_appl_id           NUMBER;                    -- W.r.t version 1.4
      ld_plm_begin_date        VARCHAR2 (40)                 := NULL;
      -- W.r.t version 1.7
      ld_plm_end_date          VARCHAR2 (40)                 := NULL;
      -- W.r.t version 1.7
      lv_product_attr_value    VARCHAR2 (100);            -- W.r.t version 1.7
      ln_inv_item_id           VARCHAR2 (100);            -- W.r.t version 1.7
      lv_price_season          VARCHAR2 (100);            -- W.r.t version 1.7
      lv_price_brand           VARCHAR2 (100);           -- W.r.t version 1.14
      lv_sourc_region          VARCHAR2 (100);            -- W.r.t version 1.8
      lv_style_name            VARCHAR2 (100);            -- W.r.t version 1.9
      lv_sample_style          VARCHAR2 (100);            -- W.r.t version 1.9
      lv_mat_overhead          VARCHAR2 (150)           := 'Material Overhead';
      -- W.r.t version 1.12
      ln_count_item_cost       NUMBER                        := 0;
      ln_error_records         NUMBER                        := 0;
      -- W.r.t version 1.12
      ln_sourcing_exist        NUMBER                        := 0;
      ln_ncount                NUMBER                        := 0;
      ln_dcount                NUMBER                        := 0;
      ln_ecount                NUMBER                        := 0;
      ln_pcount                NUMBER                        := 0;
      ln_fcount                NUMBER                        := 0;
      ln_iface_err_count       NUMBER                        := 0;
      ln_retire_count          NUMBER                        := 0;      --1.24
      l_lkp_cnt                NUMBER                        := 0;
      -- W.r.t version 1.33
      ln_is_dual_sourced       NUMBER                        := 0;
                                             -- Added for defect 677 for V1.46
      lv_mast_ats_date         VARCHAR2 (100)                := NULL;     --CCR0008053
      ln_current_season_count  NUMBER                        :=0;
   BEGIN
      -- START : Added for 1.22.
      -- Fetching Category Set Details for OM SALES CATEGORY.
      fnd_file.put_line (fnd_file.LOG,
                            '*********CONTROL_PROC Procedure Started at :: '
                         || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                        );

      BEGIN
         get_category_set_details (gv_om_sales_set_name,
                                   gn_om_sales_set_id,
                                   gn_om_sales_structure_id
                                  );
      EXCEPTION
         WHEN OTHERS
         THEN
            gn_om_sales_set_id := NULL;
            gn_om_sales_structure_id := NULL;
      END;

      -- Fetching Category Set Details for INVENTORY.
      BEGIN
         get_category_set_details (gv_inventory_set_name,
                                   gn_inventory_set_id,
                                   gn_inventory_structure_id
                                  );
      EXCEPTION
         WHEN OTHERS
         THEN
            gn_inventory_set_id := NULL;
            gn_inventory_structure_id := NULL;
      END;

      -- Fetching Category Set Details for PRODUCTION_LINE.
      BEGIN
         get_category_set_details (gv_prod_line_set_name,
                                   gn_prod_line_set_id,
                                   gn_prod_line_structure_id
                                  );
      EXCEPTION
         WHEN OTHERS
         THEN
            gn_prod_line_set_id := NULL;
            gn_prod_line_structure_id := NULL;
      END;

      -- Fetching Category Set Details for TARRIF CODE.
      BEGIN
         get_category_set_details (gv_tariff_code_set_name,
                                   gn_tariff_code_set_id,
                                   gn_tariff_code_structure_id
                                  );
      EXCEPTION
         WHEN OTHERS
         THEN
            gn_tariff_code_set_id := NULL;
            gn_tariff_code_structure_id := NULL;
      END;

      -- Fetching Category Set Details for REGION.
      BEGIN
         get_category_set_details (gn_region_set_name,
                                   gn_region_set_id,
                                   gn_region_structure_id
                                  );
      EXCEPTION
         WHEN OTHERS
         THEN
            gn_region_set_id := NULL;
            gn_region_structure_id := NULL;
      END;

      -- Fetching Category Set Details for ITEM_TYPE.
      BEGIN
         get_category_set_details (gn_item_type_set_name,
                                   gn_item_type_set_id,
                                   gn_item_type_structure_id
                                  );
      EXCEPTION
         WHEN OTHERS
         THEN
            gn_item_type_set_id := NULL;
            gn_item_type_structure_id := NULL;
      END;

      -- Fetching Category Set Details for COLLECTION.
      BEGIN
         get_category_set_details (gn_collection_set_name,
                                   gn_collection_set_id,
                                   gn_collection_structure_id
                                  );
      EXCEPTION
         WHEN OTHERS
         THEN
            gn_collection_set_id := NULL;
            gn_collection_structure_id := NULL;
      END;

      -- Fetching Category Set Details for PROJECT_TYPE.
      BEGIN
         get_category_set_details (gn_proj_type_set_name,
                                   gn_proj_type_set_id,
                                   gn_proj_type_structure_id
                                  );
      EXCEPTION
         WHEN OTHERS
         THEN
            gn_proj_type_set_id := NULL;
            gn_proj_type_structure_id := NULL;
      END;

      -- Fetching Category Set Details for PO ITEM CATEGORY.
      BEGIN
         get_category_set_details (gn_po_item_set_name,
                                   gn_po_item_set_id,
                                   gn_po_item_structure_id
                                  );
      EXCEPTION
         WHEN OTHERS
         THEN
            gn_po_item_set_id := NULL;
            gn_po_item_structure_id := NULL;
      END;

      -- Fetching Category Set Details for QR.
      BEGIN
         get_category_set_details (gn_qr_set_name,
                                   gn_qr_set_id,
                                   gn_qr_structure_id
                                  );
      EXCEPTION
         WHEN OTHERS
         THEN
            gn_qr_set_id := NULL;
            gn_qr_structure_id := NULL;
      END;

      -- Fetching Category Set Details for MASTER_SEASON.
      BEGIN
         get_category_set_details (gn_mst_season_set_name,
                                   gn_mst_season_set_id,
                                   gn_mst_season_structure_id
                                  );
      EXCEPTION
         WHEN OTHERS
         THEN
            gn_mst_season_set_id := NULL;
            gn_mst_season_structure_id := NULL;
      END;

      -- END : Added for 1.22.

      /**************************************************************
      clearing data from staging tables
      **************************************************************/
      BEGIN
         staging_table_purging (pv_reterror, pv_retcode);

         IF pv_reterror IS NOT NULL OR pv_retcode IS NOT NULL
         THEN
            fnd_file.put_line
                             (fnd_file.LOG,
                                 'Error Ocurred While Purging Staging Tables'
                              || pv_reterror
                             );
         END IF;
      END;

      BEGIN
         SELECT organization_id
           INTO gn_master_orgid
           FROM mtl_parameters
          WHERE organization_code = gn_master_org_code;
      EXCEPTION
         WHEN OTHERS
         THEN
            fnd_file.put_line
               (fnd_file.LOG,
                   'Profile Option XXDO: ORGANIZATION CODE is not Defined - '
                || SQLERRM
               );
      END;

      /*****************************************
        Reprocessing Cursor
       *****************************************/
      msg (' pv_reprocess ' || pv_reprocess);
      gv_reprocess := pv_reprocess;

      IF UPPER (NVL (pv_reprocess, 'N')) IN ('Y', 'YES')  --W.r.t Version 1.12
      THEN
         IF pv_style_v IS NOT NULL                       --W.r.t Version 1.34
         THEN
            gv_reprocess := 'N';

            BEGIN
               UPDATE xxdo.xxdo_plm_staging xps
                  SET xps.oracle_status = 'E'
                WHERE 1 = 1
                  AND style = pv_style_v
                  AND record_id IN (
                         SELECT   MAX (record_id)
                             FROM xxdo.xxdo_plm_staging
                            WHERE style = pv_style_v
                              AND NVL (attribute4, 'XX') <> 'HIERARCHY_UPDATE'
                         --AND oracle_status <> 'P'
                         GROUP BY style, colorway);

               UPDATE xxdo.xxdo_plm_ora_errors err
                  SET attribute1 = NULL
                WHERE (style, NVL (color, 'ALL')) IN (
                         SELECT style, NVL (colorway, 'ALL')
                           FROM xxdo.xxdo_plm_staging
                          WHERE record_id IN (
                                   SELECT   MAX (record_id)
                                       FROM xxdo.xxdo_plm_staging
                                      WHERE style = pv_style_v
                                        AND NVL (attribute4, 'XX') <>
                                                            'HIERARCHY_UPDATE'
                                   --AND oracle_status <> 'P'
                                   GROUP BY style, colorway))
                  AND style = pv_style_v
                  AND attribute1 = 'P';

               COMMIT;
            EXCEPTION
               WHEN OTHERS
               THEN
                  fnd_file.put_line
                     (fnd_file.LOG,
                         ' Exception occurred while updating records for Reprocessing for style '
                      || pv_style_v
                      || ' Error '
                      || SQLERRM
                     );
            END;
         END IF;                                          --W.r.t Version 1.34

         BEGIN
            UPDATE xxdo.xxdo_plm_ora_errors err
               SET verrmsg = NULL
             WHERE NVL (attribute1, 'N') <> 'P'
               AND UPPER (err.style) =
                                    UPPER (NVL (TRIM (pv_style_v), err.style))
               -- Added for 1.23.
               AND UPPER (err.brand) =
                                    UPPER (NVL (TRIM (pv_brand_v), err.brand));

            -- Added for 1.23.
            UPDATE xxdo.xxdo_plm_staging xps
               SET xps.request_id = gn_conc_request_id,
                   oracle_error_message = NULL,
                   date_updated = SYSDATE,
                   oracle_status = 'N',
                   style_name = TRIM (SUBSTR (style_name, 0, 40)),
                   -- W.r.t Version 1.13
                   master_style = TRIM (SUBSTR (master_style, 0, 40)),
                   -- W.r.t Version 1.13
                   collection = TRIM (SUBSTR (collection, 0, 40)),
                   -- W.r.t Version 1.13
                   production_line = TRIM (SUBSTR (production_line, 0, 40)),
                   -- W.r.t Version 1.13
                   sub_class = TRIM (SUBSTR (sub_class, 0, 40)),
                   -- W.r.t Version 1.13
                   supplier = TRIM (SUBSTR (supplier, 0, 40)),
                   -- W.r.t Version 1.13
                   sourcing_factory = TRIM (SUBSTR (sourcing_factory, 0, 40))
             -- W.r.t Version 1.13
            WHERE  1 = 1
               AND oracle_status = 'E'
               AND NVL (attribute4, 'XX') <> 'HIERARCHY_UPDATE'
               -- W.r.t Version 1.34
               AND EXISTS (
                      SELECT 1
                        FROM xxdo.xxdo_plm_ora_errors err
                       WHERE xps.style = err.style
                         AND NVL (xps.colorway, 'ALL') =
                                                        NVL (err.color, 'ALL')
                         AND NVL (attribute1, 'N') <> 'P'
                         AND UPPER (err.style) =
                                    UPPER (NVL (TRIM (pv_style_v), err.style))
                         -- Added for 1.23.
                         AND UPPER (err.brand) =
                                UPPER
                                     (NVL (TRIM (pv_brand_v), err.brand))
                                                            -- Added for 1.23.
                                                                         );

            ln_count := SQL%ROWCOUNT;

            UPDATE xxdo.xxdo_plm_size_stg spz
               SET request_id = NULL
             WHERE 1 = 1
               AND EXISTS (
                      SELECT 1
                        FROM xxdo.xxdo_plm_staging stg
                       WHERE stg.record_id = spz.parent_record_id
                         AND oracle_status = 'N'
                         AND stg.request_id =
                                          gn_conc_request_id
                                                            -- Added for 1.23.
                                                            );
         EXCEPTION
            WHEN OTHERS
            THEN
               fnd_file.put_line
                  (fnd_file.LOG,
                      ' Exception occurred while updating records for Reprocessing '
                   || SQLERRM
                  );
         END;
      ELSE
--******************************************************
--Updating plm staging table with concurrent request id
--*****************************************************
         BEGIN
            UPDATE xxdo.xxdo_plm_staging xps
               SET xps.request_id = gn_conc_request_id,
                   oracle_error_message = NULL,
                   date_updated = SYSDATE,
                   style_name = TRIM (SUBSTR (style_name, 0, 40)),
                   -- W.r.t Version 1.13
                   master_style = TRIM (SUBSTR (master_style, 0, 40)),
                   -- W.r.t Version 1.13
                   collection = TRIM (SUBSTR (collection, 0, 40)),
                   -- W.r.t Version 1.13
                   production_line = TRIM (SUBSTR (production_line, 0, 40)),
                   -- W.r.t Version 1.13
                   sub_class = TRIM (SUBSTR (sub_class, 0, 40)),
                   -- W.r.t Version 1.13
                   supplier = TRIM (SUBSTR (supplier, 0, 40)),
                   -- W.r.t Version 1.13
                   sourcing_factory = TRIM (SUBSTR (sourcing_factory, 0, 40))
             -- W.r.t Version 1.13
            WHERE  UPPER (xps.style) = UPPER (NVL (TRIM (pv_style_v), style))
               AND UPPER (xps.brand) = UPPER (NVL (TRIM (pv_brand_v), brand))
               AND xps.oracle_status = 'N'
               AND NVL (attribute4, 'XX') <> 'HIERARCHY_UPDATE'
               -- W.r.t Version 1.34
               AND request_id IS NULL;

            ln_count := SQL%ROWCOUNT;
         EXCEPTION
            WHEN OTHERS
            THEN
               fnd_file.put_line
                  (fnd_file.LOG,
                      'Error Ocuured While Updating Staging Table With Concurrent Request id - '
                   || SQLERRM
                  );
         END;
      END IF;

      COMMIT;

      IF ln_count >= 1
      THEN
         BEGIN
            UPDATE xxdo.xxdo_plm_size_stg siz
               SET request_id = gn_conc_request_id
             WHERE 1 = 1
               AND EXISTS (
                      SELECT 1
                        FROM xxdo.xxdo_plm_staging stg
                       WHERE stg.request_id = gn_conc_request_id
                         AND siz.parent_record_id = stg.record_id)
               AND request_id IS NULL;

            gn_tot_records_procs := SQL%ROWCOUNT;
            gn_cat_process_works := CEIL (gn_tot_records_procs * 20 / 20);
            fnd_file.put_line (fnd_file.LOG,
                                  ' gn_tot_records_procs '
                               || gn_tot_records_procs
                               || ' gn_cat_process_works '
                               || gn_cat_process_works
                              );
         EXCEPTION
            WHEN OTHERS
            THEN
               fnd_file.put_line
                  (fnd_file.LOG,
                      'Error Ocuured While Updating xxdo_plm_size_stg table With Concurrent Request id - '
                   || SQLERRM
                  );
         END;

         BEGIN
            UPDATE xxdo.xxdo_plm_region_stg reg
               SET request_id = gn_conc_request_id
             WHERE 1 = 1
               AND EXISTS (
                      SELECT 1
                        FROM xxdo.xxdo_plm_staging stg
                       WHERE stg.request_id = gn_conc_request_id
                         AND reg.parent_record_id = stg.record_id)
               AND request_id IS NULL;
         EXCEPTION
            WHEN OTHERS
            THEN
               fnd_file.put_line
                  (fnd_file.LOG,
                      'Error Ocuured While Updating xxdo_plm_region_stg table With Concurrent Request id - '
                   || SQLERRM
                  );
         END;

         COMMIT;

         BEGIN
            UPDATE xxdo.xxdo_plm_staging xsis
               SET oracle_status = 'D',
                   oracle_error_message =
                      'Ignoring this record as there exists with lastest date',
                   date_updated = SYSDATE
             WHERE xsis.request_id = gn_conc_request_id
               AND xsis.oracle_status = 'N'
               AND xsis.date_created NOT IN (
                      SELECT MAX (date_created)
                        FROM xxdo.xxdo_plm_staging xsis1
                       WHERE xsis1.style = xsis.style
                         AND NVL (xsis1.colorway, '-XXX') =
                                                   NVL (xsis.colorway, '-XXX')
                         -- AND xsis1.colorway_state = xsis.colorway_state  -- W.r.t Version 1.17
                         AND xsis1.oracle_status = 'N'
                         AND xsis1.request_id = gn_conc_request_id);
         EXCEPTION
            WHEN OTHERS
            THEN
               fnd_file.put_line
                  (fnd_file.LOG,
                      'Error in Updating Old Record to Ignore Items Staging Table :: '
                   || SQLERRM
                  );
         END;

         COMMIT;

         BEGIN
            UPDATE xxdo.xxdo_plm_staging xsis
               SET oracle_status = 'D',
                   oracle_error_message = 'Duplicate Record',
                   date_updated = SYSDATE
             WHERE xsis.request_id = gn_conc_request_id
               AND xsis.oracle_status = 'N'
               -- AND ROWID NOT IN (  -- bug as part of 1.39
               --    SELECT MAX (ROWID)
               AND record_id NOT IN (
                      SELECT MAX (record_id)
                        FROM xxdo.xxdo_plm_staging xsis1
                       WHERE xsis1.request_id = gn_conc_request_id
                         AND xsis1.oracle_status = 'N'
                         AND xsis1.style = xsis.style
                         AND NVL (xsis1.colorway, '-XXX') =
                                                   NVL (xsis.colorway, '-XXX')
                         --AND xsis1.colorway_state = xsis.colorway_state -- W.r.t Version 1.17
                         AND xsis1.date_created = xsis.date_created);
         EXCEPTION
            WHEN OTHERS
            THEN
               fnd_file.put_line
                  (fnd_file.LOG,
                      'Error in Updating Duplicate Record to Ignore for ITEMS Staging Table :: '
                   || SQLERRM
                  );
         END;

         BEGIN                                      --Start W.r.t Version 1.24
            UPDATE xxdo.xxdo_plm_staging xsis
               SET oracle_status = 'F',
                   oracle_error_message =
                         SUBSTR (oracle_error_message, 1, 500)
                      || 'Item Type Is not Available ',
                   date_updated = SYSDATE
             WHERE 1 = 1
               AND EXISTS (
                      SELECT 1
                        FROM xxdo.xxdo_plm_size_stg siz
                       WHERE siz.parent_record_id = xsis.record_id
                         AND siz.request_id = gn_conc_request_id
                         AND item_type IS NULL)
               AND xsis.request_id = gn_conc_request_id
               AND xsis.oracle_status = 'N';
         EXCEPTION
            WHEN OTHERS
            THEN
               fnd_file.put_line
                  (fnd_file.LOG,
                      'Error in Updating Record to Fail for Item Type Is not Available  Staging Table :: '
                   || SQLERRM
                  );
         END;

         BEGIN
            UPDATE xxdo.xxdo_plm_staging xsis
               SET oracle_status = 'F',
                   oracle_error_message =
                         SUBSTR (oracle_error_message, 1, 500)
                      || ' Style/ Style description Is not Available ',
                   date_updated = SYSDATE
             WHERE xsis.request_id = gn_conc_request_id
               AND xsis.oracle_status = 'N'
               AND (style IS NULL OR style_description IS NULL);
         --W.r.t Version 1.25
         EXCEPTION
            WHEN OTHERS
            THEN
               fnd_file.put_line
                  (fnd_file.LOG,
                      'Error in Updating to Fail for Item Type Is not Available Staging Table :: '
                   || SQLERRM
                  );
         END;                                         --End W.r.t Version 1.24

         COMMIT;

--**********************************************************************************
-- Calling  pre_process_validation procedure to create OM sales category,tariff code,
-- season,region,categories
--**********************************************************************************
         IF UPPER (NVL (gv_reprocess, 'N')) IN ('N', 'NO')
         THEN
            BEGIN
               pre_process_validation (pv_brand_v,
                                       pv_style_v,
                                       pv_reterror,
                                       pv_retcode
                                      );

               IF pv_reterror IS NOT NULL OR pv_retcode IS NOT NULL
               THEN
                  fnd_file.put_line
                                (fnd_file.LOG,
                                    'Error Ocurred In pre process validation'
                                 || pv_reterror
                                );
               END IF;
            EXCEPTION
               WHEN OTHERS
               THEN
                  fnd_file.put_line
                                   (fnd_file.LOG,
                                       ' Error in pre_process_validation :: '
                                    || SQLERRM
                                   );
            END;
         END IF;

         /* -- START : Commented for 1.22.
         --***************************************************
         --Getting category id for INVENTORY Item Category
         --***************************************************
                  BEGIN
                     SELECT structure_id, category_set_id
                       INTO ln_cat_struc_id, ln_category_set_id
                       FROM mtl_category_sets
                      WHERE UPPER (category_set_name) = 'INVENTORY';
                  EXCEPTION
                     WHEN NO_DATA_FOUND
                     THEN
                        fnd_file.put_line (fnd_file.LOG,
                                              'INVENTORY Item Category not found'
                                           || SQLERRM
                                          );
                     WHEN OTHERS
                     THEN
                        fnd_file.put_line
                           (fnd_file.LOG,
                               ' Error Occured while retrieving the structure id for INVENTORY Item Category '
                            || SQLERRM
                           );
                  END;
         */
         -- START : Commented for 1.22.
         ln_category_set_id := gn_inventory_set_id;         -- Added for 1.22.
         ln_cat_struc_id := gn_inventory_structure_id;      -- Added for 1.22.

--***************************************************
--Getting price list id for Wholesale - US
--***************************************************
         BEGIN
            gv_retcode := NULL;
            gv_reterror := NULL;
            lv_error_mesg := NULL;

            --Start W.r.t Version 1.3
            SELECT list_header_id
              INTO gn_wsale_pricelist_id
              FROM apps.qp_list_headers_tl
             WHERE NAME =
                      fnd_profile.VALUE
                         ('XXDO_WHOLESALE_PRICELIST')
                                             --NAME = 'US-MASTERWHOLESALE-USD'
               AND LANGUAGE = 'US';
            /*
         SELECT fnd_profile.VALUE ('XXDO_WHOLESALE_PRICELIST')
           INTO gn_wsale_pricelist_id
           FROM DUAL;
           */
            --End W.r.t Version 1.3
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               gn_wsale_pricelist_id := NULL;
               fnd_file.put_line
                            (fnd_file.LOG,
                                ' Wholesale - US price id is not configured '
                             || SQLERRM
                            );
            WHEN OTHERS
            THEN
               gn_wsale_pricelist_id := NULL;
               fnd_file.put_line
                  (fnd_file.LOG,
                      ' Exception Error Occured while retrieving Wholesale -US price id'
                   || SQLERRM
                  );
         END;

--***************************************************
--Getting price list id for Retail - US
--***************************************************
         BEGIN
            --Start W.r.t Version 1.3
            SELECT list_header_id
              INTO gn_rtl_pricelist_id
              FROM apps.qp_list_headers_tl
             WHERE NAME =
                      fnd_profile.VALUE
                                ('XXDO_RETAIL_PRICELIST')
                                                        --NAME = 'Retail - US'
               AND LANGUAGE = 'US';
           /*
         SELECT fnd_profile.VALUE ('XXDO_RETAIL_PRICELIST')
           INTO gn_rtl_pricelist_id
           FROM DUAL;
           */
           -- End W.r.t Version 1.3
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               gn_rtl_pricelist_id := NULL;
               fnd_file.put_line
                               (fnd_file.LOG,
                                   ' Retail - US price id is not configured '
                                || SQLERRM
                               );
            WHEN OTHERS
            THEN
               gn_rtl_pricelist_id := NULL;
               fnd_file.put_line
                  (fnd_file.LOG,
                      ' Exception Error Occured while retrieving Retail - US price id'
                   || SQLERRM
                  );
         END;

         fnd_file.put_line (fnd_file.LOG,
                               '*********Main Cursor csr_plm_data started at '
                            || TO_CHAR (SYSDATE, 'DD-MM-YYYY HH24:MI:SS')
                           );

         FOR rec_plm_data IN csr_plm_data
         LOOP
            lv_flag := NULL;
            lv_value := 0;
            ln_vendor_id := NULL;
            ln_vendor_site_id := NULL;
            lv_user_item_type := NULL;
            ln_inv_item_cat_id := NULL;                           --W.r.t 1.2
            lv_uom := NULL;                                       --W.r.t 1.2
            lv_item_type :=
                          UPPER (NVL (rec_plm_data.inv_item_type, 'GENERIC'));
            lv_item_desc := UPPER (TRIM (rec_plm_data.style_description));
            gv_pricing_logic := rec_plm_data.attribute2;          --W.r.t 1.7
            lv_style := rec_plm_data.style;                       --W.r.t 1.9
            gn_record_id := rec_plm_data.record_id;              --W.r.t 1.12
            gv_plm_style := rec_plm_data.style;                  --W.r.t 1.12
            gv_color_code := rec_plm_data.colorway;              --W.r.t 1.12
            gv_season := rec_plm_data.current_season;            --W.r.t 1.12
            gn_plm_rec_id := rec_plm_data.record_id;             --W.r.t 1.14
            gv_colorway_state := UPPER (rec_plm_data.colorway_state);
            gv_style_intro_date := rec_plm_data.intro_date;      --W.r.t 1.42
            gv_licensees := NVL (rec_plm_data.attribute3, 'N');  --W.r.t 1.43
            --W.r.t 1.12
            msg (   ' lv_item_type '
                 || lv_item_type
                 || ' Size '
                 || rec_plm_data.size_num
                 || ' Record id '
                 || rec_plm_data.record_id
                 || ' Style '
                 || rec_plm_data.style
                );

            IF rec_plm_data.style_description IS NULL
            THEN
               fnd_file.put_line (fnd_file.LOG,
                                     'Item Discription is null for record '
                                  || rec_plm_data.record_id
                                 );
            END IF;

--**************************************
--Deriving user item type
--**************************************
            IF UPPER (rec_plm_data.colorway_state) = 'ILR'
            THEN
               lv_user_item_type := 'GENERIC';
            ELSIF     UPPER (rec_plm_data.colorway_state) IN ('FLR', 'AP')
                  AND lv_item_type = 'SAMPLE'
            THEN
               lv_user_item_type := 'SAMPLE';
            ELSIF     UPPER (rec_plm_data.colorway_state) IN ('FLR', 'AP')
                  AND lv_item_type = 'PROD'                        -- 'SAMPLE'
            THEN
               lv_user_item_type := 'PROD';
            -- ELSIF     UPPER (rec_plm_data.colorway_state) = 'SM' --W.r.t Version 1.1
            ELSIF     UPPER (rec_plm_data.colorway_state) =
                                              'PRODUCTION'
                                                          --W.r.t Version 1.13
                  AND lv_item_type = 'B-GRADE'
            THEN
               lv_user_item_type := 'BGRADE';
               -- lv_style := 'BG' || lv_style;              -- W.r.t Version 1.9
               lv_style := lv_style;                    -- Modified for 1.11.
            -- ELSIF     UPPER (rec_plm_data.colorway_state) = 'SM'
            ELSIF     UPPER (rec_plm_data.colorway_state) =
                                              'PRODUCTION'
                                                          --W.r.t Version 1.13
                  AND lv_item_type = 'SAMPLE'
            THEN
               lv_user_item_type := 'SAMPLE';
            --  ELSIF     UPPER (rec_plm_data.colorway_state) = 'SM'
            ELSIF     UPPER (rec_plm_data.colorway_state) =
                                              'PRODUCTION'
                                                          --W.r.t Version 1.13
                  AND lv_item_type = 'PROD'
            THEN
               lv_user_item_type := 'PROD';
            ELSIF UPPER (rec_plm_data.colorway_state) = 'RETIRE'
            THEN
               -- lv_user_item_type := 'INACTIVE'; --1.5
               lv_user_item_type := UPPER (lv_item_type);               --1.5
            -- START : Added for 1.23
            ELSIF rec_plm_data.colorway_state IS NULL
            THEN
               BEGIN
                  UPDATE xxdo.xxdo_plm_staging xps
                     SET oracle_error_message =
                            SUBSTR
                               (   oracle_error_message
                                || ' Colorway State is required for processing : '
                                || rec_plm_data.style
                                || '-'
                                || rec_plm_data.colorway
                                || '-'
                                || rec_plm_data.size_num,
                                1,
                                3000
                               ),
                         date_updated = SYSDATE,
                         xps.oracle_status = 'F'
                   WHERE record_id = rec_plm_data.record_id
                     AND request_id = gn_conc_request_id
                     AND xps.oracle_status = 'N';
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     fnd_file.put_line
                           (fnd_file.LOG,
                               'Unable to update the record status to Error '
                            || SQLERRM
                           );
               END;

               lv_error_mesg :=
                     ' Colorway State is required for processing : '
                  --Start W.r.t VErsion 1.23
                  || rec_plm_data.style
                  || '-'
                  || rec_plm_data.colorway
                  || '-'
                  || rec_plm_data.size_num;
               log_error_exception (pv_procedure_name      => lv_pn,
                                    pv_plm_row_id          => rec_plm_data.record_id,
                                    pv_operation_code      => gv_op_name,
                                    pv_operation_key       => gv_op_key,
                                    pv_style               => rec_plm_data.style,
                                    pv_color               => rec_plm_data.colorway,
                                    pv_size                => rec_plm_data.size_num,
                                    pv_brand               => rec_plm_data.brand,
                                    pv_gender              => rec_plm_data.division,
                                    pv_season              => rec_plm_data.current_season,
                                    pv_reterror            => lv_error_mesg,
                                    pv_error_code          => 'REPORT',
                                    pv_error_type          => 'SYSTEM'
                                   );               --Start W.r.t VErsion 1.23
               COMMIT;
               CONTINUE;
            -- END : Added for 1.23.
            ELSE
               BEGIN
                  UPDATE xxdo.xxdo_plm_staging xps
                     SET oracle_error_message =
                            SUBSTR
                               (   oracle_error_message
                                --   || ' Not a valid Life cycle for size '   --    Commented for 1.22.
                                || ' Not a valid Life Cycle or Item Type for : '
                                -- Modified for 1.22.
                                --   || rec_plm_data.size_num,    -- Commented for 1.22.
                                || rec_plm_data.style
                                || '-'
                                || rec_plm_data.colorway
                                || '-'
                                || rec_plm_data.size_num,
                                -- Modified for 1.22.
                                1,
                                3000
                               ),
                         date_updated = SYSDATE
                   WHERE record_id = rec_plm_data.record_id
                     AND request_id = gn_conc_request_id   -- Added for  1.22.
                     AND xps.oracle_status = 'N';
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     fnd_file.put_line
                           (fnd_file.LOG,
                               'Unable to update the record status to Error '
                            || SQLERRM
                           );
               END;

               lv_error_mesg :=
                     ' Not a valid Life Cycle or Item Type for : '
                  -- --Start W.r.t VErsion 1.23
                  || rec_plm_data.style
                  || '-'
                  || rec_plm_data.colorway
                  || '-'
                  || rec_plm_data.size_num;
               log_error_exception (pv_procedure_name      => lv_pn,
                                    pv_plm_row_id          => rec_plm_data.record_id,
                                    pv_operation_code      => gv_op_name,
                                    pv_operation_key       => gv_op_key,
                                    pv_style               => rec_plm_data.style,
                                    pv_color               => rec_plm_data.colorway,
                                    pv_size                => rec_plm_data.size_num,
                                    pv_brand               => rec_plm_data.brand,
                                    pv_gender              => rec_plm_data.division,
                                    pv_season              => rec_plm_data.current_season,
                                    pv_reterror            => lv_error_mesg,
                                    pv_error_code          => 'REPORT',
                                    pv_error_type          => 'SYSTEM'
                                   );            -- --Start W.r.t VErsion 1.23
               COMMIT;
               CONTINUE;                                   -- Added for  1.22.
            END IF;

--******************************************************
-- Fetching vendor id
--****************************************************
            gv_op_key := 'Record ID: ' || rec_plm_data.record_id;
            gv_op_name := ' Fetching vendor id ';
--******************************************************
-- Fetching vendor site id
--****************************************************
            gv_op_name := ' Fetching vendor site id ';

            --BEGIN
            --   SELECT vendor_id,vendor_site_id
            --     INTO ln_vendor_id,ln_vendor_site_id
            --     FROM po_vendor_sites_all
            --    WHERE UPPER(vendor_site_code) = UPPER (rec_plm_data.supplier) || '-' || UPPER (rec_plm_data.sourcing_factory)
            --      AND ROWNUM = 1;
            --EXCEPTION
            --   WHEN OTHERS
            --   THEN
            --      lv_error_mesg :=
            --              ' Error while fetching vendor id  ' || SQLERRM;
            --      log_error_exception
            --                        (pv_procedure_name      => lv_pn,
            --                         pv_plm_row_id          => rec_plm_data.record_id,
            --                         pv_operation_code      => gv_op_name,
            --                         pv_operation_key       => gv_op_key,
            --                         pv_reterror            => lv_error_mesg
            --                        );
            --      ln_vendor_site_id := NULL;
            --END;
            IF UPPER (NVL (gv_reprocess, 'N')) IN
                                              ('N', 'NO') --W.r.t Version 1.34
            THEN
--******************************************************
-- fetching the category id for PO item
--****************************************************
               gv_op_name := ' Fetching inventory category id ';

               BEGIN
                  SELECT category_id
                    INTO ln_inv_item_cat_id
                    FROM apps.mtl_categories_b
                   WHERE segment1 = rec_plm_data.brand
                     AND segment2 = rec_plm_data.division
                     AND segment3 = rec_plm_data.product_group
                     AND segment4 = rec_plm_data.CLASS
                     AND segment5 = rec_plm_data.sub_class
                     AND segment6 = rec_plm_data.master_style
                     AND segment7 = rec_plm_data.style
                     AND segment8 = rec_plm_data.color_description
                     AND structure_id = ln_cat_struc_id
                     AND NVL (enabled_flag, 'Y') = 'Y';
               EXCEPTION
                  WHEN NO_DATA_FOUND
                  THEN
                     ln_inv_item_cat_id := NULL;
                  WHEN OTHERS
                  THEN
                     lv_error_mesg :=
                           ' Error while fetching ln_inv_item_cat_id  '
                        || SQLERRM;
                     fnd_file.put_line (fnd_file.LOG, lv_error_mesg);
                     ln_inv_item_cat_id := NULL;
               END;
            END IF;

--******************************************************
--  Fetching Buyer id
--****************************************************
            gv_op_name := ' Forming Item number ';
            ln_retire_count := 0;                          --W.rt Version 1.24
            lv_item_number := NULL;
            lv_sam_item_number := NULL;
            lv_item_number :=

                  --  (TRIM (rec_plm_data.style))
                  (TRIM (lv_style))
               || '-'
               || (NVL (TRIM (rec_plm_data.colorway), 'ALL'))
               || '-'
               || NVL (rec_plm_data.size_num, 'ALL');
            lv_sam_item_number := lv_item_number;
            lv_style_name := rec_plm_data.style_name;

            IF UPPER (rec_plm_data.colorway_state) = 'RETIRE'
            --Start W.rt Version 1.24
            THEN
               BEGIN
                  SELECT COUNT (*)
                    INTO ln_retire_count
                    FROM mtl_system_items_b
                   WHERE segment1 = lv_item_number
                     AND organization_id = gn_master_orgid;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     ln_retire_count := 0;
               END;

               IF ln_retire_count = 0
               THEN
                  BEGIN
                     UPDATE xxdo.xxdo_plm_staging xps
                        SET oracle_error_message =
                               SUBSTR
                                   (   oracle_error_message
                                    || ' Item not present for Retire record '
                                    || lv_item_number
                                    || ' - | ',
                                    1,
                                    1500
                                   ),
                            date_updated = SYSDATE,
                            oracle_status = 'F'
                      WHERE record_id = rec_plm_data.record_id
                        AND request_id = gn_conc_request_id;
                  EXCEPTION
                     WHEN OTHERS
                     THEN
                        fnd_file.put_line
                           (fnd_file.LOG,
                               'Unable to update the record status to Error '
                            || SQLERRM
                           );
                  END;

                  CONTINUE;
               END IF;
            END IF;                                    --END W.rt Version 1.24

--**********************************************************
--CREATING PROD,SAMPLE,SAMPLE-LEFT,SAMPLE-RIGHT,BGRADE ITEMS --XXDO_TEMP_MAPPING
--**********************************************************
            IF UPPER (lv_item_type) = 'PROD'                       --'REGULAR'
            THEN
               lv_item_number := lv_item_number;
               lv_uom := rec_plm_data.uom;
            ELSIF     UPPER (lv_item_type) = 'SAMPLE'
                  AND UPPER (rec_plm_data.product_group) <> 'FOOTWEAR'
            THEN
               -- lv_item_number := lv_item_number || '-' || 'S';
               lv_item_number := 'SS' || lv_item_number;         -- W.r.t 1.9
               lv_style_name := 'SS' || UPPER (rec_plm_data.style_name);
               lv_uom := 'EA';
            ELSIF UPPER (lv_item_type) = 'B-GRADE'                -- W.r.t 1.1
            THEN
               -- lv_item_number := lv_item_number || '-' || 'BG'; -- W.r.t 1.9
               lv_item_number := lv_item_number;                 -- W.r.t 1.9
               -- lv_style_name := 'BG' || rec_plm_data.style_name;
               lv_style_name := rec_plm_data.style_name;
               -- Modified for 1.11.
               lv_uom := rec_plm_data.uom;
            ELSIF     UPPER (lv_item_type) = 'SAMPLE'
                  AND UPPER (rec_plm_data.product_group) = 'FOOTWEAR'
            THEN
               lv_uom := 'EA';
               lv_item_number := lv_item_number;
            ELSE
               lv_item_type := 'GENERIC';
               lv_item_number := lv_item_number;
               lv_uom := rec_plm_data.uom;
            END IF;

--*********************************************
--INSERT INTO xxdo_plm_itemast_stg table
--*********************************************
            gv_op_name := 'Inserting Record to internal staging table ';

            IF     UPPER (lv_item_type) = 'SAMPLE'
               AND UPPER (rec_plm_data.product_group) = 'FOOTWEAR'
            THEN
               -- Start
               BEGIN
                  --lv_item_number := lv_sam_item_number || '-' || 'S';
                  lv_item_number := 'SS' || lv_sam_item_number;
                  lv_style_name := 'SS' || UPPER (rec_plm_data.style_name);
                  gv_retcode := NULL;
                  gv_reterror := NULL;
                  ln_item_id := NULL;
                  ln_wholesale_price := rec_plm_data.wholesale_price / 2;
                  --W.r.t Version 1.28
                  ln_fob := rec_plm_data.projected_cost;
                  ln_landed_cost := rec_plm_data.landed_cost;

                  IF rec_plm_data.attribute6 IS NOT NULL --w.r.t version 1.45
                  THEN
                     ln_pur_cost := rec_plm_data.attribute6;
                  ELSE
                     ln_pur_cost := rec_plm_data.purchase_cost;
                  END IF;                                 --w.r.t version 1.45

                  lv_uom := 'PR';                          --W.r.t Version 1.3
                  --lv_uom := 'EA';   --W.r.t Version 1.3
                  plm_insert_msii_stg
                     (pn_record_id                  => rec_plm_data.record_id,
                      pn_batch_id                   => rec_plm_data.batch_id,
                      pv_style                      =>    'SS'
                                                       || rec_plm_data.style,
                      pv_master_style               => rec_plm_data.master_style,
                      pn_scale_code_id              => rec_plm_data.size_sort_code,
                      pv_color                      => rec_plm_data.colorway,
                      pv_colorway                   => rec_plm_data.color_description,
                      pv_subgroup                   => rec_plm_data.sub_group,
                      pv_size                       => rec_plm_data.size_num,
                      pv_inv_type                   => UPPER (lv_item_type),
                      pv_brand                      => rec_plm_data.brand,
                      pv_product_group              => rec_plm_data.product_group,
                      pv_class                      => rec_plm_data.CLASS,
                      pv_subclass                   => rec_plm_data.sub_class,
                      pv_region                     => rec_plm_data.region,
                      pv_gender                     => rec_plm_data.division,
                      pn_projectedcost              => ln_fob,
                      pn_landedcost                 => ln_landed_cost,
                      pv_templateid                 => ln_template_id,
                      pv_styledescription           => rec_plm_data.style_description,
                      pv_currentseason              => rec_plm_data.current_season,
                      pv_begin_date                 => rec_plm_data.begin_date,
                      pv_end_date                   => rec_plm_data.end_date,
                      pv_uom                        => lv_uom,
                      pv_contry_code                => rec_plm_data.country_of_origin,
                      pv_factory                    => rec_plm_data.sourcing_factory,
                      pv_rank                       => rec_plm_data.souc_rule,
                      pv_colorwaystatus             => rec_plm_data.colorway_status,
                      pn_tarrif                     => rec_plm_data.tariff_code,
                      pn_wholesale_price            => ln_wholesale_price,
                      pn_retail_price               => rec_plm_data.retail_price,
                      pv_upc                        => NULL,
                      --  pn_purchase_cost              => rec_plm_data.purchase_cost,
                      pn_purchase_cost              => ln_pur_cost,
                                                          --w.r.t Version 1.45
                      pv_item_number                => lv_item_number,
                      pv_item_status                => lv_item_status,
                      pv_cost_type                  => rec_plm_data.cst_type,
                      pn_buyer_id                   => ln_buyer_id,
                      pv_project_type               => rec_plm_data.project_type,
                      pv_collection                 => rec_plm_data.collection,
                      pv_item_type                  => rec_plm_data.item_type,
                      pv_supplier                   => rec_plm_data.supplier,
                      pv_production_line            => rec_plm_data.production_line,
                      pv_size_scale_id              => rec_plm_data.sizing,
                      pv_detail_silhouette          => rec_plm_data.detail_silhouette,
                      pv_sub_division               => rec_plm_data.sub_group,
                      pv_lead_time                  => rec_plm_data.lead_time,
                      pv_lifecycle                  => rec_plm_data.colorway_state,
                      pv_user_item_type             => lv_user_item_type,
                      pn_vendor_id                  => ln_vendor_id,
                      pn_vendor_site_id             => ln_vendor_site_id,
                      -- pv_sourcing_flag              => lv_source_rule_flag,
                      pv_sourcing_flag              => rec_plm_data.attribute2,
                      --W.r.t Version 1.32
                      pn_po_item_cat_id             => ln_inv_item_cat_id,
                      pv_purchasing_start_date      => rec_plm_data.purchasing_start_date,
                      pv_purchasing_end_date        => rec_plm_data.purchasing_end_date,
                      pv_tariff_country_code        => rec_plm_data.tariff_country_code,
                      pv_style_name                 => lv_style_name,
                      --Start W.r.t Version 1.40
                      pv_nrf_color_code             => rec_plm_data.nrf_color_code,
                      pv_nrf_description            => rec_plm_data.nrf_description,
                      pv_nrf_size_code              => rec_plm_data.nrf_size_code,
                      pv_nrf_size_description       => rec_plm_data.nrf_size_description,
                      pv_intro_date                 => rec_plm_data.intro_date,
                      pv_tq_sourcing_name           => rec_plm_data.attribute5,
                      pv_disable_auto_upc           => gv_licensees,
                                                          --w.r.t Version 1.47
                      pv_ats_date                   => rec_plm_data.attribute7,
                                                          --w.r.t Version 1.47
                      pv_retcode                    => gv_retcode,
                      pv_reterror                   => gv_reterror
                     );
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     gv_reterror := SQLERRM;
                     gv_retcode := SQLCODE;
               END;

               -- End
               ln_wholesale_price := rec_plm_data.wholesale_price / 4;
               ln_fob := rec_plm_data.projected_cost / 2;
               ln_landed_cost := rec_plm_data.landed_cost / 2;

               IF rec_plm_data.attribute6 IS NOT NULL     --w.r.t version 1.45
               THEN
                  ln_pur_cost := rec_plm_data.attribute6 / 2;
               ELSE
                  ln_pur_cost := rec_plm_data.purchase_cost / 2;
               END IF;

               -- W.r.t Version 1.3
               lv_uom := 'EA';

               BEGIN
                  --lv_item_number := lv_sam_item_number || '-' || 'SL';
                  lv_item_number := 'SL' || lv_sam_item_number;
                  --W.r.t Version 1.9
                  lv_style_name := 'SL' || UPPER (rec_plm_data.style_name);
                  --W.r.t Version 1.9
                  gv_retcode := NULL;
                  gv_reterror := NULL;
                  ln_item_id := NULL;
                  plm_insert_msii_stg
                     (pn_record_id                  => rec_plm_data.record_id,
                      pn_batch_id                   => rec_plm_data.batch_id,
                      pv_style                      =>    'SL'
                                                       || rec_plm_data.style,
                      pv_master_style               => rec_plm_data.master_style,
                      pn_scale_code_id              => rec_plm_data.size_sort_code,
                      pv_color                      => rec_plm_data.colorway,
                      pv_colorway                   => rec_plm_data.color_description,
                      pv_subgroup                   => rec_plm_data.sub_group,
                      pv_size                       => rec_plm_data.size_num,
                      pv_inv_type                   => UPPER (lv_item_type),
                      pv_brand                      => rec_plm_data.brand,
                      pv_product_group              => rec_plm_data.product_group,
                      pv_class                      => rec_plm_data.CLASS,
                      pv_subclass                   => rec_plm_data.sub_class,
                      pv_region                     => rec_plm_data.region,
                      pv_gender                     => rec_plm_data.division,
                      pn_projectedcost              => ln_fob,
                      pn_landedcost                 => ln_landed_cost,
                      pv_templateid                 => ln_template_id,
                      pv_styledescription           => rec_plm_data.style_description,
                      pv_currentseason              => rec_plm_data.current_season,
                      pv_begin_date                 => rec_plm_data.begin_date,
                      pv_end_date                   => rec_plm_data.end_date,
                      pv_uom                        => lv_uom,
                      pv_contry_code                => rec_plm_data.country_of_origin,
                      pv_factory                    => rec_plm_data.sourcing_factory,
                      pv_rank                       => rec_plm_data.souc_rule,
                      pv_colorwaystatus             => rec_plm_data.colorway_status,
                      pn_tarrif                     => rec_plm_data.tariff_code,
                      pn_wholesale_price            => ln_wholesale_price,
                      pn_retail_price               => rec_plm_data.retail_price,
                      pv_upc                        => NULL,
                      --pn_purchase_cost              => rec_plm_data.purchase_cost,
                      pn_purchase_cost              => ln_pur_cost,
                      pv_item_number                => lv_item_number,
                      pv_item_status                => lv_item_status,
                      pv_cost_type                  => rec_plm_data.cst_type,
                      pn_buyer_id                   => ln_buyer_id,
                      pv_project_type               => rec_plm_data.project_type,
                      pv_collection                 => rec_plm_data.collection,
                      pv_item_type                  => rec_plm_data.item_type,
                      pv_supplier                   => rec_plm_data.supplier,
                      pv_production_line            => rec_plm_data.production_line,
                      pv_size_scale_id              => rec_plm_data.sizing,
                      pv_detail_silhouette          => rec_plm_data.detail_silhouette,
                      pv_sub_division               => rec_plm_data.sub_group,
                      pv_lead_time                  => rec_plm_data.lead_time,
                      pv_lifecycle                  => rec_plm_data.colorway_state,
                      pv_user_item_type             => lv_user_item_type,
                      pn_vendor_id                  => ln_vendor_id,
                      pn_vendor_site_id             => ln_vendor_site_id,
                      pv_sourcing_flag              => rec_plm_data.attribute2,
                      --W.r.t Version 1.32
                      --pv_sourcing_flag              => lv_source_rule_flag,
                      pn_po_item_cat_id             => ln_inv_item_cat_id,
                      pv_purchasing_start_date      => rec_plm_data.purchasing_start_date,
                      pv_purchasing_end_date        => rec_plm_data.purchasing_end_date,
                      pv_tariff_country_code        => rec_plm_data.tariff_country_code,
                      pv_style_name                 => lv_style_name,
                      --Start W.r.t Version 1.40
                      pv_nrf_color_code             => rec_plm_data.nrf_color_code,
                      pv_nrf_description            => rec_plm_data.nrf_description,
                      pv_nrf_size_code              => rec_plm_data.nrf_size_code,
                      pv_nrf_size_description       => rec_plm_data.nrf_size_description,
                      pv_intro_date                 => rec_plm_data.intro_date,
                      pv_tq_sourcing_name           => rec_plm_data.attribute5,
                      pv_disable_auto_upc           => gv_licensees,
                                                          --w.r.t Version 1.47
                      pv_ats_date                   => rec_plm_data.attribute7,
                                                          --w.r.t Version 1.48
                      pv_retcode                    => gv_retcode,
                      pv_reterror                   => gv_reterror
                     );
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     gv_reterror := SQLERRM;
                     gv_retcode := SQLCODE;
               END;

               BEGIN
                  --lv_item_number := lv_sam_item_number || '-' || 'SR';
                  lv_item_number := 'SR' || lv_sam_item_number;
                  --W.r.t Version 1.9
                  lv_style_name := 'SR' || UPPER (rec_plm_data.style_name);
                  --W.r.t Version 1.9
                  gv_retcode := NULL;
                  gv_reterror := NULL;
                  ln_item_id := NULL;
                  plm_insert_msii_stg
                     (pn_record_id                  => rec_plm_data.record_id,
                      pn_batch_id                   => rec_plm_data.batch_id,
                      pv_style                      =>    'SR'
                                                       || rec_plm_data.style,
                      pv_master_style               => rec_plm_data.master_style,
                      pn_scale_code_id              => rec_plm_data.size_sort_code,
                      pv_color                      => rec_plm_data.colorway,
                      pv_colorway                   => rec_plm_data.color_description,
                      pv_subgroup                   => rec_plm_data.sub_group,
                      pv_size                       => rec_plm_data.size_num,
                      pv_inv_type                   => UPPER (lv_item_type),
                      pv_brand                      => rec_plm_data.brand,
                      pv_product_group              => rec_plm_data.product_group,
                      pv_class                      => rec_plm_data.CLASS,
                      pv_subclass                   => rec_plm_data.sub_class,
                      pv_region                     => rec_plm_data.region,
                      pv_gender                     => rec_plm_data.division,
                      pn_projectedcost              => ln_fob,
                      pn_landedcost                 => ln_landed_cost,
                      pv_templateid                 => ln_template_id,
                      pv_styledescription           => rec_plm_data.style_description,
                      pv_currentseason              => rec_plm_data.current_season,
                      pv_begin_date                 => rec_plm_data.begin_date,
                      pv_end_date                   => rec_plm_data.end_date,
                      pv_uom                        => lv_uom,
                      pv_contry_code                => rec_plm_data.country_of_origin,
                      pv_factory                    => rec_plm_data.sourcing_factory,
                      pv_rank                       => rec_plm_data.souc_rule,
                      pv_colorwaystatus             => rec_plm_data.colorway_status,
                      pn_tarrif                     => rec_plm_data.tariff_code,
                      pn_wholesale_price            => ln_wholesale_price,
                      pn_retail_price               => rec_plm_data.retail_price,
                      pv_upc                        => NULL,
                      --pn_purchase_cost              => rec_plm_data.purchase_cost,  --W.r.t Version 1.3
                      pn_purchase_cost              => ln_pur_cost,
                      --W.r.t Version 1.3
                      pv_item_number                => lv_item_number,
                      pv_item_status                => lv_item_status,
                      pv_cost_type                  => rec_plm_data.cst_type,
                      pn_buyer_id                   => ln_buyer_id,
                      pv_project_type               => rec_plm_data.project_type,
                      pv_collection                 => rec_plm_data.collection,
                      pv_item_type                  => rec_plm_data.item_type,
                      pv_supplier                   => rec_plm_data.supplier,
                      pv_production_line            => rec_plm_data.production_line,
                      pv_size_scale_id              => rec_plm_data.sizing,
                      pv_detail_silhouette          => rec_plm_data.detail_silhouette,
                      pv_sub_division               => rec_plm_data.sub_group,
                      pv_lead_time                  => rec_plm_data.lead_time,
                      pv_lifecycle                  => rec_plm_data.colorway_state,
                      pv_user_item_type             => lv_user_item_type,
                      pn_vendor_id                  => ln_vendor_id,
                      pn_vendor_site_id             => ln_vendor_site_id,
                      --pv_sourcing_flag              => lv_source_rule_flag,
                      pv_sourcing_flag              => rec_plm_data.attribute2,
                      --W.r.t Version 1.32
                      pn_po_item_cat_id             => ln_inv_item_cat_id,
                      pv_purchasing_start_date      => rec_plm_data.purchasing_start_date,
                      pv_purchasing_end_date        => rec_plm_data.purchasing_end_date,
                      pv_tariff_country_code        => rec_plm_data.tariff_country_code,
                      pv_style_name                 => lv_style_name,
                      --Start W.r.t Version 1.40
                      pv_nrf_color_code             => rec_plm_data.nrf_color_code,
                      pv_nrf_description            => rec_plm_data.nrf_description,
                      pv_nrf_size_code              => rec_plm_data.nrf_size_code,
                      pv_nrf_size_description       => rec_plm_data.nrf_size_description,
                      pv_intro_date                 => rec_plm_data.intro_date,
                      pv_tq_sourcing_name           => rec_plm_data.attribute5,
                      pv_disable_auto_upc           => gv_licensees,
                                                          --w.r.t Version 1.47
                      pv_ats_date                   => rec_plm_data.attribute7,
                                                          --w.r.t Version 1.48
                      pv_retcode                    => gv_retcode,
                      pv_reterror                   => gv_reterror
                     );
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     gv_reterror := SQLERRM;
                     gv_retcode := SQLCODE;
               END;
            ELSE
               IF UPPER (lv_item_type) = 'SAMPLE'
               THEN
                  ln_fob := rec_plm_data.projected_cost;
                  ln_wholesale_price := rec_plm_data.wholesale_price / 2;
                  ln_landed_cost := rec_plm_data.landed_cost / 2;
                  lv_style_name := 'SS' || UPPER (rec_plm_data.style_name);
                  lv_sample_style := 'SS' || rec_plm_data.style;

                  IF rec_plm_data.attribute6 IS NOT NULL --w.r.t version 1.45
                  THEN
                     ln_pur_cost := rec_plm_data.attribute6;
                  ELSE
                     ln_pur_cost := rec_plm_data.purchase_cost;
                  END IF;
               --W.r.t Version 1.9
               ELSE
                  lv_sample_style := rec_plm_data.style;
                  ln_fob := rec_plm_data.projected_cost;
                  ln_wholesale_price := rec_plm_data.wholesale_price;
                  ln_landed_cost := rec_plm_data.landed_cost;
                  ln_pur_cost := rec_plm_data.purchase_cost;
                                                         --w.r.t version 1.45
               END IF;

               BEGIN
                  gv_retcode := NULL;
                  gv_reterror := NULL;
                  ln_item_id := NULL;
                  plm_insert_msii_stg
                     (pn_record_id                  => rec_plm_data.record_id,
                      pn_batch_id                   => rec_plm_data.batch_id,
                      pv_style                      => lv_sample_style,
                      pv_master_style               => rec_plm_data.master_style,
                      pn_scale_code_id              => rec_plm_data.size_sort_code,
                      pv_color                      => rec_plm_data.colorway,
                      pv_colorway                   => rec_plm_data.color_description,
                      pv_subgroup                   => rec_plm_data.sub_group,
                      pv_size                       => rec_plm_data.size_num,
                      pv_inv_type                   => UPPER (lv_item_type),
                      pv_brand                      => rec_plm_data.brand,
                      pv_product_group              => rec_plm_data.product_group,
                      pv_class                      => rec_plm_data.CLASS,
                      pv_subclass                   => rec_plm_data.sub_class,
                      pv_region                     => rec_plm_data.region,
                      pv_gender                     => rec_plm_data.division,
                      pn_projectedcost              => ln_fob,
                      pn_landedcost                 => ln_landed_cost,
                      pv_templateid                 => ln_template_id,
                      pv_styledescription           => rec_plm_data.style_description,
                      pv_currentseason              => rec_plm_data.current_season,
                      pv_begin_date                 => rec_plm_data.begin_date,
                      pv_end_date                   => rec_plm_data.end_date,
                      pv_uom                        => lv_uom,
                      pv_contry_code                => rec_plm_data.country_of_origin,
                      pv_factory                    => rec_plm_data.sourcing_factory,
                      pv_rank                       => rec_plm_data.souc_rule,
                      pv_colorwaystatus             => rec_plm_data.colorway_status,
                      pn_tarrif                     => rec_plm_data.tariff_code,
                      pn_wholesale_price            => ln_wholesale_price,
                      pn_retail_price               => rec_plm_data.retail_price,
                      pv_upc                        => NULL,
                      --  pn_purchase_cost              => rec_plm_data.purchase_cost,
                      pn_purchase_cost              => ln_pur_cost,
                                                          --w.r.t Version 1.45
                      pv_item_number                => lv_item_number,
                      pv_item_status                => lv_item_status,
                      pv_cost_type                  => rec_plm_data.cst_type,
                      pn_buyer_id                   => ln_buyer_id,
                      pv_project_type               => rec_plm_data.project_type,
                      pv_collection                 => rec_plm_data.collection,
                      pv_item_type                  => rec_plm_data.item_type,
                      pv_supplier                   => rec_plm_data.supplier,
                      pv_production_line            => rec_plm_data.production_line,
                      pv_size_scale_id              => rec_plm_data.sizing,
                      pv_detail_silhouette          => rec_plm_data.detail_silhouette,
                      pv_sub_division               => rec_plm_data.sub_group,
                      pv_lead_time                  => rec_plm_data.lead_time,
                      pv_lifecycle                  => rec_plm_data.colorway_state,
                      pv_user_item_type             => lv_user_item_type,
                      pn_vendor_id                  => ln_vendor_id,
                      pn_vendor_site_id             => ln_vendor_site_id,
                      --pv_sourcing_flag              => lv_source_rule_flag,
                      pv_sourcing_flag              => rec_plm_data.attribute2,
                      --W.r.t Version 1.32
                      pn_po_item_cat_id             => ln_inv_item_cat_id,
                      pv_purchasing_start_date      => rec_plm_data.purchasing_start_date,
                      pv_purchasing_end_date        => rec_plm_data.purchasing_end_date,
                      pv_tariff_country_code        => rec_plm_data.tariff_country_code,
                      pv_style_name                 => lv_style_name,
                      --Start W.r.t Version 1.40
                      pv_nrf_color_code             => rec_plm_data.nrf_color_code,
                      pv_nrf_description            => rec_plm_data.nrf_description,
                      pv_nrf_size_code              => rec_plm_data.nrf_size_code,
                      pv_nrf_size_description       => rec_plm_data.nrf_size_description,
                      pv_intro_date                 => rec_plm_data.intro_date,
                      pv_tq_sourcing_name           => rec_plm_data.attribute5,
                      pv_disable_auto_upc           => gv_licensees,
                                                          --w.r.t Version 1.47
                      pv_ats_date                   => rec_plm_data.attribute7,
                                                          --w.r.t Version 1.47
                      pv_retcode                    => gv_retcode,
                      pv_reterror                   => gv_reterror
                     );
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     gv_reterror := SQLERRM;
                     gv_retcode := SQLCODE;
               END;
            END IF;

            IF gv_retcode IS NOT NULL OR gv_reterror IS NOT NULL
            THEN
               BEGIN
                  lv_error_mesg :=
                     SUBSTR
                        (   'Error Ocurred While Inserting record to staging '
                         || rec_plm_data.record_id
                         || ' '
                         || gv_retcode
                         || ' '
                         || gv_reterror,
                         1,
                         2000
                        );
                  log_error_exception
                                    (pv_procedure_name      => lv_pn,
                                     pv_plm_row_id          => rec_plm_data.record_id,
                                     pv_operation_code      => gv_op_name,
                                     pv_operation_key       => gv_op_key,
                                     pv_style               => rec_plm_data.style,
                                     pv_color               => rec_plm_data.colorway,
                                     pv_size                => rec_plm_data.size_num,
                                     pv_brand               => rec_plm_data.brand,
                                     pv_gender              => rec_plm_data.division,
                                     pv_season              => rec_plm_data.current_season,
                                     pv_reterror            => lv_error_mesg,
                                     pv_error_code          => 'REPORT',
                                     pv_error_type          => 'SYSTEM'
                                    );
               END;
            END IF;
         END LOOP;

         fnd_file.put_line (fnd_file.LOG,
                               '*********Cursor csr_plm_data Ended at '
                            || TO_CHAR (SYSDATE, 'DD-MM-YYYY HH24:MI:SS')
                           );
--**********************************************************
--PROCESSING MASTER ORGANIZATIONS
--**********************************************************
         fnd_file.put_line
            (fnd_file.LOG,
                '*********Cursor csr_process_records for master Org started at '
             || TO_CHAR (SYSDATE, 'DD-MM-YYYY HH24:MI:SS')
            );

         FOR rec_process_records IN csr_process_records
         LOOP
            msg (   'After Entering csr_process_records :: '
                 || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                );
            --CHECKING FOR EXISTING ITEMS
            lv_error_message := NULL;
            ln_item_id := NULL;
            lv_transaction_type := NULL;
            lv_exist_item_status := NULL;
            gv_colorway_state := UPPER (rec_process_records.life_cycle);
            gv_style_intro_date := rec_process_records.intro_date;

            --W.r.t 1.17
            BEGIN
               SELECT inventory_item_id, inventory_item_status_code,
                      attribute16,
                      attribute24
                             --Corrected to intro season as part of CCR0006392
                 INTO ln_item_id, lv_exist_item_status,
                      lv_intro_season,
                      lv_intro_date
                 FROM mtl_system_items_b
                WHERE segment1 = rec_process_records.item_number
                  AND organization_id = gn_master_orgid;
            EXCEPTION
               WHEN NO_DATA_FOUND
               THEN
                  ln_item_id := NULL;
                  lv_exist_item_status := NULL;
                  lv_intro_season := NULL;
                  lv_intro_date := NULL;
               WHEN OTHERS
               THEN
                  ln_item_id := NULL;
                  lv_exist_item_status := NULL;
                  lv_intro_season := NULL;
                  lv_intro_date := NULL;
            END;

            IF ln_item_id IS NOT NULL
            THEN
               BEGIN
                  UPDATE xxdo.xxdo_plm_itemast_stg
                     SET stg_transaction_type = 'UPDATE',
                         item_id = ln_item_id
                   WHERE parent_record_id =
                                          rec_process_records.parent_record_id
                     AND seq_num = rec_process_records.seq_num;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     fnd_file.put_line
                        (fnd_file.LOG,
                            'Unable to update the stg_transaction_type to update '
                         || SQLERRM
                        );
               END;

               lv_transaction_type := 'UPDATE';
            ELSE
               lv_transaction_type := 'CREATE';
            END IF;

            BEGIN
               gv_retcode := NULL;
               gv_reterror := NULL;
               create_master_item
                         -- For Inserting into Interface Table for Master Org
                  (pv_item_number               => rec_process_records.item_number,
                   pv_item_desc                 => rec_process_records.styledescription,
                   pv_primary_uom               => rec_process_records.uom,
                   pv_item_type                 => rec_process_records.inventory_type,
                   pv_size_num                  => rec_process_records.size_val,
                   pv_org_code                  => gn_master_org_code,
                   pn_orgn_id                   => gn_master_orgid,
                   pn_inv_item_id               => NULL,
                   -- pv_buyer_code          => rec_process_records.buyer_id, --1.7
                   pv_buyer_code                => rec_process_records.factory,
                   --1.7
                   pv_planner_code              => lv_planner_code,
                   pv_record_status             => rec_process_records.colorwaystatus,
                   pn_template_id               => rec_process_records.templateid,
                   pv_project_cost              => rec_process_records.purchase_cost,
                   pv_style                     => rec_process_records.style,
                   pv_color_code                => rec_process_records.colorway,
                   pv_subdivision               => rec_process_records.sub_division,
                   pv_det_silho                 => rec_process_records.detail_silhouette,
                   pv_size_scale                => rec_process_records.size_scale_id,
                   pv_tran_type                 => lv_transaction_type,
                   pv_user_item_type            => UPPER
                                                      (rec_process_records.user_item_type
                                                      ),
                   pv_region                    => 'US',
                   pv_brand                     => rec_process_records.brand,
                   pv_department                => rec_process_records.product_group,
                   pv_upc                       => rec_process_records.upc,
                   pv_life_cycle                => rec_process_records.life_cycle,
                   pv_scale_code_id             => rec_process_records.scale_code_id,
                   pv_lead_time                 => rec_process_records.lead_time,
                   pv_current_season            => rec_process_records.currentseason,
                   pv_drop_in_season            => rec_process_records.colorwaystatus,
                   -- Added by Infosys on 09Sept2016 - Ver 1.35
                   pv_exist_item_status         => lv_exist_item_status,
                   -- Added by Infosys on 02Mar2017 - Ver 1.40
                   pv_nrf_color_code            => rec_process_records.nrf_color_code,
                   pv_nrf_description           => rec_process_records.nrf_description,
                   pv_nrf_size_code             => rec_process_records.nrf_size_code,
                   pv_nrf_size_description      => rec_process_records.nrf_size_description,
                   pv_intro_season              => lv_intro_season,
                                                          --w.r.t Version 1.42
                   pv_intro_date                => lv_intro_date,
                                                          --w.r.t Version 1.42
                   pv_disable_auto_upc          => rec_process_records.disable_auto_upc,
                                                          --w.r.t Version 1.47
                   pv_ats_date                  => rec_process_records.ats_date,
                                                          --w.r.t Version 1.48
                   xv_err_code                  => gv_retcode,
                   xv_err_msg                   => gv_reterror,
                   xn_item_id                   => ln_item_id,
                    pv_item_class                => rec_process_records.class,--1.51
                      pv_item_subclass             => rec_process_records.sub_class-- 1.51
                  );
            EXCEPTION
               WHEN OTHERS
               THEN
                  gv_reterror :=
                     SUBSTR (   'Exception Ocurred While Creating Item '
                             || rec_process_records.item_number
                             || ' '
                             || gv_retcode
                             || ' '
                             || SQLERRM,
                             1,
                             2000
                            );
            END;

            IF gv_retcode IS NOT NULL OR gv_reterror IS NOT NULL
            THEN
               BEGIN
                  lv_error_mesg :=
                           SUBSTR (gv_retcode || ' ' || gv_reterror, 1, 2000);
                  log_error_exception
                      (pv_procedure_name      => lv_pn,
                       pv_plm_row_id          => rec_process_records.parent_record_id,
                       pv_style               => rec_process_records.style,
                       pv_color               => rec_process_records.color_code,
                       pv_size                => rec_process_records.size_val,
                       pv_brand               => rec_process_records.brand,
                       pv_gender              => rec_process_records.gender,
                       pv_season              => rec_process_records.currentseason,
                       pv_reterror            => lv_error_mesg,
                       pv_error_code          => 'REPORT',
                       pv_error_type          => 'SYSTEM'
                      );
               END;

               /*
                              BEGIN
                                 UPDATE xxdo.xxdo_plm_itemast_stg
                                    SET error_message =
                                             SUBSTR (error_message || lv_error_mesg, 1, 3000)
                                  WHERE parent_record_id =
                                                         rec_process_records.parent_record_id
                                    AND seq_num = rec_process_records.seq_num;
                              EXCEPTION
                                 WHEN OTHERS
                                 THEN
                                    msg
                                       (   ' Error while Updating table xxdo_plm_itemast_stg '
                                        || SQLERRM
                                       );
                              END;

                              BEGIN
                                 UPDATE xxdo.xxdo_plm_staging
                                    SET oracle_error_message =
                                           SUBSTR (oracle_error_message || lv_error_mesg,
                                                   1,
                                                   3000
                                                  ),
                                        date_updated = SYSDATE
                                  WHERE record_id = rec_process_records.parent_record_id;
                              EXCEPTION
                                 WHEN OTHERS
                                 THEN
                                    msg (   ' Error while Updating table xxdo_plm_staging '
                                         || SQLERRM
                                        );
                              END;
                              */
               COMMIT;
            END IF;
         END LOOP;                -- End of csr_process_records for Master Org

         fnd_file.put_line
            (fnd_file.LOG,
                '*********Cursor csr_process_records for master Org Ended at '
             || TO_CHAR (SYSDATE, 'DD-MM-YYYY HH24:MI:SS')
            );

         -- Assigning Set Process Id for Master Org
         BEGIN
            xxdo_validate_and_batch (gv_retcode, gv_reterror);
         EXCEPTION
            WHEN OTHERS
            THEN
               fnd_file.put_line
                  (fnd_file.LOG,
                      'Error occurred while Validating and Grouping Batch logic for Items '
                   || SQLERRM
                  );
         END;

         -- Calling Import Items for Master Org
         BEGIN
            xxdo_import_items (gv_retcode, gv_reterror);
         EXCEPTION
            WHEN OTHERS
            THEN
               fnd_file.put_line (fnd_file.LOG,
                                     'Error occurred while Importing Items '
                                  || SQLERRM
                                 );
         END;

         -- Assigning Item Id to Item Master Staging table
         fnd_file.put_line
                       (fnd_file.LOG,
                           '*********Cursor csr_process_records 2 started at '
                        || TO_CHAR (SYSDATE, 'DD-MM-YYYY HH24:MI:SS')
                       );

         FOR rec_process_records IN csr_process_records
         LOOP
            ln_item_id := NULL;

            BEGIN
               SELECT inventory_item_id
                 INTO ln_item_id
                 FROM mtl_system_items_b
                WHERE segment1 = rec_process_records.item_number
                  AND organization_id = gn_master_orgid;
            EXCEPTION
               WHEN NO_DATA_FOUND
               THEN
                  ln_item_id := NULL;
               WHEN OTHERS
               THEN
                  ln_item_id := NULL;
            END;

            IF ln_item_id IS NOT NULL
            THEN
               BEGIN
                  UPDATE xxdo.xxdo_plm_itemast_stg
                     SET item_id = ln_item_id
                   WHERE parent_record_id =
                                          rec_process_records.parent_record_id
                     AND seq_num = rec_process_records.seq_num;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     fnd_file.put_line
                        (fnd_file.LOG,
                            'Unable to update the stg_transaction_type to update '
                         || SQLERRM
                        );
               END;

               COMMIT;
            END IF;
         END LOOP;                          -- End of csr_process_records loop

         fnd_file.put_line
            (fnd_file.LOG,
                '*********Cursor csr_process_records For Master Org Ended at '
             || TO_CHAR (SYSDATE, 'DD-MM-YYYY HH24:MI:SS')
            );
--*********************************************************************
--** Assign the child organizations to the Item.
--********************************************************************
         fnd_file.put_line
            (fnd_file.LOG,
                '*********Cursor csr_process_records for Child Orgs started at '
             || TO_CHAR (SYSDATE, 'DD-MM-YYYY HH24:MI:SS')
            );

         FOR rec_process_records IN csr_process_records
         LOOP
            -- Looping for All Child Orgs
            FOR child_rec IN csr_child_org (rec_process_records.seq_num)
            LOOP
               lv_error_message := NULL;
               ln_org_item_id := NULL;
               lv_exist_item_status := NULL;
               lv_transaction_type := NULL;
               gv_colorway_state := UPPER (rec_process_records.life_cycle);
                                                                 --W.r.t 1.17
               gv_style_intro_date := rec_process_records.intro_date;
               msg (' Create Child Items  ' || child_rec.item_number);

               --Get Master org values for Intro Season, Intro Season Date and ATS date. These will be propegated to child orgs.
               BEGIN                                 --Start w.r.t CCR0008053
                  SELECT attribute16, attribute24, attribute25
                    INTO lv_intro_season, lv_intro_date, lv_mast_ats_date
                    FROM mtl_system_items_b
                   WHERE segment1 = child_rec.item_number
                     AND organization_id = gn_master_orgid;
               EXCEPTION
                  WHEN NO_DATA_FOUND
                  THEN
                     lv_intro_season := NULL;
                     lv_intro_date := NULL;
                     lv_mast_ats_date := NULL;
                  WHEN OTHERS
                  THEN
                     lv_intro_season := NULL;
                     lv_intro_date := NULL;
                     lv_mast_ats_date := NULL;
               END;                                     --End w.r.t CCR0008053

               BEGIN
                  SELECT inventory_item_id, inventory_item_status_code
                    INTO ln_org_item_id, lv_exist_item_status
                    FROM mtl_system_items_b
                   WHERE segment1 = child_rec.item_number
                     AND organization_id = child_rec.organization_id;
               EXCEPTION
                  WHEN NO_DATA_FOUND
                  THEN
                     ln_org_item_id := NULL;
                     lv_exist_item_status := NULL;
                  WHEN OTHERS
                  THEN
                     ln_org_item_id := NULL;
                     lv_exist_item_status := NULL;
               END;

               IF ln_org_item_id IS NULL
               THEN
                  lv_transaction_type := 'CREATE';
               ELSE
                  lv_transaction_type := 'UPDATE';
               END IF;

               BEGIN
                  gv_retcode := NULL;
                  gv_reterror := NULL;
                  create_master_item                        -- For Child Orgs
                     (pv_item_number               => child_rec.item_number,
                      pv_item_desc                 => child_rec.styledescription,
                      pv_primary_uom               => child_rec.uom,
                      pv_item_type                 => rec_process_records.inventory_type,
                      --lv_item_type,
                      pv_size_num                  => child_rec.size_num,
                      pv_org_code                  => child_rec.organization_code,
                      pn_orgn_id                   => child_rec.organization_id,
                      pn_inv_item_id               => child_rec.item_id,
                      -- pv_buyer_code          => rec_process_records.buyer_id, --1.7
                      pv_buyer_code                => rec_process_records.factory,
                      --1.7
                      pv_planner_code              => lv_planner_code,
                      pv_record_status             => child_rec.colorwaystatus,
                      pn_template_id               => child_rec.templateid,
                      pv_project_cost              => child_rec.purchase_cost,
                      pv_style                     => child_rec.style,
                      pv_color_code                => child_rec.colorway,
                      pv_subdivision               => child_rec.sub_division,
                      pv_det_silho                 => child_rec.detail_silhouette,
                      pv_size_scale                => child_rec.size_scale_id,
                      pv_tran_type                 => lv_transaction_type,
                      pv_user_item_type            => UPPER
                                                         (rec_process_records.user_item_type
                                                         ),
                      pv_region                    => child_rec.region_name,
                      pv_brand                     => child_rec.brand,
                      pv_department                => child_rec.product_group,
                      pv_upc                       => rec_process_records.upc,
                      pv_life_cycle                => rec_process_records.life_cycle,
                      pv_scale_code_id             => rec_process_records.scale_code_id,
                      pv_lead_time                 => rec_process_records.lead_time,
                      pv_current_season            => rec_process_records.currentseason,
                      pv_drop_in_season            => rec_process_records.colorwaystatus,
                      -- Added by Infosys on 09Sept2016 - Ver 1.35
                      pv_exist_item_status         => lv_exist_item_status,
                      -- Added by Infosys on 02Mar2017 - Ver 1.40
                      pv_nrf_color_code            => rec_process_records.nrf_color_code,
                      pv_nrf_description           => rec_process_records.nrf_description,
                      pv_nrf_size_code             => rec_process_records.nrf_size_code,
                      pv_nrf_size_description      => rec_process_records.nrf_size_description,
                      pv_intro_season              => lv_intro_season,
                         --w.r.t Version 1.42 --from item master in MSIB v1.49
                      pv_intro_date                => lv_intro_date,
                        --w.r.t Version 1.42  --from item master in MSIB v1.49
                      pv_disable_auto_upc          => rec_process_records.disable_auto_upc,
                                                          --w.r.t Version 1.47
                      --pv_ats_date               => NVL(lv_mast_ats_date,rec_process_records.ATS_DATE),  --w.r.t Version 1.48 Commented for CCR0008053
                      pv_ats_date                  => lv_mast_ats_date,
                       --w.r.t CCR0008053     --from item master in MSIB v1.49
                      xv_err_code                  => gv_retcode,
                      xv_err_msg                   => gv_reterror,
                      xn_item_id                   => ln_item_id,
                      pv_item_class                => rec_process_records.class,--1.51
                      pv_item_subclass             => rec_process_records.sub_class-- 1.51
                     );
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     gv_reterror :=
                           ' Exception Ocurred While assigning Org '
                        || child_rec.organization_id
                        || ' To '
                        || rec_process_records.item_number
                        || ' - '
                        || SQLERRM;
               END;

               IF gv_retcode IS NOT NULL OR gv_reterror IS NOT NULL
               THEN
                  BEGIN
                     lv_error_mesg := gv_retcode || '  ' || gv_reterror;
                     log_error_exception
                                (pv_procedure_name      => lv_pn,
                                 pv_plm_row_id          => child_rec.parent_record_id,
                                 pv_style               => child_rec.style,
                                 pv_color               => child_rec.color_code,
                                 pv_size                => child_rec.size_num,
                                 pv_brand               => child_rec.brand,
                                 pv_gender              => child_rec.gender,
                                 pv_season              => child_rec.currentseason,
                                 pv_reterror            => lv_error_mesg,
                                 pv_error_code          => 'REPORT',
                                 pv_error_type          => 'SYSTEM'
                                );
                  END;
               /*
               BEGIN
               UPDATE xxdo.xxdo_plm_itemast_stg
                  SET error_message =
                           SUBSTR (error_message || lv_error_mesg, 1, 3000)
                WHERE seq_num = child_rec.seq_num
                  AND parent_record_id =
                                       rec_process_records.parent_record_id;



               UPDATE xxdo.xxdo_plm_staging
                  SET oracle_error_message =
                         SUBSTR (oracle_error_message || lv_error_mesg,
                                 1,
                                 3000
                                ),
                      date_updated = SYSDATE
                WHERE record_id = rec_process_records.parent_record_id;

                EXCEPTION WHEN OTHERS
                THEN
                msg ('Error while updating the Records '||SQLERRM);
                END;
                COMMIT;
                */
               END IF;
            END LOOP;                             -- End of csr_child_org Loop
         END LOOP;                          -- End of csr_process_records Loop

         fnd_file.put_line
            (fnd_file.LOG,
                '*********Cursor csr_process_records for child orgs Ended at '
             || TO_CHAR (SYSDATE, 'DD-MM-YYYY HH24:MI:SS')
            );

         -- Assigning Set Process Id for Child Orgs
         BEGIN
            xxdo_validate_and_batch (gv_retcode, gv_reterror);
         EXCEPTION
            WHEN OTHERS
            THEN
               fnd_file.put_line
                  (fnd_file.LOG,
                      'Error occurred while Validating and Grouping Batch logic for Items '
                   || SQLERRM
                  );
         END;

         -- Calling Import Items for Child Orgs
         BEGIN
            xxdo_import_items (gv_retcode, gv_reterror);
         EXCEPTION
            WHEN OTHERS
            THEN
               fnd_file.put_line (fnd_file.LOG,
                                     'Error occurred while Importing Items '
                                  || SQLERRM
                                 );
         END;

--*********************************************
-- CREATE PRICE LIST FOR WHOSLESALE PRICE
--********************************************
         fnd_file.put_line
                  (fnd_file.LOG,
                      ' Cursor csr_process_records for price list started at '
                   || TO_CHAR (SYSDATE, 'DD-MM-YYYY HH24:MI:SS')
                  );

         IF UPPER (NVL (gv_reprocess, 'N')) IN ('N', 'NO')
         THEN
            FOR rec_process_records IN csr_process_records
            LOOP
               gv_price_list_flag := 'Y';
               lv_template_name := NULL;
               gv_colorway_state := UPPER (rec_process_records.life_cycle);

               --W.r.t 1.17
               BEGIN
                  SELECT description
                    INTO lv_template_name
                    FROM fnd_lookup_values_vl
                   WHERE lookup_type = 'DO_ORG_TEMPLATE_ASSIGNMENT'
                     AND (   attribute1 = rec_process_records.life_cycle
                          OR attribute2 = rec_process_records.life_cycle
                          OR attribute3 = rec_process_records.life_cycle
                         )
                     AND attribute4 = gn_master_org_code
                     AND tag = rec_process_records.user_item_type
                     AND NVL (enabled_flag, 'Y') = 'Y';
               EXCEPTION
                  WHEN NO_DATA_FOUND
                  THEN
                     lv_template_name := NULL;
                  WHEN OTHERS
                  THEN
                     lv_template_name := NULL;
               END;

               IF lv_template_name IS NOT NULL
               THEN
                  IF UPPER (lv_template_name) IN
                               ('PLANNED ITEM TEMPLATE', 'GENERIC TEMPLATE')
                  THEN
                     gv_price_list_flag := 'N';
                  END IF;
               END IF;

               IF    (    UPPER (rec_process_records.user_item_type) IN
                                                           ('PROD', 'BGRADE')
                      -- AND rec_process_records.life_cycle = 'SM'
                      AND UPPER (rec_process_records.life_cycle) =
                                                            'PRODUCTION'
                                                                        --1.13
                     )
                  OR (    UPPER (rec_process_records.user_item_type) IN
                                                 ('SAMPLE', 'PROD', 'BGRADE')
                      --w.r.t Version 1.32 **added PROD and BGRADE
                      --  AND rec_process_records.life_cycle IN ('FLR', 'SM')   --1.7
                      AND UPPER (rec_process_records.life_cycle) IN
                                                  ('FLR', 'PRODUCTION') --1.13
                     )
               THEN
                  gv_price_list_flag := 'Y';
               ELSE
                  gv_price_list_flag := 'N';
               END IF;

               msg (   ' gn_wsale_pricelist_id '
                    || gn_wsale_pricelist_id
                    || ' gv_price_list_flag '
                    || gv_price_list_flag
                   );

               IF     rec_process_records.wholesale_price IS NOT NULL
                  AND gn_wsale_pricelist_id IS NOT NULL
                  AND gv_price_list_flag = 'Y'
               THEN
                  gv_retcode := NULL;
                  gv_reterror := NULL;
                  lv_error_mesg := NULL;
                  ln_price := NULL;
                  ln_list_line_id := NULL;
                  ln_pricing_attr_id := NULL;
                  ld_start_date := NULL;
                  ld_end_date := NULL;
                  ln_category_id := NULL;
                  ld_plm_begin_date := rec_process_records.begin_date;
                  --Start W.r.t version 1.7
                  ld_plm_end_date := rec_process_records.end_date;
                  lv_product_attr_value := NULL;    --Start W.r.t version 1.7
                  lv_price_season := NULL;          --Start W.r.t version 1.7
                  gv_sku_flag := NULL;              --Start W.r.t version 1.7
                  lv_price_brand := NULL;          --Start W.r.t version 1.14

                  --Start W.r.t version 1.7
                  --IF gv_pricing_logic = 'SKU' --W.r.t version 1.32
                  IF UPPER (rec_process_records.sourcing_flag) = 'SKU'
                  --OR UPPER (rec_process_records.inventory_type) = 'SAMPLE'
                  --Start W.r.t version 1.7
                  THEN
                     ln_inv_item_id := rec_process_records.item_id;
                     gv_sku_flag := 'Y';

                     BEGIN
                        SELECT qll.list_line_id, qpa.pricing_attribute_id,
                               qll.operand, qll.start_date_active,
                               qll.end_date_active, qll.attribute2,
                               qll.attribute1
                          INTO ln_list_line_id, ln_pricing_attr_id,
                               ln_price, ld_start_date,
                               ld_end_date, lv_price_season,
                               lv_price_brand
                          FROM apps.qp_pricing_attributes qpa,
                               apps.qp_list_lines qll,
                               apps.qp_list_headers qlh
                         WHERE qpa.list_line_id = qll.list_line_id
                           AND qll.list_header_id = qlh.list_header_id
                           --AND qll.organization_id = gn_master_orgid
                           AND qlh.list_header_id = gn_wsale_pricelist_id
                           AND qpa.product_attribute_context = 'ITEM'
                           AND product_attr_value = TO_CHAR (ln_inv_item_id)
                           AND qpa.product_uom_code = rec_process_records.uom
                           AND qll.end_date_active IS NULL;
                     EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                           ln_price := NULL;
                        WHEN OTHERS
                        THEN
                           gv_retcode := 2;
                           gv_reterror :=
                              SUBSTR
                                 (   'Error Occured while fetching price for price list Whole sale -US'
                                  || SQLERRM,
                                  1,
                                  1999
                                 );
                     END;

                     lv_product_attr_value := ln_inv_item_id;
                  ELSE            -- gv_pricing_logic  --End W.r.t version 1.7
                     gv_sku_flag := 'N';

                     BEGIN
                        SELECT mc.category_id
                          INTO ln_category_id
                          FROM mtl_categories mc,
                               mtl_category_sets mcs,
                               mtl_category_sets_tl mcst
                         WHERE mcst.category_set_name = 'OM Sales Category'
                           AND mcst.category_set_id = mcs.category_set_id
                           AND mcs.structure_id = mc.structure_id
                           --AND mc.segment1 = rec_process_records.style  -- W.r.t 1.1
                           --AND UPPER (mc.segment1) =  UPPER (rec_process_records.style_name) /*Removed Upper w.r.t  version 1.34
                           AND mc.segment1 =
                                        UPPER (rec_process_records.style_name)
                           -- W.r.t 1.1
                           AND mcst.LANGUAGE = 'US';
                     EXCEPTION
                        WHEN OTHERS
                        THEN
                           ln_category_id := NULL;
                           fnd_file.put_line
                              (fnd_file.LOG,
                                  'Unable to Fetch Category Id from OM Sales Category :: '
                               || SQLERRM
                              );
                     END;

                     IF ln_category_id IS NOT NULL
                     THEN
                        BEGIN
                           SELECT qll.list_line_id,
                                  qpa.pricing_attribute_id, qll.operand,
                                  qll.start_date_active,
                                  qll.end_date_active, qll.attribute2,
                                  qll.attribute1
                             INTO ln_list_line_id,
                                  ln_pricing_attr_id, ln_price,
                                  ld_start_date,
                                  ld_end_date, lv_price_season,
                                  lv_price_brand
                             FROM apps.qp_pricing_attributes qpa,
                                  apps.qp_list_lines qll,
                                  apps.qp_list_headers qlh
                            WHERE qpa.list_line_id = qll.list_line_id
                              AND qll.list_header_id = qlh.list_header_id
                              AND qlh.list_header_id = gn_wsale_pricelist_id
                              AND qpa.product_attribute_context = 'ITEM'
                              AND product_attr_value =
                                                      TO_CHAR (ln_category_id)
                              AND qpa.product_uom_code =
                                                       rec_process_records.uom
                              AND qll.end_date_active IS NULL;
                        EXCEPTION
                           WHEN NO_DATA_FOUND
                           THEN
                              ln_price := NULL;
                           WHEN OTHERS
                           THEN
                              ln_price := NULL;
                              gv_retcode := 2;
                              gv_reterror :=
                                 SUBSTR
                                    (   'Error Occured while fetching price for price list Whole sale -US'
                                     || SQLERRM,
                                     1,
                                     1999
                                    );
                        END;

                        lv_product_attr_value := ln_category_id;
                     --W.r.t Version 1.7
                     END IF;                               --W.r.t Version 1.7
                  END IF;                                  --W.r.t Version 1.7

                  IF lv_product_attr_value IS NOT NULL     --W.r.t Version 1.7
                  THEN
                     IF ln_price IS NULL
                     THEN
                        ln_list_line_id := NULL;
                        ln_pricing_attr_id := NULL;
                        create_price (rec_process_records.style,
                                      gn_wsale_pricelist_id,
                                      ln_list_line_id,
                                      ln_pricing_attr_id,
                                      rec_process_records.uom,
                                      --ln_category_id,
                                      lv_product_attr_value,             --1.7
                                      gn_master_orgid,
                                      rec_process_records.wholesale_price,
                                      NULL,
                                      NULL,
                                      'CREATE',
                                      rec_process_records.brand,
                                      rec_process_records.currentseason,
                                      gv_retcode,
                                      gv_reterror
                                     );
                     ELSIF     ln_price IS NOT NULL
                           --   AND ln_price <> rec_process_records.wholesale_price
                           AND UPPER (NVL (lv_price_season, 'XXX')) <>
                                     UPPER (rec_process_records.currentseason)
                     THEN
                        IF ld_start_date IS NULL AND ld_end_date IS NULL
                        THEN                        --Start W.r.t Version 1.7                        
                           create_price (rec_process_records.style,
                                         gn_wsale_pricelist_id,
                                         ln_list_line_id,
                                         ln_pricing_attr_id,
                                         rec_process_records.uom,
                                         --ln_category_id,
                                         lv_product_attr_value,          --1.7
                                         gn_master_orgid,
                                         ln_price,
                                         --rec_process_records.wholesale_price,
                                         NULL,
                                           TO_DATE (ld_plm_begin_date,
                                                    'YYYY-MM-DD'
                                                   )
                                         - 1,
                                         'UPDATE',
                                         --rec_process_records.brand,
                                         lv_price_brand,
                                         lv_price_season, --W.r.t Version 1.14
                                         --rec_process_records.currentseason  --W.r.t Version 1.14
                                         gv_retcode,
                                         gv_reterror
                                        );
                           ln_list_line_id := NULL;
                           ln_pricing_attr_id := NULL;
                           create_price (rec_process_records.style,
                                         gn_wsale_pricelist_id,
                                         ln_list_line_id,
                                         ln_pricing_attr_id,
                                         rec_process_records.uom,
                                         --ln_category_id,
                                         lv_product_attr_value,          --1.7
                                         gn_master_orgid,
                                         rec_process_records.wholesale_price,
                                         TO_DATE (ld_plm_begin_date,
                                                  'YYYY-MM-DD'
                                                 ),
                                         NULL,
                                         'CREATE',
                                         rec_process_records.brand,
                                         --lv_price_season, --W.r.t Version 1.14
                                         rec_process_records.currentseason,
                                         --W.r.t Version 1.14
                                         gv_retcode,
                                         gv_reterror
                                        );
                        ELSIF ld_start_date IS NOT NULL
                              AND ld_end_date IS NULL
                        THEN                         --Start W.r.t Version 1.7                        
                           create_price (rec_process_records.style,
                                         gn_wsale_pricelist_id,
                                         ln_list_line_id,
                                         ln_pricing_attr_id,
                                         rec_process_records.uom,
                                         --ln_category_id,
                                         lv_product_attr_value,          --1.7
                                         gn_master_orgid,
                                         --rec_process_records.wholesale_price,
                                         ln_price,
                                         ld_start_date,
                                           TO_DATE (ld_plm_begin_date,
                                                    'YYYY-MM-DD'
                                                   )
                                         - 1,
                                         'UPDATE',
                                         --rec_process_records.brand,
                                         lv_price_brand,
                                         lv_price_season, --W.r.t Version 1.14
                                         --rec_process_records.currentseason, --W.r.t Version 1.14
                                         gv_retcode,
                                         gv_reterror
                                        );
                           ln_list_line_id := NULL;
                           ln_pricing_attr_id := NULL;
                           create_price (rec_process_records.style,
                                         gn_wsale_pricelist_id,
                                         ln_list_line_id,
                                         ln_pricing_attr_id,
                                         rec_process_records.uom,
                                         --ln_category_id,
                                         lv_product_attr_value,          --1.7
                                         gn_master_orgid,
                                         rec_process_records.wholesale_price,
                                         TO_DATE (ld_plm_begin_date,
                                                  'YYYY-MM-DD'
                                                 ),
                                         NULL,
                                         'CREATE',
                                         rec_process_records.brand,
                                         --lv_price_season, --W.r.t Version 1.14
                                         rec_process_records.currentseason,
                                         --W.r.t Version 1.14
                                         gv_retcode,
                                         gv_reterror
                                        );
                        END IF;
                     ELSIF     ln_price IS NOT NULL
                           AND ln_price <> rec_process_records.wholesale_price
                           AND UPPER (NVL (lv_price_season, 'XXX')) =
                                     UPPER (rec_process_records.currentseason)
                     THEN
                         /*fnd_file.put_line (
                            fnd_file.LOG,
                               'FOR SAME SEASON FEED WHOLESALE PRICE CANNOT BE UPDATED '
                            || rec_process_records.style
                            || ' Error : '
                            || SQLERRM);*/                                          --Commented for change 1.50
                        -- Start of code changes for change 1.50
                        ln_current_season_count:=0;
                        IF UPPER (rec_process_records.sourcing_flag) = 'SKU'
                        THEN
                           BEGIN
                             SELECT COUNT(*)
                               INTO ln_current_season_count
                               FROM apps.qp_pricing_attributes qpa,
                                    apps.qp_list_lines qll,
                                    apps.qp_list_headers qlh
                              WHERE qpa.list_line_id = qll.list_line_id
                                AND qll.list_header_id = qlh.list_header_id
                                AND qlh.list_header_id = gn_wsale_pricelist_id
                                AND qpa.product_attribute_context = 'ITEM'
                                AND product_attr_value = TO_CHAR (ln_inv_item_id)
                                AND qpa.product_uom_code = rec_process_records.uom
                                AND UPPER(qll.attribute2)=UPPER (rec_process_records.currentseason);
                           EXCEPTION
                             WHEN OTHERS
                             THEN
                             gv_retcode := 2;
                              gv_reterror :=SUBSTR('Error Occured while fetching price for price list Whole sale -US'|| SQLERRM,1,1999);
                          END;
                        ELSE
                          BEGIN
                            SELECT COUNT(*)
                              INTO ln_current_season_count
                              FROM apps.qp_pricing_attributes qpa,
                                  apps.qp_list_lines qll,
                                  apps.qp_list_headers qlh
                            WHERE qpa.list_line_id = qll.list_line_id
                              AND qll.list_header_id = qlh.list_header_id
                              AND qlh.list_header_id = gn_wsale_pricelist_id
                              AND qpa.product_attribute_context = 'ITEM'
                              AND product_attr_value =  TO_CHAR (ln_category_id)
                              AND qpa.product_uom_code = rec_process_records.uom
                              AND UPPER(qll.attribute2)=UPPER (rec_process_records.currentseason);
                          EXCEPTION
                            WHEN OTHERS
                            THEN
                            gv_retcode := 2;
                            gv_reterror :=SUBSTR('Error Occured while fetching price for price list Whole sale -US'|| SQLERRM,1,1999);
                         END;
                        END IF;

                        IF ln_current_season_count=1
                        THEN
                        IF ld_start_date IS NULL AND ld_end_date IS NULL
                        THEN
                           create_price
                                   (rec_process_records.style,
                                    gn_wsale_pricelist_id,
                                    ln_list_line_id,
                                    ln_pricing_attr_id,
                                    rec_process_records.uom,
                                    lv_product_attr_value,
                                    gn_master_orgid,
                                    rec_process_records.wholesale_price,
                                    TO_DATE (rec_process_records.begin_date,
                                             'YYYY-MM-DD'
                                            ),
                                    NULL,
                                    'UPDATE',
                                    rec_process_records.brand,
                                    rec_process_records.currentseason,
                                    gv_retcode,
                                    gv_reterror
                                   );
                        ELSIF     TO_DATE (rec_process_records.begin_date,
                                           'YYYY-MM-DD'
                                          ) = ld_start_date
                              AND ld_end_date IS NULL
                        THEN
                           create_price
                                    (rec_process_records.style,
                                     gn_wsale_pricelist_id,
                                     ln_list_line_id,
                                     ln_pricing_attr_id,
                                     rec_process_records.uom,
                                     lv_product_attr_value,
                                     gn_master_orgid,
                                     rec_process_records.wholesale_price,
                                     TO_DATE (rec_process_records.begin_date,
                                              'YYYY-MM-DD'
                                             ),
                                     NULL,
                                     'UPDATE',
                                     rec_process_records.brand,
                                     rec_process_records.currentseason,
                                     gv_retcode,
                                     gv_reterror
                                    );
                        ELSIF     TO_DATE (rec_process_records.begin_date,
                                           'YYYY-MM-DD'
                                          ) > ld_start_date
                        THEN
                           create_price
                                 (rec_process_records.style,
                                  gn_wsale_pricelist_id,
                                  ln_list_line_id,
                                  ln_pricing_attr_id,
                                  rec_process_records.uom,
                                  lv_product_attr_value,
                                  gn_master_orgid,
                                  ln_price,
                                  TO_DATE (ld_start_date, 'YYYY-MM-DD'),
                                  TO_DATE (rec_process_records.begin_date - 1,
                                           'YYYY-MM-DD'
                                          ),
                                  'UPDATE',
                                  rec_process_records.brand,
                                  rec_process_records.currentseason,
                                  gv_retcode,
                                  gv_reterror
                                 );
                           ln_list_line_id := NULL;
                           ln_pricing_attr_id := NULL;
                           create_price
                                    (rec_process_records.style,
                                     gn_wsale_pricelist_id,
                                     ln_list_line_id,
                                     ln_pricing_attr_id,
                                     rec_process_records.uom,
                                     lv_product_attr_value,
                                     gn_master_orgid,
                                     rec_process_records.wholesale_price,
                                     TO_DATE (rec_process_records.begin_date,
                                              'YYYY-MM-DD'
                                             ),
                                     NULL,
                                     'CREATE',
                                     rec_process_records.brand,
                                     rec_process_records.currentseason,
                                     gv_retcode,
                                     gv_reterror
                                    );
                        END IF;
                        ELSE
                            fnd_file.put_line (
                            fnd_file.LOG,
                               'For same season feed wholesale price cannot be updated when there are more than one records '
                            || rec_process_records.style
                            || ' Error : '
                            || SQLERRM);
                       END IF;
                     --End of code changes for change 1.50
                     /* --W.r.t Verison 1.41
                        create_price (rec_process_records.style,
                                      gn_wsale_pricelist_id,
                                      ln_list_line_id,
                                      ln_pricing_attr_id,
                                      rec_process_records.uom,
                                      --ln_category_id,
                                      lv_product_attr_value,             --1.7
                                      gn_master_orgid,
                                      rec_process_records.wholesale_price,
                                      TO_DATE (ld_start_date, 'YYYY-MM-DD'),
                                      TO_DATE (ld_end_date, 'YYYY-MM-DD'),
                                      'UPDATE',
                                      rec_process_records.brand,
                                      rec_process_records.currentseason,
                                      gv_retcode,
                                      gv_reterror
                                     );
                                     */
                     --End W.r.t Verison 1.41
                     --End W.r.t Version 1.7
                     /*
                     ELSIF     TO_DATE (rec_process_records.begin_date,
                                        'YYYY-MM-DD'
                                       ) = ld_start_date
                           AND TO_DATE (rec_process_records.end_date,
                                        'YYYY-MM-DD'
                                       ) = ld_end_date
                     THEN
                        create_price
                                   (rec_process_records.style,
                                    gn_wsale_pricelist_id,
                                    ln_list_line_id,
                                    ln_pricing_attr_id,
                                    rec_process_records.uom,
                                    --ln_category_id,
                                    lv_product_attr_value,               --1.7
                                    gn_master_orgid,
                                    rec_process_records.wholesale_price,
                                    TO_DATE (rec_process_records.begin_date,
                                             'YYYY-MM-DD'
                                            ),
                                    TO_DATE (rec_process_records.end_date,
                                             'YYYY-MM-DD'
                                            ),
                                    'UPDATE',
                                    rec_process_records.brand,
                                    rec_process_records.currentseason,
                                    gv_retcode,
                                    gv_reterror
                                   );
                     ELSIF     TO_DATE (rec_process_records.begin_date,
                                        'YYYY-MM-DD'
                                       ) = ld_start_date
                           AND TO_DATE (rec_process_records.end_date,
                                        'YYYY-MM-DD'
                                       ) <> ld_end_date
                     THEN
                        create_price (rec_process_records.style,
                                      gn_wsale_pricelist_id,
                                      ln_list_line_id,
                                      ln_pricing_attr_id,
                                      rec_process_records.uom,
                                      --ln_category_id,
                                      lv_product_attr_value,             --1.7
                                      gn_master_orgid,
                                      rec_process_records.wholesale_price,
                                      ld_start_date,
                                      TO_DATE (rec_process_records.end_date,
                                               'YYYY-MM-DD'
                                              ),
                                      'UPDATE',
                                      rec_process_records.brand,
                                      rec_process_records.currentseason,
                                      gv_retcode,
                                      gv_reterror
                                     );
                     ELSIF     TO_DATE (rec_process_records.begin_date,
                                        'YYYY-MM-DD'
                                       ) > ld_start_date
                           AND TO_DATE (rec_process_records.begin_date,
                                        'YYYY-MM-DD'
                                       ) < ld_end_date
                     THEN
                        create_price
                                 (rec_process_records.style,
                                  gn_wsale_pricelist_id,
                                  ln_list_line_id,
                                  ln_pricing_attr_id,
                                  rec_process_records.uom,
                                  --ln_category_id,
                                  lv_product_attr_value,                 --1.7
                                  gn_master_orgid,
                                  ln_price,
                                  ld_start_date,
                                  TO_DATE (rec_process_records.begin_date - 1,
                                           'YYYY-MM-DD'
                                          ),
                                  'UPDATE',
                                  rec_process_records.brand,
                                  rec_process_records.currentseason,
                                  gv_retcode,
                                  gv_reterror
                                 );
                        ln_list_line_id := NULL;
                        ln_pricing_attr_id := NULL;
                        create_price
                                    (rec_process_records.style,
                                     gn_wsale_pricelist_id,
                                     ln_list_line_id,
                                     ln_pricing_attr_id,
                                     rec_process_records.uom,
                                     --ln_category_id,
                                     lv_product_attr_value,              --1.7
                                     gn_master_orgid,
                                     rec_process_records.wholesale_price,
                                     TO_DATE (rec_process_records.begin_date,
                                              'YYYY-MM-DD'
                                             ),
                                     TO_DATE (rec_process_records.end_date,
                                              'YYYY-MM-DD'
                                             ),
                                     'CREATE',
                                     rec_process_records.brand,
                                     rec_process_records.currentseason,
                                     gv_retcode,
                                     gv_reterror
                                    );
                     ELSIF     TO_DATE (rec_process_records.begin_date,
                                        'YYYY-MM-DD'
                                       ) > ld_start_date
                           AND TO_DATE (rec_process_records.begin_date,
                                        'YYYY-MM-DD'
                                       ) > ld_end_date
                     THEN                            --start W.R.T VERSION 1.6
                        ln_list_line_id := NULL;
                        ln_pricing_attr_id := NULL;
                        create_price
                                   (rec_process_records.style,
                                    gn_wsale_pricelist_id,
                                    ln_list_line_id,
                                    ln_pricing_attr_id,
                                    rec_process_records.uom,
                                    --ln_category_id,
                                    lv_product_attr_value,               --1.7
                                    gn_master_orgid,
                                    rec_process_records.wholesale_price,
                                    TO_DATE (rec_process_records.begin_date,
                                             'YYYY-MM-DD'
                                            ),
                                    TO_DATE (rec_process_records.end_date,
                                             'YYYY-MM-DD'
                                            ),
                                    'CREATE',
                                    rec_process_records.brand,
                                    rec_process_records.currentseason,
                                    gv_retcode,
                                    gv_reterror
                                   );                  --End W.R.T VERSION 1.6
                                   */
                     END IF;
                  END IF;
               END IF;

               IF gv_retcode IS NOT NULL OR gv_reterror IS NOT NULL
               THEN
                  BEGIN
                     lv_value := lv_value + 1;
                     lv_flag := 'E';
                     lv_error_mesg :=
                        SUBSTR (   lv_value
                                || ' Error in creating price List Item  '
                                || ' '
                                || gv_retcode
                                || ' '
                                || gv_reterror,
                                1,
                                1000
                               );
                     lv_error_message :=
                           SUBSTR (lv_error_message || lv_error_mesg, 1, 2000);
                     log_error_exception
                        (pv_procedure_name      => lv_pn,
                         pv_plm_row_id          => rec_process_records.parent_record_id,
                         pv_style               => rec_process_records.style,
                         pv_color               => rec_process_records.color_code,
                         pv_size                => rec_process_records.size_val,
                         pv_brand               => rec_process_records.brand,
                         pv_gender              => rec_process_records.gender,
                         pv_season              => rec_process_records.currentseason,
                         pv_reterror            => lv_error_mesg,
                         pv_error_code          => 'REPORT',
                         pv_error_type          => 'SYSTEM'
                        );

                     UPDATE xxdo.xxdo_plm_itemast_stg
                        SET error_message =
                               SUBSTR (error_message || lv_error_mesg, 1,
                                       4000)
                      WHERE parent_record_id =
                                          rec_process_records.parent_record_id
                        AND seq_num = rec_process_records.seq_num;

                     COMMIT;
                  END;
               END IF;

--*********************************************************
--CREATE_PRICE FOR RETAIL PRICE
--********************************************************
               lv_template_name := NULL;

               BEGIN
                  SELECT description
                    INTO lv_template_name
                    FROM fnd_lookup_values_vl
                   WHERE lookup_type = 'DO_ORG_TEMPLATE_ASSIGNMENT'
                     AND (   attribute1 = rec_process_records.life_cycle
                          OR attribute2 = rec_process_records.life_cycle
                          OR attribute3 = rec_process_records.life_cycle
                         )
                     AND attribute4 = gn_master_org_code
                     AND tag = rec_process_records.user_item_type
                     AND NVL (enabled_flag, 'Y') = 'Y';
               EXCEPTION
                  WHEN NO_DATA_FOUND
                  THEN
                     lv_template_name := NULL;
                  WHEN OTHERS
                  THEN
                     lv_template_name := NULL;
               END;

               IF lv_template_name IS NOT NULL
               THEN
                  IF UPPER (lv_template_name) IN
                               ('PLANNED ITEM TEMPLATE', 'GENERIC TEMPLATE')
                  THEN
                     gv_price_list_flag := 'N';
                  END IF;
               END IF;

               IF (    rec_process_records.user_item_type IN
                                                           ('PROD', 'BGRADE')
                   --     AND rec_process_records.life_cycle = 'SM'  -- W.r.t Version 1.13
                   AND UPPER (rec_process_records.life_cycle) IN
                          ('PRODUCTION', 'FLR')
                                              -- W.r.t Version 1.32 *Added FLR
                  -- W.r.t Version 1.13
                  )
               --  OR (    rec_process_records.user_item_type IN ('SAMPLE') AND rec_process_records.life_cycle IN ('FLR', 'SM') ) --1.7
               THEN
                  gv_price_list_flag := 'Y';
               ELSE
                  gv_price_list_flag := 'N';
               END IF;

               msg (   ' gn_rtl_pricelist_id '
                    || gn_rtl_pricelist_id
                    || ' gv_price_list_flag '
                    || gv_price_list_flag
                    || ' Price '
                    || rec_process_records.retail_price
                   );

               IF     rec_process_records.retail_price IS NOT NULL
                  AND gn_rtl_pricelist_id IS NOT NULL
                  AND gv_price_list_flag = 'Y'
               THEN
                  gv_retcode := NULL;
                  gv_reterror := NULL;
                  lv_error_mesg := NULL;
                  ln_price := NULL;
                  ln_list_line_id := NULL;
                  ln_pricing_attr_id := NULL;
                  ld_start_date := NULL;
                  ld_end_date := NULL;
                  ln_category_id := NULL;
                  ln_inv_item_id := NULL;           --Start W.r.t version 1.7
                  lv_product_attr_value := NULL;    --Start W.r.t version 1.7
                  lv_price_season := NULL;          --Start W.r.t version 1.7
                  gv_sku_flag := NULL;              --Start W.r.t version 1.7
                  lv_price_brand := NULL;          --Start W.r.t version 1.14

                  --IF gv_pricing_logic = 'SKU' --W.r.t version 1.32
                  IF UPPER (rec_process_records.sourcing_flag) = 'SKU'
                  -- OR UPPER (rec_process_records.inventory_type) = 'SAMPLE'
                  --Start W.r.t version 1.7
                  THEN
                     gv_sku_flag := 'Y';
                     ln_inv_item_id := rec_process_records.item_id;

                     BEGIN
                        SELECT qll.list_line_id, qpa.pricing_attribute_id,
                               qll.operand, qll.start_date_active,
                               qll.end_date_active, qll.attribute2,
                               qll.attribute1
                          INTO ln_list_line_id, ln_pricing_attr_id,
                               ln_price, ld_start_date,
                               ld_end_date, lv_price_season,
                               lv_price_brand
                          FROM apps.qp_pricing_attributes qpa,
                               apps.qp_list_lines qll,
                               apps.qp_list_headers qlh
                         WHERE qpa.list_line_id = qll.list_line_id
                           AND qll.list_header_id = qlh.list_header_id
                           --AND qll.organization_id = gn_master_orgid
                           AND qlh.list_header_id = gn_rtl_pricelist_id
                           AND qpa.product_attribute_context = 'ITEM'
                           AND product_attr_value = TO_CHAR (ln_inv_item_id)
                           AND qpa.product_uom_code = rec_process_records.uom
                           AND qll.end_date_active IS NULL;
                     EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                           ln_price := NULL;
                        WHEN OTHERS
                        THEN
                           gv_retcode := 2;
                           gv_reterror :=
                              SUBSTR
                                 (   'Error Occured while fetching price for price list Whole sale -US'
                                  || SQLERRM,
                                  1,
                                  1999
                                 );
                     END;

                     lv_product_attr_value := ln_inv_item_id;
                  ELSE            -- gv_pricing_logic  --End W.r.t version 1.7
                     gv_sku_flag := 'N';

                     BEGIN
                        SELECT mc.category_id
                          INTO ln_category_id
                          FROM mtl_categories mc,
                               mtl_category_sets mcs,
                               mtl_category_sets_tl mcst
                         WHERE mcst.category_set_name = 'OM Sales Category'
                           AND mcst.category_set_id = mcs.category_set_id
                           AND mcs.structure_id = mc.structure_id
                           --AND mc.segment1 = rec_process_records.style W.r.t version 1.1
                           --AND UPPER (mc.segment1) =  UPPER (rec_process_records.style_name) /*Removed Upper w.r.t  version 1.34
                           AND mc.segment1 =
                                        UPPER (rec_process_records.style_name)
                           --W.r.t version 1.1
                           AND mcst.LANGUAGE = 'US';
                     EXCEPTION
                        WHEN OTHERS
                        THEN
                           ln_category_id := NULL;
                           fnd_file.put_line
                              (fnd_file.LOG,
                                  'Unable to Fetch Category Id from OM Sales Category for style:: '
                               || rec_process_records.style
                               || ' Error : '
                               || SQLERRM
                              );
                     END;
                  END IF;

                  IF ln_category_id IS NOT NULL
                  THEN
                     BEGIN
                        SELECT qll.list_line_id, qpa.pricing_attribute_id,
                               qll.operand, qll.start_date_active,
                               qll.end_date_active, qll.attribute2,
                               qll.attribute1
                          INTO ln_list_line_id, ln_pricing_attr_id,
                               ln_price, ld_start_date,
                               ld_end_date, lv_price_season,
                               lv_price_brand
                          FROM apps.qp_pricing_attributes qpa,
                               apps.qp_list_lines qll,
                               apps.qp_list_headers qlh
                         WHERE qpa.list_line_id = qll.list_line_id
                           AND qll.list_header_id = qlh.list_header_id
                           AND qlh.list_header_id = gn_rtl_pricelist_id
                           AND qpa.product_attribute_context = 'ITEM'
                           AND product_attr_value = TO_CHAR (ln_category_id)
                           AND qpa.product_uom_code = rec_process_records.uom
                           AND qll.end_date_active IS NULL;
                     EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                           ln_price := NULL;
                        WHEN OTHERS
                        THEN
                           ln_price := NULL;
                           gv_retcode := 2;
                           gv_reterror :=
                              SUBSTR
                                 (   'Error Occured while fetching price for price list Retail - US'
                                  || SQLERRM,
                                  1,
                                  1999
                                 );
                     END;

                     lv_product_attr_value := ln_category_id;
                  END IF;

                  IF lv_product_attr_value IS NOT NULL
                  THEN
                     BEGIN
                        IF ln_price IS NULL
                        THEN
                           ln_list_line_id := NULL;
                           ln_pricing_attr_id := NULL;
                           create_price (rec_process_records.style,
                                         gn_rtl_pricelist_id,
                                         ln_list_line_id,
                                         ln_pricing_attr_id,
                                         rec_process_records.uom,
                                         --ln_category_id,
                                         lv_product_attr_value,          --1.7
                                         gn_master_orgid,
                                         rec_process_records.retail_price,
                                         -- TO_DATE (rec_process_records.begin_date,'YYYY-MM-DD'),
                                         -- TO_DATE (rec_process_records.end_date, 'YYYY-MM-DD' ),
                                         NULL,
                                         NULL,
                                         'CREATE',
                                         rec_process_records.brand,
                                         rec_process_records.currentseason,
                                         gv_retcode,
                                         gv_reterror
                                        );
                        ELSIF     ln_price IS NOT NULL
                              --AND ln_price <> rec_process_records.retail_price
                              AND UPPER (NVL (lv_price_season, 'XXX')) <>
                                     UPPER (rec_process_records.currentseason)
                        THEN
                           IF ld_start_date IS NULL AND ld_end_date IS NULL
                           THEN                     --Start W.r.t Version 1.7                           
                              create_price
                                        (rec_process_records.style,
                                         gn_rtl_pricelist_id,
                                         ln_list_line_id,
                                         ln_pricing_attr_id,
                                         rec_process_records.uom,
                                         --ln_category_id,
                                         lv_product_attr_value,          --1.7
                                         gn_master_orgid,
                                         --rec_process_records.retail_price,
                                         ln_price,
                                         NULL,
                                           TO_DATE (ld_plm_begin_date,
                                                    'YYYY-MM-DD'
                                                   )
                                         - 1,
                                         'UPDATE',
                                         --rec_process_records.brand,
                                         lv_price_brand,
                                         lv_price_season, --W.r.t Version 1.14
                                         --rec_process_records.currentseason, --W.r.t Version 1.14
                                         gv_retcode,
                                         gv_reterror
                                        );
                              ln_list_line_id := NULL;
                              ln_pricing_attr_id := NULL;
                              create_price (rec_process_records.style,
                                            gn_rtl_pricelist_id,
                                            ln_list_line_id,
                                            ln_pricing_attr_id,
                                            rec_process_records.uom,
                                            --ln_category_id,
                                            lv_product_attr_value,       --1.7
                                            gn_master_orgid,
                                            rec_process_records.retail_price,
                                            TO_DATE (ld_plm_begin_date,
                                                     'YYYY-MM-DD'
                                                    ),
                                            NULL,
                                            'CREATE',
                                            rec_process_records.brand,
                                            --lv_price_season, --W.r.t Version 1.14
                                            rec_process_records.currentseason,
                                            --W.r.t Version 1.14
                                            gv_retcode,
                                            gv_reterror
                                           );
                           ELSIF     ld_start_date IS NOT NULL
                                 AND ld_end_date IS NULL
                           THEN                      --Start W.r.t Version 1.7                          
                              create_price
                                        (rec_process_records.style,
                                         gn_rtl_pricelist_id,
                                         ln_list_line_id,
                                         ln_pricing_attr_id,
                                         rec_process_records.uom,
                                         --ln_category_id,
                                         lv_product_attr_value,          --1.7
                                         gn_master_orgid,
                                         -- rec_process_records.retail_price,
                                         ln_price,
                                         ld_start_date,
                                           TO_DATE (ld_plm_begin_date,
                                                    'YYYY-MM-DD'
                                                   )
                                         - 1,
                                         'UPDATE',
                                         -- rec_process_records.brand,
                                         lv_price_brand,
                                         lv_price_season, --W.r.t Version 1.14
                                         --  rec_process_records.currentseason, --W.r.t Version 1.14
                                         gv_retcode,
                                         gv_reterror
                                        );
                              ln_list_line_id := NULL;
                              ln_pricing_attr_id := NULL;
                              create_price (rec_process_records.style,
                                            gn_rtl_pricelist_id,
                                            ln_list_line_id,
                                            ln_pricing_attr_id,
                                            rec_process_records.uom,
                                            --ln_category_id,
                                            lv_product_attr_value,       --1.7
                                            gn_master_orgid,
                                            rec_process_records.retail_price,
                                            TO_DATE (ld_plm_begin_date,
                                                     'YYYY-MM-DD'
                                                    ),
                                            NULL,
                                            'CREATE',
                                            rec_process_records.brand,
                                            rec_process_records.currentseason,
                                            gv_retcode,
                                            gv_reterror
                                           );
                           END IF;
                        ELSIF     ln_price IS NOT NULL
                              AND ln_price <> rec_process_records.retail_price
                              AND UPPER (NVL (lv_price_season, 'XXX')) =
                                     UPPER (rec_process_records.currentseason)
                        THEN
                            /* fnd_file.put_line (
                                fnd_file.LOG,
                                   'FOR SAME SEASON FEED WHOLESALE PRICE CANNOT BE UPDATED '
                                || rec_process_records.style
                                || ' Error : '
                                || SQLERRM);*/                                               --commented for change 1.50
                           --Start of code changes for change 1.50
                           ln_current_season_count:=0;
                        IF UPPER (rec_process_records.sourcing_flag) = 'SKU'
                        THEN
                           BEGIN
                             SELECT COUNT(*)
                               INTO ln_current_season_count
                               FROM apps.qp_pricing_attributes qpa,
                                    apps.qp_list_lines qll,
                                    apps.qp_list_headers qlh
                              WHERE qpa.list_line_id = qll.list_line_id
                                AND qll.list_header_id = qlh.list_header_id
                                AND qlh.list_header_id = gn_wsale_pricelist_id
                                AND qpa.product_attribute_context = 'ITEM'
                                AND product_attr_value = TO_CHAR (ln_inv_item_id)
                                AND qpa.product_uom_code = rec_process_records.uom
                                AND UPPER(qll.attribute2)=UPPER (rec_process_records.currentseason);
                           EXCEPTION
                             WHEN OTHERS
                             THEN
                             gv_retcode := 2;
                              gv_reterror :=SUBSTR('Error Occured while fetching price for price list Whole sale -US'|| SQLERRM,1,1999);
                          END;
                        ELSE
                          BEGIN
                            SELECT COUNT(*)
                              INTO ln_current_season_count
                              FROM apps.qp_pricing_attributes qpa,
                                  apps.qp_list_lines qll,
                                  apps.qp_list_headers qlh
                            WHERE qpa.list_line_id = qll.list_line_id
                              AND qll.list_header_id = qlh.list_header_id
                              AND qlh.list_header_id = gn_wsale_pricelist_id
                              AND qpa.product_attribute_context = 'ITEM'
                              AND product_attr_value =  TO_CHAR (ln_category_id)
                              AND qpa.product_uom_code = rec_process_records.uom
                              AND UPPER(qll.attribute2)=UPPER (rec_process_records.currentseason);
                          EXCEPTION
                            WHEN OTHERS
                            THEN
                            gv_retcode := 2;
                            gv_reterror :=SUBSTR('Error Occured while fetching price for price list Whole sale -US'|| SQLERRM,1,1999);
                         END;
                        END IF;

                        IF ln_current_season_count=1
                        THEN
                           IF ld_start_date IS NULL AND ld_end_date IS NULL
                           THEN
                              create_price
                                   (rec_process_records.style,
                                    gn_rtl_pricelist_id,
                                    ln_list_line_id,
                                    ln_pricing_attr_id,
                                    rec_process_records.uom,
                                    lv_product_attr_value,
                                    gn_master_orgid,
                                    rec_process_records.retail_price,
                                    TO_DATE (rec_process_records.begin_date,
                                             'YYYY-MM-DD'
                                            ),
                                    NULL,
                                    'UPDATE',
                                    rec_process_records.brand,
                                    rec_process_records.currentseason,
                                    gv_retcode,
                                    gv_reterror
                                   );
                           ELSIF     TO_DATE (rec_process_records.begin_date,
                                              'YYYY-MM-DD'
                                             ) = ld_start_date
                                 AND ld_end_date IS NULL
                           THEN
                              create_price
                                    (rec_process_records.style,
                                     gn_rtl_pricelist_id,
                                     ln_list_line_id,
                                     ln_pricing_attr_id,
                                     rec_process_records.uom,
                                     lv_product_attr_value,
                                     gn_master_orgid,
                                     rec_process_records.retail_price,
                                     TO_DATE (rec_process_records.begin_date,
                                              'YYYY-MM-DD'
                                             ),
                                     NULL,
                                     'UPDATE',
                                     rec_process_records.brand,
                                     rec_process_records.currentseason,
                                     gv_retcode,
                                     gv_reterror
                                    );
                           ELSIF     TO_DATE (rec_process_records.begin_date,
                                              'YYYY-MM-DD'
                                             ) > ld_start_date
                           THEN
                              create_price
                                 (rec_process_records.style,
                                  gn_rtl_pricelist_id,
                                  ln_list_line_id,
                                  ln_pricing_attr_id,
                                  rec_process_records.uom,
                                  lv_product_attr_value,
                                  gn_master_orgid,
                                  ln_price,
                                  TO_DATE (ld_start_date, 'YYYY-MM-DD'),
                                  TO_DATE (rec_process_records.begin_date - 1,
                                           'YYYY-MM-DD'
                                          ),
                                  'UPDATE',
                                  rec_process_records.brand,
                                  rec_process_records.currentseason,
                                  gv_retcode,
                                  gv_reterror
                                 );
                              ln_list_line_id := NULL;
                              ln_pricing_attr_id := NULL;
                              create_price
                                    (rec_process_records.style,
                                     gn_rtl_pricelist_id,
                                     ln_list_line_id,
                                     ln_pricing_attr_id,
                                     rec_process_records.uom,
                                     lv_product_attr_value,
                                     gn_master_orgid,
                                     rec_process_records.retail_price,
                                     TO_DATE (rec_process_records.begin_date,
                                              'YYYY-MM-DD'
                                             ),
                                     NULL,
                                     'CREATE',
                                     rec_process_records.brand,
                                     rec_process_records.currentseason,
                                     gv_retcode,
                                     gv_reterror
                                    );
                           END IF;
                        ELSE
                            fnd_file.put_line (fnd_file.LOG,
                                               'For same season feed retail price cannot be updated when there are more than one records '
                                                || rec_process_records.style
                                                || ' Error : '
                                                || SQLERRM);
                       END IF;
                     --End of code changes for change 1.50
                        /*  -- W.r.t Verison 1.41
                           create_price (rec_process_records.style,
                                         gn_rtl_pricelist_id,
                                         ln_list_line_id,
                                         ln_pricing_attr_id,
                                         rec_process_records.uom,
                                         --ln_category_id,
                                         lv_product_attr_value,          --1.7
                                         gn_master_orgid,
                                         rec_process_records.retail_price,
                                         TO_DATE (ld_start_date, 'YYYY-MM-DD'),
                                         TO_DATE (ld_end_date, 'YYYY-MM-DD'),
                                         'UPDATE',
                                         rec_process_records.brand,
                                         rec_process_records.currentseason,
                                         gv_retcode,
                                         gv_reterror
                                        );
                                        */
                        --W.r.t Verison 1.41
                        --End W.r.t Version 1.7
                        /*
                        ELSIF     TO_DATE (rec_process_records.begin_date,
                                           'YYYY-MM-DD'
                                          ) = ld_start_date
                              AND TO_DATE (rec_process_records.end_date,
                                           'YYYY-MM-DD'
                                          ) = ld_end_date
                        THEN
                           create_price
                                   (rec_process_records.style,
                                    gn_rtl_pricelist_id,
                                    ln_list_line_id,
                                    ln_pricing_attr_id,
                                    rec_process_records.uom,
                                    --ln_category_id,
                                    lv_product_attr_value,
                                    gn_master_orgid,
                                    rec_process_records.retail_price,
                                    TO_DATE (rec_process_records.begin_date,
                                             'YYYY-MM-DD'
                                            ),
                                    TO_DATE (rec_process_records.end_date,
                                             'YYYY-MM-DD'
                                            ),
                                    'UPDATE',
                                    rec_process_records.brand,
                                    rec_process_records.currentseason,
                                    gv_retcode,
                                    gv_reterror
                                   );
                        ELSIF     TO_DATE (rec_process_records.begin_date,
                                           'YYYY-MM-DD'
                                          ) = ld_start_date
                              AND TO_DATE (rec_process_records.end_date,
                                           'YYYY-MM-DD'
                                          ) <> ld_end_date
                        THEN
                           create_price
                                     (rec_process_records.style,
                                      gn_rtl_pricelist_id,
                                      ln_list_line_id,
                                      ln_pricing_attr_id,
                                      rec_process_records.uom,
                                      --ln_category_id,
                                      lv_product_attr_value,
                                      gn_master_orgid,
                                      rec_process_records.retail_price,
                                      ld_start_date,
                                      TO_DATE (rec_process_records.end_date,
                                               'YYYY-MM-DD'
                                              ),
                                      'UPDATE',
                                      rec_process_records.brand,
                                      rec_process_records.currentseason,
                                      gv_retcode,
                                      gv_reterror
                                     );
                        ELSIF     TO_DATE (rec_process_records.begin_date,
                                           'YYYY-MM-DD'
                                          ) > ld_start_date
                              AND TO_DATE (rec_process_records.begin_date,
                                           'YYYY-MM-DD'
                                          ) < ld_end_date
                        THEN
                           create_price
                                 (rec_process_records.style,
                                  gn_rtl_pricelist_id,
                                  ln_list_line_id,
                                  ln_pricing_attr_id,
                                  rec_process_records.uom,
                                  --ln_category_id,
                                  lv_product_attr_value,
                                  gn_master_orgid,
                                  ln_price,
                                  ld_start_date,
                                  TO_DATE (rec_process_records.begin_date - 1,
                                           'YYYY-MM-DD'
                                          ),
                                  'UPDATE',
                                  rec_process_records.brand,
                                  rec_process_records.currentseason,
                                  gv_retcode,
                                  gv_reterror
                                 );
                           ln_list_line_id := NULL;
                           ln_pricing_attr_id := NULL;
                           create_price
                                    (rec_process_records.style,
                                     gn_rtl_pricelist_id,
                                     ln_list_line_id,
                                     ln_pricing_attr_id,
                                     rec_process_records.uom,
                                     --ln_category_id,
                                     lv_product_attr_value,
                                     gn_master_orgid,
                                     rec_process_records.retail_price,
                                     TO_DATE (rec_process_records.begin_date,
                                              'YYYY-MM-DD'
                                             ),
                                     TO_DATE (rec_process_records.end_date,
                                              'YYYY-MM-DD'
                                             ),
                                     'CREATE',
                                     rec_process_records.brand,
                                     rec_process_records.currentseason,
                                     gv_retcode,
                                     gv_reterror
                                    );
                        ELSIF     TO_DATE (rec_process_records.begin_date,
                                           'YYYY-MM-DD'
                                          ) > ld_start_date
                              AND TO_DATE (rec_process_records.begin_date,
                                           'YYYY-MM-DD'
                                          ) > ld_end_date
                        THEN                         --start W.R.T VERSION 1.6
                           ln_list_line_id := NULL;
                           ln_pricing_attr_id := NULL;
                           create_price
                                   (rec_process_records.style,
                                    gn_rtl_pricelist_id,
                                    ln_list_line_id,
                                    ln_pricing_attr_id,
                                    rec_process_records.uom,
                                    --ln_category_id,
                                    lv_product_attr_value,
                                    gn_master_orgid,
                                    rec_process_records.retail_price,
                                    TO_DATE (rec_process_records.begin_date,
                                             'YYYY-MM-DD'
                                            ),
                                    TO_DATE (rec_process_records.end_date,
                                             'YYYY-MM-DD'
                                            ),
                                    'CREATE',
                                    rec_process_records.brand,
                                    rec_process_records.currentseason,
                                    gv_retcode,
                                    gv_reterror
                                   );                  --End W.R.T VERSION 1.6
                                   */
                        END IF;
                     EXCEPTION
                        WHEN OTHERS
                        THEN
                           gv_retcode := 2;
                           gv_reterror := SQLERRM;
                     END;
                  END IF;
               END IF;

               IF gv_retcode IS NOT NULL OR gv_reterror IS NOT NULL
               THEN
                  BEGIN
                     lv_value := lv_value + 1;
                     lv_flag := 'E';
                     lv_error_mesg :=
                        SUBSTR (   lv_value
                                || ' Error in creating price List Item  '
                                || gv_reterror,
                                1,
                                1000
                               );
                     lv_error_message :=
                           SUBSTR (lv_error_message || lv_error_mesg, 1, 2000);
                     log_error_exception
                        (pv_procedure_name      => lv_pn,
                         pv_plm_row_id          => rec_process_records.parent_record_id,
                         pv_style               => rec_process_records.style,
                         pv_color               => rec_process_records.color_code,
                         pv_size                => rec_process_records.size_val,
                         pv_brand               => rec_process_records.brand,
                         pv_gender              => rec_process_records.gender,
                         pv_season              => rec_process_records.currentseason,
                         pv_reterror            => lv_error_mesg,
                         pv_error_code          => 'REPORT',
                         pv_error_type          => 'SYSTEM'
                        );

                     UPDATE xxdo.xxdo_plm_itemast_stg
                        SET error_message =
                               SUBSTR (error_message || lv_error_mesg, 1,
                                       4000)
                      WHERE parent_record_id =
                                          rec_process_records.parent_record_id
                        AND seq_num = rec_process_records.seq_num;

                     COMMIT;
                  END;
               END IF;

--*********************************************
-- CREATE COST TYPE
--********************************************
               lv_error_mesg := NULL;
               gv_retcode := NULL;
               gv_reterror := NULL;
               ln_cost_type_id := NULL;
               lv_cost_type := NULL;

--*********************************************
-- PEOJECTED COST TYPE
--********************************************
               IF rec_process_records.projectedcost IS NOT NULL
               THEN
                  lv_cost_type := rec_process_records.cost_type || '-FOB';

                  BEGIN
                     SELECT cost_type_id
                       INTO ln_cost_type_id
                       FROM cst_cost_types
                      WHERE UPPER (cost_type) = UPPER (lv_cost_type);
                  EXCEPTION
                     WHEN NO_DATA_FOUND
                     THEN
                        ln_cost_type_id := NULL;
                     WHEN OTHERS
                     THEN
                        ln_cost_type_id := NULL;
                        gv_retcode := 2;
                        gv_reterror :=
                           SUBSTR
                                (   'Error Occured while fetching cost type'
                                 || SQLERRM,
                                 1,
                                 1999
                                );
                  END;

                  ln_rowid := NULL;

                  IF ln_cost_type_id IS NULL
                  THEN
                     BEGIN
                        cst_cost_types_pkg.insert_row
                            (x_rowid                      => ln_rowid,
                             x_cost_type_id               => ln_cost_type_id,
                             x_last_update_date           => SYSDATE,
                             x_last_updated_by            => gn_userid,
                             x_creation_date              => SYSDATE,
                             x_created_by                 => gn_userid,
                             x_last_update_login          => g_num_login_id,
                             x_organization_id            => rec_process_records.org_id,
                             x_cost_type                  => TRIM
                                                                 (lv_cost_type),
                             x_description                =>    'COST FOR '
                                                             || lv_cost_type,
                             x_costing_method_type        => '1',
                             x_frozen_standard_flag       => NULL,
                             x_default_cost_type_id       => ln_cost_type_id,
                             x_bom_snapshot_flag          => '2',
                             x_allow_updates_flag         => 1,
                             x_pl_element_flag            => 1,
                             x_pl_resource_flag           => 1,
                             x_pl_operation_flag          => 1,
                             x_pl_activity_flag           => 1,
                             x_disable_date               => NULL,
                             x_available_to_eng_flag      => NULL,
                             x_component_yield_flag       => 1
                            );
                     EXCEPTION
                        WHEN OTHERS
                        THEN
                           gv_retcode := SQLCODE;
                           gv_reterror :=
                              SUBSTR
                                 (   'Error Occured while creating cost type'
                                  || SQLERRM,
                                  1,
                                  1999
                                 );
                     END;

                     IF gv_retcode IS NOT NULL OR gv_reterror IS NOT NULL
                     THEN
                        BEGIN
                           lv_value := lv_value + 1;
                           lv_flag := 'E';
                           lv_error_mesg :=
                              SUBSTR (   lv_value
                                      || ' Error in creating cost type '
                                      || gv_retcode
                                      || ' '
                                      || gv_reterror,
                                      1,
                                      1000
                                     );
                           lv_error_message :=
                              SUBSTR (lv_error_message || lv_error_mesg,
                                      1,
                                      2000
                                     );
                           log_error_exception
                              (pv_procedure_name      => lv_pn,
                               pv_plm_row_id          => rec_process_records.parent_record_id,
                               pv_style               => rec_process_records.style,
                               pv_color               => rec_process_records.color_code,
                               pv_size                => rec_process_records.size_val,
                               pv_brand               => rec_process_records.brand,
                               pv_gender              => rec_process_records.gender,
                               pv_season              => rec_process_records.currentseason,
                               pv_reterror            => lv_error_mesg,
                               pv_error_code          => 'REPORT',
                               pv_error_type          => 'SYSTEM'
                              );
                           fnd_file.put_line
                                  (fnd_file.LOG,
                                      ' cst_cost_types_pkg.insert_row Error  '
                                   || lv_error_mesg
                                  );
                        END;
                     END IF;
                  END IF;
               END IF;

--*********************************************
-- LANDED COST TYPE
--********************************************
               lv_error_mesg := NULL;
               gv_retcode := NULL;
               gv_reterror := NULL;
               ln_cost_type_id := NULL;
               lv_cost_type := NULL;

               IF rec_process_records.landedcost IS NOT NULL
               THEN
                  lv_cost_type := rec_process_records.cost_type || '-LD';

                  BEGIN
                     SELECT cost_type_id
                       INTO ln_cost_type_id
                       FROM cst_cost_types
                      WHERE UPPER (cost_type) = UPPER (lv_cost_type);
                  EXCEPTION
                     WHEN NO_DATA_FOUND
                     THEN
                        ln_cost_type_id := NULL;
                     WHEN OTHERS
                     THEN
                        ln_cost_type_id := NULL;
                        gv_retcode := 2;
                        gv_reterror :=
                           SUBSTR
                                (   'Error Occured while fetching cost type'
                                 || SQLERRM,
                                 1,
                                 1999
                                );
                  END;

                  ln_rowid := NULL;

                  IF ln_cost_type_id IS NULL
                  THEN
                     BEGIN
                        cst_cost_types_pkg.insert_row
                            (x_rowid                      => ln_rowid,
                             x_cost_type_id               => ln_cost_type_id,
                             x_last_update_date           => SYSDATE,
                             x_last_updated_by            => gn_userid,
                             x_creation_date              => SYSDATE,
                             x_created_by                 => gn_userid,
                             x_last_update_login          => g_num_login_id,
                             x_organization_id            => rec_process_records.org_id,
                             x_cost_type                  => TRIM
                                                                 (lv_cost_type),
                             x_description                =>    'COST FOR '
                                                             || lv_cost_type,
                             x_costing_method_type        => '1',
                             x_frozen_standard_flag       => NULL,
                             x_default_cost_type_id       => ln_cost_type_id,
                             x_bom_snapshot_flag          => '2',
                             x_allow_updates_flag         => 1,
                             x_pl_element_flag            => 1,
                             x_pl_resource_flag           => 1,
                             x_pl_operation_flag          => 1,
                             x_pl_activity_flag           => 1,
                             x_disable_date               => NULL,
                             x_available_to_eng_flag      => NULL,
                             x_component_yield_flag       => 1
                            );
                     EXCEPTION
                        WHEN OTHERS
                        THEN
                           gv_retcode := SQLCODE;
                           gv_reterror :=
                              SUBSTR
                                 (   'Error Occured while creating cost type'
                                  || SQLERRM,
                                  1,
                                  1999
                                 );
                     END;

                     IF gv_retcode IS NOT NULL OR gv_reterror IS NOT NULL
                     THEN
                        BEGIN
                           lv_value := lv_value + 1;
                           lv_flag := 'E';
                           lv_error_mesg :=
                              SUBSTR (   lv_value
                                      || ' Error in creating cost type '
                                      || gv_retcode
                                      || ' '
                                      || gv_reterror,
                                      1,
                                      1000
                                     );
                           lv_error_message :=
                              SUBSTR (lv_error_message || lv_error_mesg,
                                      1,
                                      2000
                                     );
                           log_error_exception
                              (pv_procedure_name      => lv_pn,
                               pv_plm_row_id          => rec_process_records.parent_record_id,
                               pv_style               => rec_process_records.style,
                               pv_color               => rec_process_records.color_code,
                               pv_size                => rec_process_records.size_val,
                               pv_brand               => rec_process_records.brand,
                               pv_gender              => rec_process_records.gender,
                               pv_season              => rec_process_records.currentseason,
                               pv_reterror            => lv_error_mesg,
                               pv_error_code          => 'REPORT',
                               pv_error_type          => 'SYSTEM'
                              );
                           fnd_file.put_line
                                  (fnd_file.LOG,
                                      ' cst_cost_types_pkg.insert_row Error  '
                                   || lv_error_mesg
                                  );
                        END;
                     END IF;
                  END IF;
               END IF;
            END LOOP;                              -- csr_process_records Loop
         END IF;                                           -- gv_reprocess end

         fnd_file.put_line
                    (fnd_file.LOG,
                        ' Cursor csr_process_records for price list Ended at '
                     || TO_CHAR (SYSDATE, 'DD-MM-YYYY HH24:MI:SS')
                    );

--*********************************************
-- CREATE SOURCING RULES FOR CHILD ORGS
--********************************************
         UPDATE xxdo.xxdo_plm_itemast_stg             -- Added as part of 1.34
            SET status_flag = 'S'
          WHERE status_flag = 'P' AND stg_request_id = gn_conc_request_id;

         COMMIT;
            /*
         FOR rec_process_records IN csr_process_records
         LOOP
            BEGIN
               lv_error_message := NULL;

               UPDATE xxdo.xxdo_plm_itemast_stg
                  SET status_flag = 'S'
                WHERE seq_num = rec_process_records.seq_num
                  AND parent_record_id = rec_process_records.parent_record_id;

               COMMIT;
            EXCEPTION
               WHEN NO_DATA_FOUND
               THEN
                  fnd_file.put_line
                      (fnd_file.LOG,
                       SUBSTR (   'There are no record  to be updated '
                               || SQLERRM,
                               1,
                               1999
                              )
                      );
               WHEN OTHERS
               THEN
                  fnd_file.put_line
                        (fnd_file.LOG,
                         SUBSTR (   'Exception Occured while updating table '
                                 || SQLERRM,
                                 1,
                                 1999
                                )
                        );
            END;
         END LOOP;
         */
            -- commented as part of 1.34

         --*********************************************
-- CREATE SOURCING RULES FOR CHILD ORGS W.r.t Version --1.8
--********************************************
         fnd_file.put_line
                  (fnd_file.LOG,
                      ' Cursor csr_sourcing_records Sourcing Rule started at '
                   || TO_CHAR (SYSDATE, 'DD-MM-YYYY HH24:MI:SS')
                  );

         FOR rec_sourcing_records IN csr_sourcing_records
         LOOP
            fnd_file.put_line (fnd_file.LOG,
                                  'Sourcing records - factory '
                               || rec_sourcing_records.factory
                              );
            fnd_file.put_line (fnd_file.LOG,
                                  'Sourcing records - tq_sourcing_name '
                               || rec_sourcing_records.tq_sourcing_name
                              );
            ln_sourc_org_count := 0;
            gv_retcode := NULL;
            gv_reterror := NULL;

            -- msg (   'Before Sourcing CHild Orgs :: '
            --      || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
            --      || ' Supplier '
            --      || rec_sourcing_records.supplier
            --      || ' factory '
            --     || rec_sourcing_records.factory
            --   );
            FOR rec_vendors IN cur_vendors (rec_sourcing_records.supplier,
                                            rec_sourcing_records.factory
                                           )
            LOOP
               lv_sourc_region := NULL;
               fnd_file.put_line (fnd_file.LOG,
                                     'Sourcing records - supplier '
                                  || rec_vendors.vendor_name
                                 );
--*********************************************
--INSERT INTO XXDO_SOURCING_RULE_STG table --Start W.r.t Version 1.8
--*********************************************
/*  --W.r.t 1.13
               BEGIN
                  SELECT DISTINCT flv.attribute1
                             INTO lv_sourc_region
                             FROM fnd_lookup_values_vl flv
                            WHERE UPPER (flv.lookup_type) =
                                               'XXDO_SOURCING_RULE_REGION_MAP'
                              AND UPPER (flv.attribute2) =
                                                      'INVENTORY ORGANIZATION'
                              AND flv.attribute3 =
                                              (rec_vendors.organization_code
                                              );
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     gv_retcode := SQLCODE;
                     gv_reterror :=
                        SUBSTR
                           (   'Error Occured while fetching lv_sourc_region '
                            || SQLERRM,
                            1,
                            1999
                           );
               END;

*/
--W.r.t Version 1.13
/*    ln_sourcing_exist := 0;

    BEGIN
       SELECT COUNT (*)
         INTO ln_sourcing_exist
         FROM apps.xxdo_sourcing_rule_stg
        WHERE     style = rec_sourcing_records.style
              AND color = rec_sourcing_records.color_code
              AND supplier_name = rec_vendors.vendor_name
              AND supplier_site_code =
                     rec_sourcing_records.factory
              AND SOURCE = 'PLM'
              AND plm_region = 'GLOBAL'
              AND TRUNC (start_date) = TRUNC (SYSDATE + 1);
    --W.r.t Version 1.25
    --TO_DATE (rec_sourcing_records.purchasing_start_date,'YYYY-MM-DD');
    /*   AND end_date =
                TO_DATE (rec_sourcing_records.purchasing_end_date,
                         'YYYY-MM-DD'
                        );
    -- Commented for 1.19.
    EXCEPTION
       WHEN OTHERS
       THEN
          ln_sourcing_exist := 0;
    END;*/
               l_lkp_cnt := 0;

               -- W.r.t version 1.33(Start)
               --Check if vendor/factory is in dual source lookup
               BEGIN
                  SELECT COUNT (1)
                    INTO l_lkp_cnt
                    FROM fnd_lookup_values
                   WHERE lookup_type = 'XXDO_PLM_DUAL_SOURCING'
                     AND LANGUAGE = USERENV ('LANG')
                     AND enabled_flag = 'Y'
                     AND attribute2 = rec_sourcing_records.factory
                     AND attribute1 = rec_vendors.vendor_name
                     AND (    TRUNC (start_date_active) <= TRUNC (SYSDATE)
                          AND TRUNC (NVL (end_date_active, SYSDATE)) >=
                                                               TRUNC (SYSDATE)
                         );
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     fnd_file.put_line
                        (fnd_file.LOG,
                         'While fetching the lookup count entered into the excetpion'
                        );
               END;

               -- W.r.t version 1.33(End)
               BEGIN                              -- W.r.t version 1.33(Start)
                  IF l_lkp_cnt > 0
                  THEN
                     fnd_file.put_line (fnd_file.LOG, 'Dual sourcing Y');

                     FOR i IN
                        plm_dual_sourcing_cur (rec_sourcing_records.factory,
                                               rec_vendors.vendor_name
                                              )
                     LOOP
                        --W.r.t Version 1.13
                        ln_sourcing_exist := 0;
                        fnd_file.put_line (fnd_file.LOG,
                                              'Dual sourcing - Supplier '
                                           || i.attribute1
                                          );
                        fnd_file.put_line (fnd_file.LOG,
                                              'Dual sourcing - Site '
                                           || i.attribute2
                                          );
                        fnd_file.put_line (fnd_file.LOG,
                                              'Dual sourcing - Region '
                                           || i.attribute3
                                          );

                        BEGIN
                           SELECT COUNT (*)
                             INTO ln_sourcing_exist
                             FROM apps.xxdo_sourcing_rule_stg
                            WHERE style = rec_sourcing_records.style
                              AND color = rec_sourcing_records.color_code
                              AND supplier_name = i.attribute1
                              AND supplier_site_code = i.attribute2
                              AND SOURCE = 'PLM'
                              AND plm_region = i.attribute3
                              AND TRUNC (start_date) = TRUNC (SYSDATE + 1);
                        --W.r.t Version 1.25
                        --TO_DATE (rec_sourcing_records.purchasing_start_date,'YYYY-MM-DD');
                        /*   AND end_date =
                                    TO_DATE (rec_sourcing_records.purchasing_end_date,
                                             'YYYY-MM-DD'
                                            ); */
                        -- Commented for 1.19.
                        EXCEPTION
                           WHEN OTHERS
                           THEN
                              ln_sourcing_exist := 0;
                        END;

                        fnd_file.put_line (fnd_file.LOG,
                                              'Dual sourcing - Region '
                                           || i.attribute3
                                           || ' Sourcing exists - '
                                           || TO_CHAR (ln_sourcing_exist)
                                          );

                        IF ln_sourcing_exist = 0
                        THEN
                           INSERT INTO apps.xxdo_sourcing_rule_stg
                                       (style,
                                        color,
                                        org_id, assignment_set_id,
                                        supplier_name, supplier_site_code,
                                        SOURCE, plm_region, record_status,
                                        start_date, end_date
                                       )
                                VALUES (rec_sourcing_records.style,
                                        rec_sourcing_records.color_code,
                                        NULL,
                                             --                                                      i.attribute4, -- Ord id
                                        NULL,
                                        i.attribute1,
                                                     --rec_vendors.vendor_name,
                                                     i.attribute2,

                                        --rec_sourcing_records.factory,  -- W.r.t 1.13
                                        'PLM', i.attribute3,       --'GLOBAL',
                                                            NULL,
                                        SYSDATE + 1, NULL
                                       );
                        /*     IF rec_sourcing_records.tq_sourcing_name
                                   IS NOT NULL              --w.r.t Version 1.45
                             THEN
                                lv_vendor_name :=
                                   get_tq_vendor_from_site (
                                      rec_sourcing_records.tq_sourcing_name);

                                INSERT
                                  INTO apps.xxdo_sourcing_rule_stg (
                                          style,
                                          color,
                                          org_id,
                                          assignment_set_id,
                                          supplier_name,
                                          supplier_site_code,
                                          SOURCE,
                                          plm_region,
                                          record_status,
                                          start_date,
                                          end_date)
                                VALUES (rec_sourcing_records.style,
                                        rec_sourcing_records.color_code,
                                        NULL,
                                        --                                                      i.attribute4, -- Ord id
                                        NULL,
                                        --i.attribute1,
                                        lv_vendor_name,
                                        --rec_vendors.vendor_name,
                                        i.attribute2,
                                        --rec_sourcing_records.factory,  -- W.r.t 1.13
                                        'PLM',
                                        --UPPER ( rec_sourcing_records.tq_sourcing_name), --'GLOBAL',
                                        'JP',                    --Use JP Region
                                        NULL,
                                        SYSDATE + 1,
                                        NULL);
                             END IF;                        --w.r.t Version 1.45
                             */
                        END IF;
                     END LOOP;
                  ELSE                              -- W.r.t version 1.33(End)
                     --W.r.t Version 1.13
                     ln_sourcing_exist := 0;
                     fnd_file.put_line (fnd_file.LOG, 'Dual sourcing N');

                     BEGIN
                        SELECT COUNT (*)
                          INTO ln_sourcing_exist
                          FROM apps.xxdo_sourcing_rule_stg
                         WHERE style = rec_sourcing_records.style
                           AND color = rec_sourcing_records.color_code
                           AND supplier_name = rec_vendors.vendor_name
                           AND supplier_site_code =
                                                  rec_sourcing_records.factory
                           AND SOURCE = 'PLM'
                           AND plm_region = 'GLOBAL'
                           AND TRUNC (start_date) = TRUNC (SYSDATE + 1);

                        -- Start changes for defect 677 for V1.46
                        -- check if the factory passed is in the dual_source lookup table
                        --If it is we do not want to add the global source
                        SELECT COUNT (1)
                          INTO ln_is_dual_sourced
                          FROM fnd_lookup_values
                         WHERE lookup_type = 'XXDO_PLM_DUAL_SOURCING'
                           AND LANGUAGE = USERENV ('LANG')
                           AND enabled_flag = 'Y'
                           AND attribute2 =
                                  rec_sourcing_records.factory
                                     --Check for factory only, not vendor name
                           --   AND attribute1 = rec_vendors.vendor_name
                           AND (    TRUNC (start_date_active) <=
                                                               TRUNC (SYSDATE)
                                AND TRUNC (NVL (end_date_active, SYSDATE)) >=
                                                               TRUNC (SYSDATE)
                               );
                     -- End changes for defect 677 for V1.46
                     --W.r.t Version 1.25
                     --TO_DATE (rec_sourcing_records.purchasing_start_date,'YYYY-MM-DD');
                     /*   AND end_date =
                                 TO_DATE (rec_sourcing_records.purchasing_end_date,
                                          'YYYY-MM-DD'
                                         ); */
                     -- Commented for 1.19.
                     EXCEPTION
                        WHEN OTHERS
                        THEN
                           ln_sourcing_exist := 0;
                           ln_is_dual_sourced := 0;
                                            -- Added for defect 677 for V1.46
                     END;

                     -- Start changes for defect 677 for V1.46
                     --IF ln_sourcing_exist = 0
                     IF     ln_sourcing_exist = 0
                        AND ln_is_dual_sourced =
                               0
--Sourcing does not exist and site for vendor is not in the dual-sourece lookup
                     -- End changes for defect 677 for V1.46
                     THEN
                        INSERT INTO apps.xxdo_sourcing_rule_stg
                                    (style,
                                     color,
                                           --oracle_region, -- W.r.t 1.13
                                           org_id,
                                     assignment_set_id, supplier_name,
                                     supplier_site_code, SOURCE,
                                     plm_region, record_status, start_date,
                                     end_date
                                    )
                             VALUES (rec_sourcing_records.style,
                                     rec_sourcing_records.color_code,
                                                                     --lv_sourc_region, -- W.r.t 1.13
                                     NULL,
                                     NULL, rec_vendors.vendor_name,
                                     --rec_vendors.vendor_site_id, -- W.r.t 1.13
                                     --        rec_sourcing_records.supplier || '-' ||  rec_sourcing_records.factory,  -- W.r.t 1.13
                                     rec_sourcing_records.factory,
                                                                   -- W.r.t 1.13
                                     'PLM',
                                     'GLOBAL', NULL,
                                                     /* -- START : Commented for 1.19.
                                                           TO_DATE
                                                           (rec_sourcing_records.purchasing_start_date,
                                                            'YYYY-MM-DD'
                                                           ),                  -- W.r.t Version 1.16
                                                        TO_DATE
                                                           (rec_sourcing_records.purchasing_end_date,
                                                            'YYYY-MM-DD'
                                                           )                   -- W.r.t Version 1.16
                                                     */
                                                     -- END : Commented for 1.19.
                                                     -- START : Modified for 1.19.
                                                     SYSDATE + 1,
                                     NULL          -- END : Modified for 1.19.
                                    --TO_DATE (rec_sourcing_records.begin_date,'YYYY-MM-DD' ),    -- W.r.t Version 1.16
                                    --TO_DATE (rec_sourcing_records.end_date,'YYYY-MM-DD')      -- W.r.t Version 1.16
                                    );
                                          /*   IF rec_sourcing_records.tq_sourcing_name IS NOT NULL --w.r.t Version 1.45
                                             THEN
                                                lv_vendor_name :=
                                                   get_tq_vendor_from_site (
                                                      rec_sourcing_records.tq_sourcing_name);

                                                INSERT
                                                  INTO apps.xxdo_sourcing_rule_stg (
                                                          style,
                                                          color,
                                                          --oracle_region, -- W.r.t 1.13
                                                          org_id,
                                                          assignment_set_id,
                                                          supplier_name,
                                                          supplier_site_code,
                                                          SOURCE,
                                                          plm_region,
                                                          record_status,
                                                          start_date,
                                                          end_date)
                                                VALUES (rec_sourcing_records.style,
                                                        rec_sourcing_records.color_code,
                                                        --lv_sourc_region, -- W.r.t 1.13
                                                        NULL,
                                                        NULL,
                                                        lv_vendor_name,
                                                        --rec_vendors.vendor_site_id, -- W.r.t 1.13
                                                        --        rec_sourcing_records.supplier || '-' ||  rec_sourcing_records.factory,  -- W.r.t 1.13
                                                        rec_sourcing_records.factory,
                                                        -- W.r.t 1.13
                                                        'PLM',
                                                        'JP',
                                                        NULL,
                                                        SYSDATE + 1,
                                                        NULL);
                                             END IF;                           --w.r.t Version 1.45
                     */
                     END IF;

                     COMMIT;
                  END IF;

                  fnd_file.put_line (fnd_file.LOG,
                                        'TQ Sourcing '
                                     || rec_sourcing_records.tq_sourcing_name
                                    );

                  --Moved out of inner IF statement so only one record will be added.
                  IF rec_sourcing_records.tq_sourcing_name IS NOT NULL
                                                          --w.r.t Version 1.45
                  THEN
                     lv_vendor_name :=
                        get_tq_vendor_from_site
                                       (rec_sourcing_records.tq_sourcing_name);
                     ln_sourcing_exist := 0;

                     BEGIN
                        SELECT COUNT (*)
                          INTO ln_sourcing_exist
                          FROM apps.xxdo_sourcing_rule_stg
                         WHERE style = rec_sourcing_records.style
                           AND color = rec_sourcing_records.color_code
                           AND supplier_name = lv_vendor_name
                           AND supplier_site_code =
                                         -- Start changes for defect 677 for V1.46
                                         -- rec_sourcing_records.factory
                                         rec_sourcing_records.tq_sourcing_name
                           -- End changes for defect 677 for V1.46
                           AND SOURCE = 'PLM'
                           AND plm_region = 'JP'
                           AND TRUNC (start_date) = TRUNC (SYSDATE + 1);
                     --W.r.t Version 1.25
                     --TO_DATE (rec_sourcing_records.purchasing_start_date,'YYYY-MM-DD');
                     /*   AND end_date =
                                 TO_DATE (rec_sourcing_records.purchasing_end_date,
                                          'YYYY-MM-DD'
                                         ); */
                     -- Commented for 1.19.
                     EXCEPTION
                        WHEN OTHERS
                        THEN
                           ln_sourcing_exist := 0;
                     END;

                     fnd_file.put_line (fnd_file.LOG,
                                           'TQ Sourcing - Supplier '
                                        || lv_vendor_name
                                       );
                     fnd_file.put_line (fnd_file.LOG,
                                           'TQ Sourcing - Sourcing exists '
                                        || TO_CHAR (ln_sourcing_exist)
                                       );

                     IF ln_sourcing_exist = 0
                     THEN
                        INSERT INTO apps.xxdo_sourcing_rule_stg
                                    (style,
                                     color,
                                           --oracle_region, -- W.r.t 1.13
                                           org_id,
                                     assignment_set_id, supplier_name,
                                     supplier_site_code,
                                     SOURCE, plm_region, record_status,
                                     start_date, end_date
                                    )
                             VALUES (rec_sourcing_records.style,
                                     rec_sourcing_records.color_code,
                                                                     --lv_sourc_region, -- W.r.t 1.13
                                     NULL,
                                     NULL, lv_vendor_name,
                                     --rec_vendors.vendor_site_id, -- W.r.t 1.13
                                     --        rec_sourcing_records.supplier || '-' ||  rec_sourcing_records.factory,  -- W.r.t 1.13
                                     -- Start changes for defect 677 for V1.46
                                     -- rec_sourcing_records.factory,
                                     rec_sourcing_records.tq_sourcing_name,

                                     -- End changes for defect 677 for V1.46
                                     -- W.r.t 1.13
                                     'PLM', 'JP', NULL,
                                     SYSDATE + 1, NULL
                                    );
                     END IF;
                  END IF;

                  COMMIT;                                 --w.r.t Version 1.45
               ---- W.r.t version 1.33
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     gv_retcode := SQLCODE;
                     gv_reterror :=
                        SUBSTR
                           (   'Error Occured while inserting record into XXDO_SOURCING_RULE_STG '
                            || SQLERRM,
                            1,
                            1999
                           );
                     log_error_exception
                             (pv_procedure_name      => lv_pn,
                              pv_style               => rec_sourcing_records.style,
                              pv_color               => rec_sourcing_records.color_code,
                              pv_season              => rec_sourcing_records.currentseason,
                              pv_reterror            => gv_reterror,
                              pv_error_code          => 'REPORT',
                              pv_error_type          => 'SYSTEM'
                             );
               END;
                           /*
                              BEGIN
                                 ln_num_src_rule := NULL;
                                 lv_chr_src_rule_name :=
                                       rec_process_records.style
                                    || '.'
                                    || rec_process_records.color_code
                                    || '.'
                                    || rec_vendors.organization_code;
                                 gv_retcode := NULL;
                                 gv_reterror := NULL;

                                 SELECT msr.sourcing_rule_id
                                   INTO ln_num_src_rule
                                   FROM mrp_sourcing_rules msr, mrp_sr_receipt_org msro
                                  WHERE sourcing_rule_name = lv_chr_src_rule_name
                                    AND msro.sourcing_rule_id = msr.sourcing_rule_id
                                    AND msro.effective_date =
                                           TO_DATE (rec_process_records.begin_date,
                                                    'YYYY-MM-DD'
                                                   )
                                    AND msro.disable_date =
                                           TO_DATE (rec_process_records.end_date,
                                                    'YYYY-MM-DD'
                                                   );
                              EXCEPTION
                                 WHEN OTHERS
                                 THEN
                                    ln_num_src_rule := NULL;
                              END;

                              msg ('Sourcing Rule Name is :: ' || lv_chr_src_rule_name);

                              IF ln_num_src_rule IS NULL
                              THEN
                                 BEGIN
                                    create_src_rule
                                               (lv_chr_src_rule_name,
                                                rec_vendors.organization_id,
                                                rec_vendors.vendor_id,
                                                rec_vendors.vendor_site_id,
                                                NULL,        --TO_NUMBER (child_rec.RANK),
                                                TO_DATE (rec_process_records.begin_date,
                                                         'YYYY-MM-DD'
                                                        ),
                                                TO_DATE (rec_process_records.end_date,
                                                         'YYYY-MM-DD'
                                                        ),
                                                ln_num_src_rule,
                                                gv_reterror,
                                                gv_retcode
                                               );
                                 EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                       gv_retcode := SQLCODE;
                                       msg
                                          (   'Error Occured while creating sourcing rule name :: '
                                           || SQLERRM
                                          );
                                 END;
                              END IF;

                              msg (   ' lv_chr_src_rule_name '
                                   || lv_chr_src_rule_name
                                   || ' ln_num_src_rule '
                                   || ln_num_src_rule
                                  );
            --******************************************************
            -- Check if the item is assigned to sourcing rule
            --****************************************************
                              ln_sou_count := 0;
                              msg (   ' SOURCING RULE CHILD ORG '
                                   || rec_vendors.organization_code
                                   || ' Sourcing Rule Id :: '
                                   || ln_num_src_rule
                                  );

                              BEGIN
                                 SELECT COUNT (*)
                                   INTO ln_sou_count
                                   FROM mrp_sr_assignments msra,
                                        mrp_sr_source_org msro,
                                        mrp_sr_receipt_org msrr
                                  WHERE msrr.sourcing_rule_id = msra.sourcing_rule_id
                                    AND msrr.sr_receipt_id = msro.sr_receipt_id
                                    AND msra.organization_id = rec_vendors.organization_id
                                    AND vendor_id = rec_vendors.vendor_id
                                    AND vendor_site_id = rec_vendors.vendor_site_id
                                    AND category_id = rec_process_records.po_item_cat_id;
                              EXCEPTION
                                 WHEN OTHERS
                                 THEN
                                    ln_sou_count := 0;
                              END;

                              IF ln_sou_count = 0
                              THEN
                                 lv_source_rule_flag := 'Y';
                              ELSE
                                 lv_source_rule_flag := 'N';
                              END IF;

            --*********************************************
            -- ASSIGN SOURCING RULES
            --********************************************
                              IF lv_source_rule_flag = 'Y'
                              THEN
                                 ln_num_assignment := NULL;
                                 gv_retcode := NULL;
                                 gv_reterror := NULL;
                                 lv_error_mesg := NULL;
                                 lv_chr_assign_oper := 'CREATE';
                                 item_src_assignment (lv_chr_assign_oper,
                                                      ln_num_assignment,
                                                      rec_process_records.item_id,
                                                      rec_process_records.po_item_cat_id,
                                                      ln_category_set_id,
                                                      rec_vendors.organization_id,
                                                      rec_process_records.end_date,
                                                      ln_num_src_rule,
                                                      5,             -- Category Org Level
                                                      gv_reterror,
                                                      gv_retcode
                                                     );

                                 IF gv_retcode IS NOT NULL OR gv_reterror IS NOT NULL
                                 THEN
                                    BEGIN
                                       lv_value := lv_value + 1;
                                       lv_flag := 'E';
                                       lv_error_mesg :=
                                             lv_value
                                          || ' Error in Item source rule assigment '
                                          || gv_reterror;
                                       lv_error_message :=
                                          SUBSTR (lv_error_message || lv_error_mesg,
                                                  1,
                                                  2000
                                                 );
                                       log_error_exception
                                          (pv_procedure_name      => lv_pn,
                                           pv_plm_row_id          => rec_process_records.parent_record_id,
                                           pv_style               => rec_process_records.style,
                                           pv_color               => rec_process_records.colorway,
                                           pv_size                => rec_process_records.size_val,
                                           pv_brand               => rec_process_records.brand,
                                           pv_gender              => rec_process_records.gender,
                                           pv_season              => rec_process_records.currentseason,
                                           pv_reterror            => lv_error_mesg
                                          );
                                       msg (' item_src_assignment Error  '
                                            || lv_error_mesg
                                           );
                                    END;
                                 END IF;
                              END IF;

            --*************************************************
            -- Publishing ASL attributes
            --*************************************************
                              gv_retcode := NULL;
                              gv_reterror := NULL;
                              x_asl_id := NULL;
                              x_row_id := NULL;
                              ln_apov_list_count := 0;

                              BEGIN
                                 SELECT asl_id
                                   INTO x_asl_id
                                   FROM po_approved_supplier_list
                                  WHERE owning_organization_id =
                                                               rec_vendors.organization_id
                                    AND vendor_id = rec_vendors.vendor_id
                                    AND vendor_site_id = rec_vendors.vendor_site_id
                                    AND item_id = rec_process_records.item_id;
                              EXCEPTION
                                 WHEN OTHERS
                                 THEN
                                    x_asl_id := NULL;
                              END;

                              IF x_asl_id IS NULL
                              THEN
                                 BEGIN
                                    apps.po_asl_ths.insert_row
                                            (x_row_id,
                                             x_asl_id,
                                             -1,                   --using_organization_id
                                             rec_vendors.organization_id,

                                             --owning_organization_id,
                                             'DIRECT',             --vendor_business_type,
                                             1,                               --status_id,
                                             SYSDATE,                  --last_updated_date
                                             gn_userid,                 --last_updated_by,
                                             SYSDATE,                     --creation_date,
                                             gn_userid,                      --created_by,
                                             NULL,
                                             rec_vendors.vendor_id,           --vendor_id,
                                             rec_process_records.item_id,
                                             --NULL     --inventory_item_id,
                                             NULL,
                                             rec_vendors.vendor_site_id, --vendor_site_id,
                                             NULL,                  --primary_vendor_item,
                                             NULL,
                                             NULL,
                                             NULL,
                                             NULL,
                                             NULL,
                                             NULL,
                                             NULL,
                                             NULL,
                                             NULL,
                                             NULL,
                                             NULL,
                                             NULL,
                                             NULL,
                                             NULL,
                                             NULL,
                                             NULL,
                                             NULL,
                                             NULL,
                                             NULL,
                                             NULL,
                                             NULL
                                            );
                                    COMMIT;
                                 EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                       gv_retcode := SQLCODE;
                                       gv_reterror :=
                                          SUBSTR
                                                (   'Error Occured while inserting ASL '
                                                 || SQLERRM
                                                 || '  '
                                                 || SQLCODE,
                                                 1,
                                                 1999
                                                );
                                       msg (gv_reterror);
                                 END;
                              END IF;

                              ln_asl_count := 0;

                              BEGIN
                                 SELECT COUNT (1)
                                   INTO ln_asl_count
                                   FROM po_asl_attributes
                                  WHERE asl_id = x_asl_id;
                              EXCEPTION
                                 WHEN OTHERS
                                 THEN
                                    ln_asl_count := 0;
                              END;

                              IF ln_asl_count = 0
                              THEN
                                 BEGIN
                                    x_row_id := NULL;
                                    apps.po_asl_attributes_ths.insert_row
                                        (x_row_id,
                                         x_asl_id,                                --asl_id
                                         -1,                       --using_organization_id
                                         SYSDATE,                      --last_updated_date
                                         gn_userid,                     --last_updated_by,
                                         SYSDATE,                          --creation_date
                                         gn_userid,                          --created_by,
                                         'ASL',                 --document_sourcing_method
                                         'CREATE_AND_APPROVE', --release_generation_method
                                         NULL,
                                         NULL,
                                         NULL,
                                         NULL,
                                         NULL,
                                         NULL,
                                         NULL,
                                         NULL,
                                         NULL,
                                         NULL,
                                         rec_vendors.vendor_id,               --vendor_id,
                                         rec_vendors.vendor_site_id,     --vendor_site_id,
                                         rec_process_records.item_id,
                                         --NULL,                        --inventory_item_id,
                                         NULL,                              --Category_id,
                                         NULL,                        --attribute_category
                                         NULL,                        --state(attribute1),
                                         NULL,
                                         NULL,
                                         NULL,
                                         NULL,
                                         NULL,
                                         NULL,
                                         NULL,
                                         NULL,
                                         NULL,
                                         NULL,
                                         NULL,
                                         NULL,
                                         NULL,
                                         NULL,
                                         NULL,
                                         NULL,
                                         TO_NUMBER (rec_process_records.lead_time),
                                         NULL,
                                         NULL,
                                         NULL,
                                         'US',                   --country_of_origin_code,
                                         NULL,
                                         NULL,
                                         NULL,
                                         NULL,
                                         NULL,
                                         NULL,
                                         NULL,
                                         NULL,
                                         NULL,
                                         NULL,
                                         NULL,
                                         NULL,
                                         NULL,
                                         NULL,
                                         NULL
                                        );
                                 EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                       gv_retcode := SQLCODE;
                                       gv_reterror :=
                                          SUBSTR
                                             (   'Error Occured while inserting ASL Attributes'
                                              || SQLERRM,
                                              1,
                                              1999
                                             );
                                       msg (gv_reterror);
                                 END;
                              END IF;

                              msg (   'After ASL :: '
                                   || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                                  );

                              IF gv_retcode IS NOT NULL OR gv_reterror IS NOT NULL
                              THEN
                                 BEGIN
                                    lv_value := lv_value + 1;
                                    lv_flag := 'E';
                                    lv_error_mesg :=
                                       SUBSTR (   lv_value
                                               || ' Error In ASL Attributes   '
                                               || gv_retcode
                                               || ' : '
                                               || gv_reterror,
                                               1,
                                               2000
                                              );
                                    lv_error_message :=
                                       SUBSTR (lv_error_mesg || lv_error_message, 1, 2000);
                                    log_error_exception
                                       (pv_procedure_name      => lv_pn,
                                        pv_plm_row_id          => rec_process_records.parent_record_id,
                                        pv_style               => rec_process_records.style,
                                        pv_color               => rec_process_records.colorway,
                                        pv_size                => rec_process_records.size_val,
                                        pv_brand               => rec_process_records.brand,
                                        pv_gender              => rec_process_records.gender,
                                        pv_season              => rec_process_records.currentseason,
                                        pv_reterror            => lv_error_mesg
                                       );
                                    msg (lv_error_mesg);
                                 END;
                              END IF;
                              */
                        --End W.r.t Version 1.8
            END LOOP;                                       -- End cur_vendors
         END LOOP;                                          -- End cur_vendors

         fnd_file.put_line
             (fnd_file.LOG,
                 '********Cursor csr_sourcing_records Sourcing Rule Ended at '
              || TO_CHAR (SYSDATE, 'DD-MM-YYYY HH24:MI:SS')
             );

         -- csr_process_records

         --*********************************************
-- INSERT COST DATA TO COST INTERCAE TABLE
--********************************************
         IF UPPER (NVL (gv_reprocess, 'N')) IN
                                              ('N', 'NO') --W.r.t Version 1.34
         THEN
            BEGIN
               lv_error_mesg := NULL;
               gv_reterror := NULL;
               gv_retcode := NULL;
               msg (   'Import Cost data  :: '
                    || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                   );
               insert_into_cost_interface (ln_item_id, gv_reterror,
                                           gv_retcode);
            EXCEPTION
               WHEN OTHERS
               THEN
                  gv_reterror := SQLCODE;
                  gv_retcode :=
                     SUBSTR (   'Error Occured while creating cost type'
                             || SQLERRM,
                             1,
                             1999
                            );
            END;
         END IF;                                          --W.r.t Version 1.34

         IF gv_retcode IS NOT NULL OR gv_reterror IS NOT NULL
         THEN
            BEGIN
               lv_value := lv_value + 1;
               lv_flag := 'E';
               lv_error_mesg :=
                  SUBSTR (   lv_value
                          || ' Error in cost assignment '
                          || gv_retcode
                          || '  '
                          || gv_reterror,
                          1,
                          1000
                         );
               lv_error_message :=
                           SUBSTR (lv_error_mesg || lv_error_message, 1, 2000);
               log_error_exception (pv_procedure_name      => lv_pn,
                                    pv_reterror            => lv_error_mesg,
                                    pv_error_code          => 'REPORT',
                                    pv_error_type          => 'SYSTEM'
                                   );
               fnd_file.put_line (fnd_file.LOG,
                                  ' Cost attribute Error  ' || lv_error_mesg
                                 );
            END;
         END IF;

         fnd_file.put_line
            (fnd_file.LOG,
                ' Cursor csr_item_cat_assign for category ASSIGNMENT started at '
             || TO_CHAR (SYSDATE, 'DD-MM-YYYY HH24:MI:SS')
            );

         -- Assigning Item Categories
         FOR items_cat_assi_rec IN csr_item_cat_assign
         LOOP
            BEGIN
               lv_error_mesg := NULL;
               gv_retcode := NULL;
               gv_reterror := NULL;
               gv_colorway_state := UPPER (items_cat_assi_rec.life_cycle);
               --W.r.t 1.17
               --msg (   'Before Assigning Inventory Category :: '
               --    || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
               --  );
               -- Assigning Inventory Category
               assign_inventory_category
                             (items_cat_assi_rec.batch_id,
                              items_cat_assi_rec.brand,
                              items_cat_assi_rec.gender,
                              items_cat_assi_rec.product_group,
                              items_cat_assi_rec.CLASS,
                              items_cat_assi_rec.sub_class,
                              items_cat_assi_rec.master_style,
                              -- items_cat_assi_rec.style, --UPPER (TRIM (items_cat_assi_rec.style)), -- W.r.t Version 1.1
                              items_cat_assi_rec.style_name,
                              -- W.r.t Version 1.1
                              items_cat_assi_rec.colorway,
                              items_cat_assi_rec.organization_id,
                              items_cat_assi_rec.currentseason,
                              UPPER (TRIM (items_cat_assi_rec.colorwaystatus)),
                              -- items_cat_assi_rec.size_val, --W.r.t Version 1.32
                              items_cat_assi_rec.style,   --W.r.t Version 1.32
                              items_cat_assi_rec.item_id,
                              gv_retcode,
                              gv_reterror
                             );

               IF gv_retcode IS NOT NULL AND gv_reterror IS NOT NULL
               THEN
                  lv_error_mesg :=
                        'Error Ocurred While assigning Inventory category '
                     || items_cat_assi_rec.organization_id
                     || 'To '
                     || items_cat_assi_rec.item_number
                     || ' - '
                     || gv_retcode
                     || '  '
                     || gv_reterror;
                  log_error_exception
                        (pv_procedure_name      => lv_pn,
                         pv_plm_row_id          => items_cat_assi_rec.parent_record_id,
                         pv_style               => items_cat_assi_rec.style,
                         pv_color               => items_cat_assi_rec.color_code,
                         pv_size                => items_cat_assi_rec.size_val,
                         pv_brand               => items_cat_assi_rec.brand,
                         pv_gender              => items_cat_assi_rec.gender,
                         pv_season              => items_cat_assi_rec.currentseason,
                         pv_reterror            => lv_error_mesg,
                         pv_error_code          => 'REPORT',
                         pv_error_type          => 'SYSTEM'
                        );
               END IF;
            END;

--*************************************************
-- Assign OM SALES
--************************************************
-- START : Added for 1.22.
            IF items_cat_assi_rec.style_name IS NOT NULL
            THEN
               -- END : Added for 1.22.
               BEGIN
                  lv_error_mesg := NULL;
                  gv_retcode := NULL;
                  gv_reterror := NULL;
                  -- Assigning OM Sales Category
                  assign_category (items_cat_assi_rec.batch_id,
                                   --UPPER (TRIM (items_cat_assi_rec.style)), -- W.r.t version 1.1
                                   items_cat_assi_rec.style_name,
                                   -- W.r.t version 1.1
                                   NULL,
                                   NULL,
                                   NULL,
                                   NULL,
                                   items_cat_assi_rec.item_id,
                                   items_cat_assi_rec.organization_id,
                                   items_cat_assi_rec.colorwaystatus,
                                   'OM Sales Category',
                                   gv_retcode,
                                   gv_reterror
                                  );

                  IF gv_retcode IS NOT NULL AND gv_reterror IS NOT NULL
                  THEN
                     lv_error_mesg :=
                           'Error Ocurred While assigning OM Sales category '
                        || items_cat_assi_rec.organization_id
                        || 'To '
                        || items_cat_assi_rec.item_number
                        || ' - '
                        || gv_retcode
                        || '  '
                        || gv_reterror;
                     log_error_exception
                        (pv_procedure_name      => lv_pn,
                         pv_plm_row_id          => items_cat_assi_rec.parent_record_id,
                         pv_style               => items_cat_assi_rec.style,
                         pv_color               => items_cat_assi_rec.color_code,
                         pv_size                => items_cat_assi_rec.size_val,
                         pv_brand               => items_cat_assi_rec.brand,
                         pv_gender              => items_cat_assi_rec.gender,
                         pv_season              => items_cat_assi_rec.currentseason,
                         pv_reterror            => lv_error_mesg,
                         pv_error_code          => 'REPORT',
                         pv_error_type          => 'SYSTEM'
                        );
                  END IF;
               END;
            END IF;                                         -- Added for 1.22.

--**********************************************************
-- Assign MASTER SEASON category for Sales Begin,end dates
--*********************************************************
            BEGIN
               lv_error_mesg := NULL;
               gv_retcode := NULL;
               gv_reterror := NULL;
               -- Assigning Master Season Category
               assign_multi_mem_category ('MASTER_SEASON',
                                          items_cat_assi_rec.currentseason,
                                          items_cat_assi_rec.begin_date,
                                          items_cat_assi_rec.end_date,
                                          items_cat_assi_rec.brand,
                                          'SALES',
                                          items_cat_assi_rec.item_id,
                                          items_cat_assi_rec.organization_id,
                                          gv_retcode,
                                          gv_reterror
                                         );

               IF gv_retcode IS NOT NULL AND gv_reterror IS NOT NULL
               THEN
                  lv_error_mesg :=
                        'Error Ocurred While assigning Master season category '
                     || items_cat_assi_rec.organization_id
                     || 'To '
                     || items_cat_assi_rec.item_number
                     || ' - '
                     || gv_retcode
                     || '  '
                     || gv_reterror;
                  log_error_exception
                        (pv_procedure_name      => lv_pn,
                         pv_plm_row_id          => items_cat_assi_rec.parent_record_id,
                         pv_style               => items_cat_assi_rec.style,
                         pv_color               => items_cat_assi_rec.color_code,
                         pv_size                => items_cat_assi_rec.size_val,
                         pv_brand               => items_cat_assi_rec.brand,
                         pv_gender              => items_cat_assi_rec.gender,
                         pv_season              => items_cat_assi_rec.currentseason,
                         pv_reterror            => lv_error_mesg,
                         pv_error_code          => 'REPORT',
                         pv_error_type          => 'SYSTEM'
                        );
               END IF;
            EXCEPTION
               WHEN OTHERS
               THEN
                  fnd_file.put_line
                     (fnd_file.LOG,
                         'Error in Assigning Master Season Category for Sales Begin end dates :: '
                      || SQLERRM
                     );
            END;

--***************************************************************
-- Assign MASTER SEASON category for Purchasing Begin,end dates
--**************************************************************
            BEGIN
               lv_error_mesg := NULL;
               gv_retcode := NULL;
               gv_reterror := NULL;
               -- Assigning Master Season Category
               assign_multi_mem_category
                                   ('MASTER_SEASON',
                                    items_cat_assi_rec.currentseason,
                                    items_cat_assi_rec.purchasing_start_date,
                                    items_cat_assi_rec.purchasing_end_date,
                                    items_cat_assi_rec.brand,
                                    'PURCHASING',
                                    items_cat_assi_rec.item_id,
                                    items_cat_assi_rec.organization_id,
                                    gv_retcode,
                                    gv_reterror
                                   );

               IF gv_retcode IS NOT NULL AND gv_reterror IS NOT NULL
               THEN
                  lv_error_mesg :=
                        'Error Ocurred While assigning Master season category '
                     || items_cat_assi_rec.organization_id
                     || 'To '
                     || items_cat_assi_rec.item_number
                     || ' - '
                     || gv_retcode
                     || '  '
                     || gv_reterror;
                  log_error_exception
                        (pv_procedure_name      => lv_pn,
                         pv_plm_row_id          => items_cat_assi_rec.parent_record_id,
                         pv_style               => items_cat_assi_rec.style,
                         pv_color               => items_cat_assi_rec.color_code,
                         pv_size                => items_cat_assi_rec.size_val,
                         pv_brand               => items_cat_assi_rec.brand,
                         pv_gender              => items_cat_assi_rec.gender,
                         pv_season              => items_cat_assi_rec.currentseason,
                         pv_reterror            => lv_error_mesg,
                         pv_error_code          => 'REPORT',
                         pv_error_type          => 'SYSTEM'
                        );
               END IF;
            EXCEPTION
               WHEN OTHERS
               THEN
                  fnd_file.put_line
                     (fnd_file.LOG,
                         'Error in Assigning Master Season Category for Purchasing Start end dates :: '
                      || SQLERRM
                     );
            END;

            /* -- W.r.t version 1.10
            --*************************************************
             -- Assign production Line category
             --************************************************
                        BEGIN
                           lv_error_mesg := NULL;
                           gv_retcode := NULL;
                           gv_reterror := NULL;
                           msg (   'Before Assigning Production Line Category :: '
                                || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                               );
                           -- Assigning Production Line Category
                           assign_category
                                       (items_cat_assi_rec.batch_id,
                                        items_cat_assi_rec.supplier,
                                        items_cat_assi_rec.factory,
                                        TRIM (SUBSTR (items_cat_assi_rec.production_line,
                                                      0,
                                                      40
                                                     )
                                             ),
                                        --W.r.t Version 1.1
                                        NULL,
                                        NULL,
                                        items_cat_assi_rec.item_id,
                                        items_cat_assi_rec.organization_id,
                                        UPPER (TRIM (items_cat_assi_rec.colorwaystatus)),
                                        'PRODUCTION_LINE',
                                        gv_retcode,
                                        gv_reterror
                                       );

                           IF gv_retcode IS NOT NULL AND gv_reterror IS NOT NULL
                           THEN
                              lv_error_mesg :=
                                    'Error Ocurred While assigning production  Line category '
                                 || items_cat_assi_rec.organization_id
                                 || 'To '
                                 || items_cat_assi_rec.item_number
                                 || ' - '
                                 || gv_retcode
                                 || '  '
                                 || gv_reterror;
                              log_error_exception
                                    (pv_procedure_name      => lv_pn,
                                     pv_plm_row_id          => items_cat_assi_rec.parent_record_id,
                                     pv_style               => items_cat_assi_rec.style,
                                     pv_color               => items_cat_assi_rec.colorway,
                                     pv_size                => items_cat_assi_rec.size_val,
                                     pv_brand               => items_cat_assi_rec.brand,
                                     pv_gender              => items_cat_assi_rec.gender,
                                     pv_season              => items_cat_assi_rec.currentseason,
                                     pv_reterror            => lv_error_mesg
                                    );
                           END IF;
                        END;
            */
            -- W.r.t version 1.10
            --*************************************************-- Assign COLLECTION category--************************************************
            BEGIN
               lv_error_mesg := NULL;
               gv_retcode := NULL;
               gv_reterror := NULL;

               IF items_cat_assi_rec.collection IS NOT NULL
               THEN
                  -- Assigning Collection Category
                  assign_category
                             (items_cat_assi_rec.batch_id,
                              items_cat_assi_rec.collection,
                              --UPPER (TRIM (items_cat_assi_rec.collection)),
                              items_cat_assi_rec.currentseason,
                              --UPPER (TRIM (items_cat_assi_rec.currentseason)),
                              NULL,
                              NULL,
                              NULL,
                              items_cat_assi_rec.item_id,
                              items_cat_assi_rec.organization_id,
                              UPPER (TRIM (items_cat_assi_rec.colorwaystatus)),
                              'COLLECTION',
                              gv_retcode,
                              gv_reterror
                             );

                  IF gv_retcode IS NOT NULL AND gv_reterror IS NOT NULL
                  THEN
                     lv_error_mesg :=
                           'Error Ocurred While assigning COLLECTION category '
                        || items_cat_assi_rec.organization_id
                        || 'To '
                        || items_cat_assi_rec.item_number
                        || ' - '
                        || gv_retcode
                        || '  '
                        || gv_reterror;
                     log_error_exception
                        (pv_procedure_name      => lv_pn,
                         pv_plm_row_id          => items_cat_assi_rec.parent_record_id,
                         pv_style               => items_cat_assi_rec.style,
                         pv_color               => items_cat_assi_rec.color_code,
                         pv_size                => items_cat_assi_rec.size_val,
                         pv_brand               => items_cat_assi_rec.brand,
                         pv_gender              => items_cat_assi_rec.gender,
                         pv_season              => items_cat_assi_rec.currentseason,
                         pv_reterror            => lv_error_mesg,
                         pv_error_code          => 'REPORT',
                         pv_error_type          => 'SYSTEM'
                        );
                  END IF;
               END IF;
            END;

--*************************************************
-- Assign ITEM_TYPE category
--************************************************
-- START : Added for 1.22.
            IF items_cat_assi_rec.item_type IS NOT NULL
            THEN
               -- END : Added for 1.22.
               BEGIN
                  lv_error_mesg := NULL;
                  gv_retcode := NULL;
                  gv_reterror := NULL;
                  -- Assigning Item Type Category
                  assign_category
                             (items_cat_assi_rec.batch_id,
                              items_cat_assi_rec.item_type,
                              --UPPER (TRIM (items_cat_assi_rec.item_type)),
                              items_cat_assi_rec.currentseason,
                              --UPPER (TRIM (items_cat_assi_rec.currentseason)),
                              NULL,
                              NULL,
                              NULL,
                              items_cat_assi_rec.item_id,
                              items_cat_assi_rec.organization_id,
                              UPPER (TRIM (items_cat_assi_rec.colorwaystatus)),
                              'ITEM_TYPE',
                              gv_retcode,
                              gv_reterror
                             );

                  IF gv_retcode IS NOT NULL AND gv_reterror IS NOT NULL
                  THEN
                     lv_error_mesg :=
                           'Error Ocurred While assigning COLLECTION category '
                        || items_cat_assi_rec.organization_id
                        || 'To '
                        || items_cat_assi_rec.item_number
                        || ' - '
                        || gv_retcode
                        || '  '
                        || gv_reterror;
                     log_error_exception
                        (pv_procedure_name      => lv_pn,
                         pv_plm_row_id          => items_cat_assi_rec.parent_record_id,
                         pv_style               => items_cat_assi_rec.style,
                         pv_color               => items_cat_assi_rec.color_code,
                         pv_size                => items_cat_assi_rec.size_val,
                         pv_brand               => items_cat_assi_rec.brand,
                         pv_gender              => items_cat_assi_rec.gender,
                         pv_season              => items_cat_assi_rec.currentseason,
                         pv_reterror            => lv_error_mesg,
                         pv_error_code          => 'REPORT',
                         pv_error_type          => 'SYSTEM'
                        );
                  END IF;
               END;
            END IF;                                         -- Added for 1.22.

--*************************************************
-- Assign project type category
--************************************************
-- START : Added for 1.22.
            IF items_cat_assi_rec.project_type IS NOT NULL
            THEN
               -- END : Added for 1.22.
               BEGIN
                  lv_error_mesg := NULL;
                  gv_retcode := NULL;
                  gv_reterror := NULL;
                  -- Assigning Project Type Category
                  assign_category
                             (items_cat_assi_rec.batch_id,
                              items_cat_assi_rec.project_type,
                              --UPPER (TRIM (items_cat_assi_rec.project_type)),
                              items_cat_assi_rec.currentseason,
                              --UPPER (TRIM (items_cat_assi_rec.currentseason)),
                              NULL,
                              NULL,
                              NULL,
                              items_cat_assi_rec.item_id,
                              items_cat_assi_rec.organization_id,
                              UPPER (TRIM (items_cat_assi_rec.colorwaystatus)),
                              'PROJECT_TYPE',
                              gv_retcode,
                              gv_reterror
                             );

                  IF gv_retcode IS NOT NULL AND gv_reterror IS NOT NULL
                  THEN
                     lv_error_mesg :=
                           'Error Ocurred While assigning project type category '
                        || items_cat_assi_rec.organization_id
                        || 'To '
                        || items_cat_assi_rec.item_number
                        || ' - '
                        || gv_retcode
                        || '  '
                        || gv_reterror;
                     log_error_exception
                        (pv_procedure_name      => lv_pn,
                         pv_plm_row_id          => items_cat_assi_rec.parent_record_id,
                         pv_style               => items_cat_assi_rec.style,
                         pv_color               => items_cat_assi_rec.color_code,
                         pv_size                => items_cat_assi_rec.size_val,
                         pv_brand               => items_cat_assi_rec.brand,
                         pv_gender              => items_cat_assi_rec.gender,
                         pv_season              => items_cat_assi_rec.currentseason,
                         pv_reterror            => lv_error_mesg,
                         pv_error_code          => 'REPORT',
                         pv_error_type          => 'SYSTEM'
                        );
                     COMMIT;
                  END IF;
               END;
            END IF;                                         -- Added for 1.22.

--*************************************************
-- Assign Po Item category
--************************************************
            BEGIN
               lv_error_mesg := NULL;
               gv_retcode := NULL;
               gv_reterror := NULL;
               -- Assigning PO Item Category
               assign_category
                             (items_cat_assi_rec.batch_id,
                              'Trade',
                              --UPPER (TRIM (items_cat_assi_rec.item_type)),
                              items_cat_assi_rec.CLASS,
                              --UPPER (TRIM (items_cat_assi_rec.CLASS)),
                              items_cat_assi_rec.style_name,
                              -- W.r.t Version 1.1
                              --items_cat_assi_rec.style_name, -- W.r.t Version 1.1
                              --UPPER (TRIM (items_cat_assi_rec.style)),
                              NULL,
                              NULL,
                              items_cat_assi_rec.item_id,
                              items_cat_assi_rec.organization_id,
                              UPPER (TRIM (items_cat_assi_rec.colorwaystatus)),
                              'PO Item Category',
                              gv_retcode,
                              gv_reterror
                             );

               IF gv_retcode IS NOT NULL AND gv_reterror IS NOT NULL
               THEN
                  lv_error_mesg :=
                        'Error Ocurred While assigning PO Item Category category '
                     || items_cat_assi_rec.organization_id
                     || 'To '
                     || items_cat_assi_rec.item_number
                     || ' - '
                     || gv_retcode
                     || '  '
                     || gv_reterror;
                  log_error_exception
                        (pv_procedure_name      => lv_pn,
                         pv_plm_row_id          => items_cat_assi_rec.parent_record_id,
                         pv_style               => items_cat_assi_rec.style,
                         pv_color               => items_cat_assi_rec.color_code,
                         pv_size                => items_cat_assi_rec.size_val,
                         pv_brand               => items_cat_assi_rec.brand,
                         pv_gender              => items_cat_assi_rec.gender,
                         pv_season              => items_cat_assi_rec.currentseason,
                         pv_reterror            => lv_error_mesg,
                         pv_error_code          => 'REPORT',
                         pv_error_type          => 'SYSTEM'
                        );
               END IF;
            END;

--*************************************************
-- Assign QR category
--************************************************
            IF items_cat_assi_rec.life_cycle = 'ILR'
            THEN
               BEGIN
                  lv_error_mesg := NULL;
                  gv_retcode := NULL;
                  gv_reterror := NULL;

                  -- Assigning QR Category
                  /*  -- Qr Codes are not required as per Shahns Email
                  assign_category
                              (items_cat_assi_rec.batch_id,
                               items_cat_assi_rec.currentseason,
                               --UPPER (TRIM (items_cat_assi_rec.currentseason)),
                               NULL,
                               NULL,
                               NULL,
                               NULL,
                               items_cat_assi_rec.item_id,
                               items_cat_assi_rec.organization_id,
                               UPPER (TRIM (items_cat_assi_rec.colorwaystatus)),
                               'QR',
                               gv_retcode,
                               gv_reterror
                              );
                              */
                  IF gv_retcode IS NOT NULL AND gv_reterror IS NOT NULL
                  THEN
                     lv_error_mesg :=
                           'Error Ocurred While assigning QR category '
                        || items_cat_assi_rec.organization_id
                        || 'To '
                        || items_cat_assi_rec.item_number
                        || ' - '
                        || gv_retcode
                        || '  '
                        || gv_reterror;
                     log_error_exception
                        (pv_procedure_name      => lv_pn,
                         pv_plm_row_id          => items_cat_assi_rec.parent_record_id,
                         pv_style               => items_cat_assi_rec.style,
                         pv_color               => items_cat_assi_rec.color_code,
                         pv_size                => items_cat_assi_rec.size_val,
                         pv_brand               => items_cat_assi_rec.brand,
                         pv_gender              => items_cat_assi_rec.gender,
                         pv_season              => items_cat_assi_rec.currentseason,
                         pv_reterror            => lv_error_mesg,
                         pv_error_code          => 'REPORT',
                         pv_error_type          => 'SYSTEM'
                        );
                  END IF;
               END;
            END IF;

--*******************************************
-- Assign tariff code category
--*******************************************
            FOR tarif_rec IN
               csr_tarif_cat_assign (items_cat_assi_rec.tariff_country_code)
            LOOP
               BEGIN
                  IF items_cat_assi_rec.tariff IS NOT NULL
                  THEN
                     lv_error_mesg := NULL;
                     gv_retcode := NULL;
                     gv_reterror := NULL;
                     assign_multi_mem_category
                                     ('TARRIF CODE',
                                      items_cat_assi_rec.tariff_code,
                                      --UPPER (TRIM (items_cat_assi_rec.tariff_code)),
                                      items_cat_assi_rec.tariff_country_code,

                                      --UPPER (TRIM (items_cat_assi_rec.country_code)),
                                      'N',
                                      NULL,
                                      NULL,
                                      items_cat_assi_rec.item_id,
                                      tarif_rec.organization_id,
                                      gv_retcode,
                                      gv_reterror
                                     );

                     IF gv_retcode IS NOT NULL AND gv_reterror IS NOT NULL
                     THEN
                        lv_error_mesg :=
                              'Error Ocurred While assigning tariff code category '
                           || tarif_rec.organization_id
                           || 'To '
                           || items_cat_assi_rec.item_number
                           || ' - '
                           || gv_retcode
                           || '  '
                           || gv_reterror;
                        log_error_exception
                           (pv_procedure_name      => lv_pn,
                            pv_plm_row_id          => items_cat_assi_rec.parent_record_id,
                            pv_style               => items_cat_assi_rec.style,
                            pv_color               => items_cat_assi_rec.color_code,
                            pv_size                => items_cat_assi_rec.size_val,
                            pv_brand               => items_cat_assi_rec.brand,
                            pv_gender              => items_cat_assi_rec.gender,
                            pv_season              => items_cat_assi_rec.currentseason,
                            pv_reterror            => lv_error_mesg,
                            pv_error_code          => 'REPORT',
                            pv_error_type          => 'SYSTEM'
                           );
                     END IF;
                  END IF;
               END;
            END LOOP;                                  -- csr_tarif_cat_assign

--*************************************************
-- Assign production Line category W.r.t Version 1.10
--************************************************

            -- START : Added for 1.22.
            IF     items_cat_assi_rec.supplier IS NOT NULL
               AND items_cat_assi_rec.factory IS NOT NULL
               AND items_cat_assi_rec.production_line IS NOT NULL
            THEN
               -- END : Added for 1.22.
               --   FOR rec_prod_cat_assign IN csr_prod_cat_assign  -- Commented for 1.22.
               FOR rec_prod_cat_assign IN
                  csr_prod_cat_assign (items_cat_assi_rec.item_id)
               -- Modified for 1.22.
               LOOP
                  BEGIN
                     lv_error_mesg := NULL;
                     gv_retcode := NULL;
                     gv_reterror := NULL;
                     gv_colorway_state :=
                                       UPPER (rec_prod_cat_assign.life_cycle);
                     --W.r.t 1.17
                     --     msg
                     --        (   'Before Assigning Mutli Production Line Category :: '
                     --        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                     --       );
                     -- Assigning Production Line Category
                     assign_multi_mem_category
                          ('PRODUCTION_LINE',
                           items_cat_assi_rec.supplier,
                           items_cat_assi_rec.factory,
                           TRIM (SUBSTR (items_cat_assi_rec.production_line,
                                         0,
                                         40
                                        )
                                ),
                           NULL,
                           NULL,
                           items_cat_assi_rec.item_id,
                           rec_prod_cat_assign.organization_id,
                           gv_retcode,
                           gv_reterror
                          );

                     IF gv_retcode IS NOT NULL AND gv_reterror IS NOT NULL
                     THEN
                        lv_error_mesg :=
                              'Error Ocurred While assigning production  Line category '
                           || rec_prod_cat_assign.organization_id
                           || 'To '
                           || items_cat_assi_rec.item_number
                           || ' - '
                           || gv_retcode
                           || '  '
                           || gv_reterror;
                        log_error_exception
                           (pv_procedure_name      => lv_pn,
                            pv_plm_row_id          => items_cat_assi_rec.parent_record_id,
                            pv_style               => items_cat_assi_rec.style,
                            pv_color               => items_cat_assi_rec.color_code,
                            pv_size                => items_cat_assi_rec.size_val,
                            pv_brand               => items_cat_assi_rec.brand,
                            pv_gender              => items_cat_assi_rec.gender,
                            pv_season              => items_cat_assi_rec.currentseason,
                            pv_reterror            => lv_error_mesg,
                            pv_error_code          => 'REPORT',
                            pv_error_type          => 'SYSTEM'
                           );
                     END IF;
                  END;
               END LOOP;                                  --W.r.t Version 1.10
            END IF;                                         -- Added for 1.22.

            -- Assigning Region Category
            FOR rec_region_cat IN
               csr_region_cat_assign (items_cat_assi_rec.parent_record_id)
            LOOP
               BEGIN
                  IF rec_region_cat.region_name IS NOT NULL
                  THEN
                     gv_retcode := NULL;
                     gv_reterror := NULL;
                     lv_error_mesg := NULL;
                     assign_multi_mem_category
                                         ('REGION',
                                          rec_region_cat.region_name,
                                          --UPPER (TRIM (rec_region_cat.region_name)),
                                          rec_region_cat.colorway_status,
                                          --UPPER (TRIM (rec_region_cat.colorway_status)),
                                          rec_region_cat.intro_date,
                                          --UPPER (TRIM (rec_region_cat.intro_date)),
                                          items_cat_assi_rec.currentseason,
                                          --UPPER (TRIM (items_cat_assi_rec.currentseason)),
                                          NULL,
                                          items_cat_assi_rec.item_id,
                                          items_cat_assi_rec.organization_id,
                                          gv_retcode,
                                          gv_reterror
                                         );

                     IF gv_retcode IS NOT NULL AND gv_reterror IS NOT NULL
                     THEN
                        lv_error_mesg :=
                              'Error Ocurred While assigning tariff code category '
                           || items_cat_assi_rec.organization_id
                           || 'To '
                           || items_cat_assi_rec.item_number
                           || ' - '
                           || gv_retcode
                           || '  '
                           || gv_reterror;
                        log_error_exception
                           (pv_procedure_name      => lv_pn,
                            pv_plm_row_id          => items_cat_assi_rec.parent_record_id,
                            pv_style               => items_cat_assi_rec.style,
                            pv_color               => items_cat_assi_rec.color_code,
                            pv_size                => items_cat_assi_rec.size_val,
                            pv_brand               => items_cat_assi_rec.brand,
                            pv_gender              => items_cat_assi_rec.gender,
                            pv_season              => items_cat_assi_rec.currentseason,
                            pv_reterror            => lv_error_mesg,
                            pv_error_code          => 'REPORT',
                            pv_error_type          => 'SYSTEM'
                           );
                     END IF;
                  END IF;
               END;
            END LOOP;                                 -- csr_region_cat_assign
         END LOOP;                                      -- csr_item_cat_assign

         fnd_file.put_line (fnd_file.LOG,
                               ' Cursor csr_item_cat_assign  End at '
                            || TO_CHAR (SYSDATE, 'DD-MM-YYYY HH24:MI:SS')
                           );
--**********************************
-- CATEGORY ASSIGNMENT CURSOR --1.26
--**********************************
         fnd_file.put_line (fnd_file.LOG,
                               ' Cursor import_cat_items_cur  Strated at '
                            || TO_CHAR (SYSDATE, 'DD-MM-YYYY HH24:MI:SS')
                           );
         g_tab_temp_req.DELETE;

         FOR cat_rec IN import_cat_items_cur              --W.r.t Version 1.26
         LOOP
            BEGIN
               gv_retcode := NULL;
               gv_reterror := NULL;
               fnd_file.put_line (fnd_file.LOG,
                                     ' submitting import program for '
                                  || cat_rec.set_process_id
                                 );
               submit_category_import (cat_rec.set_process_id,
                                       '1'         -- upload processed records
                                          ,
                                       '1'         -- delete processed records
                                          ,
                                       ln_req_id,
                                       gv_reterror,
                                       gv_retcode
                                      );
            EXCEPTION
               WHEN OTHERS
               THEN
                  fnd_file.put_line
                            (fnd_file.LOG,
                                ' Error while submitting import program for '
                             || cat_rec.set_process_id
                            );
            END;

            IF gv_retcode IS NOT NULL AND gv_reterror IS NOT NULL
            THEN
               fnd_file.put_line
                             (fnd_file.LOG,
                                 'Error while submitting import program for '
                              || SQLERRM
                             );
            END IF;
         END LOOP;

         fnd_file.put_line (fnd_file.LOG,
                               ' Cursor import_cat_items_cur  Ended at '
                            || TO_CHAR (SYSDATE, 'DD-MM-YYYY HH24:MI:SS')
                           );

         IF g_tab_temp_req.COUNT > 0                      --W.r.t Version 1.27
         THEN
            FOR i IN g_tab_temp_req.FIRST .. g_tab_temp_req.LAST
            LOOP
               BEGIN
                  wait_for_request (g_tab_temp_req (i).request_id);
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     fnd_file.put_line
                                (fnd_file.LOG,
                                    'Error while submitting wait_for_request'
                                 || SQLERRM
                                );
               END;
            END LOOP;
         END IF;                                          --W.r.t Version 1.27

         BEGIN
            UPDATE xxdo.xxdo_plm_itemast_stg stg
               SET last_updated_date = SYSDATE,
                   error_message =
                      (SELECT a.error_message
                         FROM apps.mtl_interface_errors a,
                              apps.mtl_item_categories_interface b
                        WHERE b.transaction_id = a.transaction_id
                          AND b.inventory_item_id = stg.item_id
                          AND b.process_flag != 7
                          AND stg.stg_request_id = gn_conc_request_id
                          AND ROWNUM = 1)
             WHERE stg_request_id = gn_conc_request_id
               AND stg.status_flag <> 'E'
               AND EXISTS (
                      SELECT 'x'
                        FROM apps.mtl_item_categories_interface msi
                       WHERE 1 = 1
                         --AND stg.organizationid = msi.organization_id
                         AND stg.item_id = msi.inventory_item_id
                         AND msi.process_flag = 3);

            COMMIT;
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               msg
                  (SUBSTR
                      (   'There are no master Items to be processed in apps.mtl_item_categories_interface interface table'
                       || SQLERRM,
                       1,
                       1999
                      )
                  );
            WHEN OTHERS
            THEN
               msg
                  (SUBSTR
                      (   'Error ocuured while submitting import program for apps.mtl_item_categories_interface items '
                       || SQLERRM,
                       1,
                       1999
                      )
                  );
         END;                                             --W.r.t Version 1.26

--*********************************************
-- CREATE CROSS REFERENCE
--********************************************
         BEGIN
            msg (   'Before Cross reference  :: '
                 || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                );
            gv_retcode := NULL;
            gv_reterror := NULL;
            lv_error_mesg := NULL;
            create_mtl_cross_reference (gv_retcode, gv_reterror);

            IF gv_retcode IS NOT NULL OR gv_reterror IS NOT NULL
            THEN
               fnd_file.put_line
                  (fnd_file.LOG,
                      'Error Ocurred In create_mtl_cross_reference Procedure '
                   || gv_reterror
                  );
            END IF;
         EXCEPTION
            WHEN OTHERS
            THEN
               fnd_file.put_line
                  (fnd_file.LOG,
                      'Error Ocurred In create_mtl_cross_reference Procedure '
                   || SQLERRM
                  );
         END;

         IF UPPER (NVL (pv_reprocess, 'N')) IN ('Y', 'YES')
         THEN
            BEGIN                                  --Start W.r.t Version 1.12
               UPDATE xxdo.xxdo_plm_ora_errors err
                  SET attribute1 = 'P',
                      verrmsg = NULL                      --W.r.t Version 1.25
                WHERE request_id <> gn_conc_request_id
                  AND (style, NVL (color, 'ALL')) IN (
                                         SELECT style, NVL (colorway, 'ALL')
                                           FROM xxdo.xxdo_plm_staging
                                          WHERE request_id =
                                                            gn_conc_request_id)
                  AND NVL (attribute1, 'N') <> 'P';
            EXCEPTION
               WHEN OTHERS
               THEN
                  fnd_file.put_line
                     (fnd_file.LOG,
                      SUBSTR
                         (   'Error ocuured while updating xxdo.xxdo_plm_ora_errors  '
                          || SQLERRM,
                          1,
                          1999
                         )
                     );
            END;
         END IF;

         ln_iface_err_count := 0;

         BEGIN
            UPDATE xxdo.xxdo_plm_itemast_stg stg1
               SET error_message =
                      (SELECT    ' Tran Id '
                              || msi1.transaction_id
                              || ' '
                              || mie1.error_message
                         FROM mtl_interface_errors mie1,
                              mtl_system_items_interface msi1
                        WHERE mie1.transaction_id = msi1.transaction_id
                          AND inventory_item_id =
                                         NVL (stg1.item_id, inventory_item_id)
                          --W.r.t Version 1.25
                          AND msi1.segment1 = stg1.item_number
                          --W.r.t Version 1.25
                          AND ROWNUM = 1)
             WHERE 1 = 1
               AND stg1.stg_request_id = gn_conc_request_id
               AND EXISTS (
                      SELECT 1
                        FROM mtl_system_items_interface msi,
                             mtl_interface_errors mie
                       WHERE inventory_item_id =
                                         NVL (stg1.item_id, inventory_item_id)
                         --W.r.t Version 1.25
                         AND msi.segment1 = stg1.item_number
                         --W.r.t Version 1.25
                         AND mie.transaction_id = msi.transaction_id);

            ln_iface_err_count := SQL%ROWCOUNT;
         EXCEPTION
            WHEN OTHERS
            THEN
               fnd_file.put_line
                  (fnd_file.LOG,
                   SUBSTR
                      (   'Error ocuured while updating xxdo.xxdo_plm_itemast_stg from interface errors '
                       || SQLERRM,
                       1,
                       1999
                      )
                  );
         END;

         BEGIN
            UPDATE xxdo.xxdo_plm_staging stg
               SET oracle_status = 'E',
                   date_updated = SYSDATE,
                   oracle_error_message =
                      SUBSTR (   TRIM (SUBSTR (oracle_error_message, 1, 1000))
                              || ', Refer Error Report for details.',
                              1,
                              1500
                             )
             WHERE request_id = gn_conc_request_id
               AND oracle_status = 'N'
               AND EXISTS (
                      SELECT 1
                        FROM xxdo.xxdo_plm_ora_errors err
                       WHERE err.style = stg.style
                         AND NVL (err.color, 'ALL') =
                                                     NVL (stg.colorway, 'ALL')
                         AND err.request_id = gn_conc_request_id);
         EXCEPTION
            WHEN OTHERS
            THEN
               fnd_file.put_line
                  (fnd_file.LOG,
                   SUBSTR
                      (   'Error ocuured while updating xxdo.xxdo_plm_staging oracle_status with E '
                       || SQLERRM,
                       1,
                       1999
                      )
                  );
         END;                                        ---End W.r.t Version 1.12

         BEGIN
            UPDATE xxdo.xxdo_plm_staging
               SET oracle_status = 'P',
                   date_updated = SYSDATE,
                   oracle_error_message = NULL            --W.r.t Version 1.25
             WHERE request_id = gn_conc_request_id AND oracle_status = 'N';
         EXCEPTION
            WHEN OTHERS
            THEN
               fnd_file.put_line
                  (fnd_file.LOG,
                   SUBSTR
                      (   'Error ocuured while updating xxdo.xxdo_plm_staging oracle_status with P '
                       || SQLERRM,
                       1,
                       1999
                      )
                  );
         END;

         IF ln_iface_err_count > 0
         THEN
            BEGIN
               UPDATE xxdo.xxdo_plm_staging stg
                  SET oracle_status = 'E',
                      date_updated = SYSDATE,
                      oracle_error_message =
                         SUBSTR
                            (   TRIM (SUBSTR (oracle_error_message, 1, 1000))
                             || ' , Error Occurred. Please check the Error report or interface table for more details. ',
                             1,
                             1500
                            )
                WHERE record_id IN (
                         SELECT DISTINCT parent_record_id
                                    FROM xxdo.xxdo_plm_itemast_stg
                                   WHERE error_message IS NOT NULL
                                     AND stg_request_id = gn_conc_request_id);

               --Start W.r.t Version 1.25
               UPDATE xxdo.xxdo_plm_ora_errors xpo
                  SET request_id = gn_conc_request_id,
                      attribute1 = NULL,
                      verrmsg =
                         SUBSTR (   verrmsg
                                 || (SELECT error_message
                                       FROM xxdo.xxdo_plm_staging xps,
                                            xxdo.xxdo_plm_itemast_stg xpi
                                      WHERE record_id = parent_record_id
                                        AND xpi.error_message IS NOT NULL
                                        AND stg_request_id =
                                                            gn_conc_request_id
                                        AND xps.style = xpo.style
                                        AND xps.colorway = xpo.color
                                        AND request_id = gn_conc_request_id
                                        AND ROWNUM = 1),
                                 1,
                                 3000
                                ),
                      creation_date = SYSDATE
                WHERE 1 = 1
                  AND (style, color) IN (
                         SELECT xps.style, xps.colorway
                           FROM xxdo.xxdo_plm_staging xps,
                                xxdo.xxdo_plm_itemast_stg xpi
                          WHERE record_id = parent_record_id
                            AND xpi.error_message IS NOT NULL
                            AND stg_request_id = gn_conc_request_id
                            AND xps.style = xpo.style
                            AND xps.colorway = xpo.color
                            AND request_id = gn_conc_request_id);
            --End W.r.t Version 1.25

            /* --start W.r.t Version 1.24
            UPDATE xxdo.xxdo_plm_staging stg
               SET oracle_status = 'E',
                   oracle_error_message =
                      SUBSTR (   oracle_error_message
                              || (SELECT SUBSTR (error_message, 1, 500)
                                    FROM xxdo.xxdo_plm_itemast_stg stg1
                                   WHERE stg_request_id =
                                                         gn_conc_request_id
                                     AND stg1.parent_record_id =
                                                              stg.record_id
                                     AND stg1.error_message IS NOT NULL
                                     AND ROWNUM = 1),
                              1,
                              1000
                             ),
                   date_updated = SYSDATE
             WHERE record_id IN (
                      SELECT DISTINCT parent_record_id
                                 FROM xxdo.xxdo_plm_itemast_stg
                                WHERE error_message IS NOT NULL
                                  AND stg_request_id = gn_conc_request_id);
            */
            --End W.r.t Version 1.24
            EXCEPTION
               WHEN OTHERS
               THEN
                  fnd_file.put_line
                     (fnd_file.LOG,
                      SUBSTR
                         (   'Error ocuured while updating table xxdo_plm_staging and xxdo_plm_ora_errors with interface error '
                          || SQLERRM,
                          1,
                          1999
                         )
                     );
            END;
         END IF;

         COMMIT;

         BEGIN
            SELECT   SUM (COUNT ((CASE
                                     WHEN oracle_status = 'N'
                                        THEN '0'
                                  END))) AS ncount,
                     SUM (COUNT ((CASE
                                     WHEN oracle_status = 'D'
                                        THEN '0'
                                  END))) AS dcount,
                     SUM (COUNT ((CASE
                                     WHEN oracle_status = 'E'
                                        THEN '0'
                                  END))) AS ecount,
                     SUM (COUNT ((CASE
                                     WHEN oracle_status = 'P'
                                        THEN '0'
                                  END))) AS pcount,
                     SUM (COUNT ((CASE
                                     WHEN oracle_status = 'F'
                                        THEN '0'
                                  END))) AS fcount
                INTO ln_ncount,
                     ln_dcount,
                     ln_ecount,
                     ln_pcount,
                     ln_fcount
                FROM xxdo.xxdo_plm_staging
               WHERE request_id = gn_conc_request_id
            GROUP BY oracle_status;
         EXCEPTION
            WHEN OTHERS
            THEN
               fnd_file.put_line
                  (fnd_file.LOG,
                   SUBSTR
                      (   'Error ocuured while fetching the count for processed records'
                       || SQLERRM,
                       1,
                       1999
                      )
                  );
         END;

         COMMIT;
         fnd_file.put_line
            (fnd_file.LOG,
             '**********************************************************************************************************'
            );
         fnd_file.put_line (fnd_file.LOG,
                            'Total Processed Records: ' || ln_pcount
                           );
         fnd_file.put_line (fnd_file.LOG,
                            'Total UnProcessed Records: ' || ln_ncount
                           );
         fnd_file.put_line (fnd_file.LOG,
                            'Total Duplicate Records : ' || ln_dcount
                           );
         fnd_file.put_line (fnd_file.LOG,
                            'Total Fail Records : ' || ln_fcount);
         fnd_file.put_line (fnd_file.LOG,
                            'Total Errored Records: ' || ln_ecount
                           );
         fnd_file.put_line (fnd_file.LOG,
                               'Total Interface Errored Records: '
                            || ln_iface_err_count
                           );

         --W.r.t Version 1.12 (Error Report )
         BEGIN
            send_error_report (pn_request_id      => gn_conc_request_id,
                               pv_reterror        => gv_reterror,
                               pv_retcode         => gv_retcode
                              );
         EXCEPTION
            WHEN OTHERS
            THEN
               fnd_file.put_line
                   (fnd_file.LOG,
                    SUBSTR (   'Error ocuured executing send_error_report  '
                            || SQLERRM,
                            1,
                            1999
                           )
                   );
         END;
      ELSE
         fnd_file.put_line (fnd_file.LOG,
                            'No Records In PLM Staging Table To Be Processed'
                           );
      END IF;

      fnd_file.put_line (fnd_file.LOG,
                            'End of Main :: '
                         || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                        );
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG,
                               'Exception Occurred In Control Proc :: '
                            || gv_reterror
                            || ' /'
                            || gv_retcode
                            || ' /'
                            || SQLERRM
                           );
   END control_proc;
END xxdoinv_plm_item_gen_pkg;
/
