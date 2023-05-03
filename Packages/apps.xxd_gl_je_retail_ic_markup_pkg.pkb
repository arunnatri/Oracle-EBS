--
-- XXD_GL_JE_RETAIL_IC_MARKUP_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:30:12 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_GL_JE_RETAIL_IC_MARKUP_PKG"
AS
    /******************************************************************************************
     NAME           : XXD_GL_JE_RETAIL_IC_MARKUP_PKG
     Desc           : Deckers Retail IC Markup for Sales and Onhand Journal Creation Program

     REVISIONS:
     Date        Author             Version  Description
     ---------   ----------         -------  ---------------------------------------------------
     31-MAR-2023 Thirupathi Gajula  1.0      Created this package XXD_GL_JE_RETAIL_IC_MARKUP_PKG
                                             for Markup Retail GL Journal Import
    *********************************************************************************************/
    -- ATTRIBUTE1 -->  Local at USD
    -- ATTRIBUTE2 -->  Markup Calculation Currency
    -- ATTRIBUTE3 -->  Calculation Exchange Rate Type
    -- ATTRIBUTE4 -->  Journal Exchange Rate Type
    -- ATTRIBUTE5 -->  Journal Local at USD
    -- SALES --
    -- ATTRIBUTE1 -->  Local at USD SALES
    -- ATTRIBUTE2 -->  Markup Calculation Currency
    -- ATTRIBUTE3 -->  Calculation Exchange Rate Type
    -- ATTRIBUTE4 -->  Journal Exchange Rate Type
    -- ATTRIBUTE5 -->  Local at USD RETURN
    --Global constants
    gn_user_id        CONSTANT NUMBER := fnd_global.user_id;
    gn_login_id       CONSTANT NUMBER := fnd_global.login_id;
    gn_org_id         CONSTANT NUMBER := fnd_profile.VALUE ('ORG_ID');
    gn_resp_id        CONSTANT NUMBER := fnd_global.resp_id;
    gn_resp_appl_id   CONSTANT NUMBER := fnd_global.resp_appl_id;
    gn_request_id     CONSTANT NUMBER := fnd_global.conc_request_id;
    gn_limit_rec      CONSTANT NUMBER := 1000;
    gn_commit_rows    CONSTANT NUMBER := 1000;
    gd_cut_of_date             DATE;
    gd_Sales_from_Rep_date     DATE;                 --(only for Sales report)
    gv_onhand_currency         VARCHAR2 (5);
    gv_markup_currency         VARCHAR2 (5);
    gv_markup_calc_cur         VARCHAR2 (5);
    gv_rate_type               VARCHAR2 (50);
    gv_jl_rate_type            VARCHAR2 (50);
    gn_ledger                  NUMBER;
    gn_org_unit_id_rms         NUMBER;
    gn_ou_id                   NUMBER;
    gn_inv_org_id              NUMBER;
    gn_store_number            NUMBER;
    gv_sales_import_status     VARCHAR2 (500);
    gv_oh_import_status        VARCHAR2 (500);
    gv_ou_name                 hr_operating_units.name%TYPE;

    PROCEDURE write_log (pv_msg IN VARCHAR2)
    IS
        lv_msg   VARCHAR2 (4000) := pv_msg;
    BEGIN
        IF gn_user_id = -1
        THEN
            DBMS_OUTPUT.put_line (pv_msg);
        ELSE
            apps.fnd_file.put_line (apps.fnd_file.LOG, pv_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Error in - Procedure -' || SQLERRM);
            DBMS_OUTPUT.put_line (
                'Error in WRITE_LOG Procedure -' || SQLERRM);
    END write_log;

    -- ======================================================================================
    -- This procedure will generate report and send the email notification to user
    -- ======================================================================================
    PROCEDURE generate_setup_err_prc (p_setup_err IN VARCHAR2)
    IS
        lv_message      VARCHAR2 (32000);
        lv_recipients   VARCHAR2 (4000);
        lv_result       VARCHAR2 (100);
        lv_result_msg   VARCHAR2 (4000);
    BEGIN
        lv_message   :=
               p_setup_err
            || CHR (10)
            || CHR (10)
            || 'Regards,'
            || CHR (10)
            || 'SYSADMIN.'
            || CHR (10)
            || CHR (10)
            || 'Note: This is auto generated mail, please donot reply.';

        BEGIN
            SELECT LISTAGG (flv.description, ';') WITHIN GROUP (ORDER BY flv.description)
              INTO lv_recipients
              FROM fnd_lookup_values flv
             WHERE     lookup_type = 'XXD_GL_COMMON_EMAILS_LKP'
                   AND lookup_code = '10001'
                   AND enabled_flag = 'Y'
                   AND language = 'US'
                   AND SYSDATE BETWEEN TRUNC (
                                           NVL (start_date_active, SYSDATE))
                                   AND TRUNC (
                                           NVL (end_date_active, SYSDATE) + 1);
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_recipients   := NULL;
        END;

        xxdo_mail_pkg.send_mail (
            pv_sender         => 'erp@deckers.com',
            pv_recipients     => lv_recipients,
            pv_ccrecipients   => NULL,
            pv_subject        =>
                'Deckers Retail IC Markup for Sales and Onhand Journal output',
            pv_message        => lv_message,
            pv_attachments    => NULL,
            xv_result         => lv_result,
            xv_result_msg     => lv_result_msg);
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
            write_log ('Exception in generate_setup_err_prc- ' || SQLERRM);
    END generate_setup_err_prc;

    /***********************************************************************************************
    **************************** Procedure for Insert records into Staging *************************
    ************************************************************************************************/

    PROCEDURE insert_sale_records (x_ret_message OUT VARCHAR2)
    AS
        CURSOR sale_cur IS
              SELECT a.location
                         store_number,
                     d.location_name
                         store_name,
                     a.loc_type
                         store_type,
                     d.loc_currency
                         store_currency,
                     d.set_of_books_id
                         ledger_id,
                     c.inventory_item_id
                         item_id,
                     NVL (c.item_number, SUBSTR (e.item_desc, 1, 25))
                         item_number,
                     a.av_cost
                         sales_avg_cost,
                     (SELECT SUM (NVL (units, 0))
                        FROM xxdo.xxd_gl_tran_data_hist_temp_t
                       WHERE     1 = 1
                             AND location = a.location
                             AND tran_date = TRUNC (gd_cut_of_date)
                             AND tran_code = 1                        -- Sales
                             AND SIGN (NVL (units, 0)) > 0
                             AND item = a.item)
                         sales_total_units,
                     (SELECT SUM (NVL (units, 0))
                        FROM xxdo.xxd_gl_tran_data_hist_temp_t
                       WHERE     1 = 1
                             AND location = a.location
                             AND tran_date = TRUNC (gd_cut_of_date)
                             AND tran_code = 1                        -- Sales
                             AND SIGN (NVL (units, 0)) < 0
                             AND item = a.item)
                         return_total_units,
                     (SELECT SUM (NVL (total_cost, 0))
                        FROM xxdo.xxd_gl_tran_data_hist_temp_t
                       WHERE     1 = 1
                             AND location = a.location
                             AND tran_date = TRUNC (gd_cut_of_date)
                             AND tran_code = 1                        -- Sales
                             AND SIGN (NVL (total_cost, 0)) > 0
                             AND item = a.item)
                         sales_total_cost,
                     (SELECT SUM (NVL (total_cost, 0))
                        FROM xxdo.xxd_gl_tran_data_hist_temp_t
                       WHERE     1 = 1
                             AND location = a.location
                             AND tran_date = TRUNC (gd_cut_of_date)
                             AND tran_code = 1                        -- Sales
                             AND SIGN (NVL (total_cost, 0)) < 0
                             AND item = a.item)
                         return_total_cost,
                     (SELECT SUM (NVL (total_retail, 0))
                        FROM xxdo.xxd_gl_tran_data_hist_temp_t
                       WHERE     1 = 1
                             AND location = a.location
                             AND tran_date = TRUNC (gd_cut_of_date)
                             AND tran_code = 1                        -- Sales
                             AND SIGN (NVL (total_retail, 0)) > 0
                             AND item = a.item)
                         sales_total_retail,
                     (SELECT SUM (NVL (total_retail, 0))
                        FROM xxdo.xxd_gl_tran_data_hist_temp_t
                       WHERE     1 = 1
                             AND location = a.location
                             AND tran_date = TRUNC (gd_cut_of_date)
                             AND tran_code = 1                        -- Sales
                             AND SIGN (NVL (total_retail, 0)) < 0
                             AND item = a.item)
                         return_total_retail,
                     a.tran_date
                         transaction_date,
                     MAX (a.tran_data_timestamp)
                         transaction_date_ts,
                     MAX (a.tran_data_timestamp)
                         tran_data_ts,
                     rou.org_unit_id
                         org_unit_id_rms,
                     NVL (c.brand,
                          REGEXP_SUBSTR (e.item_desc, '[^-:]+', 1,
                                         2))
                         brand,
                     c.style_number
                         style,
                     c.color_code
                         color,
                     c.item_type
                         item_type,
                     c.master_style
                         master_style,
                     c.item_size
                         item_size,
                     c.style_desc
                         style_desc,
                     c.item_description
                         item_desc,
                     c.department
                         department,
                     c.master_class
                         master_class,
                     c.sub_class
                         sub_class,
                     c.division
                         division,
                     c.intro_season
                         intro_season,
                     c.curr_active_season
                         current_season
                FROM        -- rms13prod.tran_data_history@xxdo_retail_rms  a,
                     xxdo.xxd_gl_tran_data_hist_temp_t a,
                     (SELECT item.*
                        FROM apps.xxd_common_items_v item
                       WHERE item.organization_id = 106) c,
                     rms13prod.mv_loc_sob@xxdo_retail_rms d,
                     rms13prod.item_master@xxdo_retail_rms e,
                     xxd_retail_stores_v ou_ship,
                     rms13prod.store@xxdo_retail_rms rou,
                     apps.org_organization_definitions inv_org
               WHERE     1 = 1
                     AND a.location = d.location
                     AND a.item = c.inventory_item_id(+)
                     AND a.loc_type = 'S'
                     AND a.item = e.item
                     --AND e.merchandise_ind = 'Y'
                     AND a.tran_code = 1                              -- Sales
                     AND a.location = rou.store                      -- RMS OU
                     AND a.location = ou_ship.rms_store_id     -- Ship From OU
                     AND NVL (ou_ship.operating_unit, 1) =
                         NVL (inv_org.operating_unit, 1)
                     AND TRUNC (a.tran_date) = TRUNC (gd_cut_of_date)
                     AND NVL (d.set_of_books_id, 1) =
                         NVL (NVL (gn_ledger, d.set_of_books_id), 1)
                     AND NVL (rou.org_unit_id, 1) =
                         NVL (NVL (gn_org_unit_id_rms, rou.org_unit_id), 1)
                     AND NVL (ou_ship.operating_unit, 1) =
                         NVL (NVL (gn_ou_id, ou_ship.operating_unit), 1)
                     AND NVL (inv_org.organization_id, 1) =
                         NVL (NVL (gn_inv_org_id, inv_org.organization_id), 1)
                     AND a.location = NVL (gn_store_number, a.location)
                     AND NOT EXISTS
                             (SELECT 1
                                FROM xxdo.xxd_gl_je_ret_ic_markup_stg_t stg1
                               WHERE     TRUNC (stg1.as_of_date) =
                                         TRUNC (gd_cut_of_date)
                                     AND stg1.record_status = 'P'
                                     AND stg1.store_number = a.location
                                     AND stg1.item_id = a.item)
            GROUP BY a.location, d.location_name, a.loc_type,
                     d.loc_currency, d.set_of_books_id, c.inventory_item_id,
                     c.item_number, e.item_desc, a.av_cost,
                     a.tran_code, a.tran_date, a.item              -- ,a.units
                                                     ,
                     rou.org_unit_id, c.brand, c.style_number,
                     c.color_code, c.item_type, c.master_style,
                     c.item_size, c.style_desc, c.item_description,
                     c.department, c.master_class, c.sub_class,
                     c.division, c.intro_season, c.curr_active_season;

        --Local variables
        TYPE ret_sales_rec_type IS RECORD
        (
            store_number           NUMBER,
            store_name             VARCHAR2 (240),
            store_type             VARCHAR2 (1),
            store_currency         VARCHAR2 (15),
            ledger_id              NUMBER,
            item_id                NUMBER,
            item_number            VARCHAR2 (40),
            sales_avg_cost         NUMBER,
            sales_total_units      NUMBER,
            return_total_units     NUMBER,
            sales_total_cost       NUMBER,
            return_total_cost      NUMBER,
            sales_total_retail     NUMBER,
            return_total_retail    NUMBER,
            transaction_date       DATE,
            transaction_date_ts    DATE,
            tran_data_ts           DATE,
            org_unit_id_rms        NUMBER,
            brand                  VARCHAR2 (40),
            style                  VARCHAR2 (150),
            color                  VARCHAR2 (150),
            item_type              VARCHAR2 (240),
            master_style           VARCHAR2 (40),
            item_size              VARCHAR2 (240),
            style_desc             VARCHAR2 (40),
            item_desc              VARCHAR2 (240),
            department             VARCHAR2 (40),
            master_class           VARCHAR2 (40),
            sub_class              VARCHAR2 (40),
            division               VARCHAR2 (40),
            intro_season           VARCHAR2 (240),
            current_season         VARCHAR2 (240)
        );

        TYPE ret_sale_type IS TABLE OF ret_sales_rec_type
            INDEX BY BINARY_INTEGER;

        ret_sale_rec   ret_sale_type;
        forall_err     EXCEPTION;
        PRAGMA EXCEPTION_INIT (forall_err, -24381);
        l_markup_cnt   NUMBER;
    BEGIN
        --Delete the data from the ret_sale_rec if exists
        IF ret_sale_rec.COUNT > 0
        THEN
            ret_sale_rec.DELETE;
        END IF;

        --Opening the Cursor
        OPEN sale_cur;

        LOOP
            FETCH sale_cur BULK COLLECT INTO ret_sale_rec LIMIT gn_limit_rec;

            IF ret_sale_rec.COUNT > 0
            THEN
                --Bulk Insert of Retail Onhand Inventory data into staging table
                FORALL i IN ret_sale_rec.FIRST .. ret_sale_rec.LAST
                  SAVE EXCEPTIONS
                    INSERT INTO xxdo.xxd_gl_je_ret_ic_markup_stg_t (
                                    store_number,
                                    store_name,
                                    store_type,
                                    store_currency,
                                    sales_journal_currency,
                                    item_id,
                                    item_number,
                                    brand,
                                    transaction_date,
                                    transaction_date_ts,
                                    tran_data_ts,
                                    as_of_date,
                                    sales_avg_cost,
                                    sales_total_units,
                                    return_total_units,
                                    sales_total_cost,
                                    return_total_cost,
                                    sales_total_retail,
                                    return_total_retail,
                                    ledger_id,
                                    operating_unit,                  -- RMS OU
                                    ou_id,                          -- SHIP OU
                                    inv_org_id,
                                    record_status,
                                    attribute2,  --Markup Calculation Currency
                                    attribute3, --Calculation Exchange Rate Type
                                    attribute4,   --Journal Exchange Rate Type
                                    request_id,
                                    created_by,
                                    creation_date,
                                    last_updated_by,
                                    last_update_date,
                                    last_update_login)
                             VALUES (
                                        ret_sale_rec (i).store_number,
                                        ret_sale_rec (i).store_name,
                                        ret_sale_rec (i).store_type,
                                        ret_sale_rec (i).store_currency,
                                        CASE
                                            WHEN gv_markup_currency = 'USD'
                                            THEN
                                                'USD'          -- USD Currency
                                            ELSE
                                                ret_sale_rec (i).store_currency -- Local Currency
                                        END,
                                        ret_sale_rec (i).item_id,
                                        ret_sale_rec (i).item_number,
                                        ret_sale_rec (i).brand,
                                        ret_sale_rec (i).transaction_date,
                                        ret_sale_rec (i).transaction_date_ts,
                                        ret_sale_rec (i).tran_data_ts,
                                        gd_cut_of_date,
                                        ret_sale_rec (i).sales_avg_cost,
                                        NVL (
                                            ret_sale_rec (i).sales_total_units,
                                            0),
                                        NVL (
                                            ret_sale_rec (i).return_total_units,
                                            0),
                                        NVL (
                                            ret_sale_rec (i).sales_total_cost,
                                            0),
                                        NVL (
                                            ret_sale_rec (i).return_total_cost,
                                            0),
                                        NVL (
                                            ret_sale_rec (i).sales_total_retail,
                                            0),
                                        NVL (
                                            ret_sale_rec (i).return_total_retail,
                                            0),
                                        ret_sale_rec (i).ledger_id,
                                        ret_sale_rec (i).org_unit_id_rms,
                                        gn_ou_id,
                                        gn_inv_org_id,
                                        'N',
                                        gv_markup_calc_cur,      -- ATTRIBUTE2
                                        gv_rate_type,            -- ATTRIBUTE3
                                        gv_jl_rate_type,         -- ATTRIBUTE4
                                        gn_request_id,
                                        gn_user_id,
                                        SYSDATE,
                                        gn_user_id,
                                        SYSDATE,
                                        gn_login_id);

                COMMIT;
                ret_sale_rec.DELETE;
            --Retail Onhand Data Cursor records Else
            ELSE
                --generate_setup_err_prc ('Either no Retail Sales records OR already processed for the Parameters provided.');
                fnd_file.put_line (
                    fnd_file.LOG,
                    'There are no Retail Sale records for the Parameters provided.');
            --x_ret_message := 'There are no Retail Sale records for the Parameters provided.';
            END IF;

            EXIT WHEN sale_cur%NOTFOUND;
        END LOOP;

        CLOSE sale_cur;
    EXCEPTION
        WHEN forall_err
        THEN
            FOR errs IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
            LOOP
                fnd_file.put_line (
                    fnd_file.LOG,
                    SQLERRM (-SQL%BULK_EXCEPTIONS (errs).ERROR_CODE));
            END LOOP;

            x_ret_message   := SQLERRM;
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unable to open the Sales Insert rec cursor. Please check the cursor query.'
                || SQLERRM);

            --Close the cursor
            CLOSE sale_cur;

            x_ret_message   := SQLERRM;
    END insert_sale_records;

    /***********************************************************************************************
    ******************* Procedure for Insert Incremental records into Staging **********************
    ************************************************************************************************/

    PROCEDURE insert_incr_sale_records (x_ret_message OUT VARCHAR2)
    AS
        CURSOR sale_cur IS
              SELECT a.location
                         store_number,
                     d.location_name
                         store_name,
                     a.loc_type
                         store_type,
                     d.loc_currency
                         store_currency,
                     d.set_of_books_id
                         ledger_id,
                     c.inventory_item_id
                         item_id,
                     NVL (c.item_number, SUBSTR (e.item_desc, 1, 25))
                         item_number,
                     (SELECT SUM (NVL (ABS (units), 0) * av_cost) / SUM (NVL (ABS (units), 0))
                        FROM xxdo.xxd_gl_tran_data_hist_temp_t
                       WHERE     1 = 1
                             AND location = a.location
                             AND tran_date = TRUNC (gd_cut_of_date)
                             AND tran_code = 1                        -- Sales
                             -- AND sign(NVL(units,0)) > 0
                             AND item = a.item)
                         sales_avg_cost,
                     (SELECT SUM (NVL (units, 0))
                        FROM xxdo.xxd_gl_tran_data_hist_temp_t
                       WHERE     1 = 1
                             AND location = a.location
                             AND tran_date = TRUNC (gd_cut_of_date)
                             AND tran_code = 1                        -- Sales
                             AND SIGN (NVL (units, 0)) > 0
                             AND item = a.item)
                         sales_total_units,
                     (SELECT SUM (NVL (units, 0))
                        FROM xxdo.xxd_gl_tran_data_hist_temp_t
                       WHERE     1 = 1
                             AND location = a.location
                             AND tran_date = TRUNC (gd_cut_of_date)
                             AND tran_code = 1                        -- Sales
                             AND SIGN (NVL (units, 0)) < 0
                             AND item = a.item)
                         return_total_units,
                     (SELECT SUM (NVL (total_cost, 0))
                        FROM xxdo.xxd_gl_tran_data_hist_temp_t
                       WHERE     1 = 1
                             AND location = a.location
                             AND tran_date = TRUNC (gd_cut_of_date)
                             AND tran_code = 1                        -- Sales
                             AND SIGN (NVL (total_cost, 0)) > 0
                             AND item = a.item)
                         sales_total_cost,
                     (SELECT SUM (NVL (total_cost, 0))
                        FROM xxdo.xxd_gl_tran_data_hist_temp_t
                       WHERE     1 = 1
                             AND location = a.location
                             AND tran_date = TRUNC (gd_cut_of_date)
                             AND tran_code = 1                        -- Sales
                             AND SIGN (NVL (total_cost, 0)) < 0
                             AND item = a.item)
                         return_total_cost,
                     (SELECT SUM (NVL (total_retail, 0))
                        FROM xxdo.xxd_gl_tran_data_hist_temp_t
                       WHERE     1 = 1
                             AND location = a.location
                             AND tran_date = TRUNC (gd_cut_of_date)
                             AND tran_code = 1                        -- Sales
                             AND SIGN (NVL (total_retail, 0)) > 0
                             AND item = a.item)
                         sales_total_retail,
                     (SELECT SUM (NVL (total_retail, 0))
                        FROM xxdo.xxd_gl_tran_data_hist_temp_t
                       WHERE     1 = 1
                             AND location = a.location
                             AND tran_date = TRUNC (gd_cut_of_date)
                             AND tran_code = 1                        -- Sales
                             AND SIGN (NVL (total_retail, 0)) < 0
                             AND item = a.item)
                         return_total_retail,
                     a.tran_date
                         transaction_date,
                     MAX (a.tran_data_timestamp)
                         transaction_date_ts,
                     MAX (a.tran_data_timestamp)
                         tran_data_ts,
                     rou.org_unit_id
                         org_unit_id_rms,
                     NVL (c.brand,
                          REGEXP_SUBSTR (e.item_desc, '[^-:]+', 1,
                                         2))
                         brand,
                     c.style_number
                         style,
                     c.color_code
                         color,
                     c.item_type
                         item_type,
                     c.master_style
                         master_style,
                     c.item_size
                         item_size,
                     c.style_desc
                         style_desc,
                     c.item_description
                         item_desc,
                     c.department
                         department,
                     c.master_class
                         master_class,
                     c.sub_class
                         sub_class,
                     c.division
                         division,
                     c.intro_season
                         intro_season,
                     c.curr_active_season
                         current_season
                FROM        -- rms13prod.tran_data_history@xxdo_retail_rms  a,
                     xxdo.xxd_gl_tran_data_hist_temp_t a,
                     (SELECT item.*
                        FROM apps.xxd_common_items_v item
                       WHERE item.organization_id = 106) c,
                     rms13prod.mv_loc_sob@xxdo_retail_rms d,
                     rms13prod.item_master@xxdo_retail_rms e,
                     xxd_retail_stores_v ou_ship,
                     rms13prod.store@xxdo_retail_rms rou,
                     apps.org_organization_definitions inv_org
               WHERE     1 = 1
                     AND a.location = d.location
                     AND a.item = c.inventory_item_id(+)
                     AND a.loc_type = 'S'
                     AND a.item = e.item
                     --AND e.merchandise_ind = 'Y'
                     AND a.tran_code = 1                              -- Sales
                     AND a.location = rou.store                      -- RMS OU
                     AND a.location = ou_ship.rms_store_id     -- Ship From OU
                     AND NVL (ou_ship.operating_unit, 1) =
                         NVL (inv_org.operating_unit, 1)
                     AND TRUNC (a.tran_date) = TRUNC (gd_cut_of_date)
                     AND NVL (d.set_of_books_id, 1) =
                         NVL (NVL (gn_ledger, d.set_of_books_id), 1)
                     AND NVL (rou.org_unit_id, 1) =
                         NVL (NVL (gn_org_unit_id_rms, rou.org_unit_id), 1)
                     AND NVL (ou_ship.operating_unit, 1) =
                         NVL (NVL (gn_ou_id, ou_ship.operating_unit), 1)
                     AND NVL (inv_org.organization_id, 1) =
                         NVL (NVL (gn_inv_org_id, inv_org.organization_id), 1)
                     AND a.location = NVL (gn_store_number, a.location)
                     AND a.tran_data_timestamp >
                         (SELECT MAX (stg1.tran_data_ts)
                            FROM xxdo.xxd_gl_je_ret_ic_markup_stg_t stg1
                           WHERE     1 = 1
                                 AND stg1.store_number = a.location
                                 AND stg1.item_id = a.item
                                 AND stg1.record_status = 'P'
                                 AND TRUNC (stg1.as_of_date) =
                                     TRUNC (gd_cut_of_date))
            GROUP BY a.location, d.location_name, a.loc_type,
                     d.loc_currency, d.set_of_books_id, c.inventory_item_id,
                     c.item_number, e.item_desc, a.tran_code,
                     a.tran_date, a.item                           -- ,a.units
                                        , rou.org_unit_id,
                     c.brand, c.style_number, c.color_code,
                     c.item_type, c.master_style, c.item_size,
                     c.style_desc, c.item_description, c.department,
                     c.master_class, c.sub_class, c.division,
                     c.intro_season, c.curr_active_season;

        --Local variables
        TYPE ret_sales_rec_type IS RECORD
        (
            store_number           NUMBER,
            store_name             VARCHAR2 (240),
            store_type             VARCHAR2 (1),
            store_currency         VARCHAR2 (15),
            ledger_id              NUMBER,
            item_id                NUMBER,
            item_number            VARCHAR2 (40),
            sales_avg_cost         NUMBER,
            sales_total_units      NUMBER,
            return_total_units     NUMBER,
            sales_total_cost       NUMBER,
            return_total_cost      NUMBER,
            sales_total_retail     NUMBER,
            return_total_retail    NUMBER,
            transaction_date       DATE,
            transaction_date_ts    DATE,
            tran_data_ts           DATE,
            org_unit_id_rms        NUMBER,
            brand                  VARCHAR2 (40),
            style                  VARCHAR2 (150),
            color                  VARCHAR2 (150),
            item_type              VARCHAR2 (240),
            master_style           VARCHAR2 (40),
            item_size              VARCHAR2 (240),
            style_desc             VARCHAR2 (40),
            item_desc              VARCHAR2 (240),
            department             VARCHAR2 (40),
            master_class           VARCHAR2 (40),
            sub_class              VARCHAR2 (40),
            division               VARCHAR2 (40),
            intro_season           VARCHAR2 (240),
            current_season         VARCHAR2 (240)
        );

        TYPE ret_sale_type IS TABLE OF ret_sales_rec_type
            INDEX BY BINARY_INTEGER;

        ret_sale_rec   ret_sale_type;
        forall_err     EXCEPTION;
        PRAGMA EXCEPTION_INIT (forall_err, -24381);
        l_markup_cnt   NUMBER;
    BEGIN
        --Delete the data from the ret_sale_rec if exists
        IF ret_sale_rec.COUNT > 0
        THEN
            ret_sale_rec.DELETE;
        END IF;

        --Opening the Cursor
        OPEN sale_cur;

        LOOP
            FETCH sale_cur BULK COLLECT INTO ret_sale_rec LIMIT gn_limit_rec;

            IF ret_sale_rec.COUNT > 0
            THEN
                --Bulk Insert of Retail sales data into staging table
                FORALL i IN ret_sale_rec.FIRST .. ret_sale_rec.LAST
                  SAVE EXCEPTIONS
                    INSERT INTO xxdo.xxd_gl_je_ret_ic_markup_stg_t (
                                    store_number,
                                    store_name,
                                    store_type,
                                    store_currency,
                                    sales_journal_currency,
                                    item_id,
                                    item_number,
                                    brand,
                                    transaction_date,
                                    transaction_date_ts,
                                    tran_data_ts,
                                    as_of_date,
                                    sales_avg_cost,
                                    sales_total_units,
                                    return_total_units,
                                    sales_total_cost,
                                    return_total_cost,
                                    sales_total_retail,
                                    return_total_retail,
                                    ledger_id,
                                    operating_unit,                  -- RMS OU
                                    ou_id,                          -- SHIP OU
                                    inv_org_id,
                                    record_status,
                                    attribute2,  --Markup Calculation Currency
                                    attribute3, --Calculation Exchange Rate Type
                                    attribute4,   --Journal Exchange Rate Type
                                    request_id,
                                    created_by,
                                    creation_date,
                                    last_updated_by,
                                    last_update_date,
                                    last_update_login)
                             VALUES (
                                        ret_sale_rec (i).store_number,
                                        ret_sale_rec (i).store_name,
                                        ret_sale_rec (i).store_type,
                                        ret_sale_rec (i).store_currency,
                                        CASE
                                            WHEN gv_markup_currency = 'USD'
                                            THEN
                                                'USD'          -- USD Currency
                                            ELSE
                                                ret_sale_rec (i).store_currency -- Local Currency
                                        END,
                                        ret_sale_rec (i).item_id,
                                        ret_sale_rec (i).item_number,
                                        ret_sale_rec (i).brand,
                                        ret_sale_rec (i).transaction_date,
                                        ret_sale_rec (i).transaction_date_ts,
                                        ret_sale_rec (i).tran_data_ts,
                                        gd_cut_of_date,
                                        ret_sale_rec (i).sales_avg_cost,
                                        NVL (
                                            ret_sale_rec (i).sales_total_units,
                                            0),
                                        NVL (
                                            ret_sale_rec (i).return_total_units,
                                            0),
                                        NVL (
                                            ret_sale_rec (i).sales_total_cost,
                                            0),
                                        NVL (
                                            ret_sale_rec (i).return_total_cost,
                                            0),
                                        NVL (
                                            ret_sale_rec (i).sales_total_retail,
                                            0),
                                        NVL (
                                            ret_sale_rec (i).return_total_retail,
                                            0),
                                        ret_sale_rec (i).ledger_id,
                                        ret_sale_rec (i).org_unit_id_rms,
                                        gn_ou_id,
                                        gn_inv_org_id,
                                        'N',
                                        gv_markup_calc_cur,      -- ATTRIBUTE2
                                        gv_rate_type,            -- ATTRIBUTE3
                                        gv_jl_rate_type,         -- ATTRIBUTE4
                                        gn_request_id,
                                        gn_user_id,
                                        SYSDATE,
                                        gn_user_id,
                                        SYSDATE,
                                        gn_login_id);

                COMMIT;
                ret_sale_rec.DELETE;
            --Retail Onhand Data Cursor records Else
            ELSE
                --generate_setup_err_prc ('Either no Retail Sales records OR already processed for the Parameters provided.');
                fnd_file.put_line (
                    fnd_file.LOG,
                    'There are no Retail Incremental Sale records for the Parameters provided.');
            --x_ret_message := 'There are no Retail Sale records for the Parameters provided.';
            END IF;

            EXIT WHEN sale_cur%NOTFOUND;
        END LOOP;

        CLOSE sale_cur;
    EXCEPTION
        WHEN forall_err
        THEN
            FOR errs IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
            LOOP
                fnd_file.put_line (
                    fnd_file.LOG,
                    SQLERRM (-SQL%BULK_EXCEPTIONS (errs).ERROR_CODE));
            END LOOP;

            x_ret_message   := SQLERRM;
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unable to open the Sales Incremental Insert rec cursor. Please check the cursor query.'
                || SQLERRM);

            --Close the cursor
            CLOSE sale_cur;

            x_ret_message   := SQLERRM;
    END insert_incr_sale_records;

    /***********************************************************************************************
    ******************* Procedure for Insert ONHAND records into ONHAND Staging ********************
    ************************************************************************************************/

    PROCEDURE insert_oh_records (x_ret_message OUT VARCHAR2)
    AS
        CURSOR stock_oh_cur IS
              SELECT /*+ parallel(b, 6) */
                     b.loc
                         store_number,
                     d.location_name
                         store_name,
                     b.loc_type
                         store_type,
                     d.loc_currency
                         store_currency,
                     d.set_of_books_id
                         ledger_id,
                     b.item
                         item_id,
                     --NVL(c.item_number, SUBSTR(e.item_desc, 1, 25)) item_number,
                     NVL (c.item_number,
                          (SELECT SUBSTR (e.item_desc, 1, 25)
                             FROM rms13prod.item_master@xxdo_retail_rms e
                            WHERE e.item = b.item))
                         item_number,
                     b.stock_on_hand
                         onhand_qty,
                     b.in_transit_qty
                         in_transit_qty,
                     (NVL (b.stock_on_hand, 0) + NVL (b.in_transit_qty, 0))
                         stock_onhand,
                     b.av_cost
                         stock_avg_cost,
                     ((NVL (b.stock_on_hand, 0) + NVL (b.in_transit_qty, 0)) * b.av_cost)
                         total_stock_cost,
                     gd_cut_of_date
                         soh_date_ts,
                     MAX (b.last_update_datetime)
                         last_update_ts,
                     rou.org_unit_id
                         org_unit_id_rms,
                     NVL (c.brand,
                          (SELECT REGEXP_SUBSTR (e.item_desc, '[^-:]+', 1,
                                                 2)
                             FROM rms13prod.item_master@xxdo_retail_rms e
                            WHERE e.item = b.item))
                         brand,
                     c.style_number
                         style,
                     c.color_code
                         color,
                     c.item_type
                         item_type,
                     c.master_style
                         master_style,
                     c.item_size
                         item_size,
                     c.style_desc
                         style_desc,
                     c.item_description
                         item_desc,
                     c.department
                         department,
                     c.master_class
                         master_class,
                     c.sub_class
                         sub_class,
                     c.division
                         division,
                     c.intro_season
                         intro_season,
                     c.curr_active_season
                         current_season
                FROM rms13prod.item_loc_soh@xxdo_retail_rms b,
                     (SELECT item.*
                        FROM apps.xxd_common_items_v item
                       WHERE item.organization_id = 106) c,
                     rms13prod.mv_loc_sob@xxdo_retail_rms d,
                     --rms13prod.item_master@xxdo_retail_rms       e,
                     xxd_retail_stores_v ou_ship,
                     rms13prod.store@xxdo_retail_rms rou,
                     apps.org_organization_definitions inv_org
               WHERE     1 = 1
                     AND b.loc = d.location
                     AND b.item = c.inventory_item_id(+)
                     --AND b.item = e.item
                     AND b.loc_type = 'S'
                     AND (NVL (b.stock_on_hand, 0) + NVL (b.in_transit_qty, 0)) <>
                         0
                     -- AND e.merchandise_ind = 'Y'
                     AND b.loc = rou.store                           -- RMS OU
                     AND b.loc = ou_ship.rms_store_id          -- Ship From OU
                     AND NVL (ou_ship.operating_unit, 1) =
                         NVL (inv_org.operating_unit, 1)
                     AND NVL (d.set_of_books_id, 1) =
                         NVL (NVL (gn_ledger, d.set_of_books_id), 1)
                     AND NVL (rou.org_unit_id, 1) =
                         NVL (NVL (gn_org_unit_id_rms, rou.org_unit_id), 1)
                     AND NVL (ou_ship.operating_unit, 1) =
                         NVL (NVL (gn_ou_id, ou_ship.operating_unit), 1)
                     AND NVL (inv_org.organization_id, 1) =
                         NVL (NVL (gn_inv_org_id, inv_org.organization_id), 1)
                     AND b.loc = NVL (gn_store_number, b.loc)
                     AND NOT EXISTS
                             (SELECT 1
                                FROM xxdo.xxd_gl_je_ret_ic_onhand_stg_t stg1
                               WHERE     TRUNC (stg1.soh_date_ts) =
                                         TRUNC (gd_cut_of_date)
                                     AND stg1.record_status = 'P'
                                     AND stg1.store_number = b.loc
                                     AND stg1.item_id = b.item)
            GROUP BY b.loc, d.location_name, b.loc_type,
                     d.loc_currency, d.set_of_books_id, b.item,
                     c.item_number                              --,e.item_desc
                                  , b.stock_on_hand, b.in_transit_qty,
                     b.av_cost, rou.org_unit_id, c.brand,
                     c.style_number, c.color_code, c.item_type,
                     c.master_style, c.item_size, c.style_desc,
                     c.item_description, c.department, c.master_class,
                     c.sub_class, c.division, c.intro_season,
                     c.curr_active_season;

        --Local variables
        TYPE ret_oh_rec_type IS RECORD
        (
            store_number        NUMBER,
            store_name          VARCHAR2 (240),
            store_type          VARCHAR2 (1),
            store_currency      VARCHAR2 (15),
            ledger_id           NUMBER,
            item_id             NUMBER,
            item_number         VARCHAR2 (40),
            onhand_qty          NUMBER,
            in_transit_qty      NUMBER,
            stock_onhand        NUMBER,
            stock_avg_cost      NUMBER,
            total_stock_cost    NUMBER,
            soh_date_ts         DATE,
            last_update_ts      DATE,
            org_unit_id_rms     NUMBER,
            brand               VARCHAR2 (40),
            style               VARCHAR2 (150),
            color               VARCHAR2 (150),
            item_type           VARCHAR2 (240),
            master_style        VARCHAR2 (40),
            item_size           VARCHAR2 (240),
            style_desc          VARCHAR2 (40),
            item_desc           VARCHAR2 (240),
            department          VARCHAR2 (40),
            master_class        VARCHAR2 (40),
            sub_class           VARCHAR2 (40),
            division            VARCHAR2 (40),
            intro_season        VARCHAR2 (240),
            current_season      VARCHAR2 (240)
        );

        TYPE ret_oh_type IS TABLE OF ret_oh_rec_type
            INDEX BY BINARY_INTEGER;

        ret_oh_rec     ret_oh_type;
        forall_err     EXCEPTION;
        PRAGMA EXCEPTION_INIT (forall_err, -24381);
        l_onhand_cnt   NUMBER;
    BEGIN
        --Delete the data from the ret_oh_rec if exists
        IF ret_oh_rec.COUNT > 0
        THEN
            ret_oh_rec.DELETE;
        END IF;

        --Opening the Cursor
        OPEN stock_oh_cur;

        LOOP
            FETCH stock_oh_cur
                BULK COLLECT INTO ret_oh_rec
                LIMIT gn_limit_rec;

            IF ret_oh_rec.COUNT > 0
            THEN
                --Bulk Insert of Retail Onhand Inventory data into staging table
                FORALL i IN ret_oh_rec.FIRST .. ret_oh_rec.LAST
                  SAVE EXCEPTIONS
                    INSERT INTO xxdo.xxd_gl_je_ret_ic_onhand_stg_t (
                                    store_number,
                                    store_name,
                                    store_type,
                                    store_currency,
                                    item_id,
                                    item_number,
                                    soh_date_ts,
                                    last_update_ts,
                                    as_of_date,
                                    onhand_qty,
                                    in_transit_qty,
                                    stock_onhand,
                                    stock_avg_cost,
                                    total_stock_cost,
                                    ledger_id,
                                    operating_unit,                  -- RMS OU
                                    ou_id,                          -- SHIP OU
                                    inv_org_id,
                                    oh_journal_currency,
                                    brand,
                                    style,
                                    color,
                                    item_type,
                                    master_style,
                                    item_size,
                                    style_desc,
                                    item_desc,
                                    department,
                                    master_class,
                                    sub_class,
                                    division,
                                    intro_season,
                                    current_season,
                                    record_status,
                                    attribute2, -- Markup Calculation Currency
                                    attribute3, -- Calculation Exchange Rate Type
                                    attribute4,  -- Journal Exchange Rate Type
                                    request_id,
                                    created_by,
                                    creation_date,
                                    last_updated_by,
                                    last_update_date,
                                    last_update_login)
                             VALUES (
                                        ret_oh_rec (i).store_number,
                                        ret_oh_rec (i).store_name,
                                        ret_oh_rec (i).store_type,
                                        ret_oh_rec (i).store_currency,
                                        ret_oh_rec (i).item_id,
                                        ret_oh_rec (i).item_number,
                                        ret_oh_rec (i).soh_date_ts,
                                        ret_oh_rec (i).last_update_ts,
                                        ret_oh_rec (i).soh_date_ts, -- As_of_Date
                                        ret_oh_rec (i).onhand_qty,
                                        ret_oh_rec (i).in_transit_qty,
                                        ret_oh_rec (i).stock_onhand,
                                        ret_oh_rec (i).stock_avg_cost,
                                        ret_oh_rec (i).total_stock_cost,
                                        ret_oh_rec (i).ledger_id,
                                        ret_oh_rec (i).org_unit_id_rms,
                                        gn_ou_id,
                                        gn_inv_org_id,
                                        CASE
                                            WHEN gv_onhand_currency = 'USD'
                                            THEN
                                                'USD'          -- USD Currency
                                            ELSE
                                                ret_oh_rec (i).store_currency -- Local Currency
                                        END,
                                        ret_oh_rec (i).brand,
                                        ret_oh_rec (i).style,
                                        ret_oh_rec (i).color,
                                        ret_oh_rec (i).item_type,
                                        ret_oh_rec (i).master_style,
                                        ret_oh_rec (i).item_size,
                                        ret_oh_rec (i).style_desc,
                                        ret_oh_rec (i).item_desc,
                                        ret_oh_rec (i).department,
                                        ret_oh_rec (i).master_class,
                                        ret_oh_rec (i).sub_class,
                                        ret_oh_rec (i).division,
                                        ret_oh_rec (i).intro_season,
                                        ret_oh_rec (i).current_season,
                                        'N',
                                        gv_markup_calc_cur,      -- Attribute2
                                        gv_rate_type,            -- Attribute3
                                        gv_jl_rate_type,         -- Attribute4
                                        gn_request_id,
                                        gn_user_id,
                                        SYSDATE,
                                        gn_user_id,
                                        SYSDATE,
                                        gn_login_id);

                COMMIT;
                ret_oh_rec.DELETE;
            --Retail Onhand Data Cursor records Else
            ELSE
                --generate_setup_err_prc ('Either no Retail Onhand records OR already processed for the Parameters provided.');
                fnd_file.put_line (
                    fnd_file.LOG,
                    'There are no Retail Onhand records for the Parameters provided.');
            --x_ret_message := 'There are no Retail Onhand records for the Parameters provided.';
            END IF;

            EXIT WHEN stock_oh_cur%NOTFOUND;
        END LOOP;

        CLOSE stock_oh_cur;
    EXCEPTION
        WHEN forall_err
        THEN
            FOR errs IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
            LOOP
                fnd_file.put_line (
                    fnd_file.LOG,
                    SQLERRM (-SQL%BULK_EXCEPTIONS (errs).ERROR_CODE));
            END LOOP;

            x_ret_message   := SQLERRM;
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unable to open the Onhand Insert rec cursor. Please check the cursor query.'
                || SQLERRM);

            --Close the cursor
            CLOSE stock_oh_cur;

            x_ret_message   := SQLERRM;
    END insert_oh_records;

    /***********************************************************************************************
    ******************* Procedure for Increment Update ONHAND records into ONHAND Staging ********************
    ************************************************************************************************/

    PROCEDURE update_oh_records (x_ret_message OUT VARCHAR2)
    AS
        ln_stock_avg_cost    NUMBER;
        Ln_localusd_factor   NUMBER;
        ln_usd_factor        NUMBER;
        Ln_local_factor      NUMBER;

        CURSOR stock_oh_upd_cur IS
              SELECT stg1.oh_rowid
                         oh_rowid,
                     a.location
                         store_number,
                     d.location_name
                         store_name,
                     a.loc_type
                         store_type,
                     d.loc_currency
                         store_currency,
                     d.set_of_books_id
                         ledger_id,
                     c.inventory_item_id
                         item_id,
                     NVL (c.item_number, SUBSTR (e.item_desc, 1, 25))
                         item_number,
                     NVL (
                         SUM (
                               DECODE (
                                   tran_code,
                                   30, 1,
                                   37, 1,
                                   20, 1,
                                   22, DECODE (GL_REF_NO,
                                               20, 1,
                                               21, 1,
                                               23, 1,
                                               24, 1))
                             * total_cost),
                         0)
                         calc_cost,
                     NVL (
                         SUM (
                               DECODE (
                                   tran_code,
                                   30, 1,
                                   37, 1,
                                   20, 1,
                                   22, DECODE (GL_REF_NO,
                                               20, 1,
                                               21, 1,
                                               23, 1,
                                               24, 1))
                             * units),
                         0)
                         calc_units,
                     NVL (
                         SUM (
                               DECODE (
                                   tran_code,
                                   1, -1,
                                   32, -1,
                                   38, -1,
                                   22, DECODE (GL_REF_NO,
                                               20, 0,
                                               21, 0,
                                               23, 0,
                                               24, 0,
                                               1),
                                   23, 1,
                                   44, 1,
                                   20, 1)
                             * units),
                         0)
                         adj_oh_qty,
                     NVL (
                         SUM (
                               DECODE (
                                   tran_code,
                                   30, 1,
                                   37, 1,
                                   44, -1,
                                   22, DECODE (GL_REF_NO,
                                               20, 1,
                                               21, 1,
                                               23, 1,
                                               24, 1,
                                               0))
                             * units),
                         0)
                         adj_intran_qty,
                     (CASE
                          WHEN ROUND (b.av_cost, 2) =
                               ROUND (stg1.stock_avg_cost, 2)
                          THEN
                              0
                          ELSE
                              1
                      END)
                         cost_check,
                     MAX (a.tran_data_timestamp)
                         tran_data_ts
                FROM        -- rms13prod.tran_data_history@xxdo_retail_rms  a,
                     xxdo.xxd_gl_tran_data_hist_temp_t a,
                     rms13prod.item_loc_soh@xxdo_retail_rms b,
                     (SELECT item.*
                        FROM apps.xxd_common_items_v item
                       WHERE item.organization_id = 106) c,
                     rms13prod.mv_loc_sob@xxdo_retail_rms d,
                     rms13prod.item_master@xxdo_retail_rms e,
                     xxd_retail_stores_v ou_ship,
                     rms13prod.store@xxdo_retail_rms rou,
                     apps.org_organization_definitions inv_org,
                     (SELECT stg.ROWID oh_rowid, stg.*
                        FROM xxdo.xxd_gl_je_ret_ic_onhand_stg_t stg
                       WHERE     TRUNC (stg.soh_date_ts) =
                                 TRUNC (gd_cut_of_date)
                             AND stg.record_status = 'P') stg1
               WHERE     1 = 1
                     AND a.location = d.location
                     AND a.item = c.inventory_item_id(+)
                     AND a.loc_type = 'S'
                     AND b.loc_type = 'S'
                     AND a.location = b.loc
                     AND a.item = b.item
                     AND a.item = e.item
                     --AND e.merchandise_ind = 'Y'
                     AND tran_code IN (1, 32, 38,
                                       22, 23, 30,
                                       37, 44, 20)
                     AND a.location = rou.store                      -- RMS OU
                     AND a.location = ou_ship.rms_store_id     -- Ship From OU
                     AND NVL (ou_ship.operating_unit, 1) =
                         NVL (inv_org.operating_unit, 1)
                     AND NVL (d.set_of_books_id, 1) =
                         NVL (NVL (gn_ledger, d.set_of_books_id), 1)
                     AND NVL (rou.org_unit_id, 1) =
                         NVL (NVL (gn_org_unit_id_rms, rou.org_unit_id), 1)
                     AND NVL (ou_ship.operating_unit, 1) =
                         NVL (NVL (gn_ou_id, ou_ship.operating_unit), 1)
                     AND NVL (inv_org.organization_id, 1) =
                         NVL (NVL (gn_inv_org_id, inv_org.organization_id), 1)
                     AND a.location = NVL (gn_store_number, a.location)
                     AND NVL (inv_org.organization_id, 1) =
                         NVL (stg1.inv_org_id, 1)
                     AND a.location = stg1.store_number
                     AND a.item = stg1.item_id
                     --AND ROUND(((NVL(b.stock_on_hand, 0) +  NVL(b.in_transit_qty, 0) ) * b.av_cost), 2) <> ROUND(stg1.total_stock_cost, 2)
                     AND TRUNC (a.tran_date) <= TRUNC (gd_cut_of_date)
                     AND TRUNC (a.tran_date) >=
                         TRUNC (TO_DATE (gd_cut_of_date, 'DD-MON-YYYY'), 'MM')
                     AND a.tran_data_timestamp > stg1.last_update_ts
                     AND a.tran_data_timestamp >
                         (SELECT MAX (tran_data_ts)
                            FROM xxdo.xxd_gl_je_ret_ic_markup_stg_t stg3
                           WHERE     1 = 1
                                 AND stg3.store_number = stg1.store_number
                                 AND stg3.item_id = stg1.item_id
                                 AND stg3.transaction_date = stg1.as_of_date)
            GROUP BY stg1.oh_rowid, a.location, d.location_name,
                     a.loc_type, d.loc_currency, d.set_of_books_id,
                     c.inventory_item_id, c.item_number, e.item_desc,
                     b.av_cost, stg1.stock_avg_cost;
    BEGIN
        FOR rec_oh_upd IN stock_oh_upd_cur
        LOOP
            ln_stock_avg_cost    := NULL;
            Ln_localusd_factor   := NULL;
            ln_usd_factor        := NULL;
            Ln_local_factor      := NULL;

            SELECT DECODE (
                       rec_oh_upd.cost_check,
                       0, stock_avg_cost,
                       DECODE (
                           (stock_onhand + rec_oh_upd.calc_units),
                           0, stock_avg_cost,
                             (total_stock_cost + rec_oh_upd.calc_cost)
                           / (stock_onhand + rec_oh_upd.calc_units))),
                   (CASE
                        WHEN     attribute2 = 'Local'
                             AND oh_journal_currency = 'USD'
                        THEN
                            1
                        ELSE
                            0
                    END),
                   (CASE
                        WHEN attribute2 = 'USD' -- AND oh_journal_currency = 'USD'
                                                THEN 1
                        ELSE 0
                    END),
                   (CASE
                        WHEN     attribute2 = 'Local'
                             AND oh_journal_currency = 'local'
                        THEN
                            1
                        ELSE
                            0
                    END)
              INTO ln_stock_avg_cost, Ln_localusd_factor, ln_usd_factor, Ln_local_factor
              FROM xxdo.xxd_gl_je_ret_ic_onhand_stg_t stg2
             WHERE     1 = 1
                   AND stg2.store_number = rec_oh_upd.store_number
                   AND stg2.item_id = rec_oh_upd.item_id
                   AND TRUNC (stg2.soh_date_ts) = TRUNC (gd_cut_of_date)
                   AND stg2.ROWID = rec_oh_upd.oh_rowid;

            UPDATE xxdo.xxd_gl_je_ret_ic_onhand_stg_t stg
               SET onhand_qty       = onhand_qty + rec_oh_upd.adj_oh_qty,
                   in_transit_qty   =
                       in_transit_qty + rec_oh_upd.adj_intran_qty,
                   stock_onhand    =
                         stock_onhand
                       + rec_oh_upd.adj_oh_qty
                       + rec_oh_upd.adj_intran_qty,
                   stock_avg_cost   = ln_stock_avg_cost,
                   total_stock_cost   =
                         (stock_onhand + rec_oh_upd.adj_oh_qty + rec_oh_upd.adj_intran_qty)
                       * ln_stock_avg_cost,
                   oh_mrgn_value_local   =
                         (stock_onhand + rec_oh_upd.adj_oh_qty + rec_oh_upd.adj_intran_qty)
                       * oh_mrgn_cst_local,
                   oh_mrgn_value_usd   =
                         (stock_onhand + rec_oh_upd.adj_oh_qty + rec_oh_upd.adj_intran_qty)
                       * oh_mrgn_cst_usd,
                   oh_markup_local   =
                       ROUND (
                             ((stock_onhand + rec_oh_upd.adj_oh_qty + rec_oh_upd.adj_intran_qty) * oh_mrgn_cst_local)
                           - oh_localval,
                           2),
                   oh_markup_usd   =
                       ROUND (
                             ((stock_onhand + rec_oh_upd.adj_oh_qty + rec_oh_upd.adj_intran_qty) * oh_mrgn_cst_usd)
                           - oh_usdval,
                           2),
                   attribute1      =
                       ROUND (
                             ((stock_onhand + rec_oh_upd.adj_oh_qty + rec_oh_upd.adj_intran_qty) * oh_mrgn_cst_local)
                           * get_conv_rate (
                                 pv_from_currency     => store_currency,
                                 pv_to_currency       => 'USD',
                                 pv_conversion_type   => attribute4,
                                 pd_conversion_date   => TRUNC (soh_date_ts)),
                           2),
                   attribute5      =
                       ROUND (
                               ((stock_onhand + rec_oh_upd.adj_oh_qty + rec_oh_upd.adj_intran_qty) * oh_mrgn_cst_local)
                             * get_conv_rate (
                                   pv_from_currency     => store_currency,
                                   pv_to_currency       => 'USD',
                                   pv_conversion_type   => attribute4,
                                   pd_conversion_date   => TRUNC (soh_date_ts))
                           - oh_usdval,
                           2),
                   oh_usdval       =
                       ROUND (
                               ln_usd_factor
                             * ((stock_onhand + rec_oh_upd.adj_oh_qty + rec_oh_upd.adj_intran_qty) * oh_mrgn_cst_usd)
                           +   Ln_localusd_factor
                             * ((stock_onhand + rec_oh_upd.adj_oh_qty + rec_oh_upd.adj_intran_qty) * oh_mrgn_cst_local)
                             * get_conv_rate (
                                   pv_from_currency     => store_currency,
                                   pv_to_currency       => 'USD',
                                   pv_conversion_type   => attribute4,
                                   pd_conversion_date   => TRUNC (soh_date_ts))
                           +   (Ln_local_factor * ((stock_onhand + rec_oh_upd.adj_oh_qty + rec_oh_upd.adj_intran_qty) * oh_mrgn_cst_local))
                             * get_conv_rate (
                                   pv_from_currency     => store_currency,
                                   pv_to_currency       => 'USD',
                                   pv_conversion_type   => attribute4,
                                   pd_conversion_date   => TRUNC (soh_date_ts)),
                           2),
                   oh_localval     =
                       ROUND (
                               (ln_usd_factor * (stock_onhand + rec_oh_upd.adj_oh_qty + rec_oh_upd.adj_intran_qty) * oh_mrgn_cst_usd)
                             * get_conv_rate (
                                   pv_from_currency     => 'USD',
                                   pv_to_currency       => store_currency,
                                   pv_conversion_type   => attribute4,
                                   pd_conversion_date   => TRUNC (soh_date_ts))
                           +   Ln_localusd_factor
                             * ((stock_onhand + rec_oh_upd.adj_oh_qty + rec_oh_upd.adj_intran_qty) * oh_mrgn_cst_local)
                           +   Ln_local_factor
                             * ((stock_onhand + rec_oh_upd.adj_oh_qty + rec_oh_upd.adj_intran_qty) * oh_mrgn_cst_local),
                           2),
                   request_id       = gn_request_id,
                   record_status    = 'S',
                   last_update_ts   = rec_oh_upd.tran_data_ts
             WHERE stg.ROWID = rec_oh_upd.oh_rowid;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_message   := SQLERRM;
    END update_oh_records;

    /***********************************************************************************************
    ******************* Procedure for Qty <> 0 and Previous Items Insert into Staging **************
    ************************************************************************************************/

    PROCEDURE insert_oh_prev_records (x_ret_message OUT VARCHAR2)
    AS
        CURSOR stock_ohp_cur IS
            SELECT store_number, store_name, store_type,
                   store_currency, item_id, item_number,
                   0 onhand_qty, 0 in_transit_qty, 0 stock_onhand,
                   stock_avg_cost, 0 total_stock_cost, 0 oh_mrgn_cst_local,
                   0 oh_mrgn_cst_usd, 0 oh_mrgn_value_local, 0 oh_mrgn_value_usd,
                   0 oh_markup_local, 0 oh_markup_usd, ledger_id,
                   operating_unit,                                   -- RMS OU
                                   brand, style,
                   color, item_type, master_style,
                   item_size, style_desc, item_desc,
                   department, master_class, sub_class,
                   division, intro_season, current_season,
                   TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS') last_update_ts
              FROM xxdo.xxd_gl_je_ret_ic_onhand_stg_t a
             WHERE     NVL (a.ledger_id, 1) =
                       NVL (NVL (gn_ledger, a.ledger_id), 1)
                   AND NVL (a.operating_unit, 1) =
                       NVL (NVL (gn_org_unit_id_rms, a.operating_unit), 1)
                   AND a.ou_id = NVL (gn_ou_id, a.ou_id)
                   AND NVL (a.inv_org_id, 1) =
                       NVL (NVL (gn_inv_org_id, a.inv_org_id), 1)
                   AND a.store_number = NVL (gn_store_number, a.store_number)
                   AND NOT EXISTS
                           (SELECT item_id
                              FROM xxdo.xxd_gl_je_ret_ic_onhand_stg_t b
                             WHERE     a.item_id = b.item_id
                                   AND b.ou_id = NVL (gn_ou_id, b.ou_id)
                                   AND b.ou_id = a.ou_id
                                   AND b.store_number = a.store_number
                                   AND TRUNC (b.soh_date_ts) =
                                       TRUNC (gd_cut_of_date))
                   AND TRUNC (a.soh_date_ts) =
                       (SELECT TRUNC (MAX (c.soh_date_ts))
                          FROM xxdo.xxd_gl_je_ret_ic_onhand_stg_t c
                         WHERE     1 = 1
                               AND c.ou_id = NVL (gn_ou_id, c.ou_id)
                               AND c.store_number = a.store_number
                               AND c.record_status = 'P'
                               AND TRUNC (c.soh_date_ts) >
                                   TRUNC (gd_cut_of_date) - 140)
                   AND a.stock_onhand <> 0;

        --Local variables
        TYPE ret_oh_rec_type IS RECORD
        (
            store_number           NUMBER,
            store_name             VARCHAR2 (240),
            store_type             VARCHAR2 (1),
            store_currency         VARCHAR2 (15),
            item_id                NUMBER,
            item_number            VARCHAR2 (40),
            onhand_qty             NUMBER,
            in_transit_qty         NUMBER,
            stock_onhand           NUMBER,
            stock_avg_cost         NUMBER,
            total_stock_cost       NUMBER,
            oh_mrgn_cst_local      NUMBER,
            oh_mrgn_cst_usd        NUMBER,
            oh_mrgn_value_local    NUMBER,
            oh_mrgn_value_usd      NUMBER,
            oh_markup_local        NUMBER,
            oh_markup_usd          NUMBER,
            ledger_id              NUMBER,
            org_unit_id_rms        NUMBER,
            brand                  VARCHAR2 (40),
            style                  VARCHAR2 (150),
            color                  VARCHAR2 (150),
            item_type              VARCHAR2 (240),
            master_style           VARCHAR2 (40),
            item_size              VARCHAR2 (240),
            style_desc             VARCHAR2 (40),
            item_desc              VARCHAR2 (240),
            department             VARCHAR2 (40),
            master_class           VARCHAR2 (40),
            sub_class              VARCHAR2 (40),
            division               VARCHAR2 (40),
            intro_season           VARCHAR2 (240),
            current_season         VARCHAR2 (240),
            last_update_ts         DATE
        );

        TYPE ret_oh_type IS TABLE OF ret_oh_rec_type
            INDEX BY BINARY_INTEGER;

        ret_oh_rec     ret_oh_type;
        forall_err     EXCEPTION;
        PRAGMA EXCEPTION_INIT (forall_err, -24381);
        l_onhand_cnt   NUMBER;
    BEGIN
        --Delete the data from the ret_oh_rec if exists
        IF ret_oh_rec.COUNT > 0
        THEN
            ret_oh_rec.DELETE;
        END IF;

        --Opening the Cursor
        OPEN stock_ohp_cur;

        LOOP
            FETCH stock_ohp_cur
                BULK COLLECT INTO ret_oh_rec
                LIMIT gn_limit_rec;

            IF ret_oh_rec.COUNT > 0
            THEN
                --Bulk Insert of Retail Onhand Inventory data into staging table
                FORALL i IN ret_oh_rec.FIRST .. ret_oh_rec.LAST
                  SAVE EXCEPTIONS
                    INSERT INTO xxdo.xxd_gl_je_ret_ic_onhand_stg_t (
                                    store_number,
                                    store_name,
                                    store_type,
                                    store_currency,
                                    item_id,
                                    item_number,
                                    soh_date_ts,
                                    last_update_ts,
                                    as_of_date,
                                    onhand_qty,
                                    in_transit_qty,
                                    stock_onhand,
                                    stock_avg_cost,
                                    total_stock_cost,
                                    oh_mrgn_cst_local,
                                    oh_mrgn_cst_usd,
                                    oh_mrgn_value_local,
                                    oh_mrgn_value_usd,
                                    oh_markup_local,
                                    oh_markup_usd,
                                    ledger_id,
                                    operating_unit,                  -- RMS OU
                                    ou_id,                          -- SHIP OU
                                    inv_org_id,
                                    oh_journal_currency,
                                    brand,
                                    style,
                                    color,
                                    item_type,
                                    master_style,
                                    item_size,
                                    style_desc,
                                    item_desc,
                                    department,
                                    master_class,
                                    sub_class,
                                    division,
                                    intro_season,
                                    current_season,
                                    record_status,
                                    request_id,
                                    created_by,
                                    creation_date,
                                    last_updated_by,
                                    last_update_date,
                                    last_update_login)
                             VALUES (
                                        ret_oh_rec (i).store_number,
                                        ret_oh_rec (i).store_name,
                                        ret_oh_rec (i).store_type,
                                        ret_oh_rec (i).store_currency,
                                        ret_oh_rec (i).item_id,
                                        ret_oh_rec (i).item_number,
                                        gd_cut_of_date,
                                        ret_oh_rec (i).last_update_ts,
                                        gd_cut_of_date,          -- As_of_Date
                                        ret_oh_rec (i).onhand_qty,
                                        ret_oh_rec (i).in_transit_qty,
                                        ret_oh_rec (i).stock_onhand,
                                        ret_oh_rec (i).stock_avg_cost,
                                        ret_oh_rec (i).total_stock_cost,
                                        ret_oh_rec (i).oh_mrgn_cst_local,
                                        ret_oh_rec (i).oh_mrgn_cst_usd,
                                        ret_oh_rec (i).oh_mrgn_value_local,
                                        ret_oh_rec (i).oh_mrgn_value_usd,
                                        ret_oh_rec (i).oh_markup_local,
                                        ret_oh_rec (i).oh_markup_usd,
                                        ret_oh_rec (i).ledger_id,
                                        ret_oh_rec (i).org_unit_id_rms,
                                        gn_ou_id,
                                        gn_inv_org_id,
                                        CASE
                                            WHEN gv_onhand_currency = 'USD'
                                            THEN
                                                'USD'          -- USD Currency
                                            ELSE
                                                ret_oh_rec (i).store_currency -- Local Currency
                                        END,
                                        ret_oh_rec (i).brand,
                                        ret_oh_rec (i).style,
                                        ret_oh_rec (i).color,
                                        ret_oh_rec (i).item_type,
                                        ret_oh_rec (i).master_style,
                                        ret_oh_rec (i).item_size,
                                        ret_oh_rec (i).style_desc,
                                        ret_oh_rec (i).item_desc,
                                        ret_oh_rec (i).department,
                                        ret_oh_rec (i).master_class,
                                        ret_oh_rec (i).sub_class,
                                        ret_oh_rec (i).division,
                                        ret_oh_rec (i).intro_season,
                                        ret_oh_rec (i).current_season,
                                        'N',
                                        gn_request_id,
                                        gn_user_id,
                                        SYSDATE,
                                        gn_user_id,
                                        SYSDATE,
                                        gn_login_id);

                COMMIT;
                ret_oh_rec.DELETE;
            --Retail Onhand Data Cursor records Else
            ELSE
                --generate_setup_err_prc ('Either no Retail Onhand records OR already processed for the Parameters provided.');
                fnd_file.put_line (
                    fnd_file.LOG,
                    'There are no Retail Onhand Zero records for the Parameters provided.');
            --x_ret_message := 'There are no Retail Onhand records for the Parameters provided.';
            END IF;

            EXIT WHEN stock_ohp_cur%NOTFOUND;
        END LOOP;

        CLOSE stock_ohp_cur;
    EXCEPTION
        WHEN forall_err
        THEN
            FOR errs IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
            LOOP
                fnd_file.put_line (
                    fnd_file.LOG,
                    SQLERRM (-SQL%BULK_EXCEPTIONS (errs).ERROR_CODE));
            END LOOP;

            x_ret_message   := SQLERRM;
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unable to open the Onhand Insert Zero rec cursor. Please check the cursor query.'
                || SQLERRM);

            --Close the cursor
            CLOSE stock_ohp_cur;

            x_ret_message   := SQLERRM;
    END insert_oh_prev_records;

    /***********************************************************************************************
    **************************** Procedure for update Valueset to Staging **************************
    ************************************************************************************************/

    PROCEDURE update_kff_attributes (x_ret_message OUT VARCHAR2)
    IS
        CURSOR c_get_sale_vs_data IS
            SELECT a.ROWID
                       sale_rowid,
                   a.store_number,
                   DECODE (
                       a.brand,
                       'ALL BRAND', '1000',
                       (SELECT flex_value
                          FROM fnd_flex_value_sets ffv, fnd_flex_values_vl ffvl
                         WHERE     ffv.flex_value_set_name = 'DO_GL_BRAND'
                               AND ffv.flex_value_set_id =
                                   ffvl.flex_value_set_id
                               AND SYSDATE BETWEEN NVL (
                                                       ffvl.start_date_active,
                                                       SYSDATE)
                                               AND NVL (ffvl.end_date_active,
                                                        SYSDATE + 1)
                               AND ffvl.enabled_flag = 'Y'
                               AND UPPER (ffvl.description) = a.brand))
                       brand,
                   ffvl.*
              FROM xxdo.xxd_gl_je_ret_ic_markup_stg_t a, apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
             WHERE     1 = 1
                   AND a.request_id = gn_request_id
                   AND ffvl.flex_value = a.store_number
                   AND ffvs.flex_value_set_name = 'XXD_GL_JE_MARKUP_VS'
                   AND ffvs.flex_value_set_id = ffvl.flex_value_set_id
                   AND SYSDATE BETWEEN NVL (ffvl.start_date_active, SYSDATE)
                                   AND NVL (ffvl.end_date_active,
                                            SYSDATE + 1)
                   AND ffvl.enabled_flag = 'Y';

        CURSOR c_get_oh_vs_data IS
            SELECT a.ROWID
                       oh_rowid,
                   a.store_number,
                   DECODE (
                       a.brand,
                       'ALL BRAND', '1000',
                       (SELECT flex_value
                          FROM fnd_flex_value_sets ffv, fnd_flex_values_vl ffvl
                         WHERE     ffv.flex_value_set_name = 'DO_GL_BRAND'
                               AND ffv.flex_value_set_id =
                                   ffvl.flex_value_set_id
                               AND SYSDATE BETWEEN NVL (
                                                       ffvl.start_date_active,
                                                       SYSDATE)
                                               AND NVL (ffvl.end_date_active,
                                                        SYSDATE + 1)
                               AND ffvl.enabled_flag = 'Y'
                               AND UPPER (ffvl.description) = a.brand))
                       brand,
                   ffvl.*
              FROM xxdo.xxd_gl_je_ret_ic_onhand_stg_t a, apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
             WHERE     1 = 1
                   AND a.request_id = gn_request_id
                   AND ffvs.flex_value_set_name = 'XXD_GL_JE_MARKUP_VS'
                   AND ffvs.flex_value_set_id = ffvl.flex_value_set_id
                   AND ffvl.flex_value = a.store_number
                   AND SYSDATE BETWEEN NVL (ffvl.start_date_active, SYSDATE)
                                   AND NVL (ffvl.end_date_active,
                                            SYSDATE + 1)
                   AND ffvl.enabled_flag = 'Y';

        l_ledger_id           NUMBER;
        l_oh_ledger_id        NUMBER;
        l_mt_oh_ledger_id     NUMBER;
        l_ou_id               NUMBER;
        l_org_unit_id         NUMBER;
        l_markup_method       VARCHAR2 (20);
        l_sales_company       NUMBER;
        l_geo                 NUMBER;
        l_channel             NUMBER;
        l_cost_center         NUMBER;
        l_sales_dr_acct       NUMBER;
        l_sales_dr_acct_ret   NUMBER;
        l_sales_cr_acct       NUMBER;
        l_sales_cr_acct_ret   NUMBER;
        l_onhand_company      NUMBER;
        l_onhand_dr_acct      NUMBER;
        l_onhand_cr_acct      NUMBER;
    BEGIN
        FOR rec_sale IN c_get_sale_vs_data
        LOOP
            l_ledger_id           := NULL;
            l_ou_id               := NULL;
            l_org_unit_id         := NULL;
            l_markup_method       := NULL;
            l_sales_company       := NULL;
            l_geo                 := NULL;
            l_channel             := NULL;
            l_cost_center         := NULL;
            l_sales_dr_acct       := NULL;
            l_sales_dr_acct_ret   := NULL;
            l_sales_cr_acct       := NULL;
            l_sales_cr_acct_ret   := NULL;

            BEGIN
                SELECT DISTINCT
                       a.operating_unit,
                       c.org_unit_id,
                       DECODE (region,
                               'CA', 'HOLDING',
                               'CN', 'HOLDING',
                               'JP', 'HOLDING',
                               'HK', 'DIRECT',
                               'FR', 'DIRECT',
                               'UK', 'DIRECT') markup_method,
                       (SELECT gl_code
                          FROM rms13prod.deck_master_config@xxdo_retail_rms
                         WHERE     master_value = b.master_value
                               AND ref_1 = 'RESA'
                               AND entity = 'COMPANY') sales_company,
                       (SELECT gl_code
                          FROM rms13prod.deck_master_config@xxdo_retail_rms
                         WHERE     master_value = b.master_value
                               AND entity = 'GEO') geo,
                       c.store_name3 channel,
                       c.store_name_secondary cost_center,
                       '54995' sales_dr_acct,
                       '54006' sales_dr_acct_return,
                       --null intercom,-- '1000' FUTURE
                       '54001' sales_cr_acct,
                       '54995' sales_cr_acct_return
                  INTO l_ou_id, l_org_unit_id, l_markup_method, l_sales_company,
                              l_geo, l_channel, l_cost_center,
                              l_sales_dr_acct, l_sales_dr_acct_ret, l_sales_cr_acct,
                              l_sales_cr_acct_ret
                  FROM apps.xxd_retail_stores_v a, rms13prod.deck_master_config@xxdo_retail_rms b, rms13prod.store@xxdo_retail_rms c
                 WHERE     1 = 1
                       AND a.rms_store_id = c.store
                       AND b.master_value = TO_CHAR (c.tsf_entity_id)
                       AND a.store_type IS NOT NULL
                       AND c.store_close_date IS NULL
                       AND a.rms_store_id = rec_sale.store_number;

                BEGIN
                    SELECT ffvl.attribute6
                      INTO l_ledger_id
                      FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                     WHERE     1 = 1
                           AND ffvs.flex_value_set_name = 'DO_GL_COMPANY'
                           AND ffvs.flex_value_set_id =
                               ffvl.flex_value_set_id
                           AND ffvl.flex_value = l_sales_company;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                END;

                UPDATE xxdo.xxd_gl_je_ret_ic_markup_stg_t stg
                   SET ledger_id = NVL (l_ledger_id, ledger_id), ou_id = NVL (NVL (gn_ou_id, rec_sale.attribute1), l_ou_id), inv_org_id = NVL (NVL (gn_inv_org_id, rec_sale.attribute2), l_org_unit_id),
                       markup_type = NVL (rec_sale.attribute3, l_markup_method), sales_company = NVL (rec_sale.attribute4, l_sales_company), sales_dr_brand = NVL (rec_sale.attribute5, rec_sale.brand),
                       sales_dr_geo = NVL (rec_sale.attribute6, l_geo), sales_dr_channel = NVL (rec_sale.attribute7, l_channel), sales_dr_dept = NVL (rec_sale.attribute8, l_cost_center),
                       sales_dr_account = NVL (rec_sale.attribute9, l_sales_dr_acct), sales_dr_acct_return = NVL (rec_sale.attribute10, l_sales_dr_acct_ret), sales_dr_intercom = NVL (rec_sale.attribute11, l_sales_company),
                       sales_cr_brand = NVL (rec_sale.attribute12, rec_sale.brand), sales_cr_geo = NVL (rec_sale.attribute13, l_geo), sales_cr_channel = NVL (rec_sale.attribute14, l_channel),
                       sales_cr_dept = NVL (rec_sale.attribute15, l_cost_center), sales_cr_account = NVL (rec_sale.attribute16, l_sales_cr_acct), sales_cr_acct_return = NVL (rec_sale.attribute17, l_sales_cr_acct_ret),
                       sales_cr_intercom = NVL (rec_sale.attribute18, l_sales_company), sales_debit_code_comb = NVL (rec_sale.attribute4, l_sales_company) || '.' || NVL (rec_sale.attribute5, rec_sale.brand) || '.' || NVL (rec_sale.attribute6, l_geo) || '.' || NVL (rec_sale.attribute7, l_channel) || '.' || NVL (rec_sale.attribute8, l_cost_center) || '.' || NVL (rec_sale.attribute9, l_sales_dr_acct) || '.' || NVL (rec_sale.attribute11, l_sales_company) || '.' || '1000', sales_credit_code_comb = NVL (rec_sale.attribute4, l_sales_company) || '.' || NVL (rec_sale.attribute12, rec_sale.brand) || '.' || NVL (rec_sale.attribute13, l_geo) || '.' || NVL (rec_sale.attribute14, l_channel) || '.' || NVL (rec_sale.attribute15, l_cost_center) || '.' || NVL (rec_sale.attribute16, l_sales_cr_acct) || '.' || NVL (rec_sale.attribute18, l_sales_company) || '.' || '1000',
                       return_debit_code_comb = NVL (rec_sale.attribute4, l_sales_company) || '.' || NVL (rec_sale.attribute5, rec_sale.brand) || '.' || NVL (rec_sale.attribute6, l_geo) || '.' || NVL (rec_sale.attribute7, l_channel) || '.' || NVL (rec_sale.attribute8, l_cost_center) || '.' || NVL (rec_sale.attribute10, l_sales_dr_acct_ret) || '.' || NVL (rec_sale.attribute11, l_sales_company) || '.' || '1000', return_credit_code_comb = NVL (rec_sale.attribute4, l_sales_company) || '.' || NVL (rec_sale.attribute12, rec_sale.brand) || '.' || NVL (rec_sale.attribute13, l_geo) || '.' || NVL (rec_sale.attribute14, l_channel) || '.' || NVL (rec_sale.attribute15, l_cost_center) || '.' || NVL (rec_sale.attribute17, l_sales_cr_acct_ret) || '.' || NVL (rec_sale.attribute18, l_sales_company) || '.' || '1000'
                 WHERE     stg.ROWID = rec_sale.sale_rowid
                       AND stg.request_id = gn_request_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            --                fnd_file.put_line(fnd_file.log,'Error with update in Loop - '||SQLERRM);
            END;
        END LOOP;

        COMMIT;

        FOR rec_oh IN c_get_oh_vs_data
        LOOP
            l_oh_ledger_id      := NULL;
            l_mt_oh_ledger_id   := NULL;
            l_ou_id             := NULL;
            l_org_unit_id       := NULL;
            l_markup_method     := NULL;
            l_onhand_company    := NULL;
            l_geo               := NULL;
            l_channel           := NULL;
            l_cost_center       := NULL;
            l_onhand_dr_acct    := NULL;
            l_onhand_cr_acct    := NULL;

            BEGIN
                SELECT DISTINCT
                       (SELECT ledger_id
                          FROM apps.gl_ledgers
                         WHERE UPPER (name) = UPPER (rec_oh.attribute33)),
                       a.operating_unit,
                       c.org_unit_id,
                       DECODE (region,
                               'CA', 'HOLDING',
                               'CN', 'HOLDING',
                               'JP', 'HOLDING',
                               'HK', 'DIRECT',
                               'FR', 'DIRECT',
                               'UK', 'DIRECT') markup_method,
                       (SELECT gl_code
                          FROM rms13prod.deck_master_config@xxdo_retail_rms
                         WHERE     master_value = b.master_value
                               AND ref_1 = 'RETEK'
                               AND entity = 'COMPANY') onhand_company,
                       (SELECT gl_code
                          FROM rms13prod.deck_master_config@xxdo_retail_rms
                         WHERE     master_value = b.master_value
                               AND entity = 'GEO') geo,
                       c.store_name3 channel,
                       c.store_name_secondary cost_center,
                       '51150' onhand_dr_acct,
                       '11592' onhand_cr_acct
                  INTO l_oh_ledger_id, l_ou_id, l_org_unit_id, l_markup_method,
                                     l_onhand_company, l_geo, l_channel,
                                     l_cost_center, l_onhand_dr_acct, l_onhand_cr_acct
                  FROM apps.xxd_retail_stores_v a, rms13prod.deck_master_config@xxdo_retail_rms b, rms13prod.store@xxdo_retail_rms c
                 WHERE     1 = 1
                       AND a.rms_store_id = c.store
                       AND b.master_value = TO_CHAR (c.tsf_entity_id)
                       AND a.store_type IS NOT NULL
                       AND c.store_close_date IS NULL
                       AND a.rms_store_id = rec_oh.store_number;

                BEGIN
                    SELECT (SELECT ledger_id
                              FROM gl_ledgers
                             WHERE UPPER (name) = UPPER (ffvl.attribute1))
                      INTO l_mt_oh_ledger_id
                      FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                     WHERE     1 = 1
                           AND ffvs.flex_value_set_name =
                               'XXD_GL_JE_IC_MARKUP_TYPES'
                           AND ffvs.flex_value_set_id =
                               ffvl.flex_value_set_id
                           AND flex_value = 'ONHAND'
                           AND SYSDATE BETWEEN NVL (ffvl.start_date_active,
                                                    SYSDATE)
                                           AND NVL (ffvl.end_date_active,
                                                    SYSDATE + 1)
                           AND ffvl.enabled_flag = 'Y';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_mt_oh_ledger_id   := NULL;
                END;

                UPDATE xxdo.xxd_gl_je_ret_ic_onhand_stg_t ohstg
                   SET ledger_id = NVL (NVL (l_oh_ledger_id, l_mt_oh_ledger_id), ledger_id), ou_id = NVL (NVL (gn_ou_id, rec_oh.attribute1), l_ou_id), inv_org_id = NVL (NVL (gn_inv_org_id, rec_oh.attribute2), l_org_unit_id),
                       markup_type = NVL (rec_oh.attribute3, l_markup_method), oh_company = NVL (rec_oh.attribute19, l_onhand_company), oh_dr_brand = NVL (rec_oh.attribute20, rec_oh.brand),
                       oh_dr_geo = NVL (rec_oh.attribute21, l_geo), oh_dr_channel = NVL (rec_oh.attribute22, l_channel), oh_dr_dept = NVL (rec_oh.attribute23, l_cost_center),
                       oh_dr_account = NVL (rec_oh.attribute24, l_onhand_dr_acct), oh_dr_intercom = NVL (rec_oh.attribute25, l_onhand_company), oh_cr_brand = NVL (rec_oh.attribute26, rec_oh.brand),
                       oh_cr_geo = NVL (rec_oh.attribute27, l_geo), oh_cr_channel = NVL (rec_oh.attribute28, l_channel), oh_cr_dept = NVL (rec_oh.attribute29, l_cost_center),
                       oh_cr_account = NVL (rec_oh.attribute30, l_onhand_cr_acct), oh_cr_intercom = NVL (rec_oh.attribute31, l_onhand_company), oh_debit_code_comb = NVL (rec_oh.attribute19, l_onhand_company) || '.' || NVL (rec_oh.attribute20, rec_oh.brand) || '.' || NVL (rec_oh.attribute21, l_geo) || '.' || NVL (rec_oh.attribute22, l_channel) || '.' || NVL (rec_oh.attribute23, l_cost_center) || '.' || NVL (rec_oh.attribute24, l_onhand_dr_acct) || '.' || NVL (rec_oh.attribute25, l_onhand_company) || '.' || '1000',
                       oh_credit_code_comb = NVL (rec_oh.attribute19, l_onhand_company) || '.' || NVL (rec_oh.attribute26, rec_oh.brand) || '.' || NVL (rec_oh.attribute27, l_geo) || '.' || NVL (rec_oh.attribute28, l_channel) || '.' || NVL (rec_oh.attribute29, l_cost_center) || '.' || NVL (rec_oh.attribute30, l_onhand_cr_acct) || '.' || NVL (rec_oh.attribute31, l_onhand_company) || '.' || '1000'
                 WHERE     ohstg.ROWID = rec_oh.oh_rowid
                       AND ohstg.request_id = gn_request_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            --                fnd_file.put_line(fnd_file.log,'Error with update in Loop - '||SQLERRM);
            END;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_message   := SQLERRM;
    END update_kff_attributes;

    /***********************************************************************************************
    **************************** Function to get period name ***************************************
    ************************************************************************************************/

    FUNCTION get_period_name (p_ledger_id IN NUMBER, p_gl_date IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_period_name   VARCHAR2 (100);
    BEGIN
        BEGIN
            SELECT period_name
              INTO lv_period_name
              FROM gl_period_statuses
             WHERE     application_id = 101
                   AND ledger_id = p_ledger_id
                   AND closing_status = 'O'
                   AND p_gl_date BETWEEN start_date AND end_date;

            fnd_file.put_line (fnd_file.LOG,
                               'Period Name is:' || lv_period_name);
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       ' Open Period is not found for Date : '
                    || p_gl_date
                    || CHR (9)
                    || ' ledger ID = '
                    || p_ledger_id);

                lv_period_name   := NULL;
            WHEN TOO_MANY_ROWS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       ' Multiple Open periods found for date : '
                    || p_gl_date
                    || CHR (9)
                    || ' ledger ID = '
                    || p_ledger_id);

                lv_period_name   := NULL;
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       ' Exception found while getting open period date for  : '
                    || p_gl_date
                    || CHR (9)
                    || SQLERRM);

                lv_period_name   := NULL;
        END;

        RETURN lv_period_name;
    END get_period_name;

    /***********************************************************************************************
    **************************** Function to get journal source for Markup *************************
    ************************************************************************************************/

    FUNCTION get_js_markup (p_markup_source VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_je_source_markup   VARCHAR2 (100);
    BEGIN
        BEGIN
            SELECT user_je_source_name
              INTO lv_je_source_markup
              FROM gl_je_sources
             WHERE user_je_source_name = p_markup_source AND language = 'US';

            fnd_file.put_line (
                fnd_file.LOG,
                'Journal Source for Markup is: ' || lv_je_source_markup);
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_je_source_markup   := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Failed to fetch Journal source for Markup ' || SQLERRM);
        END;

        RETURN lv_je_source_markup;
    END get_js_markup;

    /***********************************************************************************************
    **************************** Function to get journal source for Elimination ********************
    ************************************************************************************************/

    FUNCTION get_js_elimination (p_onhand_source VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_je_source_elimination   VARCHAR2 (100);
    BEGIN
        BEGIN
            SELECT user_je_source_name
              INTO lv_je_source_elimination
              FROM gl_je_sources
             WHERE user_je_source_name = p_onhand_source AND language = 'US';

            fnd_file.put_line (
                fnd_file.LOG,
                   'Journal Source for Elimination is: '
                || lv_je_source_elimination);
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_je_source_elimination   := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Failed to fetch Journal source for elimination '
                    || SQLERRM);
        END;

        RETURN lv_je_source_elimination;
    END get_js_elimination;

    /***********************************************************************************************
    **************************** Function to get journal Category **********************************
    ************************************************************************************************/

    FUNCTION get_journal_cat_markup (p_markup_category VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_je_cat_markup   VARCHAR2 (200);
    BEGIN
        BEGIN
            SELECT user_je_category_name
              INTO lv_je_cat_markup
              FROM gl_je_categories
             WHERE     user_je_category_name = p_markup_category
                   AND language = 'US';

            fnd_file.put_line (
                fnd_file.LOG,
                'Journal Category for Markup is: ' || lv_je_cat_markup);
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_je_cat_markup   := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Failed to fetch Journal Category for Markup ' || SQLERRM);
        END;

        RETURN lv_je_cat_markup;
    END get_journal_cat_markup;

    /***********************************************************************************************
    *************************** Function to get journal Category Elimination ***********************
    ************************************************************************************************/

    FUNCTION get_journal_cat_elimination (p_onhand_category VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_je_cat_elimination   VARCHAR2 (200);
    BEGIN
        BEGIN
            SELECT user_je_category_name
              INTO lv_je_cat_elimination
              FROM gl_je_categories
             WHERE     user_je_category_name = p_onhand_category
                   AND language = 'US';

            fnd_file.put_line (
                fnd_file.LOG,
                   'Journal Category for elimination is: '
                || lv_je_cat_elimination);
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_je_cat_elimination   := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Failed to fetch Journal Category for elimination '
                    || SQLERRM);
        END;

        RETURN lv_je_cat_elimination;
    END get_journal_cat_elimination;

    /***********************************************************************************************
    ************************** Function to Get Conversion Rate *************************************
    ************************************************************************************************/

    FUNCTION get_conv_rate (pv_from_currency IN VARCHAR2, pv_to_currency IN VARCHAR2, pv_conversion_type IN VARCHAR2
                            , pd_conversion_date IN DATE)
        RETURN NUMBER
    IS
        ln_conversion_rate   NUMBER := 0;
    BEGIN
        SELECT gdr.conversion_rate
          INTO ln_conversion_rate
          FROM apps.gl_daily_rates gdr
         WHERE     1 = 1
               AND gdr.conversion_type = pv_conversion_type
               AND gdr.from_currency = pv_from_currency
               AND gdr.to_currency = pv_to_currency
               AND gdr.conversion_date = pd_conversion_date;

        RETURN ln_conversion_rate;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log ('Error in GET_CONV_RATE Procedure -' || SQLERRM);
            ln_conversion_rate   := 0;
            RETURN ln_conversion_rate;
    END get_conv_rate;

    /***********************************************************************************************
    ************************** Function to Get Fixed Margin Percentage *****************************
    ************************************************************************************************/

    FUNCTION get_fixed_margin_pct (pn_ou_id        IN NUMBER,
                                   pv_brand        IN VARCHAR2,
                                   pv_store_type   IN VARCHAR2)
        RETURN NUMBER
    IS
        ln_fixed_margin_pct   NUMBER := 0;
    BEGIN
        BEGIN
            SELECT margin_pct
              INTO ln_fixed_margin_pct
              FROM (SELECT TO_NUMBER (ffvl.attribute4) margin_pct, RANK () OVER (PARTITION BY ffvl.attribute1 ORDER BY ffvl.attribute1, ffvl.attribute2, ffvl.attribute3 NULLS LAST) rnk
                      FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                     WHERE     1 = 1
                           AND ffvs.flex_value_set_name =
                               'XXD_WMS_RET_INV_FIXED_MARGIN'
                           AND ffvs.flex_value_set_id =
                               ffvl.flex_value_set_id
                           AND TO_NUMBER (ffvl.attribute1) = pn_ou_id
                           AND ffvl.enabled_flag = 'Y'
                           AND SYSDATE BETWEEN NVL (ffvl.start_date_active,
                                                    SYSDATE)
                                           AND NVL (ffvl.end_date_active,
                                                    SYSDATE)
                           AND CASE
                                   WHEN ffvl.attribute2 IS NOT NULL
                                   THEN
                                       ffvl.attribute2
                                   ELSE
                                       pv_brand
                               END =
                               pv_brand
                           AND CASE
                                   WHEN ffvl.attribute3 IS NOT NULL
                                   THEN
                                       ffvl.attribute3
                                   ELSE
                                       pv_store_type
                               END =
                               pv_store_type) xx
             WHERE rnk = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_fixed_margin_pct   := 0;
                write_log (
                       'Error in getting margin percent from XXD_WMS_RET_INV_FIXED_MARGIN value set for OU='
                    || pn_ou_id
                    || ', BRAND='
                    || pv_brand
                    || ' and STORE_TYPE='
                    || pv_store_type
                    || '. Error is: '
                    || SQLERRM);
        END;

        RETURN ln_fixed_margin_pct;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log (
                'Error in GET_FIXED_MARGIN_PCT Procedure -' || SQLERRM);
            ln_fixed_margin_pct   := 0;
            RETURN ln_fixed_margin_pct;
    END get_fixed_margin_pct;

    /***********************************************************************************************
    ************************ Procedure to Get HOLDING - ONHAND Markup ******************************
    ************************************************************************************************/

    PROCEDURE get_holding_markup_values (
        p_orgn_id               IN     NUMBER,
        p_inventory_item_id     IN     NUMBER,
        p_transaction_date      IN     DATE,
        xn_trx_mrgn_cst_usd        OUT NUMBER,
        xn_trx_mrgn_cst_local      OUT NUMBER)
    IS
    BEGIN
        BEGIN
            SELECT avg_mrgn_cst_local, avg_mrgn_cst_usd
              INTO xn_trx_mrgn_cst_local, xn_trx_mrgn_cst_usd
              FROM (  SELECT *
                        FROM xxd_ont_po_margin_calc_t a
                       WHERE     1 = 1
                             AND destination_organization_id = p_orgn_id
                             AND inventory_item_id = p_inventory_item_id
                             AND transaction_date <= p_transaction_date
                    ORDER BY a.transaction_date DESC)
             WHERE ROWNUM = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                xn_trx_mrgn_cst_local   := 0;
                xn_trx_mrgn_cst_usd     := 0;
        -- fnd_file.put_line(fnd_file.log, 'Failed to get Sales Markup:' || SQLERRM);
        END;
    END get_holding_markup_values;

    /***********************************************************************************************
    ************************* Procedure to Get DIRECT Method ONHAND Markup **************************
    ************************************************************************************************/

    PROCEDURE get_direct_oh_markup_values (pn_request_id IN NUMBER, pn_ou_id IN NUMBER, pn_store_number IN NUMBER
                                           , pn_inv_item_id IN NUMBER, xn_margin_store_curr_final OUT NUMBER, xn_margin_usd_final OUT NUMBER)
    IS
        --Cursors Declaration
        --Cursor to get the items for which the Margin has to be calculated and displayed in report

        CURSOR src_cur IS
            SELECT stg.ROWID, stg.*
              FROM xxdo.xxd_gl_je_ret_ic_onhand_stg_t stg
             WHERE     1 = 1
                   AND stg.request_id = pn_request_id
                   AND stg.operating_unit = pn_ou_id
                   AND stg.store_number =
                       NVL (pn_store_number, stg.store_number)
                   AND stg.item_id = NVL (pn_inv_item_id, stg.item_id);

        --Cursor to get Shipment details
        CURSOR ship_cur (cn_inv_item_id IN NUMBER, cn_store_number IN NUMBER, cn_ou_id IN NUMBER
                         , cd_as_of_date IN DATE)
        IS
              SELECT oola.org_id, oola.ordered_item, mmt.transaction_id,
                     mmt.transaction_date, ABS (mmt.transaction_quantity) shipment_qty, mmt.actual_cost,
                     oola.unit_selling_price, oola.unit_list_price, stv.store_name,
                     mmt.organization_id, ooha.order_number, stv.store_type,
                     stv.currency_code store_currency_code, ooha.transactional_curr_code sales_ord_curr_code, gl.currency_code inv_org_curr_code
                FROM apps.fnd_flex_value_sets ffvs_ind, apps.fnd_flex_values ffv_ind, apps.fnd_flex_values_tl ffvt_ind,
                     apps.fnd_flex_value_sets ffvs_dep, apps.fnd_flex_values ffv_dep, apps.fnd_flex_values_tl ffvt_dep,
                     apps.hr_operating_units hrou, apps.mtl_parameters mp, apps.hr_organization_information hoi,
                     apps.gl_ledgers gl, apps.mtl_material_transactions mmt, apps.oe_order_lines_all oola,
                     apps.oe_order_headers_all ooha, apps.xxd_retail_stores_v stv
               WHERE     1 = 1
                     AND hrou.organization_id = cn_ou_id
                     AND hrou.name = ffv_ind.flex_value
                     AND mp.organization_code = ffv_dep.flex_value
                     AND hoi.organization_id = mp.organization_id
                     -- AND (gn_inv_org_id IS NULL OR mp.organization_id = gn_inv_org_id)
                     AND hoi.org_information_context = 'Accounting Information'
                     AND TO_NUMBER (hoi.org_information1) = gl.ledger_id
                     AND mmt.inventory_item_id = cn_inv_item_id
                     AND mmt.organization_id = mp.organization_id
                     AND mmt.transaction_date <= cd_as_of_date
                     AND mmt.transaction_type_id = 33      --Sales order issue
                     AND mmt.transaction_source_type_id = 2      --Sales order
                     AND mmt.trx_source_line_id = oola.line_id
                     AND mmt.organization_id = oola.ship_from_org_id
                     AND mmt.inventory_item_id = oola.inventory_item_id
                     AND oola.org_id = cn_ou_id
                     AND oola.header_id = ooha.header_id
                     AND ooha.sold_to_org_id = stv.ra_customer_id
                     AND stv.rms_store_id = cn_store_number
                     AND ffvs_ind.flex_value_set_id = ffv_ind.flex_value_set_id
                     AND ffv_ind.flex_value_id = ffvt_ind.flex_value_id
                     AND ffvt_ind.language = USERENV ('LANG')
                     AND UPPER (ffvs_ind.flex_value_set_name) =
                         'XXD_WMS_RET_INV_EBS_OU'
                     AND ffvs_ind.flex_value_set_id =
                         ffvs_dep.parent_flex_value_set_id
                     AND ffv_ind.flex_value = ffv_dep.parent_flex_value_low
                     AND ffvs_dep.flex_value_set_id = ffv_dep.flex_value_set_id
                     AND ffv_dep.flex_value_id = ffvt_dep.flex_value_id
                     AND ffvt_dep.language = USERENV ('LANG')
                     AND ffv_ind.enabled_flag = 'Y'
                     AND SYSDATE BETWEEN NVL (ffv_ind.start_date_active,
                                              SYSDATE)
                                     AND NVL (ffv_ind.end_date_active, SYSDATE)
                     AND ffv_dep.enabled_flag = 'Y'
                     AND SYSDATE BETWEEN NVL (ffv_dep.start_date_active,
                                              SYSDATE)
                                     AND NVL (ffv_dep.end_date_active, SYSDATE)
            ORDER BY mmt.transaction_date DESC, mmt.transaction_id DESC;

        ln_purge_days                 NUMBER := 60;
        lv_err_msg                    VARCHAR2 (4000) := NULL;
        lv_sql_stmt                   VARCHAR2 (32000) := NULL;
        lv_select_clause              VARCHAR2 (5000) := NULL;
        lv_from_clause                VARCHAR2 (5000) := NULL;
        lv_where_clause               VARCHAR2 (5000) := NULL;
        lv_store_cond                 VARCHAR2 (1000) := NULL;
        lv_org_unit_cond              VARCHAR2 (1000) := NULL;
        lv_brand_cond                 VARCHAR2 (1000) := NULL;
        lv_style_cond                 VARCHAR2 (1000) := NULL;
        lv_style_color_cond           VARCHAR2 (1000) := NULL;
        lv_sku_cond                   VARCHAR2 (1000) := NULL;
        lv_ou_name                    VARCHAR2 (120) := NULL;
        ln_remaining_soh              NUMBER := 0;
        ln_qty                        NUMBER := 0;
        ln_chg_qty                    NUMBER := 0;
        lv_ship_qty_met_soh           VARCHAR2 (1) := 'N';
        ln_conv_rate                  NUMBER := 0;
        ln_conv_rate_usd              NUMBER := 0;
        ln_margin_store_curr          NUMBER := 0;
        ln_margin_usd                 NUMBER := 0;
        ln_margin_store_curr_final    NUMBER := 0;
        ln_margin_usd_final           NUMBER := 0;
        ln_avg_margin_st_curr_final   NUMBER := 0;
        ln_avg_margin_usd_final       NUMBER := 0;
        ln_loop_ctr                   NUMBER := 0;
        lv_shipments_exists           VARCHAR2 (1) := 'N';
        ln_conv_rate_to_trx_curr      NUMBER := 0;
        ln_actual_cost_order_curr     NUMBER := 0;
        ln_fixed_margin_pct           NUMBER := 0;
        ld_as_of_date                 DATE;
        lv_org_unit_id_rms            VARCHAR2 (120) := NULL;
        lv_comp                       VARCHAR2 (100);
        lv_geo                        VARCHAR2 (100);
        lv_interco                    VARCHAR2 (100);
        lv_nat_acc                    VARCHAR2 (100);
        lv_ret_message                VARCHAR2 (4000) := NULL;
        lv_file_name                  VARCHAR2 (100);
        lv_ret_code                   VARCHAR2 (30) := NULL;
        ln_tot_sales_mrgn_cst_usd     NUMBER := 0;
        ln_rec_count                  NUMBER;
        ln_org_count                  NUMBER;
        ln_item_cnt                   NUMBER;
        l_max_run_date                DATE := NULL;
        l_max_mrgn_cst_local          NUMBER;
        l_max_mrgn_cst_usd            NUMBER;
        ln_tot_ic_margin_usd          NUMBER;
    BEGIN
        BEGIN
            SELECT soh_date_ts, oh_mrgn_cst_local, oh_mrgn_cst_usd
              INTO l_max_run_date, l_max_mrgn_cst_local, l_max_mrgn_cst_usd
              FROM (SELECT a.*, ROW_NUMBER () OVER (ORDER BY soh_date_ts DESC) rn
                      FROM xxdo.xxd_gl_je_ret_ic_onhand_stg_t a
                     WHERE     a.store_number =
                               NVL (pn_store_number, a.store_number)
                           AND a.item_id = NVL (pn_inv_item_id, a.item_id)
                           AND record_status = 'P'
                           AND TRUNC (a.soh_date_ts) >= TRUNC (SYSDATE) - 140)
             WHERE rn = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_max_run_date         := NULL;
                l_max_mrgn_cst_local   := NULL;
                l_max_mrgn_cst_usd     := NULL;
        END;

        SELECT COUNT (*)
          INTO ln_item_cnt
          FROM apps.fnd_flex_value_sets ffvs_ind, apps.fnd_flex_values ffv_ind, apps.fnd_flex_values_tl ffvt_ind,
               apps.fnd_flex_value_sets ffvs_dep, apps.fnd_flex_values ffv_dep, apps.fnd_flex_values_tl ffvt_dep,
               apps.hr_operating_units hrou, apps.mtl_parameters mp, apps.hr_organization_information hoi,
               apps.gl_ledgers gl, apps.mtl_material_transactions mmt, apps.oe_order_lines_all oola,
               apps.oe_order_headers_all ooha, apps.xxd_retail_stores_v stv
         WHERE     1 = 1
               AND hrou.organization_id = pn_ou_id
               AND hrou.name = ffv_ind.flex_value
               AND mp.organization_code = ffv_dep.flex_value
               AND hoi.organization_id = mp.organization_id
               --AND (gn_inv_org_id IS NULL OR mp.organization_id = gn_inv_org_id)
               AND hoi.org_information_context = 'Accounting Information'
               AND TO_NUMBER (hoi.org_information1) = gl.ledger_id
               AND mmt.inventory_item_id = pn_inv_item_id
               AND mmt.organization_id = mp.organization_id
               AND mmt.transaction_date >
                   NVL (l_max_run_date, gd_cut_of_date)
               AND mmt.transaction_type_id = 33            --Sales order issue
               AND mmt.transaction_source_type_id = 2            --Sales order
               AND mmt.trx_source_line_id = oola.line_id
               AND mmt.organization_id = oola.ship_from_org_id
               AND mmt.inventory_item_id = oola.inventory_item_id
               AND oola.org_id = pn_ou_id
               AND oola.header_id = ooha.header_id
               AND ooha.sold_to_org_id = stv.ra_customer_id
               AND stv.rms_store_id = pn_store_number
               AND ffvs_ind.flex_value_set_id = ffv_ind.flex_value_set_id
               AND ffv_ind.flex_value_id = ffvt_ind.flex_value_id
               AND ffvt_ind.language = USERENV ('LANG')
               AND UPPER (ffvs_ind.flex_value_set_name) =
                   'XXD_WMS_RET_INV_EBS_OU'
               AND ffvs_ind.flex_value_set_id =
                   ffvs_dep.parent_flex_value_set_id
               AND ffv_ind.flex_value = ffv_dep.parent_flex_value_low
               AND ffvs_dep.flex_value_set_id = ffv_dep.flex_value_set_id
               AND ffv_dep.flex_value_id = ffvt_dep.flex_value_id
               AND ffvt_dep.language = USERENV ('LANG')
               AND ffv_ind.enabled_flag = 'Y'
               AND SYSDATE BETWEEN NVL (ffv_ind.start_date_active, SYSDATE)
                               AND NVL (ffv_ind.end_date_active, SYSDATE)
               AND ffv_dep.enabled_flag = 'Y'
               AND SYSDATE BETWEEN NVL (ffv_dep.start_date_active, SYSDATE)
                               AND NVL (ffv_dep.end_date_active, SYSDATE)
               AND ROWNUM = 1;

        IF ln_item_cnt = 0
        THEN
            xn_margin_store_curr_final   := l_max_mrgn_cst_local;
            xn_margin_usd_final          := l_max_mrgn_cst_usd;
        END IF;

        -- ELSE
        IF ln_item_cnt <> 0 OR l_max_mrgn_cst_usd IS NULL -- OR xn_margin_usd_final IS NULL
        THEN
            FOR src_rec IN src_cur
            LOOP
                --Assign total stock on hand to ln_remaining_soh variable
                ln_remaining_soh              := ABS (src_rec.stock_onhand);
                lv_ship_qty_met_soh           := 'N';
                ln_margin_store_curr_final    := 0;
                ln_margin_usd_final           := 0;
                ln_avg_margin_st_curr_final   := 0;
                ln_avg_margin_usd_final       := 0;
                ln_tot_ic_margin_usd          := 0;

                --Open the shipments cursor for the item and the store number and get the shipment details in the descending order of transaction date in MMT
                FOR ship_rec
                    IN ship_cur (cn_inv_item_id => src_rec.item_id, cn_store_number => src_rec.store_number, cn_ou_id => src_rec.ou_id
                                 , cd_as_of_date => src_rec.soh_date_ts)
                LOOP
                    lv_shipments_exists    := 'Y'; --If the Shipment exists(If we enter the ship_cur loop), set to Yes
                    ln_qty                 := 0;
                    ln_margin_store_curr   := 0;
                    ln_margin_usd          := 0;
                    ln_chg_qty             := 0;    -- Added as per Change 2.0

                    --If shipment quantity is equal to stock on hand in RMS then assign shipment or stock on hand quantity to ln_qty variable
                    --and also set lv_ship_qty_met_soh to Yes. If lv_ship_qty_met_soh is yes, then exit the shipment loop as SOH met the shipment qty
                    IF ship_rec.shipment_qty = ln_remaining_soh
                    THEN
                        ln_qty                := ship_rec.shipment_qty;
                        --Decrease the stock on hand by the shipment qty
                        ln_remaining_soh      :=
                            ln_remaining_soh - ship_rec.shipment_qty;
                        lv_ship_qty_met_soh   := 'Y';
                    --If shipment quantity is less than stock on hand in RMS then decrease the SOH by the shipment qty
                    --and assign shipment qty to ln_qty variable and calculate the margin for ln_qty. Also loop through the shipments if any until the SOH is met
                    ELSIF ship_rec.shipment_qty < ln_remaining_soh
                    THEN
                        --Decrease the stock on hand by the shipment qty
                        ln_remaining_soh   :=
                            ln_remaining_soh - ship_rec.shipment_qty;
                        --Assign the shipment quantity to a variable for which qty the margin has to be calculated
                        ln_qty   := ship_rec.shipment_qty;
                    --If shipment quantity is greater than stock on hand in RMS then assign stock on hand quantity to ln_qty variable
                    --and also set lv_ship_qty_met_soh to Yes. If lv_ship_qty_met_soh is yes, then exit the shipment loop as SOH met the shipment qty
                    ELSIF ship_rec.shipment_qty > ln_remaining_soh
                    THEN
                        --Assign SOH or remaining SOH to ln_qty variable
                        ln_qty                := ln_remaining_soh;
                        --As the shipment quantity is greater than SOH/remaining SOH then set the shipment met SOH variable to Yes
                        lv_ship_qty_met_soh   := 'Y';
                        --Decrease the stock on hand by the shipment qty
                        ln_remaining_soh      :=
                            ln_remaining_soh - ship_rec.shipment_qty;
                    END IF;

                    --If Sales Order currency and Warehouse/Inv Org currency are not same, then convert the warehouse currency to sales order currency
                    IF ship_rec.sales_ord_curr_code <>
                       ship_rec.inv_org_curr_code
                    THEN
                        ln_conv_rate_to_trx_curr   := NULL;
                        ln_conv_rate_to_trx_curr   :=
                            get_conv_rate (
                                pv_from_currency     =>
                                    ship_rec.inv_org_curr_code --Warehouse Currency
                                                              ,
                                pv_to_currency       =>
                                    ship_rec.sales_ord_curr_code --Sales Order Currency
                                                                ,
                                pv_conversion_type   => 'Corporate' -- gv_rate_type
                                                                   ,
                                pd_conversion_date   =>
                                    TRUNC (ship_rec.transaction_date) --Shipment/Transaction Date
                                                                     );
                        --Get actual cost in sales order currency and round it to 2 decimals
                        ln_actual_cost_order_curr   :=
                            ROUND (
                                  ship_rec.actual_cost
                                * ln_conv_rate_to_trx_curr,
                                2);
                    ELSE
                        ln_actual_cost_order_curr   :=
                            ROUND (ship_rec.actual_cost, 2);
                    END IF;

                    --Margin Calculation in Store Currency(If Sales Order Currency is not equal to store currency, convert the order currency to store currency)
                    IF ship_rec.sales_ord_curr_code <>
                       ship_rec.store_currency_code
                    THEN
                        ln_conv_rate   := NULL;
                        ln_conv_rate   :=
                            get_conv_rate (
                                pv_from_currency     =>
                                    ship_rec.sales_ord_curr_code --Sales order currency
                                                                ,
                                pv_to_currency       =>
                                    ship_rec.store_currency_code --Store Currency Code
                                                                ,
                                pv_conversion_type   => 'Corporate' -- gv_rate_type
                                                                   ,
                                pd_conversion_date   =>
                                    TRUNC (ship_rec.transaction_date) --Shipment/Transaction Date
                                                                     );

                        --Margin = unit selling price minus actual cost

                        IF src_rec.stock_onhand < 0
                        THEN
                            ln_chg_qty   := -1;
                        ELSE
                            ln_chg_qty   := 1;
                        END IF;

                        IF   ship_rec.unit_selling_price
                           - ln_actual_cost_order_curr <
                           0
                        THEN
                            ln_margin_store_curr   := 0;
                        ELSE
                            ln_margin_store_curr   :=
                                  (ship_rec.unit_selling_price - ln_actual_cost_order_curr)
                                * ln_qty
                                * ln_chg_qty;
                        END IF;
                    --If sales order currency and store currency are same then conversion is not required
                    ELSE
                        IF src_rec.stock_onhand < 0
                        THEN
                            ln_chg_qty   := -1;
                        ELSE
                            ln_chg_qty   := 1;
                        END IF;

                        IF   ship_rec.unit_selling_price
                           - ln_actual_cost_order_curr <
                           0
                        THEN
                            ln_margin_store_curr   := 0;
                        ELSE
                            ln_margin_store_curr   :=
                                  (ship_rec.unit_selling_price - ln_actual_cost_order_curr)
                                * ln_qty
                                * ln_chg_qty;
                        END IF;
                    END IF;

                    --Margin Calculation in USD
                    IF ship_rec.store_currency_code <> 'USD'
                    THEN
                        ln_conv_rate_usd   :=
                            get_conv_rate (
                                pv_from_currency     =>
                                    ship_rec.store_currency_code,
                                pv_to_currency       => 'USD',
                                pv_conversion_type   => 'Corporate' -- gv_rate_type
                                                                   ,
                                pd_conversion_date   =>
                                    TRUNC (ship_rec.transaction_date));
                        --ln_margin_usd:= (ln_margin_store_curr * ln_qty) * ln_conv_rate_usd; --Commented on 30Jul2019
                        ln_margin_usd   :=
                            (ln_margin_store_curr) * ln_conv_rate_usd; --Added on 30Jul2019
                    ELSE
                        --ln_margin_usd:= ln_margin_store_curr * ln_qty;  --Commented on 30Jul2019
                        ln_margin_usd   := ln_margin_store_curr; --Added on 30Jul2019
                    END IF;

                    --Add margin for current shipment to final margin for the item and store in both Store Currency and USD
                    ln_margin_store_curr_final   :=
                        ln_margin_store_curr_final + ln_margin_store_curr;
                    ln_margin_usd_final    :=
                        ln_margin_usd_final + ln_margin_usd;

                    --If shipment quantity meets the Stock on hand then exit the shipment loop and move to next item in src_cur loop
                    IF lv_ship_qty_met_soh = 'Y'
                    THEN
                        EXIT; --exit the ship_cur loop and move to next item in src_cur loop
                    END IF;
                END LOOP;                                  --ship_cur end loop

                --Check if shipments exists for this item and store in EBS or not
                IF lv_shipments_exists = 'Y'
                THEN
                    --Check if remaining stock on hand quantity is negative or zero(ln_remaining_soh = ln_remaining_soh - shipment qty for each shipment record)
                    --Negative or zero means, shipment quantity is equal or more than stock on hand
                    IF ln_remaining_soh <= 0
                    THEN
                        ln_avg_margin_st_curr_final   :=
                            ln_margin_store_curr_final / src_rec.stock_onhand;
                        ln_avg_margin_usd_final   :=
                            ln_margin_usd_final / src_rec.stock_onhand;
                    --ln_remaining_soh is greater than ZERO then Shipment quantity is less than stock on hand
                    --In this case for the remaining Stock on hand, get the fixed margin from value set as there are no more shipment records
                    ELSE
                        --Get the fixed margin from lookup for the remaining stock on hand(ln_remaining_soh) and calculate Margins
                        ln_fixed_margin_pct   :=
                            get_fixed_margin_pct (
                                pn_ou_id        => src_rec.ou_id,
                                pv_brand        => src_rec.brand,
                                pv_store_type   => src_rec.store_type);

                        IF src_rec.store_currency <> 'USD'
                        THEN
                            ln_conv_rate_usd   := NULL;
                            ln_conv_rate_usd   :=
                                get_conv_rate (
                                    pv_from_currency     =>
                                        src_rec.store_currency,
                                    pv_to_currency       => 'USD',
                                    pv_conversion_type   => 'Corporate' -- gv_rate_type
                                                                       ,
                                    pd_conversion_date   =>
                                        TRUNC (src_rec.soh_date_ts));
                        ELSE
                            ln_conv_rate_usd   := 1;
                        END IF;

                        ln_margin_store_curr_final   :=
                              ln_margin_store_curr_final
                            + ((ln_remaining_soh * src_rec.stock_avg_cost) * (ln_fixed_margin_pct / 100));
                        ln_margin_usd_final   :=
                              ln_margin_usd_final
                            + ((ln_remaining_soh * src_rec.stock_avg_cost) * (ln_fixed_margin_pct / 100) * ln_conv_rate_usd);
                        ln_avg_margin_st_curr_final   :=
                            ln_margin_store_curr_final / ln_remaining_soh;
                        ln_avg_margin_usd_final   :=
                            ln_margin_usd_final / ln_remaining_soh;
                    END IF;
                --If shipments does not exists for an item and store then get the fixed margin from value set and calculate margin values
                ELSE
                    --                    write_log('Before Calculation - START. ln_fixed_margin_pct with Y as Incude Margin :'||TO_CHAR(SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));

                    --Write the logic to derive fixed margin and calculate the margins
                    ln_fixed_margin_pct   :=
                        get_fixed_margin_pct (
                            pn_ou_id        => src_rec.ou_id,
                            pv_brand        => src_rec.brand,
                            pv_store_type   => src_rec.store_type);

                    IF src_rec.store_currency <> 'USD'
                    THEN
                        ln_conv_rate_usd   := NULL;
                        ln_conv_rate_usd   :=
                            get_conv_rate (
                                pv_from_currency     => src_rec.store_currency,
                                pv_to_currency       => 'USD',
                                pv_conversion_type   => 'Corporate' -- gv_rate_type
                                                                   ,
                                pd_conversion_date   =>
                                    TRUNC (src_rec.soh_date_ts));
                    ELSE
                        ln_conv_rate_usd   := 1;
                    END IF;

                    ln_margin_store_curr_final   :=
                          (src_rec.stock_onhand * src_rec.stock_avg_cost)
                        * (ln_fixed_margin_pct / 100);
                    ln_margin_usd_final   :=
                          (src_rec.stock_onhand * src_rec.stock_avg_cost)
                        * (ln_fixed_margin_pct / 100)
                        * ln_conv_rate_usd;
                    ln_avg_margin_st_curr_final   :=
                        ln_margin_store_curr_final / src_rec.stock_onhand;
                    ln_avg_margin_usd_final   :=
                        ln_margin_usd_final / src_rec.stock_onhand;
                END IF;

                xn_margin_store_curr_final    := ln_avg_margin_st_curr_final;
                xn_margin_usd_final           := ln_avg_margin_usd_final;
            END LOOP;                                       --src_cur end loop
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            xn_margin_store_curr_final   := 0;
            xn_margin_usd_final          := 0;
    END get_direct_oh_markup_values;

    /***********************************************************************************************
    ************************* Procedure to Get DIRECT Method SALES Markup **************************
    ************************************************************************************************/

    PROCEDURE get_direct_sales_markup_values (pn_store_number IN NUMBER, pn_inv_item_id IN NUMBER, pn_ou_id IN NUMBER
                                              , xn_margin_store_curr_final OUT NUMBER, xn_margin_usd_final OUT NUMBER)
    IS
        --Cursors Declaration
        --Cursor to get the items for which the Margin has to be calculated

        CURSOR src_cur IS
            SELECT stg.ROWID, DECODE (sales_total_units, 0, return_total_units, sales_total_units) sales_ret_total_units, DECODE (sales_total_cost, 0, return_total_cost, sales_total_cost) sales_ret_total_cost,
                   stg.*
              FROM xxdo.xxd_gl_je_ret_ic_markup_stg_t stg
             WHERE     1 = 1
                   AND stg.request_id = gn_request_id
                   AND stg.store_number =
                       NVL (pn_store_number, stg.store_number)
                   AND stg.item_id = NVL (pn_inv_item_id, stg.item_id)
                   AND stg.operating_unit =
                       NVL (pn_ou_id, stg.operating_unit);

        --Cursor to get Shipment details
        CURSOR ship_cur (cn_inv_item_id IN NUMBER, cn_store_number IN NUMBER, cn_ou_id IN NUMBER
                         , cd_as_of_date IN DATE)
        IS
              SELECT oola.org_id, oola.ordered_item, mmt.transaction_id,
                     mmt.transaction_date, ABS (mmt.transaction_quantity) shipment_qty, mmt.actual_cost,
                     oola.unit_selling_price, oola.unit_list_price, stv.store_name,
                     mmt.organization_id, ooha.order_number, stv.store_type,
                     stv.currency_code store_currency_code, ooha.transactional_curr_code sales_ord_curr_code, gl.currency_code inv_org_curr_code
                FROM apps.fnd_flex_value_sets ffvs_ind, apps.fnd_flex_values ffv_ind, apps.fnd_flex_values_tl ffvt_ind,
                     apps.fnd_flex_value_sets ffvs_dep, apps.fnd_flex_values ffv_dep, apps.fnd_flex_values_tl ffvt_dep,
                     apps.hr_operating_units hrou, apps.mtl_parameters mp -- end of change 2.0
                                                                         , apps.hr_organization_information hoi,
                     apps.gl_ledgers gl, apps.mtl_material_transactions mmt, apps.oe_order_lines_all oola,
                     apps.oe_order_headers_all ooha, apps.xxd_retail_stores_v stv
               WHERE     1 = 1
                     AND hrou.organization_id = cn_ou_id
                     AND hrou.name = ffv_ind.flex_value
                     AND mp.organization_code = ffv_dep.flex_value
                     AND hoi.organization_id = mp.organization_id
                     ---AND (pn_inv_org_id IS NULL OR mp.organization_id = pn_inv_org_id)
                     AND hoi.org_information_context = 'Accounting Information'
                     AND TO_NUMBER (hoi.org_information1) = gl.ledger_id
                     AND mmt.inventory_item_id = cn_inv_item_id
                     AND mmt.organization_id = mp.organization_id
                     AND mmt.transaction_date <= cd_as_of_date
                     AND mmt.transaction_type_id = 33      --Sales order issue
                     AND mmt.transaction_source_type_id = 2      --Sales order
                     AND mmt.trx_source_line_id = oola.line_id
                     AND mmt.organization_id = oola.ship_from_org_id
                     AND mmt.inventory_item_id = oola.inventory_item_id
                     AND oola.org_id = cn_ou_id
                     AND oola.header_id = ooha.header_id
                     AND ooha.sold_to_org_id = stv.ra_customer_id
                     AND stv.rms_store_id = cn_store_number
                     AND ffvs_ind.flex_value_set_id = ffv_ind.flex_value_set_id
                     AND ffv_ind.flex_value_id = ffvt_ind.flex_value_id
                     AND ffvt_ind.language = USERENV ('LANG')
                     AND UPPER (ffvs_ind.flex_value_set_name) =
                         'XXD_WMS_RET_INV_EBS_OU'
                     AND ffvs_ind.flex_value_set_id =
                         ffvs_dep.parent_flex_value_set_id
                     AND ffv_ind.flex_value = ffv_dep.parent_flex_value_low
                     AND ffvs_dep.flex_value_set_id = ffv_dep.flex_value_set_id
                     AND ffv_dep.flex_value_id = ffvt_dep.flex_value_id
                     AND ffvt_dep.language = USERENV ('LANG')
                     AND ffv_ind.enabled_flag = 'Y'
                     AND SYSDATE BETWEEN NVL (ffv_ind.start_date_active,
                                              SYSDATE)
                                     AND NVL (ffv_ind.end_date_active, SYSDATE)
                     AND ffv_dep.enabled_flag = 'Y'
                     AND SYSDATE BETWEEN NVL (ffv_dep.start_date_active,
                                              SYSDATE)
                                     AND NVL (ffv_dep.end_date_active, SYSDATE)
            ORDER BY mmt.transaction_date DESC, mmt.transaction_id DESC;

        ln_purge_days                 NUMBER := 60;
        lv_err_msg                    VARCHAR2 (4000) := NULL;
        lv_sql_stmt                   VARCHAR2 (32000) := NULL;
        lv_select_clause              VARCHAR2 (5000) := NULL;
        lv_from_clause                VARCHAR2 (5000) := NULL;
        lv_where_clause               VARCHAR2 (5000) := NULL;
        lv_store_cond                 VARCHAR2 (1000) := NULL;
        lv_org_unit_cond              VARCHAR2 (1000) := NULL;
        lv_brand_cond                 VARCHAR2 (1000) := NULL;
        lv_style_cond                 VARCHAR2 (1000) := NULL;
        lv_style_color_cond           VARCHAR2 (1000) := NULL;
        lv_sku_cond                   VARCHAR2 (1000) := NULL;
        lv_ou_name                    VARCHAR2 (120) := NULL;
        ln_remaining_soh              NUMBER := 0;
        ln_qty                        NUMBER := 0;
        ln_chg_qty                    NUMBER := 0;
        lv_ship_qty_met_soh           VARCHAR2 (1) := 'N';
        ln_conv_rate                  NUMBER := 0;
        ln_conv_rate_usd              NUMBER := 0;
        ln_margin_store_curr          NUMBER := 0;
        ln_margin_usd                 NUMBER := 0;
        ln_margin_store_curr_final    NUMBER := 0;
        ln_margin_usd_final           NUMBER := 0;
        ln_avg_margin_st_curr_final   NUMBER := 0;
        ln_avg_margin_usd_final       NUMBER := 0;
        ln_loop_ctr                   NUMBER := 0;
        lv_shipments_exists           VARCHAR2 (1) := 'N';
        ln_conv_rate_to_trx_curr      NUMBER := 0;
        ln_actual_cost_order_curr     NUMBER := 0;
        ln_fixed_margin_pct           NUMBER := 0;
        ld_as_of_date                 DATE;
        lv_org_unit_id_rms            VARCHAR2 (120) := NULL;
        lv_comp                       VARCHAR2 (100);
        lv_geo                        VARCHAR2 (100);
        lv_interco                    VARCHAR2 (100);
        lv_nat_acc                    VARCHAR2 (100);
        lv_ret_message                VARCHAR2 (4000) := NULL;
        lv_file_name                  VARCHAR2 (100);
        lv_ret_code                   VARCHAR2 (30) := NULL;
        ln_tot_sales_mrgn_cst_usd     NUMBER := 0;
        ln_rec_count                  NUMBER;
        ln_org_count                  NUMBER;
        ln_item_cnt                   NUMBER;
        l_max_run_date                DATE := NULL;
        l_max_mrgn_cst_local          NUMBER := 0;
        l_max_mrgn_cst_usd            NUMBER := 0;
    BEGIN
        BEGIN
            SELECT soh_date_ts, oh_mrgn_cst_local, oh_mrgn_cst_usd
              INTO l_max_run_date, l_max_mrgn_cst_local, l_max_mrgn_cst_usd
              FROM (SELECT a.*, ROW_NUMBER () OVER (ORDER BY soh_date_ts DESC) rn
                      FROM xxdo.xxd_gl_je_ret_ic_onhand_stg_t a
                     WHERE     a.store_number =
                               NVL (pn_store_number, a.store_number)
                           AND a.item_id = NVL (pn_inv_item_id, a.item_id)
                           --AND a.as_of_date = gd_cut_of_date
                           AND record_status = 'P'
                           AND TRUNC (a.soh_date_ts) >= TRUNC (SYSDATE) - 140)
             WHERE rn = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_max_run_date         := NULL;
                l_max_mrgn_cst_local   := NULL;
                l_max_mrgn_cst_usd     := NULL;
        END;

        IF l_max_run_date = gd_cut_of_date
        THEN
            xn_margin_store_curr_final   := l_max_mrgn_cst_local;
            xn_margin_usd_final          := l_max_mrgn_cst_usd;
        ELSIF l_max_run_date IS NOT NULL
        THEN
            SELECT COUNT (*)
              INTO ln_item_cnt
              FROM apps.fnd_flex_value_sets ffvs_ind, apps.fnd_flex_values ffv_ind, apps.fnd_flex_values_tl ffvt_ind,
                   apps.fnd_flex_value_sets ffvs_dep, apps.fnd_flex_values ffv_dep, apps.fnd_flex_values_tl ffvt_dep,
                   apps.hr_operating_units hrou, apps.mtl_parameters mp, apps.hr_organization_information hoi,
                   apps.gl_ledgers gl, apps.mtl_material_transactions mmt, apps.oe_order_lines_all oola,
                   apps.oe_order_headers_all ooha, apps.xxd_retail_stores_v stv
             WHERE     1 = 1
                   AND hrou.organization_id = pn_ou_id
                   AND hrou.name = ffv_ind.flex_value
                   AND mp.organization_code = ffv_dep.flex_value
                   AND hoi.organization_id = mp.organization_id
                   ---AND (pn_inv_org_id IS NULL OR mp.organization_id = pn_inv_org_id)
                   AND hoi.org_information_context = 'Accounting Information'
                   AND TO_NUMBER (hoi.org_information1) = gl.ledger_id
                   AND mmt.inventory_item_id = pn_inv_item_id
                   AND mmt.organization_id = mp.organization_id
                   AND mmt.transaction_date >
                       NVL (l_max_run_date, gd_cut_of_date)
                   AND mmt.transaction_type_id = 33        --Sales order issue
                   AND mmt.transaction_source_type_id = 2        --Sales order
                   AND mmt.trx_source_line_id = oola.line_id
                   AND mmt.organization_id = oola.ship_from_org_id
                   AND mmt.inventory_item_id = oola.inventory_item_id
                   AND oola.org_id = pn_ou_id
                   AND oola.header_id = ooha.header_id
                   AND ooha.sold_to_org_id = stv.ra_customer_id
                   AND stv.rms_store_id = pn_store_number
                   AND ffvs_ind.flex_value_set_id = ffv_ind.flex_value_set_id
                   AND ffv_ind.flex_value_id = ffvt_ind.flex_value_id
                   AND ffvt_ind.language = USERENV ('LANG')
                   AND UPPER (ffvs_ind.flex_value_set_name) =
                       'XXD_WMS_RET_INV_EBS_OU'
                   AND ffvs_ind.flex_value_set_id =
                       ffvs_dep.parent_flex_value_set_id
                   AND ffv_ind.flex_value = ffv_dep.parent_flex_value_low
                   AND ffvs_dep.flex_value_set_id = ffv_dep.flex_value_set_id
                   AND ffv_dep.flex_value_id = ffvt_dep.flex_value_id
                   AND ffvt_dep.language = USERENV ('LANG')
                   AND ffv_ind.enabled_flag = 'Y'
                   AND SYSDATE BETWEEN NVL (ffv_ind.start_date_active,
                                            SYSDATE)
                                   AND NVL (ffv_ind.end_date_active, SYSDATE)
                   AND ffv_dep.enabled_flag = 'Y'
                   AND SYSDATE BETWEEN NVL (ffv_dep.start_date_active,
                                            SYSDATE)
                                   AND NVL (ffv_dep.end_date_active, SYSDATE)
                   AND ROWNUM = 1;

            IF ln_item_cnt = 0
            THEN
                xn_margin_store_curr_final   := l_max_mrgn_cst_local;
                xn_margin_usd_final          := l_max_mrgn_cst_usd;
            END IF;
        END IF;

        IF l_max_run_date IS NULL OR ln_item_cnt <> 0
        THEN
            --Open the shipments cursor for the item and the store number and get the shipment details in the descending order of transaction date in MMT
            FOR src_rec IN src_cur
            LOOP
                --Assign total stock on hand to ln_remaining_soh variable
                ln_remaining_soh              := ABS (src_rec.sales_ret_total_units);
                lv_ship_qty_met_soh           := 'N';
                ln_margin_store_curr_final    := 0;
                ln_margin_usd_final           := 0;
                ln_avg_margin_st_curr_final   := 0;
                ln_avg_margin_usd_final       := 0;

                --ln_tot_ic_margin_usd := 0;

                --Open the shipments cursor for the item and the store number and get the shipment details in the descending order of transaction date in MMT
                FOR ship_rec IN ship_cur (cn_inv_item_id => src_rec.item_id, cn_store_number => src_rec.store_number, cn_ou_id => src_rec.ou_id
                                          , cd_as_of_date => gd_cut_of_date)
                LOOP
                    lv_shipments_exists    := 'Y'; --If the Shipment exists(If we enter the ship_cur loop), set to Yes
                    ln_qty                 := 0;
                    ln_margin_store_curr   := 0;
                    ln_margin_usd          := 0;
                    ln_chg_qty             := 0;    -- Added as per Change 2.0

                    --If shipment quantity is equal to stock on hand in RMS then assign shipment or stock on hand quantity to ln_qty variable
                    --and also set lv_ship_qty_met_soh to Yes. If lv_ship_qty_met_soh is yes, then exit the shipment loop as SOH met the shipment qty
                    IF ship_rec.shipment_qty = ln_remaining_soh
                    THEN
                        ln_qty                := ship_rec.shipment_qty;
                        --Decrease the stock on hand by the shipment qty
                        ln_remaining_soh      :=
                            ln_remaining_soh - ship_rec.shipment_qty;
                        lv_ship_qty_met_soh   := 'Y';
                    --If shipment quantity is less than stock on hand in RMS then decrease the SOH by the shipment qty
                    --and assign shipment qty to ln_qty variable and calculate the margin for ln_qty. Also loop through the shipments if any until the SOH is met
                    ELSIF ship_rec.shipment_qty < ln_remaining_soh
                    THEN
                        --Decrease the stock on hand by the shipment qty
                        ln_remaining_soh   :=
                            ln_remaining_soh - ship_rec.shipment_qty;
                        --Assign the shipment quantity to a variable for which qty the margin has to be calculated
                        ln_qty   := ship_rec.shipment_qty;
                    --If shipment quantity is greater than stock on hand in RMS then assign stock on hand quantity to ln_qty variable
                    --and also set lv_ship_qty_met_soh to Yes. If lv_ship_qty_met_soh is yes, then exit the shipment loop as SOH met the shipment qty
                    ELSIF ship_rec.shipment_qty > ln_remaining_soh
                    THEN
                        --Assign SOH or remaining SOH to ln_qty variable
                        ln_qty                := ln_remaining_soh;
                        --As the shipment quantity is greater than SOH/remaining SOH then set the shipment met SOH variable to Yes
                        lv_ship_qty_met_soh   := 'Y';
                        --Decrease the stock on hand by the shipment qty
                        ln_remaining_soh      :=
                            ln_remaining_soh - ship_rec.shipment_qty;
                    END IF;

                    --If Sales Order currency and Warehouse/Inv Org currency are not same, then convert the warehouse currency to sales order currency
                    IF ship_rec.sales_ord_curr_code <>
                       ship_rec.inv_org_curr_code
                    THEN
                        ln_conv_rate_to_trx_curr   := NULL;
                        ln_conv_rate_to_trx_curr   :=
                            get_conv_rate (
                                pv_from_currency     =>
                                    ship_rec.inv_org_curr_code --Warehouse Currency
                                                              ,
                                pv_to_currency       =>
                                    ship_rec.sales_ord_curr_code --Sales Order Currency
                                                                ,
                                pv_conversion_type   => 'Corporate' -- gv_rate_type
                                                                   ,
                                pd_conversion_date   =>
                                    TRUNC (ship_rec.transaction_date) --Shipment/Transaction Date
                                                                     );
                        --Get actual cost in sales order currency and round it to 2 decimals
                        ln_actual_cost_order_curr   :=
                            ROUND (
                                  ship_rec.actual_cost
                                * ln_conv_rate_to_trx_curr,
                                2);
                    ELSE
                        ln_actual_cost_order_curr   :=
                            ROUND (ship_rec.actual_cost, 2);
                    END IF;

                    --Margin Calculation in Store Currency(If Sales Order Currency is not equal to store currency, convert the order currency to store currency)
                    IF ship_rec.sales_ord_curr_code <>
                       ship_rec.store_currency_code
                    THEN
                        ln_conv_rate   := NULL;
                        ln_conv_rate   :=
                            get_conv_rate (
                                pv_from_currency     =>
                                    ship_rec.sales_ord_curr_code --Sales order currency
                                                                ,
                                pv_to_currency       =>
                                    ship_rec.store_currency_code --Store Currency Code
                                                                ,
                                pv_conversion_type   => 'Corporate' -- gv_rate_type
                                                                   ,
                                pd_conversion_date   =>
                                    TRUNC (ship_rec.transaction_date) --Shipment/Transaction Date
                                                                     );

                        --Margin = unit selling price minus actual cost

                        IF src_rec.sales_ret_total_units < 0
                        THEN
                            ln_chg_qty   := -1;
                        ELSE
                            ln_chg_qty   := 1;
                        END IF;

                        IF   ship_rec.unit_selling_price
                           - ln_actual_cost_order_curr <
                           0
                        THEN
                            ln_margin_store_curr   := 0;
                        ELSE
                            ln_margin_store_curr   :=
                                  (ship_rec.unit_selling_price - ln_actual_cost_order_curr)
                                * ln_qty
                                * ln_chg_qty;
                        END IF;
                    --If sales order currency and store currency are same then conversion is not required
                    ELSE
                        IF src_rec.sales_ret_total_units < 0
                        THEN
                            ln_chg_qty   := -1;
                        ELSE
                            ln_chg_qty   := 1;
                        END IF;

                        IF   ship_rec.unit_selling_price
                           - ln_actual_cost_order_curr <
                           0
                        THEN
                            ln_margin_store_curr   := 0;
                        ELSE
                            ln_margin_store_curr   :=
                                  (ship_rec.unit_selling_price - ln_actual_cost_order_curr)
                                * ln_qty
                                * ln_chg_qty;
                        END IF;
                    END IF;

                    --Margin Calculation in USD
                    IF ship_rec.store_currency_code <> 'USD'
                    THEN
                        ln_conv_rate_usd   :=
                            get_conv_rate (
                                pv_from_currency     =>
                                    ship_rec.store_currency_code,
                                pv_to_currency       => 'USD',
                                pv_conversion_type   => 'Corporate' -- gv_rate_type
                                                                   ,
                                pd_conversion_date   =>
                                    TRUNC (ship_rec.transaction_date));
                        --ln_margin_usd:= (ln_margin_store_curr * ln_qty) * ln_conv_rate_usd; --Commented on 30Jul2019
                        ln_margin_usd   :=
                            (ln_margin_store_curr) * ln_conv_rate_usd; --Added on 30Jul2019
                    ELSE
                        --ln_margin_usd:= ln_margin_store_curr * ln_qty;  --Commented on 30Jul2019
                        ln_margin_usd   := ln_margin_store_curr; --Added on 30Jul2019
                    END IF;

                    --Add margin for current shipment to final margin for the item and store in both Store Currency and USD
                    ln_margin_store_curr_final   :=
                        ln_margin_store_curr_final + ln_margin_store_curr;
                    ln_margin_usd_final    :=
                        ln_margin_usd_final + ln_margin_usd;

                    --If shipment quantity meets the Stock on hand then exit the shipment loop and move to next item in src_cur loop
                    IF lv_ship_qty_met_soh = 'Y'
                    THEN
                        EXIT; --exit the ship_cur loop and move to next item in src_cur loop
                    END IF;
                END LOOP;                                  --ship_cur end loop

                --Check if shipments exists for this item and store in EBS or not
                IF lv_shipments_exists = 'Y'
                THEN
                    --Check if remaining stock on hand quantity is negative or zero(ln_remaining_soh = ln_remaining_soh - shipment qty for each shipment record)
                    --Negative or zero means, shipment quantity is equal or more than stock on hand
                    IF ln_remaining_soh <= 0
                    THEN
                        ln_avg_margin_st_curr_final   :=
                              ln_margin_store_curr_final
                            / src_rec.sales_ret_total_units;
                        ln_avg_margin_usd_final   :=
                              ln_margin_usd_final
                            / src_rec.sales_ret_total_units;
                    --ln_remaining_soh is greater than ZERO then Shipment quantity is less than stock on hand
                    --In this case for the remaining Stock on hand, get the fixed margin from value set as there are no more shipment records
                    ELSE
                        --Get the fixed margin from lookup for the remaining stock on hand(ln_remaining_soh) and calculate Margins
                        ln_fixed_margin_pct   :=
                            get_fixed_margin_pct (
                                pn_ou_id        => src_rec.ou_id,
                                pv_brand        => src_rec.brand,
                                pv_store_type   => src_rec.store_type);

                        IF src_rec.store_currency <> 'USD'
                        THEN
                            ln_conv_rate_usd   := NULL;
                            ln_conv_rate_usd   :=
                                get_conv_rate (
                                    pv_from_currency     =>
                                        src_rec.store_currency,
                                    pv_to_currency       => 'USD',
                                    pv_conversion_type   => 'Corporate' -- gv_rate_type
                                                                       ,
                                    pd_conversion_date   => gd_cut_of_date --TRUNC(src_rec.soh_date_ts)
                                                                          );
                        ELSE
                            ln_conv_rate_usd   := 1;
                        END IF;

                        ln_margin_store_curr_final   :=
                              ln_margin_store_curr_final
                            + ((ln_remaining_soh * src_rec.sales_ret_total_cost) * (ln_fixed_margin_pct / 100));
                        ln_margin_usd_final   :=
                              ln_margin_usd_final
                            + ((ln_remaining_soh * src_rec.sales_ret_total_cost) * (ln_fixed_margin_pct / 100) * ln_conv_rate_usd);
                        ln_avg_margin_st_curr_final   :=
                            ln_margin_store_curr_final / ln_remaining_soh;
                        ln_avg_margin_usd_final   :=
                            ln_margin_usd_final / ln_remaining_soh;
                    END IF;
                --If shipments does not exists for an item and store then get the fixed margin from value set and calculate margin values
                ELSE
                    --                    write_log('Before Calculation - START. ln_fixed_margin_pct with Y as Incude Margin :'||TO_CHAR(SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));

                    --Write the logic to derive fixed margin and calculate the margins
                    ln_fixed_margin_pct   :=
                        get_fixed_margin_pct (
                            pn_ou_id        => src_rec.ou_id,
                            pv_brand        => src_rec.brand,
                            pv_store_type   => src_rec.store_type);

                    IF src_rec.store_currency <> 'USD'
                    THEN
                        ln_conv_rate_usd   := NULL;
                        ln_conv_rate_usd   :=
                            get_conv_rate (
                                pv_from_currency     => src_rec.store_currency,
                                pv_to_currency       => 'USD',
                                pv_conversion_type   => 'Corporate' -- gv_rate_type
                                                                   ,
                                pd_conversion_date   => gd_cut_of_date);
                    ELSE
                        ln_conv_rate_usd   := 1;
                    END IF;

                    ln_margin_store_curr_final   :=
                          (src_rec.sales_ret_total_units * src_rec.sales_ret_total_cost)
                        * (ln_fixed_margin_pct / 100);
                    ln_margin_usd_final   :=
                          (src_rec.sales_ret_total_units * src_rec.sales_ret_total_cost)
                        * (ln_fixed_margin_pct / 100)
                        * ln_conv_rate_usd;
                    ln_avg_margin_st_curr_final   :=
                          ln_margin_store_curr_final
                        / src_rec.sales_ret_total_units;
                    ln_avg_margin_usd_final   :=
                        ln_margin_usd_final / src_rec.sales_ret_total_units;
                END IF;

                xn_margin_store_curr_final    := ln_avg_margin_st_curr_final;
                xn_margin_usd_final           := ln_avg_margin_usd_final;
            END LOOP;                                       --src_cur end loop
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            xn_margin_store_curr_final   := 0;
            xn_margin_usd_final          := 0;
    END get_direct_sales_markup_values;

    /***********************************************************************************************
    ************************** Procedure to update Onhand Holding Markup values ********************
    ************************************************************************************************/

    PROCEDURE update_oh_holding_markup_values (x_ret_message OUT VARCHAR2)
    IS
        CURSOR c_onhand_holding IS
            SELECT oh.ROWID oh_row_id, oh.store_number oh_store_number, oh.item_id oh_item_id,
                   oh.inv_org_id oh_inv_org_id, oh.as_of_date oh_as_of_date, oh.style oh_style,
                   oh.color oh_color, oh.item_size oh_item_size, oh.brand oh_brand,
                   oh.ou_id oh_ou_id, oh.operating_unit oh_ou_id_rms, oh.store_currency oh_store_currency,
                   oh.stock_onhand oh_stock_onhand, oh.stock_avg_cost oh_stock_avg_cost, oh.soh_date_ts oh_soh_date,
                   oh.markup_type oh_markup_type, oh.oh_journal_currency oh_journal_currency, oh.attribute1 oh_attr1_calc_curr
              FROM xxdo.xxd_gl_je_ret_ic_onhand_stg_t oh
             WHERE     1 = 1
                   AND oh.request_id = gn_request_id
                   AND oh.markup_type = 'HOLDING';

        xn_trx_mrgn_cst_usd              NUMBER;
        xn_trx_mrgn_cst_local            NUMBER;
        ln_trx_mrgn_cst_usd              NUMBER;
        ln_trx_mrgn_cst_local            NUMBER;
        ln_trx_mrgn_value_local          NUMBER;
        ln_trx_mrgn_value_usd            NUMBER;
        ln_trx_mrgn_cst_ret_usd          NUMBER;
        ln_trx_mrgn_cst_ret_local        NUMBER;
        xn_margin_str_curr               NUMBER;
        xn_margin_usd                    NUMBER;
        ln_margin_str_curr               NUMBER;
        ln_margin_usd                    NUMBER;
        ln_oh_prev_margin_value_local    NUMBER;
        ln_oh_prev_margin_value_usd      NUMBER;
        ln_oh_markup_local_at_usd        NUMBER;
        ln_oh_markup_local_at_usd1       NUMBER;
        ln_oh_prev_markup_local_at_usd   NUMBER;
        ln_oh_markup_local               NUMBER;
        ln_oh_markup_usd                 NUMBER;
        ln_margin_str_ret_curr           NUMBER;
        ln_margin_ret_usd                NUMBER;
        ln_conv_rate_usd                 NUMBER;
        ln_mrgn_cst_local1               NUMBER;
        ln_loop_ctr                      NUMBER := 0;
        ln_oh_prev_markup_usd            NUMBER;
        ln_oh_prev_markup_local          NUMBER;
        l_usd_val                        NUMBER;
    BEGIN
        FOR rec_onhand_holding IN c_onhand_holding
        LOOP
            xn_trx_mrgn_cst_usd              := 0;
            xn_trx_mrgn_cst_local            := 0;
            ln_trx_mrgn_cst_usd              := 0;
            ln_trx_mrgn_cst_local            := 0;
            ln_trx_mrgn_value_local          := 0;
            ln_trx_mrgn_value_usd            := 0;
            ln_trx_mrgn_cst_ret_usd          := 0;
            ln_trx_mrgn_cst_ret_local        := 0;
            xn_margin_str_curr               := 0;
            xn_margin_usd                    := 0;
            ln_margin_str_curr               := 0;
            ln_margin_usd                    := 0;
            ln_oh_prev_margin_value_local    := 0;
            ln_oh_prev_margin_value_usd      := 0;
            ln_oh_markup_local_at_usd        := 0;
            ln_oh_markup_local_at_usd1       := 0;
            ln_oh_prev_markup_local_at_usd   := 0;
            ln_oh_markup_local               := 0;
            ln_oh_markup_usd                 := 0;
            ln_margin_str_ret_curr           := 0;
            ln_margin_ret_usd                := 0;
            ln_conv_rate_usd                 := 0;
            ln_loop_ctr                      := 0;
            ln_oh_prev_markup_usd            := 0;
            ln_oh_prev_markup_local          := 0;
            l_usd_val                        := 0;

            BEGIN
                SELECT NVL (oh_usdval, 0), NVL (oh_localval, 0)
                  INTO ln_oh_prev_markup_usd, ln_oh_prev_markup_local
                  FROM (SELECT a.*, ROW_NUMBER () OVER (ORDER BY as_of_date DESC) rn
                          FROM xxdo.xxd_gl_je_ret_ic_onhand_stg_t a
                         WHERE     a.store_number =
                                   rec_onhand_holding.oh_store_number
                               AND a.item_id = rec_onhand_holding.oh_item_id
                               AND record_status = 'P'
                               AND TRUNC (a.soh_date_ts) >=
                                   TRUNC (SYSDATE) - 140)
                 WHERE rn = 1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_oh_prev_markup_usd     := 0;
                    ln_oh_prev_markup_local   := 0;
            END;

            BEGIN
                get_holding_markup_values     -- HOLDING - ONHAND Markup value
                                          (rec_onhand_holding.oh_inv_org_id,
                                           rec_onhand_holding.oh_item_id,
                                           gd_cut_of_date,
                                           xn_trx_mrgn_cst_usd,
                                           xn_trx_mrgn_cst_local);

                IF rec_onhand_holding.oh_stock_avg_cost <
                   xn_trx_mrgn_cst_local
                THEN
                    SELECT DECODE (NVL (xn_trx_mrgn_cst_local, 1), 0, 1, NVL (xn_trx_mrgn_cst_local, 1))
                      INTO ln_mrgn_cst_local1
                      FROM DUAL;

                    xn_trx_mrgn_cst_usd   :=
                        ROUND (
                            ((NVL (rec_onhand_holding.oh_stock_avg_cost, 0) / (ln_mrgn_cst_local1)) * NVL (xn_trx_mrgn_cst_usd, 0)),
                            2);

                    xn_trx_mrgn_cst_local   :=
                        rec_onhand_holding.oh_stock_avg_cost;
                END IF;

                IF xn_trx_mrgn_cst_local < 0
                THEN
                    xn_trx_mrgn_cst_local   := 0;
                END IF;

                IF xn_trx_mrgn_cst_usd < 0
                THEN
                    xn_trx_mrgn_cst_usd   := 0;
                END IF;

                ln_trx_mrgn_cst_local   :=
                    ln_trx_mrgn_cst_local + xn_trx_mrgn_cst_local;
                ln_trx_mrgn_cst_usd   :=
                    ln_trx_mrgn_cst_usd + xn_trx_mrgn_cst_usd;

                ln_trx_mrgn_value_local   :=
                    ROUND (
                        (rec_onhand_holding.oh_stock_onhand * ABS (ln_trx_mrgn_cst_local)),
                        2);
                ln_trx_mrgn_value_usd   :=
                    ROUND (
                        (rec_onhand_holding.oh_stock_onhand * ABS (ln_trx_mrgn_cst_usd)),
                        2);

                ln_oh_markup_local_at_usd1   :=
                    ROUND (
                          ln_trx_mrgn_value_local
                        * get_conv_rate (
                              pv_from_currency     =>
                                  rec_onhand_holding.oh_store_currency,
                              pv_to_currency       => 'USD',
                              pv_conversion_type   => gv_rate_type,
                              pd_conversion_date   =>
                                  TRUNC (rec_onhand_holding.oh_soh_date)),
                        2);

                ln_oh_markup_local   :=
                    ln_trx_mrgn_value_local - ln_oh_prev_markup_local;
                ln_oh_markup_usd   :=
                    ln_trx_mrgn_value_usd - ln_oh_prev_markup_usd;
                ln_oh_markup_local_at_usd   :=
                    ln_oh_markup_local_at_usd1 - ln_oh_prev_markup_usd;

                SELECT ROUND (
                           NVL (
                               CASE
                                   WHEN     gv_markup_calc_cur = 'Local'
                                        AND gv_onhand_currency = 'USD'
                                   THEN
                                       NVL (ln_oh_markup_local_at_usd1,
                                            NVL (ln_trx_mrgn_value_usd, 0))
                                   WHEN gv_markup_calc_cur = 'USD' --AND oh_journal_currency = 'USD'
                                   THEN
                                       NVL (ln_trx_mrgn_value_usd, 0)
                                   WHEN     gv_markup_calc_cur = 'Local'
                                        AND gv_onhand_currency = 'Local'
                                   THEN
                                         NVL (ln_trx_mrgn_value_local, 0)
                                       * (SELECT get_conv_rate (
                                                     pv_from_currency   =>
                                                         rec_onhand_holding.oh_store_currency,
                                                     pv_to_currency   => 'USD',
                                                     pv_conversion_type   =>
                                                         gv_jl_rate_type,
                                                     pd_conversion_date   =>
                                                         TRUNC (
                                                             rec_onhand_holding.oh_soh_date))
                                            FROM DUAL)
                                   ELSE
                                       NVL (ln_trx_mrgn_value_usd, 0)
                               END,
                               0),
                           2) usdval
                  INTO l_usd_val
                  FROM DUAL;

                UPDATE xxdo.xxd_gl_je_ret_ic_onhand_stg_t
                   SET oh_usdval             = l_usd_val,
                       oh_localval          =
                           ROUND (
                                 l_usd_val
                               * (SELECT get_conv_rate (
                                             pv_from_currency   => 'USD',
                                             pv_to_currency     =>
                                                 rec_onhand_holding.oh_store_currency,
                                             pv_conversion_type   =>
                                                 gv_jl_rate_type,
                                             pd_conversion_date   =>
                                                 TRUNC (
                                                     rec_onhand_holding.oh_soh_date))
                                    FROM DUAL),
                               2),
                       oh_mrgn_cst_local     = ln_trx_mrgn_cst_local,
                       oh_mrgn_cst_usd       = ln_trx_mrgn_cst_usd,
                       oh_mrgn_value_local   = ln_trx_mrgn_value_local,
                       oh_mrgn_value_usd     = ln_trx_mrgn_value_usd,
                       oh_markup_local       = ln_oh_markup_local,
                       oh_markup_usd         = ln_oh_markup_usd,
                       attribute1            = ln_oh_markup_local_at_usd1,
                       attribute5            = ln_oh_markup_local_at_usd,
                       last_update_date      = SYSDATE,
                       last_updated_by       = gn_user_id
                 WHERE     ROWID = rec_onhand_holding.oh_row_id
                       AND store_number = rec_onhand_holding.oh_store_number
                       AND item_id = rec_onhand_holding.oh_item_id
                       AND request_id = gn_request_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            ln_loop_ctr                      := ln_loop_ctr + 1;

            --Issue commit for every gn_commit_rows records
            IF MOD (ln_loop_ctr, gn_commit_rows) = 0
            THEN
                COMMIT;
            END IF;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put (
                fnd_file.LOG,
                   'Error while fetching the update_oh_holding_markup_values - '
                || SQLERRM);
            x_ret_message   := SQLERRM;
    END update_oh_holding_markup_values;

    /***********************************************************************************************
    ************************** Procedure to update Onhand Direct Markup values ********************
    ************************************************************************************************/
    -- Child Request Procedure to run consolidated invidual operating unit level
    PROCEDURE update_oh_direct_ou (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY VARCHAR2, pn_ou_id NUMBER
                                   , pn_request_id NUMBER)
    IS
        CURSOR c_onhand_direct_store IS
            SELECT DISTINCT oh.store_number
              FROM xxdo.xxd_gl_je_ret_ic_onhand_stg_t oh
             WHERE     1 = 1
                   AND oh.request_id = pn_request_id
                   AND oh.markup_type = 'DIRECT'
                   AND oh.operating_unit = pn_ou_id;

        CURSOR c_onhand_direct (p_store NUMBER)
        IS
            SELECT oh.ROWID oh_row_id, oh.store_number oh_store_number, oh.item_id oh_item_id,
                   oh.inv_org_id oh_inv_org_id, oh.as_of_date oh_as_of_date, oh.style oh_style,
                   oh.color oh_color, oh.item_size oh_item_size, oh.brand oh_brand,
                   oh.ou_id oh_ou_id, oh.operating_unit oh_ou_id_rms, oh.store_currency oh_store_currency,
                   oh.stock_onhand oh_stock_onhand, oh.stock_avg_cost oh_stock_avg_cost, oh.soh_date_ts oh_soh_date,
                   oh.markup_type oh_markup_type, oh.oh_journal_currency oh_journal_currency, oh.attribute1 oh_attr1_calc_curr,
                   oh.attribute3 oh_attr3_exch_rate, oh.attribute4 oh_attr4_jl_exch_rate
              FROM xxdo.xxd_gl_je_ret_ic_onhand_stg_t oh
             WHERE     1 = 1
                   AND oh.request_id = pn_request_id
                   AND oh.markup_type = 'DIRECT'
                   AND oh.operating_unit = pn_ou_id
                   AND oh.store_number = p_store;


        xn_trx_mrgn_cst_usd              NUMBER;
        xn_trx_mrgn_cst_local            NUMBER;
        ln_trx_mrgn_cst_usd              NUMBER;
        ln_trx_mrgn_cst_local            NUMBER;
        ln_trx_mrgn_value_local          NUMBER;
        ln_trx_mrgn_value_usd            NUMBER;
        ln_trx_mrgn_cst_ret_usd          NUMBER;
        ln_trx_mrgn_cst_ret_local        NUMBER;
        xn_margin_str_curr               NUMBER;
        xn_margin_usd                    NUMBER;
        ln_margin_str_curr               NUMBER;
        ln_margin_usd                    NUMBER;
        ln_oh_prev_margin_value_local    NUMBER;
        ln_oh_prev_margin_value_usd      NUMBER;
        ln_oh_prev_markup_local_at_usd   NUMBER;
        ln_oh_markup_local_at_usd        NUMBER;
        ln_oh_markup_local_at_usd1       NUMBER;
        ln_oh_markup_local               NUMBER;
        ln_oh_markup_usd                 NUMBER;
        ln_margin_str_ret_curr           NUMBER;
        ln_margin_ret_usd                NUMBER;
        ln_conv_rate_usd                 NUMBER;
        ln_mrgn_cst_local1               NUMBER;
        ln_loop_ctr                      NUMBER := 0;
        ln_oh_prev_markup_local          NUMBER;
        ln_oh_prev_markup_usd            NUMBER;
        l_usd_val                        NUMBER;
    BEGIN
        FOR rec_onhand_direct_store IN c_onhand_direct_store
        LOOP
            FOR rec_onhand_direct
                IN c_onhand_direct (rec_onhand_direct_store.store_number)
            LOOP
                xn_trx_mrgn_cst_usd              := 0;
                xn_trx_mrgn_cst_local            := 0;
                ln_trx_mrgn_cst_usd              := 0;
                ln_trx_mrgn_cst_local            := 0;
                ln_trx_mrgn_value_local          := 0;
                ln_trx_mrgn_value_usd            := 0;
                ln_trx_mrgn_cst_ret_usd          := 0;
                ln_trx_mrgn_cst_ret_local        := 0;
                xn_margin_str_curr               := 0;
                xn_margin_usd                    := 0;
                ln_margin_str_curr               := 0;
                ln_margin_usd                    := 0;
                ln_oh_prev_margin_value_local    := 0;
                ln_oh_prev_margin_value_usd      := 0;
                ln_oh_prev_markup_local_at_usd   := 0;
                ln_oh_markup_local_at_usd        := 0;
                ln_oh_markup_local_at_usd1       := 0;
                ln_oh_markup_local               := 0;
                ln_oh_markup_usd                 := 0;
                ln_margin_str_ret_curr           := 0;
                ln_margin_ret_usd                := 0;
                ln_conv_rate_usd                 := 0;
                ln_mrgn_cst_local1               := 0;
                ln_loop_ctr                      := 0;
                ln_oh_prev_markup_usd            := 0;
                ln_oh_prev_markup_local          := 0;
                l_usd_val                        := 0;

                BEGIN
                    SELECT NVL (oh_usdval, 0), NVL (oh_localval, 0)
                      INTO ln_oh_prev_markup_usd, ln_oh_prev_markup_local
                      FROM (SELECT a.*, ROW_NUMBER () OVER (ORDER BY as_of_date DESC) rn
                              FROM xxdo.xxd_gl_je_ret_ic_onhand_stg_t a
                             WHERE     a.store_number =
                                       rec_onhand_direct.oh_store_number
                                   AND a.item_id =
                                       rec_onhand_direct.oh_item_id
                                   AND record_status = 'P'
                                   AND TRUNC (a.soh_date_ts) >=
                                       TRUNC (SYSDATE) - 140)
                     WHERE rn = 1;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_oh_prev_markup_usd     := 0;
                        ln_oh_prev_markup_local   := 0;
                END;

                BEGIN
                    xxd_gl_je_retail_ic_markup_pkg.get_direct_oh_markup_values (
                        pn_request_id,
                        pn_ou_id,
                        rec_onhand_direct.oh_store_number,
                        rec_onhand_direct.oh_item_id,
                        xn_margin_str_curr,
                        xn_margin_usd);

                    IF rec_onhand_direct.oh_stock_avg_cost <
                       xn_margin_str_curr
                    THEN
                        SELECT DECODE (NVL (xn_margin_str_curr, 1), 0, 1, NVL (xn_margin_str_curr, 1))
                          INTO ln_mrgn_cst_local1
                          FROM DUAL;

                        xn_margin_usd   :=
                            ROUND (
                                ((NVL (rec_onhand_direct.oh_stock_avg_cost, 0) / (ln_mrgn_cst_local1)) * NVL (xn_margin_usd, 0)),
                                2);

                        xn_margin_str_curr   :=
                            rec_onhand_direct.oh_stock_avg_cost;
                    END IF;

                    IF xn_margin_str_curr < 0
                    THEN
                        xn_margin_str_curr   := 0;
                    END IF;

                    IF xn_margin_usd < 0
                    THEN
                        xn_margin_usd   := 0;
                    END IF;

                    ln_margin_str_curr   :=
                        ln_margin_str_curr + xn_margin_str_curr;
                    ln_margin_usd   := ln_margin_usd + xn_margin_usd;

                    ln_trx_mrgn_value_local   :=
                        ROUND (
                              rec_onhand_direct.oh_stock_onhand
                            * ABS (ln_margin_str_curr),
                            2);
                    ln_trx_mrgn_value_usd   :=
                        ROUND (
                              rec_onhand_direct.oh_stock_onhand
                            * ABS (ln_margin_usd),
                            2);

                    ln_oh_markup_local_at_usd1   :=
                        ROUND (
                              ln_trx_mrgn_value_local
                            * get_conv_rate (
                                  pv_from_currency   =>
                                      rec_onhand_direct.oh_store_currency,
                                  pv_to_currency   => 'USD',
                                  pv_conversion_type   =>
                                      rec_onhand_direct.oh_attr3_exch_rate,
                                  pd_conversion_date   =>
                                      TRUNC (rec_onhand_direct.oh_soh_date)),
                            2);

                    ln_oh_markup_local   :=
                        ln_trx_mrgn_value_local - ln_oh_prev_markup_local;
                    ln_oh_markup_usd   :=
                        ln_trx_mrgn_value_usd - ln_oh_prev_markup_usd;
                    ln_oh_markup_local_at_usd   :=
                        ln_oh_markup_local_at_usd1 - ln_oh_prev_markup_usd;

                    SELECT ROUND (
                               NVL (
                                   CASE
                                       WHEN     gv_markup_calc_cur = 'Local'
                                            AND gv_onhand_currency = 'USD'
                                       THEN
                                           NVL (
                                               ln_oh_markup_local_at_usd1,
                                               NVL (ln_trx_mrgn_value_usd, 0))
                                       WHEN gv_markup_calc_cur = 'USD' --AND oh_journal_currency = 'USD'
                                       THEN
                                           NVL (ln_trx_mrgn_value_usd, 0)
                                       WHEN     gv_markup_calc_cur = 'Local'
                                            AND gv_onhand_currency = 'Local'
                                       THEN
                                             NVL (ln_trx_mrgn_value_local, 0)
                                           * (SELECT get_conv_rate (
                                                         pv_from_currency   =>
                                                             rec_onhand_direct.oh_store_currency,
                                                         pv_to_currency   =>
                                                             'USD',
                                                         pv_conversion_type   =>
                                                             rec_onhand_direct.oh_attr4_jl_exch_rate,
                                                         pd_conversion_date   =>
                                                             TRUNC (
                                                                 rec_onhand_direct.oh_soh_date))
                                                FROM DUAL)
                                       ELSE
                                           NVL (ln_trx_mrgn_value_usd, 0)
                                   END,
                                   0),
                               2) usdval
                      INTO l_usd_val
                      FROM DUAL;

                    UPDATE xxdo.xxd_gl_je_ret_ic_onhand_stg_t
                       SET oh_usdval             = l_usd_val,
                           oh_localval          =
                               ROUND (
                                     l_usd_val
                                   * (SELECT get_conv_rate (
                                                 pv_from_currency   => 'USD',
                                                 pv_to_currency     =>
                                                     rec_onhand_direct.oh_store_currency,
                                                 pv_conversion_type   =>
                                                     rec_onhand_direct.oh_attr4_jl_exch_rate,
                                                 pd_conversion_date   =>
                                                     TRUNC (
                                                         rec_onhand_direct.oh_soh_date))
                                        FROM DUAL),
                                   2),
                           oh_mrgn_cst_local     = ln_margin_str_curr,
                           oh_mrgn_cst_usd       = ln_margin_usd,
                           oh_mrgn_value_local   = ln_trx_mrgn_value_local,
                           oh_mrgn_value_usd     = ln_trx_mrgn_value_usd,
                           oh_markup_local       = ln_oh_markup_local,
                           oh_markup_usd         = ln_oh_markup_usd,
                           attribute1            = ln_oh_markup_local_at_usd1,
                           attribute5            = ln_oh_markup_local_at_usd,
                           last_update_date      = SYSDATE,
                           last_updated_by       = gn_user_id
                     WHERE     ROWID = rec_onhand_direct.oh_row_id
                           AND store_number =
                               rec_onhand_direct.oh_store_number
                           AND item_id = rec_onhand_direct.oh_item_id
                           AND request_id = pn_request_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                END;

                ln_loop_ctr                      := ln_loop_ctr + 1;

                --Issue commit for every gn_commit_rows records
                IF MOD (ln_loop_ctr, gn_commit_rows) = 0
                THEN
                    COMMIT;
                END IF;
            END LOOP;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put (
                fnd_file.LOG,
                'Error while fetching the update_oh_direct_ou - ' || SQLERRM);
    --  x_ret_message := SQLERRM;
    END update_oh_direct_ou;

    PROCEDURE update_oh_direct_markup_values (x_ret_message OUT VARCHAR2)
    IS
        CURSOR c_onhand_direct_ou IS
            SELECT DISTINCT oh.operating_unit
              FROM xxdo.xxd_gl_je_ret_ic_onhand_stg_t oh
             WHERE     1 = 1
                   AND oh.request_id = gn_request_id
                   AND oh.markup_type = 'DIRECT';

        l_req_id        NUMBER;
        l_req_id1       VARCHAR2 (1000);

        l_req_id2       NUMBER;
        l_phase2        VARCHAR2 (100);
        l_status2       VARCHAR2 (30);
        l_dev_phase2    VARCHAR2 (100);
        l_dev_status2   VARCHAR2 (100);
        l_wait_req2     BOOLEAN;
        l_message2      VARCHAR2 (2000);

        l_req_id3       NUMBER;
        l_phase3        VARCHAR2 (100);
        l_status3       VARCHAR2 (30);
        l_dev_phase3    VARCHAR2 (100);
        l_dev_status3   VARCHAR2 (100);
        l_wait_req3     BOOLEAN;
        l_message3      VARCHAR2 (2000);

        l_req_id4       NUMBER;
        l_phase4        VARCHAR2 (100);
        l_status4       VARCHAR2 (30);
        l_dev_phase4    VARCHAR2 (100);
        l_dev_status4   VARCHAR2 (100);
        l_wait_req4     BOOLEAN;
        l_message4      VARCHAR2 (2000);

        l_req_id5       NUMBER;
        l_phase5        VARCHAR2 (100);
        l_status5       VARCHAR2 (30);
        l_dev_phase5    VARCHAR2 (100);
        l_dev_status5   VARCHAR2 (100);
        l_wait_req5     BOOLEAN;
        l_message5      VARCHAR2 (2000);

        l_req_id6       NUMBER;
        l_phase6        VARCHAR2 (100);
        l_status6       VARCHAR2 (30);
        l_dev_phase6    VARCHAR2 (100);
        l_dev_status6   VARCHAR2 (100);
        l_wait_req6     BOOLEAN;
        l_message6      VARCHAR2 (2000);

        l_req_id7       NUMBER;
        l_phase7        VARCHAR2 (100);
        l_status7       VARCHAR2 (30);
        l_dev_phase7    VARCHAR2 (100);
        l_dev_status7   VARCHAR2 (100);
        l_wait_req7     BOOLEAN;
        l_message7      VARCHAR2 (2000);

        l_req_id8       NUMBER;
        l_phase8        VARCHAR2 (100);
        l_status8       VARCHAR2 (30);
        l_dev_phase8    VARCHAR2 (100);
        l_dev_status8   VARCHAR2 (100);
        l_wait_req8     BOOLEAN;
        l_message8      VARCHAR2 (2000);
    BEGIN
        FND_GLOBAL.APPS_INITIALIZE (gn_user_id, gn_resp_id, gn_resp_appl_id);

        FOR rec_oh_direct_ou IN c_onhand_direct_ou
        LOOP
            l_req_id    := NULL;

            BEGIN
                l_req_id   :=
                    apps.fnd_request.submit_request ('XXDO', 'XXD_GL_JE_RETAIL_IC_OU', NULL, NULL, FALSE, rec_oh_direct_ou.operating_unit
                                                     , gn_request_id);
                COMMIT;

                IF NVL (l_req_id, 0) = 0
                THEN
                    write_log (
                           'Error in Deckers Retail IC Markup - EMEA OU: '
                        || rec_oh_direct_ou.operating_unit);
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    write_log (
                           'Error in Deckers Retail IC Markup - EMEA OU: '
                        || rec_oh_direct_ou.operating_unit);
            END;

            l_req_id1   := l_req_id1 || '-' || l_req_id;
        END LOOP;

        COMMIT;

        SELECT REGEXP_SUBSTR (l_req_id1, '[^-]+', 1,
                              1),
               REGEXP_SUBSTR (l_req_id1, '[^-]+', 1,
                              2),
               REGEXP_SUBSTR (l_req_id1, '[^-]+', 1,
                              3),
               REGEXP_SUBSTR (l_req_id1, '[^-]+', 1,
                              4),
               REGEXP_SUBSTR (l_req_id1, '[^-]+', 1,
                              5),
               REGEXP_SUBSTR (l_req_id1, '[^-]+', 1,
                              6),
               REGEXP_SUBSTR (l_req_id1, '[^-]+', 1,
                              7)
          INTO l_req_id2, l_req_id3, l_req_id4, l_req_id5,
                        l_req_id6, l_req_id7, l_req_id8
          FROM DUAL;

        IF l_req_id2 > 0
        THEN
            l_wait_req2   :=
                fnd_concurrent.wait_for_request (request_id => l_req_id2, INTERVAL => 5, phase => l_phase2, status => l_status2, dev_phase => l_dev_phase2, dev_status => l_dev_status2
                                                 , MESSAGE => l_message2);
        END IF;

        IF l_req_id3 > 0
        THEN
            l_wait_req3   :=
                fnd_concurrent.wait_for_request (request_id => l_req_id3, INTERVAL => 5, phase => l_phase3, status => l_status3, dev_phase => l_dev_phase3, dev_status => l_dev_status3
                                                 , MESSAGE => l_message3);
        END IF;

        IF l_req_id4 > 0
        THEN
            l_wait_req4   :=
                fnd_concurrent.wait_for_request (request_id => l_req_id4, INTERVAL => 5, phase => l_phase4, status => l_status4, dev_phase => l_dev_phase4, dev_status => l_dev_status4
                                                 , MESSAGE => l_message4);
        END IF;

        IF l_req_id5 > 0
        THEN
            l_wait_req5   :=
                fnd_concurrent.wait_for_request (request_id => l_req_id5, INTERVAL => 5, phase => l_phase5, status => l_status5, dev_phase => l_dev_phase5, dev_status => l_dev_status5
                                                 , MESSAGE => l_message5);
        END IF;

        IF l_req_id6 > 0
        THEN
            l_wait_req6   :=
                fnd_concurrent.wait_for_request (request_id => l_req_id6, INTERVAL => 5, phase => l_phase6, status => l_status6, dev_phase => l_dev_phase6, dev_status => l_dev_status6
                                                 , MESSAGE => l_message6);
        END IF;

        IF l_req_id7 > 0
        THEN
            l_wait_req7   :=
                fnd_concurrent.wait_for_request (request_id => l_req_id7, INTERVAL => 5, phase => l_phase7, status => l_status7, dev_phase => l_dev_phase7, dev_status => l_dev_status7
                                                 , MESSAGE => l_message7);
        END IF;

        IF l_req_id8 > 0
        THEN
            l_wait_req8   :=
                fnd_concurrent.wait_for_request (request_id => l_req_id8, INTERVAL => 5, phase => l_phase8, status => l_status8, dev_phase => l_dev_phase8, dev_status => l_dev_status8
                                                 , MESSAGE => l_message8);
        END IF;

        IF     (NVL (l_dev_phase2, 'COMPLETE') = 'COMPLETE' AND NVL (l_dev_status2, 'NORMAL') = 'NORMAL')
           AND (NVL (l_dev_phase3, 'COMPLETE') = 'COMPLETE' AND NVL (l_dev_status3, 'NORMAL') = 'NORMAL')
           AND (NVL (l_dev_phase4, 'COMPLETE') = 'COMPLETE' AND NVL (l_dev_status4, 'NORMAL') = 'NORMAL')
           AND (NVL (l_dev_phase5, 'COMPLETE') = 'COMPLETE' AND NVL (l_dev_status5, 'NORMAL') = 'NORMAL')
           AND (NVL (l_dev_phase6, 'COMPLETE') = 'COMPLETE' AND NVL (l_dev_status6, 'NORMAL') = 'NORMAL')
           AND (NVL (l_dev_phase7, 'COMPLETE') = 'COMPLETE' AND NVL (l_dev_status7, 'NORMAL') = 'NORMAL')
           AND (NVL (l_dev_phase8, 'COMPLETE') = 'COMPLETE' AND NVL (l_dev_status8, 'NORMAL') = 'NORMAL')
        THEN
            write_log (
                   'Deckers Retail IC Markup concurrent request with the request id '
                || l_req_id
                || ' completed with NORMAL status.');
        ELSE
            write_log (
                   'Deckers Retail IC Markup concurrent request with the request id '
                || l_req_id
                || ' did not complete with NORMAL status.');
            x_ret_message   :=
                ('Deckers Retail IC Markup concurrent request with the request id ' || l_req_id || ' did not complete with NORMAL status.');
        END IF; -- End of if to check if the status is normal and phase is complete

        UPDATE xxdo.xxd_gl_je_ret_ic_onhand_stg_t
           SET child_request_ids   = l_req_id1
         WHERE     1 = 1
               AND request_id = gn_request_id
               AND markup_type = 'DIRECT';

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put (
                fnd_file.LOG,
                   'Error while fetching the update_oh_direct_markup_values - '
                || SQLERRM);
            x_ret_message   := SQLERRM;
    END update_oh_direct_markup_values;

    /***********************************************************************************************
    ************************** Procedure to update Sales Markup values ***********************************
    ************************************************************************************************/

    PROCEDURE update_sales_markup_values (x_ret_message OUT VARCHAR2)
    IS
        CURSOR c_markup IS
            SELECT sales.ROWID sales_row_id, sales.store_number sales_store_number, sales.item_id sales_item_id,
                   sales.inv_org_id sales_inv_org_id, sales.as_of_date sales_as_of_date, sales.brand sales_brand,
                   sales.ou_id sales_ou_id, sales.operating_unit sales_operating_unit, sales.store_currency sales_store_currency,
                   sales.sales_avg_cost, sales.sales_total_units, sales.sales_total_cost,
                   sales.return_total_units, sales.return_total_cost, sales.transaction_date sales_transaction_date,
                   sales.markup_type sales_markup_type
              FROM xxdo.xxd_gl_je_ret_ic_markup_stg_t sales
             WHERE 1 = 1 AND sales.request_id = gn_request_id
            UNION ALL
            SELECT sales.ROWID sales_row_id, sales.store_number sales_store_number, sales.item_id sales_item_id,
                   sales.inv_org_id sales_inv_org_id, sales.as_of_date sales_as_of_date, sales.brand sales_brand,
                   sales.ou_id sales_ou_id, sales.operating_unit sales_operating_unit, sales.store_currency sales_store_currency,
                   sales.sales_avg_cost, sales.sales_total_units, sales.sales_total_cost,
                   sales.return_total_units, sales.return_total_cost, sales.transaction_date sales_transaction_date,
                   sales.markup_type sales_markup_type
              FROM xxdo.xxd_gl_je_ret_ic_markup_stg_t sales
             WHERE     1 = 1
                   AND sales.request_id = gn_request_id
                   AND NVL (sales.sales_total_units, 0) = 0
                   AND NVL (sales.return_total_units, 0) <> 0;

        xn_trx_mrgn_cst_usd              NUMBER;
        xn_trx_mrgn_cst_local            NUMBER;
        ln_trx_mrgn_cst_usd              NUMBER;
        ln_trx_mrgn_cst_local            NUMBER;
        ln_trx_mrgn_value_local          NUMBER;
        ln_trx_mrgn_value_usd            NUMBER;
        ln_trx_mrgn_cst_ret_usd          NUMBER;
        ln_trx_mrgn_cst_ret_local        NUMBER;
        xn_margin_str_curr               NUMBER;
        xn_margin_usd                    NUMBER;
        ln_margin_str_curr               NUMBER;
        ln_margin_usd                    NUMBER;
        ln_oh_prev_margin_value_local    NUMBER;
        ln_oh_prev_margin_value_usd      NUMBER;
        ln_oh_markup_local               NUMBER;
        ln_oh_markup_usd                 NUMBER;
        ln_margin_str_ret_curr           NUMBER;
        ln_margin_ret_usd                NUMBER;
        ln_trx_mrgn_value_localusd       NUMBER;
        ln_trx_mrgn_value_ret_localusd   NUMBER;
        ln_conv_rate_usd                 NUMBER;
        ln_attribute1                    NUMBER;
        ln_tot_qty                       NUMBER;
        ln_mrgn_cst_local1               NUMBER;
        ln_loop_ctr                      NUMBER := 0;
    BEGIN
        FOR rec_markup IN c_markup
        LOOP
            xn_trx_mrgn_cst_usd              := 0;
            xn_trx_mrgn_cst_local            := 0;
            ln_trx_mrgn_cst_local            := 0;
            ln_trx_mrgn_cst_usd              := 0;
            ln_trx_mrgn_value_local          := 0;
            ln_trx_mrgn_value_usd            := 0;
            ln_trx_mrgn_cst_ret_usd          := 0;
            ln_trx_mrgn_cst_ret_local        := 0;
            xn_margin_str_curr               := 0;
            xn_margin_usd                    := 0;
            ln_margin_str_curr               := 0;
            ln_margin_usd                    := 0;
            ln_margin_str_ret_curr           := 0;
            ln_margin_ret_usd                := 0;
            ln_trx_mrgn_value_localusd       := 0;
            ln_trx_mrgn_value_ret_localusd   := 0;
            ln_conv_rate_usd                 := 0;
            ln_loop_ctr                      := 0;
            ln_attribute1                    := 0;
            ln_mrgn_cst_local1               := 0;
            ln_tot_qty                       := 0;

            BEGIN
                SELECT oh_mrgn_cst_local, oh_mrgn_cst_usd, TO_NUMBER (attribute1),
                       stock_onhand
                  INTO ln_trx_mrgn_cst_local, ln_trx_mrgn_cst_usd, ln_attribute1, ln_tot_qty
                  FROM xxdo.xxd_gl_je_ret_ic_onhand_stg_t
                 WHERE     1 = 1
                       AND store_number = rec_markup.sales_store_number
                       AND item_id = rec_markup.sales_item_id
                       AND TRUNC (soh_date_ts) =
                           TRUNC (rec_markup.sales_transaction_date)
                       AND stock_onhand <> 0
                       AND ROWNUM <= 1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_trx_mrgn_cst_usd   := NULL;
            END;

            IF UPPER (rec_markup.sales_markup_type) = 'HOLDING'
            THEN
                IF ln_trx_mrgn_cst_usd IS NULL
                THEN
                    get_holding_markup_values  -- HOLDING - SALES Markup value
                                              (
                        rec_markup.sales_inv_org_id,
                        rec_markup.sales_item_id,
                        rec_markup.sales_transaction_date,
                        xn_trx_mrgn_cst_usd,
                        xn_trx_mrgn_cst_local);

                    IF rec_markup.sales_avg_cost < xn_trx_mrgn_cst_local
                    THEN
                        SELECT DECODE (NVL (xn_trx_mrgn_cst_local, 1), 0, 1, NVL (xn_trx_mrgn_cst_local, 1))
                          INTO ln_mrgn_cst_local1
                          FROM DUAL;

                        xn_trx_mrgn_cst_usd     :=
                            ROUND (
                                ((NVL (rec_markup.sales_avg_cost, 0) / (ln_mrgn_cst_local1)) * NVL (xn_trx_mrgn_cst_usd, 0)),
                                2);

                        xn_trx_mrgn_cst_local   := rec_markup.sales_avg_cost;
                    END IF;

                    IF xn_trx_mrgn_cst_usd < 0
                    THEN
                        xn_trx_mrgn_cst_usd   := 0;
                    END IF;

                    IF xn_trx_mrgn_cst_local < 0
                    THEN
                        xn_trx_mrgn_cst_local   := 0;
                    END IF;

                    ln_trx_mrgn_cst_local   := 0;
                    ln_trx_mrgn_cst_usd     := 0;

                    IF rec_markup.sales_total_units > 0
                    THEN
                        ln_trx_mrgn_cst_local   :=
                            ln_trx_mrgn_cst_local + xn_trx_mrgn_cst_local;
                        ln_trx_mrgn_cst_usd   :=
                            ln_trx_mrgn_cst_usd + xn_trx_mrgn_cst_usd;
                        ln_trx_mrgn_value_local   :=
                            ROUND (
                                (rec_markup.sales_total_units * ln_trx_mrgn_cst_local),
                                2);
                        ln_trx_mrgn_value_usd   :=
                            ROUND (
                                (rec_markup.sales_total_units * ln_trx_mrgn_cst_usd),
                                2);
                        ln_trx_mrgn_value_localusd   :=
                            ROUND (
                                  ln_trx_mrgn_value_local
                                * get_conv_rate (
                                      pv_from_currency     =>
                                          rec_markup.sales_store_currency,
                                      pv_to_currency       => 'USD',
                                      pv_conversion_type   => gv_rate_type,
                                      pd_conversion_date   =>
                                          TRUNC (rec_markup.sales_as_of_date)),
                                2);
                    END IF;

                    IF     rec_markup.sales_total_units > 0
                       AND rec_markup.return_total_units < 0
                    THEN                -- HOLDING - SALES RETURN Markup value
                        ln_trx_mrgn_cst_ret_local   :=
                            ROUND (
                                (rec_markup.return_total_units * xn_trx_mrgn_cst_local),
                                2);
                        ln_trx_mrgn_cst_ret_usd   :=
                            ROUND (
                                (rec_markup.return_total_units * xn_trx_mrgn_cst_usd),
                                2);
                        ln_trx_mrgn_value_ret_localusd   :=
                            ROUND (
                                  ln_trx_mrgn_cst_ret_local
                                * get_conv_rate (
                                      pv_from_currency     =>
                                          rec_markup.sales_store_currency,
                                      pv_to_currency       => 'USD',
                                      pv_conversion_type   => gv_rate_type,
                                      pd_conversion_date   =>
                                          TRUNC (rec_markup.sales_as_of_date)),
                                2);
                    END IF;

                    IF     NVL (rec_markup.sales_total_units, 0) = 0
                       AND rec_markup.return_total_units < 0
                    THEN                -- HOLDING - SALES RETURN Markup value
                        ln_trx_mrgn_cst_ret_local   :=
                            ROUND (
                                (rec_markup.return_total_units * xn_trx_mrgn_cst_local),
                                2);
                        ln_trx_mrgn_cst_ret_usd   :=
                            ROUND (
                                (rec_markup.return_total_units * xn_trx_mrgn_cst_usd),
                                2);
                        ln_trx_mrgn_value_ret_localusd   :=
                            ROUND (
                                  ln_trx_mrgn_cst_ret_local
                                * get_conv_rate (
                                      pv_from_currency     =>
                                          rec_markup.sales_store_currency,
                                      pv_to_currency       => 'USD',
                                      pv_conversion_type   => gv_rate_type,
                                      pd_conversion_date   =>
                                          TRUNC (rec_markup.sales_as_of_date)),
                                2);
                    END IF;
                ELSE
                    IF rec_markup.sales_total_units > 0
                    THEN
                        ln_trx_mrgn_value_local   :=
                            ROUND (
                                (rec_markup.sales_total_units * ln_trx_mrgn_cst_local),
                                2);
                        ln_trx_mrgn_value_usd   :=
                            ROUND (
                                (rec_markup.sales_total_units * ln_trx_mrgn_cst_usd),
                                2);
                        ln_trx_mrgn_value_localusd   :=
                            ROUND (
                                ((NVL (ln_attribute1, 0) / NVL (ln_tot_qty, 1)) * rec_markup.sales_total_units),
                                2);
                    END IF;

                    IF     rec_markup.sales_total_units > 0
                       AND rec_markup.return_total_units < 0
                    THEN                -- HOLDING - SALES RETURN Markup value
                        ln_trx_mrgn_cst_ret_local   :=
                            ROUND (
                                (rec_markup.return_total_units * ln_trx_mrgn_cst_local),
                                2);
                        ln_trx_mrgn_cst_ret_usd   :=
                            ROUND (
                                (rec_markup.return_total_units * ln_trx_mrgn_cst_usd),
                                2);
                        ln_trx_mrgn_value_ret_localusd   :=
                            ROUND (
                                ((NVL (ln_attribute1, 0) / NVL (ln_tot_qty, 1)) * rec_markup.return_total_units),
                                2);
                    END IF;

                    IF     NVL (rec_markup.sales_total_units, 0) = 0
                       AND rec_markup.return_total_units < 0
                    THEN                -- HOLDING - SALES RETURN Markup value
                        ln_trx_mrgn_cst_ret_local   :=
                            ROUND (
                                (rec_markup.return_total_units * ln_trx_mrgn_cst_local),
                                2);
                        ln_trx_mrgn_cst_ret_usd   :=
                            ROUND (
                                (rec_markup.return_total_units * ln_trx_mrgn_cst_usd),
                                2);
                        ln_trx_mrgn_value_ret_localusd   :=
                            ROUND (
                                ((NVL (ln_attribute1, 0) / NVL (ln_tot_qty, 1)) * rec_markup.return_total_units),
                                2);
                    END IF;
                END IF;

                BEGIN
                    UPDATE xxdo.xxd_gl_je_ret_ic_markup_stg_t
                       SET sales_mrgn_cst_local = ln_trx_mrgn_cst_local, sales_mrgn_cst_usd = ln_trx_mrgn_cst_usd, sales_mrgn_value_local = ln_trx_mrgn_value_local,
                           sales_mrgn_value_usd = ln_trx_mrgn_value_usd, return_mrgn_value_local = ln_trx_mrgn_cst_ret_local, return_mrgn_value_usd = ln_trx_mrgn_cst_ret_usd,
                           attribute1 = ln_trx_mrgn_value_localusd, attribute5 = ln_trx_mrgn_value_ret_localusd, as_of_date = gd_cut_of_date,
                           last_update_date = SYSDATE, last_updated_by = gn_user_id
                     WHERE     ROWID = rec_markup.sales_row_id
                           AND store_number = rec_markup.sales_store_number
                           AND item_id = rec_markup.sales_item_id
                           AND request_id = gn_request_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                END;
            END IF;

            IF UPPER (rec_markup.sales_markup_type) = 'DIRECT'
            THEN
                IF ln_trx_mrgn_cst_usd IS NULL
                THEN
                    get_direct_sales_markup_values (
                        rec_markup.sales_store_number,
                        rec_markup.sales_item_id,
                        rec_markup.sales_operating_unit,
                        xn_margin_str_curr,
                        xn_margin_usd);

                    IF rec_markup.sales_avg_cost < xn_margin_str_curr
                    THEN
                        SELECT DECODE (NVL (xn_margin_str_curr, 1), 0, 1, NVL (xn_margin_str_curr, 1))
                          INTO ln_mrgn_cst_local1
                          FROM DUAL;

                        xn_margin_usd        :=
                            ROUND (
                                ((NVL (rec_markup.sales_avg_cost, 0) / (ln_mrgn_cst_local1)) * NVL (xn_margin_usd, 0)),
                                2);

                        xn_margin_str_curr   := rec_markup.sales_avg_cost;
                    END IF;

                    IF xn_margin_str_curr < 0
                    THEN
                        xn_margin_str_curr   := 0;
                    END IF;

                    IF xn_margin_usd < 0
                    THEN
                        xn_margin_usd   := 0;
                    END IF;

                    ln_trx_mrgn_cst_local   := 0;
                    ln_trx_mrgn_cst_usd     := 0;

                    IF rec_markup.sales_total_units > 0
                    THEN                        -- DIRECT - SALES Markup value
                        ln_trx_mrgn_cst_local   :=
                            ln_trx_mrgn_cst_local + xn_margin_str_curr;
                        ln_trx_mrgn_cst_usd   :=
                            ln_trx_mrgn_cst_usd + xn_margin_usd;
                        ln_trx_mrgn_value_local   :=
                            ROUND (
                                (rec_markup.sales_total_units * ln_trx_mrgn_cst_local),
                                2);
                        ln_trx_mrgn_value_usd   :=
                            ROUND (
                                (rec_markup.sales_total_units * ln_trx_mrgn_cst_usd),
                                2);
                        ln_trx_mrgn_value_localusd   :=
                            ROUND (
                                  ln_trx_mrgn_value_local
                                * get_conv_rate (
                                      pv_from_currency     =>
                                          rec_markup.sales_store_currency,
                                      pv_to_currency       => 'USD',
                                      pv_conversion_type   => gv_rate_type,
                                      pd_conversion_date   =>
                                          TRUNC (rec_markup.sales_as_of_date)),
                                2);
                    END IF;

                    IF     rec_markup.sales_total_units > 0
                       AND rec_markup.return_total_units < 0
                    THEN             -- DIRECT - SALES and RETURN Markup value
                        ln_margin_str_ret_curr   :=
                            ROUND (
                                (rec_markup.return_total_units * xn_margin_str_curr),
                                2);
                        ln_margin_ret_usd   :=
                            ROUND (
                                (rec_markup.return_total_units * xn_margin_usd),
                                2);
                        ln_trx_mrgn_value_ret_localusd   :=
                            ROUND (
                                  ln_margin_str_ret_curr
                                * get_conv_rate (
                                      pv_from_currency     =>
                                          rec_markup.sales_store_currency,
                                      pv_to_currency       => 'USD',
                                      pv_conversion_type   => gv_rate_type,
                                      pd_conversion_date   =>
                                          TRUNC (rec_markup.sales_as_of_date)),
                                2);
                    END IF;

                    IF     NVL (rec_markup.sales_total_units, 0) = 0
                       AND rec_markup.return_total_units < 0
                    THEN                  -- DIRECT - ONLY RETURN Markup value
                        ln_margin_str_ret_curr   :=
                            ROUND (
                                (rec_markup.return_total_units * xn_margin_str_curr),
                                2);
                        ln_margin_ret_usd   :=
                            ROUND (
                                (rec_markup.return_total_units * xn_margin_usd),
                                2);
                        ln_trx_mrgn_value_ret_localusd   :=
                            ROUND (
                                  ln_margin_str_ret_curr
                                * get_conv_rate (
                                      pv_from_currency     =>
                                          rec_markup.sales_store_currency,
                                      pv_to_currency       => 'USD',
                                      pv_conversion_type   => gv_rate_type,
                                      pd_conversion_date   =>
                                          TRUNC (rec_markup.sales_as_of_date)),
                                2);
                    END IF;
                ELSE
                    IF rec_markup.sales_total_units > 0
                    THEN                        -- DIRECT - SALES Markup value
                        ln_trx_mrgn_value_local   :=
                            ROUND (
                                (rec_markup.sales_total_units * ln_trx_mrgn_cst_local),
                                2);
                        ln_trx_mrgn_value_usd   :=
                            ROUND (
                                (rec_markup.sales_total_units * ln_trx_mrgn_cst_usd),
                                2);
                        ln_trx_mrgn_value_localusd   :=
                            ROUND (
                                ((NVL (ln_attribute1, 0) / NVL (ln_tot_qty, 1)) * rec_markup.sales_total_units),
                                2);
                    END IF;

                    IF     rec_markup.sales_total_units > 0
                       AND rec_markup.return_total_units < 0
                    THEN             -- DIRECT - SALES and RETURN Markup value
                        ln_margin_str_ret_curr   :=
                            ROUND (
                                (rec_markup.return_total_units * ln_trx_mrgn_cst_local),
                                2);
                        ln_margin_ret_usd   :=
                            ROUND (
                                (rec_markup.return_total_units * ln_trx_mrgn_cst_usd),
                                2);
                        ln_trx_mrgn_value_ret_localusd   :=
                            ROUND (
                                ((NVL (ln_attribute1, 0) / NVL (ln_tot_qty, 1)) * rec_markup.return_total_units),
                                2);
                    END IF;

                    IF     NVL (rec_markup.sales_total_units, 0) = 0
                       AND rec_markup.return_total_units < 0
                    THEN                  -- DIRECT - ONLY RETURN Markup value
                        ln_margin_str_ret_curr   :=
                            ROUND (
                                (rec_markup.return_total_units * ln_trx_mrgn_cst_local),
                                2);
                        ln_margin_ret_usd   :=
                            ROUND (
                                (rec_markup.return_total_units * ln_trx_mrgn_cst_usd),
                                2);
                        ln_trx_mrgn_value_ret_localusd   :=
                            ROUND (
                                ((NVL (ln_attribute1, 0) / NVL (ln_tot_qty, 1)) * rec_markup.return_total_units),
                                2);
                    END IF;
                END IF;

                BEGIN
                    UPDATE xxdo.xxd_gl_je_ret_ic_markup_stg_t
                       SET sales_mrgn_cst_local = ln_trx_mrgn_cst_local, sales_mrgn_cst_usd = ln_trx_mrgn_cst_usd, sales_mrgn_value_local = ln_trx_mrgn_value_local,
                           sales_mrgn_value_usd = ln_trx_mrgn_value_usd, return_mrgn_value_local = ln_margin_str_ret_curr, return_mrgn_value_usd = ln_margin_ret_usd,
                           attribute1 = ln_trx_mrgn_value_localusd, attribute5 = ln_trx_mrgn_value_ret_localusd, as_of_date = gd_cut_of_date,
                           last_update_date = SYSDATE, last_updated_by = gn_user_id
                     WHERE     ROWID = rec_markup.sales_row_id
                           AND store_number = rec_markup.sales_store_number
                           AND item_id = rec_markup.sales_item_id
                           AND request_id = gn_request_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                END;
            END IF;

            ln_loop_ctr                      := ln_loop_ctr + 1;

            --Issue commit for every gn_commit_rows records
            IF MOD (ln_loop_ctr, gn_commit_rows) = 0
            THEN
                COMMIT;
            END IF;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put (
                fnd_file.LOG,
                   'Error while fetching the update_sales_markup_values - '
                || SQLERRM);
            x_ret_message   := SQLERRM;
    END update_sales_markup_values;

    /***********************************************************************************************
    ************************** Procedure to validate staging GL Data *******************************
    ************************************************************************************************/

    PROCEDURE validate_gl_data (x_ret_msg OUT NOCOPY VARCHAR2)
    IS
        lv_js_markup                 gl_je_sources.user_je_source_name%TYPE;
        lv_js_elimination            gl_je_sources.user_je_source_name%TYPE;
        lv_journal_cat_markup        gl_je_categories.user_je_category_name%TYPE;
        lv_journal_cat_elimination   gl_je_categories.user_je_category_name%TYPE;
        lv_currency_code             fnd_currencies.currency_code%TYPE;
        lv_ledger_id                 NUMBER;
        lv_ret_status                VARCHAR2 (1);
        lv_ret_msg                   VARCHAR2 (4000);
        lv_credit_ccid               VARCHAR2 (2000);
        lv_debit_ccid                VARCHAR2 (2000);
        ln_structure_number          NUMBER;
        lb_sucess                    BOOLEAN;
        v_seg_count                  NUMBER;
        lv_oh_period_name            gl_periods.period_name%TYPE;
        lv_sale_period_name          gl_periods.period_name%TYPE;
        lv_oh_transaction_date       DATE;
        lv_sale_transaction_date     DATE;
        lv_ledger_name               gl_ledgers.name%TYPE;
        l_markup_ledger              VARCHAR2 (240);
        l_markup_source              VARCHAR2 (240);
        l_markup_category            VARCHAR2 (240);
        l_journal_batch              VARCHAR2 (500);
        l_journal_name               VARCHAR2 (500);
        l_onhand_ledger              VARCHAR2 (240);
        l_onhand_source              VARCHAR2 (240);
        l_onhand_category            VARCHAR2 (240);
        l_oh_journal_batch           VARCHAR2 (500);
        l_oh_journal_name            VARCHAR2 (500);
        l_sales_ledger_id            NUMBER;
        l_onhand_ledger_id           NUMBER;
        l_sales_cnt                  NUMBER;
        l_onhand_cnt                 NUMBER;

        CURSOR c_gl_oh_data IS
            SELECT stg.ROWID, stg.*
              FROM xxdo.xxd_gl_je_ret_ic_onhand_stg_t stg
             WHERE     request_id = gn_request_id
                   AND NVL (oh_markup_usd, 0) <> 0
                   AND record_status = 'N';

        CURSOR c_gl_sale_data IS
            SELECT stg.ROWID, stg.*
              FROM xxdo.xxd_gl_je_ret_ic_markup_stg_t stg
             WHERE request_id = gn_request_id AND record_status = 'N';
    BEGIN
        write_log ('Start validate_gl_data');
        lv_ret_status           := 'S';
        lv_ret_msg              := NULL;

        SELECT ffvl.attribute2, ffvl.attribute3, ffvl.attribute4,
               ffvl.attribute5
          INTO l_markup_source, l_markup_category, l_journal_batch, l_journal_name
          FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
         WHERE     1 = 1
               AND ffvs.flex_value_set_name = 'XXD_GL_JE_IC_MARKUP_TYPES'
               AND ffvs.flex_value_set_id = ffvl.flex_value_set_id
               AND flex_value = 'MARKUP'
               AND SYSDATE BETWEEN NVL (ffvl.start_date_active, SYSDATE)
                               AND NVL (ffvl.end_date_active, SYSDATE + 1)
               AND ffvl.enabled_flag = 'Y';

        SELECT ffvl.attribute2, ffvl.attribute3, ffvl.attribute4,
               ffvl.attribute5
          INTO l_onhand_source, l_onhand_category, l_oh_journal_batch, l_oh_journal_name
          FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
         WHERE     1 = 1
               AND ffvs.flex_value_set_name = 'XXD_GL_JE_IC_MARKUP_TYPES'
               AND ffvs.flex_value_set_id = ffvl.flex_value_set_id
               AND flex_value = 'ONHAND'
               AND SYSDATE BETWEEN NVL (ffvl.start_date_active, SYSDATE)
                               AND NVL (ffvl.end_date_active, SYSDATE + 1)
               AND ffvl.enabled_flag = 'Y';

        BEGIN
            SELECT DISTINCT ledger_id
              INTO l_sales_ledger_id
              FROM xxdo.XXD_GL_JE_RET_IC_MARKUP_STG_T
             WHERE request_id = gn_request_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        BEGIN
            SELECT DISTINCT ledger_id
              INTO l_onhand_ledger_id
              FROM xxdo.XXD_GL_JE_RET_IC_ONHAND_STG_T
             WHERE request_id = gn_request_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        IF l_sales_ledger_id IS NOT NULL OR l_onhand_ledger_id IS NOT NULL
        THEN
            lv_sale_period_name   :=
                get_period_name (l_sales_ledger_id, gd_cut_of_date);
            lv_oh_period_name   :=
                get_period_name (l_onhand_ledger_id, gd_cut_of_date);

            IF (lv_sale_period_name IS NULL AND lv_oh_period_name IS NULL)
            THEN
                lv_ret_status   := 'E';
                lv_ret_msg      :=
                       lv_ret_msg
                    || CHR (10)
                    || 'Period is either Closed or Not Opened.';
                write_log (
                       'Error Occured in Period is either Not Opened or Closed for provided Ledger-'
                    || SQLERRM);
            END IF;
        ELSIF l_sales_ledger_id IS NULL
        THEN
            lv_ret_msg   :=
                   lv_ret_msg
                || CHR (10)
                || 'No Retail Sales records for the Parameters provided.';
        END IF;

        ---- SOURCE NAME Validation -----
        lv_js_markup            := get_js_markup (l_markup_source);

        IF (lv_js_markup IS NULL)
        THEN
            lv_ret_status   := 'E';
            lv_ret_msg      :=
                   lv_ret_msg
                || CHR (10)
                || 'The SOURCE NAME for MARKUP is not correct.';
            write_log (
                'Error Occured in sales Source validation-' || SQLERRM);
        END IF;

        lv_js_elimination       := get_js_elimination (l_onhand_source);

        IF (lv_js_elimination IS NULL)
        THEN
            lv_ret_status   := 'E';
            lv_ret_msg      :=
                   lv_ret_msg
                || CHR (10)
                || 'The SOURCE NAME for ELIMINATION is not correct.';
            write_log (
                'Error Occured in onhand Source validation-' || SQLERRM);
        END IF;

        write_log ('Source Validation completed');

        ---- CATEGORY NAME Validation -----
        lv_journal_cat_markup   := get_journal_cat_markup (l_markup_category);

        IF (lv_journal_cat_markup IS NULL)
        THEN
            lv_ret_status   := 'E';
            lv_ret_msg      :=
                   lv_ret_msg
                || CHR (10)
                || 'The SOURCE CATEGORY for MARKUP is not correct.';
            write_log (
                'Error Occured in Sales category validation-' || SQLERRM);
        END IF;

        lv_journal_cat_elimination   :=
            get_journal_cat_elimination (l_onhand_category);

        IF (lv_journal_cat_elimination IS NULL)
        THEN
            lv_ret_status   := 'E';
            lv_ret_msg      :=
                   lv_ret_msg
                || CHR (10)
                || 'The SOURCE CATEGORY for ELIMINATION is not correct.';
            write_log (
                'Error Occured in Onhand category validation-' || SQLERRM);
        END IF;

        write_log ('Category Validation completed');
        --END IF;
        write_log ('lv_ret_status-' || lv_ret_status);

        IF lv_ret_status = 'S'
        THEN
            FOR r_gl_oh_data IN c_gl_oh_data
            LOOP
                lv_ret_status            := 'S';
                lv_ret_msg               := NULL;
                lv_debit_ccid            := NULL;
                lv_credit_ccid           := NULL;
                lv_oh_period_name        := NULL;
                lv_oh_transaction_date   := NULL;
                lv_currency_code         := NULL;

                ---- Code combination validation for Debit segments ----
                BEGIN
                    ln_structure_number   := NULL;
                    lb_sucess             := NULL;
                    lv_ledger_name        := NULL;

                    SELECT chart_of_accounts_id, name, currency_code
                      INTO ln_structure_number, lv_ledger_name, lv_currency_code
                      FROM gl_ledgers
                     WHERE ledger_id = r_gl_oh_data.ledger_id;

                    lv_debit_ccid         := r_gl_oh_data.oh_debit_code_comb;
                    lb_sucess             :=
                        fnd_flex_keyval.validate_segs (
                            operation          => 'CREATE_COMBINATION',
                            appl_short_name    => 'SQLGL',
                            key_flex_code      => 'GL#',
                            structure_number   => ln_structure_number,
                            concat_segments    => lv_debit_ccid,
                            validation_date    => SYSDATE);

                    write_log ('lv_debit_ccid:' || lv_debit_ccid);

                    IF lb_sucess
                    THEN
                        write_log (
                               'Successful. Onhand Debit Code Combination ID:'
                            || fnd_flex_keyval.combination_id ());
                    ELSE
                        lv_ret_status   := 'E';
                        lv_ret_msg      :=
                               lv_ret_msg
                            || ' - '
                            || 'One or more provided Onhand Debit Segment values are not correct combination.';
                        write_log (
                               'Error creating a Onhand Debit Code Combination ID for '
                            || lv_debit_ccid
                            || 'Error:'
                            || fnd_flex_keyval.error_message ());
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_ret_status   := 'E';
                        lv_ret_msg      :=
                               lv_ret_msg
                            || ' - '
                            || 'Unexpected Error creating a Code Combination ID with provided Onhand Debit Segment values.';
                        write_log (
                               'Unable to create a Onhand Debit Code Combination ID for '
                            || lv_debit_ccid
                            || 'Error:'
                            || SQLERRM ());
                END;

                ---- Code combination validation for Credit segments ----

                BEGIN
                    ln_structure_number   := NULL;
                    lb_sucess             := NULL;

                    SELECT chart_of_accounts_id
                      INTO ln_structure_number
                      FROM gl_ledgers
                     WHERE ledger_id = r_gl_oh_data.ledger_id;

                    lv_credit_ccid        := r_gl_oh_data.oh_credit_code_comb;
                    lb_sucess             :=
                        fnd_flex_keyval.validate_segs (
                            operation          => 'CREATE_COMBINATION',
                            appl_short_name    => 'SQLGL',
                            key_flex_code      => 'GL#',
                            structure_number   => ln_structure_number,
                            concat_segments    => lv_credit_ccid,
                            validation_date    => SYSDATE);

                    write_log ('lv_credit_ccid:' || lv_credit_ccid);

                    IF lb_sucess
                    THEN
                        write_log (
                               'Successful. Onhand Credit Code Combination ID:'
                            || fnd_flex_keyval.combination_id ());
                    ELSE
                        lv_ret_status   := 'E';
                        lv_ret_msg      :=
                               lv_ret_msg
                            || ' - '
                            || 'One or more provided Onhand Credit Segment values are not correct combination.';
                        write_log (
                               'Error creating a Onhand Credit Code Combination ID for '
                            || lv_credit_ccid
                            || 'Error:'
                            || fnd_flex_keyval.error_message ());
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_ret_status   := 'E';
                        lv_ret_msg      :=
                               lv_ret_msg
                            || ' - '
                            || 'Unexpected Error creating a Code Combination ID with provided Onahnd Credit Segment values.';
                        write_log (
                               'Unable to create a Onhand Credit Code Combination ID for '
                            || lv_credit_ccid
                            || 'Error:'
                            || SQLERRM ());
                END;

                -- Update status and derived values in to STG table
                UPDATE xxdo.xxd_gl_je_ret_ic_onhand_stg_t
                   SET soh_date_ts = r_gl_oh_data.soh_date_ts, -- Accounting Date
                                                               user_je_source_name = lv_js_elimination, user_je_category_name = lv_journal_cat_elimination,
                       journal_batch_name = l_oh_journal_batch || ' ' || lv_oh_period_name || ' ' || NVL (TO_CHAR (r_gl_oh_data.soh_date_ts, 'DD-MON-RRRR'), TRUNC (SYSDATE)), journal_name = l_oh_journal_name || ' ' || lv_oh_period_name || ' ' || NVL (TO_CHAR (r_gl_oh_data.soh_date_ts, 'DD-MON-RRRR'), TRUNC (SYSDATE)), ledger_name = NVL (lv_ledger_name, ledger_name),
                       oh_ledger_currency = NVL (lv_currency_code, store_currency), -- Added as part of Consolidation OU
                                                                                    request_id = gn_request_id, record_status = lv_ret_status,
                       error_msg = error_msg || lv_ret_msg
                 WHERE     ROWID = r_gl_oh_data.ROWID
                       AND request_id = gn_request_id;
            END LOOP;

            FOR r_gl_sale_data IN c_gl_sale_data
            LOOP
                lv_ret_status              := 'S';
                lv_ret_msg                 := NULL;
                lv_debit_ccid              := NULL;
                lv_credit_ccid             := NULL;
                lv_sale_period_name        := NULL;
                lv_sale_transaction_date   := NULL;

                -- Derivation for SALE GL Period Name
                -- lv_sale_period_name := get_period_name(r_gl_sale_data.ledger_id, r_gl_sale_data.transaction_date);

                ---- Code combination validation for Debit segments ----
                BEGIN
                    ln_structure_number   := NULL;
                    lb_sucess             := NULL;
                    lv_ledger_name        := NULL;
                    lv_currency_code      := NULL;

                    SELECT chart_of_accounts_id, name, currency_code
                      INTO ln_structure_number, lv_ledger_name, lv_currency_code
                      FROM gl_ledgers
                     WHERE ledger_id = r_gl_sale_data.ledger_id;

                    IF r_gl_sale_data.return_total_units < 0
                    THEN
                        lv_debit_ccid   :=
                            r_gl_sale_data.return_debit_code_comb;
                    ELSE
                        lv_debit_ccid   :=
                            r_gl_sale_data.sales_debit_code_comb;
                    END IF;

                    lb_sucess             :=
                        fnd_flex_keyval.validate_segs (
                            operation          => 'CREATE_COMBINATION',
                            appl_short_name    => 'SQLGL',
                            key_flex_code      => 'GL#',
                            structure_number   => ln_structure_number,
                            concat_segments    => lv_debit_ccid,
                            validation_date    => SYSDATE);

                    IF lb_sucess
                    THEN
                        write_log (
                               'Successful. Sale/Return Item Debit Code Combination ID:'
                            || fnd_flex_keyval.combination_id ());
                    ELSE
                        lv_ret_status   := 'E';
                        lv_ret_msg      :=
                               lv_ret_msg
                            || ' - '
                            || 'One or more provided Sale/Return Item Debit Segment values are not correct combination.'
                            || 'Error:'
                            || fnd_flex_keyval.error_message ();
                        write_log (
                               'Error creating a Sale/Return Item Debit Code Combination ID for '
                            || lv_debit_ccid
                            || 'Error:'
                            || fnd_flex_keyval.error_message ());
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_ret_status   := 'E';
                        lv_ret_msg      :=
                               lv_ret_msg
                            || ' - '
                            || 'Unexpected Error creating a Code Combination ID with provided Sale Debit Segment values.';
                        write_log (
                               'Unable to create a Sale Debit Code Combination ID for '
                            || lv_debit_ccid
                            || 'Error:'
                            || SQLERRM ());
                END;

                ---- Code combination validation for Credit segments ----

                BEGIN
                    ln_structure_number   := NULL;
                    lb_sucess             := NULL;

                    SELECT chart_of_accounts_id
                      INTO ln_structure_number
                      FROM gl_ledgers
                     WHERE ledger_id = r_gl_sale_data.ledger_id;

                    IF r_gl_sale_data.return_total_units < 0
                    THEN
                        lv_credit_ccid   :=
                            r_gl_sale_data.return_credit_code_comb;
                    ELSE
                        lv_credit_ccid   :=
                            r_gl_sale_data.sales_credit_code_comb;
                    END IF;

                    lb_sucess             :=
                        fnd_flex_keyval.validate_segs (
                            operation          => 'CREATE_COMBINATION',
                            appl_short_name    => 'SQLGL',
                            key_flex_code      => 'GL#',
                            structure_number   => ln_structure_number,
                            concat_segments    => lv_credit_ccid,
                            validation_date    => SYSDATE);

                    IF lb_sucess
                    THEN
                        write_log (
                               'Successful. Sale/Return Item Credit Code Combination ID:'
                            || fnd_flex_keyval.combination_id ());
                    ELSE
                        lv_ret_status   := 'E';
                        lv_ret_msg      :=
                               lv_ret_msg
                            || ' - '
                            || 'One or more provided Sale/Return Item Credit Segment values are not correct combination.'
                            || 'Error:'
                            || fnd_flex_keyval.error_message ();
                        write_log (
                               'Error creating a Sale/Return Item Credit Code Combination ID for '
                            || lv_credit_ccid
                            || 'Error:'
                            || fnd_flex_keyval.error_message ());
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_ret_status   := 'E';
                        lv_ret_msg      :=
                               lv_ret_msg
                            || ' - '
                            || 'Unexpected Error creating a Code Combination ID with provided Sales Credit Segment values.';
                        write_log (
                               'Unable to create a Code Combination ID for '
                            || lv_credit_ccid
                            || 'Error:'
                            || SQLERRM ());
                END;

                -- Update status and derived values in to SALES STG table
                UPDATE xxdo.xxd_gl_je_ret_ic_markup_stg_t
                   SET transaction_date = r_gl_sale_data.transaction_date, -- Accounting Date
                                                                           user_je_source_name = lv_js_markup, user_je_category_name = lv_journal_cat_markup,
                       journal_batch_name = l_journal_batch || ' ' || lv_sale_period_name || ' ' || NVL (TO_CHAR (r_gl_sale_data.transaction_date, 'DD-MON-RRRR'), TRUNC (SYSDATE)), journal_name = l_journal_name || ' ' || lv_sale_period_name || ' ' || NVL (TO_CHAR (r_gl_sale_data.transaction_date, 'DD-MON-RRRR'), TRUNC (SYSDATE)), ledger_name = NVL (lv_ledger_name, ledger_name),
                       sales_ledger_currency = NVL (lv_currency_code, store_currency), -- Added as part of Consolidation OU
                                                                                       request_id = gn_request_id, record_status = lv_ret_status,
                       error_msg = error_msg || lv_ret_msg
                 WHERE     ROWID = r_gl_sale_data.ROWID
                       AND request_id = gn_request_id;
            END LOOP;
        ELSE
            -- Send an email notification if Setup issues
            generate_setup_err_prc (lv_ret_msg);
            x_ret_msg   := 'Setup validations error-' || SQLERRM;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log ('validate_gl_data' || SQLERRM);
            x_ret_msg   := 'validate_data-' || SQLERRM;
    END validate_gl_data;

    /***********************************************************************************************
    ************************** Procedure to Insert into GL_INTERFACE *******************************
    ************************************************************************************************/

    PROCEDURE populate_gl_int (x_ret_msg OUT NOCOPY VARCHAR2)
    IS
        --Get Valid records from staging

        CURSOR get_valid_sales_data IS
              SELECT ledger_id, user_je_source_name, user_je_category_name,
                     store_currency, sales_journal_currency, sales_ledger_currency,
                     TRUNC (transaction_date) transaction_date, TRUNC (creation_date) creation_date, SUM (sales_total_cost) sales_total_cost,
                     SUM (return_total_cost) return_total_cost, SUM (sales_mrgn_value_usd) sales_mrgn_value_usd, SUM (sales_mrgn_value_local) sales_mrgn_value_local,
                     SUM (return_mrgn_value_usd) return_mrgn_value_usd, SUM (return_mrgn_value_local) return_mrgn_value_local, sales_company,
                     sales_cr_brand, sales_cr_geo, sales_cr_channel,
                     sales_cr_account, sales_cr_dept, sales_cr_acct_return,
                     sales_cr_intercom, sales_dr_brand, sales_dr_geo,
                     sales_dr_channel, sales_dr_account, sales_dr_dept,
                     sales_dr_acct_return, sales_dr_intercom, journal_batch_name,
                     journal_name, SUM (attribute1) Sales_localusd, SUM (attribute5) Return_localusd
                FROM xxdo.xxd_gl_je_ret_ic_markup_stg_t stg
               WHERE     1 = 1
                     AND request_id = gn_request_id
                     AND record_status = 'S'
            GROUP BY ledger_id, user_je_source_name, user_je_category_name,
                     store_currency, sales_journal_currency, sales_ledger_currency,
                     TRUNC (transaction_date), TRUNC (creation_date), sales_company,
                     sales_cr_brand, sales_cr_geo, sales_cr_channel,
                     sales_cr_account, sales_cr_dept, sales_cr_acct_return,
                     sales_cr_intercom, sales_dr_brand, sales_dr_geo,
                     sales_dr_channel, sales_dr_account, sales_dr_dept,
                     sales_dr_acct_return, sales_dr_intercom, journal_batch_name,
                     journal_name;

        CURSOR get_valid_onhand_data IS
              SELECT ledger_id, user_je_source_name, user_je_category_name,
                     store_currency, oh_journal_currency, oh_ledger_currency,
                     TRUNC (soh_date_ts) soh_date_ts, TRUNC (creation_date) creation_date, SUM (oh_markup_usd) oh_markup_usd,
                     SUM (oh_markup_local) oh_markup_local, oh_company, oh_cr_brand,
                     oh_cr_geo, oh_cr_channel, oh_cr_dept,
                     oh_cr_account, oh_cr_intercom, oh_dr_brand,
                     oh_dr_geo, oh_dr_channel, oh_dr_dept,
                     oh_dr_account, oh_dr_intercom, journal_batch_name,
                     journal_name, SUM (attribute1) localusd, SUM (attribute5) journal_localusd
                FROM xxdo.xxd_gl_je_ret_ic_onhand_stg_t stg
               WHERE     1 = 1
                     AND request_id = gn_request_id
                     AND NVL (oh_markup_usd, 0) <> 0
                     AND record_status = 'S'
            GROUP BY ledger_id, user_je_source_name, user_je_category_name,
                     store_currency, oh_journal_currency, oh_ledger_currency,
                     TRUNC (soh_date_ts), TRUNC (creation_date), oh_company,
                     oh_cr_brand, oh_cr_geo, oh_cr_channel,
                     oh_cr_dept, oh_cr_account, oh_cr_intercom,
                     oh_dr_brand, oh_dr_geo, oh_dr_channel,
                     oh_dr_dept, oh_dr_account, oh_dr_intercom,
                     journal_batch_name, journal_name;

        ln_count             NUMBER := 0;
        ln_count1            NUMBER := 0;
        ln_count2            NUMBER := 0;
        ln_err_count         NUMBER := 0;
        ln_err_count1        NUMBER := 0;
        v_seq                NUMBER;
        v_group_id           NUMBER;
        v_group_id1          NUMBER;
        l_oh_journal_val     NUMBER;
        ln_conv_rate_usd     NUMBER;
        l_sale_journal_val   NUMBER;
        l_ret_journal_val    NUMBER;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Populate GL Interface');

        SELECT COUNT (*)
          INTO ln_err_count
          FROM xxdo.xxd_gl_je_ret_ic_onhand_stg_t stg
         WHERE     1 = 1
               AND request_id = gn_request_id
               AND NVL (oh_markup_usd, 0) <> 0
               AND record_status = 'E';

        SELECT COUNT (*)
          INTO ln_err_count1
          FROM xxdo.xxd_gl_je_ret_ic_markup_stg_t stg
         WHERE 1 = 1 AND request_id = gn_request_id -- AND NVL(sales_mrgn_value_usd, 0) <> 0
                                                    AND record_status = 'E';

        -- START Onhand Journal
        write_log ('ln_err_count:' || ln_err_count);

        IF ln_err_count = 0
        THEN
            FOR valid_onhand_data_rec IN get_valid_onhand_data
            LOOP
                IF (NVL (valid_onhand_data_rec.oh_markup_usd, 0) + NVL (valid_onhand_data_rec.oh_markup_local, 0)) <>
                   0
                THEN
                    ln_count           := ln_count + 1;
                    ln_conv_rate_usd   := 0;
                    l_oh_journal_val   := 0;

                    IF     gv_markup_calc_cur = 'USD'
                       AND gv_onhand_currency = 'Local'
                    THEN
                        ln_conv_rate_usd   :=
                            get_conv_rate (
                                pv_from_currency     => 'USD',
                                pv_to_currency       =>
                                    valid_onhand_data_rec.store_currency,
                                pv_conversion_type   => gv_rate_type,
                                pd_conversion_date   =>
                                    TRUNC (valid_onhand_data_rec.soh_date_ts));
                    ELSIF     gv_markup_calc_cur = 'Local'
                          AND gv_onhand_currency = 'USD'
                    THEN
                        ln_conv_rate_usd   :=
                            get_conv_rate (
                                pv_from_currency     =>
                                    valid_onhand_data_rec.store_currency,
                                pv_to_currency       => 'USD',
                                pv_conversion_type   => gv_rate_type,
                                pd_conversion_date   =>
                                    TRUNC (valid_onhand_data_rec.soh_date_ts));
                    END IF;

                    BEGIN
                        SELECT CASE
                                   WHEN     gv_markup_calc_cur = 'USD'
                                        AND gv_onhand_currency = 'USD'
                                   THEN
                                       ROUND (
                                           valid_onhand_data_rec.oh_markup_usd,
                                           2)                    -- OH Amt USD
                                   WHEN     gv_markup_calc_cur = 'Local'
                                        AND gv_onhand_currency = 'Local'
                                   THEN
                                       ROUND (
                                           valid_onhand_data_rec.oh_markup_local,
                                           (SELECT PRECISION
                                              FROM FND_CURRENCIES
                                             WHERE CURRENCY_CODE =
                                                   valid_onhand_data_rec.store_currency)) -- OH Amt Local
                                   WHEN     gv_markup_calc_cur = 'USD'
                                        AND gv_onhand_currency = 'Local'
                                   THEN
                                       ROUND (
                                             valid_onhand_data_rec.oh_markup_usd
                                           * ln_conv_rate_usd,
                                           (SELECT PRECISION
                                              FROM FND_CURRENCIES
                                             WHERE CURRENCY_CODE =
                                                   valid_onhand_data_rec.store_currency)) -- OH Amt USD
                                   WHEN     gv_markup_calc_cur = 'Local'
                                        AND gv_onhand_currency = 'USD'
                                   THEN
                                       ROUND (
                                           valid_onhand_data_rec.journal_localusd,
                                           2)                  -- OH Amt Local
                               END
                          INTO l_oh_journal_val
                          FROM DUAL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_oh_journal_val   := 0;
                    END;

                    INSERT INTO gl_interface (status,
                                              ledger_id,
                                              GROUP_ID,
                                              user_je_source_name,
                                              user_je_category_name,
                                              currency_code,
                                              actual_flag,
                                              accounting_date,
                                              date_created,
                                              created_by,
                                              entered_dr,
                                              entered_cr,
                                              segment1,
                                              segment2,
                                              segment3,
                                              segment4,
                                              segment5,
                                              segment6,
                                              segment7,
                                              segment8,
                                              reference1,        -- batch_name
                                              reference4,      -- journal_name
                                              --reference5,
                                              reference10,      -- Description
                                              currency_conversion_date,
                                              user_currency_conversion_type)
                             VALUES (
                                        'NEW',
                                        valid_onhand_data_rec.ledger_id,
                                        99998,                    -- group_id,
                                        valid_onhand_data_rec.user_je_source_name,
                                        valid_onhand_data_rec.user_je_category_name,
                                        --valid_onhand_data_rec.store_currency,
                                        CASE
                                            WHEN valid_onhand_data_rec.oh_journal_currency =
                                                 'USD'
                                            THEN
                                                'USD'          -- USD Currency
                                            ELSE
                                                valid_onhand_data_rec.store_currency -- Local Currency
                                        END,
                                        'A',
                                        valid_onhand_data_rec.soh_date_ts,
                                        valid_onhand_data_rec.creation_date,
                                        gn_user_id,
                                        CASE
                                            WHEN l_oh_journal_val > 0
                                            THEN
                                                NULL
                                            ELSE
                                                ABS (l_oh_journal_val)
                                        END,
                                        CASE
                                            WHEN l_oh_journal_val > 0
                                            THEN
                                                ABS (l_oh_journal_val)
                                            ELSE
                                                NULL
                                        END,
                                        valid_onhand_data_rec.oh_company,
                                        valid_onhand_data_rec.oh_cr_brand,
                                        valid_onhand_data_rec.oh_cr_geo,
                                        valid_onhand_data_rec.oh_cr_channel,
                                        valid_onhand_data_rec.oh_cr_dept,
                                        valid_onhand_data_rec.oh_cr_account,
                                        valid_onhand_data_rec.oh_cr_intercom,
                                        '1000',
                                           gv_ou_name
                                        || ' '
                                        || valid_onhand_data_rec.journal_batch_name,
                                           gv_ou_name
                                        || ' '
                                        || valid_onhand_data_rec.journal_name,
                                        --valid_onhand_data_rec.journal_name, -- Header description,
                                        valid_onhand_data_rec.journal_name, -- Line description
                                        CASE
                                            WHEN NVL (
                                                     valid_onhand_data_rec.oh_journal_currency,
                                                     valid_onhand_data_rec.store_currency) <>
                                                 valid_onhand_data_rec.oh_ledger_currency
                                            THEN
                                                valid_onhand_data_rec.soh_date_ts -- accounting date
                                            ELSE
                                                NULL
                                        END,
                                        CASE
                                            WHEN NVL (
                                                     valid_onhand_data_rec.oh_journal_currency,
                                                     valid_onhand_data_rec.store_currency) <>
                                                 valid_onhand_data_rec.oh_ledger_currency
                                            THEN
                                                gv_jl_rate_type -- 'Corporate'
                                            ELSE
                                                NULL
                                        END);

                    INSERT INTO gl_interface (status,
                                              ledger_id,
                                              GROUP_ID,
                                              user_je_source_name,
                                              user_je_category_name,
                                              currency_code,
                                              actual_flag,
                                              accounting_date,
                                              date_created,
                                              created_by,
                                              entered_dr,
                                              entered_cr,
                                              segment1,
                                              segment2,
                                              segment3,
                                              segment4,
                                              segment5,
                                              segment6,
                                              segment7,
                                              segment8,
                                              reference1,
                                              reference4,
                                              --reference5,
                                              reference10,      -- description
                                              currency_conversion_date,
                                              user_currency_conversion_type)
                             VALUES (
                                        'NEW',
                                        valid_onhand_data_rec.ledger_id,
                                        99998,                    -- group_id,
                                        valid_onhand_data_rec.user_je_source_name,
                                        valid_onhand_data_rec.user_je_category_name,
                                        -- valid_onhand_data_rec.store_currency,
                                        CASE
                                            WHEN valid_onhand_data_rec.oh_journal_currency =
                                                 'USD'
                                            THEN
                                                'USD'          -- USD Currency
                                            ELSE
                                                valid_onhand_data_rec.store_currency -- Local Currency
                                        END,
                                        'A',
                                        valid_onhand_data_rec.soh_date_ts,
                                        valid_onhand_data_rec.creation_date,
                                        gn_user_id,
                                        CASE
                                            WHEN l_oh_journal_val > 0
                                            THEN
                                                ABS (l_oh_journal_val)
                                            ELSE
                                                NULL
                                        END,
                                        CASE
                                            WHEN l_oh_journal_val > 0
                                            THEN
                                                NULL
                                            ELSE
                                                ABS (l_oh_journal_val)
                                        END,
                                        valid_onhand_data_rec.oh_company,
                                        valid_onhand_data_rec.oh_dr_brand,
                                        valid_onhand_data_rec.oh_dr_geo,
                                        valid_onhand_data_rec.oh_dr_channel,
                                        valid_onhand_data_rec.oh_dr_dept,
                                        valid_onhand_data_rec.oh_dr_account,
                                        valid_onhand_data_rec.oh_dr_intercom,
                                        '1000',
                                           gv_ou_name
                                        || ' '
                                        || valid_onhand_data_rec.journal_batch_name,
                                           gv_ou_name
                                        || ' '
                                        || valid_onhand_data_rec.journal_name,
                                        --valid_onhand_data_rec.journal_name,
                                        valid_onhand_data_rec.journal_name, -- description
                                        CASE
                                            WHEN NVL (
                                                     valid_onhand_data_rec.oh_journal_currency,
                                                     valid_onhand_data_rec.store_currency) <>
                                                 valid_onhand_data_rec.oh_ledger_currency
                                            THEN
                                                valid_onhand_data_rec.soh_date_ts -- accounting date
                                            ELSE
                                                NULL
                                        END,
                                        CASE
                                            WHEN NVL (
                                                     valid_onhand_data_rec.oh_journal_currency,
                                                     valid_onhand_data_rec.store_currency) <>
                                                 valid_onhand_data_rec.oh_ledger_currency
                                            THEN
                                                gv_jl_rate_type -- 'Corporate'
                                            ELSE
                                                NULL
                                        END);

                    ---- Update status to STG table for processed records
                    UPDATE xxdo.xxd_gl_je_ret_ic_onhand_stg_t
                       SET record_status   = 'P'
                     WHERE 1 = 1 AND request_id = gn_request_id;
                --AND ROWID = valid_onhand_data_rec.rowid;

                END IF;
            END LOOP;

            COMMIT;
        ELSE
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error records in ONHAND Staging Table Count: '
                || ln_err_count);
        END IF;

        -- START SALES Journal Interface
        IF ln_err_count1 = 0
        THEN
            FOR valid_sales_data_rec IN get_valid_sales_data
            LOOP
                IF valid_sales_data_rec.sales_total_cost > 0
                THEN                                             -- SALES Data
                    IF (NVL (valid_sales_data_rec.sales_mrgn_value_usd, 0) + NVL (valid_sales_data_rec.sales_mrgn_value_local, 0)) <>
                       0
                    THEN
                        ln_count1            := ln_count1 + 1;
                        ln_conv_rate_usd     := 0;
                        l_sale_journal_val   := 0;

                        IF     gv_markup_calc_cur = 'USD'
                           AND gv_markup_currency = 'Local'
                        THEN                                  -- Add conv type
                            ln_conv_rate_usd   :=
                                get_conv_rate (
                                    pv_from_currency     => 'USD',
                                    pv_to_currency       =>
                                        valid_sales_data_rec.store_currency,
                                    pv_conversion_type   => gv_rate_type,
                                    pd_conversion_date   =>
                                        TRUNC (
                                            valid_sales_data_rec.transaction_date));
                        ELSIF     gv_markup_calc_cur = 'Local'
                              AND gv_markup_currency = 'USD'
                        THEN
                            ln_conv_rate_usd   :=
                                get_conv_rate (
                                    pv_from_currency     =>
                                        valid_sales_data_rec.store_currency,
                                    pv_to_currency       => 'USD',
                                    pv_conversion_type   => gv_rate_type,
                                    pd_conversion_date   =>
                                        TRUNC (
                                            valid_sales_data_rec.transaction_date));
                        END IF;

                        BEGIN
                            SELECT CASE
                                       WHEN     gv_markup_calc_cur = 'USD'
                                            AND gv_markup_currency = 'USD'
                                       THEN
                                           ROUND (
                                               valid_sales_data_rec.sales_mrgn_value_usd,
                                               2)             -- Sales Amt USD
                                       WHEN     gv_markup_calc_cur = 'Local'
                                            AND gv_markup_currency = 'Local'
                                       THEN
                                           ROUND (
                                               valid_sales_data_rec.sales_mrgn_value_local,
                                               (SELECT PRECISION
                                                  FROM FND_CURRENCIES
                                                 WHERE CURRENCY_CODE =
                                                       valid_sales_data_rec.store_currency)) -- OH Amt Local
                                       WHEN     gv_markup_calc_cur = 'USD'
                                            AND gv_markup_currency = 'Local'
                                       THEN
                                           ROUND (
                                                 valid_sales_data_rec.sales_mrgn_value_usd
                                               * ln_conv_rate_usd,
                                               (SELECT PRECISION
                                                  FROM FND_CURRENCIES
                                                 WHERE CURRENCY_CODE =
                                                       valid_sales_data_rec.store_currency)) -- OH Amt USD
                                       WHEN     gv_markup_calc_cur = 'Local'
                                            AND gv_markup_currency = 'USD'
                                       THEN
                                           ROUND (
                                               valid_sales_data_rec.Sales_localusd,
                                               2)
                                   END
                              INTO l_sale_journal_val
                              FROM DUAL;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_sale_journal_val   := 0;
                        END;

                        INSERT INTO gl_interface (
                                        status,
                                        ledger_id,
                                        GROUP_ID,
                                        user_je_source_name,
                                        user_je_category_name,
                                        currency_code,
                                        actual_flag,
                                        accounting_date,
                                        date_created,
                                        created_by,
                                        entered_dr,
                                        entered_cr,
                                        segment1,
                                        segment2,
                                        segment3,
                                        segment4,
                                        segment5,
                                        segment6,
                                        segment7,
                                        segment8,
                                        reference1,
                                        reference4,
                                        --reference5,
                                        reference10,            -- description
                                        currency_conversion_date,
                                        user_currency_conversion_type)
                                 VALUES (
                                            'NEW',
                                            valid_sales_data_rec.ledger_id,
                                            99997,                -- group_id,
                                            valid_sales_data_rec.user_je_source_name,
                                            valid_sales_data_rec.user_je_category_name,
                                            -- valid_sales_data_rec.store_currency,
                                            CASE
                                                WHEN valid_sales_data_rec.sales_journal_currency =
                                                     'USD'
                                                THEN
                                                    'USD'      -- USD Currency
                                                ELSE
                                                    valid_sales_data_rec.store_currency -- Local Currency
                                            END,
                                            'A',
                                            valid_sales_data_rec.transaction_date,
                                            valid_sales_data_rec.creation_date,
                                            gn_user_id,
                                            CASE
                                                WHEN l_sale_journal_val > 0
                                                THEN
                                                    NULL
                                                ELSE
                                                    ABS (l_sale_journal_val)
                                            END,
                                            CASE
                                                WHEN l_sale_journal_val > 0
                                                THEN
                                                    ABS (l_sale_journal_val)
                                                ELSE
                                                    NULL
                                            END,
                                            valid_sales_data_rec.sales_company,
                                            valid_sales_data_rec.sales_cr_brand,
                                            valid_sales_data_rec.sales_cr_geo,
                                            valid_sales_data_rec.sales_cr_channel,
                                            valid_sales_data_rec.sales_cr_dept,
                                            valid_sales_data_rec.sales_cr_account,
                                            valid_sales_data_rec.sales_cr_intercom,
                                            '1000',
                                               gv_ou_name
                                            || ' '
                                            || valid_sales_data_rec.journal_batch_name,
                                               gv_ou_name
                                            || ' '
                                            || valid_sales_data_rec.journal_name,
                                            --valid_sales_data_rec.journal_name,
                                            valid_sales_data_rec.journal_name, -- description
                                            CASE
                                                WHEN NVL (
                                                         valid_sales_data_rec.sales_journal_currency,
                                                         valid_sales_data_rec.store_currency) <>
                                                     valid_sales_data_rec.sales_ledger_currency
                                                THEN
                                                    valid_sales_data_rec.transaction_date -- accounting date
                                                ELSE
                                                    NULL
                                            END,
                                            CASE
                                                WHEN NVL (
                                                         valid_sales_data_rec.sales_journal_currency,
                                                         valid_sales_data_rec.store_currency) <>
                                                     valid_sales_data_rec.sales_ledger_currency
                                                THEN
                                                    gv_jl_rate_type -- 'Corporate'
                                                ELSE
                                                    NULL
                                            END);

                        INSERT INTO gl_interface (
                                        status,
                                        ledger_id,
                                        GROUP_ID,
                                        user_je_source_name,
                                        user_je_category_name,
                                        currency_code,
                                        actual_flag,
                                        accounting_date,
                                        date_created,
                                        created_by,
                                        entered_dr,
                                        entered_cr,
                                        segment1,
                                        segment2,
                                        segment3,
                                        segment4,
                                        segment5,
                                        segment6,
                                        segment7,
                                        segment8,
                                        reference1,
                                        reference4,
                                        --reference5,
                                        reference10,           -- description,
                                        currency_conversion_date,
                                        user_currency_conversion_type)
                                 VALUES (
                                            'NEW',
                                            valid_sales_data_rec.ledger_id,
                                            99997,                -- group_id,
                                            valid_sales_data_rec.user_je_source_name,
                                            valid_sales_data_rec.user_je_category_name,
                                            -- valid_sales_data_rec.store_currency,
                                            CASE
                                                WHEN valid_sales_data_rec.sales_journal_currency =
                                                     'USD'
                                                THEN
                                                    'USD'      -- USD Currency
                                                ELSE
                                                    valid_sales_data_rec.store_currency -- Local Currency
                                            END,
                                            'A',
                                            valid_sales_data_rec.transaction_date,
                                            valid_sales_data_rec.creation_date,
                                            gn_user_id,
                                            CASE
                                                WHEN l_sale_journal_val > 0
                                                THEN
                                                    ABS (l_sale_journal_val)
                                                ELSE
                                                    NULL
                                            END,
                                            CASE
                                                WHEN l_sale_journal_val > 0
                                                THEN
                                                    NULL
                                                ELSE
                                                    ABS (l_sale_journal_val)
                                            END,
                                            valid_sales_data_rec.sales_company,
                                            valid_sales_data_rec.sales_dr_brand,
                                            valid_sales_data_rec.sales_dr_geo,
                                            valid_sales_data_rec.sales_dr_channel,
                                            valid_sales_data_rec.sales_dr_dept,
                                            valid_sales_data_rec.sales_dr_account,
                                            valid_sales_data_rec.sales_dr_intercom,
                                            '1000',
                                               gv_ou_name
                                            || ' '
                                            || valid_sales_data_rec.journal_batch_name,
                                               gv_ou_name
                                            || ' '
                                            || valid_sales_data_rec.journal_name,
                                            --valid_sales_data_rec.journal_name,
                                            valid_sales_data_rec.journal_name, -- description
                                            CASE
                                                WHEN NVL (
                                                         valid_sales_data_rec.sales_journal_currency,
                                                         valid_sales_data_rec.store_currency) <>
                                                     valid_sales_data_rec.sales_ledger_currency
                                                THEN
                                                    valid_sales_data_rec.transaction_date -- accounting date
                                                ELSE
                                                    NULL
                                            END,
                                            CASE
                                                WHEN NVL (
                                                         valid_sales_data_rec.sales_journal_currency,
                                                         valid_sales_data_rec.store_currency) <>
                                                     valid_sales_data_rec.sales_ledger_currency
                                                THEN
                                                    gv_jl_rate_type -- 'Corporate'
                                                ELSE
                                                    NULL
                                            END);

                        ---- Update status to STG table for SALES processed records
                        UPDATE xxdo.xxd_gl_je_ret_ic_markup_stg_t
                           SET record_status   = 'P'
                         WHERE 1 = 1 AND request_id = gn_request_id;
                    -- AND ROWID = valid_sales_data_rec.rowid;

                    END IF;
                END IF;

                -- START RETURN Journal Interface
                IF valid_sales_data_rec.return_total_cost < 0
                THEN                                            -- RETURN Data
                    IF (NVL (valid_sales_data_rec.return_mrgn_value_usd, 0) + NVL (valid_sales_data_rec.return_mrgn_value_local, 0)) <>
                       0
                    THEN
                        ln_count2           := ln_count2 + 1;
                        ln_conv_rate_usd    := 0;
                        l_ret_journal_val   := 0;

                        IF     gv_markup_calc_cur = 'USD'
                           AND gv_markup_currency = 'Local'
                        THEN
                            ln_conv_rate_usd   :=
                                get_conv_rate (
                                    pv_from_currency     => 'USD',
                                    pv_to_currency       =>
                                        valid_sales_data_rec.store_currency,
                                    pv_conversion_type   => gv_rate_type,
                                    pd_conversion_date   =>
                                        TRUNC (
                                            valid_sales_data_rec.transaction_date));
                        ELSIF     gv_markup_calc_cur = 'Local'
                              AND gv_markup_currency = 'USD'
                        THEN
                            ln_conv_rate_usd   :=
                                get_conv_rate (
                                    pv_from_currency     =>
                                        valid_sales_data_rec.store_currency,
                                    pv_to_currency       => 'USD',
                                    pv_conversion_type   => gv_rate_type,
                                    pd_conversion_date   =>
                                        TRUNC (
                                            valid_sales_data_rec.transaction_date));
                        END IF;

                        BEGIN
                            SELECT CASE
                                       WHEN     gv_markup_calc_cur = 'USD'
                                            AND gv_markup_currency = 'USD'
                                       THEN
                                           ROUND (
                                               valid_sales_data_rec.return_mrgn_value_usd,
                                               2)                -- OH Amt USD
                                       WHEN     gv_markup_calc_cur = 'Local'
                                            AND gv_markup_currency = 'Local'
                                       THEN
                                           ROUND (
                                               valid_sales_data_rec.return_mrgn_value_local,
                                               (SELECT PRECISION
                                                  FROM FND_CURRENCIES
                                                 WHERE CURRENCY_CODE =
                                                       valid_sales_data_rec.store_currency)) -- OH Amt Local
                                       WHEN     gv_markup_calc_cur = 'USD'
                                            AND gv_markup_currency = 'Local'
                                       THEN
                                           ROUND (
                                                 valid_sales_data_rec.return_mrgn_value_usd
                                               * ln_conv_rate_usd,
                                               (SELECT PRECISION
                                                  FROM FND_CURRENCIES
                                                 WHERE CURRENCY_CODE =
                                                       valid_sales_data_rec.store_currency)) -- OH Amt USD
                                       WHEN     gv_markup_calc_cur = 'Local'
                                            AND gv_markup_currency = 'USD'
                                       THEN
                                           ROUND (
                                               valid_sales_data_rec.Return_localusd,
                                               2)
                                   END
                              INTO l_ret_journal_val
                              FROM DUAL;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_ret_journal_val   := 0;
                        END;

                        INSERT INTO gl_interface (
                                        status,
                                        ledger_id,
                                        GROUP_ID,
                                        user_je_source_name,
                                        user_je_category_name,
                                        currency_code,
                                        actual_flag,
                                        accounting_date,
                                        date_created,
                                        created_by,
                                        entered_dr,
                                        entered_cr,
                                        segment1,
                                        segment2,
                                        segment3,
                                        segment4,
                                        segment5,
                                        segment6,
                                        segment7,
                                        segment8,
                                        reference1,
                                        reference4,
                                        --reference5,
                                        reference10,            -- description
                                        currency_conversion_date,
                                        user_currency_conversion_type)
                                 VALUES (
                                            'NEW',
                                            valid_sales_data_rec.ledger_id,
                                            99997,                -- group_id,
                                            valid_sales_data_rec.user_je_source_name,
                                            valid_sales_data_rec.user_je_category_name,
                                            -- valid_sales_data_rec.store_currency,
                                            CASE
                                                WHEN valid_sales_data_rec.sales_journal_currency =
                                                     'USD'
                                                THEN
                                                    'USD'      -- USD Currency
                                                ELSE
                                                    valid_sales_data_rec.store_currency -- Local Currency
                                            END,
                                            'A',
                                            valid_sales_data_rec.transaction_date,
                                            valid_sales_data_rec.creation_date,
                                            gn_user_id,
                                            CASE
                                                WHEN l_ret_journal_val > 0
                                                THEN
                                                    ABS (l_ret_journal_val)
                                                ELSE
                                                    NULL
                                            END,
                                            CASE
                                                WHEN l_ret_journal_val > 0
                                                THEN
                                                    NULL
                                                ELSE
                                                    ABS (l_ret_journal_val)
                                            END,
                                            valid_sales_data_rec.sales_company,
                                            valid_sales_data_rec.sales_cr_brand,
                                            valid_sales_data_rec.sales_cr_geo,
                                            valid_sales_data_rec.sales_cr_channel,
                                            valid_sales_data_rec.sales_cr_dept,
                                            valid_sales_data_rec.sales_cr_acct_return,
                                            valid_sales_data_rec.sales_cr_intercom,
                                            '1000',
                                               gv_ou_name
                                            || ' '
                                            || valid_sales_data_rec.journal_batch_name,
                                               gv_ou_name
                                            || ' '
                                            || valid_sales_data_rec.journal_name,
                                            --valid_sales_data_rec.journal_name,
                                            valid_sales_data_rec.journal_name, -- description
                                            CASE
                                                WHEN NVL (
                                                         valid_sales_data_rec.sales_journal_currency,
                                                         valid_sales_data_rec.store_currency) <>
                                                     valid_sales_data_rec.sales_ledger_currency
                                                THEN
                                                    valid_sales_data_rec.transaction_date -- accounting date
                                                ELSE
                                                    NULL
                                            END,
                                            CASE
                                                WHEN NVL (
                                                         valid_sales_data_rec.sales_journal_currency,
                                                         valid_sales_data_rec.store_currency) <>
                                                     valid_sales_data_rec.sales_ledger_currency
                                                THEN
                                                    gv_jl_rate_type -- 'Corporate'
                                                ELSE
                                                    NULL
                                            END);

                        INSERT INTO gl_interface (
                                        status,
                                        ledger_id,
                                        GROUP_ID,
                                        user_je_source_name,
                                        user_je_category_name,
                                        currency_code,
                                        actual_flag,
                                        accounting_date,
                                        date_created,
                                        created_by,
                                        entered_dr,
                                        entered_cr,
                                        segment1,
                                        segment2,
                                        segment3,
                                        segment4,
                                        segment5,
                                        segment6,
                                        segment7,
                                        segment8,
                                        reference1,
                                        reference4,
                                        --reference5,
                                        reference10,            -- description
                                        currency_conversion_date,
                                        user_currency_conversion_type)
                                 VALUES (
                                            'NEW',
                                            valid_sales_data_rec.ledger_id,
                                            99997,                -- group_id,
                                            valid_sales_data_rec.user_je_source_name,
                                            valid_sales_data_rec.user_je_category_name,
                                            -- valid_sales_data_rec.store_currency,
                                            CASE
                                                WHEN valid_sales_data_rec.sales_journal_currency =
                                                     'USD'
                                                THEN
                                                    'USD'      -- USD Currency
                                                ELSE
                                                    valid_sales_data_rec.store_currency -- Local Currency
                                            END,
                                            'A',
                                            valid_sales_data_rec.transaction_date,
                                            valid_sales_data_rec.creation_date,
                                            gn_user_id,
                                            CASE
                                                WHEN l_ret_journal_val > 0
                                                THEN
                                                    NULL
                                                ELSE
                                                    ABS (l_ret_journal_val)
                                            END,
                                            CASE
                                                WHEN l_ret_journal_val > 0
                                                THEN
                                                    ABS (l_ret_journal_val)
                                                ELSE
                                                    NULL
                                            END,
                                            valid_sales_data_rec.sales_company,
                                            valid_sales_data_rec.sales_dr_brand,
                                            valid_sales_data_rec.sales_dr_geo,
                                            valid_sales_data_rec.sales_dr_channel,
                                            valid_sales_data_rec.sales_dr_dept,
                                            valid_sales_data_rec.sales_dr_acct_return,
                                            valid_sales_data_rec.sales_dr_intercom,
                                            '1000',
                                               gv_ou_name
                                            || ' '
                                            || valid_sales_data_rec.journal_batch_name,
                                               gv_ou_name
                                            || ' '
                                            || valid_sales_data_rec.journal_name,
                                            --valid_sales_data_rec.journal_name,
                                            valid_sales_data_rec.journal_name, -- description
                                            CASE
                                                WHEN NVL (
                                                         valid_sales_data_rec.sales_journal_currency,
                                                         valid_sales_data_rec.store_currency) <>
                                                     valid_sales_data_rec.sales_ledger_currency
                                                THEN
                                                    valid_sales_data_rec.transaction_date -- accounting date
                                                ELSE
                                                    NULL
                                            END,
                                            CASE
                                                WHEN NVL (
                                                         valid_sales_data_rec.sales_journal_currency,
                                                         valid_sales_data_rec.store_currency) <>
                                                     valid_sales_data_rec.sales_ledger_currency
                                                THEN
                                                    gv_jl_rate_type -- 'Corporate'
                                                ELSE
                                                    NULL
                                            END);

                        ---- Update status to STG table for RETURN processed records
                        UPDATE xxdo.xxd_gl_je_ret_ic_markup_stg_t
                           SET record_status   = 'P'
                         WHERE 1 = 1 AND request_id = gn_request_id;
                    --AND ROWID = valid_sales_data_rec.rowid;

                    END IF;
                END IF;
            END LOOP;
        ELSE
            fnd_file.put_line (
                fnd_file.LOG,
                'Error records in Staging Table Count: ' || ln_err_count);
        END IF;

        COMMIT;
        fnd_file.put_line (fnd_file.LOG,
                           'GL_INTERFACE ONHAND Record Count: ' || ln_count);
        fnd_file.put_line (fnd_file.LOG,
                           'GL_INTERFACE SALES Record Count: ' || ln_count1);
        fnd_file.put_line (
            fnd_file.LOG,
            'GL_INTERFACE SALES RETURN Record Count: ' || ln_count2);
        x_ret_msg   := NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_msg   := SQLERRM;
            fnd_file.put_line (fnd_file.LOG,
                               'Error in POPULATE_GL_INT:' || SQLERRM);
    END populate_gl_int;

    /***********************************************************************************************
    ************************** Procedure to Import Markup Sales into GL ****************************
    ************************************************************************************************/
    PROCEDURE import_markup_gl (x_ret_message OUT VARCHAR2)
    IS
        CURSOR c_markup_gl_src IS
            SELECT DISTINCT GROUP_ID, ledger_id, user_je_source_name
              FROM gl_interface
             WHERE     status = 'NEW'
                   AND user_je_source_name = 'Markup'
                   AND GROUP_ID = 99997;

        ln_access_set_id   NUMBER;
        l_source_name      gl_je_sources.je_source_name%TYPE;
        v_req_id           NUMBER;
        v_phase            VARCHAR2 (2000);
        v_wait_status      VARCHAR2 (2000);
        v_dev_phase        VARCHAR2 (2000);
        v_dev_status       VARCHAR2 (2000);
        v_message          VARCHAR2 (2000);
        v_request_status   BOOLEAN;
        l_imp_req_id       NUMBER;
        l_imp_phase        VARCHAR2 (10);
        l_imp_status       VARCHAR2 (10);
    BEGIN
        FOR j IN c_markup_gl_src
        LOOP
            gv_sales_import_status   := NULL;

            BEGIN
                SELECT je_source_name
                  INTO l_source_name
                  FROM gl_je_sources
                 WHERE user_je_source_name = j.user_je_source_name;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            BEGIN
                SELECT access_set_id
                  INTO ln_access_set_id
                  FROM (  SELECT gas.access_set_id
                            FROM gl_access_sets gas, gl_ledgers gl
                           WHERE     gas.default_ledger_id = gl.ledger_id
                                 AND gl.ledger_id = j.ledger_id
                        ORDER BY gas.access_set_id)
                 WHERE ROWNUM = 1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_access_set_id   :=
                        fnd_profile.VALUE ('GL_ACCESS_SET_ID');
            END;

            v_req_id                 :=
                fnd_request.submit_request (application   => 'SQLGL',
                                            program       => 'GLLEZLSRS', -- Short Name of program
                                            description   => NULL,
                                            start_time    => NULL,
                                            sub_request   => FALSE,
                                            argument1     => ln_access_set_id, --Data Access Set ID
                                            argument2     => l_source_name,
                                            argument3     => j.ledger_id,
                                            argument4     => j.GROUP_ID,
                                            argument5     => 'N', --Post Errors to Suspense
                                            argument6     => 'N', --Create Summary Journals
                                            argument7     => 'O'  --Import DFF
                                                                );

            COMMIT;

            IF v_req_id = 0
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Request Not Submitted due to "'
                    || fnd_message.get
                    || '".');
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Journal Import Program submitted succesfully. Request id :'
                    || v_req_id);
            END IF;

            IF v_req_id > 0
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    '   Waiting for the Journal Import Program');

                LOOP
                    v_request_status   :=
                        fnd_concurrent.wait_for_request (
                            request_id   => v_req_id,
                            INTERVAL     => 60, --interval Number of seconds to wait between checks
                            max_wait     => 0, --Maximum number of seconds to wait for the request completion
                            phase        => v_phase,
                            status       => v_wait_status,
                            dev_phase    => v_dev_phase,
                            dev_status   => v_dev_status,
                            MESSAGE      => v_message);

                    EXIT WHEN    UPPER (v_phase) = 'COMPLETED'
                              OR UPPER (v_wait_status) IN
                                     ('CANCELLED', 'ERROR', 'TERMINATED');
                END LOOP;

                COMMIT;
                fnd_file.put_line (
                    fnd_file.LOG,
                       '  Journal Import Program Request Phase'
                    || '-'
                    || v_dev_phase);
                fnd_file.put_line (
                    fnd_file.LOG,
                       '  Journal Import Program Request Dev status'
                    || '-'
                    || v_dev_status);

                BEGIN
                        SELECT request_id, phase_code, status_code
                          INTO l_imp_req_id, l_imp_phase, l_imp_status
                          FROM apps.fnd_concurrent_requests fcr
                         WHERE 1 = 1
                    START WITH fcr.parent_request_id = v_req_id
                    CONNECT BY PRIOR fcr.request_id = fcr.parent_request_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                END;

                IF UPPER (l_imp_phase) = 'C' AND UPPER (l_imp_status) = 'C'
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Sales Journal Import successfully completed for Request ID: '
                        || l_imp_req_id);
                    gv_sales_import_status   :=
                           'Sales Records Inserted to GL Interface Succesfully. Journal Import successfully completed for Request ID: '
                        || l_imp_req_id;
                ELSE
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'The Sales Journal Import request failed.Review log for Oracle Request ID: '
                        || l_imp_req_id);
                    fnd_file.put_line (fnd_file.LOG, SQLERRM);
                    gv_sales_import_status   :=
                           'Sales Records Inserted to GL Interface Succesfully. Journal Import got warning/error out for Request ID: '
                        || l_imp_req_id;
                    RETURN;
                END IF;
            END IF;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            x_ret_message   := SQLERRM;
    END import_markup_gl;

    /***********************************************************************************************
    ******************** Procedure to Import Elimination Program Onhand into GL ********************
    ************************************************************************************************/
    PROCEDURE import_onhand_gl (x_ret_message OUT VARCHAR2)
    IS
        CURSOR c_oh_gl_src IS
            SELECT DISTINCT GROUP_ID, ledger_id, user_je_source_name
              FROM gl_interface
             WHERE     status = 'NEW'
                   AND user_je_source_name = 'Elimination Program'
                   AND GROUP_ID = 99998;

        ln_access_set_id   NUMBER;
        l_source_name      gl_je_sources.je_source_name%TYPE;
        v_req_id           NUMBER;
        v_phase            VARCHAR2 (2000);
        v_wait_status      VARCHAR2 (2000);
        v_dev_phase        VARCHAR2 (2000);
        v_dev_status       VARCHAR2 (2000);
        v_message          VARCHAR2 (2000);
        v_request_status   BOOLEAN;
        l_imp_req_id       NUMBER;
        l_imp_phase        VARCHAR2 (10);
        l_imp_status       VARCHAR2 (10);
    BEGIN
        FOR j IN c_oh_gl_src
        LOOP
            gv_oh_import_status   := NULL;

            BEGIN
                SELECT je_source_name
                  INTO l_source_name
                  FROM gl_je_sources
                 WHERE user_je_source_name = j.user_je_source_name;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            BEGIN
                SELECT access_set_id
                  INTO ln_access_set_id
                  FROM (  SELECT gas.access_set_id
                            FROM gl_access_sets gas, gl_ledgers gl
                           WHERE     gas.default_ledger_id = gl.ledger_id
                                 AND gl.ledger_id = j.ledger_id
                        ORDER BY gas.access_set_id)
                 WHERE ROWNUM = 1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_access_set_id   :=
                        fnd_profile.VALUE ('GL_ACCESS_SET_ID');
            END;

            v_req_id              :=
                fnd_request.submit_request (application   => 'SQLGL',
                                            program       => 'GLLEZLSRS', -- Short Name of program
                                            description   => NULL,
                                            start_time    => NULL,
                                            sub_request   => FALSE,
                                            argument1     => ln_access_set_id, --Data Access Set ID
                                            argument2     => l_source_name,
                                            argument3     => j.ledger_id,
                                            argument4     => j.GROUP_ID,
                                            argument5     => 'N', --Post Errors to Suspense
                                            argument6     => 'N', --Create Summary Journals
                                            argument7     => 'O'  --Import DFF
                                                                );

            COMMIT;

            IF v_req_id = 0
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Request Not Submitted due to "'
                    || fnd_message.get
                    || '".');
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Journal Import Program submitted succesfully. Request id :'
                    || v_req_id);
            END IF;

            IF v_req_id > 0
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    '   Waiting for the Journal Import Program');

                LOOP
                    v_request_status   :=
                        fnd_concurrent.wait_for_request (
                            request_id   => v_req_id,
                            INTERVAL     => 60, --interval Number of seconds to wait between checks
                            max_wait     => 0, --Maximum number of seconds to wait for the request completion
                            phase        => v_phase,
                            status       => v_wait_status,
                            dev_phase    => v_dev_phase,
                            dev_status   => v_dev_status,
                            MESSAGE      => v_message);

                    EXIT WHEN    UPPER (v_phase) = 'COMPLETED'
                              OR UPPER (v_wait_status) IN
                                     ('CANCELLED', 'ERROR', 'TERMINATED');
                END LOOP;

                COMMIT;
                fnd_file.put_line (
                    fnd_file.LOG,
                       '  Journal Import Program Request Phase'
                    || '-'
                    || v_dev_phase);
                fnd_file.put_line (
                    fnd_file.LOG,
                       '  Journal Import Program Request Dev status'
                    || '-'
                    || v_dev_status);
                fnd_file.put_line (fnd_file.LOG,
                                   '  v_message' || '-' || v_message);
                fnd_file.put_line (fnd_file.LOG,
                                   '  v_wait_status' || '-' || v_wait_status);

                BEGIN
                        SELECT request_id, phase_code, status_code
                          INTO l_imp_req_id, l_imp_phase, l_imp_status
                          FROM apps.fnd_concurrent_requests fcr
                         WHERE 1 = 1
                    START WITH fcr.parent_request_id = v_req_id
                    CONNECT BY PRIOR fcr.request_id = fcr.parent_request_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                END;

                IF UPPER (l_imp_phase) = 'C' AND UPPER (l_imp_status) = 'C'
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Onhand Journal Import successfully completed for Request ID: '
                        || l_imp_req_id);
                    gv_oh_import_status   :=
                           'Onhand Records Inserted to GL Interface Succesfully. Journal Import successfully completed for Request ID: '
                        || l_imp_req_id;
                ELSE
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'The Onhand Journal Import request failed.Review log for Oracle Request ID: '
                        || l_imp_req_id);
                    fnd_file.put_line (fnd_file.LOG, SQLERRM);
                    gv_oh_import_status   :=
                           'Onhand Records Inserted to GL Interface Succesfully. Journal Import got warning/error out for Request ID: '
                        || l_imp_req_id;
                    RETURN;
                END IF;
            END IF;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            x_ret_message   := SQLERRM;
    END import_onhand_gl;

    /***************************************************************************
    -- PROCEDURE create_final_zip_prc
    -- PURPOSE: This Procedure Converts the file to zip file
    ***************************************************************************/

    FUNCTION file_to_blob_fnc (pv_directory_name   IN VARCHAR2,
                               pv_file_name        IN VARCHAR2)
        RETURN BLOB
    IS
        dest_loc   BLOB := EMPTY_BLOB ();
        src_loc    BFILE := BFILENAME (pv_directory_name, pv_file_name);
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           ' Start of Convering the file to BLOB');

        DBMS_LOB.OPEN (src_loc, DBMS_LOB.LOB_READONLY);

        DBMS_LOB.CREATETEMPORARY (lob_loc   => dest_loc,
                                  cache     => TRUE,
                                  dur       => DBMS_LOB.session);

        DBMS_LOB.OPEN (dest_loc, DBMS_LOB.LOB_READWRITE);

        DBMS_LOB.LOADFROMFILE (dest_lob   => dest_loc,
                               src_lob    => src_loc,
                               amount     => DBMS_LOB.getLength (src_loc));

        DBMS_LOB.CLOSE (dest_loc);

        DBMS_LOB.CLOSE (src_loc);

        RETURN dest_loc;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                ' Exception in Converting the file to BLOB - ' || SQLERRM);

            RETURN NULL;
    END file_to_blob_fnc;

    PROCEDURE save_zip_prc (pb_zipped_blob     BLOB,
                            pv_dir             VARCHAR2,
                            pv_zip_file_name   VARCHAR2)
    IS
        t_fh    UTL_FILE.file_type;
        t_len   PLS_INTEGER := 32767;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, ' Start of save_zip_prc Procedure');

        t_fh   := UTL_FILE.fopen (pv_dir, pv_zip_file_name, 'wb');

        FOR i IN 0 ..
                 TRUNC ((DBMS_LOB.getlength (pb_zipped_blob) - 1) / t_len)
        LOOP
            UTL_FILE.put_raw (
                t_fh,
                DBMS_LOB.SUBSTR (pb_zipped_blob, t_len, i * t_len + 1));
        END LOOP;

        UTL_FILE.fclose (t_fh);
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
            fnd_file.put_line (
                fnd_file.LOG,
                ' Exception in save_zip_prc Procedure - ' || SQLERRM);
    END save_zip_prc;

    PROCEDURE create_final_zip_prc (pv_directory_name IN VARCHAR2, pv_file_name IN VARCHAR2, pv_zip_file_name IN VARCHAR2)
    IS
        lb_file   BLOB;
        lb_zip    BLOB;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, ' Start of file_to_blob_fnc ');

        lb_file   := file_to_blob_fnc (pv_directory_name, pv_file_name);

        fnd_file.put_line (fnd_file.LOG, pv_directory_name || pv_file_name);

        fnd_file.put_line (fnd_file.LOG, ' Start of add_file PROC ');

        APEX_200200.WWV_FLOW_ZIP.add_file (lb_zip, pv_file_name, lb_file);

        fnd_file.put_line (fnd_file.LOG, ' Start of finish PROC ');

        APEX_200200.wwv_flow_zip.finish (lb_zip);

        fnd_file.put_line (fnd_file.LOG, ' Start of Saving ZIP File PROC ');

        save_zip_prc (lb_zip, pv_directory_name, pv_zip_file_name);
    END create_final_zip_prc;

    -- ======================================================================================
    -- This procedure will write the ouput data into file for report - Process Type
    -- ======================================================================================

    PROCEDURE generate_exception_report_prc (pv_directory_path IN VARCHAR2, pv_exc_file_name OUT VARCHAR2, pv_exc_file_name1 OUT VARCHAR2)
    IS
        CURSOR c_sales_rpt IS
            SELECT DISTINCT sales.ledger_name, sales.store_number, sales.store_name,
                            sales.store_currency, sales.sales_journal_currency, sales.journal_batch_name,
                            sales.journal_name, sales.item_number, sales.transaction_date,
                            sales.sales_total_units, sales.sales_total_cost, sales.sales_total_retail,
                            0 return_total_units, 0 return_total_cost, 0 return_total_retail,
                            sales.sales_mrgn_cst_local, sales.sales_mrgn_cst_usd, sales.sales_mrgn_value_local,
                            sales.sales_mrgn_value_usd, 0 return_mrgn_value_local, 0 return_mrgn_value_usd,
                            sales.user_je_source_name, sales.user_je_category_name, sales.sales_debit_code_comb,
                            sales.sales_credit_code_comb, sales.return_debit_code_comb, sales.return_credit_code_comb,
                            sales.request_id, sales.record_status, sales.error_msg,
                            sales.attribute1, sales.attribute5
              FROM xxdo.xxd_gl_je_ret_ic_markup_stg_t sales
             WHERE sales.request_id = gn_request_id
            --AND NVL(sales.sales_mrgn_value_usd, 0) <> 0
            UNION ALL
            SELECT DISTINCT sales.ledger_name, sales.store_number, sales.store_name,
                            sales.store_currency, sales.sales_journal_currency, sales.journal_batch_name,
                            sales.journal_name, sales.item_number, sales.transaction_date,
                            0 sales_total_units, 0 sales_total_cost, 0 sales_total_retail,
                            sales.return_total_units, sales.return_total_cost, sales.return_total_retail,
                            0 sales_mrgn_cst_local, 0 sales_mrgn_cst_usd, 0 sales_mrgn_value_local,
                            0 sales_mrgn_value_usd, sales.return_mrgn_value_local, sales.return_mrgn_value_usd,
                            sales.user_je_source_name, sales.user_je_category_name, sales.sales_debit_code_comb,
                            sales.sales_credit_code_comb, sales.return_debit_code_comb, sales.return_credit_code_comb,
                            sales.request_id, sales.record_status, sales.error_msg,
                            sales.attribute1, sales.attribute5
              FROM xxdo.xxd_gl_je_ret_ic_markup_stg_t sales
             WHERE     sales.request_id = gn_request_id
                   AND NVL (sales.return_mrgn_value_usd, 0) <> 0;

        CURSOR c_oh_rpt IS
              SELECT oh.ledger_name, oh.store_number, oh.store_name,
                     oh.store_type, oh.store_currency, oh.oh_journal_currency,
                     oh.item_number, oh.user_je_source_name, oh.user_je_category_name,
                     oh.journal_batch_name, oh.journal_name, oh.request_id,
                     oh.record_status, oh.error_msg, oh.soh_date_ts,
                     oh.onhand_qty, oh.in_transit_qty, oh.stock_onhand,
                     oh.stock_avg_cost, oh.total_stock_cost, oh.oh_mrgn_cst_local,
                     oh.oh_mrgn_cst_usd, oh.oh_mrgn_value_local, oh.oh_mrgn_value_usd,
                     oh.oh_markup_local, oh.oh_markup_usd, oh.oh_localval,
                     oh.oh_usdval, oh.attribute5, oh.oh_debit_code_comb,
                     oh.oh_credit_code_comb, oh.brand, oh.style,
                     oh.color, oh.item_size
                FROM xxdo.xxd_gl_je_ret_ic_onhand_stg_t oh
               WHERE     oh.request_id = gn_request_id
                     AND NVL (oh.oh_markup_usd, 0) <> 0
            ORDER BY oh.ledger_name, oh.store_number DESC;

        --DEFINE VARIABLES
        lv_output_file      UTL_FILE.file_type;
        lv_outbound_file    VARCHAR2 (4000);
        lv_err_msg          VARCHAR2 (4000) := NULL;
        lv_line             VARCHAR2 (32767) := NULL;
        lv_directory_path   VARCHAR2 (2000);
        lv_file_name        VARCHAR2 (4000);
        l_line              VARCHAR2 (4000);
        lv_result           VARCHAR2 (1000);
        lv_output_file1     UTL_FILE.file_type;
        lv_outbound_file1   VARCHAR2 (4000);
        lv_err_msg1         VARCHAR2 (4000) := NULL;
        lv_line1            VARCHAR2 (32767) := NULL;
        lv_file_name1       VARCHAR2 (4000);
        l_line1             VARCHAR2 (4000);
        lv_result1          VARCHAR2 (1000);
    BEGIN
        lv_outbound_file    :=
               gn_request_id
            || '_IC_Sales_Retail_'
            || TO_CHAR (SYSDATE, 'DDMMRRRRHH24MISS')
            || '.xls';

        lv_outbound_file1   :=
               gn_request_id
            || '_IC_OH_Retail_'
            || TO_CHAR (SYSDATE, 'DDMMRRRRHH24MISS')
            || '.xls';

        lv_directory_path   := pv_directory_path;
        lv_output_file      :=
            UTL_FILE.fopen (lv_directory_path, lv_outbound_file, 'W',
                            32767);

        IF UTL_FILE.is_open (lv_output_file)
        THEN
            lv_line   :=
                   'Ledger Name'
                || CHR (9)
                || 'User JE Source Name'
                || CHR (9)
                || 'User JE Category Name'
                || CHR (9)
                || 'Journal Batch Name'
                || CHR (9)
                || 'Journal Name'
                || CHR (9)
                || 'Store Number'
                || CHR (9)
                || 'Store Name'
                || CHR (9)
                || 'Store Currency'
                || CHR (9)
                || 'Sales Journal Currency'
                || CHR (9)
                || 'Item Number'
                || CHR (9)
                || 'Transaction Date'
                || CHR (9)
                || 'Sales Total Units'
                || CHR (9)
                || 'Sales Total Cost'
                || CHR (9)
                || 'Sales Total Retail'
                || CHR (9)
                || 'RETURN Total Units'
                || CHR (9)
                || 'RETURN Total Cost'
                || CHR (9)
                || 'RETURN Total Retail'
                || CHR (9)
                || 'Local CST Sales Markup'
                || CHR (9)
                || 'Local Value Sales Markup'
                || CHR (9)
                || 'USD CST Sales Markup'
                || CHR (9)
                || 'USD Value Sales Markup'
                || CHR (9)
                || 'LocalUSD Value Sales Markup'                 -- Attribute1
                || CHR (9)
                || 'Local Value RETURN Markup'
                || CHR (9)
                || 'USD Value RETURN Markup'
                || CHR (9)
                || 'LocalUSD Value RETURN Markup'                -- Attribute5
                || CHR (9)
                || 'Sales Debit code combination'
                || CHR (9)
                || 'Sales Credit code combination'
                || CHR (9)
                || 'Return Debit code combination'
                || CHR (9)
                || 'Return Credit code combination'
                || CHR (9)
                || 'Request ID'
                || CHR (9)
                || 'Record Status'
                || CHR (9)
                || 'Error Message';

            UTL_FILE.put_line (lv_output_file, lv_line);

            FOR r_sales_rpt IN c_sales_rpt
            LOOP
                lv_line   :=
                       NVL (r_sales_rpt.ledger_name, '')
                    || CHR (9)
                    || NVL (r_sales_rpt.user_je_source_name, '')
                    || CHR (9)
                    || NVL (r_sales_rpt.user_je_category_name, '')
                    || CHR (9)
                    || NVL (r_sales_rpt.journal_batch_name, '')
                    || CHR (9)
                    || NVL (r_sales_rpt.journal_name, '')
                    || CHR (9)
                    || NVL (r_sales_rpt.store_number, '')
                    || CHR (9)
                    || NVL (r_sales_rpt.store_name, '')
                    || CHR (9)
                    || NVL (r_sales_rpt.store_currency, '')
                    || CHR (9)
                    || NVL (r_sales_rpt.sales_journal_currency, '')
                    || CHR (9)
                    || NVL (r_sales_rpt.item_number, '')
                    || CHR (9)
                    || NVL (r_sales_rpt.transaction_date, '')
                    || CHR (9)
                    || NVL (r_sales_rpt.sales_total_units, '')
                    || CHR (9)
                    || NVL (r_sales_rpt.sales_total_cost, '')
                    || CHR (9)
                    || NVL (r_sales_rpt.sales_total_retail, '')
                    || CHR (9)
                    || NVL (r_sales_rpt.return_total_units, '')
                    || CHR (9)
                    || NVL (r_sales_rpt.return_total_cost, '')
                    || CHR (9)
                    || NVL (r_sales_rpt.return_total_retail, '')
                    || CHR (9)
                    || NVL (r_sales_rpt.sales_mrgn_cst_local, '')
                    || CHR (9)
                    || NVL (r_sales_rpt.sales_mrgn_value_local, '')
                    || CHR (9)
                    || NVL (r_sales_rpt.sales_mrgn_cst_usd, '')
                    || CHR (9)
                    || NVL (r_sales_rpt.sales_mrgn_value_usd, '')
                    || CHR (9)
                    || NVL (r_sales_rpt.attribute1, '') -- LocalUSD Value SALES Margin
                    || CHR (9)
                    || NVL (r_sales_rpt.return_mrgn_value_local, '')
                    || CHR (9)
                    || NVL (r_sales_rpt.return_mrgn_value_usd, '')
                    || CHR (9)
                    || NVL (r_sales_rpt.attribute5, '') -- LocalUSD Value RETURN Margin
                    || CHR (9)
                    || NVL (r_sales_rpt.sales_debit_code_comb, '')
                    || CHR (9)
                    || NVL (r_sales_rpt.sales_credit_code_comb, '')
                    || CHR (9)
                    || NVL (r_sales_rpt.return_debit_code_comb, '')
                    || CHR (9)
                    || NVL (r_sales_rpt.return_credit_code_comb, '')
                    || CHR (9)
                    || NVL (r_sales_rpt.request_id, '')
                    || CHR (9)
                    || NVL (r_sales_rpt.record_status, '')
                    || CHR (9)
                    || NVL (SUBSTR (r_sales_rpt.error_msg, 1, 200), '');

                UTL_FILE.put_line (lv_output_file, lv_line);
            END LOOP;
        ELSE
            lv_err_msg   :=
                SUBSTR (
                       'Error in Opening the Sales data file for writing. Error is : '
                    || SQLERRM,
                    1,
                    2000);
            write_log (lv_err_msg);
            RETURN;
        END IF;

        UTL_FILE.fclose (lv_output_file);
        lv_output_file1     :=
            UTL_FILE.fopen (lv_directory_path, lv_outbound_file1, 'W',
                            32767);

        IF UTL_FILE.is_open (lv_output_file1)
        THEN
            lv_line1   :=
                   'Ledger Name'
                || CHR (9)
                || 'User JE Source Name'
                || CHR (9)
                || 'User JE Category Name'
                || CHR (9)
                || 'Journal Batch Name'
                || CHR (9)
                || 'Journal Name'
                || CHR (9)
                || 'Store Number'
                || CHR (9)
                || 'Store Name'
                || CHR (9)
                || 'Store Currency'
                || CHR (9)
                || 'Onhand Journal Currency'
                || CHR (9)
                || 'Item Number'
                || CHR (9)
                || 'SOH Date'
                || CHR (9)
                || 'Onhand Qty'
                || CHR (9)
                || 'In Transit Qty'
                || CHR (9)
                || 'Stock Onhand'
                || CHR (9)
                || 'Stock AVG Cost'
                || CHR (9)
                || 'Total Stock Cost'
                || CHR (9)
                || 'Local CST Markup'
                || CHR (9)
                || 'Local Value Markup'
                || CHR (9)
                || 'USD CST Markup'
                || CHR (9)
                || 'USD Value Markup'
                || CHR (9)
                || 'Local Final Markup Value'
                || CHR (9)
                || 'USD Final Markup Value'
                || CHR (9)
                || 'Local Journal Onhand'
                || CHR (9)
                || 'USD Journal Onahand'
                || CHR (9)
                || 'LocalUSD Journal Onhand'
                || CHR (9)
                || 'Onhand COGS Account'
                || CHR (9)
                || 'Onhand Assets Account'
                || CHR (9)
                || 'Request ID'
                || CHR (9)
                || 'Record Status'
                || CHR (9)
                || 'Error Message';

            UTL_FILE.put_line (lv_output_file1, lv_line1);

            FOR r_oh_rpt IN c_oh_rpt
            LOOP
                lv_line1   :=
                       NVL (r_oh_rpt.ledger_name, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.user_je_source_name, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.user_je_category_name, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.journal_batch_name, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.journal_name, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.store_number, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.store_name, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.store_currency, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_journal_currency, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.item_number, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.soh_date_ts, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.onhand_qty, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.in_transit_qty, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.stock_onhand, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.stock_avg_cost, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.total_stock_cost, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_mrgn_cst_local, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_mrgn_value_local, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_mrgn_cst_usd, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_mrgn_value_usd, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_localval, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_usdval, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_markup_local, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_markup_usd, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.attribute5, '')      -- LocalUSD JL Value
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_debit_code_comb, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_credit_code_comb, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.request_id, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.record_status, '')
                    || CHR (9)
                    || NVL (SUBSTR (r_oh_rpt.error_msg, 1, 200), '');

                UTL_FILE.put_line (lv_output_file1, lv_line1);
            END LOOP;
        ELSE
            lv_err_msg1   :=
                SUBSTR (
                       'Error in Opening the data file for Onhand data writing. Error is : '
                    || SQLERRM,
                    1,
                    2000);
            write_log (lv_err_msg1);
            RETURN;
        END IF;

        UTL_FILE.fclose (lv_output_file1);
        pv_exc_file_name    := lv_outbound_file;
        pv_exc_file_name1   := lv_outbound_file1;
    EXCEPTION
        WHEN UTL_FILE.invalid_path
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_PATH: File location or filename was invalid.';
            write_log (lv_err_msg);
            raise_application_error (-20101, lv_err_msg);
        WHEN UTL_FILE.invalid_mode
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_MODE: The open_mode parameter in FOPEN was invalid.';
            write_log (lv_err_msg);
            raise_application_error (-20102, lv_err_msg);
        WHEN UTL_FILE.invalid_filehandle
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_FILEHANDLE: The file handle was invalid.';
            write_log (lv_err_msg);
            raise_application_error (-20103, lv_err_msg);
        WHEN UTL_FILE.invalid_operation
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_OPERATION: The file could not be opened or operated on as requested.';
            write_log (lv_err_msg);
            raise_application_error (-20104, lv_err_msg);
        WHEN UTL_FILE.read_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'READ_ERROR: An operating system error occurred during the read operation.';
            write_log (lv_err_msg);
            raise_application_error (-20105, lv_err_msg);
        WHEN UTL_FILE.write_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'WRITE_ERROR: An operating system error occurred during the write operation.';
            write_log (lv_err_msg);
            raise_application_error (-20106, lv_err_msg);
        WHEN UTL_FILE.internal_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   := 'INTERNAL_ERROR: An unspecified error in PL/SQL.';
            write_log (lv_err_msg);
            raise_application_error (-20107, lv_err_msg);
        WHEN UTL_FILE.invalid_filename
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_FILENAME: The filename parameter is invalid.';
            write_log (lv_err_msg);
            raise_application_error (-20108, lv_err_msg);
        WHEN OTHERS
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                SUBSTR (
                       'Error while creating or writing the data into the file.'
                    || SQLERRM,
                    1,
                    2000);
            write_log (lv_err_msg);
            raise_application_error (-20109, lv_err_msg);
    END generate_exception_report_prc;

    -- ======================================================================================
    -- This procedure will generate report and send the email notification to user
    -- ======================================================================================

    PROCEDURE generate_report_prc
    IS
        ln_sale_rec_fail         NUMBER;
        ln_ret_rec_fail          NUMBER;
        ln_oh_rec_fail           NUMBER;
        ln_sale_rec_total        NUMBER;
        ln_ret_rec_total         NUMBER;
        ln_oh_rec_total          NUMBER;
        ln_sale_rec_success      NUMBER;
        ln_ret_rec_success       NUMBER;
        ln_oh_rec_success        NUMBER;
        ln_sale_zero_rec         NUMBER;
        ln_ret_zero_rec          NUMBER;
        ln_oh_zero_rec           NUMBER;
        lv_message               VARCHAR2 (32000);
        lv_message1              VARCHAR2 (32000);
        lv_recipients            VARCHAR2 (4000);
        lv_result                VARCHAR2 (100);
        lv_result1               VARCHAR2 (100);
        lv_result_msg            VARCHAR2 (4000);
        lv_result_msg1           VARCHAR2 (4000);
        lv_exc_directory_path    VARCHAR2 (1000);
        lv_exc_file_name         VARCHAR2 (1000);
        lv_exc_file_name1        VARCHAR2 (1000);
        lv_exc_file_name_final   VARCHAR2 (1000);
        lv_directory_path        VARCHAR2 (1000);
        l_exception              EXCEPTION;
        lv_mail_delimiter        VARCHAR2 (1) := '/';
        ln_war_rec               NUMBER;
        l_file_name_str          VARCHAR2 (1000);
        lv_onhand_file_zip       VARCHAR2 (1000);
    BEGIN
        ln_sale_rec_fail      := 0;
        ln_ret_rec_fail       := 0;
        ln_oh_rec_fail        := 0;
        ln_sale_rec_total     := 0;
        ln_ret_rec_total      := 0;
        ln_oh_rec_total       := 0;
        ln_sale_rec_success   := 0;
        ln_ret_rec_success    := 0;
        ln_oh_rec_success     := 0;
        ln_sale_zero_rec      := 0;
        ln_ret_zero_rec       := 0;
        ln_oh_zero_rec        := 0;
        ln_war_rec            := 0;

        BEGIN
            SELECT COUNT (1)
              INTO ln_sale_rec_total
              FROM xxdo.xxd_gl_je_ret_ic_markup_stg_t sales
             WHERE 1 = 1 AND sales.request_id = gn_request_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_sale_rec_total   := 0;
        END;

        BEGIN
            SELECT COUNT (1)
              INTO ln_ret_rec_total
              FROM xxdo.xxd_gl_je_ret_ic_markup_stg_t sales
             WHERE     1 = 1
                   AND sales.request_id = gn_request_id
                   AND NVL (sales.return_mrgn_value_usd, 0) <> 0;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_ret_rec_total   := 0;
        END;

        BEGIN
            SELECT COUNT (1)
              INTO ln_oh_rec_total
              FROM xxdo.xxd_gl_je_ret_ic_onhand_stg_t oh
             WHERE     1 = 1
                   AND oh.request_id = gn_request_id
                   AND NVL (oh.oh_markup_usd, 0) <> 0;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_oh_rec_total   := 0;
        END;

        IF ln_sale_rec_total <= 0
        THEN
            generate_setup_err_prc (
                'There is nothing to Process...No Sales Journal Markup values are available.');
            write_log (
                'There is nothing to Process...No Sales Journal Markup values are available.');
        END IF;

        IF ln_oh_rec_total <= 0
        THEN
            generate_setup_err_prc (
                'There is nothing to Process...No Onhand Journal Markup values are available.');
            write_log (
                'There is nothing to Process...No Onhand Journal Markup values are available.');
        END IF;

        IF ln_sale_rec_total <= 0 AND ln_oh_rec_total <= 0
        THEN
            --- generate_setup_err_prc ('There is nothing to Process...No Sales OR Onhand Journal Markup values are available.');
            write_log (
                'There is nothing to Process...No Sales OR Onhand Journal Markups are available.');
        ELSE
            BEGIN
                SELECT COUNT (1)
                  INTO ln_sale_rec_success
                  FROM xxdo.xxd_gl_je_ret_ic_markup_stg_t sales
                 WHERE     sales.request_id = gn_request_id
                       AND NVL (sales.sales_mrgn_value_usd, 0) <> 0
                       AND sales.record_status = 'P';
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_sale_rec_success   := 0;
            END;

            BEGIN
                SELECT COUNT (1)
                  INTO ln_sale_zero_rec
                  FROM xxdo.xxd_gl_je_ret_ic_markup_stg_t sales
                 WHERE     sales.request_id = gn_request_id
                       AND NVL (sales.sales_mrgn_value_usd, 0) = 0
                       AND sales.record_status = 'P';
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_sale_zero_rec   := 0;
            END;

            BEGIN
                SELECT COUNT (1)
                  INTO ln_ret_rec_success
                  FROM xxdo.xxd_gl_je_ret_ic_markup_stg_t sales
                 WHERE     sales.request_id = gn_request_id
                       AND NVL (sales.return_mrgn_value_usd, 0) <> 0
                       AND sales.record_status IN ('P');
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_ret_rec_success   := 0;
            END;

            BEGIN
                SELECT COUNT (1)
                  INTO ln_oh_rec_success
                  FROM xxdo.xxd_gl_je_ret_ic_onhand_stg_t oh
                 WHERE     oh.request_id = gn_request_id
                       AND oh.record_status IN ('P')
                       AND NVL (oh.oh_markup_usd, 0) <> 0;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_oh_rec_success   := 0;
            END;

            ln_sale_rec_fail         :=
                ln_sale_rec_total - (ln_sale_rec_success + ln_sale_zero_rec);
            ln_ret_rec_fail          := ln_ret_rec_total - ln_ret_rec_success;
            ln_oh_rec_fail           := ln_oh_rec_total - ln_oh_rec_success;
            lv_exc_file_name         := NULL;
            lv_exc_file_name1        := NULL;
            lv_exc_file_name_final   := NULL;
            lv_directory_path        := NULL;

            -- Derive the directory Path
            BEGIN
                lv_exc_directory_path   := NULL;

                SELECT directory_path
                  INTO lv_exc_directory_path
                  FROM dba_directories
                 WHERE     1 = 1
                       AND directory_name LIKE 'XXD_GL_CCID_UPLOAD_ARC_DIR'; -- 'XXD_GL_ACCT_CONTROL_EXC_DIR';
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_exc_directory_path   := NULL;
                    lv_message              :=
                           'Exception Occurred while retriving the Exception Directory-'
                        || SQLERRM;
                    RAISE l_exception;
            END;

            generate_exception_report_prc (lv_exc_directory_path,
                                           lv_exc_file_name,
                                           lv_exc_file_name1);

            lv_exc_file_name         :=
                   lv_exc_directory_path
                || lv_mail_delimiter
                || lv_exc_file_name;

            IF ln_oh_rec_total <= 15000
            THEN
                lv_onhand_file_zip   :=
                       lv_exc_directory_path
                    || lv_mail_delimiter
                    || lv_exc_file_name1;
            ELSE
                lv_onhand_file_zip   :=
                       lv_exc_directory_path
                    || lv_mail_delimiter
                    || SUBSTR (lv_exc_file_name1,
                               1,
                               (INSTR (lv_exc_file_name1, '.', -1) - 1))
                    || '.zip';

                create_final_zip_prc (
                    pv_directory_name   => 'XXD_GL_CCID_UPLOAD_ARC_DIR',
                    pv_file_name        => lv_exc_file_name1,
                    pv_zip_file_name    => lv_onhand_file_zip);
            END IF;

            lv_message               :=
                   'Hello Team,'
                || CHR (10)
                || CHR (10)
                || 'Please Find the Attached Deckers Retail IC Markup for Sales Journal Interface Output. '
                || CHR (10)
                || CHR (10)
                || l_file_name_str
                || CHR (10)
                || ' Number of SALES Rows in the Sales File                - '
                || ln_sale_rec_total
                || CHR (10)
                || ' Number of SALES Rows Errored in Sales File          - '
                || ln_sale_rec_fail
                || CHR (10)
                || ' Number of SALES Rows with ZERO margin                - '
                || ln_sale_zero_rec
                || CHR (10)
                || ' Number of SALES Rows Processed to GL Interface     - '
                || ln_sale_rec_success
                || CHR (10)
                || CHR (10)
                || ' Number of RETURN Rows in the Sales File              - '
                || ln_ret_rec_total
                || CHR (10)
                || ' Number of RETURN Rows Errored in Sales File         - '
                || ln_ret_rec_fail
                || CHR (10)
                || ' Number of RETURN Rows Processed to GL Interface    - '
                || ln_ret_rec_success
                || CHR (10)
                || CHR (10)
                || gv_sales_import_status
                || CHR (10)
                || CHR (10)
                || 'Regards,'
                || CHR (10)
                || 'SYSADMIN.'
                || CHR (10)
                || CHR (10)
                || 'Note: This is auto generated mail, please donot reply.';

            lv_message1              :=
                   'Hello Team,'
                || CHR (10)
                || CHR (10)
                || 'Please Find the Attached Deckers Retail IC Markup for Onhand Journal Interface Output. '
                || CHR (10)
                || CHR (10)
                || l_file_name_str
                || CHR (10)
                || ' Number of Rows in the Onhand File                    - '
                || ln_oh_rec_total
                || CHR (10)
                || ' Number of Rows Errored in Onhand File               - '
                || ln_oh_rec_fail
                || CHR (10)
                || ' Number of Rows Processed to GL Interface          - '
                || ln_oh_rec_success
                || CHR (10)
                || CHR (10)
                || gv_oh_import_status
                || CHR (10)
                || CHR (10)
                || 'Regards,'
                || CHR (10)
                || 'SYSADMIN.'
                || CHR (10)
                || CHR (10)
                || 'Note: This is auto generated mail, please donot reply.';

            BEGIN
                SELECT LISTAGG (flv.description, ';') WITHIN GROUP (ORDER BY flv.description)
                  INTO lv_recipients
                  FROM fnd_lookup_values flv
                 WHERE     lookup_type = 'XXD_GL_COMMON_EMAILS_LKP'
                       AND lookup_code = '10001'
                       AND enabled_flag = 'Y'
                       AND language = 'US'
                       AND SYSDATE BETWEEN TRUNC (
                                               NVL (start_date_active,
                                                    SYSDATE))
                                       AND TRUNC (
                                                 NVL (end_date_active,
                                                      SYSDATE)
                                               + 1);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_recipients   := NULL;
            END;

            IF ln_sale_rec_total > 0
            THEN
                xxdo_mail_pkg.send_mail (
                    pv_sender         => 'erp@deckers.com',
                    pv_recipients     => lv_recipients,
                    pv_ccrecipients   => NULL,
                    pv_subject        =>
                           gv_ou_name
                        || ' - '
                        || 'Deckers Retail IC Markup for Sales Journal Interface output',
                    pv_message        => lv_message,
                    pv_attachments    => lv_exc_file_name,
                    xv_result         => lv_result,
                    xv_result_msg     => lv_result_msg);
            END IF;

            IF ln_oh_rec_total > 0
            THEN
                xxdo_mail_pkg.send_mail (
                    pv_sender         => 'erp@deckers.com',
                    pv_recipients     => lv_recipients,
                    pv_ccrecipients   => NULL,
                    pv_subject        =>
                           gv_ou_name
                        || ' - '
                        || 'Deckers Retail IC Markup for Onhand Journal Interface output',
                    pv_message        => lv_message1,
                    pv_attachments    => lv_onhand_file_zip,
                    xv_result         => lv_result1,
                    xv_result_msg     => lv_result_msg1);
            END IF;

            BEGIN
                UTL_FILE.fremove (lv_exc_directory_path, lv_exc_file_name);
                UTL_FILE.fremove (lv_exc_directory_path, lv_onhand_file_zip);
            EXCEPTION
                WHEN OTHERS
                THEN
                    write_log (
                           'Unable to delete the execption report file- '
                        || SQLERRM);
            END;

            write_log ('Sales Result is - ' || lv_result);
            write_log ('Sales Result MSG is - ' || lv_result_msg);
            write_log ('Onhand Result is - ' || lv_result1);
            write_log ('Onhand Result MSG is - ' || lv_result_msg1);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log ('Exception in generate_report_prc- ' || SQLERRM);
    END generate_report_prc;

    -- ======================================================================================
    -- This procedure will write the ouput data into file for report - Report Type
    -- ======================================================================================
    PROCEDURE generate_report_type_prc (pv_directory_path IN VARCHAR2, pv_report_mode IN VARCHAR2, pv_exc_file_name OUT VARCHAR2)
    IS
        CURSOR c_sales_rpt IS
            SELECT DISTINCT (SELECT DISTINCT name
                               FROM GL_LEDGERS
                              WHERE ledger_id = sales.ledger_id) ledger_name,
                            sales.store_number,
                            sales.store_name,
                            sales.store_currency,
                            sales.sales_journal_currency,
                            sales.journal_name,
                            sales.markup_type,
                            sales.brand,
                            sales.item_number,
                            sales.transaction_date,
                            sales.sales_total_units,
                            sales.sales_total_cost,
                            sales.sales_total_retail,
                            0   return_total_units,
                            0   return_total_cost,
                            0   return_total_retail,
                            sales.sales_avg_cost,
                            sales.sales_mrgn_cst_local,
                            sales.sales_mrgn_cst_usd,
                            sales.sales_mrgn_value_local,
                            sales.sales_mrgn_value_usd,
                            0   return_mrgn_value_local,
                            0   return_mrgn_value_usd,
                            sales.user_je_source_name,
                            sales.user_je_category_name,
                            sales.sales_debit_code_comb,
                            sales.sales_credit_code_comb,
                            sales.return_debit_code_comb,
                            sales.return_credit_code_comb,
                            sales.request_id,
                            sales.record_status,
                            sales.error_msg,
                            sales.attribute1,
                            sales.attribute5
              FROM xxdo.xxd_gl_je_ret_ic_markup_stg_t sales
             WHERE     1 = 1
                   --AND TRUNC(sales.as_of_date) = TRUNC(gd_cut_of_date)
                   AND TRUNC (sales.as_of_date) <= TRUNC (gd_cut_of_date)
                   AND TRUNC (sales.as_of_date) >=
                       TRUNC (gd_Sales_from_Rep_date)
                   AND NVL (sales.ledger_id, 1) =
                       NVL (NVL (gn_ledger, sales.ledger_id), 1)
                   AND NVL (sales.operating_unit, 1) =
                       NVL (NVL (gn_org_unit_id_rms, sales.operating_unit),
                            1)                                       -- RMS OU
                   AND NVL (sales.ou_id, 1) =
                       NVL (NVL (gn_ou_id, sales.ou_id), 1)    -- Ship From OU
                   AND NVL (sales.inv_org_id, 1) =
                       NVL (NVL (gn_inv_org_id, sales.inv_org_id), 1)
                   AND NVL (sales.store_number, 1) =
                       NVL (NVL (gn_store_number, sales.store_number), 1)
                   AND NVL (sales.sales_mrgn_value_usd, 0) <> 0
                   AND sales.record_status = 'P'
            UNION ALL
            SELECT DISTINCT (SELECT DISTINCT name
                               FROM GL_LEDGERS
                              WHERE ledger_id = sales.ledger_id) ledger_name,
                            sales.store_number,
                            sales.store_name,
                            sales.store_currency,
                            sales.sales_journal_currency,
                            sales.journal_name,
                            sales.markup_type,
                            sales.brand,
                            sales.item_number,
                            sales.transaction_date,
                            0   sales_total_units,
                            0   sales_total_cost,
                            0   sales_total_retail,
                            sales.return_total_units,
                            sales.return_total_cost,
                            sales.return_total_retail,
                            sales.sales_avg_cost,
                            0   sales_mrgn_cst_local,
                            0   sales_mrgn_cst_usd,
                            0   sales_mrgn_value_local,
                            0   sales_mrgn_value_usd,
                            sales.return_mrgn_value_local,
                            sales.return_mrgn_value_usd,
                            sales.user_je_source_name,
                            sales.user_je_category_name,
                            sales.sales_debit_code_comb,
                            sales.sales_credit_code_comb,
                            sales.return_debit_code_comb,
                            sales.return_credit_code_comb,
                            sales.request_id,
                            sales.record_status,
                            sales.error_msg,
                            sales.attribute1,
                            sales.attribute5
              FROM xxdo.xxd_gl_je_ret_ic_markup_stg_t sales
             WHERE     1 = 1
                   -- AND TRUNC(sales.as_of_date) = TRUNC(gd_cut_of_date)
                   AND TRUNC (sales.as_of_date) <= TRUNC (gd_cut_of_date)
                   AND TRUNC (sales.as_of_date) >=
                       TRUNC (gd_Sales_from_Rep_date)
                   AND NVL (sales.ledger_id, 1) =
                       NVL (NVL (gn_ledger, sales.ledger_id), 1)
                   AND NVL (sales.operating_unit, 1) =
                       NVL (NVL (gn_org_unit_id_rms, sales.operating_unit),
                            1)                                       -- RMS OU
                   AND NVL (sales.ou_id, 1) =
                       NVL (NVL (gn_ou_id, sales.ou_id), 1)    -- Ship From OU
                   AND NVL (sales.inv_org_id, 1) =
                       NVL (NVL (gn_inv_org_id, sales.inv_org_id), 1)
                   AND NVL (sales.store_number, 1) =
                       NVL (NVL (gn_store_number, sales.store_number), 1)
                   AND NVL (sales.return_mrgn_value_usd, 0) <> 0
                   AND sales.record_status = 'P';

        CURSOR c_oh_rpt IS
              SELECT (SELECT DISTINCT name
                        FROM GL_LEDGERS
                       WHERE ledger_id = oh.ledger_id) ledger_name1,
                     oh.*
                FROM xxdo.xxd_gl_je_ret_ic_onhand_stg_t oh
               WHERE     1 = 1
                     AND TRUNC (oh.soh_date_ts) = TRUNC (gd_cut_of_date)
                     AND NVL (oh.ledger_id, 1) =
                         NVL (NVL (gn_ledger, oh.ledger_id), 1)
                     AND NVL (oh.operating_unit, 1) =
                         NVL (NVL (gn_org_unit_id_rms, oh.operating_unit), 1) -- RMS OU
                     AND NVL (oh.ou_id, 1) = NVL (NVL (gn_ou_id, oh.ou_id), 1) -- Ship From OU
                     AND NVL (oh.inv_org_id, 1) =
                         NVL (NVL (gn_inv_org_id, oh.inv_org_id), 1)
                     AND NVL (oh.store_number, 1) =
                         NVL (NVL (gn_store_number, oh.store_number), 1)
                     AND oh.record_status = 'P'
            ORDER BY oh.ledger_name, oh.store_number DESC;

        --DEFINE VARIABLES
        lv_output_file      UTL_FILE.file_type;
        lv_outbound_file    VARCHAR2 (4000);
        lv_err_msg          VARCHAR2 (4000) := NULL;
        lv_line             VARCHAR2 (32767) := NULL;
        lv_directory_path   VARCHAR2 (2000);
        lv_file_name        VARCHAR2 (4000);
        l_line              VARCHAR2 (4000);
        lv_result           VARCHAR2 (1000);
        lv_output_file1     UTL_FILE.file_type;
        lv_outbound_file1   VARCHAR2 (4000);
        lv_err_msg1         VARCHAR2 (4000) := NULL;
        lv_line1            VARCHAR2 (32767) := NULL;
        lv_file_name1       VARCHAR2 (4000);
        l_line1             VARCHAR2 (4000);
        lv_result1          VARCHAR2 (1000);
    BEGIN
        IF pv_report_mode = 'Sales'
        THEN
            lv_outbound_file    :=
                   gn_request_id
                || '_IC_Sales_Retail_'
                || TO_CHAR (SYSDATE, 'DDMMRRRRHH24MISS')
                || '.xls';

            lv_directory_path   := pv_directory_path;
            lv_output_file      :=
                UTL_FILE.fopen (lv_directory_path, lv_outbound_file, 'W',
                                32767);

            IF UTL_FILE.is_open (lv_output_file)
            THEN
                lv_line   :=
                       'User JE Source Name'
                    || CHR (9)
                    || 'User JE Category Name'
                    || CHR (9)
                    || 'Store Number'
                    || CHR (9)
                    || 'Store Name'
                    || CHR (9)
                    || 'Store Currency'
                    || CHR (9)
                    || 'Sales Journal Currency'
                    || CHR (9)
                    || 'Markup Type'
                    || CHR (9)
                    || 'Brand'
                    || CHR (9)
                    || 'Item Number'
                    || CHR (9)
                    || 'Transaction Date'
                    || CHR (9)
                    || 'Sales Average Cost'
                    || CHR (9)
                    || 'Sales Total Units'
                    || CHR (9)
                    || 'Sales Total Cost'
                    || CHR (9)
                    || 'Sales Total Retail'
                    || CHR (9)
                    || 'RETURN Total Units'
                    || CHR (9)
                    || 'RETURN Total Cost'
                    || CHR (9)
                    || 'RETURN Total Retail'
                    || CHR (9)
                    || 'Local CST Sales Markup'
                    || CHR (9)
                    || 'Local Value Sales Markup'
                    || CHR (9)
                    || 'USD CST Sales Markup'
                    || CHR (9)
                    || 'USD Value Sales Markup'
                    || CHR (9)
                    || 'LocalUSD Value Sales Markup'             -- ATTRIBUTE1
                    || CHR (9)
                    || 'Local Value RETURN Markup'
                    || CHR (9)
                    || 'USD Value RETURN Markup'
                    || CHR (9)
                    || 'LocalUSD Value RETURN Markup'            -- ATTRIBUTE5
                    || CHR (9)
                    || 'Sales Debit code combination'
                    || CHR (9)
                    || 'Sales Credit code combination'
                    || CHR (9)
                    || 'Return Debit code combination'
                    || CHR (9)
                    || 'Return Credit code combination'
                    || CHR (9)
                    || 'Request ID'
                    || CHR (9)
                    || 'Record Status'
                    || CHR (9)
                    || 'Error Message';

                UTL_FILE.put_line (lv_output_file, lv_line);

                FOR r_sales_rpt IN c_sales_rpt
                LOOP
                    lv_line   :=
                           NVL (r_sales_rpt.user_je_source_name, '')
                        || CHR (9)
                        || NVL (r_sales_rpt.user_je_category_name, '')
                        || CHR (9)
                        || NVL (r_sales_rpt.store_number, '')
                        || CHR (9)
                        || NVL (r_sales_rpt.store_name, '')
                        || CHR (9)
                        || NVL (r_sales_rpt.store_currency, '')
                        || CHR (9)
                        || NVL (r_sales_rpt.sales_journal_currency, '')
                        || CHR (9)
                        || NVL (r_sales_rpt.markup_type, '')
                        || CHR (9)
                        || NVL (r_sales_rpt.brand, '')
                        || CHR (9)
                        || NVL (r_sales_rpt.item_number, '')
                        || CHR (9)
                        || NVL (r_sales_rpt.transaction_date, '')
                        || CHR (9)
                        || NVL (r_sales_rpt.sales_avg_cost, '')
                        || CHR (9)
                        || NVL (r_sales_rpt.sales_total_units, '')
                        || CHR (9)
                        || NVL (r_sales_rpt.sales_total_cost, '')
                        || CHR (9)
                        || NVL (r_sales_rpt.sales_total_retail, '')
                        || CHR (9)
                        || NVL (r_sales_rpt.return_total_units, '')
                        || CHR (9)
                        || NVL (r_sales_rpt.return_total_cost, '')
                        || CHR (9)
                        || NVL (r_sales_rpt.return_total_retail, '')
                        || CHR (9)
                        || NVL (r_sales_rpt.sales_mrgn_cst_local, '')
                        || CHR (9)
                        || NVL (r_sales_rpt.sales_mrgn_value_local, '')
                        || CHR (9)
                        || NVL (r_sales_rpt.sales_mrgn_cst_usd, '')
                        || CHR (9)
                        || NVL (r_sales_rpt.sales_mrgn_value_usd, '')
                        || CHR (9)
                        || NVL (r_sales_rpt.attribute1, '') -- LocalUSD Sales Value Markup
                        || CHR (9)
                        || NVL (r_sales_rpt.return_mrgn_value_local, '')
                        || CHR (9)
                        || NVL (r_sales_rpt.return_mrgn_value_usd, '')
                        || CHR (9)
                        || NVL (r_sales_rpt.attribute5, '') -- LocalUSD RETURN Value Markup
                        || CHR (9)
                        || NVL (r_sales_rpt.sales_debit_code_comb, '')
                        || CHR (9)
                        || NVL (r_sales_rpt.sales_credit_code_comb, '')
                        || CHR (9)
                        || NVL (r_sales_rpt.return_debit_code_comb, '')
                        || CHR (9)
                        || NVL (r_sales_rpt.return_credit_code_comb, '')
                        || CHR (9)
                        || NVL (r_sales_rpt.request_id, '')
                        || CHR (9)
                        || NVL (r_sales_rpt.record_status, '')
                        || CHR (9)
                        || NVL (SUBSTR (r_sales_rpt.error_msg, 1, 200), '');

                    UTL_FILE.put_line (lv_output_file, lv_line);
                END LOOP;
            ELSE
                lv_err_msg   :=
                    SUBSTR (
                           'Error in Opening the Sales data file for writing. Error is : '
                        || SQLERRM,
                        1,
                        2000);
                write_log (lv_err_msg);
                RETURN;
            END IF;

            UTL_FILE.fclose (lv_output_file);
            pv_exc_file_name    := lv_outbound_file;
        ELSIF pv_report_mode = 'Onhand'
        THEN
            lv_outbound_file1   :=
                   gn_request_id
                || '_IC_OH_Retail_'
                || TO_CHAR (SYSDATE, 'DDMMRRRRHH24MISS')
                || '.xls';
            lv_directory_path   := pv_directory_path;
            lv_output_file1     :=
                UTL_FILE.fopen (lv_directory_path, lv_outbound_file1, 'W',
                                32767);

            IF UTL_FILE.is_open (lv_output_file1)
            THEN
                lv_line1   :=
                       'User JE Source Name'
                    || CHR (9)
                    || 'User JE Category Name'
                    || CHR (9)
                    || 'Markup Type'
                    || CHR (9)
                    || 'Store Number'
                    || CHR (9)
                    || 'Store Name'
                    || CHR (9)
                    || 'Store Currency'
                    || CHR (9)
                    || 'Onhand Journal Currency'
                    || CHR (9)
                    || 'Item Number'
                    || CHR (9)
                    || 'Brand'
                    || CHR (9)
                    || 'Style'
                    || CHR (9)
                    || 'Color'
                    || CHR (9)
                    || 'Item Size'
                    || CHR (9)
                    || 'Item Type'
                    || CHR (9)
                    || 'SOH Date'
                    || CHR (9)
                    || 'Onhand Qty'
                    || CHR (9)
                    || 'In Transit Qty'
                    || CHR (9)
                    || 'Stock Onhand'
                    || CHR (9)
                    || 'Stock AVG Cost'
                    || CHR (9)
                    || 'Total Stock Cost'
                    || CHR (9)
                    || 'Local CST Markup'
                    || CHR (9)
                    || 'Local Value Markup'
                    || CHR (9)
                    || 'USD CST Markup'
                    || CHR (9)
                    || 'USD Value Markup'
                    || CHR (9)
                    || 'Local Final Markup Value'
                    || CHR (9)
                    || 'USD Final Markup Value'
                    || CHR (9)
                    || 'Onhand COGS Code Combination'
                    || CHR (9)
                    || 'Onhand Asset Code Combination';

                UTL_FILE.put_line (lv_output_file1, lv_line1);

                FOR r_oh_rpt IN c_oh_rpt
                LOOP
                    lv_line1   :=
                           NVL (r_oh_rpt.user_je_source_name, '')
                        || CHR (9)
                        || NVL (r_oh_rpt.user_je_category_name, '')
                        || CHR (9)
                        || NVL (r_oh_rpt.markup_type, '')
                        || CHR (9)
                        || NVL (r_oh_rpt.store_number, '')
                        || CHR (9)
                        || NVL (r_oh_rpt.store_name, '')
                        || CHR (9)
                        || NVL (r_oh_rpt.store_currency, '')
                        || CHR (9)
                        || NVL (r_oh_rpt.oh_journal_currency, '')
                        || CHR (9)
                        || NVL (r_oh_rpt.item_number, '')
                        || CHR (9)
                        || NVL (r_oh_rpt.brand, '')
                        || CHR (9)
                        || NVL (r_oh_rpt.style, '')
                        || CHR (9)
                        || NVL (r_oh_rpt.color, '')
                        || CHR (9)
                        || NVL (r_oh_rpt.item_size, '')
                        || CHR (9)
                        || NVL (r_oh_rpt.item_type, '')
                        || CHR (9)
                        || NVL (r_oh_rpt.soh_date_ts, '')
                        || CHR (9)
                        || NVL (r_oh_rpt.onhand_qty, '')
                        || CHR (9)
                        || NVL (r_oh_rpt.in_transit_qty, '')
                        || CHR (9)
                        || NVL (r_oh_rpt.stock_onhand, '')
                        || CHR (9)
                        || NVL (r_oh_rpt.stock_avg_cost, '')
                        || CHR (9)
                        || NVL (r_oh_rpt.total_stock_cost, '')
                        || CHR (9)
                        || NVL (r_oh_rpt.oh_mrgn_cst_local, '')
                        || CHR (9)
                        || NVL (r_oh_rpt.oh_mrgn_value_local, '')
                        || CHR (9)
                        || NVL (r_oh_rpt.oh_mrgn_cst_usd, '')
                        || CHR (9)
                        || NVL (r_oh_rpt.oh_mrgn_value_usd, '')
                        || CHR (9)
                        || NVL (r_oh_rpt.oh_localval, '')
                        || CHR (9)
                        || NVL (r_oh_rpt.oh_usdval, '')
                        || CHR (9)
                        || NVL (r_oh_rpt.oh_debit_code_comb, '')
                        || CHR (9)
                        || NVL (r_oh_rpt.oh_credit_code_comb, '');

                    UTL_FILE.put_line (lv_output_file1, lv_line1);
                END LOOP;
            ELSE
                lv_err_msg1   :=
                    SUBSTR (
                           'Error in Opening the data file for Onhand data writing. Error is : '
                        || SQLERRM,
                        1,
                        2000);
                write_log (lv_err_msg1);
                RETURN;
            END IF;

            UTL_FILE.fclose (lv_output_file1);

            pv_exc_file_name    := lv_outbound_file1;
        END IF;
    EXCEPTION
        WHEN UTL_FILE.invalid_path
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_PATH: File location or filename was invalid.';
            write_log (lv_err_msg);
            raise_application_error (-20101, lv_err_msg);
        WHEN UTL_FILE.invalid_mode
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_MODE: The open_mode parameter in FOPEN was invalid.';
            write_log (lv_err_msg);
            raise_application_error (-20102, lv_err_msg);
        WHEN UTL_FILE.invalid_filehandle
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_FILEHANDLE: The file handle was invalid.';
            write_log (lv_err_msg);
            raise_application_error (-20103, lv_err_msg);
        WHEN UTL_FILE.invalid_operation
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_OPERATION: The file could not be opened or operated on as requested.';
            write_log (lv_err_msg);
            raise_application_error (-20104, lv_err_msg);
        WHEN UTL_FILE.read_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'READ_ERROR: An operating system error occurred during the read operation.';
            write_log (lv_err_msg);
            raise_application_error (-20105, lv_err_msg);
        WHEN UTL_FILE.write_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'WRITE_ERROR: An operating system error occurred during the write operation.';
            write_log (lv_err_msg);
            raise_application_error (-20106, lv_err_msg);
        WHEN UTL_FILE.internal_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   := 'INTERNAL_ERROR: An unspecified error in PL/SQL.';
            write_log (lv_err_msg);
            raise_application_error (-20107, lv_err_msg);
        WHEN UTL_FILE.invalid_filename
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_FILENAME: The filename parameter is invalid.';
            write_log (lv_err_msg);
            raise_application_error (-20108, lv_err_msg);
        WHEN OTHERS
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                SUBSTR (
                       'Error while creating or writing the data into the file.'
                    || SQLERRM,
                    1,
                    2000);
            write_log (lv_err_msg);
            raise_application_error (-20109, lv_err_msg);
    END generate_report_type_prc;

    -- ======================================================================================
    -- This procedure will generate report and send the email notification to user
    -- ======================================================================================
    PROCEDURE mail_report_type_prc (pv_report_mode VARCHAR2)
    IS
        ln_sale_rec_fail         NUMBER;
        ln_ret_rec_fail          NUMBER;
        ln_oh_rec_fail           NUMBER;
        ln_sale_rec_total        NUMBER;
        ln_ret_rec_total         NUMBER;
        ln_oh_rec_total          NUMBER;
        ln_sale_rec_success      NUMBER;
        ln_ret_rec_success       NUMBER;
        ln_oh_rec_success        NUMBER;
        lv_message               VARCHAR2 (32000);
        lv_message1              VARCHAR2 (32000);
        lv_recipients            VARCHAR2 (4000);
        lv_user_email            VARCHAR2 (4000);
        lv_result                VARCHAR2 (100);
        lv_result1               VARCHAR2 (100);
        lv_result_msg            VARCHAR2 (4000);
        lv_result_msg1           VARCHAR2 (4000);
        lv_exc_directory_path    VARCHAR2 (1000);
        lv_exc_file_name         VARCHAR2 (1000);
        lv_exc_file_name1        VARCHAR2 (1000);
        lv_exc_file_name_final   VARCHAR2 (1000);
        lv_directory_path        VARCHAR2 (1000);
        l_exception              EXCEPTION;
        lv_mail_delimiter        VARCHAR2 (1) := '/';
        ln_war_rec               NUMBER;
        l_file_name_str          VARCHAR2 (1000);
        lv_onhand_file_zip       VARCHAR2 (1000);
    BEGIN
        ln_sale_rec_fail         := 0;
        ln_ret_rec_fail          := 0;
        ln_oh_rec_fail           := 0;
        ln_sale_rec_total        := 0;
        ln_ret_rec_total         := 0;
        ln_oh_rec_total          := 0;
        ln_sale_rec_success      := 0;
        ln_ret_rec_success       := 0;
        ln_oh_rec_success        := 0;
        ln_war_rec               := 0;

        lv_exc_file_name         := NULL;
        lv_exc_file_name1        := NULL;
        lv_exc_file_name_final   := NULL;
        lv_directory_path        := NULL;

        -- Derive the directory Path
        BEGIN
            lv_exc_directory_path   := NULL;

            SELECT directory_path
              INTO lv_exc_directory_path
              FROM dba_directories
             WHERE 1 = 1 AND directory_name LIKE 'XXD_GL_CCID_UPLOAD_ARC_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_exc_directory_path   := NULL;
                lv_message              :=
                       'Exception Occurred while retriving the Exception Directory-'
                    || SQLERRM;
                RAISE l_exception;
        END;

        IF pv_report_mode = 'Sales'
        THEN
            BEGIN
                SELECT COUNT (1)
                  INTO ln_sale_rec_total
                  FROM xxdo.xxd_gl_je_ret_ic_markup_stg_t sales
                 WHERE     1 = 1
                       AND TRUNC (sales.as_of_date) = TRUNC (gd_cut_of_date)
                       AND NVL (sales.ledger_id, 1) =
                           NVL (NVL (gn_ledger, sales.ledger_id), 1)
                       AND NVL (sales.operating_unit, 1) =
                           NVL (
                               NVL (gn_org_unit_id_rms, sales.operating_unit),
                               1)                                    -- RMS OU
                       AND NVL (sales.ou_id, 1) =
                           NVL (NVL (gn_ou_id, sales.ou_id), 1) -- Ship From OU
                       AND NVL (sales.inv_org_id, 1) =
                           NVL (NVL (gn_inv_org_id, sales.inv_org_id), 1)
                       AND NVL (sales.store_number, 1) =
                           NVL (NVL (gn_store_number, sales.store_number), 1);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_sale_rec_total   := 0;
            END;

            generate_report_type_prc (lv_exc_directory_path,
                                      pv_report_mode,
                                      lv_exc_file_name);

            lv_exc_file_name   :=
                   lv_exc_directory_path
                || lv_mail_delimiter
                || lv_exc_file_name;

            lv_message   :=
                   'Hello Team,'
                || CHR (10)
                || CHR (10)
                || 'Please find the attached Deckers Retail IC Markup for Sales Journal Report Output for the Parameters provided. '
                || CHR (10)
                || CHR (10)
                || 'Regards,'
                || CHR (10)
                || 'SYSADMIN.'
                || CHR (10)
                || CHR (10)
                || 'Note: This is auto generated mail, please donot reply.';

            SELECT email_address
              INTO lv_user_email
              FROM apps.FND_USER
             WHERE user_id = gn_user_id;

            IF ln_sale_rec_total > 0
            THEN
                xxdo_mail_pkg.send_mail (
                    pv_sender         => 'erp@deckers.com',
                    pv_recipients     => lv_user_email,
                    pv_ccrecipients   => NULL,
                    pv_subject        =>
                           gv_ou_name
                        || ' - '
                        || 'Deckers Retail IC Markup for Sales Journal Report output',
                    pv_message        => lv_message,
                    pv_attachments    => lv_exc_file_name,
                    xv_result         => lv_result,
                    xv_result_msg     => lv_result_msg);
            ELSE
                generate_setup_err_prc (
                    'No Retail Sales journal records for the Parameters provided. ');
            END IF;

            BEGIN
                UTL_FILE.fremove (lv_exc_directory_path, lv_exc_file_name);
            EXCEPTION
                WHEN OTHERS
                THEN
                    write_log (
                           'Unable to delete the mail Sales eport file- '
                        || SQLERRM);
            END;

            write_log ('Sales Report Result is - ' || lv_result);
            write_log ('Sales Report Result MSG is - ' || lv_result_msg);
        ELSIF pv_report_mode = 'Onhand'
        THEN
            BEGIN
                SELECT COUNT (1)
                  INTO ln_oh_rec_total
                  FROM xxdo.xxd_gl_je_ret_ic_onhand_stg_t oh
                 WHERE     1 = 1
                       AND TRUNC (oh.soh_date_ts) = TRUNC (gd_cut_of_date)
                       AND NVL (oh.ledger_id, 1) =
                           NVL (NVL (gn_ledger, oh.ledger_id), 1)
                       AND NVL (oh.operating_unit, 1) =
                           NVL (NVL (gn_org_unit_id_rms, oh.operating_unit),
                                1)                                   -- RMS OU
                       AND NVL (oh.ou_id, 1) =
                           NVL (NVL (gn_ou_id, oh.ou_id), 1)   -- Ship From OU
                       AND NVL (oh.inv_org_id, 1) =
                           NVL (NVL (gn_inv_org_id, oh.inv_org_id), 1)
                       AND NVL (oh.store_number, 1) =
                           NVL (NVL (gn_store_number, oh.store_number), 1);
            --AND NVL(oh.oh_markup_usd, 0) <> 0;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_oh_rec_total   := 0;
            END;

            generate_report_type_prc (lv_exc_directory_path,
                                      pv_report_mode,
                                      lv_exc_file_name1);

            IF ln_oh_rec_total <= 15000
            THEN
                lv_onhand_file_zip   :=
                       lv_exc_directory_path
                    || lv_mail_delimiter
                    || lv_exc_file_name1;
            ELSE
                lv_onhand_file_zip   :=
                       lv_exc_directory_path
                    || lv_mail_delimiter
                    || SUBSTR (lv_exc_file_name1,
                               1,
                               (INSTR (lv_exc_file_name1, '.', -1) - 1))
                    || '.zip';

                create_final_zip_prc (
                    pv_directory_name   => 'XXD_GL_CCID_UPLOAD_ARC_DIR',
                    pv_file_name        => lv_exc_file_name1,
                    pv_zip_file_name    => lv_onhand_file_zip);
            END IF;

            lv_message1   :=
                   'Hello Team,'
                || CHR (10)
                || CHR (10)
                || 'Please find the attached Deckers Retail IC Markup for Onhand Journal Report Output for the Parameters provided. '
                || CHR (10)
                || CHR (10)
                || 'Regards,'
                || CHR (10)
                || 'SYSADMIN.'
                || CHR (10)
                || CHR (10)
                || 'Note: This is auto generated mail, please donot reply.';

            SELECT email_address
              INTO lv_user_email
              FROM apps.FND_USER
             WHERE user_id = gn_user_id;

            IF ln_oh_rec_total > 0
            THEN
                xxdo_mail_pkg.send_mail (
                    pv_sender         => 'erp@deckers.com',
                    pv_recipients     => lv_user_email,
                    pv_ccrecipients   => NULL,
                    pv_subject        =>
                           gv_ou_name
                        || ' - '
                        || 'Deckers Retail IC Markup for Onhand Journal Report output',
                    pv_message        => lv_message1,
                    pv_attachments    => lv_onhand_file_zip,
                    xv_result         => lv_result1,
                    xv_result_msg     => lv_result_msg1);
            ELSE
                generate_setup_err_prc (
                    'No Retail Onhand journal records for the Parameters provided. ');
            END IF;

            BEGIN
                UTL_FILE.fremove (lv_exc_directory_path, lv_onhand_file_zip);
            EXCEPTION
                WHEN OTHERS
                THEN
                    write_log (
                           'Unable to delete the mail Onhand report file- '
                        || SQLERRM);
            END;

            write_log ('Onhand Report Result is - ' || lv_result1);
            write_log ('Onhand Report Result MSG is - ' || lv_result_msg1);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log ('Exception in mail_report_type_prc- ' || SQLERRM);
    END mail_report_type_prc;

    /***********************************************************************************************
    ************************** Markup Retail - MAIN Procedure **************************************
    ************************************************************************************************/

    PROCEDURE main_prc (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY VARCHAR2, p_cut_of_date IN VARCHAR2, p_Sales_from_Rep_date IN VARCHAR2, p_ledger IN NUMBER, p_org_unit_id_rms IN NUMBER, p_ou_id IN NUMBER, p_inv_org_id IN NUMBER, p_store_number IN NUMBER, p_onhand_currency IN VARCHAR2, p_markup_currency IN VARCHAR2, p_markup_calc_cur IN VARCHAR2, p_rate_type IN VARCHAR2, p_jl_rate_type IN VARCHAR2, p_type IN VARCHAR2
                        , p_report_mode IN VARCHAR2)
    AS
        lv_ret_message          VARCHAR2 (4000);
        lv_exception            EXCEPTION;
        ln_purge_days           NUMBER := 60;
        lv_file_name            VARCHAR2 (240);
        lv_exc_directory_path   VARCHAR2 (240);
        l_max_run_date          DATE;
        ln_request_id           NUMBER;
    BEGIN
        gd_cut_of_date           := TO_DATE (p_cut_of_date, 'RRRR/MM/DD HH24:MI:SS');
        gd_Sales_from_Rep_date   :=
            TO_DATE (p_Sales_from_Rep_date, 'RRRR/MM/DD HH24:MI:SS');
        gn_ledger                := p_ledger;
        gn_org_unit_id_rms       := p_org_unit_id_rms;
        gn_ou_id                 := p_ou_id;
        gn_inv_org_id            := p_inv_org_id;
        gn_store_number          := p_store_number;
        gv_onhand_currency       := p_onhand_currency; -- Onhand Journal Currency
        gv_markup_currency       := p_markup_currency; -- Sales Journal Currency
        gv_markup_calc_cur       := p_markup_calc_cur; -- Markup Calculation Currency
        gv_rate_type             := p_rate_type;
        gv_jl_rate_type          := p_jl_rate_type;

        BEGIN
            SELECT name
              INTO gv_ou_name
              FROM hr_operating_units
             WHERE organization_id = NVL (gn_org_unit_id_rms, gn_ou_id);
        EXCEPTION
            WHEN OTHERS
            THEN
                gv_ou_name   := NULL;
        END;

        IF p_type = 'Report'
        THEN
            IF p_report_mode = 'Sales'
            THEN
                mail_report_type_prc (p_report_mode);
            ELSIF p_report_mode = 'Onhand'
            THEN
                mail_report_type_prc (p_report_mode);
            ELSE
                mail_report_type_prc ('Sales');
                mail_report_type_prc ('Onhand');
            END IF;
        ELSE
            DELETE FROM
                xxdo.xxd_gl_je_ret_ic_onhand_stg_t
                  WHERE     record_status <> 'P'
                        AND TRUNC (soh_date_ts) < TRUNC (gd_cut_of_date) - 10; -- Delete Data from ONHAND staging table for last 10days of cut off date

            DELETE FROM
                xxdo.xxd_gl_je_ret_ic_markup_stg_t
                  WHERE     record_status <> 'P'
                        AND TRUNC (as_of_date) < TRUNC (gd_cut_of_date) - 10; -- Delete Data from SALES staging table for last 10days of cut off date

            DELETE FROM xxdo.xxd_gl_tran_data_hist_temp_t;

            COMMIT;

            INSERT INTO xxdo.xxd_gl_tran_data_hist_temp_t
                SELECT *
                  FROM rms13prod.tran_data_history@xxdo_retail_rms
                 WHERE 1 = 1 AND tran_date = gd_cut_of_date AND tran_code = 1;

            COMMIT;

            IF    gn_ledger IS NOT NULL
               OR gn_org_unit_id_rms IS NOT NULL
               OR gn_ou_id IS NOT NULL
               OR gn_inv_org_id IS NOT NULL
               OR gn_store_number IS NOT NULL
            THEN
                BEGIN
                    SELECT MAX (soh_date_ts)
                      INTO l_max_run_date
                      FROM xxdo.xxd_gl_je_ret_ic_onhand_stg_t
                     WHERE     1 = 1
                           AND ledger_id = NVL (gn_ledger, ledger_id)
                           AND operating_unit =
                               NVL (gn_org_unit_id_rms, operating_unit)
                           AND ou_id = NVL (gn_ou_id, ou_id)
                           AND inv_org_id = NVL (gn_inv_org_id, inv_org_id)
                           AND store_number =
                               NVL (gn_store_number, store_number)
                           AND record_status = 'P';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_max_run_date   := NULL;
                END;
            END IF;

            IF gd_cut_of_date < l_max_run_date
            THEN
                generate_setup_err_prc (
                       'Entered Cut off date should be greater than to Max Run Date.. '
                    || 'Max Run Date: '
                    || l_max_run_date);
                fnd_file.put_line (
                    fnd_file.OUTPUT,
                       'Entered Cut off date should be greater than to Max Run Date.. '
                    || 'Max Run Date: '
                    || l_max_run_date);
                raise_application_error (
                    -20001,
                       'Entered Cut off date should be greater than to Max Run Date.. '
                    || 'Max Run Date: '
                    || l_max_run_date);
            END IF;

            IF p_type = 'Process'
            THEN
                lv_ret_message   := NULL;
                insert_sale_records (lv_ret_message);

                IF lv_ret_message IS NOT NULL
                THEN
                    RAISE lv_exception;
                END IF;

                lv_ret_message   := NULL;
                insert_oh_records (lv_ret_message);

                IF lv_ret_message IS NOT NULL
                THEN
                    RAISE lv_exception;
                END IF;

                lv_ret_message   := NULL;
                insert_oh_prev_records (lv_ret_message);

                IF lv_ret_message IS NOT NULL
                THEN
                    RAISE lv_exception;
                END IF;

                lv_ret_message   := NULL;
                update_kff_attributes (lv_ret_message);

                IF lv_ret_message IS NOT NULL
                THEN
                    RAISE lv_exception;
                END IF;

                lv_ret_message   := NULL;
                update_oh_holding_markup_values (lv_ret_message);

                IF lv_ret_message IS NOT NULL
                THEN
                    RAISE lv_exception;
                END IF;

                lv_ret_message   := NULL;
                update_oh_direct_markup_values (lv_ret_message);

                IF lv_ret_message IS NOT NULL
                THEN
                    RAISE lv_exception;
                END IF;

                lv_ret_message   := NULL;
                update_sales_markup_values (lv_ret_message);

                IF lv_ret_message IS NOT NULL
                THEN
                    RAISE lv_exception;
                END IF;

                lv_ret_message   := NULL;
                validate_gl_data (lv_ret_message);

                IF lv_ret_message IS NOT NULL
                THEN
                    RAISE lv_exception;
                END IF;
            ELSIF p_type = 'Increment'
            THEN
                lv_ret_message   := NULL;
                insert_incr_sale_records (lv_ret_message);

                IF lv_ret_message IS NOT NULL
                THEN
                    RAISE lv_exception;
                END IF;

                lv_ret_message   := NULL;
                update_kff_attributes (lv_ret_message);

                IF lv_ret_message IS NOT NULL
                THEN
                    RAISE lv_exception;
                END IF;

                lv_ret_message   := NULL;
                update_sales_markup_values (lv_ret_message);

                IF lv_ret_message IS NOT NULL
                THEN
                    RAISE lv_exception;
                END IF;

                lv_ret_message   := NULL;
                validate_gl_data (lv_ret_message);

                IF lv_ret_message IS NOT NULL
                THEN
                    RAISE lv_exception;
                END IF;

                lv_ret_message   := NULL;
                update_oh_records (lv_ret_message);

                IF lv_ret_message IS NOT NULL
                THEN
                    RAISE lv_exception;
                END IF;
            END IF;

            lv_ret_message   := NULL;
            populate_gl_int (lv_ret_message);

            IF lv_ret_message IS NOT NULL
            THEN
                RAISE lv_exception;
            END IF;

            lv_ret_message   := NULL;
            import_markup_gl (lv_ret_message);

            IF lv_ret_message IS NOT NULL
            THEN
                RAISE lv_exception;
            END IF;

            lv_ret_message   := NULL;
            import_onhand_gl (lv_ret_message);

            IF lv_ret_message IS NOT NULL
            THEN
                RAISE lv_exception;
            END IF;

            generate_report_prc;
        END IF;

        write_log ('End main_prc-');
    EXCEPTION
        WHEN lv_exception
        THEN
            write_log (lv_ret_message);
        WHEN OTHERS
        THEN
            write_log ('Error in main_prc-' || SQLERRM);
    END main_prc;
END xxd_gl_je_retail_ic_markup_pkg;
/
