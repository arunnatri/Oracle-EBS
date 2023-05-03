--
-- XXD_ONT_ATP_UTILS_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:08 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_ATP_UTILS_PKG"
AS
    -- ####################################################################################################################
    -- Package      : XXD_ONT_ATP_UTILS_PKG
    -- Design       :  This package will be used to find ATP for items based on avaiable dates
    --
    -- Notes        :
    -- Modification :
    -- ----------
    -- Date            Name                Ver    Description
    -- ----------      --------------      -----  ------------------
    -- 07-Mar-2022    Shivanshu Talwar       1.0    Initial Version
    -- #########################################################################################################################

    --Global Variables declaration
    gv_package_name      VARCHAR2 (200) := 'XXD_ONT_ATP_UTILS_PKG';
    gn_created_by        NUMBER := apps.fnd_global.user_id;
    gn_last_updated_by   NUMBER := apps.fnd_global.user_id;
    gn_conc_request_id   NUMBER := apps.fnd_global.conc_request_id;
    gn_user_id           NUMBER := apps.fnd_global.user_id;
    gn_resp_appl_id      NUMBER := apps.fnd_global.resp_appl_id;
    gn_resp_id           NUMBER := apps.fnd_global.resp_id;
    gv_debug_flag        VARCHAR2 (20) := 'N';
    gv_op_name           VARCHAR2 (1000);
    gv_op_key            VARCHAR2 (1000);

    PROCEDURE GET_ATP_FUTURE_DATES (p_in_style_color IN VARCHAR2, p_in_demand_class IN VARCHAR2, p_in_customer IN VARCHAR2, p_in_order_type IN VARCHAR2, p_in_bulk_flag IN VARCHAR2, p_out_size_atp OUT SYS_REFCURSOR
                                    , p_out_err_msg OUT VARCHAR2)
    IS
        l_atp_rec               mrp_atp_pub.atp_rec_typ;
        l_atp_rec_out           mrp_atp_pub.atp_rec_typ;
        x_atp_rec               mrp_atp_pub.atp_rec_typ;
        x_atp_supply_demand     mrp_atp_pub.atp_supply_demand_typ;
        x_atp_period            mrp_atp_pub.atp_period_typ;
        x_atp_details           mrp_atp_pub.atp_details_typ;
        lv_query                VARCHAR2 (3000);
        lv_item_list            VARCHAR (3000);
        lv_warehouse            VARCHAR2 (100);
        x_errmessage            VARCHAR2 (2000);
        p_req_ship_date         DATE := SYSDATE;
        x_errflag               VARCHAR2 (2000);
        lv_atp_cur              VARCHAR2 (32000);
        lv_plan_cur             VARCHAR2 (30000);
        lv_item_id_list         VARCHAR2 (3000);
        lv_dblink               VARCHAR2 (100);
        ln_plan_id              NUMBER;
        lv_plan_date            VARCHAR2 (100);
        ln_organization_id      NUMBER;
        ln_cust_acct_id         NUMBER;
        lv_in_bulk_flag         VARCHAR2 (100);


        TYPE atp_rec_type IS RECORD
        (
            demand_class         VARCHAR2 (120),
            priority_date        VARCHAR2 (120),
            organization_id      VARCHAR2 (120),
            inventory_item_id    VARCHAR2 (120),
            sku                  VARCHAR2 (100),
            sizes                VARCHAR2 (100),
            request_date         VARCHAR2 (100),
            poh                  VARCHAR2 (120),
            atp                  VARCHAR2 (120),
            atp_wb               VARCHAR2 (120)
        );

        TYPE atp_tab_type IS TABLE OF atp_rec_type
            INDEX BY BINARY_INTEGER;

        atp_rec_tab_type        atp_tab_type;


        TYPE plan_cur_typ IS REF CURSOR;

        plan_cur                plan_cur_typ;


        TYPE atp_item_cur_type IS REF CURSOR;

        atp_item_cur            atp_item_cur_type;


        CURSOR cur_get_color (p_in_style_color VARCHAR2, p_org_id NUMBER, p_item_type VARCHAR2
                              , p_inv_item_id NUMBER)
        IS
              SELECT mcat.segment7 style, msi.attribute27 l_size, mcat.segment8 color_description,
                     msi.inventory_item_id inventory_item_id, msi.organization_id warehouse_id, msi.primary_uom_code primary_uom_code
                FROM mtl_system_items_b msi, mtl_item_categories micat, mtl_categories mcat,
                     mtl_category_sets mcats
               WHERE     mcats.category_set_name LIKE 'Inventory'
                     AND micat.category_set_id = mcats.category_set_id
                     AND micat.category_id = mcat.category_id
                     AND msi.inventory_item_id = micat.inventory_item_id
                     AND msi.inventory_item_id =
                         NVL (p_inv_item_id, msi.inventory_item_id)
                     AND mcats.structure_id = mcat.structure_id
                     AND msi.organization_id = micat.organization_id
                     AND mcat.attribute_category = 'Item Categories'
                     AND mcat.attribute7 || '-' || mcat.attribute8 =
                         p_in_style_color
                     AND msi.organization_id = p_org_id
                     AND NVL (msi.attribute28, 'PROD') =
                         NVL (p_item_type, 'PROD')
            -- AND MSI.INVENTORY_ITEM_ID = 5351
            ORDER BY msi.attribute27;                    --added order by size

        --Start v1.6 Changes

        CURSOR cur_get_atp (l_session_id NUMBER)
        IS
              SELECT inventory_item_id, organization_id, uom_code,
                     period_start_date, SUM (cumulative_quantity) qty
                FROM (SELECT DISTINCT md_qty.inventory_item_id, md_qty.organization_id, md_qty.uom_code,
                                      dt_qry.period_start_date, cumulative_quantity
                        FROM mrp_atp_details_temp md_qty,
                             (SELECT DISTINCT inventory_item_id, organization_id, supply_demand_date period_start_date
                                -- ,period_start_date
                                FROM mrp_atp_details_temp md_date
                               WHERE     Session_id = l_session_id --AND    record_type = 1
                                     AND supply_demand_type = 2
                                     AND record_type = 2) dt_qry
                       WHERE     md_qty.INVENTORY_ITEM_ID =
                                 dt_qry.INVENTORY_ITEM_ID
                             AND md_qty.ORGANIZATION_ID =
                                 dt_qry.organization_id
                             AND md_qty.session_id = l_session_id
                             AND MD_QTY.RECORD_TYPE = 1
                             AND TRUNC (DT_QRY.PERIOD_START_DATE) BETWEEN TRUNC (
                                                                              md_qty.period_start_date)
                                                                      AND TRUNC (
                                                                              md_qty.period_end_date))
            GROUP BY inventory_item_id, organization_id, uom_code,
                     period_start_date;


        l_cnt                   NUMBER := 0;
        l_var                   NUMBER := 0;

        TYPE get_size_tbl_type IS TABLE OF cur_get_color%ROWTYPE
            INDEX BY PLS_INTEGER;

        l_inv_items_rec         get_size_tbl_type;
        x_atp_style_out_temp    xxdo.xxd_atp_style_color_tab_typ;
        x_atp_style_out_temp1   xxdo.xxd_atp_style_color_tab_typ;
        x_atp_style_out_temp2   xxdo.xxd_atp_style_color_tab_typ
                                    := xxdo.xxd_atp_style_color_tab_typ ();
        future_qty              NUMBER;
    BEGIN
        --x_atp_style_out := xxd_atp_style_tab ();
        x_atp_style_out_temp    := xxdo.xxd_atp_style_color_tab_typ ();
        x_atp_style_out_temp1   := xxdo.xxd_atp_style_color_tab_typ ();

        /*  SELECT responsibility_id, application_id
            INTO l_resp_id, l_appl_id
            FROM apps.fnd_responsibility_vl
           WHERE responsibility_name = 'Deckers Order Management User - US';
           */

        /*SELECT user_id
          INTO l_user_id
          FROM fnd_user
         WHERE user_name = 'BATCH.O2F';
         */

        -- fnd_global.apps_initialize (l_user_id, l_resp_id, l_appl_id);

        -- ====================================================
        -- IF using 11.5.9 and above, Use MSC_ATP_GLOBAL.Extend_ATP
        -- API to extend record structure as per standards. This
        -- will ensure future compatibility.

        --msc_atp_global.extend_atp (l_atp_rec, x_return_status, 1);

        -- IF using 11.5.8 code, Use MSC_SATP_FUNC.Extend_ATP
        -- API to avoid any issues with Extending ATP record
        -- type.
        -- ====================================================

        IF p_in_demand_class = 'UGG-US-ALL OTHER'
        THEN
            SELECT organization_code, inventory_org_id
              INTO lv_warehouse, ln_organization_id
              FROM apps.xxd_om_b2b_demand_classes_v
             WHERE     demand_class = p_in_demand_class
                   AND organization_code = 'US1';
        ELSE
            BEGIN
                SELECT organization_code, inventory_org_id
                  INTO lv_warehouse, ln_organization_id
                  FROM apps.xxd_om_b2b_demand_classes_v
                 WHERE demand_class = p_in_demand_class;
            EXCEPTION
                WHEN OTHERS
                THEN
                    BEGIN
                        SELECT organization_code, inventory_org_id
                          INTO lv_warehouse, ln_organization_id
                          FROM apps.xxd_om_b2b_demand_classes_v
                         WHERE demand_class || '-' || ORGANIZATION_CODE =
                               p_in_demand_class;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            SELECT organization_code, inventory_org_id
                              INTO lv_warehouse, ln_organization_id
                              FROM apps.xxd_om_b2b_demand_classes_v
                             WHERE     demand_class = p_in_demand_class
                                   AND ROWNUM = 1;
                    END;
            END;
        END IF;

        DBMS_OUTPUT.put_line (ln_organization_id || '-' || lv_warehouse);


        BEGIN
            SELECT a2m_dblink INTO lv_dblink FROM mrp_ap_apps_instances_all;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_dblink   := NULL;
                RETURN;
        END;

        BEGIN
            SELECT cust_account_id
              INTO ln_cust_acct_id
              FROM hz_cust_Accounts
             WHERE ACCOUNT_NUMBER = p_in_customer;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_cust_acct_id   := '9999';
        END;

        --DBMS_OUTPUT.put_line (lv_dblink);

        lv_plan_cur             := '
        SELECT mp.plan_id, 
               TO_CHAR(mp.curr_start_date, ''DD-MON-YYYY'') plan_date 
          FROM msc_plans@' || lv_dblink || ' mp
         WHERE 1 = 1
           AND mp.compile_designator = ''ATP''';

        OPEN plan_cur FOR lv_plan_cur;

        FETCH plan_cur INTO ln_plan_id, lv_plan_date;

        CLOSE plan_cur;

        --DBMS_OUTPUT.put_line (ln_plan_id);

        -- DBMS_OUTPUT.put_line (lv_plan_date);


        lv_query                :=
               'select listagg (inventory_item_id, '', '') within group (order by inventory_item_id) 
	     from msc.msc_system_items@'
            || lv_dblink
            || ' msi
		where organization_id = 107
       and plan_id = '
            || ln_plan_id
            || '
       and item_name like '''
            || p_in_style_color
            || '-%''';

        DBMS_OUTPUT.put_line (lv_query);

        EXECUTE IMMEDIATE lv_query
            INTO lv_item_list;

        lv_item_id_list         := '(' || lv_item_list || ')';

        --DBMS_OUTPUT.put_line (lv_item_id_list);


        IF    NVL (UPPER (p_in_bulk_flag), 'N') = 'N'
           OR NVL (UPPER (p_in_bulk_flag), 'N') = 'NO'
        THEN
            lv_in_bulk_flag   := 'N';
        ELSE
            lv_in_bulk_flag   := 'Y';
        END IF;

        --DBMS_OUTPUT.put_line (lv_in_bulk_flag);

        lv_atp_cur              :=
               'SELECT   epsilon.demand_class
                                 , epsilon.priority
                                 , epsilon.organization_id
                                 , epsilon.inventory_item_id
								 , epsilon.sku
								 , epsilon.sizes
                                 , min(epsilon.dte) dte
								 , DECODE(SIGN(min(epsilon.poh)),-1,0,min(epsilon.poh)) poh								 
								 , DECODE(SIGN(epsilon.atp),-1,0,epsilon.atp) atp
								 , DECODE(SIGN(epsilon.atp_wb_ec),-1,0,epsilon.atp_wb_ec) atp_wb_ec
                              from (
                                    select
                                           delta.demand_class
                                         , delta.priority
                                         , delta.organization_id
                                         , delta.inventory_item_id
										 , delta.sku
										 , substr(delta.sku,instr(sku,''-'',-1)+1,10) sizes
                                         , delta.dte
                                         , delta.quantity
                                         , least(delta.poh,10000000000) poh
                                         , rnk
                                         , min(least(poh,10000000000)) over (partition by organization_id, demand_class, inventory_item_id order by dte desc rows unbounded preceding) atp 
                                         , min(least(poh_wb_ec,10000000000)) over (partition by organization_id, demand_class, inventory_item_id order by dte desc rows unbounded preceding) atp_wb_ec
                                      from(
                                            select gamma.demand_class
                                                 , gamma.priority
                                                 , gamma.organization_id
                                                 , gamma.inventory_item_id
												 , gamma.sku
                                                 , gamma.dte
                                                 , gamma.quantity
                                                 , sum(gamma.quantity) over (partition by organization_id, demand_class, inventory_item_id order by dte asc rows unbounded preceding) poh 
                                                 , sum(gamma.qty_wb_ec) over (partition by organization_id, demand_class, inventory_item_id order by dte asc rows unbounded preceding) poh_wb_ec
                                                 , max(gamma.rnk) over (partition by organization_id, demand_class, inventory_item_id order by dte asc rows unbounded preceding) rnk
                                              from (
                                                    select /*+ FULL(msi) */
                                                           beta.demand_class
                                                         , ''1'' priority 
                                                         , beta.organization_id
                                                         , msi.sr_inventory_item_id inventory_item_id
														 , item_name sku
                                                         , beta.dte
                                                         , sum(beta.quantity) quantity 
                                                         , sum(beta.qty_wb_ec) qty_wb_ec
                                                         , sum(beta.rnk) rnk
                                                      from (
                                                           select /*+ FULL(md) */
                                                                   md.sr_instance_id
                                                                 , md.plan_id
                                                                 , md.organization_id
                                                                 , ''-1'' demand_class 
                                                                 , md.inventory_item_id
                                                                 , greatest(mcd_sd.next_date, trunc(sysdate)) dte
																 , sum(-md.using_requirement_quantity) quantity
																 , 0 qty_wb_ec
                                                                 , 0 rnk
                                                              from msc.msc_plans@'
            || lv_dblink
            || ' mp
                                                                 , msc.msc_demands@'
            || lv_dblink
            || ' md
                                                                 , msc.msc_calendar_dates@'
            || lv_dblink
            || ' mcd_sd
                                                              where mp.compile_designator = ''ATP''
                                                                and md.plan_id = mp.plan_id
                                                                and md.sr_instance_id = mp.sr_instance_id
                                                                and mcd_sd.sr_instance_id = md.sr_instance_id
                                                                and mcd_sd.calendar_date = TRUNC(md.schedule_ship_date)
                                                               -- and mcd_sd.calendar_code = ''DEC:Deckers445'' -- ver 1.2 commented for ccr CCR0007711
															   and mcd_sd.calendar_code in ( select  calendar_code from msc_trading_partners@'
            || lv_dblink
            || '  where calendar_code is not null and sr_tp_id= md.organization_id and rownum <100 )
																and mcd_sd.exception_set_id = -1
																AND md.plan_id = '
            || ln_plan_id
            || '
                                                   and md.inventory_item_id IN	'
            || lv_item_id_list
            || '
                                                   and md.organization_id = '
            || ln_organization_id
            || '
                                                                group by md.sr_instance_id
                                                                     , md.plan_id
                                                                     , md.organization_id
                                                                     , md.inventory_item_id
                                                                     , greatest(mcd_sd.next_date, trunc(sysdate))
                                                           union all
                                                           select /*+ FULL(md) */
                                                                 md.sr_instance_id
                                                                 , md.plan_id
                                                                 , md.organization_id
                                                                 , ''-1'' demand_class 
                                                                 , md.inventory_item_id
                                                                 , greatest(mcd_sd.next_date, trunc(sysdate)) dte
																 , 0 quantity
																 , sum(-md.using_requirement_quantity) qty_wb_ec
                                                                 , 0 rnk
                                                              from msc.msc_plans@'
            || lv_dblink
            || '  mp
                                                                 , msc.msc_demands@'
            || lv_dblink
            || '  md
                                                                 , msc.msc_calendar_dates@'
            || lv_dblink
            || ' mcd_sd
                                                              where mp.compile_designator = ''ATP''
                                                                and md.plan_id = mp.plan_id
                                                              AND md.plan_id = '
            || ln_plan_id
            || '
															   and md.organization_id = '
            || ln_organization_id
            || '
                                                               and md.inventory_item_id IN '
            || lv_item_id_list
            || '				
                                                                and md.sr_instance_id = mp.sr_instance_id
                                                                and mcd_sd.sr_instance_id = md.sr_instance_id
                                                                and mcd_sd.calendar_date = TRUNC(md.schedule_ship_date)
															    and mcd_sd.calendar_code in ( select calendar_code 
																                                from msc_trading_partners@'
            || lv_dblink
            || '
																							   where calendar_code is not null 
																							     and sr_tp_id = md.organization_id )
																and mcd_sd.exception_set_id = -1
																and not exists (SELECT 1
															FROM 	oe_transaction_types_all  otta,
																	oe_transaction_types_tl   ott,
																	oe_order_headers_all      oha,
																	oe_order_lines_all        ola
															WHERE     otta.ATTRIBUTE5 = ''BO''
																AND otta.TRANSACTION_TYPE_ID = ott.TRANSACTION_TYPE_ID
																AND ott.LANGUAGE = ''US''
																AND oha.header_id = ola.header_id
																AND  ola.line_id = md.sales_order_line_id
																AND order_type_id=otta.TRANSACTION_TYPE_ID
																AND oha.sold_to_org_id = '
            || ln_cust_acct_id
            || '
																AND ola.open_flag = ''Y''
																AND schedule_ship_date IS NOT NULL)
														      group by md.sr_instance_id
                                                                     , md.plan_id
                                                                     , md.organization_id
                                                                     , md.inventory_item_id
                                                                     , greatest(mcd_sd.next_date, trunc(sysdate))
                                                            union all
                                                            select /*+ FULL(ms) */
                                                                   ms.sr_instance_id
                                                                 , ms.plan_id
                                                                 , ms.organization_id
                                                                 , ''-1'' demand_class 
                                                                 , ms.inventory_item_id inventory_item_id
                                                                 , greatest(mcd_sd.prior_date, trunc(sysdate)) dte
                                                                 , sum(ms.new_order_quantity) quantity 
                                                                 , sum(ms.new_order_quantity) qty_wb_ec
                                                                 , rank() over (partition by ms.organization_id--, mas.demand_class --v1.3
																                           , ms.inventory_item_id 
																					order by greatest(mcd_sd.prior_date, trunc(sysdate))) rnk
                                                              from msc.msc_plans@'
            || lv_dblink
            || ' mp
                                                                 , msc.msc_supplies@'
            || lv_dblink
            || ' ms
                                                                 , msc.msc_calendar_dates@'
            || lv_dblink
            || ' mcd_sd
                                                              where mp.compile_designator = ''ATP''
                                                                and ms.plan_id = mp.plan_id
                                                               and ms.plan_id = '
            || ln_plan_id
            || '
                                                               and ms.organization_id = '
            || ln_organization_id
            || '
                                                                and mcd_sd.sr_instance_id = ms.sr_instance_id
                                                                and mcd_sd.calendar_date = TRUNC(ms.new_schedule_date)
										 AND mcd_sd.calendar_code IN 
   ( select calendar_code from  MSC.MSC_TRADING_PARTNERS@'
            || lv_dblink
            || '  where calendar_code is not null and sr_tp_id= ms.organization_id and rownum<100)
                                                                and mcd_sd.exception_set_id = -1
                                                              group by ms.sr_instance_id
                                                                     , ms.plan_id
                                                                     , ms.organization_id
                                                                     , ms.inventory_item_id
                                                                     , greatest(mcd_sd.prior_date, trunc(sysdate)) ) beta
                                                                     , msc.msc_system_items@'
            || lv_dblink
            || ' msi
                                                                               where 1=1
                                                        and msi.plan_id = beta.plan_id
                                                        and msi.sr_instance_id = beta.sr_instance_id
                                                        and msi.inventory_item_id = beta.inventory_item_id
                                                        and msi.organization_id = beta.organization_id
                                                        and msi.organization_id = '
            || ln_organization_id
            || '
                                                        AND msi.inventory_item_id IN '
            || lv_item_id_list
            || '
                                                        AND msi.plan_id= '
            || ln_plan_id
            || '
                                                        AND msi.SR_INSTANCE_ID=1
                                                      group by beta.demand_class
                                                             , beta.organization_id
                                                             , msi.sr_inventory_item_id
                                                             ,msi.item_name
                                                             , beta.dte
                                                      order by msi.sr_inventory_item_id asc
                                                             , beta.demand_class asc
                                                             , beta.dte asc
                                                    ) gamma
                                            ) delta
                                      order by organization_id asc
                                             , demand_class asc
                                             , dte asc
                                    ) epsilon where atp < 10000000000 
                              group by epsilon.demand_class
                                     , epsilon.priority
                                     , epsilon.organization_id
                                     , epsilon.inventory_item_id
                                     , epsilon.sku
									 , epsilon.sizes
									 , epsilon.rnk
                                     , epsilon.atp
                                     , epsilon.atp_wb_ec';

        DBMS_OUTPUT.put_line (lv_atp_cur);

        OPEN atp_item_cur FOR lv_atp_cur;

        FETCH atp_item_cur BULK COLLECT INTO atp_rec_tab_type;

        CLOSE atp_item_cur;


        IF atp_rec_tab_type.COUNT > 0
        THEN
            FORALL y IN atp_rec_tab_type.FIRST .. atp_rec_tab_type.LAST
                INSERT INTO XXDO.XXD_ONT_ATP_STYLE_COLOR_GTT (demand_class, priority_date, organization_id, inventory_item_id, sku, sizes, request_date, poh, atp
                                                              , atp_wb)
                     VALUES (atp_rec_tab_type (y).demand_class, atp_rec_tab_type (y).priority_date, atp_rec_tab_type (y).organization_id, atp_rec_tab_type (y).inventory_item_id, atp_rec_tab_type (y).sku, atp_rec_tab_type (y).sizes, atp_rec_tab_type (y).request_date, atp_rec_tab_type (y).poh, DECODE (lv_in_bulk_flag,  'Y', atp_rec_tab_type (y).atp_wb,  'N', atp_rec_tab_type (y).atp)
                             , atp_rec_tab_type (y).atp_wb);
        END IF;

        l_cnt                   := 0;

        OPEN p_out_size_atp FOR   SELECT DISTINCT sizes item_size,
                                                  CURSOR (
                                                        SELECT REQUEST_DATE available_date, atp - LAG (atp, 1, 0) OVER (PARTITION BY SKU ORDER BY TO_DATE (REQUEST_DATE, 'DD-MON-YY')) available_quantity
                                                          FROM XXDO.XXD_ONT_ATP_STYLE_COLOR_GTT b
                                                         WHERE a.sizes = b.sizes
                                                      ORDER BY TO_DATE (REQUEST_DATE, 'DD-MON-YY')) Inventory
                                    FROM XXDO.XXD_ONT_ATP_STYLE_COLOR_GTT a
                                GROUP BY sizes
                                ORDER BY a.sizes;
    /*
        APEX_JSON.initialize_clob_output;

        APEX_JSON.open_object;
        APEX_JSON.write ('size_atp', p_out_size_atp);
        APEX_JSON.close_object;

        DBMS_OUTPUT.put_line (APEX_JSON.get_clob_output);
        APEX_JSON.free_output;

        DBMS_OUTPUT.put_line (APEX_JSON.get_clob_output);
    */


    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            x_errflag       := 'E';
            p_out_err_msg   := 'E';
            DBMS_OUTPUT.put_line (
                   'An error was encountered in procedure get_atp_future_dates'
                || SQLCODE
                || ' -ERROR- '
                || SQLERRM);
    END GET_ATP_FUTURE_DATES;
END XXD_ONT_ATP_UTILS_PKG;
/


GRANT EXECUTE, DEBUG ON APPS.XXD_ONT_ATP_UTILS_PKG TO XXORDS
/
