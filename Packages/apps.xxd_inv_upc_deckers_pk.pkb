--
-- XXD_INV_UPC_DECKERS_PK  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:33 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_INV_UPC_DECKERS_PK"
AS
    --  ###################################################################################
    --
    --  System          : Oracle Applications
    --  Project         : Inventory Product Report
    --  Description     : Package for Inventory Product Report
    --  Module          : xxd_inv_upc_deckers_pk
    --  File            : xxd_inv_upc_deckers_pk.pkb
    --  Schema          : APPS
    --  Date            : 01-FEB-2016
    --  Version         : 1.0
    --  Author(s)       : Rakesh Dudani [ Suneratech Consulting]
    --  Purpose         : Package used to generate the order status report based on the
    --                    input parameters and return an excel file.
    --  dependency      : None
    --  Change History
    --  --------------
    --  Date            Name                Ver     Change                  Description
    --  ----------      --------------      -----   --------------------    ------------------
    --  01-FEB-2016     Rakesh Dudani       1.0                             Initial Version
    -- 04-MAY-2016    BT Dev Team          1.1                            Modified to fetch Item-description instead of style-description
    --
    --  ###################################################################################


    PROCEDURE run_upc_report (errbuff OUT VARCHAR2, retcode OUT VARCHAR2, p_cur_season IN VARCHAR2, p_prod_class IN VARCHAR2, p_prod_group IN VARCHAR2, p_brand IN VARCHAR2, p_style IN VARCHAR2, p_color IN VARCHAR2, p_upc IN VARCHAR2
                              , p_ean IN VARCHAR2)
    IS
        lv_query   VARCHAR2 (32000);
        ln_one     NUMBER := 1;
    BEGIN
        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                'Inventory Product Report.');

        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                '==============Parameters===============');
        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                'p_cur_season = ' || p_cur_season);
        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                'p_prod_class = ' || p_prod_class);
        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                'p_prod_group = ' || p_prod_group);
        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG, 'p_brand = ' || p_brand);
        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG, 'p_style = ' || p_style);
        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG, 'p_color = ' || p_color);
        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG, 'p_upc = ' || p_upc);
        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG, 'p_ean = ' || p_ean);


        lv_query   :=
               ' SELECT xciv.curr_active_season, xciv.department product_class, xciv.master_class product_group, '
            || ' xciv.brand, xciv.style_number, xciv.item_description style_desc,xciv.color_code as color, '
            || ' xciv.color_desc,xciv.item_size AS "SIZE", xciv.division AS gender, '
            || ' xciv.upc_code AS upc, '
            || ' ''0'' || xciv.upc_code AS EAN '
            || --' do_custom.do_get_price_list_value ' ||
               --' (6016,xciv.inventory_item_id) AS wholesale_price, ' ||
               --' do_custom.do_get_price_list_value ' ||
               --'  (6016, xciv.inventory_item_id )* 2 AS msrp ' ||
               ' from xxd_common_items_v xciv, '
            || ' apps.mtl_cross_references mcr, '
            || ' apps.hr_organization_units horg, '
            || ' apps.mtl_parameters mpar '
            || ' where xciv.organization_id = mcr.organization_id(+) '
            || ' AND xciv.inventory_item_id = mcr.inventory_item_id(+) '
            || ' AND xciv.organization_id = horg.organization_id '
            || ' AND xciv.organization_id = mpar.organization_id '
            || ' AND xciv.item_size <> ''ALL'' '
            || ' AND SYSDATE BETWEEN NVL (horg.date_from, SYSDATE - 1) '
            || ' AND NVL (horg.date_to, SYSDATE + 1) '
            || --' AND mpar.wms_enabled_flag = ''Y'' '
               ' AND mpar.organization_code = ''MST'' ';

        IF p_cur_season IS NOT NULL
        THEN
            lv_query   := lv_query || ' and xciv.curr_active_season = ';
            lv_query   := lv_query || '''' || p_cur_season || '''';
        END IF;

        IF p_prod_class IS NOT NULL
        THEN
            lv_query   := lv_query || ' and xciv.department = ';
            lv_query   := lv_query || '''' || p_prod_class || '''';
        END IF;

        IF p_prod_group IS NOT NULL
        THEN
            lv_query   := lv_query || ' and xciv.master_class = ';
            lv_query   := lv_query || '''' || p_prod_group || '''';
        END IF;

        IF p_brand IS NOT NULL
        THEN
            lv_query   := lv_query || ' AND xciv.brand = ';
            lv_query   := lv_query || '''' || p_brand || '''';
        END IF;

        IF p_style IS NOT NULL
        THEN
            lv_query   := lv_query || ' and xciv.style_number = ';
            lv_query   := lv_query || '''' || p_style || '''';
        END IF;

        IF p_color IS NOT NULL
        THEN
            lv_query   := lv_query || ' and xciv.color_code = ';
            lv_query   := lv_query || '''' || p_color || '''';
        END IF;

        IF p_upc IS NOT NULL
        THEN
            lv_query   := lv_query || ' and mcr.cross_reference = ';
            lv_query   := lv_query || '''' || p_upc || '''';
        END IF;

        IF p_ean IS NOT NULL
        THEN
            lv_query   := lv_query || ' and mcr.cross_reference = ';
            lv_query   := lv_query || '''' || p_ean || '''';
        END IF;

        lv_query   := lv_query || ' AND 1 = :ONE';

        lv_query   :=
            lv_query || ' order by xciv.style_number, xciv.color_code ';

        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG, 'Query :: ' || lv_query);

        apps.owa_sylk_apps.show (
            p_query         => lv_query,
            p_parm_names    => apps.owa_sylk_apps.owaSylkArray ('ONE'),
            p_parm_values   => apps.owa_sylk_apps.owaSylkArray (ln_one),
            p_widths        => apps.owa_sylk_apps.owaSylkArray (20, 20, 20,
                                                                20, 20, 20,
                                                                20, 20, 20,
                                                                20, 20, 20),
            p_font_name     => 'Calibri');
    END;
END xxd_inv_upc_deckers_pk;
/
