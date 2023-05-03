--
-- XXDO_INV_ITEM_CONV_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:41 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_INV_ITEM_CONV_PKG"
AS
    /******************************************************************************
       NAME:       xxdo_inv_item_conv_pkg
       PURPOSE:    This package contains procedures for One time Item Transmission

       REVISIONS:
       Ver        Date        Author           Description
       ---------  ----------  ---------------  ------------------------------------
       1.0        14/8/2014   Infosys           Created this package.
       2.0        09/4/2015   Infosys           COO modified to blank ; Identified by COO_BLANK
       3.0        16/4/2015   Infosys           Logic to derive the case weight added ; Identified by CASE_WEIGHT
                                                Logic to derive HTS Code added ; Identified by HTS_CODE
    ******************************************************************************/

    --Global Variables-----
    c_num_debug              NUMBER := 0;
    g_num_request_id         NUMBER := fnd_global.conc_request_id;
    g_item_request_ids_tab   tabtype_id;
    g_num_operating_unit     NUMBER := fnd_profile.VALUE ('ORG_ID');
    g_chr_status             VARCHAR2 (100) := 'UNPROCESSED';
    g_num_user_id            NUMBER := fnd_global.user_id;
    g_num_resp_id            NUMBER := fnd_global.resp_id;
    g_num_login_id           NUMBER := fnd_global.login_id;

    --------------------------------------------------------------------------------
    -- Procedure  : msg
    -- Description: procedure to print debug messages
    --------------------------------------------------------------------------------
    PROCEDURE msg (in_var_message IN VARCHAR2)
    IS
    BEGIN
        IF c_num_debug = 1
        THEN
            fnd_file.put_line (fnd_file.LOG, in_var_message);
        END IF;
    END msg;

    PROCEDURE get_gl_accounts (pn_org_id           IN     NUMBER,
                               pv_sample           IN     VARCHAR2,
                               pv_brand            IN     VARCHAR2,
                               pn_cogs_new_ccid       OUT NUMBER,
                               pn_sales_new_ccid      OUT NUMBER,
                               pn_exp_new_ccid        OUT NUMBER,
                               pv_reterror            OUT VARCHAR2,
                               pv_retcode             OUT VARCHAR2)
    IS
        ln_cogs_ccid         NUMBER;
        lv_cogs_segment1     VARCHAR2 (20);
        lv_cogs_segment2     VARCHAR2 (20);
        lv_cogs_segment3     VARCHAR2 (20);
        lv_cogs_segment4     VARCHAR2 (20);
        ln_cogs_new_ccid     NUMBER;
        lv_segment3_lookup   VARCHAR2 (50) := 'XXDOINV_GL_SEGMENT3_VALUE';
        lv_cogs_samp_code    VARCHAR2 (20) := 'COGS SAMPLE';
        lv_cogs_reg_code     VARCHAR2 (10) := 'COGS';
        ln_sales_ccid        NUMBER;
        lv_sales_segment1    VARCHAR2 (20);
        lv_sales_segment2    VARCHAR2 (20);
        lv_sales_segment3    VARCHAR2 (20);
        lv_sales_segment4    VARCHAR2 (20);
        ln_new_sales_ccid    NUMBER;
        --lv_segment3_lookup   VARCHAR2 (50) := 'XXDOINV_GL_SEGMENT3_VALUE';
        lv_sales_samp_code   VARCHAR2 (20) := 'SALES SAMPLE';
        lv_sales_reg_code    VARCHAR2 (10) := 'SALES';
        ln_exp_ccid          NUMBER;
        lv_exp_segment1      VARCHAR2 (20);
        lv_exp_segment2      VARCHAR2 (20);
        lv_exp_segment3      VARCHAR2 (20);
        lv_exp_segment4      VARCHAR2 (20);
        ln_new_exp_ccid      NUMBER;
        --  lv_segment3_lookup   VARCHAR2 (50) := 'XXDOINV_GL_SEGMENT3_VALUE';
        --   lv_samp_code         VARCHAR2 (20) := 'SALES SAMPLE';
        lv_exp_reg_code      VARCHAR2 (10) := 'EXPENSE';
        lv_err_code          VARCHAR2 (2);
        lv_err_msg           VARCHAR2 (2000);
    BEGIN
        pv_reterror   := NULL;
        pv_retcode    := NULL;

        BEGIN
            BEGIN
                SELECT cost_of_sales_account
                  INTO ln_cogs_ccid
                  FROM apps.mtl_parameters
                 WHERE organization_id = pn_org_id;

                fnd_file.put_line (
                    fnd_file.LOG,
                    'COGS defined at warehouse level:' || ln_cogs_ccid);
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_retcode   := 'E';
                    pv_reterror   :=
                        SUBSTR (
                               'Error Ocurred While Fetching COGS Account For Organization Id: '
                            || pn_org_id
                            || '  '
                            || SQLERRM,
                            1,
                            1999);
            END;

            IF ln_cogs_ccid IS NULL
            THEN
                pv_retcode   := 'E';
                pv_reterror   :=
                       'Null Cogs CCID Defined For Organization ID:'
                    || pn_org_id;
            END IF;

            IF ((pv_retcode IS NULL) AND (ln_cogs_ccid IS NOT NULL))
            THEN
                BEGIN
                    SELECT segment1, segment2
                      INTO lv_cogs_segment1, lv_cogs_segment2
                      FROM apps.gl_code_combinations
                     WHERE code_combination_id = ln_cogs_ccid;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        pv_retcode   := 'E';
                        pv_reterror   :=
                               'COGS Code Combination ID Does Not Exist For CCID:  '
                            || ln_cogs_ccid;
                    WHEN OTHERS
                    THEN
                        pv_retcode   := 'E';
                        pv_reterror   :=
                            SUBSTR (
                                   'Error Ocurred While Fetching COGS Segment1,Segment2 For CCID: '
                                || ln_cogs_ccid
                                || '  '
                                || SQLERRM,
                                1,
                                1999);
                END;

                IF pv_retcode IS NULL
                THEN
                    IF pv_sample = 'N'
                    THEN
                        BEGIN
                            SELECT meaning
                              INTO lv_cogs_segment3
                              FROM apps.fnd_lookup_values
                             WHERE     LANGUAGE = 'US'
                                   AND enabled_flag = 'Y'
                                   AND lookup_type = lv_segment3_lookup
                                   AND lookup_code = lv_cogs_reg_code;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                pv_retcode   := 'E';
                                pv_reterror   :=
                                    SUBSTR (
                                           'Error Ocurred While Fetching Segment3 For COGS Account  '
                                        || SQLERRM,
                                        1,
                                        1999);
                        END;
                    ELSE
                        BEGIN
                            SELECT meaning
                              INTO lv_cogs_segment3
                              FROM apps.fnd_lookup_values
                             WHERE     LANGUAGE = 'US'
                                   AND enabled_flag = 'Y'
                                   AND lookup_type = lv_segment3_lookup
                                   AND lookup_code = lv_cogs_samp_code;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                pv_retcode   := 'E';
                                pv_reterror   :=
                                    SUBSTR (
                                           'Error Ocurred While Fetching Segment3 For COGS Account  '
                                        || SQLERRM,
                                        1,
                                        1999);
                        END;
                    END IF;

                    IF pv_retcode IS NULL
                    THEN
                        BEGIN
                            SELECT gl_segment4
                              INTO lv_cogs_segment4
                              FROM do_custom.do_brands
                             WHERE brand_name = pv_brand;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                pv_retcode   := 'E';
                                pv_reterror   :=
                                       'GL_Segment4 Does Not Exist For Brand '
                                    || pv_brand;
                            WHEN OTHERS
                            THEN
                                pv_retcode   := 'E';
                                pv_reterror   :=
                                    SUBSTR (
                                           'Error Ocurred While Fetching Segment4 For Brand:'
                                        || pv_brand
                                        || '  '
                                        || SQLERRM,
                                        1,
                                        1999);
                        END;

                        IF pv_retcode IS NULL
                        THEN
                            BEGIN
                                SELECT code_combination_id
                                  INTO ln_cogs_new_ccid
                                  FROM apps.gl_code_combinations
                                 WHERE     segment1 = lv_cogs_segment1
                                       AND segment2 = lv_cogs_segment2
                                       AND segment3 = lv_cogs_segment3
                                       AND segment4 = lv_cogs_segment4;
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    -- msg ('GL accounts1');
                                    ln_cogs_new_ccid   := NULL;
                                    --       msg('G6 no data found');
                                    lv_err_code        := 'E';
                                    lv_err_msg         :=
                                           'COGS Code Combination Does Not Exists - '
                                        || lv_cogs_segment1
                                        || '-'
                                        || lv_cogs_segment2
                                        || '-'
                                        || lv_cogs_segment3
                                        || '-'
                                        || lv_cogs_segment4;
                                --  msg('err1'||lv_err_msg);
                                WHEN OTHERS
                                THEN
                                    pv_retcode   := 'E';
                                    pv_reterror   :=
                                        SUBSTR (
                                               SQLERRM
                                            || ' - Error When Getting COGS CCID FOR Segments- '
                                            || lv_cogs_segment1
                                            || '-'
                                            || lv_cogs_segment2
                                            || '-'
                                            || lv_cogs_segment3
                                            || '-'
                                            || lv_cogs_segment4,
                                            1,
                                            1999);
                            --  msg ('G6  ' || SQLERRM);
                            END;
                        END IF;
                    END IF;
                END IF;
            END IF;

            pn_cogs_new_ccid   := NVL (ln_cogs_new_ccid, ln_cogs_ccid);
        END;

        --  IF ln_cogs_new_ccid IS NOT NULL
        --THEN
        BEGIN
            BEGIN
                SELECT sales_account
                  INTO ln_sales_ccid
                  FROM apps.mtl_parameters
                 WHERE organization_id = pn_org_id;

                fnd_file.put_line (
                    fnd_file.LOG,
                       'Sales account defined at warehouse level:'
                    || ln_sales_ccid);
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_retcode   := 'E';
                    pv_reterror   :=
                        SUBSTR (
                               pv_reterror
                            || ' '
                            || 'Error Ocurred While Fetching SALES Account For Organization Id: '
                            || pn_org_id
                            || '  '
                            || SQLERRM,
                            1,
                            1999);
            END;

            IF ln_sales_ccid IS NULL
            THEN
                pv_retcode   := 'E';
                pv_reterror   :=
                    SUBSTR (
                           pv_reterror
                        || ' '
                        || 'Null Sales CCID Defined For Organization ID:'
                        || pn_org_id,
                        1,
                        1999);
            END IF;

            --msg ('G9');
            IF ((pv_retcode IS NULL) AND (ln_sales_ccid IS NOT NULL))
            THEN
                BEGIN
                    SELECT segment1, segment2
                      INTO lv_sales_segment1, lv_sales_segment2
                      FROM apps.gl_code_combinations
                     WHERE code_combination_id = ln_sales_ccid;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        pv_retcode   := 'E';
                        pv_reterror   :=
                            SUBSTR (
                                   pv_reterror
                                || ' '
                                || 'Sales Code Combination ID Does Not Exist For CCID:  '
                                || ln_cogs_ccid,
                                1,
                                1999);
                    WHEN OTHERS
                    THEN
                        pv_retcode   := 'E';
                        pv_reterror   :=
                            SUBSTR (
                                   pv_reterror
                                || ' '
                                || 'Error Ocurred While Fetching Sales Segment1,Segment2 For CCID: '
                                || ln_cogs_ccid
                                || '  '
                                || SQLERRM,
                                1,
                                1999);
                END;

                --  msg ('G10');
                IF pv_retcode IS NULL
                THEN
                    IF pv_sample = 'N'
                    THEN
                        BEGIN
                            SELECT meaning
                              INTO lv_sales_segment3
                              FROM apps.fnd_lookup_values
                             WHERE     LANGUAGE = 'US'
                                   AND enabled_flag = 'Y'
                                   AND lookup_type = lv_segment3_lookup
                                   AND lookup_code = lv_sales_reg_code;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                pv_retcode   := 'E';
                                pv_reterror   :=
                                    SUBSTR (
                                           pv_reterror
                                        || ' '
                                        || 'Error Ocurred While Fetching Segment3 For SALES Account  '
                                        || SQLERRM,
                                        1,
                                        1999);
                        END;
                    ELSE
                        BEGIN
                            SELECT meaning
                              INTO lv_sales_segment3
                              FROM apps.fnd_lookup_values
                             WHERE     LANGUAGE = 'US'
                                   AND enabled_flag = 'Y'
                                   AND lookup_type = lv_segment3_lookup
                                   AND lookup_code = lv_sales_samp_code;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                pv_retcode   := 'E';
                                pv_reterror   :=
                                    SUBSTR (
                                           pv_reterror
                                        || ' '
                                        || 'Error Ocurred While Fetching Segment3 For SALES Account  '
                                        || SQLERRM,
                                        1,
                                        1999);
                        END;
                    END IF;

                    -- msg ('G11');
                    IF pv_retcode IS NULL
                    THEN
                        BEGIN
                            SELECT gl_segment4
                              INTO lv_sales_segment4
                              FROM do_custom.do_brands
                             WHERE brand_name = pv_brand;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                pv_retcode   := 'E';
                                pv_reterror   :=
                                    SUBSTR (
                                           pv_reterror
                                        || ' '
                                        || 'GL_Segment4 Does Not Exist For Brand '
                                        || pv_brand,
                                        1,
                                        1999);
                            WHEN OTHERS
                            THEN
                                pv_retcode   := 'E';
                                pv_reterror   :=
                                    SUBSTR (
                                           pv_reterror
                                        || ' '
                                        || 'Error Ocurred While Fetching Segment4 For Brand:'
                                        || pv_brand
                                        || '  '
                                        || SQLERRM,
                                        1,
                                        1999);
                        END;

                        -- msg ('G12');
                        IF pv_retcode IS NULL
                        THEN
                            BEGIN
                                SELECT code_combination_id
                                  INTO ln_new_sales_ccid
                                  FROM apps.gl_code_combinations
                                 WHERE     segment1 = lv_sales_segment1
                                       AND segment2 = lv_sales_segment2
                                       AND segment3 = lv_sales_segment3
                                       AND segment4 = lv_sales_segment4;
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    --msg ('GL accounts2');
                                    ln_new_sales_ccid   := NULL;
                                    lv_err_code         := 'E';
                                    lv_err_msg          :=
                                        SUBSTR (
                                               lv_err_msg
                                            || ' '
                                            || 'Sales Code Combination Does Not Exists - '
                                            || lv_sales_segment1
                                            || '-'
                                            || lv_sales_segment2
                                            || '-'
                                            || lv_sales_segment3
                                            || '-'
                                            || lv_sales_segment4,
                                            1,
                                            1999);
                                -- msg('err2'||lv_err_msg);
                                WHEN OTHERS
                                THEN
                                    pv_retcode   := 'E';
                                    pv_reterror   :=
                                        SUBSTR (
                                               pv_reterror
                                            || ' '
                                            || SQLERRM
                                            || ' - Error When Getting COGS CCID FOR Segments- '
                                            || lv_sales_segment1
                                            || '-'
                                            || lv_sales_segment2
                                            || '-'
                                            || lv_sales_segment3
                                            || '-'
                                            || lv_sales_segment4,
                                            1,
                                            1999);
                            -- msg('sales acct error '||sqlerrm);
                            END;
                        END IF;
                    END IF;
                END IF;
            END IF;

            pn_sales_new_ccid   := NVL (ln_new_sales_ccid, ln_sales_ccid);
        END;

        --IF ln_new_sales_ccid IS NOT NULL
        --THEN
        BEGIN
            BEGIN
                SELECT expense_account
                  INTO ln_exp_ccid
                  FROM apps.mtl_parameters
                 WHERE organization_id = pn_org_id;

                fnd_file.put_line (
                    fnd_file.LOG,
                       'Expense account defined at warehouse level:'
                    || ln_exp_ccid);
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_retcode   := 'E';
                    pv_reterror   :=
                        SUBSTR (
                               pv_reterror
                            || ' '
                            || 'Error Ocurred While Fetching EXPENSE Account For Organization Id: '
                            || pn_org_id
                            || '  '
                            || SQLERRM,
                            1,
                            1999);
            END;

            IF ln_exp_ccid IS NULL
            THEN
                pv_retcode   := 'E';
                pv_reterror   :=
                    SUBSTR (
                           pv_reterror
                        || '-'
                        || 'Null Expense CCID Defined For Organization ID:'
                        || pn_org_id,
                        1,
                        1999);
            END IF;

            IF ((ln_exp_ccid IS NOT NULL) AND (pv_retcode IS NULL))
            THEN
                BEGIN
                    SELECT segment1, segment2
                      INTO lv_exp_segment1, lv_exp_segment2
                      FROM apps.gl_code_combinations
                     WHERE code_combination_id = ln_exp_ccid;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        pv_retcode   := 'E';
                        pv_reterror   :=
                            SUBSTR (
                                   pv_reterror
                                || ' '
                                || 'Code Combination ID Does Not Exist For EXPENSE CCID:  '
                                || ln_cogs_ccid,
                                1,
                                1999);
                    WHEN OTHERS
                    THEN
                        pv_retcode   := 'E';
                        pv_reterror   :=
                            SUBSTR (
                                   pv_reterror
                                || ' '
                                || 'Error Ocurred While Fetching Segment1,Segment2 For EXPENSE CCID: '
                                || ln_cogs_ccid
                                || '  '
                                || SQLERRM,
                                1,
                                1999);
                END;

                IF pv_retcode IS NULL
                THEN
                    BEGIN
                        SELECT meaning
                          INTO lv_exp_segment3
                          FROM apps.fnd_lookup_values
                         WHERE     LANGUAGE = 'US'
                               AND enabled_flag = 'Y'
                               AND lookup_type = lv_segment3_lookup
                               AND lookup_code = lv_exp_reg_code;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            pv_retcode   := 'E';
                            pv_reterror   :=
                                SUBSTR (
                                       pv_reterror
                                    || ' '
                                    || 'Error Ocurred While Fetching Segment3 For EXPENSE Account  '
                                    || SQLERRM,
                                    1,
                                    1999);
                    END;

                    IF pv_retcode IS NULL
                    THEN
                        BEGIN
                            SELECT gl_segment4
                              INTO lv_exp_segment4
                              FROM do_custom.do_brands
                             WHERE brand_name = pv_brand;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                pv_retcode   := 'E';
                                pv_reterror   :=
                                    SUBSTR (
                                           pv_reterror
                                        || ' '
                                        || 'GL_Segment4 Does Not Exist For Brand '
                                        || pv_brand,
                                        1,
                                        1999);
                            WHEN OTHERS
                            THEN
                                pv_retcode   := 'E';
                                pv_reterror   :=
                                    SUBSTR (
                                           pv_reterror
                                        || ' '
                                        || 'Error Ocurred While Fetching Segment4 For Brand:'
                                        || pv_brand
                                        || '  '
                                        || SQLERRM,
                                        1,
                                        1999);
                        END;

                        IF pv_retcode IS NULL
                        THEN
                            BEGIN
                                SELECT code_combination_id
                                  INTO ln_new_exp_ccid
                                  FROM apps.gl_code_combinations
                                 WHERE     segment1 = lv_exp_segment1
                                       AND segment2 = lv_exp_segment2
                                       AND segment3 = lv_exp_segment3
                                       AND segment4 = lv_exp_segment4;
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    --msg ('GL accounts3');
                                    ln_new_exp_ccid   := NULL;
                                    lv_err_code       := 'E';
                                    lv_err_msg        :=
                                        SUBSTR (
                                               lv_err_msg
                                            || ' '
                                            || 'Expense Code Combination Does Not Exists - '
                                            || lv_exp_segment1
                                            || '-'
                                            || lv_exp_segment2
                                            || '-'
                                            || lv_exp_segment3
                                            || '-'
                                            || lv_exp_segment4,
                                            1,
                                            1999);
                                WHEN OTHERS
                                THEN
                                    --msg('EXP others'||SQLERRM);
                                    pv_retcode   := 'E';
                                    pv_reterror   :=
                                        SUBSTR (
                                               pv_reterror
                                            || ' '
                                            || SQLERRM
                                            || ' - Error When Getting EXPENSE CCID FOR Segments- '
                                            || lv_exp_segment1
                                            || '-'
                                            || lv_exp_segment2
                                            || '-'
                                            || lv_exp_segment3
                                            || '-'
                                            || lv_exp_segment4,
                                            1,
                                            1999);
                            END;
                        END IF;
                    END IF;
                END IF;
            END IF;

            --msg('err'||lv_err_msg);
            pv_reterror       := lv_err_msg;
            pv_retcode        := lv_err_code;
            pn_exp_new_ccid   := NVL (ln_new_exp_ccid, ln_exp_ccid);
        END;
    -- END IF;
    -- END IF;
    END;

    -- ***************************************************************************
    --                (c) Copyright Deckers
    --                    All rights reserved
    -- ***************************************************************************
    --
    -- Package Name :  xxdo_inv_item_conv_pkg
    -- PROCEDURE Name :main_extract
    -- Description  :  This is procedure body to insert valid items into the
    --                 staging table
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- DATE          Author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    --
    -- 2014/08/14    Infosys            12.0.0   Initial
    -- 2015/01/15    Infosys            12.0.1   Updated accounting info and serial flag
    -- 2015/01/28    Infosys            12.0.2   Modified for BT Remediation
    -- ***************************************************************************
    PROCEDURE main_extract (
        p_out_var_errbuf         OUT VARCHAR2,
        p_out_var_retcode        OUT NUMBER,
        p_in_var_source       IN     VARCHAR2,
        p_in_var_dest         IN     VARCHAR2 DEFAULT 'US1',
        p_in_var_brand        IN     VARCHAR2,
        p_in_var_gender       IN     VARCHAR2,
        p_in_var_series       IN     VARCHAR2,
        p_in_var_prod_class   IN     VARCHAR2,
        p_in_num_months       IN     NUMBER,
        p_in_var_mode         IN     VARCHAR2 DEFAULT 'Extract',
        p_debug_level         IN     VARCHAR2,
        p_in_var_batch_size   IN     NUMBER,
        p_in_style            IN     VARCHAR2,
        p_in_color            IN     VARCHAR2,
        p_in_size             IN     VARCHAR2)
    AS
        CURSOR cur_item IS
              SELECT mp.organization_id
                         wh_id,
                     msi.inventory_item_id
                         inventory_item_id,
                     mp.organization_code
                         warehouse_code,
                     /*(msi.segment1 || '-' || msi.segment2 || '-' || msi.segment3
                     ) item_number,*/
                     -- Commented for BT Remediation
                     msi.segment1
                         item_number,              -- Added for BT Remediation
                     msi.description
                         host_description,
                     apps.xxdo_iid_to_serial (msi.inventory_item_id,
                                              msi.organization_id)
                         serial_control,
                     msi.primary_uom_code
                         uom,
                     /*Commented for BT Remediation BEGIN*/
                     /*msi.segment1 style_code,
                       mc.attribute7 style_code,
                       ffv_styles.description style_name,
                       --msi.segment2 color_code,
                       mc.attribute8 color_code,
                       ffv_colors.description color_name,
                       --msi.segment3 size_code,  */
                     /*Commented for BT Remediation END*/
                     /*Added for BT Remediation BEGIN*/
                     xciv.style_number
                         style_code,
                     xciv.style_desc
                         style_name,
                     xciv.color_code
                         color_code,
                     xciv.color_desc
                         color_name,
                     /*Added for BT Remediation END*/
                     msi.attribute27
                         size_code,
                     --msi.segment3 size_name,
                     msi.attribute27
                         size_name,
                     msi.attribute11
                         upc,
                     DECODE (msi.attribute11,
                             NULL, NULL,
                             '''' || msi.attribute11 || '''')
                         upc_rep,
                     NVL (msi.unit_weight, 0)
                         each_weight,
                     NVL (msi.unit_length, 0)
                         each_length,
                     NVL (msi.unit_width, 0)
                         each_width,
                     NVL (msi.unit_height, 0)
                         each_height,
                     mc.segment1
                         brand_code,
                     NULL
                         coo,                                      --COO_BLANK
                     msi.item_type
                         inventory_type,
                     (SELECT meaning
                        FROM fnd_lookup_values
                       WHERE     lookup_type LIKE 'ITEM_TYPE'
                             AND LANGUAGE = 'US'
                             AND lookup_code = msi.item_type)
                         inventory_type_rep,
                     msi.shelf_life_days
                         shelf_life,
                     1
                         alt_item_number,
                     mc.segment2
                         gender,
                     mc.segment3
                         product_class,
                     mc.segment4
                         product_category,
                     msi.inventory_item_status_code
                         host_status,
                     msi.attribute1
                         intro_season,
                     msi.attribute1
                         last_active_season,
                     msi.purchasing_item_flag,
                     msi.summary_flag,
                     msi.enabled_flag,
                     mp.sales_account,
                     mp.cost_of_sales_account,
                     msi.creation_date,
                     NVL (conversion_rate, 0)
                         unit_per_case,
                     NVL (LENGTH, 0)
                         case_length,
                     NVL (width, 0)
                         case_width,
                     NVL (height, 0)
                         case_height,
                     NVL (conversion_rate, 0) * NVL (msi.unit_weight, 0)
                         case_weight,                           -- CASE_WEIGHT
                     NVL (
                         NVL (
                             (SELECT mcb.segment1 hts_code
                                FROM apps.mtl_categories_b mcb, apps.mtl_item_categories mic2, apps.mtl_category_sets mcs
                               WHERE     mic2.category_set_id =
                                         mcs.category_set_id
                                     AND mic2.category_id = mcb.category_id
                                     AND mic2.organization_id =
                                         msi.organization_id
                                     AND mic2.inventory_item_id =
                                         msi.inventory_item_id
                                     AND mcb.structure_id = mcs.structure_id
                                     AND mcs.category_set_name = 'TARRIF CODE'),
                             (SELECT tag
                                FROM apps.fnd_lookup_values
                               WHERE     lookup_type = 'XXDO_DC2_HTS_CODE'
                                     AND LANGUAGE = 'US'
                                     AND lookup_code = xciv.style_number)),
                         NULL)
                         hts_code                                   --HTS_CODE
                FROM mtl_parameters mp, mtl_system_items_b msi, mtl_categories_b mc,
                     mtl_item_categories mic, mtl_category_sets mcs, /*Commented for BT Remediation BEGIN*/
                                                                     --fnd_flex_values_vl ffv_styles,
                                                                     --fnd_flex_value_sets ffvs_styles,
                                                                     --fnd_flex_values_vl ffv_colors,
                                                                     --fnd_flex_value_sets ffvs_colors,
                                                                     /*Commented for BT Remediation END*/
                                                                     mtl_uom_conversions muc,
                     xxd_common_items_v xciv       -- Added for BT Remediation
               WHERE     mp.organization_code = p_in_var_source
                     AND mp.organization_id = msi.organization_id
                     AND msi.organization_id = mic.organization_id
                     AND mic.inventory_item_id = msi.inventory_item_id
                     AND mcs.category_set_id = mic.category_set_id
                     AND mcs.category_set_id = 1
                     AND msi.inventory_item_status_code IN
                             ('Active', 'NAB', 'CloseOut')
                     AND mic.inventory_item_id = msi.inventory_item_id
                     /*Commented for BT Remediation BEGIN*/
                     /*AND ffv_styles.flex_value = msi.segment1
                      AND ffv_styles.flex_value = mc.attribute7
                      AND ffv_styles.flex_value_set_id = ffvs_styles.flex_value_set_id
                      AND ffvs_styles.flex_value_set_name = 'DO_STYLES_CAT'
                      AND ffvs_styles.flex_value_set_name = 'DO_STYLE_CAT'
                      AND ffv_colors.flex_value = msi.segment2
                      AND ffv_colors.flex_value = mc.attribute8
                      AND ffv_colors.flex_value_set_id = ffvs_colors.flex_value_set_id
                      AND ffvs_colors.flex_value_set_name = 'DO_COLORS_CAT'
                      AND ffvs_colors.flex_value_set_name = 'DO_STYLEOPTION_CAT'  */
                     /*Commented for BT Remediation END*/
                     /*Added for BT Remediation BEGIN*/
                     AND xciv.inventory_item_id = msi.inventory_item_id
                     AND xciv.organization_id = msi.organization_id
                     AND xciv.category_set_id = mcs.category_set_id
                     AND xciv.category_id = mc.category_id
                     /*Added for BT Remediation END*/
                     AND mc.category_id = mic.category_id
                     AND UPPER (mc.segment1) = UPPER (p_in_var_brand)
                     AND mc.segment4 = NVL (p_in_var_prod_class, mc.segment4)
                     AND mc.segment3 = NVL (p_in_var_series, mc.segment3)
                     AND mc.segment2 = NVL (p_in_var_gender, mc.segment2)
                     /* below parameters are added only for testing purpose */
                     /* AND msi.segment1 = NVL (p_in_style, msi.segment1)
                      AND msi.segment2 = NVL (p_in_color, msi.segment2)
                      AND msi.segment3 = NVL (p_in_size, msi.segment3)
                      AND mc.segment7 = NVL (p_in_style, mc.segment7)
                      AND mc.segment8 = NVL (p_in_color, mc.segment8)*/
                     AND xciv.style_number =
                         NVL (p_in_style, xciv.style_number)
                     AND xciv.color_code = NVL (p_in_color, xciv.color_code)
                     AND msi.attribute27 = NVL (p_in_size, msi.attribute27)
                     AND msi.inventory_item_id = muc.inventory_item_id(+)
                     AND muc.unit_of_measure(+) = 'Case'
            ORDER BY wh_id, inventory_item_id;

        CURSOR cur_stg IS
            SELECT DISTINCT batch_id
              FROM xxdo_inv_item_stg
             WHERE request_id = g_num_request_id;

        fhandle                    UTL_FILE.file_type;
        lv_file_name               VARCHAR2 (50)
                                       := 'Items-' || g_num_request_id || '.xls';
        lv_location                VARCHAR2 (50) := 'XXDO_INV_ITEM_FILE_DIR';
        l_chr_req_failure          VARCHAR2 (1) := 'N';
        l_chr_phase                VARCHAR2 (100) := NULL;
        l_chr_status               VARCHAR2 (100) := NULL;
        l_chr_dev_phase            VARCHAR2 (100) := NULL;
        l_chr_dev_status           VARCHAR2 (100) := NULL;
        l_chr_message              VARCHAR2 (1000) := NULL;
        lv_hdata_record            VARCHAR2 (32767);
        ln_set_process_id          NUMBER := 0;
        ln_batch_size              NUMBER := 1000;
        ln_total_count             NUMBER;
        ln_no_of_batches           NUMBER;
        l_bol_req_status           BOOLEAN;
        ln_or_id                   NUMBER;
        ln_mas_or_id               NUMBER;
        l_num_count                NUMBER := 0;
        l_num_batch_id             NUMBER := 0;
        l_num_master_org           NUMBER := 0;
        i                          NUMBER;
        l_chr_valid_item_flag      VARCHAR2 (1) := 'N';
        l_num_value                NUMBER;
        l_num_cogs_ccid_sample     NUMBER := NULL;
        l_num_sales_ccid_sample    NUMBER := NULL;
        l_num_exp_ccid_sample      NUMBER := NULL;
        l_num_cogs_ccid_regular    NUMBER := NULL;
        l_num_sales_ccid_regular   NUMBER := NULL;
        l_num_exp_ccid_regular     NUMBER := NULL;
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
               'Main program started for Item Conv Interface:'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
        fnd_file.put_line (fnd_file.LOG, 'Input Parameters:');
        fnd_file.put_line (fnd_file.LOG, 'Source :- ' || p_in_var_source);
        fnd_file.put_line (fnd_file.LOG, 'Destination :- ' || p_in_var_dest);
        fnd_file.put_line (fnd_file.LOG, 'Brand :- ' || p_in_var_brand);
        fnd_file.put_line (fnd_file.LOG,
                           'Number of Months :- ' || p_in_num_months);
        fnd_file.put_line (fnd_file.LOG, 'Series :- ' || p_in_var_series);
        fnd_file.put_line (fnd_file.LOG,
                           'Product Class:- ' || p_in_var_prod_class);
        fnd_file.put_line (fnd_file.LOG, 'Gender :- ' || p_in_var_gender);
        fnd_file.put_line (fnd_file.LOG, 'Mode :- ' || p_in_var_mode);

        BEGIN
            SELECT organization_id, master_organization_id
              INTO ln_or_id, l_num_master_org
              FROM mtl_parameters
             WHERE organization_code = p_in_var_dest;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_or_id           := -1;
                l_num_master_org   := -1;
        END;

        IF p_debug_level = 'Y'
        THEN
            c_num_debug   := 1;
        ELSE
            c_num_debug   := 0;
        END IF;

        p_out_var_errbuf    := NULL;
        p_out_var_retcode   := NULL;

        /*fnd_file.put_line (fnd_file.LOG, 'Deriving accounts for regular items');
        get_gl_accounts (ln_or_id,
                         'N',
                         p_in_var_brand,
                         l_num_cogs_ccid_regular,
                         l_num_sales_ccid_regular,
                         l_num_exp_ccid_regular,
                         p_out_var_errbuf,
                         p_out_var_retcode
                        );
        fnd_file.put_line (fnd_file.LOG,
                              'gl accout derivation for regular. Return status '
                           || p_out_var_errbuf
                          );
        fnd_file.put_line (fnd_file.LOG,
                           'Derived cogs account:' || l_num_cogs_ccid_regular
                          );
        fnd_file.put_line (fnd_file.LOG,
                           'Derived sales account:' || l_num_sales_ccid_regular
                          );
        fnd_file.put_line (fnd_file.LOG,
                           'Derived expense account:' || l_num_exp_ccid_regular
                          );
        p_out_var_errbuf := NULL;
        p_out_var_retcode := NULL;
        fnd_file.put_line (fnd_file.LOG, 'Deriving accounts for sample items');
        get_gl_accounts (ln_or_id,
                         'Y',
                         p_in_var_brand,
                         l_num_cogs_ccid_sample,
                         l_num_sales_ccid_sample,
                         l_num_exp_ccid_sample,
                         p_out_var_errbuf,
                         p_out_var_retcode
                        );
        fnd_file.put_line (fnd_file.LOG,
                              'gl accout derivation for sample. Return status '
                           || p_out_var_errbuf
                          );
        fnd_file.put_line (fnd_file.LOG,
                           'Derived cogs account:' || l_num_cogs_ccid_sample
                          );
        fnd_file.put_line (fnd_file.LOG,
                           'Derived sales account:' || l_num_sales_ccid_sample
                          );
        fnd_file.put_line (fnd_file.LOG,
                           'Derived expense account:' || l_num_exp_ccid_sample
                          );
        p_out_var_errbuf := NULL;
        p_out_var_retcode := NULL; */

        SELECT xxdo_inv_item_s.NEXTVAL INTO l_num_batch_id FROM DUAL;

        l_num_count         := 0;

        FOR rec_cur_item IN cur_item
        LOOP
            /********************************
            VALIDATIONS
            *********************************/
            l_chr_valid_item_flag   := 'N';
            l_num_value             := 0;

            /* creation date is within p_in_num_months */
            IF MONTHS_BETWEEN (SYSDATE, rec_cur_item.creation_date) <=
               p_in_num_months
            THEN
                l_chr_valid_item_flag   := 'Y';
            END IF;

            /* onhand exists for item */
            IF l_chr_valid_item_flag = 'N'
            THEN
                BEGIN
                    SELECT SUM (transaction_quantity)
                      INTO l_num_value
                      FROM mtl_onhand_quantities moq
                     WHERE     moq.inventory_item_id =
                               rec_cur_item.inventory_item_id
                           AND moq.organization_id = rec_cur_item.wh_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_num_value   := 0;
                END;

                IF l_num_value > 0
                THEN
                    l_chr_valid_item_flag   := 'Y';
                END IF;
            END IF;

            l_num_value             := 0;

            /*  supply exists */
            IF l_chr_valid_item_flag = 'N'
            THEN
                BEGIN
                    SELECT COUNT (1)
                      INTO l_num_value
                      FROM mtl_supply ms
                     WHERE     ms.item_id = rec_cur_item.inventory_item_id
                           AND ms.to_organization_id = rec_cur_item.wh_id
                           AND ROWNUM = 1;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_num_value   := 0;
                END;

                IF l_num_value > 0
                THEN
                    l_chr_valid_item_flag   := 'Y';
                END IF;
            END IF;

            l_num_value             := 0;

            /*  SO in past n months */
            IF l_chr_valid_item_flag = 'N'
            THEN
                BEGIN
                    SELECT COUNT (1)
                      INTO l_num_value
                      FROM oe_order_lines_all ool
                     WHERE     ool.inventory_item_id =
                               rec_cur_item.inventory_item_id
                           AND ool.ship_from_org_id = rec_cur_item.wh_id
                           AND MONTHS_BETWEEN (SYSDATE, ool.creation_date) <=
                               p_in_num_months
                           AND ROWNUM = 1;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_num_value   := 0;
                END;

                IF l_num_value > 0
                THEN
                    l_chr_valid_item_flag   := 'Y';
                END IF;
            END IF;

            IF l_chr_valid_item_flag = 'N'
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Item : '
                    || rec_cur_item.item_number
                    || ' is not eligible for extraction');
            ELSE
                l_num_count   := l_num_count + 1;

                IF l_num_count = 1
                THEN
                    fnd_file.put_line (
                        fnd_file.output,
                           'wh_id'
                        || CHR (9)
                        || 'item_number'
                        || CHR (9)
                        || 'host_description'
                        || CHR (9)
                        || 'serial_control'
                        || CHR (9)
                        || 'uom'
                        || CHR (9)
                        || 'style_code'
                        || CHR (9)
                        || 'style_name'
                        || CHR (9)
                        || 'color_code'
                        || CHR (9)
                        || 'color_name'
                        || CHR (9)
                        || 'size_code'
                        || CHR (9)
                        || 'size_name'
                        || CHR (9)
                        || 'upc'
                        || CHR (9)
                        || 'each_weight'
                        || CHR (9)
                        || 'each_length'
                        || CHR (9)
                        || 'each_width'
                        || CHR (9)
                        || 'each_height'
                        || CHR (9)
                        || 'brand_code'
                        || CHR (9)
                        || 'coo'
                        || CHR (9)
                        || 'inventory_type'
                        || CHR (9)
                        || 'shelf_life'
                        || CHR (9)
                        || 'alt_item_number'
                        || CHR (9)
                        || 'gender'
                        || CHR (9)
                        || 'product_class'
                        || CHR (9)
                        || 'product_category'
                        || CHR (9)
                        || 'host_status'
                        || CHR (9)
                        || 'intro_season'
                        || CHR (9)
                        || 'last_active_season'
                        || CHR (9)
                        || 'unit_per_case'
                        || CHR (9)
                        || 'case_length'
                        || CHR (9)
                        || 'case_width'
                        || CHR (9)
                        || 'case_height'
                        || CHR (9)
                        || 'case_weight'
                        || CHR (9)
                        || 'hts_code');
                END IF;

                /*         IF l_num_count = 1
                         THEN
                            --Generate an MS excel file
                            fhandle := UTL_FILE.fopen (lv_location, lv_file_name, 'w', 32767);
                            UTL_FILE.put_line (fhandle,
                                                  'warehouse_code'
                                               || CHR(9)
                                               || 'item_number'
                                               || CHR(9)
                                               || 'host_description'
                                               || CHR(9)
                                               || 'serial_control'
                                               || CHR(9)
                                               || 'uom'
                                               || CHR(9)
                                               || 'style_code'
                                               || CHR(9)
                                               || 'style_name'
                                               || CHR(9)
                                               || 'color_code'
                                               || CHR(9)
                                               || 'color_name'
                                               || CHR(9)
                                               || 'size_code'
                                               || CHR(9)
                                               || 'size_name'
                                               || CHR(9)
                                               || 'upc'
                                               || CHR(9)
                                               || 'each_weight'
                                               || CHR(9)
                                               || 'each_length'
                                               || CHR(9)
                                               || 'each_width'
                                               || CHR(9)
                                               || 'each_height'
                                               || CHR(9)
                                               || 'brand_code'
                                               || CHR(9)
                                               || 'coo'
                                               || CHR(9)
                                               || 'inventory_type'
                                               || CHR(9)
                                               || 'shelf_life'
                                               || CHR(9)
                                               || 'alt_item_number'
                                               || CHR(9)
                                               || 'gender'
                                               || CHR(9)
                                               || 'product_class'
                                               || CHR(9)
                                               || 'product_category'
                                               || CHR(9)
                                               || 'host_status'
                                               || CHR(9)
                                               || 'intro_season'
                                               || CHR(9)
                                               || 'last_active_season'
                                              );
                         END IF;
                */
                lv_hdata_record   :=
                       --  rec_cur_item.warehouse_code
                       p_in_var_dest
                    || CHR (9)
                    || rec_cur_item.item_number
                    || CHR (9)
                    || rec_cur_item.host_description
                    || CHR (9)
                    || rec_cur_item.serial_control
                    || CHR (9)
                    || rec_cur_item.uom
                    || CHR (9)
                    || rec_cur_item.style_code
                    || CHR (9)
                    || rec_cur_item.style_name
                    || CHR (9)
                    || rec_cur_item.color_code
                    || CHR (9)
                    || rec_cur_item.color_name
                    || CHR (9)
                    || ''''
                    || rec_cur_item.size_code
                    || CHR (9)
                    || ''''
                    || rec_cur_item.size_name
                    || CHR (9)
                    || rec_cur_item.upc_rep
                    || CHR (9)
                    || NVL (rec_cur_item.each_weight, 0)
                    || CHR (9)
                    || NVL (rec_cur_item.each_length, 0)
                    || CHR (9)
                    || NVL (rec_cur_item.each_width, 0)
                    || CHR (9)
                    || NVL (rec_cur_item.each_height, 0)
                    || CHR (9)
                    || rec_cur_item.brand_code
                    || CHR (9)
                    || rec_cur_item.coo
                    || CHR (9)
                    || rec_cur_item.inventory_type_rep
                    || CHR (9)
                    || rec_cur_item.shelf_life
                    || CHR (9)
                    || rec_cur_item.alt_item_number
                    || CHR (9)
                    || rec_cur_item.gender
                    || CHR (9)
                    || rec_cur_item.product_class
                    || CHR (9)
                    || rec_cur_item.product_category
                    || CHR (9)
                    || rec_cur_item.host_status
                    || CHR (9)
                    || rec_cur_item.intro_season
                    || CHR (9)
                    || rec_cur_item.last_active_season
                    || CHR (9)
                    || rec_cur_item.unit_per_case
                    || CHR (9)
                    || rec_cur_item.case_length
                    || CHR (9)
                    || rec_cur_item.case_width
                    || CHR (9)
                    || rec_cur_item.case_height
                    || CHR (9)
                    || rec_cur_item.case_weight
                    || CHR (9)
                    || rec_cur_item.hts_code;
                --UTL_FILE.put_line (fhandle, lv_hdata_record);
                fnd_file.put_line (fnd_file.output, lv_hdata_record);

                IF (p_in_var_mode = 'Extract And Copy')
                THEN
                    IF MOD (l_num_count, p_in_var_batch_size) = 0
                    THEN
                        SELECT xxdo_inv_item_s.NEXTVAL
                          INTO l_num_batch_id
                          FROM DUAL;
                    END IF;

                    /*insert into staging table*/
                    BEGIN
                        INSERT INTO xxdo_inv_item_stg (warehouse_code,
                                                       item_number,
                                                       host_description,
                                                       serial_control,
                                                       uom,
                                                       style_code,
                                                       style_name,
                                                       color_code,
                                                       color_name,
                                                       size_code,
                                                       size_name,
                                                       upc,
                                                       each_weight,
                                                       each_length,
                                                       each_width,
                                                       each_height,
                                                       brand_code,
                                                       coo,
                                                       inventory_type,
                                                       shelf_life,
                                                       alt_item_number,
                                                       gender,
                                                       product_class,
                                                       product_category,
                                                       host_status,
                                                       intro_season,
                                                       last_active_season,
                                                       process_status,
                                                       request_id,
                                                       inventory_item_id,
                                                       summary_flag,
                                                       enabled_flag,
                                                       purchasing_item_flag,
                                                       sales_account,
                                                       cost_of_sales_account,
                                                       --expense_account,
                                                       record_type,
                                                       dest_wh_code,
                                                       dest_wh_id,
                                                       batch_id)
                                 VALUES (
                                            rec_cur_item.warehouse_code,
                                            rec_cur_item.item_number,
                                            rec_cur_item.host_description,
                                            NVL (rec_cur_item.serial_control,
                                                 'N'),
                                            rec_cur_item.uom,
                                            rec_cur_item.style_code,
                                            rec_cur_item.style_name,
                                            rec_cur_item.color_code,
                                            rec_cur_item.color_name,
                                            rec_cur_item.size_code,
                                            rec_cur_item.size_name,
                                            rec_cur_item.upc,
                                            NVL (rec_cur_item.each_weight, 0),
                                            NVL (rec_cur_item.each_length, 0),
                                            NVL (rec_cur_item.each_width, 0),
                                            NVL (rec_cur_item.each_height, 0),
                                            rec_cur_item.brand_code,
                                            rec_cur_item.coo,
                                            rec_cur_item.inventory_type,
                                            rec_cur_item.shelf_life,
                                            rec_cur_item.alt_item_number,
                                            rec_cur_item.gender,
                                            rec_cur_item.product_class,
                                            rec_cur_item.product_category,
                                            rec_cur_item.host_status,
                                            rec_cur_item.intro_season,
                                            rec_cur_item.last_active_season,
                                            'INPROCESS',
                                            g_num_request_id,
                                            rec_cur_item.inventory_item_id,
                                            rec_cur_item.summary_flag,
                                            rec_cur_item.enabled_flag,
                                            rec_cur_item.purchasing_item_flag,
                                            /*DECODE (rec_cur_item.product_class,
                                                    'SAMPLE', l_num_sales_ccid_sample,
                                                    l_num_sales_ccid_regular
                                                   ),
                                            DECODE (rec_cur_item.product_class,
                                                    'SAMPLE', l_num_cogs_ccid_sample,
                                                    l_num_cogs_ccid_regular
                                                   ),
                                            DECODE (rec_cur_item.product_class,
                                                    'SAMPLE', l_num_exp_ccid_sample,
                                                    l_num_exp_ccid_regular
                                                   ),*/
                                            rec_cur_item.sales_account,
                                            rec_cur_item.cost_of_sales_account,
                                            'CREATE',
                                            p_in_var_dest,
                                            ln_or_id,
                                            l_num_batch_id);

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            p_out_var_retcode   := 2;
                            p_out_var_errbuf    :=
                                   'Error occured for staging table insert '
                                || SQLERRM;
                            msg (p_out_var_errbuf);
                            ROLLBACK;
                    END;
                END IF;
            END IF;
        END LOOP;

        IF l_num_count > 0 AND (p_in_var_mode = 'Extract And Copy')
        THEN
            -- UTL_FILE.fclose (fhandle);
            NULL;
        END IF;

        UPDATE xxdo_inv_item_stg xit
           SET error_message = 'Item already exists', process_status = 'IGNORED'
         WHERE     request_id = g_num_request_id
               AND EXISTS
                       (SELECT 1
                          FROM mtl_system_items msi
                         WHERE     msi.organization_id = xit.dest_wh_id
                               AND msi.inventory_item_id =
                                   xit.inventory_item_id);

        COMMIT;

        /*
        DUAL UOM CONTROL flags cannot be null at master org level. These are master controlled attributes.
        If these attributes are null, item import will fail. These were null for items that were created long back.
        This might be an issues with older versions of Oracle and currently for newly created items this issue
        does not exist. To make sure that item import won't fail in such cases where data has issues, these
        flags are updated for master org. This approach has been followed in all the customizations / item import
        processess. This has been discussed with current production support team and same is incorporated here.
        */
        UPDATE mtl_system_items msi
           SET dual_uom_deviation_high = 0, dual_uom_deviation_low = 0, dual_uom_control = 1
         WHERE     inventory_item_id IN
                       (SELECT xit.inventory_item_id
                          FROM xxdo_inv_item_stg xit
                         WHERE     request_id = g_num_request_id
                               AND process_status = 'INPROCESS')
               AND (msi.dual_uom_deviation_high IS NULL OR msi.dual_uom_deviation_low IS NULL OR msi.dual_uom_control IS NULL)
               AND organization_id = (SELECT mp.master_organization_id
                                        FROM mtl_parameters mp
                                       WHERE mp.organization_id = ln_or_id);

        COMMIT;

        /*insert into interface table (batch wise)*/
        BEGIN
            INSERT INTO mtl_system_items_interface (organization_id,
                                                    inventory_item_id,
                                                    item_type,
                                                    segment1,
                                                    /*segment2, segment3,*/
                                                     --Commented for BT Remediation
                                                    description,
                                                    transaction_type,
                                                    set_process_id,
                                                    summary_flag,
                                                    enabled_flag,
                                                    organization_code,
                                                    primary_uom_code,
                                                    process_flag,
                                                    purchasing_item_flag,
                                                    sales_account,
                                                    cost_of_sales_account,
                                                    expense_account,
                                                    last_update_date,
                                                    last_updated_by,
                                                    creation_date,
                                                    created_by,
                                                    last_update_login)
                SELECT dest_wh_id, inventory_item_id, inventory_type,
                       /*style_code,color_code, size_code,*/
                                                --Commented for BT Remediation
                       style_code || '-' || color_code || '-' || size_code, host_description, record_type,
                       batch_id, summary_flag, enabled_flag,
                       dest_wh_code, uom, 1,
                       purchasing_item_flag, sales_account, cost_of_sales_account,
                       expense_account, SYSDATE, g_num_user_id,
                       SYSDATE, g_num_user_id, g_num_login_id
                  FROM xxdo_inv_item_stg
                 WHERE     request_id = g_num_request_id
                       AND process_status = 'INPROCESS';

            l_num_count   := SQL%ROWCOUNT;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_chr_req_failure   := 'Y';
                p_out_var_retcode   := 2;
                p_out_var_errbuf    :=
                    'Error occured for interface table insert ' || SQLERRM;
                msg (p_out_var_errbuf);
                ROLLBACK;
        END;

        COMMIT;
        i                   := 0;

        IF l_num_count > 0
        THEN
            FOR cur_stg_rec IN cur_stg
            LOOP
                i   := i + 1;
                g_item_request_ids_tab (i)   :=
                    fnd_request.submit_request (
                        application   => 'INV',
                        program       => 'INCOIN',
                        argument1     => l_num_master_org,
                        argument2     => 1,
                        argument3     => 1,
                        argument4     => 1,
                        argument5     => 1,
                        argument6     => cur_stg_rec.batch_id,
                        --batch_number
                        argument7     => 1,
                        description   => NULL,
                        start_time    => NULL);
                COMMIT;

                IF g_item_request_ids_tab (i) = 0
                THEN
                    fnd_file.put_line (fnd_file.LOG,
                                       ' Concurrent Request is not launched');
                    p_out_var_retcode   := '1';
                    p_out_var_errbuf    :=
                        'One or more Child requests are not launched. Please refer the log file for more details';
                ELSE
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Concurrent Request ID : '
                        || g_item_request_ids_tab (i));
                END IF;
            END LOOP;

            COMMIT;
            l_chr_req_failure   := 'N';
            fnd_file.put_line (fnd_file.LOG, '');
            fnd_file.put_line (
                fnd_file.LOG,
                '-------------Concurrent Requests Status Report ---------------');

            FOR i IN 1 .. g_item_request_ids_tab.COUNT
            LOOP
                l_bol_req_status   :=
                    fnd_concurrent.wait_for_request (
                        g_item_request_ids_tab (i),
                        10,
                        0,
                        l_chr_phase,
                        l_chr_status,
                        l_chr_dev_phase,
                        l_chr_dev_status,
                        l_chr_message);
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Concurrent request ID : '
                    || g_item_request_ids_tab (i)
                    || CHR (9)
                    || ' Phase: '
                    || l_chr_phase
                    || CHR (9)
                    || ' Status: '
                    || l_chr_status
                    || CHR (9)
                    || ' Dev Phase: '
                    || l_chr_dev_phase
                    || CHR (9)
                    || ' Dev Status: '
                    || l_chr_dev_status
                    || CHR (9)
                    || ' Message: '
                    || l_chr_message);
            END LOOP;
        END IF;

        UPDATE xxdo_inv_item_stg xii
           SET process_status     = 'ERROR',
               last_update_date   = SYSDATE,
               error_message     =
                   (SELECT error_message
                      FROM mtl_interface_errors mie, mtl_system_items_interface msii
                     WHERE     msii.set_process_id = xii.batch_id
                           AND msii.organization_id = xii.dest_wh_id
                           AND msii.inventory_item_id = xii.inventory_item_id
                           AND msii.transaction_id = mie.transaction_id
                           AND msii.process_flag = 3
                           AND ROWNUM = 1)
         WHERE     request_id = g_num_request_id
               AND process_status = 'INPROCESS'
               AND EXISTS
                       (SELECT 1
                          FROM mtl_system_items_interface msii
                         WHERE     msii.set_process_id = xii.batch_id
                               AND msii.organization_id = xii.dest_wh_id
                               AND msii.inventory_item_id =
                                   xii.inventory_item_id
                               AND msii.set_process_id = xii.batch_id
                               AND msii.process_flag = 3);

        UPDATE xxdo_inv_item_stg xii
           SET process_status = 'SUCCESS', error_message = NULL, last_update_date = SYSDATE
         WHERE request_id = g_num_request_id AND process_status = 'INPROCESS';

        COMMIT;
    EXCEPTION
        WHEN UTL_FILE.invalid_path
        THEN
            raise_application_error (-20100, 'Invalid Path');
            UTL_FILE.fclose (fhandle);
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
        WHEN UTL_FILE.invalid_mode
        THEN
            raise_application_error (-20101, 'Invalid Mode');
            UTL_FILE.fclose (fhandle);
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
        WHEN UTL_FILE.invalid_operation
        THEN
            raise_application_error (-20102, 'Invalid Operation');
            UTL_FILE.fclose (fhandle);
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
        WHEN UTL_FILE.invalid_filehandle
        THEN
            raise_application_error (-20103, 'Invalid Filehandle');
            UTL_FILE.fclose (fhandle);
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
        WHEN UTL_FILE.write_error
        THEN
            raise_application_error (-20104, 'Write Error');
            UTL_FILE.fclose (fhandle);
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
        WHEN UTL_FILE.read_error
        THEN
            raise_application_error (-20105, 'Read Error');
            UTL_FILE.fclose (fhandle);
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
        WHEN UTL_FILE.internal_error
        THEN
            raise_application_error (-20106, 'Internal Error');
            UTL_FILE.fclose (fhandle);
        WHEN OTHERS
        THEN
            p_out_var_retcode   := 2;
            p_out_var_errbuf    := SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                'Error occured in item insert due to  ' || SQLERRM);
    END main_extract;
END xxdo_inv_item_conv_pkg;
/
