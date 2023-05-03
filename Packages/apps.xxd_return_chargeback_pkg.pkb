--
-- XXD_RETURN_CHARGEBACK_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:20 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_RETURN_CHARGEBACK_PKG"
AS
    /***********************************************************************************
       * $Header$
       * Program Name : XXD_RETURN_CHARGEBACK_PKG.pkb
       * Language     : PL/SQL
       * Description  : This package routine will be used to place multiple files to
       *                specific directory based upon the combination of brand and factory code
       *
       *
       * HISTORY
       *===================================================================================
       * Author                      Version                              Date
       *===================================================================================
       * BT Technology Team          1.0 - Initial Version                23-Feb-2015
       * BT Technology Team          1.1 - Changes as per CR 107          02-Sep-2015
       * BT Technology Team          1.2 - Fix for UAT2 Defect 286        02-Sep-2015
       ***********************************************************************************/
    PROCEDURE xxd_po_receipt (p_inventory_item_id NUMBER, p_organization_id NUMBER, p_vendor_id NUMBER, p_factory_code VARCHAR2, p_date_of_mfg VARCHAR2, x_po_num OUT NOCOPY VARCHAR2, x_receipt_num OUT NOCOPY VARCHAR2, x_vendor_name OUT NOCOPY VARCHAR2, x_vendor_site_code OUT NOCOPY VARCHAR2
                              , x_receipt_date OUT DATE)
    IS
        lc_po_num             VARCHAR2 (50);
        ln_item_id            NUMBER;
        ln_organization_id    NUMBER;
        lv_receipt_num        VARCHAR2 (100);
        lv_invoice_num        VARCHAR2 (100);
        lv_vendor_name        VARCHAR2 (240);
        lv_vendor_site_code   VARCHAR2 (100);
        ln_unit_cost          NUMBER;
        ld_transaction_date   DATE;
    BEGIN
        SELECT ph.segment1, rsh.receipt_num, ass.vendor_name,
               assa.vendor_site_code, TO_DATE (rt.transaction_date, 'DD-MM-YYYY')
          INTO x_po_num, x_receipt_num, x_vendor_name, x_vendor_site_code,
                       x_receipt_date
          FROM rcv_shipment_headers rsh, rcv_shipment_lines rsl, rcv_transactions rt,
               po_headers_all ph, po_lines_all pl, ap_suppliers ass,
               ap_supplier_sites_all assa
         WHERE     rsh.shipment_header_id = rsl.shipment_header_id
               AND rt.shipment_header_id = rsh.shipment_header_id
               AND rt.shipment_line_id = rsl.shipment_line_id
               AND rsl.po_header_id = ph.po_header_id
               AND rsl.po_line_id = pl.po_line_id
               AND ph.vendor_id = ass.vendor_id
               AND ph.vendor_site_id = assa.vendor_site_id
               AND rsl.item_id = p_inventory_item_id
               AND rt.organization_id = p_organization_id
               AND ass.vendor_id = p_vendor_id
               AND assa.attribute5 = p_factory_code
               AND rt.transaction_type = 'RECEIVE'
               AND (TRUNC (rt.transaction_date), rsl.item_id) =
                   (  SELECT MIN (TRUNC (rt1.transaction_date)), rsl1.item_id
                        FROM rcv_transactions rt1, rcv_shipment_lines rsl1
                       WHERE     1 = 1
                             AND rt1.shipment_line_id = rsl1.shipment_line_id
                             AND rsl1.item_id = rsl.item_id
                             AND rt1.organization_id = rt.organization_id
                             AND rt1.vendor_id = rt.vendor_id
                             AND rt1.transaction_type = 'RECEIVE'
                             AND rt1.transaction_date >=
                                 LAST_DAY ('01-' || p_date_of_mfg)
                    GROUP BY rsl1.item_id)
               AND ROWNUM = 1;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_po_num             := NULL;
            x_receipt_num        := NULL;
            x_vendor_name        := NULL;
            x_vendor_site_code   := NULL;
            x_receipt_date       := NULL;
    END xxd_po_receipt;

    PROCEDURE main (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY VARCHAR2, p_org_id IN NUMBER, p_brand IN VARCHAR2, p_style IN VARCHAR2, p_color IN VARCHAR2, p_factory_code IN VARCHAR2, p_product_code IN VARCHAR2, p_return_date_from IN VARCHAR2, p_return_date_to IN VARCHAR2, p_reason_code IN VARCHAR2, p_product_group IN VARCHAR2
                    , p_sales_region IN VARCHAR2, p_threshold_value IN VARCHAR2, p_source_dir IN VARCHAR2)
    AS
        TYPE return_chargeback_typ IS RECORD
        (
            factory_code          VARCHAR2 (240),
            vendor_id             NUMBER,
            order_number          VARCHAR2 (240),
            style_number          VARCHAR2 (240),
            return_date           DATE,
            brand                 VARCHAR2 (240),
            style_name            VARCHAR2 (240),
            color_code            VARCHAR2 (240),
            item_cost             NUMBER,
            date_of_mfg           VARCHAR2 (240),
            quantity              NUMBER,
            it_cost               NUMBER,
            return_reason_code    VARCHAR2 (240),
            inventory_item_id     NUMBER,
            trans_no              NUMBER,
            sales_region          VARCHAR2 (240),
            within_warranty       VARCHAR2 (240),
            production_code       VARCHAR2 (240),
            gl_num                VARCHAR2 (240),
            defect_damage_code    VARCHAR2 (240),
            organization_id       NUMBER
        );

        rec_return_chargeback       return_chargeback_typ;

        TYPE refcur_return_chargeback IS REF CURSOR;

        cur_return_chargeback       refcur_return_chargeback;

        -- Variable Declaration
        ln_success                  NUMBER DEFAULT 0;
        ln_warning                  NUMBER DEFAULT 1;
        ln_error                    NUMBER DEFAULT 2;
        ln_total_sum                NUMBER DEFAULT 0;
        lc_old_brand_factory_code   VARCHAR2 (100) DEFAULT 'X';
        lc_new_brand_factory_code   VARCHAR2 (100);
        lc_po_num                   VARCHAR2 (100);
        lc_receipt_num              VARCHAR2 (100);
        lc_vendor_name              VARCHAR2 (100);
        lc_vendor_site_code         VARCHAR2 (100);
        lc_file_name                VARCHAR2 (100);
        lc_query                    LONG;
        ld_receipt_date             DATE;
        l_utl_file_type             UTL_FILE.file_type;
        ln_enable_debug             NUMBER
            DEFAULT NVL (
                        do_get_profile_value ('XXD_CHARGEBACK_REPORT_DEBUG'),
                        0);
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Debug Enable: ' || ln_enable_debug);

        -- Start modification by BT Technology Team for UAT2 Defect 286 on 04-Nov-2015,  v1.2
        -- Changed the below query to have outer join for ASSA and APS
        -- Changes to lookup XXD_FACTORY_CODE_OU
        -- End modification by BT Technology Team for UAT2 Defect 286 on 04-Nov-2015,  v1.2
        lc_query    :=
            '             SELECT /*+ PARALLEL(10) */
                  -- aps.attribute1 factory_code, -- Commented by BT Technology Team for CR 107 on 11-Sep-2015,  v1.1
                  assa.attribute5 factory_code, -- Added by BT Technology Team for CR 107 on 11-Sep-2015,  v1.1
                  aps.vendor_id vendor_id,
                  ooha.order_number,
                  xciv.style_number,
                  TO_DATE (oola.fulfillment_date, ''DD-MON-YYYY'') return_date,
                  ooha.attribute5 brand,
                  xciv.style_desc style_name,
                  xciv.color_code,
                  ROUND (cis.item_cost, 2) item_cost,
                  bom_month.month_year date_of_mfg,
                  SUM (NVL (oola.ordered_quantity, 0)) quantity,
                  ROUND (
                     SUM (NVL (oola.fulfilled_quantity, 0) * cis.item_cost),
                     2)
                     it_cost,
                  oola.attribute12 return_reason_code,
                  xciv.inventory_item_id,
                  oola.line_id trans_no,
                  mp.attribute1 sales_region,
                  (CASE
                      WHEN TO_DATE (oola.fulfillment_date, ''DD-MON-YYYY'') <=
                              ADD_MONTHS (
                                 TO_DATE (bom_month.month_year, ''MON-YYYY''),
                                 15)
                      THEN
                         ''Yes''
                      ELSE
                         ''No''
                   END)
                     within_warranty,
                  bom_month.month_year production_code,
                  gl_code.description gl_num,
                  oola.attribute12 defect_damage_code,
                  oola.ship_from_org_id organization_id
             FROM cst_item_costs cis,
                  xxd_common_items_v xciv,
                  oe_order_headers_all ooha,
                  ap_suppliers aps,
                  ap_supplier_sites_all assa, -- Added by BT Technology Team for CR 107 on 11-Sep-2015,  v1.1
                  mtl_parameters mp,
                  do_bom_month_year_v bom_month,
                  oe_order_lines_all oola,
                  (SELECT lookup_code
                     FROM fnd_lookup_values flv
                    WHERE     lookup_type = ''DO_SALES_REGIONS''
                          AND language = USERENV (''LANG'')
                          AND enabled_flag = ''Y''
                          AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE)
                                          AND NVL (end_date_active, SYSDATE)) sales_reg_lkp,
                  (SELECT lookup_code, description
                     FROM fnd_lookup_values
                    WHERE     lookup_type = ''XXDO_BRAND_GL_LKP''
                          AND language = USERENV (''LANG'')
                          AND enabled_flag = ''Y''
                          AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE)
                                          AND NVL (end_date_active, SYSDATE)) gl_code,
                  (SELECT hou.organization_id
                     FROM hr_all_organization_units hou,
                          fnd_lookup_values flv
                    WHERE     hou.name = flv.meaning
                          AND flv.lookup_type = ''XXD_FACTORY_CODE_OU''
                          AND flv.enabled_flag = ''Y''
                          AND SYSDATE BETWEEN NVL (flv.start_date_active, SYSDATE)
                                          AND NVL (flv.end_date_active, SYSDATE)
                          AND flv.language = USERENV (''LANG'')) vendor_org
            WHERE     mp.organization_id = oola.ship_from_org_id
                  AND bom_month.month_year_code (+) = oola.attribute5
                  AND ooha.header_id = oola.header_id
                  AND xciv.inventory_item_id = oola.inventory_item_id
                  AND xciv.organization_id = oola.ship_from_org_id
                  AND cis.inventory_item_id = oola.inventory_item_id
                  AND cis.organization_id = oola.ship_from_org_id
                  AND cis.cost_type_id = 2                  -- Average Costing
                  -- Start modification by BT Technology Team for CR 107 on 11-Sep-2015,  v1.1
                  -- AND aps.vendor_id(+) = TO_NUMBER (TRIM (oola.attribute4))
                  AND aps.vendor_id (+) = assa.vendor_id
                  AND assa.vendor_site_id(+) =
                         TO_NUMBER (TRIM (oola.attribute4))
                  AND assa.purchasing_site_flag(+) = ''Y''
                  AND NVL (assa.inactive_date(+), SYSDATE + 1) > SYSDATE
                  AND NVL (assa.attribute5(+), ''NONE'') != ''NONE''
                  AND assa.org_id = vendor_org.organization_id(+)
                  -- End modification by BT Technology Team for CR 107 on 11-Sep-2015,  v1.1
                  AND sales_reg_lkp.lookup_code = mp.attribute1
                  AND gl_code.lookup_code = ooha.attribute5
                  AND oola.line_category_code = ''RETURN''
                  AND oola.ordered_quantity != 0
                  AND EXISTS
                         (SELECT 1
                            FROM apps.fnd_flex_value_sets ffvs,
                                 apps.fnd_flex_values ffv,
                                 apps.fnd_flex_values_tl ffvt
                           WHERE     ffvs.flex_value_set_name =
                                        ''DO_OM_DEFECT_VS''
                                 AND ffvs.flex_value_set_id =
                                        ffv.flex_value_set_id
                                 AND ffvt.flex_value_id = ffv.flex_value_id
                                 AND ffv.enabled_flag = ''Y''
                                 AND ffvt.language = USERENV (''LANG'')
                                 AND oola.attribute12 = ffv.flex_value)
                  AND oola.org_id = :p_org_id
                  AND TO_DATE (oola.fulfillment_date, ''DD-MON-YYYY'') >=
                         TO_DATE (
                            fnd_date.canonical_to_date (:p_return_date_from),
                            ''DD-MON-YYYY'')
                  AND TO_DATE (oola.fulfillment_date, ''DD-MON-YYYY'') <=
                         TO_DATE (
                            fnd_date.canonical_to_date (:p_return_date_to),
                            ''DD-MON-YYYY'')';

        IF p_brand IS NOT NULL
        THEN
            lc_query   :=
                   lc_query
                || CHR (10)
                || ' AND ooha.attribute5 ='''
                || p_brand
                || '''';
        END IF;

        IF p_style IS NOT NULL
        THEN
            lc_query   :=
                   lc_query
                || CHR (10)
                || ' AND xciv.style_number ='''
                || p_style
                || '''';
        END IF;

        IF p_color IS NOT NULL
        THEN
            lc_query   :=
                   lc_query
                || CHR (10)
                || ' AND xciv.color_code ='''
                || p_color
                || '''';
        END IF;

        IF p_product_code IS NOT NULL
        THEN
            lc_query   :=
                   lc_query
                || CHR (10)
                || ' AND NVL (oola.attribute5, ''N/A'') ='''
                || p_product_code
                || '''';
        END IF;

        IF p_factory_code IS NOT NULL
        THEN
            lc_query   :=
                   lc_query
                || CHR (10)
                || ' AND assa.vendor_site_id ='''
                || p_factory_code
                || '''';
        END IF;

        IF p_reason_code IS NOT NULL
        THEN
            lc_query   :=
                   lc_query
                || CHR (10)
                || ' AND NVL (oola.attribute12, ''N/A'') ='''
                || p_reason_code
                || '''';
        END IF;

        IF p_product_group IS NOT NULL
        THEN
            lc_query   :=
                   lc_query
                || CHR (10)
                || ' AND xciv.department='''
                || p_product_group
                || '''';
        END IF;

        IF p_sales_region IS NOT NULL
        THEN
            lc_query   :=
                   lc_query
                || CHR (10)
                || ' AND sales_reg_lkp.lookup_code ='''
                || p_sales_region
                || '''';
        END IF;

        lc_query    :=
               lc_query
            || CHR (10)
            || '                  -- Start modification by BT Technology Team for CR 107 on 11-Sep-2015,  v1.1
                  -- GROUP BY aps.attribute1,
                  GROUP BY assa.attribute5,
                  -- End modification by BT Technology Team for CR 107 on 11-Sep-2015,  v1.1
                       aps.vendor_id,
                       xciv.style_number,
                       ooha.attribute5,
                       xciv.style_desc,
                       xciv.color_code,
                       cis.item_cost,
                       bom_month.month_year,
                       oola.attribute12,
                       xciv.inventory_item_id,
                       oola.ship_from_org_id,
                       ooha.order_number,
                       oola.line_id,
                       TO_DATE (oola.fulfillment_date, ''DD-MON-YYYY''),
                       mp.attribute1,
                       gl_code.description
         ORDER BY brand, factory_code';

        OPEN cur_return_chargeback FOR lc_query USING p_org_id, p_return_date_from, p_return_date_to;

        IF ln_enable_debug <> 0
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Dynamic Query:' || CHR (10) || lc_query);
        END IF;

        IF cur_return_chargeback%ISOPEN
        THEN
           <<main_loop>>
            LOOP
                FETCH cur_return_chargeback INTO rec_return_chargeback;

                EXIT main_loop WHEN cur_return_chargeback%NOTFOUND;

                lc_new_brand_factory_code   :=
                       rec_return_chargeback.brand
                    || '_'
                    || rec_return_chargeback.factory_code;

                -- Skip any line which doesn't satisfy the threshold
                IF NVL (p_threshold_value, rec_return_chargeback.it_cost) <=
                   rec_return_chargeback.it_cost
                THEN
                    IF lc_new_brand_factory_code <> lc_old_brand_factory_code
                    THEN
                        -- Reset the value for new file
                        lc_old_brand_factory_code   :=
                            lc_new_brand_factory_code;

                        lc_file_name   :=
                               'Returns_Chargeback_'
                            || rec_return_chargeback.sales_region
                            || '_'
                            || lc_new_brand_factory_code
                            || '_'
                            || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS')
                            || '.xls';

                        -- Trailer record for Total. Will be executed before a new file opens
                        IF UTL_FILE.is_open (l_utl_file_type)
                        THEN
                            UTL_FILE.put_line (
                                l_utl_file_type,
                                   ''
                                || CHR (9)
                                || ''
                                || CHR (9)
                                || ''
                                || CHR (9)
                                || ''
                                || CHR (9)
                                || ''
                                || CHR (9)
                                || ''
                                || CHR (9)
                                || ''
                                || CHR (9)
                                || ''
                                || CHR (9)
                                || ''
                                || CHR (9)
                                || ''
                                || CHR (9)
                                || 'Total Item Cost'
                                || CHR (9)
                                || ln_total_sum);

                            IF ln_enable_debug <> 0
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       ''
                                    || CHR (9)
                                    || ''
                                    || CHR (9)
                                    || ''
                                    || CHR (9)
                                    || ''
                                    || CHR (9)
                                    || ''
                                    || CHR (9)
                                    || ''
                                    || CHR (9)
                                    || ''
                                    || CHR (9)
                                    || ''
                                    || CHR (9)
                                    || ''
                                    || CHR (9)
                                    || ''
                                    || CHR (9)
                                    || 'Total Item Cost'
                                    || CHR (9)
                                    || ln_total_sum);
                                fnd_file.put_line (fnd_file.LOG, CHR (10));
                            END IF;

                            -- Close the old file
                            UTL_FILE.fclose (l_utl_file_type);
                            -- Reset value after each file close
                            ln_total_sum   := 0;
                        END IF;                            -- UTL_FILE.is_open

                        l_utl_file_type   :=
                            UTL_FILE.fopen (p_source_dir, lc_file_name, 'W');

                        IF ln_enable_debug <> 0
                        THEN
                            fnd_file.put_line (fnd_file.LOG, CHR (10));
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'File Name - ' || lc_file_name);
                        END IF;

                        UTL_FILE.put_line (
                            l_utl_file_type,
                               'Trans#'
                            || CHR (9)
                            || 'GL#'
                            || CHR (9)
                            || 'Sales Region'
                            || CHR (9)
                            || 'Brand'
                            || CHR (9)
                            || 'Factory Code'
                            || CHR (9)
                            || 'Production Code'
                            || CHR (9)
                            || 'Style Number'
                            || CHR (9)
                            || 'Style Name'
                            || CHR (9)
                            || 'Color Code'
                            || CHR (9)
                            || 'Order Number'
                            || CHR (9)
                            || 'Return Date'
                            || CHR (9)
                            || 'Item Cost'
                            || CHR (9)
                            || 'PO#'
                            || CHR (9)
                            || 'Receipt#'
                            || CHR (9)
                            || 'Receipt Date'
                            || CHR (9)
                            || 'Vendor Name'
                            || CHR (9)
                            || 'Vendor Site'
                            || CHR (9)
                            || 'Defect Damage Code'
                            || CHR (9)
                            || 'Within Warranty'
                            || CHR (9)
                            || 'Image File Name'
                            || CHR (9)
                            || 'Image1');

                        IF ln_enable_debug <> 0
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Trans#'
                                || CHR (9)
                                || 'GL#'
                                || CHR (9)
                                || 'Sales Region'
                                || CHR (9)
                                || 'Brand'
                                || CHR (9)
                                || 'Factory Code'
                                || CHR (9)
                                || 'Production Code'
                                || CHR (9)
                                || 'Style Number'
                                || CHR (9)
                                || 'Style Name'
                                || CHR (9)
                                || 'Color Code'
                                || CHR (9)
                                || 'Order Number'
                                || CHR (9)
                                || 'Return Date'
                                || CHR (9)
                                || 'Item Cost'
                                || CHR (9)
                                || 'PO#'
                                || CHR (9)
                                || 'Receipt#'
                                || CHR (9)
                                || 'Receipt Date'
                                || CHR (9)
                                || 'Vendor Name'
                                || CHR (9)
                                || 'Vendor Site'
                                || CHR (9)
                                || 'Defect Damage Code'
                                || CHR (9)
                                || 'Within Warranty'
                                || CHR (9)
                                || 'Image File Name'
                                || CHR (9)
                                || 'Image1');
                        END IF;
                    END IF;                          -- new value <> old value

                    ln_total_sum   :=
                        ln_total_sum + rec_return_chargeback.it_cost;
                    xxd_po_receipt (p_inventory_item_id => rec_return_chargeback.inventory_item_id, p_organization_id => rec_return_chargeback.organization_id, p_vendor_id => rec_return_chargeback.vendor_id, p_factory_code => rec_return_chargeback.factory_code, p_date_of_mfg => rec_return_chargeback.date_of_mfg, x_po_num => lc_po_num, x_receipt_num => lc_receipt_num, x_vendor_name => lc_vendor_name, x_vendor_site_code => lc_vendor_site_code
                                    , x_receipt_date => ld_receipt_date);
                    UTL_FILE.put_line (
                        l_utl_file_type,
                           rec_return_chargeback.trans_no
                        || CHR (9)
                        || rec_return_chargeback.gl_num
                        || CHR (9)
                        || rec_return_chargeback.sales_region
                        || CHR (9)
                        || rec_return_chargeback.brand
                        || CHR (9)
                        || rec_return_chargeback.factory_code
                        || CHR (9)
                        || rec_return_chargeback.production_code
                        || CHR (9)
                        || rec_return_chargeback.style_number
                        || CHR (9)
                        || rec_return_chargeback.style_name
                        || CHR (9)
                        || rec_return_chargeback.color_code
                        || CHR (9)
                        || rec_return_chargeback.order_number
                        || CHR (9)
                        || rec_return_chargeback.return_date
                        || CHR (9)
                        || rec_return_chargeback.it_cost
                        || CHR (9)
                        || lc_po_num
                        || CHR (9)
                        || lc_receipt_num
                        || CHR (9)
                        || ld_receipt_date
                        || CHR (9)
                        || lc_vendor_name
                        || CHR (9)
                        || lc_vendor_site_code
                        || CHR (9)
                        || rec_return_chargeback.defect_damage_code
                        || CHR (9)
                        || rec_return_chargeback.within_warranty
                        || CHR (9)
                        || rec_return_chargeback.trans_no
                        || CHR (9)
                        || NULL);

                    IF ln_enable_debug <> 0
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               rec_return_chargeback.trans_no
                            || CHR (9)
                            || rec_return_chargeback.gl_num
                            || CHR (9)
                            || rec_return_chargeback.sales_region
                            || CHR (9)
                            || rec_return_chargeback.brand
                            || CHR (9)
                            || rec_return_chargeback.factory_code
                            || CHR (9)
                            || rec_return_chargeback.production_code
                            || CHR (9)
                            || rec_return_chargeback.style_number
                            || CHR (9)
                            || rec_return_chargeback.style_name
                            || CHR (9)
                            || rec_return_chargeback.color_code
                            || CHR (9)
                            || rec_return_chargeback.order_number
                            || CHR (9)
                            || rec_return_chargeback.return_date
                            || CHR (9)
                            || rec_return_chargeback.it_cost
                            || CHR (9)
                            || lc_po_num
                            || CHR (9)
                            || lc_receipt_num
                            || CHR (9)
                            || ld_receipt_date
                            || CHR (9)
                            || lc_vendor_name
                            || CHR (9)
                            || lc_vendor_site_code
                            || CHR (9)
                            || rec_return_chargeback.defect_damage_code
                            || CHR (9)
                            || rec_return_chargeback.within_warranty
                            || CHR (9)
                            || rec_return_chargeback.trans_no
                            || CHR (9)
                            || NULL);
                    END IF;
                END IF;                               -- Threshold limit check
            END LOOP;
        END IF;                                -- cur_return_chargeback%ISOPEN

        -- Close the Last File after printing the Trailer record
        IF UTL_FILE.is_open (l_utl_file_type)
        THEN
            UTL_FILE.put_line (
                l_utl_file_type,
                   ''
                || CHR (9)
                || ''
                || CHR (9)
                || ''
                || CHR (9)
                || ''
                || CHR (9)
                || ''
                || CHR (9)
                || ''
                || CHR (9)
                || ''
                || CHR (9)
                || ''
                || CHR (9)
                || ''
                || CHR (9)
                || ''
                || CHR (9)
                || 'Total Item Cost'
                || CHR (9)
                || ln_total_sum);

            IF ln_enable_debug <> 0
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       ''
                    || CHR (9)
                    || ''
                    || CHR (9)
                    || ''
                    || CHR (9)
                    || ''
                    || CHR (9)
                    || ''
                    || CHR (9)
                    || ''
                    || CHR (9)
                    || ''
                    || CHR (9)
                    || ''
                    || CHR (9)
                    || ''
                    || CHR (9)
                    || ''
                    || CHR (9)
                    || 'Total Item Cost'
                    || CHR (9)
                    || ln_total_sum);
                fnd_file.put_line (fnd_file.LOG, CHR (10));
            END IF;

            UTL_FILE.fclose (l_utl_file_type);
        END IF;

        x_retcode   := ln_success;
    EXCEPTION
        WHEN UTL_FILE.invalid_operation
        THEN
            fnd_file.put_line (fnd_file.LOG, 'invalid operation');
            UTL_FILE.fclose_all;
        WHEN UTL_FILE.invalid_path
        THEN
            fnd_file.put_line (fnd_file.LOG, 'invalid path');
            UTL_FILE.fclose_all;
            x_retcode   := ln_error;
        WHEN UTL_FILE.invalid_mode
        THEN
            fnd_file.put_line (fnd_file.LOG, 'invalid mode');
            UTL_FILE.fclose_all;
        WHEN UTL_FILE.invalid_filehandle
        THEN
            fnd_file.put_line (fnd_file.LOG, 'invalid filehandle');
            UTL_FILE.fclose_all;
        WHEN UTL_FILE.read_error
        THEN
            fnd_file.put_line (fnd_file.LOG, 'read error');
            UTL_FILE.fclose_all;
            x_retcode   := ln_error;
        WHEN UTL_FILE.internal_error
        THEN
            fnd_file.put_line (fnd_file.LOG, 'internal error');
            UTL_FILE.fclose_all;
            x_retcode   := ln_error;
        WHEN OTHERS
        THEN
            x_retcode   := ln_warning;
            fnd_file.put_line (fnd_file.LOG, 'other error: ' || SQLERRM);
            UTL_FILE.fclose_all;
    END main;
END xxd_return_chargeback_pkg;
/
