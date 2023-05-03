--
-- XXD_ONT_GENESIS_MAIN_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:40 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_GENESIS_MAIN_PKG"
AS
    -- ####################################################################################################################
    -- Package      : xxd_ont_genesis_main_pkg
    -- Design       : This package will be used to fetch values required for LOV
    --                in the genesis tool. This package will also  search
    --                for order details based on user entered data.
    --
    -- Notes        :
    -- Modification :
    -- ----------
    -- Date            Name                Ver    Description
    -- ----------      --------------      -----  ------------------
    -- 28-Jun-2021    Infosys              1.0    Initial Version
    -- 23-Aug-2021    Jayarajan A K        1.1    Requirement Changes
    -- 25-Aug-2021    Infosys           1.2    New columns addition to capture updates done at UI
    -- 26-Aug-2021    Infosys           1.3    Request Date issue fix
    -- 27-Aug-2021    Infosys           1.4    Ordered Date issue fix
    -- 30-Aug-2021    Infosys           1.5    Order total format fix
    -- 09-Sep-2021    Infosys           1.6    variable usage fix
    -- 22-Sep-2021    Manju Gopakumar      2.0    Modified to include cancel date also as input to search and ATP fetch bug
    -- 28-Oct-2021    Infosys              2.1    Modified to include fetch_cancel_reasons procedure and accept cancel reasons and
    --           cancel comments as input
    --14-Feb-2022     Infosys              3.0 HOKA changes
    --08-Mar-2022     Infosys              3.1 HOKA changes -bug fix
    --29-Jun-2022  Infosys     3.2    Code fix to restrict order lines that are pick-released or shipped
    --02-Aug-2022  Infosys     3.3    Code fix to allow orders to be picked till 365 days if search criteria is
    --                                            order number or po number or B2B order number
    --29-Aug-2022     Infosys              3.4 Code change to insert line price and unit selling price to table
    --14-Sep-2022     Infosys              3.5 Code change to convert char to number for line price and unit selling price
    -- #########################################################################################################################

    PROCEDURE fetch_batch_id (p_out_batch_id OUT NUMBER)
    IS
    BEGIN
        SELECT xxdo.xxd_genesis_batch_id_s.NEXTVAL
          INTO p_out_batch_id
          FROM DUAL;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_batch_id   := 9999999999;
    END fetch_batch_id;

    --Start changes v3.0
    --Start changes v1.1
    --PROCEDURE fetch_req_dt_threshold(p_out_threshold OUT NUMBER)
    PROCEDURE fetch_req_dt_threshold (p_in_brand IN VARCHAR2, p_in_ou_id IN NUMBER, p_out_threshold OUT NUMBER)
    --End changes v3.0
    IS
        lv_flex_value   VARCHAR2 (100);
    --Start changes v3.0
    BEGIN
        BEGIN
            SELECT ffv_main.flex_value
              INTO lv_flex_value
              FROM fnd_flex_value_sets ffvs_main, fnd_flex_values ffv_main, fnd_flex_values_tl ffvt_main
             WHERE     ffvs_main.flex_value_set_id =
                       ffv_main.flex_value_set_id
                   AND ffv_main.flex_value_id = ffvt_main.flex_value_id
                   AND ffvt_main.language = USERENV ('LANG')
                   AND UPPER (ffvs_main.flex_value_set_name) =
                       'XXD_ONT_GENESIS_BRAND_OU_VS'
                   AND attribute1 = p_in_brand
                   AND INSTR (attribute2, TO_CHAR (p_in_ou_id)) = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_flex_value   := NULL;
        END;

        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'in fetch_req_dt_threshold lv_flex_value: ' || lv_flex_value,
            'xxd_ont_genesis_main_pkg.fetch_req_dt_threshold');

        BEGIN
            SELECT TO_NUMBER (ffv_sub.attribute5)
              INTO p_out_threshold
              FROM fnd_flex_value_sets ffvs_main, fnd_flex_values ffv_main, fnd_flex_values_tl ffvt_main,
                   fnd_flex_value_sets ffvs_sub, fnd_flex_values ffv_sub, fnd_flex_values_tl ffvt_sub
             WHERE     ffvs_main.flex_value_set_id =
                       ffv_main.flex_value_set_id
                   AND ffv_main.flex_value_id = ffvt_main.flex_value_id
                   AND ffvt_main.language = USERENV ('LANG')
                   AND ffv_sub.enabled_flag = 'Y'
                   AND ffvt_sub.description = 'Header'
                   AND UPPER (ffvs_main.flex_value_set_name) =
                       'XXD_ONT_GENESIS_BRAND_OU_VS'
                   AND ffvs_main.flex_value_set_id =
                       ffvs_sub.parent_flex_value_set_id
                   AND ffv_main.flex_value = lv_flex_value
                   AND ffv_main.flex_value = ffv_sub.parent_flex_value_low
                   AND ffvs_sub.flex_value_set_id = ffv_sub.flex_value_set_id
                   AND ffv_sub.flex_value_id = ffvt_sub.flex_value_id
                   AND ffvt_sub.language = USERENV ('LANG')
                   --AND ffv_sub.attribute1 = 'YES'--ver3.1
                   AND ffv_sub.flex_value = 'header_request_date';

            xxd_ont_genesis_proc_ord_pkg.write_to_table (
                   'in fetch_req_dt_threshold p_out_threshold: '
                || p_out_threshold,
                'xxd_ont_genesis_main_pkg.fetch_req_dt_threshold');
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_threshold   := 0;
        END;
    /*BEGIN
     SELECT TO_NUMBER(flv.attribute6)
       INTO p_out_threshold
       FROM fnd_lookup_values flv
      WHERE flv.lookup_type  = 'XXD_ONT_GENESIS_FIELDS_LKP'
           AND flv.meaning = 'header_request_date'
        AND flv.language     = USERENV('LANG')
        AND flv.enabled_flag = 'Y'
        AND SYSDATE BETWEEN NVL (
                          flv.start_date_active,
                       SYSDATE)
                  AND NVL (
                      flv.end_date_active,
                      SYSDATE + 1)
      AND flv.tag        = 'Header';
    EXCEPTION
      WHEN OTHERS
      THEN
     p_out_threshold := 0;*/

    END fetch_req_dt_threshold;

    --End changes v1.1

    --start v3.3
    PROCEDURE fetch_req_dt_thrshd_gen (p_in_brand IN VARCHAR2, p_in_ou_id IN NUMBER, p_out_threshold_gen OUT NUMBER)
    IS
        lv_flex_value   VARCHAR2 (100);
    BEGIN
        BEGIN
            SELECT ffv_main.flex_value
              INTO lv_flex_value
              FROM fnd_flex_value_sets ffvs_main, fnd_flex_values ffv_main, fnd_flex_values_tl ffvt_main
             WHERE     ffvs_main.flex_value_set_id =
                       ffv_main.flex_value_set_id
                   AND ffv_main.flex_value_id = ffvt_main.flex_value_id
                   AND ffvt_main.language = USERENV ('LANG')
                   AND UPPER (ffvs_main.flex_value_set_name) =
                       'XXD_ONT_GENESIS_BRAND_OU_VS'
                   AND attribute1 = p_in_brand
                   AND INSTR (attribute2, TO_CHAR (p_in_ou_id)) = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_flex_value   := NULL;
        END;

        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'in fetch_req_dt_thrshd_gen lv_flex_value: ' || lv_flex_value,
            'xxd_ont_genesis_main_pkg.fetch_req_dt_thrshd_gen');

        BEGIN
            SELECT TO_NUMBER (ffv_sub.attribute6)
              INTO p_out_threshold_gen
              FROM fnd_flex_value_sets ffvs_main, fnd_flex_values ffv_main, fnd_flex_values_tl ffvt_main,
                   fnd_flex_value_sets ffvs_sub, fnd_flex_values ffv_sub, fnd_flex_values_tl ffvt_sub
             WHERE     ffvs_main.flex_value_set_id =
                       ffv_main.flex_value_set_id
                   AND ffv_main.flex_value_id = ffvt_main.flex_value_id
                   AND ffvt_main.language = USERENV ('LANG')
                   AND ffv_sub.enabled_flag = 'Y'
                   AND ffvt_sub.description = 'Header'
                   AND UPPER (ffvs_main.flex_value_set_name) =
                       'XXD_ONT_GENESIS_BRAND_OU_VS'
                   AND ffvs_main.flex_value_set_id =
                       ffvs_sub.parent_flex_value_set_id
                   AND ffv_main.flex_value = lv_flex_value
                   AND ffv_main.flex_value = ffv_sub.parent_flex_value_low
                   AND ffvs_sub.flex_value_set_id = ffv_sub.flex_value_set_id
                   AND ffv_sub.flex_value_id = ffvt_sub.flex_value_id
                   AND ffvt_sub.language = USERENV ('LANG')
                   --AND ffv_sub.attribute1 = 'YES'--ver3.1
                   AND ffv_sub.flex_value = 'header_request_date';

            xxd_ont_genesis_proc_ord_pkg.write_to_table (
                   'in fetch_req_dt_thrshd_gen p_out_threshold_gen: '
                || p_out_threshold_gen,
                'xxd_ont_genesis_main_pkg.fetch_req_dt_thrshd_gen');
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_threshold_gen   := 0;
        END;
    END fetch_req_dt_thrshd_gen;

    --End Ver3.3

    PROCEDURE search_results (p_input_data    IN     CLOB,
                              p_out_results      OUT CLOB,
                              p_out_err_msg      OUT VARCHAR2)
    IS
        lv_org                 VARCHAR2 (10);
        lv_cus_number          VARCHAR2 (100);
        lv_brand               VARCHAR2 (100);
        lv_so_number           VARCHAR2 (240);
        lv_DB2B_onum           VARCHAR2 (240);
        lv_cus_po_num          VARCHAR2 (240);
        lv_style_cond          VARCHAR2 (500);
        lv_brand_cond          VARCHAR2 (500);
        lv_color_cond          VARCHAR2 (500);
        lv_whse_cond           VARCHAR2 (500);
        lv_st_color_cond       VARCHAR2 (500);
        lv_salesrep_cond       VARCHAR2 (500);
        lv_cus_num_cond        VARCHAR2 (500);
        lv_request_dt_cond     VARCHAR2 (500);
        --Start changes v1.4
        --lv_creation_dt_cond  VARCHAR2(500);
        lv_ordered_dt_cond     VARCHAR2 (500);
        --End changes v1.4
        lv_so_num_cond         VARCHAR2 (500);
        lv_po_num_cond         VARCHAR2 (500);
        lv_sku_cond            VARCHAR2 (500);
        lv_b2b_ordnum_cond     VARCHAR2 (500);
        lv_order_search_cur    VARCHAR2 (32000);
        lv_style_color         VARCHAR2 (4000);
        l_cur                  VARCHAR2 (32000);
        ln_ou_cond             VARCHAR2 (500);
        lv_total               VARCHAR2 (100);
        ln_org_id              NUMBER;
        ln_salesrep_id         NUMBER;
        ln_count               NUMBER;
        ln_pre_headerid        NUMBER;
        ln_av_qty              NUMBER;
        ln_ou_id               NUMBER;
        ln_rq_dt_threshold     NUMBER;                                  --v1.1
        ln_rq_dt_thrshld_gen   NUMBER;                                --ver3.3
        --Start changes v1.4
        --lv_creation_date_fm  DATE;
        --lv_creation_date_to  DATE;
        lv_ordered_date_fm     DATE;
        lv_ordered_date_to     DATE;
        --End changes v1.4
        lv_req_date_from       DATE;
        lv_req_date_to         DATE;
        --Start changes v2.0
        lv_cancel_date_from    DATE;
        lv_cancel_date_to      DATE;
        lv_cancel_dt_cond      VARCHAR2 (500);
        --End changes v2.0
        lv_query_exception     EXCEPTION;
        lv_nodata_exception    EXCEPTION;
        lv_no_search_exp       EXCEPTION;
        l_cursor               SYS_REFCURSOR;
        --start ver3.0
        lv_flex_value          VARCHAR2 (100);
        lv_string              VARCHAR2 (500);
        lv_value               VARCHAR2 (50);
        ln_exist               NUMBER;
        ln_counts              NUMBER;

        --end ver 3.0

        TYPE so_line_rec_type
            IS RECORD
        (
            order_number               oe_order_headers_all.order_number%TYPE,
            header_id                  oe_order_headers_all.header_id%TYPE,
            customer_name              VARCHAR2 (250),
            customer_number            VARCHAR2 (50),
            B2B_order_number           oe_order_headers_all.orig_sys_document_ref%TYPE,
            customer_po_number         oe_order_headers_all.cust_po_number%TYPE,
            order_status               oe_order_headers_all.flow_status_code%TYPE,
            warehouse                  mtl_parameters.organization_code%TYPE,
            ship_method                VARCHAR2 (500),
            ordered_date               oe_order_headers_all.ordered_date%TYPE,
            ord_creation_date          oe_order_headers_all.creation_date%TYPE,
            header_request_date        oe_order_headers_all.request_date%TYPE,
            header_cancel_date         DATE,
            total_lines                NUMBER,
            total_lines_pre_picked     NUMBER,
            total_price                NUMBER,
            currency_code              VARCHAR2 (50),
            total_units                NUMBER,
            total_units_pre_picked     NUMBER,
            salesrep_hold              NUMBER,
            line_id                    oe_order_lines_all.line_id%TYPE,
            inventory_item_id          oe_order_lines_all.inventory_item_id%TYPE,
            line_number                oe_order_lines_all.Line_Number%TYPE,
            ordered_item               oe_order_lines_all.Ordered_Item%TYPE,
            item_desc                  mtl_system_items_b.description%TYPE,
            line_status                oe_order_lines_all.flow_status_code%TYPE,
            quantity                   oe_order_lines_all.ordered_quantity%TYPE,
            line_request_date          oe_order_lines_all.request_date%TYPE,
            latest_accepatable_date    oe_order_lines_all.latest_acceptable_date%TYPE,
            line_cancel_date           DATE,
            schedule_ship_date         oe_order_lines_all.schedule_ship_date%TYPE,
            available_quantity         NUMBER--start v2.0
                                             ,
            sort_order                 NUMBER--End v2.0
                                             --start v2.1
                                             ,
            cancel_flag                NUMBER,
            line_price                 NUMBER,
            unit_selling_price         NUMBER,
            multi_salesrep             NUMBER
        --End v2.1
        );

        TYPE so_line_type IS TABLE OF so_line_rec_type
            INDEX BY BINARY_INTEGER;

        so_line_rec            so_line_type;

        TYPE so_line_typ IS REF CURSOR;

        so_line_cur            so_line_typ;

        CURSOR ou_list_cur (p_in_brand VARCHAR2)
        IS
            SELECT attribute2, ffv_main.flex_value
              FROM fnd_flex_value_sets ffvs_main, fnd_flex_values ffv_main, fnd_flex_values_tl ffvt_main
             WHERE     ffvs_main.flex_value_set_id =
                       ffv_main.flex_value_set_id
                   AND ffv_main.flex_value_id = ffvt_main.flex_value_id
                   AND ffvt_main.language = USERENV ('LANG')
                   AND UPPER (ffvs_main.flex_value_set_name) =
                       'XXD_ONT_GENESIS_BRAND_OU_VS'
                   AND attribute1 = p_in_brand;

        CURSOR edit_hdr_fields_cur (p_in_flex_value VARCHAR2)
        IS
            SELECT ffv_sub.flex_value sub_flex_value, DECODE (ffv_sub.attribute1,  'YES', 'TRUE',  'NO', 'FALSE') editable_fields, DECODE (ffv_sub.attribute2,  'YES', 'TRUE',  'NO', 'FALSE') approval_reqd,
                   DECODE (ffv_sub.attribute3,  'YES', 'TRUE',  'NO', 'FALSE') increase_allowed, DECODE (ffv_sub.attribute4,  'YES', 'TRUE',  'NO', 'FALSE') decrease_allowed
              FROM fnd_flex_value_sets ffvs_main, fnd_flex_values ffv_main, fnd_flex_values_tl ffvt_main,
                   fnd_flex_value_sets ffvs_sub, fnd_flex_values ffv_sub, fnd_flex_values_tl ffvt_sub
             WHERE     ffvs_main.flex_value_set_id =
                       ffv_main.flex_value_set_id
                   AND ffv_main.flex_value_id = ffvt_main.flex_value_id
                   AND ffvt_main.language = USERENV ('LANG')
                   AND ffv_sub.enabled_flag = 'Y'
                   AND ffvt_sub.description = 'Header'
                   AND UPPER (ffvs_main.flex_value_set_name) =
                       'XXD_ONT_GENESIS_BRAND_OU_VS'
                   AND ffvs_main.flex_value_set_id =
                       ffvs_sub.parent_flex_value_set_id
                   AND ffv_main.flex_value = p_in_flex_value
                   AND ffv_main.flex_value = ffv_sub.parent_flex_value_low
                   AND ffvs_sub.flex_value_set_id = ffv_sub.flex_value_set_id
                   AND ffv_sub.flex_value_id = ffvt_sub.flex_value_id
                   AND ffvt_sub.language = USERENV ('LANG')
                   AND ffv_sub.attribute1 = 'YES';

        CURSOR edit_line_fields_cur (p_in_flex_value VARCHAR2)
        IS
            SELECT ffv_sub.flex_value sub_flex_value, DECODE (ffv_sub.attribute1,  'YES', 'TRUE',  'NO', 'FALSE') editable_fields, DECODE (ffv_sub.attribute2,  'YES', 'TRUE',  'NO', 'FALSE') approval_reqd,
                   DECODE (ffv_sub.attribute3,  'YES', 'TRUE',  'NO', 'FALSE') increase_allowed, DECODE (ffv_sub.attribute4,  'YES', 'TRUE',  'NO', 'FALSE') decrease_allowed
              FROM fnd_flex_value_sets ffvs_main, fnd_flex_values ffv_main, fnd_flex_values_tl ffvt_main,
                   fnd_flex_value_sets ffvs_sub, fnd_flex_values ffv_sub, fnd_flex_values_tl ffvt_sub
             WHERE     ffvs_main.flex_value_set_id =
                       ffv_main.flex_value_set_id
                   AND ffv_main.flex_value_id = ffvt_main.flex_value_id
                   AND ffvt_main.language = USERENV ('LANG')
                   AND ffv_sub.enabled_flag = 'Y'
                   AND ffvt_sub.description = 'Line'
                   AND UPPER (ffvs_main.flex_value_set_name) =
                       'XXD_ONT_GENESIS_BRAND_OU_VS'
                   AND ffvs_main.flex_value_set_id =
                       ffvs_sub.parent_flex_value_set_id
                   AND ffv_main.flex_value = p_in_flex_value
                   AND ffv_main.flex_value = ffv_sub.parent_flex_value_low
                   AND ffvs_sub.flex_value_set_id = ffv_sub.flex_value_set_id
                   AND ffv_sub.flex_value_id = ffvt_sub.flex_value_id
                   AND ffvt_sub.language = USERENV ('LANG')
                   AND ffv_sub.attribute1 = 'YES';

        CURSOR edit_features_cur (p_in_flex_value VARCHAR2)
        IS
            SELECT ffv_sub.flex_value sub_flex_value, DECODE (ffv_sub.attribute1,  'YES', 'TRUE',  'NO', 'FALSE') allowed
              FROM fnd_flex_value_sets ffvs_main, fnd_flex_values ffv_main, fnd_flex_values_tl ffvt_main,
                   fnd_flex_value_sets ffvs_sub, fnd_flex_values ffv_sub, fnd_flex_values_tl ffvt_sub
             WHERE     ffvs_main.flex_value_set_id =
                       ffv_main.flex_value_set_id
                   AND ffv_main.flex_value_id = ffvt_main.flex_value_id
                   AND ffvt_main.language = USERENV ('LANG')
                   AND ffv_sub.enabled_flag = 'Y'
                   AND ffvt_sub.description = 'Feature'
                   AND UPPER (ffvs_main.flex_value_set_name) =
                       'XXD_ONT_GENESIS_BRAND_OU_VS'
                   AND ffvs_main.flex_value_set_id =
                       ffvs_sub.parent_flex_value_set_id
                   AND ffv_main.flex_value = p_in_flex_value
                   AND ffv_main.flex_value = ffv_sub.parent_flex_value_low
                   AND ffvs_sub.flex_value_set_id = ffv_sub.flex_value_set_id
                   AND ffv_sub.flex_value_id = ffvt_sub.flex_value_id
                   AND ffvt_sub.language = USERENV ('LANG');

        CURSOR other_holds_cur (p_in_header_id NUMBER)
        IS
            SELECT DISTINCT hdef.name                                 --ver3.0
              FROM apps.oe_order_holds_all hld, apps.oe_hold_sources_all hsrc, apps.oe_hold_definitions hdef
             WHERE     hld.hold_source_id = hsrc.hold_source_id
                   AND hsrc.hold_id = hdef.hold_id
                   AND hld.header_id = p_in_header_id
                   --Start changes v2.0
                   --and hsrc.hold_id     <> 1002
                   AND hsrc.hold_id <> 1005
                   --End changes v2.0
                   AND hld.released_flag = 'N'
                   AND hsrc.released_flag = 'N'
                   AND hsrc.hold_release_id IS NULL;
    BEGIN
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
               'in search_results: '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'),
            'xxd_ont_genesis_main_pkg.search_results');

        APEX_JSON.parse (p_input_data);
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'in search_results parsing data: ',
            'xxd_ont_genesis_main_pkg.search_results');

        lv_org                := APEX_JSON.get_varchar2 (p_path => 'warehouse');
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'in search_results parsing data lv_org: ' || lv_org,
            'xxd_ont_genesis_main_pkg.search_results');
        ln_salesrep_id        := APEX_JSON.get_number (p_path => 'salesrep_id');
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
               'in search_results parsing data ln_salesrep_id: '
            || ln_salesrep_id,
            'xxd_ont_genesis_main_pkg.search_results');
        lv_cus_number         :=
            APEX_JSON.get_varchar2 (p_path => 'customer_number');
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'in search_results parsing data lv_cus_number: ' || lv_cus_number,
            'xxd_ont_genesis_main_pkg.search_results');
        lv_brand              := APEX_JSON.get_varchar2 (p_path => 'brand');
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'in search_results parsing data lv_brand: ' || lv_brand,
            'xxd_ont_genesis_main_pkg.search_results');
        lv_so_number          := APEX_JSON.get_varchar2 (p_path => 'order_number');
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'in search_results parsing data lv_so_number: ' || lv_so_number,
            'xxd_ont_genesis_main_pkg.search_results');
        lv_DB2B_onum          :=
            APEX_JSON.get_varchar2 (p_path => 'B2B_order_number');
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'in search_results parsing data lv_DB2B_onum: ' || lv_DB2B_onum,
            'xxd_ont_genesis_main_pkg.search_results');
        lv_cus_po_num         :=
            APEX_JSON.get_varchar2 (p_path => 'customer_po_number');
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'in search_results parsing data lv_cus_po_num: ' || lv_cus_po_num,
            'xxd_ont_genesis_main_pkg.search_results');
        --Start changes v1.4
        --lv_creation_date_fm  := APEX_JSON.get_date(p_path => 'creation_date_from');
        lv_ordered_date_fm    :=
            APEX_JSON.get_date (p_path => 'ordered_date_from');
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
               'in search_results parsing data lv_ordered_date_fm: '
            || lv_ordered_date_fm,
            'xxd_ont_genesis_main_pkg.search_results');
        --lv_creation_date_to  := APEX_JSON.get_date(p_path => 'creation_date_to');
        lv_ordered_date_to    :=
            APEX_JSON.get_date (p_path => 'ordered_date_to');
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
               'in search_results parsing data lv_ordered_date_to: '
            || lv_ordered_date_to,
            'xxd_ont_genesis_main_pkg.search_results');
        --End changes v1.4
        lv_req_date_from      := APEX_JSON.get_date (p_path => 'req_date_from');
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
               'in search_results parsing data lv_req_date_from: '
            || lv_req_date_from,
            'xxd_ont_genesis_main_pkg.search_results');
        lv_req_date_to        := APEX_JSON.get_date (p_path => 'req_date_to');
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
               'in search_results parsing data lv_req_date_to: '
            || lv_req_date_to,
            'xxd_ont_genesis_main_pkg.search_results');
        --Start changes v2.0
        lv_cancel_date_from   :=
            APEX_JSON.get_date (p_path => 'cancel_date_from');
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
               'in search_results parsing data lv_cancel_date_from: '
            || lv_cancel_date_from,
            'xxd_ont_genesis_main_pkg.search_results');
        lv_cancel_date_to     :=
            APEX_JSON.get_date (p_path => 'cancel_date_to');
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
               'in search_results parsing data lv_cancel_date_to: '
            || lv_cancel_date_to,
            'xxd_ont_genesis_main_pkg.search_results');
        --End changes v2.0
        ln_ou_id              := APEX_JSON.get_number (p_path => 'ou_id');
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'in search_results parsing data ln_ou_id: ' || ln_ou_id,
            'xxd_ont_genesis_main_pkg.search_results');

        ln_count              := APEX_JSON.get_count (p_path => 'genesis');
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'in search_results parsing data ln_count: ' || ln_count,
            'xxd_ont_genesis_main_pkg.search_results');

        IF ln_count IS NULL
        THEN
            xxd_ont_genesis_proc_ord_pkg.write_to_table (
                'ln_count is null ',
                'xxd_ont_genesis_main_pkg.search_results');
            RAISE lv_no_search_exp;
        END IF;

        FOR i IN 1 .. ln_count
        LOOP
            IF i = 1
            THEN
                lv_style_color   :=
                       ''''
                    || APEX_JSON.get_varchar2 (
                           p_path   => 'genesis[%d].style_color',
                           p0       => i)
                    || '''';
            END IF;

            IF i > 1
            THEN
                IF LENGTH (lv_style_color) <= 3982
                THEN
                    lv_style_color   :=
                           lv_style_color
                        || ','''
                        || APEX_JSON.get_varchar2 (
                               p_path   => 'genesis[%d].style_color',
                               p0       => i)
                        || '''';
                END IF;
            END IF;
        END LOOP;

        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'in search_results lv_style_color: ' || lv_style_color,
            'xxd_ont_genesis_main_pkg.search_results');

        IF lv_org IS NOT NULL
        THEN
            BEGIN
                SELECT organization_id
                  INTO ln_org_id
                  FROM mtl_parameters
                 WHERE organization_code = lv_org;
            EXCEPTION
                WHEN OTHERS
                THEN
                    xxd_ont_genesis_proc_ord_pkg.write_to_table (
                           'Unexpected error while fetching organization_id for warehouse '
                        || lv_org,
                        'xxd_ont_genesis_main_pkg.search_results');
            END;
        END IF;

        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'in search_results ln_org_id: ' || ln_org_id,
            'xxd_ont_genesis_main_pkg.search_results');

        --Start changes v3.0
        --Start changes v1.1

        --fetch_req_dt_threshold(ln_rq_dt_threshold);
        fetch_req_dt_threshold (p_in_brand        => lv_brand,
                                p_in_ou_id        => ln_ou_id,
                                p_out_threshold   => ln_rq_dt_threshold);

        fetch_req_dt_thrshd_gen (
            p_in_brand            => lv_brand,
            p_in_ou_id            => ln_ou_id,
            p_out_threshold_gen   => ln_rq_dt_thrshld_gen);           --ver3.3
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'in search_results ln_rq_dt_threshold: ' || ln_rq_dt_threshold,
            'xxd_ont_genesis_main_pkg.search_results');
        --start ver3.3
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
               'in search_results ln_rq_dt_thrshld_gen: '
            || ln_rq_dt_thrshld_gen,
            'xxd_ont_genesis_main_pkg.search_results');
        --end ver3.3
        --End changes v1.1
        --End changes v3.0
        lv_order_search_cur   :=
            ' SELECT DISTINCT ooha.order_number       					       order_number,						
								   ooha.header_id											   header_id,
								   hca.account_name                							   customer_name,
								   hca.account_number                					       customer_number,
								   ooha.orig_sys_document_ref 								   B2B_order_number, 
								   ooha.cust_po_number 									       customer_po_number,
								   ooha.flow_status_code 								       order_status,
								   (SELECT organization_code
                                     FROM mtl_parameters
                                    WHERE organization_id = ooha.ship_from_org_id)             warehouse,
								   (SELECT flv1.meaning
                                      FROM fnd_lookup_values flv1
                                     WHERE 1=1
                                       AND flv1.lookup_type      = ''SHIP_METHOD''
                                       AND flv1.enabled_flag     = ''Y''
                                       AND flv1.LANGUAGE      = USERENV(''LANG'')
                                       AND flv1.lookup_code = ooha.shipping_method_code )      ship_method, 
								    TRUNC(ooha.ordered_date)								   ordered_date, 
								   TRUNC(ooha.creation_date)								   ord_creation_date, 
								   TRUNC(ooha.request_date)									   header_request_date, 
								   TRUNC(TO_DATE(ooha.attribute1,''YYYY/MM/DD HH24:MI:SS'') )   header_cancel_date, 
								   (select count(line_id) 
									  from oe_order_lines_all a 
									 where a.header_id = ooha.header_id) 				       total_lines,
								  --Start changes v1.4
								 /* (select count(line_id)								
									  from oe_order_lines_all a, mtl_reservations     mr 
									 WHERE mr.demand_source_line_id = oola.line_id
									   AND oola.header_id = ooha.header_id)			           total_lines_pre_picked, */
								  (SELECT COUNT (1)
									  FROM mtl_reservations mr, mtl_sales_orders mso
									 WHERE mr.demand_source_header_id = mso.sales_order_id
									   AND mso.segment1 = to_char (ooha.order_number)
									   AND mso.segment2 = flv2.meaning
									   AND mso.segment3 = ''ORDER ENTRY'') 					   total_lines_pre_picked,  	   
								 --End changes v1.4	   
								   (SELECT NVL(SUM(unit_selling_price * ordered_quantity) + SUM(nvl(tax_value, 0)),0) 								
									  FROM oe_order_lines_all a 
									 WHERE a.header_id = ooha.header_id) 					   total_price,
								   (SELECT currency_code 
								      FROM apps.qp_list_headers_b 
									 WHERE list_header_id = ooha.price_list_id
								   )				   										   currency_code,
								   (SELECT NVL(sum(ordered_quantity),0)								
									  FROM oe_order_lines_all a 
									 WHERE a.header_id = ooha.header_id) 					   total_units,
									--Start changes v1.4
									/* (SELECT NVL(sum(ordered_quantity),0) 								
									  FROM oe_order_lines_all a ,mtl_reservations     mr
									 WHERE mr.demand_source_line_id = oola.line_id
									   AND oola.header_id = ooha.header_id)		               total_units_pre_picked, */
									 (SELECT NVL (SUM (mr.reservation_quantity), 0)
									   FROM mtl_reservations mr, mtl_sales_orders mso
									  WHERE mr.demand_source_header_id = mso.sales_order_id
									    AND mso.segment1 = to_char (ooha.order_number)
									    AND mso.segment2 = flv2.meaning
									    AND mso.segment3 = ''ORDER ENTRY'') 				   total_units_pre_picked,
									--End changes v1.4   
									(SELECT DECODE (COUNT(1), 0, 0, 1)
									   FROM oe_order_holds_all hold, 
										    oe_hold_sources_all ohsa
										WHERE hold.header_id = ooha.header_id 
										 and hold.released_flag = ''N'' 
										 and hold.hold_source_id = ohsa.hold_source_id 
										 and ohsa.released_flag = ''N'' 
										 and ohsa.hold_release_id is null 
										 --Start changes v2.0
										 --and ohsa.hold_id = 1002
										 and ohsa.hold_id = 1005
										 --End changes v2.0
										AND ohsa.hold_entity_code = ''O'')                     salesrep_hold,								
									 oola.line_id                                              line_id,
									 oola.inventory_item_id									   inventory_item_id,
									 oola.line_number
									   || ''.''
									   || oola.shipment_number 								   line_lumber,
									 oola.ordered_item       				    			   ordered_item ,
									 msib.description 										   item_desc,
									 oola.flow_status_code   				    			   line_status,
									 oola.ordered_quantity 									   quantity,  
									  TRUNC(oola.request_date)           		        	   line_request_date,
									 TRUNC(oola.latest_acceptable_date) 					   latest_accepatable_date,
									 TRUNC(TO_DATE(oola.attribute1,
									 ''YYYY/MM/DD HH24:MI:SS''))                 			   line_cancel_date,
									 TRUNC(oola.Schedule_Ship_Date) 						   schedule_ship_sate ,  
									   --Start changes v2.0
									  --(SELECT xmaf.available_quantity  
									    (SELECT max(xmaf.available_quantity)  
										 --End changes v2.0
									    FROM xxdo.xxd_master_atp_full_t xmaf
									   WHERE xmaf.inventory_item_id   = oola.inventory_item_id
									     AND xmaf.inv_organization_id = oola.ship_from_org_id 
										 --Start changes v2.0
                                         --AND  xmaf.available_date > oola.request_date
										 --AND  xmaf.available_date  <=(select min(available_date)  
										 AND  (xmaf.available_date >=(select max(available_date)
										 --End changes v2.0                                     
                                         from xxdo.xxd_master_atp_full_t xmaf1 where xmaf1.inventory_item_id   = oola.inventory_item_id
									     AND xmaf1.inv_organization_id = oola.ship_from_org_id
										  --Start changes v2.0
                                        -- AND xmaf1.available_date >  oola.request_date
										 AND xmaf1.available_date <=  oola.request_date
										  --End changes v2.0  
                                         AND xmaf1.application         = ''HUBSOFT'') OR xmaf.available_date >= oola.request_date)
										  --Start changes v2.0
										  AND  xmaf.available_date <=  (select (latest_acceptable_date) 
                                         from oe_order_lines_all oola1 where oola1.line_id   = oola.line_id  
                                         )  
										  --End changes v2.0  
									     AND xmaf.application         = ''HUBSOFT'') available_quantity
										 --start v2.0
										 ,TO_NUMBER (msib.attribute10) 				 sort_order
										 --End v2.0
										 --start v2.1
										  ,CASE
											WHEN EXISTS (SELECT 1 
													   FROM oe_order_lines_all oola1
													  WHERE oola1.header_id = ooha.header_id 
														AND EXISTS( SELECT 1 
																	  FROM mtl_reservations     mr
																	 WHERE mr.demand_source_line_id = oola1.line_id
																	   AND mr.organization_id       = oola1.ship_from_org_id))    THEN 1
											WHEN EXISTS (SELECT 1 
													   FROM oe_order_lines_all oola1
													  WHERE oola1.header_id = ooha.header_id
														AND oola1.actual_shipment_date IS NOT NULL)    THEN 1
											--start v3.2
										    WHEN EXISTS(SELECT 1 
													   FROM wsh_delivery_details wdd
													  WHERE wdd.source_line_id = oola.line_id
														AND wdd.move_order_line_id IS NOT NULL) THEN 1
											--end v3.2			
											ELSE 0
											END AS cancel_flag
										 ,NVL((oola.unit_selling_price * oola.ordered_quantity),0) line_price										  										  	
										 ,NVL(oola.unit_selling_price,0) unit_selling_price
										 ,(SELECT DECODE (COUNT(*), 1, 0, 1) from (SELECT DISTINCT oola1.header_id,oola1.salesrep_id
											 FROM oe_order_lines_all oola1 
											WHERE oola1.header_id  = ooha.header_id
										 GROUP BY oola1.header_id,oola1.salesrep_id)) multi_salesrep
										--End v2.1				   
							  FROM oe_order_headers_all    ooha,  
							       oe_order_lines_all      oola, 
								   hz_cust_accounts        hca,
								   --hz_parties 			   hp,
								   mtl_system_items_b 	   msib,
								  mtl_categories_b 	   mc,
								   mtl_item_categories 	   mic,
								   --Start changes v1.2	
							       --fnd_lookup_values flv,
								   --End changes v1.2	
								   fnd_lookup_values flv2								   
							 WHERE ooha.header_id          = oola.header_id 
							   AND oola.ordered_quantity   > 0
							   AND oola.open_flag          = ''Y''
							   AND oola.booked_flag 	   = ''Y''
							   AND oola.line_category_code = ''ORDER''   
							   AND hca.cust_account_id     = ooha.sold_to_org_id
							   AND hca.attribute18 IS NULL
							   AND msib.inventory_item_id  = oola.inventory_item_id
							   AND msib.organization_id    = oola.ship_from_org_id
							   AND mc.disable_date         IS NULL 
							   AND mic.category_id         = mc.category_id
							   AND mic.inventory_item_id   = msib.inventory_item_id
							   AND mic.organization_id     = msib.organization_id
							   --Start changes v1.2
							   /*AND flv.lookup_type          = ''XXD_ONT_GENESIS_ORD_SRC_LKP''  
							   AND flv.language             = USERENV(''LANG'')
							   AND flv.enabled_flag         = ''Y'' 
							   AND ooha.order_source_id     = TO_NUMBER(flv.description)
							   AND SYSDATE BETWEEN NVL ( flv.start_date_active,
														  SYSDATE)
											   AND NVL ( flv.end_date_active,
														  SYSDATE + 1)*/
							   AND EXISTS (SELECT 1 FROM fnd_lookup_values flv
											WHERE flv.lookup_type          = ''XXD_ONT_GENESIS_ORD_SRC_LKP''  
											  AND flv.language             = USERENV(''LANG'')
											  AND flv.enabled_flag         = ''Y'' 
											  AND ooha.order_source_id     = TO_NUMBER(flv.description)
											  AND SYSDATE BETWEEN NVL ( flv.start_date_active,
														  SYSDATE)
											                  AND NVL ( flv.end_date_active,
														  SYSDATE + 1)	) 	
								--End changes v1.2						  
							   AND flv2.lookup_type          = ''XXD_ONT_GENESIS_ORD_TYPE_LKP''  
							   AND flv2.language             = USERENV(''LANG'')
							   AND flv2.enabled_flag         = ''Y'' 
							   AND ooha.order_type_id        = TO_NUMBER(flv2.description)
							   AND SYSDATE BETWEEN NVL ( flv2.start_date_active,
														  SYSDATE)
												AND NVL ( flv2.end_date_active,
														  SYSDATE + 1)
								--start v3.2
							   AND NOT EXISTS(SELECT 1 
										   FROM wsh_delivery_details wdd
										  WHERE wdd.source_line_id = oola.line_id
											AND wdd.move_order_line_id IS NOT NULL)
								--end v3.2						  
							   AND NOT EXISTS( SELECT 1 
												  FROM mtl_reservations     mr
												 WHERE mr.demand_source_line_id = oola.line_id)';


        ln_ou_cond            := ' AND oola.org_id = ''' || ln_ou_id || '''';

        IF ln_salesrep_id IS NOT NULL
        THEN
            lv_salesrep_cond   :=
                ' AND oola.salesrep_id = ''' || ln_salesrep_id || '''';
        ELSE
            RAISE lv_query_exception;
        END IF;

        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'in search_results lv_salesrep_cond: ' || lv_salesrep_cond,
            'xxd_ont_genesis_main_pkg.search_results');

        IF lv_brand IS NOT NULL
        THEN
            lv_brand_cond   := ' AND mc.segment1 = ''' || lv_brand || '''';
        ELSE
            lv_brand_cond   := ' AND 1=1';
        END IF;

        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'in search_results lv_brand_cond: ' || lv_brand_cond,
            'xxd_ont_genesis_main_pkg.search_results');

        IF lv_org IS NOT NULL
        THEN
            lv_whse_cond   := ' AND oola.ship_from_org_id = ' || ln_org_id;
        ELSE
            lv_whse_cond   := ' AND 1=1';
        END IF;

        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'in search_results lv_whse_cond: ' || lv_whse_cond,
            'xxd_ont_genesis_main_pkg.search_results');

        IF LENGTH (lv_style_color) > 2 AND lv_style_color IS NOT NULL
        THEN
            lv_st_color_cond   :=
                   ' AND SUBSTR (msib.segment1,1,INSTR(msib.segment1, ''-'',1, 2)-1) IN '
                || '('
                || lv_style_color
                || ')';
        ELSE
            lv_st_color_cond   := ' AND 1=1';
        END IF;

        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'in search_results lv_st_color_cond: ' || lv_st_color_cond,
            'xxd_ont_genesis_main_pkg.search_results');

        IF lv_cus_number IS NOT NULL
        THEN
            lv_cus_num_cond   :=
                ' AND hca.account_number =  ''' || lv_cus_number || '''';
        ELSE
            lv_cus_num_cond   := ' AND 1=1';
        END IF;

        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'in search_results lv_cus_num_cond: ' || lv_cus_num_cond,
            'xxd_ont_genesis_main_pkg.search_results');

        IF (lv_req_date_from IS NOT NULL OR lv_req_date_to IS NOT NULL)
        THEN
            --Start changes v1.2
            /*IF lv_req_date_to IS NOT NULL THEN
       lv_req_date_to:=  TO_DATE(lv_req_date_to,'DD-MON-YYYY') + INTERVAL '1' DAY ;

      END IF;*/
            --End changes v1.2
            --Start changes v1.1
            /*IF lv_req_date_to > SYSDATE + ln_rq_dt_threshold THEN
         lv_req_date_to := SYSDATE + ln_rq_dt_threshold;
      END IF; */
            --v3.3
            --End changes v1.1
            --Start changes v1.3
            lv_request_dt_cond   :=
                   ' AND trunc(ooha.request_date) BETWEEN to_date('''
                || lv_req_date_from
                || ''' ,''DD-MON-YY'') AND to_date('''
                || lv_req_date_to
                || ''',''DD-MON-YY'')';
        --End changes v1.3
        ELSE
            --lv_request_dt_cond := ' AND 1=1';
            --Start changes v1.1
            --Start changes v3.3
            IF    lv_so_number IS NOT NULL
               OR lv_DB2B_onum IS NOT NULL
               OR lv_cus_po_num IS NOT NULL
            THEN
                lv_req_date_to   := SYSDATE + ln_rq_dt_thrshld_gen;
            ELSE
                --End changes v3.3
                lv_req_date_to   := SYSDATE + ln_rq_dt_threshold;
            END IF;                                                     --v3.3

            --Start changes v1.3
            /*lv_request_dt_cond :=
         '  AND ooha.request_date <= '''
          || lv_req_date_to
       || ''''
         ;*/
            lv_request_dt_cond   :=
                   '  AND trunc(ooha.request_date) <= to_date('''
                || lv_req_date_to
                || ''',''DD-MON-YY'')';
        --End changes v1.3
        --End changes v1.1
        END IF;

        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'in search_results lv_request_dt_cond: ' || lv_request_dt_cond,
            'xxd_ont_genesis_main_pkg.search_results');

        --Start changes v1.4
        /*IF (   lv_creation_date_fm IS NOT NULL
         OR lv_creation_date_to IS NOT NULL)
        THEN */
        IF (lv_ordered_date_fm IS NOT NULL OR lv_ordered_date_to IS NOT NULL)
        THEN
            --End changes v1.4
            --Start changes v1.2
            /*IF lv_creation_date_to IS NOT NULL THEN
       lv_creation_date_to:=  TO_DATE(lv_creation_date_to,'DD-MON-YYYY') + INTERVAL '1' DAY ;
      END IF;*/
            --End changes v1.2
            --Start changes v1.3
            /*lv_creation_dt_cond :=
         ' AND ooha.creation_date BETWEEN '''
      || lv_creation_date_fm
      || ''' AND '''
      || lv_creation_date_to
      || ''''
       ;*/
            lv_ordered_dt_cond   :=                                     --v1.4
                   ' AND trunc(ooha.ordered_date) BETWEEN to_date('''
                || lv_ordered_date_fm                                   --v1.4
                || ''' ,''DD-MON-YY'') AND to_date('''
                || lv_ordered_date_to                                   --v1.4
                || ''',''DD-MON-YY'')';
        --End changes v1.3
        ELSE
            lv_ordered_dt_cond   := ' AND 1=1';                         --v1.4
        END IF;

        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'in search_results lv_ordered_dt_cond: ' || lv_ordered_dt_cond,
            'xxd_ont_genesis_main_pkg.search_results');

        --Start changes v2.0
        IF (lv_cancel_date_from IS NOT NULL OR lv_cancel_date_to IS NOT NULL)
        THEN
            lv_cancel_dt_cond   :=
                   ' AND TRUNC(TO_DATE(ooha.attribute1,''YYYY/MM/DD HH24:MI:SS'') ) BETWEEN to_date('''
                || lv_cancel_date_from
                || ''' ,''DD-MON-YY'') AND to_date('''
                || lv_cancel_date_to
                || ''',''DD-MON-YY'')';
        ELSE
            lv_cancel_dt_cond   := ' AND 1=1';
        END IF;

        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'in search_results lv_cancel_dt_cond: ' || lv_cancel_dt_cond,
            'xxd_ont_genesis_main_pkg.search_results');

        --End changes v2.0

        IF lv_so_number IS NOT NULL
        THEN
            lv_so_num_cond   :=
                ' AND ooha.order_number = ''' || lv_so_number || '''';
        ELSE
            lv_so_num_cond   := ' AND 1=1';
        END IF;

        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'in search_results lv_so_num_cond: ' || lv_so_num_cond,
            'xxd_ont_genesis_main_pkg.search_results');

        IF lv_cus_po_num IS NOT NULL
        THEN
            lv_po_num_cond   :=
                ' AND ooha.cust_po_number = ''' || lv_cus_po_num || '''';
        ELSE
            lv_po_num_cond   := ' AND 1=1';
        END IF;

        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'in search_results lv_so_num_cond: ' || lv_so_num_cond,
            'xxd_ont_genesis_main_pkg.search_results');

        IF lv_DB2B_onum IS NOT NULL
        THEN
            lv_b2b_ordnum_cond   :=
                   ' AND ooha.orig_sys_document_ref = '''
                || lv_DB2B_onum
                || '''';
        ELSE
            lv_b2b_ordnum_cond   := ' AND 1=1';
        END IF;

        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'in search_results lv_b2b_ordnum_cond: ' || lv_b2b_ordnum_cond,
            'xxd_ont_genesis_main_pkg.search_results');

        lv_order_search_cur   :=
               lv_order_search_cur
            || lv_salesrep_cond
            || lv_brand_cond
            || lv_whse_cond
            || lv_st_color_cond
            || lv_cus_num_cond
            || lv_request_dt_cond
            || lv_ordered_dt_cond                                       --v1.4
            || lv_cancel_dt_cond                                        --v2.0
            || lv_so_num_cond
            || lv_po_num_cond
            || lv_b2b_ordnum_cond
            || ln_ou_cond
            || ' ORDER BY ooha.header_id, oola.line_id';

        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'before open cursor: ',
            'xxd_ont_genesis_main_pkg.search_results');

        OPEN so_line_cur FOR lv_order_search_cur;

        FETCH so_line_cur BULK COLLECT INTO so_line_rec;

        CLOSE so_line_cur;

        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'after open cursor: ',
            'xxd_ont_genesis_main_pkg.search_results');

        BEGIN
            xxd_ont_genesis_proc_ord_pkg.write_to_table (
                'before write output: ',
                'xxd_ont_genesis_main_pkg.search_results');
            ln_pre_headerid   := -1;
            APEX_JSON.initialize_clob_output;
            APEX_JSON.open_object;                                        -- {
            APEX_JSON.open_array ('order_headers');
            xxd_ont_genesis_proc_ord_pkg.write_to_table (
                'open header array: ',
                'xxd_ont_genesis_main_pkg.search_results');

            BEGIN
                FOR i IN so_line_rec.FIRST .. so_line_rec.LAST
                LOOP
                    xxd_ont_genesis_proc_ord_pkg.write_to_table (
                           'in header array headerid: '
                        || so_line_rec (i).header_id,
                        'xxd_ont_genesis_main_pkg.search_results');

                    IF (ln_pre_headerid != so_line_rec (i).header_id)
                    THEN
                        BEGIN
                            IF (ln_pre_headerid != -1)
                            THEN
                                BEGIN
                                    APEX_JSON.close_array;    -- ] order_lines
                                    APEX_JSON.close_object;   --} order_header
                                END;
                            END IF;

                            --Start changes v1.5
                            lv_total   :=
                                TO_CHAR (
                                    so_line_rec (i).total_price,
                                    fnd_currency.get_format_mask (
                                        so_line_rec (i).currency_code,
                                        30));
                            --End changes v1.5
                            xxd_ont_genesis_proc_ord_pkg.write_to_table (
                                'before open object hdr: ',
                                'xxd_ont_genesis_main_pkg.search_results');
                            APEX_JSON.open_object;
                            APEX_JSON.write ('order_number',
                                             so_line_rec (i).order_number);
                            APEX_JSON.write ('header_id',
                                             so_line_rec (i).header_id);
                            APEX_JSON.write ('customer_name',
                                             so_line_rec (i).customer_name);
                            APEX_JSON.write ('customer_number',
                                             so_line_rec (i).customer_number);
                            APEX_JSON.write (
                                'B2B_order_number',
                                so_line_rec (i).B2B_order_number);
                            APEX_JSON.write (
                                'customer_po_number',
                                so_line_rec (i).customer_po_number);
                            APEX_JSON.write ('order_status',
                                             so_line_rec (i).order_status);
                            APEX_JSON.write ('warehouse',
                                             so_line_rec (i).warehouse);
                            APEX_JSON.write ('ship_method',
                                             so_line_rec (i).ship_method);
                            APEX_JSON.write (
                                'ord_creation_date',
                                so_line_rec (i).ord_creation_date,
                                TRUE);
                            --start v1.4
                            APEX_JSON.write ('ordered_date',
                                             so_line_rec (i).ordered_date,
                                             TRUE);
                            --end v1.4
                            APEX_JSON.write (
                                'header_request_date',
                                so_line_rec (i).header_request_date,
                                TRUE);
                            APEX_JSON.write (
                                'header_cancel_date',
                                so_line_rec (i).header_cancel_date,
                                TRUE);
                            APEX_JSON.write ('total_lines',
                                             so_line_rec (i).total_lines,
                                             TRUE);
                            APEX_JSON.write (
                                'total_lines_pre_picked',
                                so_line_rec (i).total_lines_pre_picked,
                                TRUE);
                            --Start changes v1.5
                            --APEX_JSON.write('total_price', so_line_rec(i).total_price,TRUE);
                            APEX_JSON.write ('total_price', lv_total, TRUE);
                            --End changes v1.5
                            APEX_JSON.write ('currency_code',
                                             so_line_rec (i).currency_code);
                            APEX_JSON.write ('total_units',
                                             so_line_rec (i).total_units,
                                             TRUE);
                            APEX_JSON.write (
                                'total_units_pre_picked',
                                so_line_rec (i).total_units_pre_picked,
                                TRUE);
                            APEX_JSON.write ('salesrep_hold',
                                             so_line_rec (i).salesrep_hold);
                            --start v2.1
                            APEX_JSON.write ('cancel_flag',
                                             so_line_rec (i).cancel_flag,
                                             TRUE);
                            APEX_JSON.write ('multi_salesrep',
                                             so_line_rec (i).multi_salesrep,
                                             TRUE);
                            --End v2.1
                            -- .... all header fields
                            xxd_ont_genesis_proc_ord_pkg.write_to_table (
                                'before open hold info: ',
                                'xxd_ont_genesis_main_pkg.search_results');

                            APEX_JSON.open_array ('other_holds');

                            FOR other_holds_rec
                                IN other_holds_cur (
                                       so_line_rec (i).header_id)
                            LOOP
                                APEX_JSON.write (other_holds_rec.name);
                            END LOOP;

                            APEX_JSON.close_array;
                            APEX_JSON.open_array ('order_lines');
                        END;
                    END IF;

                    IF so_line_rec (i).available_quantity IS NULL
                    THEN
                        so_line_rec (i).available_quantity   := 0;
                    END IF;

                    xxd_ont_genesis_proc_ord_pkg.write_to_table (
                        'before open object line: ',
                        'xxd_ont_genesis_main_pkg.search_results');
                    APEX_JSON.open_object;
                    APEX_JSON.write ('order_number',
                                     so_line_rec (i).order_number);
                    APEX_JSON.write ('line_number',
                                     so_line_rec (i).line_number);
                    APEX_JSON.write ('line_id', so_line_rec (i).line_id);
                    APEX_JSON.write ('ordered_item',
                                     so_line_rec (i).ordered_item,
                                     TRUE);
                    APEX_JSON.write ('item_desc',
                                     so_line_rec (i).item_desc,
                                     TRUE);
                    APEX_JSON.write ('inventory_item_id',
                                     so_line_rec (i).inventory_item_id);
                    APEX_JSON.write ('line_status',
                                     so_line_rec (i).line_status);
                    APEX_JSON.write ('quantity', so_line_rec (i).quantity);
                    APEX_JSON.write ('line_request_date',
                                     so_line_rec (i).line_request_date,
                                     TRUE);
                    APEX_JSON.write ('line_cancel_date',
                                     so_line_rec (i).line_cancel_date,
                                     TRUE);
                    APEX_JSON.write ('latest_accepatable_date',
                                     so_line_rec (i).latest_accepatable_date,
                                     TRUE);
                    APEX_JSON.write ('schedule_ship_date',
                                     so_line_rec (i).schedule_ship_date,
                                     TRUE);
                    APEX_JSON.write ('warehouse', so_line_rec (i).warehouse);
                    APEX_JSON.write ('available_quantity',
                                     so_line_rec (i).available_quantity,
                                     TRUE);
                    --Start changes v2.0
                    APEX_JSON.write ('sort_order',
                                     so_line_rec (i).sort_order,
                                     TRUE);
                    --End changes v2.0
                    --start v3.5
                    --start v2.1
                    /*APEX_JSON.write('line_price',so_line_rec(i).line_price,TRUE);
           APEX_JSON.write('unit_selling_price',so_line_rec(i).unit_selling_price,TRUE);*/
                    APEX_JSON.write (
                        'line_price',
                        TO_CHAR (
                            so_line_rec (i).line_price,
                            fnd_currency.get_format_mask (
                                so_line_rec (i).currency_code,
                                30)),
                        TRUE);
                    APEX_JSON.write (
                        'unit_selling_price',
                        TO_CHAR (
                            so_line_rec (i).unit_selling_price,
                            fnd_currency.get_format_mask (
                                so_line_rec (i).currency_code,
                                30)),
                        TRUE);
                    --End v2.1
                    --End v3.5
                    -- .... all lines fields
                    APEX_JSON.close_object;

                    ln_pre_headerid   := so_line_rec (i).header_id;
                END LOOP;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    RAISE lv_nodata_exception;
                WHEN OTHERS
                THEN
                    RAISE lv_nodata_exception;
            END;

            xxd_ont_genesis_proc_ord_pkg.write_to_table (
                'close: ',
                'xxd_ont_genesis_main_pkg.search_results');
            APEX_JSON.close_array;                            -- ] order_lines
            APEX_JSON.close_object;                           --} order_header
            APEX_JSON.close_array;                          -- ] order_headers

            xxd_ont_genesis_proc_ord_pkg.write_to_table (
                'before open editable_fields: ',
                'xxd_ont_genesis_main_pkg.search_results');
            APEX_JSON.open_object ('editable_fields');  --editable_fields  hdr
            APEX_JSON.open_array ('Header Level');

            --start ver 3.0
            xxd_ont_genesis_proc_ord_pkg.write_to_table (
                'before fetching lv_flex_value:lv_brand: ' || lv_brand,
                'xxd_ont_genesis_main_pkg.search_results');
            xxd_ont_genesis_proc_ord_pkg.write_to_table (
                'before fetching lv_flex_value:ln_ou_id: ' || ln_ou_id,
                'xxd_ont_genesis_main_pkg.search_results');

            /*SELECT ffv_main.flex_value
              INTO lv_flex_value
              FROM fnd_flex_value_sets ffvs_main
                  ,fnd_flex_values ffv_main
                  ,fnd_flex_values_tl ffvt_main
            WHERE ffvs_main.flex_value_set_id = ffv_main.flex_value_set_id
              AND ffv_main.flex_value_id = ffvt_main.flex_value_id
              AND ffvt_main.language = USERENV ('LANG')
              AND UPPER(ffvs_main.flex_value_set_name) = 'XXD_ONT_GENESIS_BRAND_OU_VS'
              AND attribute1 = lv_brand
              AND INSTR(attribute2, to_char(ln_ou_id))= 1;*/
            BEGIN
                SELECT ffv_main.flex_value
                  INTO lv_flex_value
                  FROM fnd_flex_value_sets ffvs_main, fnd_flex_values ffv_main, fnd_flex_values_tl ffvt_main
                 WHERE     ffvs_main.flex_value_set_id =
                           ffv_main.flex_value_set_id
                       AND ffv_main.flex_value_id = ffvt_main.flex_value_id
                       AND ffvt_main.language = USERENV ('LANG')
                       AND UPPER (ffvs_main.flex_value_set_name) =
                           'XXD_ONT_GENESIS_BRAND_OU_VS'
                       AND attribute1 = lv_brand
                       AND attribute2 = TO_CHAR (ln_ou_id);
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lv_flex_value   := 0;
                WHEN OTHERS
                THEN
                    lv_flex_value   := 0;
            END;

            IF lv_flex_value = 0
            THEN
                FOR ou_list_rec IN ou_list_cur (lv_brand)
                LOOP
                    xxd_ont_genesis_proc_ord_pkg.write_to_table (
                        'ou_list_rec.attribute2' || ou_list_rec.attribute2,
                        'xxd_ont_genesis_main_pkg.search_results');
                    ln_exist    := 0;
                    lv_string   := ou_list_rec.attribute2 || ',';

                    LOOP
                        xxd_ont_genesis_proc_ord_pkg.write_to_table (
                            'lv_string' || lv_string,
                            'xxd_ont_genesis_main_pkg.search_results');
                        EXIT WHEN lv_string IS NULL;
                        ln_counts   := INSTR (lv_string, ',');
                        lv_value    :=
                            LTRIM (
                                RTRIM (SUBSTR (lv_string, 1, ln_counts - 1)));
                        xxd_ont_genesis_proc_ord_pkg.write_to_table (
                            'lv_value' || lv_value,
                            'xxd_ont_genesis_main_pkg.search_results');
                        lv_string   := SUBSTR (lv_string, ln_counts + 1);

                        IF lv_value = TO_CHAR (ln_ou_id)
                        THEN
                            ln_exist   := 1;
                            EXIT;
                        END IF;

                        xxd_ont_genesis_proc_ord_pkg.write_to_table (
                            'ln_exist' || ln_exist,
                            'xxd_ont_genesis_main_pkg.search_results');
                    END LOOP;

                    IF ln_exist = 1
                    THEN
                        lv_flex_value   := ou_list_rec.flex_value;
                        EXIT;
                    END IF;
                --lv_email_list.EXTEND;
                --lv_email_list(lv_email_list.COUNT) :=  LTRIM(RTRIM(SUBSTR(lv_string, 1, ln_count - 1)));
                --lv_string := SUBSTR(lv_string, ln_count + 1);

                END LOOP;
            END IF;

            xxd_ont_genesis_proc_ord_pkg.write_to_table (
                'lv_flex_value: ' || lv_flex_value,
                'xxd_ont_genesis_main_pkg.search_results');

            --end ver 3.0
            FOR edit_hdr_fields_rec IN edit_hdr_fields_cur (lv_flex_value) --v3.0
            LOOP
                xxd_ont_genesis_proc_ord_pkg.write_to_table (
                    'in edit_hdr_fields_cur: ' || edit_hdr_fields_rec.sub_flex_value,
                    'xxd_ont_genesis_main_pkg.search_results');
                APEX_JSON.open_object;
                APEX_JSON.write ('field_name',
                                 edit_hdr_fields_rec.sub_flex_value,
                                 TRUE);
                APEX_JSON.write ('approval',
                                 edit_hdr_fields_rec.approval_reqd,
                                 TRUE);
                APEX_JSON.write ('increase_allowed',
                                 edit_hdr_fields_rec.increase_allowed,
                                 TRUE);
                APEX_JSON.write ('decrease_allowed',
                                 edit_hdr_fields_rec.decrease_allowed,
                                 TRUE);
                APEX_JSON.close_object;
            END LOOP;

            xxd_ont_genesis_proc_ord_pkg.write_to_table (
                'before close editable_fields: ',
                'xxd_ont_genesis_main_pkg.search_results');
            APEX_JSON.close_array;           --close array editable_fields hdr
            APEX_JSON.open_array ('Line Level');  --open editable_fields lines

            xxd_ont_genesis_proc_ord_pkg.write_to_table (
                'before open editable_line: ',
                'xxd_ont_genesis_main_pkg.search_results');

            FOR edit_line_fields_rec IN edit_line_fields_cur (lv_flex_value) --v3.0
            LOOP
                APEX_JSON.open_object;                 --editable_fields  line
                APEX_JSON.write ('field_name',
                                 edit_line_fields_rec.sub_flex_value,
                                 TRUE);
                APEX_JSON.write ('approval',
                                 edit_line_fields_rec.approval_reqd,
                                 TRUE);
                APEX_JSON.write ('increase_allowed',
                                 edit_line_fields_rec.increase_allowed,
                                 TRUE);
                APEX_JSON.write ('decrease_allowed',
                                 edit_line_fields_rec.decrease_allowed,
                                 TRUE);
                APEX_JSON.close_object;
            END LOOP;

            --end ver 3.0
            xxd_ont_genesis_proc_ord_pkg.write_to_table (
                'before close editable_line: ',
                'xxd_ont_genesis_main_pkg.search_results');
            APEX_JSON.close_array;                           --editable_fields
            APEX_JSON.close_object;                                        --}
            --start ver 3.0
            xxd_ont_genesis_proc_ord_pkg.write_to_table (
                'optional_features: ',
                'xxd_ont_genesis_main_pkg.search_results');
            APEX_JSON.open_array ('optional_features');

            FOR edit_features_rec IN edit_features_cur (lv_flex_value)
            LOOP
                APEX_JSON.open_object;
                APEX_JSON.write ('feature',
                                 edit_features_rec.sub_flex_value,
                                 TRUE);
                APEX_JSON.write ('allowed', edit_features_rec.allowed);
                APEX_JSON.close_object;
            END LOOP;

            APEX_JSON.close_array;
            APEX_JSON.close_object;                                        --}
        END;

        xxd_ont_genesis_proc_ord_pkg.write_to_table (
               'after p_out_results: '
            || lv_style_color
            || ': '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'),
            'xxd_ont_genesis_main_pkg.search_results');
        p_out_results         := APEX_JSON.get_clob_output;
        APEX_JSON.free_output;
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
               'end search_results: '
            || ': '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'),
            'xxd_ont_genesis_main_pkg.search_results');
    EXCEPTION
        WHEN lv_no_search_exp
        THEN
            p_out_err_msg   := 'No search criteria received';
            xxd_ont_genesis_proc_ord_pkg.write_to_table (
                'No search criteria received',
                'xxd_ont_genesis_main_pkg.search_results');
        WHEN lv_nodata_exception
        THEN
            p_out_err_msg   := 'No data fetched for the search criteria ';
            xxd_ont_genesis_proc_ord_pkg.write_to_table (
                'No data fetched for the search criteria  ',
                'xxd_ont_genesis_main_pkg.search_results');
        WHEN lv_query_exception
        THEN
            p_out_err_msg   := 'salesrep id cannot be null ';
            xxd_ont_genesis_proc_ord_pkg.write_to_table (
                'salesrep id cannot be null ',
                'xxd_ont_genesis_main_pkg.search_results');
        WHEN OTHERS
        THEN
            p_out_err_msg   := 'Unexpected error in search results for user ';
            --xxd_ont_genesis_proc_ord_pkg.write_to_table ('Unexpected error in search results for user ','xxd_ont_genesis_main_pkg.search_results');
            xxd_ont_genesis_proc_ord_pkg.write_to_table (
                SUBSTR ('Unexpected error in search_results: ' || SQLERRM,
                        1,
                        2000),
                'xxd_ont_genesis_main_pkg.search_results');             --v1.1
    END search_results;

    PROCEDURE parse_data (p_in_input_data IN CLOB, p_out_err_msg OUT VARCHAR2, p_out_batch_id OUT NUMBER)
    IS
        l_input_data_tab     GEN_TBL_TYPE;
        ln_count             NUMBER;
        ln_hdr_count         NUMBER;
        ln_salesrep_id       NUMBER;
        ln_user_id           NUMBER;
        ln_batch_id          NUMBER;
        ln_header_id         NUMBER;
        ln_org_id            NUMBER;
        ln_generic_count     NUMBER := 0;
        ld_hdr_req_date      VARCHAR2 (100);
        ld_hdr_cancel_date   VARCHAR2 (100);
        lv_hold              VARCHAR2 (10);
        lv_action            VARCHAR2 (10);
        lv_appr_reqd         VARCHAR2 (10);
        lv_appr_recvd        VARCHAR2 (10);
        lv_org               VARCHAR2 (10);
    BEGIN
        APEX_JSON.parse (p_in_input_data);
        ln_batch_id        := APEX_JSON.get_number (p_path => 'batch_id');
        ln_user_id         := APEX_JSON.get_number (p_path => 'user_id');
        ln_hdr_count       := APEX_JSON.get_count (p_path => 'order_details');
        l_input_data_tab   := GEN_TBL_TYPE ();

        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'ln_batch_id' || ln_batch_id,
            'xxd_ont_genesis_main_pkg.parse_data');
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'ln_user_id' || ln_user_id,
            'xxd_ont_genesis_main_pkg.parse_data');
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'ln_hdr_count' || ln_hdr_count,
            'xxd_ont_genesis_main_pkg.parse_data');

        FOR i IN 1 .. ln_hdr_count
        LOOP
            IF ln_batch_id IS NULL
            THEN
                BEGIN
                    SELECT xxdo.xxd_genesis_batch_id_s.NEXTVAL
                      INTO ln_batch_id
                      FROM DUAL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_batch_id   := 9999999999;
                END;
            END IF;

            ln_count   :=
                APEX_JSON.get_count (
                    p_path   => 'order_details[%d].order_lines',
                    p0       => i);
            xxd_ont_genesis_proc_ord_pkg.write_to_table (
                'ln_count' || ln_count,
                'xxd_ont_genesis_main_pkg.parse_data');

            IF ln_count = 0
            THEN
                xxd_ont_genesis_proc_ord_pkg.write_to_table (
                    'in count 0',
                    'xxd_ont_genesis_main_pkg.parse_data');
                ln_generic_count   := ln_generic_count + 1;

                l_input_data_tab.EXTEND;
                -- l_input_data_tab(i):=  GEN_REC_TYPE (NULL,--v1.6
                l_input_data_tab (ln_generic_count)   :=
                    GEN_REC_TYPE (NULL,                                 --v1.6
                                        NULL, NULL,
                                  NULL, NULL, NULL,
                                  NULL, NULL, NULL,
                                  NULL, NULL, NULL,
                                  NULL, NULL, NULL,
                                  NULL, NULL, NULL,
                                  NULL, NULL, NULL,
                                  NULL, NULL, NULL,
                                  NULL,                                 --v2.1
                                        NULL,                           --v2.1
                                              NULL                      --v2.1
                                                  );

                l_input_data_tab (ln_generic_count).attribute1   :=
                    APEX_JSON.get_number (
                        p_path   => 'order_details[%d].header_id',
                        p0       => i);
                l_input_data_tab (ln_generic_count).attribute5   :=
                    APEX_JSON.get_date (
                        p_path   =>
                            'order_details[%d].new_header_request_date',
                        p0   => i);
                l_input_data_tab (ln_generic_count).attribute6   :=
                    APEX_JSON.get_date (
                        p_path   => 'order_details[%d].new_header_cancel_date',
                        p0       => i);
                l_input_data_tab (ln_generic_count).attribute9   :=
                    APEX_JSON.get_varchar2 (
                        p_path   => 'order_details[%d].new_salesrep_hold',
                        p0       => i);
                l_input_data_tab (ln_generic_count).attribute10   :=
                    APEX_JSON.get_varchar2 (
                        p_path   => 'order_details[%d].hdr_action',
                        p0       => i);
                --Start changes v1.2
                l_input_data_tab (ln_generic_count).attribute12   :=
                    APEX_JSON.get_varchar2 (
                        p_path   => 'order_details[%d].hdr_updates',
                        p0       => i);
                --End changes v1.2
                --Start changes v2.1
                l_input_data_tab (ln_generic_count).attribute11   :=
                    APEX_JSON.get_varchar2 (
                        p_path   => 'order_details[%d].hdr_cancel_reason',
                        p0       => i);
                l_input_data_tab (ln_generic_count).attribute25   :=
                    APEX_JSON.get_varchar2 (
                        p_path   => 'order_details[%d].hdr_cancel_comment',
                        p0       => i);
                l_input_data_tab (ln_generic_count).attribute27   :=
                    APEX_JSON.get_varchar2 (
                        p_path   => 'order_details[%d].apprvl_reqd',
                        p0       => i);
                --End changes v2.1
                xxd_ont_genesis_proc_ord_pkg.write_to_table (
                       'header_id'
                    || l_input_data_tab (ln_generic_count).attribute1,
                    'xxd_ont_genesis_main_pkg.parse_data');
                xxd_ont_genesis_proc_ord_pkg.write_to_table (
                       'new_header_request_date'
                    || l_input_data_tab (ln_generic_count).attribute5,
                    'xxd_ont_genesis_main_pkg.parse_data');
                xxd_ont_genesis_proc_ord_pkg.write_to_table (
                       'new_header_cancel_date'
                    || l_input_data_tab (ln_generic_count).attribute6,
                    'xxd_ont_genesis_main_pkg.parse_data');
                xxd_ont_genesis_proc_ord_pkg.write_to_table (
                       'new_salesrep_hold'
                    || l_input_data_tab (ln_generic_count).attribute9,
                    'xxd_ont_genesis_main_pkg.parse_data');
                xxd_ont_genesis_proc_ord_pkg.write_to_table (
                       'hdr_action'
                    || l_input_data_tab (ln_generic_count).attribute10,
                    'xxd_ont_genesis_main_pkg.parse_data');
                xxd_ont_genesis_proc_ord_pkg.write_to_table (
                       'hdr_updates'
                    || l_input_data_tab (ln_generic_count).attribute12,
                    'xxd_ont_genesis_main_pkg.parse_data');
            END IF;

            FOR j IN 1 .. ln_count
            LOOP
                xxd_ont_genesis_proc_ord_pkg.write_to_table (
                    'in j ln_count',
                    'xxd_ont_genesis_main_pkg.parse_data');
                ln_generic_count   := ln_generic_count + 1;
                l_input_data_tab.EXTEND;
                l_input_data_tab (ln_generic_count)   :=
                    GEN_REC_TYPE (NULL, NULL, NULL,
                                  NULL, NULL, NULL,
                                  NULL, NULL, NULL,
                                  NULL, NULL, NULL,
                                  NULL, NULL, NULL,
                                  NULL, NULL, NULL,
                                  NULL, NULL, NULL,
                                  NULL, NULL, NULL,
                                  NULL,                                 --v2.1
                                        NULL,                           --v2.1
                                              NULL                      --v2.1
                                                  );
                l_input_data_tab (ln_generic_count).attribute1   :=
                    APEX_JSON.get_number (
                        p_path   => 'order_details[%d].header_id',
                        p0       => i);
                l_input_data_tab (ln_generic_count).attribute5   :=
                    APEX_JSON.get_date (
                        p_path   =>
                            'order_details[%d].new_header_request_date',
                        p0   => i);
                l_input_data_tab (ln_generic_count).attribute6   :=
                    APEX_JSON.get_date (
                        p_path   => 'order_details[%d].new_header_cancel_date',
                        p0       => i);
                l_input_data_tab (ln_generic_count).attribute9   :=
                    APEX_JSON.get_varchar2 (
                        p_path   => 'order_details[%d].new_salesrep_hold',
                        p0       => i);
                l_input_data_tab (ln_generic_count).attribute10   :=
                    APEX_JSON.get_varchar2 (
                        p_path   => 'order_details[%d].hdr_action',
                        p0       => i);
                --Start changes v1.2
                l_input_data_tab (ln_generic_count).attribute12   :=
                    APEX_JSON.get_varchar2 (
                        p_path   => 'order_details[%d].hdr_updates',
                        p0       => i);
                --End changes v1.2
                --Start changes v2.1
                l_input_data_tab (ln_generic_count).attribute11   :=
                    APEX_JSON.get_varchar2 (
                        p_path   => 'order_details[%d].hdr_cancel_reason',
                        p0       => i);
                l_input_data_tab (ln_generic_count).attribute25   :=
                    APEX_JSON.get_varchar2 (
                        p_path   => 'order_details[%d].hdr_cancel_comment',
                        p0       => i);
                l_input_data_tab (ln_generic_count).attribute27   :=
                    APEX_JSON.get_varchar2 (
                        p_path   => 'order_details[%d].apprvl_reqd',
                        p0       => i);
                --End changes v2.1
                l_input_data_tab (ln_generic_count).attribute13   :=
                    APEX_JSON.get_number (
                        p_path   =>
                            'order_details[%d].order_lines[%d].line_id',
                        p0   => i,
                        p1   => j);
                l_input_data_tab (ln_generic_count).attribute14   :=
                    APEX_JSON.get_number (
                        p_path   =>
                            'order_details[%d].order_lines[%d].new_quantity',
                        p0   => i,
                        p1   => j);
                l_input_data_tab (ln_generic_count).attribute17   :=
                    APEX_JSON.get_date (
                        p_path   =>
                            'order_details[%d].order_lines[%d].new_line_request_date',
                        p0   => i,
                        p1   => j);
                l_input_data_tab (ln_generic_count).attribute18   :=
                    APEX_JSON.get_date (
                        p_path   =>
                            'order_details[%d].order_lines[%d].new_line_cancel_date',
                        p0   => i,
                        p1   => j);
                --Start changes v2.0
                l_input_data_tab (ln_generic_count).attribute19   :=
                    APEX_JSON.get_date (
                        p_path   =>
                            'order_details[%d].order_lines[%d].new_latest_accepatable_date',
                        p0   => i,
                        p1   => j);
                --End changes v2.0
                l_input_data_tab (ln_generic_count).attribute21   :=
                    APEX_JSON.get_varchar2 (
                        p_path   =>
                            'order_details[%d].order_lines[%d].ordered_item',
                        p0   => i,
                        p1   => j);
                l_input_data_tab (ln_generic_count).attribute22   :=
                    APEX_JSON.get_varchar2 (
                        p_path   =>
                            'order_details[%d].order_lines[%d].line_action',
                        p0   => i,
                        p1   => j);
                --Start changes v1.2
                l_input_data_tab (ln_generic_count).attribute24   :=
                    APEX_JSON.get_varchar2 (
                        p_path   =>
                            'order_details[%d].order_lines[%d].line_updates',
                        p0   => i,
                        p1   => j);
                --End changes v1.2
                --Start changes v2.1
                l_input_data_tab (ln_generic_count).attribute23   :=
                    APEX_JSON.get_varchar2 (
                        p_path   =>
                            'order_details[%d].order_lines[%d].line_reason',
                        p0   => i,
                        p1   => j);
                l_input_data_tab (ln_generic_count).attribute26   :=
                    APEX_JSON.get_varchar2 (
                        p_path   =>
                            'order_details[%d].order_lines[%d].line_comment',
                        p0   => i,
                        p1   => j);
                --End changes v2.1
                --Start changes v3.5
                --Start changes v3.4
                /*l_input_data_tab(ln_generic_count).attribute15 := APEX_JSON.get_number(p_path =>'order_details[%d].order_lines[%d].line_price', p0 => i,p1 => j);
          l_input_data_tab(ln_generic_count).attribute16 := APEX_JSON.get_number(p_path =>'order_details[%d].order_lines[%d].unit_selling_price', p0 => i,p1 => j);*/
                l_input_data_tab (ln_generic_count).attribute15   :=
                    TO_NUMBER (
                        APEX_JSON.get_varchar2 (
                            p_path   =>
                                'order_details[%d].order_lines[%d].line_price',
                            p0   => i,
                            p1   => j),
                        '999,999,999,990.999');
                l_input_data_tab (ln_generic_count).attribute16   :=
                    TO_NUMBER (
                        APEX_JSON.get_varchar2 (
                            p_path   =>
                                'order_details[%d].order_lines[%d].unit_selling_price',
                            p0   => i,
                            p1   => j),
                        '999,999,999,990.999');
                --End changes v3.4
                --End changes v3.5
                xxd_ont_genesis_proc_ord_pkg.write_to_table (
                       'hdr id'
                    || l_input_data_tab (ln_generic_count).attribute1,
                    'xxd_ont_genesis_main_pkg.parse_data');
                xxd_ont_genesis_proc_ord_pkg.write_to_table (
                       'new_header_request_date'
                    || l_input_data_tab (ln_generic_count).attribute5,
                    'xxd_ont_genesis_main_pkg.parse_data');
                xxd_ont_genesis_proc_ord_pkg.write_to_table (
                       'new_header_cancel_date'
                    || l_input_data_tab (ln_generic_count).attribute6,
                    'xxd_ont_genesis_main_pkg.parse_data');
                xxd_ont_genesis_proc_ord_pkg.write_to_table (
                       'new_salesrep_hold'
                    || l_input_data_tab (ln_generic_count).attribute9,
                    'xxd_ont_genesis_main_pkg.parse_data');
                xxd_ont_genesis_proc_ord_pkg.write_to_table (
                       'hdr_action'
                    || l_input_data_tab (ln_generic_count).attribute10,
                    'xxd_ont_genesis_main_pkg.parse_data');
                --Start changes v1.2
                xxd_ont_genesis_proc_ord_pkg.write_to_table (
                       'hdr_updates'
                    || l_input_data_tab (ln_generic_count).attribute12,
                    'xxd_ont_genesis_main_pkg.parse_data');
                --End changes v1.2
                --Start changes v2.1
                xxd_ont_genesis_proc_ord_pkg.write_to_table (
                       'hdr_cancel_reason'
                    || l_input_data_tab (ln_generic_count).attribute11,
                    'xxd_ont_genesis_main_pkg.parse_data');
                xxd_ont_genesis_proc_ord_pkg.write_to_table (
                       'hdr_cancel_comment'
                    || l_input_data_tab (ln_generic_count).attribute25,
                    'xxd_ont_genesis_main_pkg.parse_data');
                xxd_ont_genesis_proc_ord_pkg.write_to_table (
                       'apprvl_reqd'
                    || l_input_data_tab (ln_generic_count).attribute27,
                    'xxd_ont_genesis_main_pkg.parse_data');
                --End changes v2.1
                xxd_ont_genesis_proc_ord_pkg.write_to_table (
                       'line_id'
                    || l_input_data_tab (ln_generic_count).attribute13,
                    'xxd_ont_genesis_main_pkg.parse_data');
                xxd_ont_genesis_proc_ord_pkg.write_to_table (
                       'new_quantity'
                    || l_input_data_tab (ln_generic_count).attribute14,
                    'xxd_ont_genesis_main_pkg.parse_data');
                xxd_ont_genesis_proc_ord_pkg.write_to_table (
                       'new_line_request_date'
                    || l_input_data_tab (ln_generic_count).attribute17,
                    'xxd_ont_genesis_main_pkg.parse_data');
                xxd_ont_genesis_proc_ord_pkg.write_to_table (
                       'new_line_cancel_date'
                    || l_input_data_tab (ln_generic_count).attribute18,
                    'xxd_ont_genesis_main_pkg.parse_data');
                --Start changes v2.0
                xxd_ont_genesis_proc_ord_pkg.write_to_table (
                       'new_latest_accepatable_date'
                    || l_input_data_tab (ln_generic_count).attribute19,
                    'xxd_ont_genesis_main_pkg.parse_data');
                --End changes v2.0
                xxd_ont_genesis_proc_ord_pkg.write_to_table (
                       'ordered_item'
                    || l_input_data_tab (ln_generic_count).attribute21,
                    'xxd_ont_genesis_main_pkg.parse_data');
                xxd_ont_genesis_proc_ord_pkg.write_to_table (
                       'line_action'
                    || l_input_data_tab (ln_generic_count).attribute22,
                    'xxd_ont_genesis_main_pkg.parse_data');
                --Start changes v1.2
                xxd_ont_genesis_proc_ord_pkg.write_to_table (
                       'line_updates'
                    || l_input_data_tab (ln_generic_count).attribute24,
                    'xxd_ont_genesis_main_pkg.parse_data');
                --End changes v1.2
                --Start changes v2.1
                xxd_ont_genesis_proc_ord_pkg.write_to_table (
                       'line_reason'
                    || l_input_data_tab (ln_generic_count).attribute23,
                    'xxd_ont_genesis_main_pkg.parse_data');
                xxd_ont_genesis_proc_ord_pkg.write_to_table (
                       'line_comment'
                    || l_input_data_tab (ln_generic_count).attribute26,
                    'xxd_ont_genesis_main_pkg.parse_data');
                --End changes v2.1
                --Start changes v3.4
                xxd_ont_genesis_proc_ord_pkg.write_to_table (
                       'line_price'
                    || l_input_data_tab (ln_generic_count).attribute15,
                    'xxd_ont_genesis_main_pkg.parse_data');
                xxd_ont_genesis_proc_ord_pkg.write_to_table (
                       'unit_selling_price'
                    || l_input_data_tab (ln_generic_count).attribute16,
                    'xxd_ont_genesis_main_pkg.parse_data');
            --End changes v3.4
            END LOOP;
        END LOOP;

        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'calling insert_stg_data',
            'xxd_ont_genesis_main_pkg.parse_data');
        xxd_ont_genesis_proc_ord_pkg.insert_stg_data (
            p_in_user_id    => ln_user_id,
            p_in_batch_id   => ln_batch_id,
            p_input_data    => l_input_data_tab,
            p_out_err_msg   => p_out_err_msg);
        p_out_err_msg      := p_out_err_msg || SQLERRM;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_err_msg   := 'ERROR' || SQLERRM;
            xxd_ont_genesis_proc_ord_pkg.write_to_table (
                'Unexpected error while parsing data' || SQLERRM,
                'xxd_ont_genesis_main_pkg.parse_data');
    END parse_data;

    --Start changes v2.1
    PROCEDURE fetch_cancel_reasons (p_out_reasons   OUT SYS_REFCURSOR,
                                    p_out_err_msg   OUT VARCHAR2)
    IS
        l_input_data_tab   GEN_TBL_TYPE;
        ln_count           NUMBER;
        ld_hdr_req_date    VARCHAR2 (100);
        lv_org             VARCHAR2 (10);
    BEGIN
        OPEN p_out_reasons FOR
            /*SELECT flv1.attribute1
       FROM fnd_lookup_values flv1
      WHERE 1=1
        AND flv1.lookup_type      ='XXD_ONT_GEN_ORD_CANCEL_CODE_LK'
        AND flv1.enabled_flag     = 'Y'
        AND flv1.LANGUAGE         = USERENV('LANG');*/
            SELECT flv1.attribute1 cancel_reason, ol.lookup_code cancel_code --,flv1.attribute2 default_comment
              FROM fnd_lookup_values flv1, oe_lookups ol
             WHERE     1 = 1
                   AND flv1.lookup_type = 'XXD_ONT_GENESIS_CANCELCODE_LKP'
                   AND flv1.enabled_flag = 'Y'
                   AND ol.meaning = flv1.attribute1
                   AND SYSDATE BETWEEN NVL (flv1.start_date_active, SYSDATE)
                                   AND NVL (flv1.end_date_active,
                                            SYSDATE + 1)
                   AND flv1.LANGUAGE = USERENV ('LANG');
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_err_msg   :=
                'Error while fetching cancel reasons' || SQLERRM;
            xxd_ont_genesis_proc_ord_pkg.write_to_table (
                'Unexpected error while fetching cancel reasons' || SQLERRM,
                'xxd_ont_genesis_main_pkg.fetch_cancel_reasons');
    END fetch_cancel_reasons;
--End changes v2.1
END xxd_ont_genesis_main_pkg;
/


GRANT EXECUTE, DEBUG ON APPS.XXD_ONT_GENESIS_MAIN_PKG TO XXORDS
/
