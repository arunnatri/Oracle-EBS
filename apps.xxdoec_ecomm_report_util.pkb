--
-- XXDOEC_ECOMM_REPORT_UTIL  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:04 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOEC_ECOMM_REPORT_UTIL"
IS
    -- Purpose: Briefly explain the functionality of the package
    -- Oracle apps custom reports, output file excel
    -- MODIFICATION HISTORY
    -- Person                                    Date                                Comments
    --Saritha  Movva                      03-06-2011                           Initial Version
    --Saritha Movva                       07-18-2011                       Phase3 Report Changes
    --Saritha Movva                       12-26-2011                       INC0099731  New Report for  Order reconciliation
    --Saritha Movva                       12-26-2011                       INC0101724 Added Result, Process Flag, Site in Order Summary Report
    --Saritha Movva                       12-26-2011                       INC0101724  Added Site in Back Order,Booked Orders, Booked Orders NA, Order Cancellation, Gift Warp,
    --Credit memo, Shipped not invoiced, Outstanding Account balance, Return Orders report
    --Saritha Movva                       01-16-2012                       Added Site_ID Parameter to Order fill Rate, Booked orders, Unpaid Invoices, Warehouse Aging reports.
    --Saritha Movva                       01-24-2012                       New Report for Chanel Advisor  Cash reconciliation
    --Saritha Movva                       01-25-2012                       Added Ship to address information to Return  Report
    --Madhav Dhurjaty                   11-26-2012                       Added Default Null to in parameters of procedure ca_cash_recon_report for INC0127948
    --Randy Kinsel                         11-27-2012                       Added call to remove_special_characters(model_name) in run_atp_report() for INC0122993/AtTask20336161
    --Madhav Dhurjaty                     03-15-2013                       Created new functions 'get_tracking_num', 'get_shipping_status' for DFCT0010413
    --Madhav Dhurjaty                     08-21-2013                       Modified run_margin_report for DFCT0010598
    -- Amitava Ghosh                      08-19-2014                       Added  Web User Column in Return Order Report
    -- BT Technology Team                 06-JAN-2014                      Added Tender type column in Manual refund report
    --GJensen                             30-May-2017                      Added site_id and country to return report
    -- -----------------                   ------------------                ---------------------------------------------------------------------------------------------------------------
    FUNCTION get_tracking_num (p_order_line_id IN NUMBER)
        --Created by Madhav Dhurjaty on 03/15/2013 for DFCT0010413
        RETURN VARCHAR2
    IS
        l_tracking_num   VARCHAR2 (360);

        CURSOR c_trk_num IS
            SELECT tracking_number
              FROM apps.wsh_delivery_details
             WHERE     1 = 1
                   AND source_code = 'OE'
                   AND source_line_id(+) = p_order_line_id;
    BEGIN
        FOR r_trk_num IN c_trk_num
        LOOP
            IF l_tracking_num IS NOT NULL
            THEN
                l_tracking_num   := l_tracking_num || ',';
            END IF;

            l_tracking_num   :=
                SUBSTR (l_tracking_num || r_trk_num.tracking_number, 1, 360);
        END LOOP;

        RETURN l_tracking_num;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_tracking_num;

    FUNCTION get_shipping_status (p_order_line_id IN NUMBER)
        --Created by Madhav Dhurjaty on 03/15/2013 for DFCT0010413
        --Modified by kcopeland on 10/1/2013 for 1259337
        RETURN VARCHAR2
    IS
        l_del_status   VARCHAR2 (240);
    BEGIN
        SELECT lkp.meaning
          INTO l_del_status
          FROM apps.wsh_delivery_details wdd, apps.fnd_lookup_values lkp
         WHERE     1 = 1
               AND wdd.source_line_id(+) = p_order_line_id
               --53975331--ool.line_id removed hard coded line id 10/1/2013 for AtTask reference 1259337
               AND wdd.source_code(+) = 'OE'
               AND lkp.lookup_code = wdd.released_status
               AND lkp.lookup_type = 'PICK_STATUS'
               AND lkp.LANGUAGE = 'US'
               AND ROWNUM = 1;

        RETURN l_del_status;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_shipping_status;

    PROCEDURE run_margin_report (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id VARCHAR2, p_multi_org_ids VARCHAR2, p_date_from VARCHAR2, p_date_to VARCHAR2, p_brand VARCHAR2, p_margin NUMBER, p_customer_id NUMBER
                                 , p_dis_pro_code VARCHAR2)
    IS
        l_date_from      DATE;
        l_date_to        DATE;
        v_margin         NUMBER := 0;
        l_query_string   VARCHAR2 (4000);
        l_where_string   VARCHAR2 (2000);
    BEGIN
        l_date_from   := fnd_date.canonical_to_date (p_date_from);
        l_date_to     := fnd_date.canonical_to_date (p_date_to);

        /*IF p_margin IS NULL
        THEN
           v_margin := 5;
        ELSE
           v_margin := p_margin;
        END IF;*/
        BEGIN
            IF p_org_id IS NOT NULL
            THEN
                l_where_string   := ' AND org_id = ' || p_org_id;
            ELSIF p_multi_org_ids IS NOT NULL
            THEN
                l_where_string   :=
                    ' AND org_id IN (' || p_multi_org_ids || ')';
            ELSE
                l_where_string   :=
                    ' AND org_id IN (SELECT DISTINCT erp_org_id FROM xxdoec_country_brand_params) ';
            END IF;

            IF p_customer_id IS NOT NULL
            THEN
                l_where_string   :=
                    ' AND cust_account_id = ' || p_customer_id;
            END IF;

            IF p_brand IS NOT NULL
            THEN
                l_where_string   :=
                       l_where_string
                    || ' AND brand =  '
                    || ''''
                    || p_brand
                    || '''';
            END IF;

            IF p_dis_pro_code IS NOT NULL
            THEN
                l_where_string   :=
                       l_where_string
                    || ' AND discount_code like '
                    || '''%'
                    || p_dis_pro_code
                    || '%''';
            END IF;

            /*l_where_string := l_where_string ||
                              ' AND ordered_date BETWEEN  to_date(' || '''' ||
                              l_date_from || ' 00:00:00' || '''' || ',' || '''' ||
                              'DD-MON-RR HH24:MI:SS' || '''' || ')  AND ' ||
                              ' to_date(' || '''' || l_date_to || ' 23:59:59' || '''' || ',' || '''' ||
                              'DD-MON-RR HH24:MI:SS' || '''' || ')';*/
            --Commented by Madhav Dhurjaty  for DFCT0010598 on 8/21/13
            l_where_string   :=
                   l_where_string
                || ' AND invoice_date BETWEEN  to_date('
                || ''''
                || l_date_from
                || ' 00:00:00'
                || ''''
                || ','
                || ''''
                || 'DD-MON-RR HH24:MI:SS'
                || ''''
                || ')  AND '
                || ' to_date('
                || ''''
                || l_date_to
                || ' 23:59:59'
                || ''''
                || ','
                || ''''
                || 'DD-MON-RR HH24:MI:SS'
                || ''''
                || ')'; --Added by Madhav Dhurjaty  for DFCT0010598 on 8/21/13
            l_where_string   :=
                   l_where_string
                || ' AND result IS NOT NULL AND result <> ''FAIL''';

            --l_where_string :=  l_where_string || ' AND ROUND (100- (unit_selling_price * 100 / decode(unit_list_price,0,1,unit_list_price)), 2) >= ' || v_margin;
            IF p_margin IS NOT NULL
            THEN
                l_where_string   :=
                       l_where_string
                    || ' AND ROUND ((unit_selling_price - unit_cost) * 100 / decode(unit_selling_price,0,1,unit_selling_price), 2) <> '
                    || p_margin;
            END IF;

            l_query_string   :=
                   'SELECT OPERATING_UNIT "Operating Unit", '
                || 'site "Website ID", '
                || 'customer_number "Customer Number", '
                || 'XXDOEC_ECOMM_REPORT_UTIL.remove_special_characters '
                || '(customer_name) '
                || ' "Customer Name", '
                || 'EMAIL_ADDRESS "Email Address", '
                || 'to_number(invoice_number) "Invoice Number", '
                || 'invoice_date "Invoice Date", '
                || '(invoice_line_total + tax_amount) "Invoice Total", '
                || 'web_order_number "Web Order Number", '
                || 'ordered_date "Ordered Date", '
                || 'oracle_order_number "Oracle Order Number", '
                || 'brand "Brand", '
                || 'sku_number "Sku Number", '
                || 'ordered_quantity "Ordered Quantity", '
                || 'currency_code "Currency", '
                || 'ROUND (unit_list_price, 2) "Item List Price", '
                || 'ROUND (unit_selling_price, 2) "Item Selling Price", '
                || 'ROUND(unit_cost,2) "Product Cost ", '
                || 'ROUND (unit_selling_price - unit_cost, 2) "Margin Amount", '
                || 'ROUND ((unit_selling_price - unit_cost) * 100 / decode(unit_selling_price,0,1,unit_selling_price), 2) "Margin % ", '
                || 'ROUND (unit_list_price - unit_selling_price, 2) "Item Discount Amount", '
                || 'ROUND ((unit_list_price - unit_selling_price) * 100 / decode(unit_list_price,0,1,unit_list_price), 2) "Item Discount % ", '
                || 'discount_code "Discount Code / Promotion ID", '
                || 'ROUND(freight_charge,2) "Freight Charge Amount ", '
                || 'ROUND (freight_discount, 2) "Freight Discount Amount", '
                || 'ROUND(freight_charge + freight_discount, 2) "Freight Amount", '
                || 'ROUND ( freight_discount * 100 / decode(freight_charge,0,1,freight_charge), 2)  "Freight Discount % ", '
                || '(case when unit_list_price - unit_selling_price > 0 and freight_discount > 0 then ''Product/Freight'' when unit_list_price - unit_selling_price > 0  then ''Product'' when freight_discount > 0  then ''Freight'' else null end) "What Discounted", '
                || 'retail_price_list "Retail Price List", '
                || 'order_line_status "Order Line Status", '
                || 'custom_line_status "Custom Line Status", '
                || 'sales_rep_name "SalesRep Name" '
                || 'FROM APPS.XXDOEC_MARGIN_RPT_V '
                || 'WHERE 1 = 1'
                || l_where_string
                || ' ORDER BY operating_unit,sku_number,ROUND (unit_selling_price - unit_cost, 2) ';
            fnd_file.put_line (fnd_file.LOG, l_query_string);
            owa_sylk_apps.show (p_query => l_query_string);
        EXCEPTION
            WHEN OTHERS
            THEN
                errbuf    := SQLERRM;
                retcode   := 2;
                fnd_file.put_line (
                    fnd_file.LOG,
                    '**************ERROR OCCURRED at Sylk************');
                fnd_file.put_line (fnd_file.LOG, SQLERRM);
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            errbuf    := SQLERRM;
            retcode   := 2;
            fnd_file.put_line (
                fnd_file.LOG,
                '**************ERROR OCCURRED general************');
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
    END;

    --*********************************************************************
    PROCEDURE run_unpaid_invoices_report (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id VARCHAR2, p_site_id VARCHAR2, p_date_from VARCHAR2, p_date_to VARCHAR2
                                          , p_multi_org_ids VARCHAR2)
    IS
        l_date_from      DATE;
        l_date_to        DATE;
        l_query_string   VARCHAR2 (4000);
        l_where_string   VARCHAR2 (2000);
    BEGIN
        l_date_from   := fnd_date.canonical_to_date (p_date_from);
        l_date_to     := fnd_date.canonical_to_date (p_date_to);

        BEGIN
            IF p_org_id IS NOT NULL
            THEN
                l_where_string   := ' AND org_id = ' || p_org_id;
            ELSIF p_multi_org_ids IS NOT NULL
            THEN
                l_where_string   :=
                    ' AND org_id IN (' || p_multi_org_ids || ')';
            ELSE
                l_where_string   :=
                    ' AND org_id IN (SELECT DISTINCT erp_org_id FROM xxdoec_country_brand_params) ';
            END IF;

            IF p_site_id IS NOT NULL
            THEN
                l_where_string   :=
                       l_where_string
                    || ' AND site =  '
                    || ''''
                    || p_site_id
                    || '''';
            END IF;

            l_where_string   :=
                   l_where_string
                || ' AND invoice_date BETWEEN  to_date('
                || ''''
                || ---Modified by Kishore Sunera(INC0118839 ) As per CCR CCR0002396
                   l_date_from
                || ' 00:00:00'
                || ''''
                || ','
                || ''''
                || 'DD-MON-RR HH24:MI:SS'
                || ''''
                || ')  AND '
                || ' to_date('
                || ''''
                || l_date_to
                || ' 23:59:59'
                || ''''
                || ','
                || ''''
                || 'DD-MON-RR HH24:MI:SS'
                || ''''
                || ')';
            l_query_string   :=
                   'SELECT operating_unit "Operating Unit", '
                || 'site "Website ID", '
                || 'oracle_order_number "Oracle Order Number", '
                || 'ordered_date "Ordered Date", '
                || 'web_order_number "Web Order Number", '
                || 'customer_number "Customer Number", '
                || 'XXDOEC_ECOMM_REPORT_UTIL.remove_special_characters '
                || '(customer_name) '
                || ' "Customer Name", '
                || 'to_number(invoice_number) "Invoice Number", '
                || 'invoice_date "Invoice Date", '
                || 'currency "Currency", '
                || 'invoice_amount "Invoice Amount", '
                || 'invoice_balance "Invoice Balance", '
                || 'order_line_status "Order Line Status", '
                || 'custom_line_status "Custom Line Status", '
                || 'order_source "Source", '
                || 'do_order_type "Order Type", '
                || 'Scheduled_close_date "Scheduled Close Date" '
                || 'FROM XXDOEC_UNPAID_INVOICES_RPT_V '
                || 'WHERE 1 = 1'
                || l_where_string
                || 'ORDER BY  operating_unit ,oracle_order_number ';
            fnd_file.put_line (fnd_file.LOG, l_query_string);
            owa_sylk_apps.show (p_query => l_query_string);
        EXCEPTION
            WHEN OTHERS
            THEN
                errbuf    := SQLERRM;
                retcode   := 2;
                fnd_file.put_line (
                    fnd_file.LOG,
                    '**************ERROR OCCURRED at Sylk************');
                fnd_file.put_line (fnd_file.LOG, SQLERRM);
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            errbuf    := SQLERRM;
            retcode   := 2;
            fnd_file.put_line (
                fnd_file.LOG,
                '**************ERROR OCCURRED general************');
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
    END;

    --*********************************************************************
    PROCEDURE run_unapplied_cash_report (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id VARCHAR2
                                         , p_multi_org_ids VARCHAR2)
    IS
        l_query_string   VARCHAR2 (4000);
        l_where_string   VARCHAR2 (2000);
    BEGIN
        IF p_org_id IS NOT NULL
        THEN
            l_where_string   := ' AND org_id = ' || p_org_id;
        ELSIF p_multi_org_ids IS NOT NULL
        THEN
            l_where_string   := ' AND org_id IN (' || p_multi_org_ids || ')';
        ELSE
            l_where_string   :=
                ' AND org_id IN (SELECT DISTINCT erp_org_id FROM xxdoec_country_brand_params) ';
        END IF;

        l_query_string   :=
               'SELECT operating_unit "Operating Unit", '
            || 'site "Website ID",'
            || 'receipt_number "Receipt Number", '
            || 'receipt_date "Receipt Date",'
            || 'customer_number "Customer Number", '
            || 'XXDOEC_ECOMM_REPORT_UTIL.remove_special_characters '
            || '(customer_name) '
            || ' "Customer Name", '
            || 'currency_code "Currency Code", '
            || 'receipt_amount "Receipt Amount",'
            || 'applied_amount "Applied Amount", '
            || 'balance "Balance", '
            || 'comments "Comments" '
            || 'FROM APPS.XXDOEC_UNAPPLIED_CASH_R_RPT_V '
            || 'WHERE 1 = 1'
            || l_where_string
            || 'ORDER BY  operating_unit ,customer_number ';
        fnd_file.put_line (fnd_file.LOG, l_query_string);
        owa_sylk_apps.show (p_query => l_query_string);
    EXCEPTION
        WHEN OTHERS
        THEN
            errbuf    := SQLERRM;
            retcode   := 2;
            fnd_file.put_line (
                fnd_file.LOG,
                '**************ERROR OCCURRED at Sylk************');
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
    END;

    --*********************************************************************
    PROCEDURE run_warehouse_aging_report (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id VARCHAR2, p_multi_org_ids VARCHAR2, p_site_id VARCHAR2, p_brand VARCHAR2
                                          , p_back_order VARCHAR2)
    IS
        l_query_string   VARCHAR2 (4000);
        l_where_string   VARCHAR2 (2000);
    BEGIN
        IF p_org_id IS NOT NULL
        THEN
            l_where_string   := ' AND org_id = ' || p_org_id;
        ELSIF p_multi_org_ids IS NOT NULL
        THEN
            l_where_string   := ' AND org_id IN (' || p_multi_org_ids || ')';
        ELSE
            l_where_string   :=
                ' AND org_id IN (SELECT DISTINCT erp_org_id FROM xxdoec_country_brand_params) ';
        END IF;

        IF p_site_id IS NOT NULL
        THEN
            l_where_string   :=
                   l_where_string
                || ' AND site =  '
                || ''''
                || p_site_id
                || '''';
        END IF;

        IF p_brand IS NOT NULL
        THEN
            l_where_string   :=
                l_where_string || ' AND brand =  ' || '''' || p_brand || '''';
        END IF;

        IF p_back_order IS NOT NULL
        THEN
            l_where_string   :=
                   l_where_string
                || ' AND back_ordered =  '
                || ''''
                || p_back_order
                || '''';
        END IF;

        l_query_string   :=
               'SELECT OPERATING_UNIT "Operating Unit", '
            || 'SITE "Website ID", '
            || 'ORACLE_ORDER_NUMBER "Oracle Order Number", '
            || 'WEB_ORDER_NUMBER "Web Order Number", '
            || 'ORDERED_DATE "Ordered Date", '
            || 'PICK_TICKET_NUMBER "Pick Ticket Number", '
            || 'PICKED_ON "Picked On", '
            || 'CUSTOMER_NUMBER "Cutomer Number", '
            || 'XXDOEC_ECOMM_REPORT_UTIL.remove_special_characters '
            || '(CUSTOMER_NAME) '
            || ' "Customer Name", '
            || 'ORDER_AGE "Order Age", '
            || 'BRAND "Brand", '
            || 'ORDERED_ITEM "Ordered Item", '
            || 'ORDERED_QUANTITY "Order Quantity", '
            || 'ORDERED_AMOUNT "Order Amount", '
            || 'CURRENCY_CODE "Currency", '
            || 'ORDER_SOURCE "Order Source", '
            || 'ORDER_LINE_STATUS "Order Line Status", '
            || 'DELIVERY_STATUS "Order Delivery Status", '
            || 'CUSTOM_LINE_STATUS "Order Custom Line Status", '
            || 'RESULT "Result", '
            || 'PROCESS_FLAG "Process Flag", '
            || 'BACK_ORDERED "Back Ordered" '
            || 'FROM XXDOEC_WAREHOUSE_AGING_RPT_V  '
            || 'WHERE 1 = 1'
            || l_where_string
            || 'ORDER BY  OPERATING_UNIT,ORDER_AGE DESC ';
        fnd_file.put_line (fnd_file.LOG, l_query_string);
        owa_sylk_apps.show (p_query => l_query_string);
    EXCEPTION
        WHEN OTHERS
        THEN
            errbuf    := SQLERRM;
            retcode   := 2;
            fnd_file.put_line (
                fnd_file.LOG,
                '**************ERROR OCCURRED at Sylk************');
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
    END;

    --*********************************************************************
    PROCEDURE run_atp_report (errbuf         OUT VARCHAR2,
                              retcode        OUT VARCHAR2,
                              p_brand            VARCHAR2,
                              p_sku_filter       VARCHAR2 DEFAULT NULL,
                              p_inv_org          NUMBER)
    IS
        l_query_string   VARCHAR2 (4000);
        l_where_string   VARCHAR2 (2000);
    BEGIN
        IF p_inv_org IS NOT NULL
        THEN
            l_where_string   := ' AND inv_org_id = ' || p_inv_org;
        ELSE
            l_where_string   :=
                ' AND inv_org_id IN (SELECT DISTINCT inv_org_id FROM xxdoec_country_brand_params) ';
        END IF;

        IF p_brand IS NOT NULL
        THEN
            l_where_string   :=
                l_where_string || ' AND brand =  ' || '''' || p_brand || '''';
        END IF;

        IF p_sku_filter IS NOT NULL
        THEN
            l_where_string   :=
                   l_where_string
                || ' AND SKU like '
                || '''%'
                || UPPER (p_sku_filter)
                || '%''';
        END IF;

        l_query_string   :=
               'SELECT operating_unit "Operating Unit", '
            ---- Added  by Saritha Movva on 08/05/11 for Phase3 Report Changes
            || 'organization_name "Inventory Organization Name", '
            || 'brand "Brand", '
            || ' XXDOEC_ECOMM_REPORT_UTIL.remove_special_characters(model_name) "Model Name", '
            || 'sku "SKU", '
            || 'atp_qty "ATP", '
            || 'open_orders_qty "Open Orders" '
            || 'FROM APPS.XXDOEC_ATP_RPT_V '
            || 'WHERE 1 = 1'
            || l_where_string
            || ' ORDER BY organization_name,brand,sku ';
        fnd_file.put_line (fnd_file.LOG, l_query_string);
        owa_sylk_apps.show (p_query => l_query_string);
    EXCEPTION
        WHEN OTHERS
        THEN
            errbuf    := SQLERRM;
            retcode   := 2;
            fnd_file.put_line (
                fnd_file.LOG,
                '**************ERROR OCCURRED at Sylk************');
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
    END;

    --*********************************************************************
    FUNCTION remove_special_characters (p_in_string VARCHAR2)
        RETURN VARCHAR2
    IS
        v_out_string   VARCHAR2 (1024);
        v_length       NUMBER;
        v_dec          NUMBER;
        v_char         VARCHAR2 (1);
    BEGIN
        v_out_string   := SUBSTR (p_in_string, 1, 1024);
        v_length       := LENGTH (v_out_string);

        IF v_length > 0
        THEN
            FOR i IN 1 .. v_length
            LOOP
                v_char   := SUBSTR (v_out_string, i, 1);
                v_dec    := ASCII (v_char);

                IF (   (v_dec BETWEEN 0 AND 31)
                    OR v_dec IN (35, 47, 127,
                                 126, 124, 94,
                                 96))
                THEN
                    v_out_string   := REPLACE (v_out_string, v_char, ' ');
                END IF;
            END LOOP;
        ELSE
            RETURN NULL;
        END IF;

        v_out_string   :=
            REPLACE (
                REPLACE (
                    REPLACE (REPLACE (v_out_string, '\n', ' '), '\r', ' '),
                    ';',
                    ''),
                '-->',
                '');
        RETURN v_out_string;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    --********************************************************************
    PROCEDURE run_return_report (errbuf            OUT VARCHAR2,
                                 retcode           OUT VARCHAR2,
                                 p_org_id              VARCHAR2,
                                 p_multi_org_ids       VARCHAR2,
                                 p_date_from           VARCHAR2,
                                 p_date_to             VARCHAR2,
                                 p_brand               VARCHAR2,
                                 p_return_status       VARCHAR2)
    IS
        l_date_from      DATE;
        l_date_to        DATE;
        l_query_string   VARCHAR2 (4000);
        l_where_string   VARCHAR2 (2000);
    BEGIN
        l_date_from   := fnd_date.canonical_to_date (p_date_from);
        l_date_to     := fnd_date.canonical_to_date (p_date_to);

        BEGIN
            IF p_org_id IS NOT NULL
            THEN
                l_where_string   := ' AND org_id = ' || p_org_id;
            ELSIF p_multi_org_ids IS NOT NULL
            THEN
                l_where_string   :=
                    ' AND org_id IN (' || p_multi_org_ids || ')';
            ELSE
                l_where_string   :=
                    ' AND org_id IN (SELECT DISTINCT erp_org_id FROM xxdoec_country_brand_params) ';
            END IF;

            IF p_brand IS NOT NULL
            THEN
                l_where_string   :=
                       l_where_string
                    || ' AND brand =  '
                    || ''''
                    || p_brand
                    || '''';
            END IF;

            l_where_string   :=
                   l_where_string
                || ' AND RETURNED_DATE BETWEEN  to_date('
                || ''''
                || l_date_from
                || ' 00:00:00'
                || ''''
                || ','
                || ''''
                || 'DD-MON-RR HH24:MI:SS'
                || ''''
                || ')  AND '
                || ' to_date('
                || ''''
                || l_date_to
                || ' 23:59:59'
                || ''''
                || ','
                || ''''
                || 'DD-MON-RR HH24:MI:SS'
                || ''''
                || ')';
            l_where_string   :=
                   l_where_string
                || ' AND nvl(return_line_status,''NULL'') =  '
                || 'nvl('''
                || p_return_status
                || ''', nvl(return_line_status,''NULL'')) ';
            l_query_string   :=
                   'SELECT OPERATING_UNIT "Operating Unit", '
                || 'SITE "Website ID", '
                || 'RETURN_ORACLE_ORDER "Return Oracle Order#", '
                || 'ORIG_ORACLE_ORDER "Orig Oracle Order#", '
                || 'RETURNED_DATE "Returned Date", '
                || 'ORIG_ORDERED_DATE "Orig Ordered Date", '
                || 'CUSTOMER_NUMBER "Cutomer Number", '
                || 'XXDOEC_ECOMM_REPORT_UTIL.remove_special_characters '
                || '(CUSTOMER_NAME) '
                || ' "Customer Name", '
                || 'CUSTOMER_TYPE "Customer Type", '
                -- Added  by Saritha Movva on 08/01/11 for Phase3 report Changes
                || 'ORDER_TYPE "Order Type", '
                || 'RETURN_WEB_ORDER "Return Web Order#", '
                || 'ORIG_WEB_ORDER "Orig Web Order#", '
                || 'ORG_SOURCE "Orig Source", '
                || 'RETURN_SOURCE "Return Source", '
                || 'RETURN_REASON "Return Reason", '
                || 'LINE_STATUS "Line Status", '
                || 'CUSTOM_LINE_STATUS "Custom Line Status", '
                || 'BRAND "Brand", '
                || 'ORDERED_ITEM "Item", '
                || 'ORDER_LINE_AMOUNT "Order Line Amount", '
                || '(LINE_AMOUNT+TAX_AMOUNT) "Invoice Amount", '
                || 'LINE_AMOUNT "Line Amount", '
                || 'TAX_AMOUNT "Tax Amount", '
                || 'INVOICE_NUMBER "Invoice Number", '
                || 'INVOICE_DATE "Invoice Date", '
                || 'EMAIL_ADDRESS "Email Addess", '
                || 'XXDOEC_ECOMM_REPORT_UTIL.remove_special_characters '
                || '(ADDRESS1) '
                || ' "Ship To Address1", '
                || 'XXDOEC_ECOMM_REPORT_UTIL.remove_special_characters '
                || '(ADDRESS2) '
                || ' "Ship To Address2", '
                || 'XXDOEC_ECOMM_REPORT_UTIL.remove_special_characters '
                || '(CITY) '
                || ' "Ship to City", '
                || 'XXDOEC_ECOMM_REPORT_UTIL.remove_special_characters '
                || '(STATE) '
                || ' "Ship to State", '
                || 'POSTAL_CODE "Ship to Postal Code", '
                || 'COUNTRY "Country", '
                || 'WEB_USER   "Web User" '
                ||                                 ---- Added By Amitava Ghosh
                   'FROM XXDOEC_RETURN_ORDERS_RPT_V  '
                || 'WHERE 1 = 1'
                || l_where_string
                || 'ORDER BY OPERATING_UNIT,RETURN_ORACLE_ORDER ';
            fnd_file.put_line (fnd_file.LOG, l_query_string);
            owa_sylk_apps.show (p_query => l_query_string);
            NULL;
        EXCEPTION
            WHEN OTHERS
            THEN
                errbuf    := SQLERRM;
                retcode   := 2;
                fnd_file.put_line (
                    fnd_file.LOG,
                    '**************ERROR OCCURRED at Sylk************');
                fnd_file.put_line (fnd_file.LOG, SQLERRM);
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            errbuf    := SQLERRM;
            retcode   := 2;
            fnd_file.put_line (
                fnd_file.LOG,
                '**************ERROR OCCURRED general************');
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
    END;

    --*****************************************************************
    PROCEDURE fillrate (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_brand VARCHAR2, p_year NUMBER, p_org_id NUMBER, p_multi_org_ids VARCHAR2
                        , p_site_id VARCHAR2)
    IS
        l_query_string   VARCHAR2 (4000);
        l_where_string   VARCHAR2 (2000);
    BEGIN
        BEGIN
            IF p_org_id IS NOT NULL
            THEN
                l_where_string   := ' AND org_id = ' || p_org_id;
            ELSIF p_multi_org_ids IS NOT NULL
            THEN
                l_where_string   :=
                    ' AND org_id IN (' || p_multi_org_ids || ')';
            ELSE
                l_where_string   :=
                    ' AND org_id IN (SELECT DISTINCT erp_org_id FROM xxdoec_country_brand_params) ';
            END IF;

            IF p_site_id IS NOT NULL
            THEN
                l_where_string   :=
                       l_where_string
                    || ' AND site =  '
                    || ''''
                    || p_site_id
                    || '''';
            END IF;

            l_where_string   :=
                   l_where_string
                || ' AND ordered_date BETWEEN to_date('
                || ''''
                || '01-JAN-'
                || p_year
                || ''''
                || ') AND to_date('
                || ''''
                || '31-DEC-'
                || p_year
                || ''''
                || ') AND brand =  '
                || ''''
                || p_brand
                || '''';
            l_query_string   :=
                   'SELECT site "Website ID", '
                || 'ordered_week "Week Number", '
                || 'ordered_week_start "Week Start Date", '
                || 'ordered_week_end "Week End Date", '
                || 'ROUND(sum(case when ordered_week = nvl(shipped_week,ordered_week) then NVL(shipped_quantity,0) else 0 end)*100/sum(ordered_quantity+cancelled_quantity),2)|| '
                || '''%'''
                || '  "Initial Fill Rate", '
                || 'ROUND(sum(NVL(shipped_quantity,0)) *100/sum(ordered_quantity+cancelled_quantity),2)|| '
                || '''%'''
                || '  "Final Fill Rate", '
                || 'ROUND(sum(NVL(cancelled_quantity,0)) *100/sum(ordered_quantity+cancelled_quantity),2)|| '
                || '''%'''
                || '  "Cancel Rate", '
                || 'ROUND(SUM(CASE WHEN cancel_reason = '
                || '''SCH'''
                || ' THEN NVL(cancelled_quantity,0) else 0 end) *100 / SUM(ordered_quantity+cancelled_quantity),2)|| '
                || '''%'''
                || '   " SCH Cancel Rate", '
                || 'ROUND(SUM(CASE WHEN cancel_reason = '
                || '''FRC'''
                || ' THEN NVL(cancelled_quantity,0) else 0 end) *100 / SUM(ordered_quantity+cancelled_quantity),2)|| '
                || '''%'''
                || '  "FRC Cancel Rate", '
                || 'ROUND(SUM(CASE WHEN cancel_reason = '
                || '''PGA'''
                || ' THEN NVL(cancelled_quantity,0) else 0 end) *100 / SUM(ordered_quantity+cancelled_quantity),2)|| '
                || '''%'''
                || '  "PGA Cancel Rate", '
                || 'ROUND(SUM(CASE WHEN cancel_reason NOT IN ('
                || '''SCH'''
                || ', '
                || '''FRC'''
                || ', '
                || '''PGA'''
                || ') THEN NVL(cancelled_quantity,0) else 0 end) *100 / SUM(ordered_quantity+cancelled_quantity),2)|| '
                || '''%'''
                || '  "Other Cancel Rate", '
                || 'SUM(ordered_quantity+cancelled_quantity) "Total Qty", '
                || 'sum(case when ordered_week = nvl(shipped_week,ordered_week) then NVL(shipped_quantity,0) else 0 end) "Initial Fill Qty", '
                || 'sum(NVL(shipped_quantity,0)) "Final Fill Qty", '
                || 'sum(NVL(cancelled_quantity,0)) "Cancel Qty", '
                || 'SUM(CASE WHEN cancel_reason =  '
                || '''SCH'''
                || '  THEN NVL(cancelled_quantity,0) else 0 end)   " SCH Cancel Qty", '
                || 'SUM(CASE WHEN cancel_reason = '
                || '''FRC'''
                || ' THEN NVL(cancelled_quantity,0) else 0 end)   "FRC Cancel Qty", '
                || ' SUM(CASE WHEN cancel_reason ='
                || '''PGA'''
                || ' THEN NVL(cancelled_quantity,0) else 0 end)  "PGA Cancel Qty", '
                || 'SUM(CASE WHEN cancel_reason NOT IN ('
                || '''SCH'''
                || ', '
                || '''FRC'''
                || ', '
                || '''PGA'''
                || ')  THEN NVL(cancelled_quantity,0) else 0 end)  "Other Cancel Qty" '
                || 'FROM XXDOEC_FILLRATE_RPT_V '
                || 'WHERE 1 = 1'
                || l_where_string
                || ' GROUP BY site, ordered_week, '
                || 'ordered_week_start, '
                || 'ordered_week_end '
                || 'ORDER BY ordered_week_start ';
            fnd_file.put_line (fnd_file.LOG, l_query_string);
            owa_sylk_apps.show (p_query => l_query_string);
        EXCEPTION
            WHEN OTHERS
            THEN
                errbuf    := SQLERRM;
                retcode   := 2;
                fnd_file.put_line (
                    fnd_file.LOG,
                    '**************ERROR OCCURRED at Sylk************');
                fnd_file.put_line (fnd_file.LOG, SQLERRM);
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            errbuf    := SQLERRM;
            retcode   := 2;
            fnd_file.put_line (
                fnd_file.LOG,
                '**************ERROR OCCURRED general************');
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
    END;

    --*********************************************************************
    PROCEDURE credit_memo (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_date_from VARCHAR2, p_date_to VARCHAR2, p_org_id NUMBER, p_multi_org_ids VARCHAR2
                           , p_brand VARCHAR2)
    IS
        l_date_from      DATE;
        l_date_to        DATE;
        l_query_string   VARCHAR2 (4000);
        l_where_string   VARCHAR2 (2000);
    BEGIN
        l_date_from   := fnd_date.canonical_to_date (p_date_from);
        l_date_to     := fnd_date.canonical_to_date (p_date_to);

        BEGIN
            IF p_org_id IS NOT NULL
            THEN
                l_where_string   := ' AND org_id = ' || p_org_id;
            ELSIF p_multi_org_ids IS NOT NULL
            THEN
                l_where_string   :=
                    ' AND org_id IN (' || p_multi_org_ids || ')';
            ELSE
                l_where_string   :=
                    ' AND org_id IN (SELECT DISTINCT erp_org_id FROM xxdoec_country_brand_params) ';
            END IF;

            IF p_brand IS NOT NULL
            THEN
                l_where_string   :=
                       l_where_string
                    || ' AND brand =  '
                    || ''''
                    || p_brand
                    || '''';
            END IF;

            l_where_string   :=
                   l_where_string
                || ' AND cm_date BETWEEN  to_date('
                || ''''
                || l_date_from
                || ' 00:00:00'
                || ''''
                || ','
                || ''''
                || 'DD-MON-RR HH24:MI:SS'
                || ''''
                || ')  AND '
                || ' to_date('
                || ''''
                || l_date_to
                || ' 23:59:59'
                || ''''
                || ','
                || ''''
                || 'DD-MON-RR HH24:MI:SS'
                || ''''
                || ')';
            l_query_string   :=
                   'SELECT  operating_unit "Operating Unit", '
                || 'SITE "Website ID", '
                || 'source "Source", '
                || 'cm_date "CM Date", '
                || 'cm_number "CM Number", '
                || '(line_amount + tax_amount) "Amount", '
                || 'reason_code "Reason Code", '
                || 'comments "Comments", '
                || 'customer_number "Cutomer Number", '
                || 'XXDOEC_ECOMM_REPORT_UTIL.remove_special_characters '
                || '(customer_name) '
                || ' "Customer Name", '
                || 'brand "Brand", '
                || 'order_number "Oracle Order Number", '
                || 'cust_po_number "PO Number", '
                || 'create_user "Create User", '
                || 'update_user "Update User" '
                || 'FROM XXDOEC_CEDIT_MEMO_RPT_V '
                || 'WHERE 1 = 1'
                || l_where_string
                || ' ORDER BY Operating_unit,source,cm_date ';
            fnd_file.put_line (fnd_file.LOG, l_query_string);
            owa_sylk_apps.show (p_query => l_query_string);
        EXCEPTION
            WHEN OTHERS
            THEN
                errbuf    := SQLERRM;
                retcode   := 2;
                fnd_file.put_line (
                    fnd_file.LOG,
                    '**************ERROR OCCURRED at Sylk************');
                fnd_file.put_line (fnd_file.LOG, SQLERRM);
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            errbuf    := SQLERRM;
            retcode   := 2;
            fnd_file.put_line (
                fnd_file.LOG,
                '**************ERROR OCCURRED general************');
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
    END;

    --*********************************************************************
    PROCEDURE orders_booking (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id NUMBER, p_multi_org_ids VARCHAR2, p_site_id VARCHAR2, p_brand VARCHAR2, p_start_date VARCHAR2, p_end_date VARCHAR2, p_show_by VARCHAR2
                              , p_ignore_cancel_lines VARCHAR2 -- Added  by Saritha Movva on 07/18/11 for Phase3 Report Changes
                                                              )
    IS
        l_date_from      DATE;
        l_date_to        DATE;
        l_show_by        VARCHAR2 (50);
        l_show_by_name   VARCHAR2 (400);
        l_query_string   VARCHAR2 (4000);
        l_where_string   VARCHAR2 (2000);
    BEGIN
        l_date_from   := fnd_date.canonical_to_date (p_start_date);
        l_date_to     := fnd_date.canonical_to_date (p_end_date);

        BEGIN
            IF p_org_id IS NOT NULL
            THEN
                l_where_string   := ' AND org_id = ' || p_org_id;
            ELSIF p_multi_org_ids IS NOT NULL
            THEN
                l_where_string   :=
                    ' AND org_id IN (' || p_multi_org_ids || ')';
            ELSE
                l_where_string   :=
                    ' AND org_id IN (SELECT DISTINCT erp_org_id FROM xxdoec_country_brand_params) ';
            END IF;

            IF p_site_id IS NOT NULL
            THEN
                l_where_string   :=
                       l_where_string
                    || ' AND site =  '
                    || ''''
                    || p_site_id
                    || '''';
            END IF;

            l_where_string   :=
                   l_where_string
                || ' AND ordered_date BETWEEN  to_date('
                || ''''
                || l_date_from
                || ' 00:00:00'
                || ''''
                || ','
                || ''''
                || 'DD-MON-RR HH24:MI:SS'
                || ''''
                || ')  AND '
                || ' to_date('
                || ''''
                || l_date_to
                || ' 23:59:59'
                || ''''
                || ','
                || ''''
                || 'DD-MON-RR HH24:MI:SS'
                || ''''
                || ')';
            l_where_string   :=
                l_where_string || ' AND brand =  ' || '''' || p_brand || '''';

            -- Added  by Saritha Movva on 07/18/11 for Phase3 Report Changes
            IF p_ignore_cancel_lines = 'Y'
            THEN
                l_where_string   :=
                       l_where_string
                    || ' AND nvl(cancelled_flag,''N'') =  ''N''';
            END IF;

            IF p_show_by = 'M'
            THEN
                l_show_by        := 'model';
                l_show_by_name   := 'Model';
            ELSIF p_show_by = 'MC'
            THEN
                l_show_by        := 'model||  ''-''  ||color';
                l_show_by_name   := 'Model / Color';
            ELSE
                l_show_by        := 'model||  ''-''  ||color||  ''-''  ||size_no';
                l_show_by_name   := 'Model / Color / Size';
            END IF;

            l_query_string   :=
                   'SELECT  operating_unit "Operating Unit", '
                || 'SITE "Website ID", '
                || l_show_by
                || '"'
                || l_show_by_name
                || '"'
                || ',description "Description", '
                || 'unit_selling_price "Unit Price Including Tax", '
                -- Added  by Saritha Movva on 07/18/11 for Phase3 Report Changes START.
                || 'unit_selling_price - nvl(tax_amount,0) "Unit Price Excluding Tax", '
                || 'sum(ordered_quantity) "Qty Sold", '
                || 'sum(unit_selling_price * ordered_quantity) "Total Including Tax", '
                || 'sum((unit_selling_price - nvl(tax_amount,0)) * ordered_quantity) "Total Excluding Tax" '
                -- Added  by Saritha Movva on 07/18/11 for Phase3 Report Changes END.
                /*||'unit_selling_price "Unit Price", '
                                                                                                                                                                                                         ||'sum(ordered_quantity) "Qty Sold", '
                                                                                                                                                                                                         ||'sum(unit_selling_price * ordered_quantity) "Total (qty * price)" ' */
                -- Commented by Saritha Movva on 07/18/11 for Phase3 Report Changes .
                || 'FROM XXDOEC_ORDERS_BOOKING_RPT_V '
                || 'WHERE 1 = 1'
                || l_where_string
                || ' GROUP BY tax_amount,description,site,unit_selling_price,operating_unit, '
                || l_show_by
                || ' ORDER BY operating_unit,site, '
                || l_show_by;
            fnd_file.put_line (fnd_file.LOG, l_query_string);
            owa_sylk_apps.show (p_query => l_query_string);
        EXCEPTION
            WHEN OTHERS
            THEN
                errbuf    := SQLERRM;
                retcode   := 2;
                fnd_file.put_line (
                    fnd_file.LOG,
                    '**************ERROR OCCURRED at Sylk************');
                fnd_file.put_line (fnd_file.LOG, SQLERRM);
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            errbuf    := SQLERRM;
            retcode   := 2;
            fnd_file.put_line (
                fnd_file.LOG,
                '**************ERROR OCCURRED general************');
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
    END;

    --*********************************************************************
    PROCEDURE order_summary (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id NUMBER, p_multi_org_ids VARCHAR2, p_start_date VARCHAR2, p_end_date VARCHAR2, p_brand VARCHAR2, p_invoice_start_date VARCHAR2, --Added by Saritha Movva on 07/21/11 for Phase3 Changes
                                                                                                                                                                                                                p_invoice_end_date VARCHAR2, p_state VARCHAR2, p_country VARCHAR2, p_inv_org_id NUMBER
                             , p_model VARCHAR2, p_back_ordered VARCHAR2)
    IS
        l_date_from       DATE;
        l_date_to         DATE;
        l_query_string    VARCHAR2 (4000);
        l_where_string    VARCHAR2 (4000);
        l_inv_date_from   DATE;    --Added by Saritha Movva for Phase3 Changes
        l_inv_date_to     DATE;
    BEGIN
        l_date_from       := fnd_date.canonical_to_date (p_start_date);
        l_date_to         := fnd_date.canonical_to_date (p_end_date);
        l_inv_date_from   :=
            fnd_date.canonical_to_date (p_invoice_start_date);
        --Added by Saritha Movva for Phase3 Changes
        l_inv_date_to     := fnd_date.canonical_to_date (p_invoice_end_date);

        BEGIN
            IF p_org_id IS NOT NULL
            THEN
                l_where_string   := ' AND org_id = ' || p_org_id;
            ELSIF p_multi_org_ids IS NOT NULL
            THEN
                l_where_string   :=
                    ' AND org_id IN (' || p_multi_org_ids || ')';
            ELSE
                l_where_string   :=
                    ' AND org_id IN (SELECT DISTINCT erp_org_id FROM xxdoec_country_brand_params) ';
            END IF;

            IF p_brand IS NOT NULL
            THEN
                l_where_string   :=
                       l_where_string
                    || ' AND brand =  '
                    || ''''
                    || p_brand
                    || '''';
            END IF;

            --Added by Saritha Movva for Phase3 Changes
            IF     p_invoice_start_date IS NOT NULL
               AND p_invoice_end_date IS NOT NULL
            THEN
                l_where_string   :=
                       l_where_string
                    || ' AND invoice_date BETWEEN  to_date('
                    || ''''
                    || l_inv_date_from
                    || ' 00:00:00'
                    || ''''
                    || ','
                    || ''''
                    || 'DD-MON-RR HH24:MI:SS'
                    || ''''
                    || ')  AND '
                    || ' to_date('
                    || ''''
                    || l_inv_date_to
                    || ' 23:59:59'
                    || ''''
                    || ','
                    || ''''
                    || 'DD-MON-RR HH24:MI:SS'
                    || ''''
                    || ')';
            END IF;

            IF p_state IS NOT NULL
            THEN
                l_where_string   :=
                       l_where_string
                    || ' AND upper(state) like '
                    || '''%'
                    || UPPER (p_state)
                    || '%''';
            END IF;

            IF p_country IS NOT NULL
            THEN
                l_where_string   :=
                       l_where_string
                    || ' AND country =  '
                    || ''''
                    || p_country
                    || '''';
            END IF;

            IF p_inv_org_id IS NOT NULL
            THEN
                l_where_string   :=
                       l_where_string
                    || ' AND ship_from_org_id = '
                    || p_inv_org_id;
            ELSE
                /*Commented by Madhav Dhurjaty for DFCT0010525*/
                -- Start
                /*--l_where_string := l_where_string ||
                --                  ' AND ship_from_org_id IN (SELECT DISTINCT inv_org_id FROM xxdoec_country_brand_params) ';
                */
                /*Commented by Madhav Dhurjaty for DFCT0010525*/
                -- End
                NULL;              -- Added by Madhav Dhurjaty for DFCT0010525
            END IF;

            IF p_model IS NOT NULL
            THEN
                l_where_string   :=
                       l_where_string
                    || ' AND model like '
                    || '''%'
                    || UPPER (p_model)
                    || '%''';
            END IF;

            IF p_back_ordered IS NOT NULL
            THEN
                l_where_string   :=
                       l_where_string
                    || ' AND back_ordered =  '
                    || ''''
                    || p_back_ordered
                    || '''';
            END IF;

            -- l_where_string:= l_where_string || ' AND ordered_date BETWEEN  '|| '''' || l_start_date  ||''''|| ' AND ' || '''' || l_end_date ||'''';

            --l_where_string:= l_where_string || ' AND ordered_date BETWEEN  to_date('|| '''' || p_start_date  ||''''|| ','||''''||'YYYY/MM/DD HH24:MI:SS'||''''||')  AND ' ||' to_date('|| ''''|| p_end_date ||'''' || ','||''''||'YYYY/MM/DD HH24:MI:SS'||'''' ||')' ;
            l_where_string   :=
                   l_where_string
                || ' AND ordered_date BETWEEN  to_date('
                || ''''
                || l_date_from
                || ' 00:00:00'
                || ''''
                || ','
                || ''''
                || 'DD-MON-RR HH24:MI:SS'
                || ''''
                || ')  AND '
                || ' to_date('
                || ''''
                || l_date_to
                || ' 23:59:59'
                || ''''
                || ','
                || ''''
                || 'DD-MON-RR HH24:MI:SS'
                || ''''
                || ')';
            l_query_string   :=
                   'SELECT OPERATING_UNIT "Operating Unit", '
                || 'SITE "Website ID", '
                || 'ORACLE_ORDER_NUMBER "Oracle Order Number", '
                || 'WEB_ORDER_NUMBER "Web Order Number", '
                || 'ORDERED_DATE "Ordered Date", '
                || 'CUSTOMER_NUMBER "Customer Number", '
                || 'XXDOEC_ECOMM_REPORT_UTIL.remove_special_characters '
                || '(CUSTOMER_NAME) '
                || ' "Customer Name", '
                || 'EMAIL_ADDRESS "Email Address", '
                || 'XXDOEC_ECOMM_REPORT_UTIL.remove_special_characters '
                || '(SHIP_TO_ADDRESS1) '
                || ' "Ship to Address1", '
                --Added by Saritha Movva for Phase3 Changes
                || 'XXDOEC_ECOMM_REPORT_UTIL.remove_special_characters '
                || '(SHIP_TO_ADDRESS2) '
                || '  "Ship to Address2", '
                || 'XXDOEC_ECOMM_REPORT_UTIL.remove_special_characters '
                || '(CITY) '
                || '  " Ship to City", '
                || 'XXDOEC_ECOMM_REPORT_UTIL.remove_special_characters '
                || '(STATE) '
                || '  " Ship to State", '
                || 'XXDOEC_ECOMM_REPORT_UTIL.remove_special_characters '
                || '(POSTAL_CODE) '
                || '  " Ship to Postal Code", '
                || 'XXDOEC_ECOMM_REPORT_UTIL.remove_special_characters '
                || '(COUNTRY) '
                || '  " Ship to Country", '
                || 'XXDOEC_ECOMM_REPORT_UTIL.remove_special_characters '
                || '(BILL_TO_ADDRESS1) '
                || '  "Bill to Address1", '
                || 'XXDOEC_ECOMM_REPORT_UTIL.remove_special_characters '
                || '(BILL_TO_ADDRESS2) '
                || '  "Bill to Address2", '
                || 'XXDOEC_ECOMM_REPORT_UTIL.remove_special_characters '
                || '(BILL_CITY) '
                || '  "Bill to City", '
                || 'XXDOEC_ECOMM_REPORT_UTIL.remove_special_characters '
                || '(BILL_STATE) '
                || '  "Bill to State", '
                || 'XXDOEC_ECOMM_REPORT_UTIL.remove_special_characters '
                || '(BILL_POSTAL_CODE) '
                || '  "Bill to Postal Code", '
                || 'XXDOEC_ECOMM_REPORT_UTIL.remove_special_characters '
                || '(BILL_COUNTRY) '
                || '  "Bill to Country", '
                || 'TIME_PLACED "Time Placed", '
                || 'BRAND "Brand", '
                || 'XXDOEC_ECOMM_REPORT_UTIL.remove_special_characters '
                || '(ORDERED_ITEM) '
                || '  "Ordered Item", '
                || 'XXDOEC_ECOMM_REPORT_UTIL.remove_special_characters '
                || '(ITEM_DESCRIPTION) '
                || '  "Item Description", '
                || 'MODEL "Model", '
                || 'COLOR "Color", '
                || 'SIZE_NO "Size", '
                || 'ORDERED_QUANTITY "Order Quantity", '
                || 'UNIT_SELLING_PRICE "Item Selling Price", '
                || 'LINE_AMOUNT "Order Amount", '
                || '(INVOICE_LINE_TOTAL + INVOICE_TAX_AMOUNT) "Invoice Amount", '
                || 'FREIGHT_CHARGE + FREIGHT_DISCOUNT "Freight Amount", '
                || 'SALES_TAX_AMOUNT "Sales Tax Amount", '
                || 'UNIT_COST "Deckers Cost", '
                || 'ORDER_LINE_STATUS "Order Line Status", '
                || 'DELIVERY_STATUS "Order Delivery Status", '
                || 'CUSTOM_LINE_STATUS "Order Custom Line Status", '
                || 'PROCESS_FLAG "Process Flag", '
                --Added by Saritha Movva 12/26/11
                || 'RESULT "Result", '
                || 'CANCEL_REASON "Cancel Reason", '
                || 'INVOICE_NUMBER "Invoice Number", '
                --Added by Saritha Movva for Phase3 Changes
                || 'INVOICE_DATE "Invoice Date", '
                || 'BACK_ORDERED "Back Ordered", '
                || 'SHIP_FROM_ORG_ID "Inventory Org ID", '
                || 'ORDER_AGE "Order Age", '
                || 'ORDER_FULLFILL_TIME "Order Fullfill Time", '
                || 'TRACKING_NUMBER "Tracking Number", '
                || 'SHIPPING_METHOD_CODE "Ship Method Code",'
                || 'LATEST_ACCEPTABLE_DATE "Latest Acceptable Date",'
                || 'SCHEDULE_SHIP_DATE "Schedule Ship Date",'
                || 'CANCEL_DATE "Cancel Date",'
                || 'CANCELLED_BY "Cancelled By", '
                || 'STORE_NUMBER "Store Number" '
                || 'FROM XXDOEC_ORDER_SUMMARY_RPT_V  '
                || 'WHERE 1 = 1'
                || l_where_string
                || ' ORDER BY OPERATING_UNIT, ORACLE_ORDER_NUMBER ';
            fnd_file.put_line (fnd_file.LOG, l_query_string);
            owa_sylk_apps.show (p_query => l_query_string);
        EXCEPTION
            WHEN OTHERS
            THEN
                errbuf    := SQLERRM;
                retcode   := 2;
                fnd_file.put_line (
                    fnd_file.LOG,
                    '**************ERROR OCCURRED at Sylk************');
                fnd_file.put_line (fnd_file.LOG, SQLERRM);
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            errbuf    := SQLERRM;
            retcode   := 2;
            fnd_file.put_line (
                fnd_file.LOG,
                '**************ERROR OCCURRED general************');
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
    END;

    --*********************************************************************
    PROCEDURE shipped_not_invoiced (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id NUMBER, p_multi_org_ids VARCHAR2, p_start_date VARCHAR2, p_end_date VARCHAR2
                                    , p_brand VARCHAR2)
    IS
        l_date_from      DATE;
        l_date_to        DATE;
        l_query_string   VARCHAR2 (4000);
        l_where_string   VARCHAR2 (2000);
    BEGIN
        l_date_from   := fnd_date.canonical_to_date (p_start_date);
        l_date_to     := fnd_date.canonical_to_date (p_end_date);

        BEGIN
            IF p_org_id IS NOT NULL
            THEN
                l_where_string   := ' AND org_id = ' || p_org_id;
            ELSIF p_multi_org_ids IS NOT NULL
            THEN
                l_where_string   :=
                    ' AND org_id IN (' || p_multi_org_ids || ')';
            ELSE
                l_where_string   :=
                    ' AND org_id IN (SELECT DISTINCT erp_org_id FROM xxdoec_country_brand_params) ';
            END IF;

            IF p_brand IS NOT NULL
            THEN
                l_where_string   :=
                       l_where_string
                    || ' AND brand =  '
                    || ''''
                    || p_brand
                    || '''';
            END IF;

            l_where_string   :=
                   l_where_string
                || ' AND ordered_date BETWEEN  to_date('
                || ''''
                || l_date_from
                || ' 00:00:00'
                || ''''
                || ','
                || ''''
                || 'DD-MON-RR HH24:MI:SS'
                || ''''
                || ')  AND '
                || ' to_date('
                || ''''
                || l_date_to
                || ' 23:59:59'
                || ''''
                || ','
                || ''''
                || 'DD-MON-RR HH24:MI:SS'
                || ''''
                || ')';
            l_query_string   :=
                   'SELECT OPERATING_UNIT "Operating Unit", '
                || 'SITE "Website ID", '
                || 'ORACLE_ORDER_NUMBER "Oracle Order Number", '
                || 'WEB_ORDER_NUMBER "Web Order Number", '
                || 'ORDERED_DATE "Ordered Date", '
                || 'CUSTOMER_NUMBER "Cutomer Number", '
                || 'XXDOEC_ECOMM_REPORT_UTIL.remove_special_characters '
                || '(CUSTOMER_NAME) '
                || ' "Customer Name", '
                || 'SHIPED_DATE "Ship Date", '
                || 'BRAND "Brand", '
                || 'ordered_item "ordered_item", '
                || 'DESCRIPTION "Description", '
                || 'ORDERED_QUANTITY "Ordered Quantity", '
                || 'LINE_AMOUNT "Ordered Amount", '
                || 'ORDER_LINE_STATUS "Order Line Status" '
                || 'FROM XXDOEC_SHIPPED_NOT_INV_RPT_V  '
                || 'WHERE 1 = 1'
                || l_where_string
                || 'ORDER BY OPERATING_UNIT,ORACLE_ORDER_NUMBER ';
            fnd_file.put_line (fnd_file.LOG, l_query_string);
            owa_sylk_apps.show (p_query => l_query_string);
        EXCEPTION
            WHEN OTHERS
            THEN
                errbuf    := SQLERRM;
                retcode   := 2;
                fnd_file.put_line (
                    fnd_file.LOG,
                    '**************ERROR OCCURRED at Sylk************');
                fnd_file.put_line (fnd_file.LOG, SQLERRM);
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            errbuf    := SQLERRM;
            retcode   := 2;
            fnd_file.put_line (
                fnd_file.LOG,
                '**************ERROR OCCURRED general************');
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
    END;

    -- Added  by Saritha Movva on 07/18/11 for Phase3 Report Changes START
    PROCEDURE giftwrap (errbuf         OUT VARCHAR2,
                        retcode        OUT VARCHAR2,
                        p_org_id           NUMBER,
                        p_brand            VARCHAR2,
                        p_start_date       VARCHAR2,
                        p_end_date         VARCHAR2)
    IS
        l_date_from      DATE;
        l_date_to        DATE;
        l_query_string   VARCHAR2 (4000);
        l_where_string   VARCHAR2 (2000);
    BEGIN
        l_date_from   := fnd_date.canonical_to_date (p_start_date);
        l_date_to     := fnd_date.canonical_to_date (p_end_date);

        BEGIN
            IF p_org_id IS NOT NULL
            THEN
                l_where_string   := ' AND org_id = ' || p_org_id;
            ELSE
                l_where_string   :=
                    ' AND org_id IN (SELECT DISTINCT erp_org_id FROM xxdoec_country_brand_params) ';
            END IF;

            IF p_brand IS NOT NULL
            THEN
                l_where_string   :=
                       l_where_string
                    || ' AND brand =  '
                    || ''''
                    || p_brand
                    || '''';
            END IF;

            l_where_string   :=
                   l_where_string
                || ' AND ordered_date BETWEEN  to_date('
                || ''''
                || l_date_from
                || ' 00:00:00'
                || ''''
                || ','
                || ''''
                || 'DD-MON-RR HH24:MI:SS'
                || ''''
                || ')  AND '
                || ' to_date('
                || ''''
                || l_date_to
                || ' 23:59:59'
                || ''''
                || ','
                || ''''
                || 'DD-MON-RR HH24:MI:SS'
                || ''''
                || ')';
            l_query_string   :=
                   'SELECT OPERATING_UNIT "Operating Unit", '
                || 'SITE "Website ID",'
                || 'BRAND "Brand", '
                || 'ORDERED_DATE "Ordered Date", '
                || 'ORACLE_ORDER_NUMBER "Oracle Order Number", '
                || 'WEB_ORDER_NUMBER "Web Order Number", '
                || 'LINE_NUMBER "Line Number", '
                || 'GIFTWRAP "Gift Wrap", '
                || 'GIFTWRAP_CHARGE "Gift Wrap Charge", '
                || 'GiftWrapType "giftwraptype" ' -- Added By BT Technology Team on 06-JAN-2015
                || 'FROM XXDOEC_GIFTWRAP_RPT_V  '
                || 'WHERE 1 = 1 AND GIFTWRAP = ''Yes'' '
                || l_where_string
                || 'ORDER BY OPERATING_UNIT,ORDERED_DATE ';
            fnd_file.put_line (fnd_file.LOG, l_query_string);
            owa_sylk_apps.show (p_query => l_query_string);
        EXCEPTION
            WHEN OTHERS
            THEN
                errbuf    := SQLERRM;
                retcode   := 2;
                fnd_file.put_line (
                    fnd_file.LOG,
                    '**************ERROR OCCURRED at Sylk************');
                fnd_file.put_line (fnd_file.LOG, SQLERRM);
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            errbuf    := SQLERRM;
            retcode   := 2;
            fnd_file.put_line (
                fnd_file.LOG,
                '**************ERROR OCCURRED general************');
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
    END;

    PROCEDURE back_orders (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id NUMBER, p_multi_org_ids VARCHAR2, p_brand VARCHAR2, p_start_date VARCHAR2
                           , p_end_date VARCHAR2, p_show_by VARCHAR2)
    IS
        l_date_from      DATE;
        l_date_to        DATE;
        l_show_by        VARCHAR2 (50);
        l_show_by_name   VARCHAR2 (400);
        l_query_string   VARCHAR2 (4000);
        l_where_string   VARCHAR2 (2000);
    BEGIN
        l_date_from   := fnd_date.canonical_to_date (p_start_date);
        l_date_to     := fnd_date.canonical_to_date (p_end_date);

        BEGIN
            IF p_org_id IS NOT NULL
            THEN
                l_where_string   := ' AND org_id = ' || p_org_id;
            ELSIF p_multi_org_ids IS NOT NULL
            THEN
                l_where_string   :=
                    ' AND org_id IN (' || p_multi_org_ids || ')';
            ELSE
                l_where_string   :=
                    ' AND org_id IN (SELECT DISTINCT erp_org_id FROM xxdoec_country_brand_params) ';
            END IF;

            l_where_string   :=
                   l_where_string
                || ' AND ordered_date BETWEEN  to_date('
                || ''''
                || l_date_from
                || ' 00:00:00'
                || ''''
                || ','
                || ''''
                || 'DD-MON-RR HH24:MI:SS'
                || ''''
                || ')  AND '
                || ' to_date('
                || ''''
                || l_date_to
                || ' 23:59:59'
                || ''''
                || ','
                || ''''
                || 'DD-MON-RR HH24:MI:SS'
                || ''''
                || ')';
            l_where_string   :=
                l_where_string || ' AND brand =  ' || '''' || p_brand || '''';

            IF p_show_by = 'M'
            THEN
                l_show_by        := 'model';
                l_show_by_name   := 'Model';
            ELSIF p_show_by = 'MC'
            THEN
                l_show_by        := 'model||  ''-''  ||color';
                l_show_by_name   := 'Model / Color';
            ELSE
                l_show_by        := 'model||  ''-''  ||color||  ''-''  ||size_no';
                l_show_by_name   := 'Model / Color / Size';
            END IF;

            l_query_string   :=
                   'SELECT  operating_unit "Operating Unit", '
                || 'SITE "Website ID", '
                || l_show_by
                || '"'
                || l_show_by_name
                || '"'
                || ',description "Description", '
                || 'sum(ordered_quantity) "Qty Sold", '
                || 'sum(unit_selling_price * ordered_quantity) "Total Including Tax", '
                || 'sum((unit_selling_price - nvl(tax_amount,0)) * ordered_quantity) "Total Excluding Tax" '
                || 'FROM XXDOEC_ORDERS_BOOKING_RPT_V '
                || 'WHERE 1 = 1 AND BACK_ORDERED = ''Yes'' '
                || l_where_string
                || ' GROUP BY description,site,operating_unit, '
                || l_show_by
                || ' ORDER BY operating_unit,site, '
                || l_show_by;
            fnd_file.put_line (fnd_file.LOG, l_query_string);
            owa_sylk_apps.show (p_query => l_query_string);
        EXCEPTION
            WHEN OTHERS
            THEN
                errbuf    := SQLERRM;
                retcode   := 2;
                fnd_file.put_line (
                    fnd_file.LOG,
                    '**************ERROR OCCURRED at Sylk************');
                fnd_file.put_line (fnd_file.LOG, SQLERRM);
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            errbuf    := SQLERRM;
            retcode   := 2;
            fnd_file.put_line (
                fnd_file.LOG,
                '**************ERROR OCCURRED general************');
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
    END;

    PROCEDURE cancel_orders (errbuf            OUT VARCHAR2,
                             retcode           OUT VARCHAR2,
                             p_org_id              NUMBER,
                             p_multi_org_ids       VARCHAR2,
                             p_brand               VARCHAR2,
                             p_start_date          VARCHAR2,
                             p_end_date            VARCHAR2,
                             p_show_by             VARCHAR2,
                             p_cancel_reason       VARCHAR2)
    IS
        l_date_from      DATE;
        l_date_to        DATE;
        l_show_by        VARCHAR2 (50);
        l_show_by_name   VARCHAR2 (400);
        l_query_string   VARCHAR2 (4000);
        l_where_string   VARCHAR2 (2000);
    BEGIN
        l_date_from   := fnd_date.canonical_to_date (p_start_date);
        l_date_to     := fnd_date.canonical_to_date (p_end_date);

        BEGIN
            IF p_org_id IS NOT NULL
            THEN
                l_where_string   := ' AND org_id = ' || p_org_id;
            ELSIF p_multi_org_ids IS NOT NULL
            THEN
                l_where_string   :=
                    ' AND org_id IN (' || p_multi_org_ids || ')';
            ELSE
                l_where_string   :=
                    ' AND org_id IN (SELECT DISTINCT erp_org_id FROM xxdoec_country_brand_params) ';
            END IF;

            IF p_cancel_reason IS NOT NULL
            THEN
                l_where_string   :=
                       l_where_string
                    || ' AND cancel_reason_code =  '
                    || ''''
                    || p_cancel_reason
                    || '''';
            END IF;

            l_where_string   :=
                   l_where_string
                || ' AND ordered_date BETWEEN  to_date('
                || ''''
                || l_date_from
                || ' 00:00:00'
                || ''''
                || ','
                || ''''
                || 'DD-MON-RR HH24:MI:SS'
                || ''''
                || ')  AND '
                || ' to_date('
                || ''''
                || l_date_to
                || ' 23:59:59'
                || ''''
                || ','
                || ''''
                || 'DD-MON-RR HH24:MI:SS'
                || ''''
                || ')';
            l_where_string   :=
                l_where_string || ' AND brand =  ' || '''' || p_brand || '''';

            IF p_show_by = 'M'
            THEN
                l_show_by        := 'model';
                l_show_by_name   := 'Model';
            ELSIF p_show_by = 'MC'
            THEN
                l_show_by        := 'model||  ''-''  ||color';
                l_show_by_name   := 'Model / Color';
            ELSE
                l_show_by        := 'model||  ''-''  ||color||  ''-''  ||size_no';
                l_show_by_name   := 'Model / Color / Size';
            END IF;

            l_query_string   :=
                   'SELECT  operating_unit "Operating Unit", '
                || 'SITE "Website ID", '
                || l_show_by
                || '"'
                || l_show_by_name
                || '"'
                || ',description "Description", '
                || 'cancel_reason "Cancel Reason", '
                || 'sum(ordered_quantity) "Qty Sold", '
                || 'sum(unit_selling_price * ordered_quantity) "Total Including Tax", '
                || 'sum((unit_selling_price - nvl(tax_amount,0)) * ordered_quantity) "Total Excluding Tax" '
                || 'FROM XXDOEC_ORDERS_BOOKING_RPT_V '
                || 'WHERE 1 = 1 AND CANCELLED_FLAG =  ''Y'' '
                || l_where_string
                || ' GROUP BY description,cancel_reason,operating_unit,site, '
                || l_show_by
                || ' ORDER BY operating_unit,site, '
                || l_show_by;
            fnd_file.put_line (fnd_file.LOG, l_query_string);
            owa_sylk_apps.show (p_query => l_query_string);
        EXCEPTION
            WHEN OTHERS
            THEN
                errbuf    := SQLERRM;
                retcode   := 2;
                fnd_file.put_line (
                    fnd_file.LOG,
                    '**************ERROR OCCURRED at Sylk************');
                fnd_file.put_line (fnd_file.LOG, SQLERRM);
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            errbuf    := SQLERRM;
            retcode   := 2;
            fnd_file.put_line (
                fnd_file.LOG,
                '**************ERROR OCCURRED general************');
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
    END;

    PROCEDURE outstanding_acc_bal (errbuf OUT VARCHAR2, retcode OUT VARCHAR2)
    IS
        l_query_string   VARCHAR2 (4000);
    BEGIN
        BEGIN
            l_query_string   :=
                   'SELECT  operating_unit "Operating Unit", '
                || 'SITE "Website ID", '
                || 'customer_number "Customer Number", '
                || 'XXDOEC_ECOMM_REPORT_UTIL.remove_special_characters '
                || '(customer_name) '
                || ' "Customer Name", '
                || 'age1 "AGE1 (1 to 30 Days)", '
                || 'age2 "AGE2 (31 to 60 Days)", '
                || 'age3 "AGE3 (61 to 90 Days)", '
                || 'age4 "AGE4 (Above 90 Days)", '
                || 'age_current " Age Current (Today)", '
                || 'age_future "Age Future", '
                || 'amount_due " Amount Due" '
                || 'FROM APPS.XXDOEC_OUTSTAND_ACC_BAL_RPT_V ';
            fnd_file.put_line (fnd_file.LOG, l_query_string);
            owa_sylk_apps.show (p_query => l_query_string);
        EXCEPTION
            WHEN OTHERS
            THEN
                errbuf    := SQLERRM;
                retcode   := 2;
                fnd_file.put_line (
                    fnd_file.LOG,
                    '**************ERROR OCCURRED at Sylk************');
                fnd_file.put_line (fnd_file.LOG, SQLERRM);
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            errbuf    := SQLERRM;
            retcode   := 2;
            fnd_file.put_line (
                fnd_file.LOG,
                '**************ERROR OCCURRED general************');
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
    END;

    PROCEDURE outof_stock (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id NUMBER, p_inv_org NUMBER, p_brand VARCHAR2, p_sku VARCHAR2, p_item_category VARCHAR2, --Added by BT Technology Team on 19-FEB-2015
                                                                                                                                                                     p_atp_qty_min NUMBER, p_atp_qty_max NUMBER, p_atp_start_date VARCHAR2, p_atp_end_date VARCHAR2, p_back_order_qty_min NUMBER, p_back_order_qty_max NUMBER, p_back_order_start_date VARCHAR2, p_back_order_end_date VARCHAR2, p_pre_order_qty_min NUMBER, p_pre_order_qty_max NUMBER, p_pre_order_start_date VARCHAR2
                           , p_pre_order_end_date VARCHAR2, p_consumed_start_date VARCHAR2, p_consumed_end_date VARCHAR2 --      ,
 --      p_kco_qty_min                   NUMBER,                                 --Commented by BT Technology Team on 19-FEB-2015
 --      p_kco_qty_max                   NUMBER                                  --Commented by BT Technology Team on 19-FEB-2015
                           )
    IS
        l_query_string           VARCHAR2 (4000);
        l_where_string           VARCHAR2 (2000);
        l_atp_date_from          DATE;
        l_atp_date_to            DATE;
        l_back_order_date_from   DATE;
        l_back_order_date_to     DATE;
        l_pre_order_date_from    DATE;
        l_pre_order_date_to      DATE;
        l_consumed_date_from     DATE;
        l_consumed_date_to       DATE;
    BEGIN
        l_atp_date_from   := fnd_date.canonical_to_date (p_atp_start_date);
        l_atp_date_to     := fnd_date.canonical_to_date (p_atp_end_date);
        l_back_order_date_from   :=
            fnd_date.canonical_to_date (p_back_order_start_date);
        l_back_order_date_to   :=
            fnd_date.canonical_to_date (p_back_order_end_date);
        l_pre_order_date_from   :=
            fnd_date.canonical_to_date (p_pre_order_start_date);
        l_pre_order_date_to   :=
            fnd_date.canonical_to_date (p_pre_order_end_date);
        l_consumed_date_from   :=
            fnd_date.canonical_to_date (p_consumed_start_date);
        l_consumed_date_to   :=
            fnd_date.canonical_to_date (p_consumed_end_date);

        IF p_org_id IS NOT NULL
        THEN
            l_where_string   := ' AND erp_org_id = ' || p_org_id;
        ELSE
            l_where_string   :=
                ' AND erp_org_id IN (SELECT DISTINCT erp_org_id FROM xxdoec_country_brand_params) ';
        END IF;

        IF p_inv_org IS NOT NULL
        THEN
            l_where_string   :=
                l_where_string || ' AND inv_org_id = ' || p_inv_org;
        ELSE
            l_where_string   :=
                   l_where_string
                || ' AND inv_org_id IN (SELECT DISTINCT inv_org_id FROM xxdoec_country_brand_params) ';
        END IF;

        IF p_brand IS NOT NULL
        THEN
            l_where_string   :=
                l_where_string || ' AND brand =  ' || '''' || p_brand || '''';
        END IF;

        IF p_sku IS NOT NULL
        THEN
            l_where_string   :=
                   l_where_string
                || ' AND SKU like '
                || '''%'
                || UPPER (p_sku)
                || '%''';
        END IF;

        IF p_atp_qty_min IS NOT NULL AND p_atp_qty_max IS NOT NULL
        THEN
            l_where_string   :=
                   l_where_string
                || ' AND atp_qty between '
                || p_atp_qty_min
                || ' AND '
                || p_atp_qty_max;
        END IF;

        IF p_atp_start_date IS NOT NULL AND p_atp_end_date IS NOT NULL
        THEN
            l_where_string   :=
                   l_where_string
                || ' AND atp_date BETWEEN  to_date('
                || ''''
                || l_atp_date_from
                || ' 00:00:00'
                || ''''
                || ','
                || ''''
                || 'DD-MON-RR HH24:MI:SS'
                || ''''
                || ')  AND '
                || ' to_date('
                || ''''
                || l_atp_date_to
                || ' 23:59:59'
                || ''''
                || ','
                || ''''
                || 'DD-MON-RR HH24:MI:SS'
                || ''''
                || ')';
        END IF;

        IF     p_back_order_qty_min IS NOT NULL
           AND p_back_order_qty_max IS NOT NULL
        THEN
            l_where_string   :=
                   l_where_string
                || ' AND back_order_qty between '
                || p_back_order_qty_min
                || ' AND '
                || p_back_order_qty_max;
        END IF;

        IF     p_back_order_start_date IS NOT NULL
           AND p_back_order_end_date IS NOT NULL
        THEN
            l_where_string   :=
                   l_where_string
                || ' AND back_order_date BETWEEN  to_date('
                || ''''
                || l_back_order_date_from
                || ' 00:00:00'
                || ''''
                || ','
                || ''''
                || 'DD-MON-RR HH24:MI:SS'
                || ''''
                || ')  AND '
                || ' to_date('
                || ''''
                || l_back_order_date_to
                || ' 23:59:59'
                || ''''
                || ','
                || ''''
                || 'DD-MON-RR HH24:MI:SS'
                || ''''
                || ')';
        END IF;

        IF     p_pre_order_qty_min IS NOT NULL
           AND p_pre_order_qty_max IS NOT NULL
        THEN
            l_where_string   :=
                   l_where_string
                || ' AND pre_order_qty between '
                || p_pre_order_qty_min
                || ' AND '
                || p_pre_order_qty_max;
        END IF;

        IF     p_pre_order_start_date IS NOT NULL
           AND p_pre_order_end_date IS NOT NULL
        THEN
            l_where_string   :=
                   l_where_string
                || ' AND pre_order_date BETWEEN  to_date('
                || ''''
                || l_pre_order_date_from
                || ' 00:00:00'
                || ''''
                || ','
                || ''''
                || 'DD-MON-RR HH24:MI:SS'
                || ''''
                || ')  AND '
                || ' to_date('
                || ''''
                || l_pre_order_date_to
                || ' 23:59:59'
                || ''''
                || ','
                || ''''
                || 'DD-MON-RR HH24:MI:SS'
                || ''''
                || ')';
        END IF;

        /*Start Comments by BT Technology Team on 19-FEB-2105  */
        /*      IF p_kco_qty_min IS NOT NULL AND p_kco_qty_max IS NOT NULL
              THEN
                 l_where_string :=
                       l_where_string
                    || ' AND kco_qty between '
                    || p_kco_qty_min
                    || ' AND '
                    || p_kco_qty_max;
              END IF;   */
        /*End Comments by BT Technology Team on 19-FEB-2015  */
        IF     p_consumed_start_date IS NOT NULL
           AND p_consumed_end_date IS NOT NULL
        THEN
            l_where_string   :=
                   l_where_string
                || ' AND consumed_date BETWEEN  to_date('
                || ''''
                || l_consumed_date_from
                || ' 00:00:00'
                || ''''
                || ','
                || ''''
                || 'DD-MON-RR HH24:MI:SS'
                || ''''
                || ')  AND '
                || ' to_date('
                || ''''
                || l_consumed_date_to
                || ' 23:59:59'
                || ''''
                || ','
                || ''''
                || 'DD-MON-RR HH24:MI:SS'
                || ''''
                || ')';
        END IF;

        l_query_string    :=
               'SELECT operating_unit "Operating Unit", '
            || 'organization_name "Inventory Organization Name", '
            || 'brand "Brand", '
            || 'sku "SKU", '
            || 'gender "Gender",' --Added by BT Technology Team on 19-FEB-2015
            || 'description "Description", '
            || 'atp_qty "ATP Quantity", '
            || 'atp_date "ATP Date", '
            || 'back_order_qty "Back Order Quantity", '
            || 'back_order_date "Back Order Date", '
            || 'pre_order_qty "Pre Order Quantity", '
            || 'pre_order_date "Pre Order Date", '
            || 'atp_for_atr "ATP for ATR", '
            || 'atp_buffer "ATP Buffer", '
            || 'consumed_date "Consumed Date" '
            /*Start Comments by BT Technology Team on 19-FEB-2015  */
            --         || 'kco_name "KCO Name", '
            --         || 'kco_next_qty "KCO Next Quantity", '
            --         || 'kco_next_date "KCO Next Date", '
            --         || 'kco_qty "KCO Quantity" '
            /*End Comments by BT Technology Team on 19-FEB-2015  */
            || 'FROM APPS.XXDOEC_OUTOF_STOCK_RPT_V '
            || 'WHERE 1 = 1'
            || l_where_string
            || ' ORDER BY organization_name,brand,gender ';
        fnd_file.put_line (fnd_file.LOG, l_query_string);
        owa_sylk_apps.show (p_query => l_query_string);
    EXCEPTION
        WHEN OTHERS
        THEN
            errbuf    := SQLERRM;
            retcode   := 2;
            fnd_file.put_line (
                fnd_file.LOG,
                '**************ERROR OCCURRED at Sylk************');
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
    END;

    --*********************************************************************
    PROCEDURE orders_booking_na (errbuf                  OUT VARCHAR2,
                                 retcode                 OUT VARCHAR2,
                                 p_org_id                    NUMBER,
                                 p_multi_org_ids             VARCHAR2,
                                 p_site_id                   VARCHAR2,
                                 p_brand                     VARCHAR2,
                                 p_start_date                VARCHAR2,
                                 p_end_date                  VARCHAR2,
                                 p_sub_category              VARCHAR2,
                                 p_show_by                   VARCHAR2,
                                 p_ignore_cancel_lines       VARCHAR2)
    IS
        l_date_from      DATE;
        l_date_to        DATE;
        l_show_by        VARCHAR2 (50);
        l_show_by_name   VARCHAR2 (400);
        l_query_string   VARCHAR2 (4000);
        l_where_string   VARCHAR2 (2000);
    BEGIN
        l_date_from   := fnd_date.canonical_to_date (p_start_date);
        l_date_to     := fnd_date.canonical_to_date (p_end_date);

        BEGIN
            IF p_org_id IS NOT NULL
            THEN
                l_where_string   := ' AND org_id = ' || p_org_id;
            ELSIF p_multi_org_ids IS NOT NULL
            THEN
                l_where_string   :=
                    ' AND org_id IN (' || p_multi_org_ids || ')';
            ELSE
                l_where_string   :=
                    ' AND org_id IN (SELECT DISTINCT erp_org_id FROM xxdoec_country_brand_params) ';
            END IF;

            IF p_site_id IS NOT NULL
            THEN
                l_where_string   :=
                       l_where_string
                    || ' AND site =  '
                    || ''''
                    || p_site_id
                    || '''';
            END IF;

            l_where_string   :=
                   l_where_string
                || ' AND ordered_date BETWEEN  to_date('
                || ''''
                || l_date_from
                || ' 00:00:00'
                || ''''
                || ','
                || ''''
                || 'DD-MON-RR HH24:MI:SS'
                || ''''
                || ')  AND '
                || ' to_date('
                || ''''
                || l_date_to
                || ' 23:59:59'
                || ''''
                || ','
                || ''''
                || 'DD-MON-RR HH24:MI:SS'
                || ''''
                || ')';
            l_where_string   :=
                l_where_string || ' AND brand =  ' || '''' || p_brand || '''';

            IF p_sub_category IS NOT NULL
            THEN
                l_where_string   :=
                       l_where_string
                    || ' AND sub_category =  '
                    || ''''
                    || p_sub_category
                    || '''';
            END IF;

            IF p_ignore_cancel_lines = 'Y'
            THEN
                l_where_string   :=
                       l_where_string
                    || ' AND nvl(cancelled_flag,''N'') =  ''N''';
            END IF;


            IF p_show_by = 'M'
            THEN
                l_show_by        := 'model';
                l_show_by_name   := 'Model';
            ELSIF p_show_by = 'MC'
            THEN
                l_show_by        := 'model||  ''-''  ||color';
                l_show_by_name   := 'Model / Color';
            ELSE
                l_show_by        := 'model||  ''-''  ||color||  ''-''  ||size_no';
                l_show_by_name   := 'Model / Color / Size';
            END IF;


            l_query_string   :=
                   'SELECT  operating_unit "Operating Unit", '
                || 'SITE "Website ID", '
                || 'sub_category "Sub Category ", '
                || l_show_by
                || '"'
                || l_show_by_name
                || '"'
                || ',description "Description", '
                || 'sum(ordered_quantity) "Qty Booked", '
                || 'sum((unit_selling_price - nvl(tax_amount,0)) * ordered_quantity) "Total Amount" '
                || 'FROM XXDOEC_ORDERS_BOOKING_RPT_V '
                || 'WHERE 1 = 1'
                || l_where_string
                || ' GROUP BY description,operating_unit,site,sub_category , '
                || l_show_by
                || ' ORDER BY operating_unit, site, sub_category, '
                || l_show_by;
            fnd_file.put_line (fnd_file.LOG, l_query_string);
            owa_sylk_apps.show (p_query => l_query_string);        --Mdhurjaty
        EXCEPTION
            WHEN OTHERS
            THEN
                errbuf    := SQLERRM;
                retcode   := 2;
                fnd_file.put_line (
                    fnd_file.LOG,
                    '**************ERROR OCCURRED at Sylk************');
                fnd_file.put_line (fnd_file.LOG, SQLERRM);
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            errbuf    := SQLERRM;
            retcode   := 2;
            fnd_file.put_line (
                fnd_file.LOG,
                '**************ERROR OCCURRED general************');
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
    END;

    FUNCTION get_cancel_reason (p_line_id NUMBER, p_header_id NUMBER)
        RETURN VARCHAR2
    IS
        CURSOR c1 (p_line_id NUMBER, p_header_id NUMBER)
        IS
            SELECT meaning
              FROM apps.oe_reasons oer, apps.fnd_lookup_values flv
             WHERE     oer.entity_code = 'LINE'
                   AND entity_id = p_line_id
                   AND header_id = p_header_id
                   AND flv.lookup_code = oer.reason_code
                   AND lookup_type = 'CANCEL_CODE'
                   AND LANGUAGE = 'US';

        l_return   VARCHAR2 (250);
    BEGIN
        FOR i IN c1 (p_line_id, p_header_id)
        LOOP
            l_return   := l_return || ',' || i.meaning;
        END LOOP;

        RETURN TRIM (',' FROM l_return);
    END get_cancel_reason;

    --*********************************************************************
    PROCEDURE order_reconciliation_report (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id VARCHAR2, p_multi_org_ids VARCHAR2, p_start_date VARCHAR2, p_end_date VARCHAR2
                                           , p_brand VARCHAR2)
    IS
        l_date_from      DATE;
        l_date_to        DATE;
        l_query_string   VARCHAR2 (4000);
        l_where_string   VARCHAR2 (2000);
    BEGIN
        l_date_from   := fnd_date.canonical_to_date (p_start_date);
        l_date_to     := fnd_date.canonical_to_date (p_end_date);

        BEGIN
            IF p_org_id IS NOT NULL
            THEN
                l_where_string   := ' AND org_id = ' || p_org_id;
            ELSIF p_multi_org_ids IS NOT NULL
            THEN
                l_where_string   :=
                    ' AND org_id IN (' || p_multi_org_ids || ')';
            ELSE
                l_where_string   :=
                    ' AND org_id IN (SELECT DISTINCT erp_org_id FROM xxdoec_country_brand_params) ';
            END IF;

            l_where_string   :=
                   l_where_string
                || ' AND ordered_date BETWEEN  to_date('
                || ''''
                || l_date_from
                || ' 00:00:00'
                || ''''
                || ','
                || ''''
                || 'DD-MON-RR HH24:MI:SS'
                || ''''
                || ')  AND '
                || ' to_date('
                || ''''
                || l_date_to
                || ' 23:59:59'
                || ''''
                || ','
                || ''''
                || 'DD-MON-RR HH24:MI:SS'
                || ''''
                || ')';

            IF p_brand IS NOT NULL
            THEN
                l_where_string   :=
                       l_where_string
                    || ' AND brand =  '
                    || ''''
                    || p_brand
                    || '''';
            END IF;

            l_query_string   :=
                   'SELECT OPERATING_UNIT "Operating Unit", '
                || 'SITE "Website ID", '
                || 'BRAND "Brand", '
                || 'ORACLE_ORDER_NUMBER "Oracle Order Number", '
                || 'WEB_ORDER_NUMBER "Web Order Number", '
                || 'ORDERED_DATE "Ordered Date", '
                || 'ORDERED_ITEM  "Ordered Item", '
                || 'LINE_AMOUNT "Order Amount", '
                || 'BACK_ORDERED "Back Ordered", '
                || 'SCHEDULE_SHIP_DATE "Schedule Ship Date", '
                || 'ORDER_LINE_STATUS "Order Line Status", '
                || 'DELIVERY_STATUS "Delivery Status", '
                || 'CUSTOM_LINE_STATUS "Order Custom Line Status", '
                || 'RESULT "Result", '
                || 'CANCEL_REASON "Cancel Reason" '
                || 'FROM APPS.XXDOEC_ORDER_RECON_RPT_V '
                || 'WHERE 1 = 1'
                || l_where_string
                || ' ORDER BY operating_unit, brand, oracle_order_number ';
            fnd_file.put_line (fnd_file.LOG, l_query_string);
            owa_sylk_apps.show (p_query => l_query_string);
        EXCEPTION
            WHEN OTHERS
            THEN
                errbuf    := SQLERRM;
                retcode   := 2;
                fnd_file.put_line (
                    fnd_file.LOG,
                    '**************ERROR OCCURRED at Sylk************');
                fnd_file.put_line (fnd_file.LOG, SQLERRM);
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            errbuf    := SQLERRM;
            retcode   := 2;
            fnd_file.put_line (
                fnd_file.LOG,
                '**************ERROR OCCURRED general************');
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
    END;

    PROCEDURE ca_cash_recon_report (
        errbuf                OUT VARCHAR2,
        retcode               OUT VARCHAR2,
        p_site_id                 VARCHAR2,
        --p_settlement_id     VARCHAR2, --Commented by Madhav Dhurjaty for INC0127948
        --p_settlement_status VARCHAR2, --Commented by Madhav Dhurjaty for INC0127948
        --p_deposit_date_from VARCHAR2, --Commented by Madhav Dhurjaty for INC0127948
        --p_deposit_date_to   VARCHAR2  --Commented by Madhav Dhurjaty for INC0127948
        p_settlement_id           VARCHAR2 DEFAULT NULL,
        --Added by Madhav Dhurjaty for INC0127948
        p_settlement_status       VARCHAR2 DEFAULT NULL,
        --Added by Madhav Dhurjaty for INC0127948
        p_deposit_date_from       VARCHAR2 DEFAULT NULL,
        --Added by Madhav Dhurjaty for INC0127948
        p_deposit_date_to         VARCHAR2 DEFAULT NULL --Added by Madhav Dhurjaty for INC0127948
                                                       )
    IS
        l_deposit_date_from   DATE;
        l_deposit_date_to     DATE;
        l_query_string        VARCHAR2 (4000);
        l_where_string        VARCHAR2 (2000);
    BEGIN
        l_deposit_date_from   :=
            fnd_date.canonical_to_date (p_deposit_date_from);
        l_deposit_date_to   := fnd_date.canonical_to_date (p_deposit_date_to);

        BEGIN
            IF p_site_id IS NOT NULL
            THEN
                l_where_string   :=
                       l_where_string
                    || ' AND website_id =  '
                    || ''''
                    || p_site_id
                    || '''';
            END IF;

            IF p_settlement_id IS NOT NULL
            THEN
                l_where_string   :=
                       l_where_string
                    || ' AND settlement_id =  '
                    || ''''
                    || p_settlement_id
                    || '''';
            END IF;

            IF p_settlement_status IS NOT NULL
            THEN
                l_where_string   :=
                       l_where_string
                    || ' AND settlement_status =  '
                    || ''''
                    || p_settlement_status
                    || '''';
            END IF;

            IF     p_deposit_date_from IS NOT NULL
               AND p_deposit_date_to IS NOT NULL
            THEN
                l_where_string   :=
                       l_where_string
                    || ' AND deposit_date BETWEEN  to_date('
                    || ''''
                    || l_deposit_date_from
                    || ' 00:00:00'
                    || ''''
                    || ','
                    || ''''
                    || 'DD-MON-RR HH24:MI:SS'
                    || ''''
                    || ')  AND '
                    || ' to_date('
                    || ''''
                    || l_deposit_date_to
                    || ' 23:59:59'
                    || ''''
                    || ','
                    || ''''
                    || 'DD-MON-RR HH24:MI:SS'
                    || ''''
                    || ')';
            END IF;

            l_query_string   :=
                   'SELECT website_id "Website ID", '
                || 'Settlement_id "Settlement ID", '
                || 'Deposit_date "Deposit Date", '
                || 'transaction_type "Transaction Type", '
                || 'order_number "Oracle Order Number", '
                || 'seller_order_id "Seller Order Number", '
                || 'sku "SKU", '
                || 'unit_selling_price "Unit Selling Price", '
                || 'freight_amount "Freight Amount", '
                || 'tax_amount "Tax Amount", '
                || 'promo_amount "Promo Amount", '
                || '(unit_selling_price + freight_amount + tax_amount + promo_amount) "Item Amount", '
                || 'commission_amount "Fee Amount", '
                || '(unit_selling_price + freight_amount + tax_amount + promo_amount) +  commission_amount  "Total For Order", '
                || 'settlement_status "Settlement Status", '
                || 'error_message "Error Message", '
                || 'batch "Batch", '
                || 'batch_amount "Batch Amount" '
                || 'FROM APPS.XXDOEC_CA_CASH_RECON_RPT_V '
                || 'WHERE 1 = 1'
                || l_where_string
                || ' ORDER BY website_id, deposit_date, order_number ';
            fnd_file.put_line (fnd_file.LOG, l_query_string);
            owa_sylk_apps.show (p_query => l_query_string);
        EXCEPTION
            WHEN OTHERS
            THEN
                errbuf    := SQLERRM;
                retcode   := 2;
                fnd_file.put_line (
                    fnd_file.LOG,
                    '**************ERROR OCCURRED at Sylk************');
                fnd_file.put_line (fnd_file.LOG, SQLERRM);
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            errbuf    := SQLERRM;
            retcode   := 2;
            fnd_file.put_line (
                fnd_file.LOG,
                '**************ERROR OCCURRED general************');
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
    END;

    PROCEDURE manual_refunds_report (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_payment_date_from VARCHAR2
                                     , p_payment_date_to VARCHAR2)
    IS
        l_payment_date_from   DATE;
        l_payment_date_to     DATE;
        l_query_string        VARCHAR2 (4000);
        l_where_string        VARCHAR2 (2000);
    BEGIN
        l_payment_date_from   :=
            fnd_date.canonical_to_date (p_payment_date_from);
        l_payment_date_to   := fnd_date.canonical_to_date (p_payment_date_to);

        BEGIN
            IF     p_payment_date_from IS NOT NULL
               AND p_payment_date_to IS NOT NULL
            THEN
                l_where_string   :=
                       l_where_string
                    || ' AND payment_date BETWEEN  to_date('
                    || ''''
                    || l_payment_date_from
                    || ' 00:00:00'
                    || ''''
                    || ','
                    || ''''
                    || 'DD-MON-RR HH24:MI:SS'
                    || ''''
                    || ')  AND '
                    || ' to_date('
                    || ''''
                    || l_payment_date_to
                    || ' 23:59:59'
                    || ''''
                    || ','
                    || ''''
                    || 'DD-MON-RR HH24:MI:SS'
                    || ''''
                    || ')';
            END IF;

            l_query_string   :=
                   'SELECT Customer_Name "Customer Name", '
                || 'Customer_Number "Customer Number", '
                || 'Oracle_Order_Number "Oracle Order#", '
                || 'Web_Order_number "Web Order#", '
                || 'Brand "Brand Name", '
                || 'website_id "Site ID", '
                || 'country "Country", '
                || 'Refund_processed_by "Refund Processed By", '
                || 'Refund_request_date "Request Date", '
                || 'Orig_order_amt "Original Order Amt", '
                || 'Refund_Amount "Amount Requested", '
                || 'Refund_Reason "Refund Reason", '
                || 'GL_Account "GL Account", '
                || 'Refund_Type "Transaction Type", '
                || 'Refund_product "Refunded Product", '
                || 'product_amt "Product Amount", '
                || 'tax_amt "Tax Amount", '
                || 'Shipping_amt "Shipping Amount", '
                || 'Giftwrap_amt "Giftwrap Amount", '
                || 'Other_amt "Other Amount", '
                || 'Payment_date "Transaction Date", '
                || 'PG_Reference_num "Transaction ID", '
                || 'DECODE(PG_Status,''S'', ''Success'', ''E'', ''Error'', ''N'', ''New'',PG_Status) "Status", '
                || 'Currency_Code "Currency", '
                || 'Payment_type "Payment Type", '
                || 'Tender_type "Tender Type" ' -- Added by BT Technology Team on 06-JAN-2014
                || 'FROM APPS.xxdoec_manual_refunds_rpt_v '
                || 'WHERE 1 = 1'
                || l_where_string
                || ' ORDER BY Payment_date, oracle_order_number ';
            fnd_file.put_line (fnd_file.LOG, l_query_string);
            owa_sylk_apps.show (p_query => l_query_string);
        EXCEPTION
            WHEN OTHERS
            THEN
                errbuf    := SQLERRM;
                retcode   := 2;
                fnd_file.put_line (
                    fnd_file.LOG,
                    '**************ERROR OCCURRED at Sylk************');
                fnd_file.put_line (fnd_file.LOG, SQLERRM);
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            errbuf    := SQLERRM;
            retcode   := 2;
            fnd_file.put_line (
                fnd_file.LOG,
                '**************ERROR OCCURRED general************');
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
    END;
END xxdoec_ecomm_report_util;
/


GRANT EXECUTE ON APPS.XXDOEC_ECOMM_REPORT_UTIL TO APPSRO
/
