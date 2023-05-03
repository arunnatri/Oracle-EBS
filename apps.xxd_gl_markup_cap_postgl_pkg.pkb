--
-- XXD_GL_MARKUP_CAP_POSTGL_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:58 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_GL_MARKUP_CAP_POSTGL_PKG"
AS
    --  #########################################################################################################
    --  Package      : XXD_GL_MARKUP_CAP_POSTGL_PKG
    --  Design       : This package is used to capture the markup and post to GL.
    --  Notes        :
    --  Modification :
    --  ======================================================================================
    --  Date            Version#   Name                    Comments
    --  ======================================================================================
    --  22-Mar-2020     1.0        Showkath Ali             Initial Version
    --  05-Aug-2010     1.1        Showkath Ali             UAT Defect -- New Changes
    --  28-Mar-2023     1.2        Thirupathi Gajula        CCR0010170 - Summarize the Interface/Journal records
    --  #########################################################################################################

    gn_user_id        CONSTANT NUMBER := fnd_global.user_id;
    gn_login_id       CONSTANT NUMBER := fnd_global.login_id;
    gn_org_id         CONSTANT NUMBER := fnd_global.org_id;
    gn_resp_id        CONSTANT NUMBER := fnd_global.resp_id;
    gn_resp_appl_id   CONSTANT NUMBER := fnd_global.resp_appl_id;
    gn_request_id     CONSTANT NUMBER := fnd_global.conc_request_id;
    -- Start changes for V1.2
    gv_calc_currency           VARCHAR2 (5);
    gv_rate_type               VARCHAR2 (50);
    -- End changes for V1.2
    lv_org_id                  NUMBER := 0;

    /***********************************************************************************************
    **************** Function to get source values *****************************
    ************************************************************************************************/
    FUNCTION get_source_val_fnc
        RETURN source_tbl
        PIPELINED
    IS
        l_source_tbl   source_rec;
    BEGIN
        FOR l_source_tbl
            IN (SELECT ffvl.flex_value
                  FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                 WHERE     1 = 1
                       AND ffvs.flex_value_set_name =
                           'XXD_CM_CAPTURE_MARGIN_ORD_SRC_VS'
                       AND ffvs.flex_value_set_id = ffvl.flex_value_set_id
                       AND NVL (ffvl.enabled_flag, 'Y') = 'Y'
                       AND NVL (TRUNC (ffvl.start_date_active),
                                TRUNC (SYSDATE)) <=
                           TRUNC (SYSDATE)
                       AND NVL (TRUNC (ffvl.end_date_active),
                                TRUNC (SYSDATE)) >=
                           TRUNC (SYSDATE))
        LOOP
            PIPE ROW (l_source_tbl);
        END LOOP;

        RETURN;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END get_source_val_fnc;

    /***********************************************************************************************
    **************** Function to get average margin for on-hand Markup *****************************
    ************************************************************************************************/

    FUNCTION get_onhand_avg_margin (p_orgn_id IN NUMBER, p_inventory_item_id IN NUMBER, p_transaction_date IN DATE)
        RETURN NUMBER
    IS
        ln_avg_mrgn_cst_usd   NUMBER;
        lv_curr_code          gl_ledgers.currency_code%TYPE; -- changes for V1.2
    BEGIN
        -- Start changes for V1.2
        BEGIN
            SELECT gl.currency_code
              INTO lv_curr_code
              FROM gl_ledgers gl, org_organization_definitions ood
             WHERE     1 = 1
                   AND ledger_id = set_of_books_id
                   AND organization_id = p_orgn_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_curr_code   := NULL;
        END;

        BEGIN
            SELECT                   -- avg_mrgn_cst_local -- changes for V1.2
                   CASE
                       WHEN NVL (gv_calc_currency, 'ABC') = 'Local'
                       THEN
                           NVL (avg_mrgn_cst_local, 0)
                       ELSE                    --gv_calc_currency = 'USD' THEN
                           NVL (
                               (  avg_mrgn_cst_usd
                                * (SELECT gdr.conversion_rate
                                     FROM apps.gl_daily_rates gdr
                                    WHERE     1 = 1
                                          AND gdr.conversion_type =
                                              gv_rate_type
                                          AND gdr.from_currency = 'USD'
                                          AND gdr.to_currency = lv_curr_code
                                          AND gdr.conversion_date =
                                              p_transaction_date)),
                               0)
                   END
              -- End changes for V1.2
              INTO ln_avg_mrgn_cst_usd
              FROM (  SELECT avg_mrgn_cst_local, avg_mrgn_cst_usd -- changes for V1.2
                        FROM xxd_ont_po_margin_calc_t a
                       WHERE     1 = 1
                             /*source NOT IN (
                                            'ONE_TIME_UPLOAD'
                                            )*/
                             AND destination_organization_id = p_orgn_id
                             AND inventory_item_id = p_inventory_item_id
                             AND transaction_date <= p_transaction_date
                    ORDER BY a.transaction_date DESC)
             WHERE ROWNUM = 1;

            fnd_file.put_line (fnd_file.LOG,
                               'on-hand Markup is:' || ln_avg_mrgn_cst_usd);
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_avg_mrgn_cst_usd   := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Failed to get on-hand Markup:' || SQLERRM);
        END;

        RETURN ln_avg_mrgn_cst_usd;
    END get_onhand_avg_margin;

    /***********************************************************************************************
    ************************** Function to update  markup in MMT table******************************
    ************************************************************************************************/

    FUNCTION update_mmt_attr_fun (p_avg_margin_cost   IN NUMBER,
                                  p_transaction_id    IN NUMBER)
        RETURN VARCHAR2
    IS
        lv_status   VARCHAR2 (100);
    BEGIN
        BEGIN
            UPDATE mtl_material_transactions
               SET attribute14 = p_avg_margin_cost, last_update_date = SYSDATE, last_updated_by = gn_user_id
             WHERE transaction_id = p_transaction_id;

            COMMIT;
            lv_status   := 'S';
            fnd_file.put_line (
                fnd_file.LOG,
                   'Average Margin Cost is updated for the transaction_id:'
                || p_transaction_id);
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_status   := 'E';
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Failed to update Average Margin Cost for the transaction_id:'
                    || p_transaction_id
                    || '-'
                    || SQLERRM);
        END;

        RETURN lv_status;
    END;

    /***********************************************************************************************
    **************************** Function to get ship_from org *************************************
    ************************************************************************************************/

    FUNCTION get_ship_from_org (p_organization_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_operating_unit   NUMBER;
    BEGIN
        BEGIN
            SELECT operating_unit
              INTO ln_operating_unit
              FROM org_organization_definitions a
             WHERE organization_id = p_organization_id;

            fnd_file.put_line (fnd_file.LOG,
                               'operating unit is:' || ln_operating_unit);
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_operating_unit   := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Failed to fetch operating unit' || SQLERRM);
        END;

        RETURN ln_operating_unit;
    END;

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
    **************************** Function to get Ledger id based on OU *****************************
    ************************************************************************************************/

    FUNCTION get_ledger_id (p_organization_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_ledger_id   NUMBER;
    BEGIN
        BEGIN
            SELECT set_of_books_id
              INTO ln_ledger_id
              FROM org_organization_definitions
             WHERE organization_id = p_organization_id;

            fnd_file.put_line (fnd_file.LOG,
                               'Ledger id is :' || ln_ledger_id);
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_ledger_id   := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                       ' Failed to fetch Ledger id for OU :'
                    || p_organization_id
                    || '-'
                    || SQLERRM);
        END;

        RETURN ln_ledger_id;
    END get_ledger_id;

    /***********************************************************************************************
    **************************** Function to get Order type (Regular/Return) ***********************
    ************************************************************************************************/

    FUNCTION get_order_line_type (p_line_id IN NUMBER)
        RETURN VARCHAR2
    IS
        l_rma_count         NUMBER := 0;
        l_order_line_type   VARCHAR2 (20);
    BEGIN
        BEGIN
            SELECT COUNT (1)
              INTO l_rma_count
              FROM oe_order_lines_all
             WHERE return_reason_code IS NOT NULL AND line_id = p_line_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_rma_count   := 0;
                fnd_file.put_line (fnd_file.LOG,
                                   'Failed to fetch count:' || SQLERRM);
        END;

        IF l_rma_count = 1
        THEN
            l_order_line_type   := 'RETURN';
            fnd_file.put_line (fnd_file.LOG,
                               'Order line type is :' || l_order_line_type);
        ELSE
            l_order_line_type   := 'SHIPMENT';
            fnd_file.put_line (fnd_file.LOG,
                               'Order line type is :' || l_order_line_type);
        END IF;

        RETURN l_order_line_type;
    END get_order_line_type;

    /***********************************************************************************************
    **************************** PROCEDURE to get COGS CCID Segments *******************************
    ************************************************************************************************/

    PROCEDURE get_cogs_ccid_segments_prc (p_line_id IN NUMBER, p_ledger_id IN NUMBER, p_cogs_segment1 OUT VARCHAR2, p_cogs_segment2 OUT VARCHAR2, p_cogs_segment3 OUT VARCHAR2, p_cogs_segment4 OUT VARCHAR2, p_cogs_segment5 OUT VARCHAR2, p_cogs_segment6 OUT VARCHAR2, p_cogs_segment7 OUT VARCHAR2
                                          , p_cogs_segment8 OUT VARCHAR2)
    AS
        lv_order_line_type   VARCHAR2 (100);
        lv_cogs_segment1     gl_code_combinations.segment1%TYPE := NULL;
        lv_cogs_segment2     gl_code_combinations.segment2%TYPE := NULL;
        lv_cogs_segment3     gl_code_combinations.segment3%TYPE := NULL;
        lv_cogs_segment4     gl_code_combinations.segment4%TYPE := NULL;
        lv_cogs_segment5     gl_code_combinations.segment5%TYPE := NULL;
        lv_cogs_segment6     gl_code_combinations.segment6%TYPE := NULL;
        lv_cogs_segment7     gl_code_combinations.segment7%TYPE := NULL;
        lv_cogs_segment8     gl_code_combinations.segment8%TYPE := NULL;
    BEGIN
        BEGIN
            SELECT segment1, segment2, segment3,
                   segment4, segment5, segment6,
                   segment7, segment8
              INTO lv_cogs_segment1, lv_cogs_segment2, lv_cogs_segment3, lv_cogs_segment4,
                                   lv_cogs_segment5, lv_cogs_segment6, lv_cogs_segment7,
                                   lv_cogs_segment8
              FROM gl_code_combinations
             WHERE code_combination_id =
                   (  SELECT MAX (xal.code_combination_id)
                        FROM apps.xla_ae_lines xal,
                             (SELECT application_id, event_id, ae_header_id,
                                     ae_line_num
                                FROM apps.xla_distribution_links
                               WHERE     source_distribution_id_num_1 IN
                                             (SELECT inv_sub_ledger_id
                                                FROM apps.mtl_transaction_accounts
                                               WHERE transaction_id IN
                                                         (SELECT transaction_id
                                                            FROM apps.mtl_material_transactions mmto
                                                           WHERE mmto.trx_source_line_id =
                                                                 p_line_id --ola lineid
                                                                          ))
                                     AND source_distribution_type =
                                         'MTL_TRANSACTION_ACCOUNTS') aa
                       WHERE     aa.application_id = xal.application_id
                             AND aa.ae_header_id = xal.ae_header_id
                             AND aa.ae_line_num = xal.ae_line_num
                             AND xal.accounting_class_code IN
                                     ('OFFSET', 'COST_OF_GOODS_SOLD')
                             AND xal.ledger_id = p_ledger_id      -- ledger id
                    GROUP BY xal.code_combination_id);

            fnd_file.put_line (
                fnd_file.LOG,
                   'Segment Values of COGS Account:'
                || 'segment1:'
                || lv_cogs_segment1
                || '-'
                || 'segment2:'
                || lv_cogs_segment2
                || '-'
                || 'segment3:'
                || lv_cogs_segment3
                || '-'
                || 'segment4:'
                || lv_cogs_segment4
                || '-'
                || 'segment5:'
                || lv_cogs_segment5
                || '-'
                || 'segment6:'
                || lv_cogs_segment6
                || '-'
                || 'segment7:'
                || lv_cogs_segment7
                || '-'
                || 'segment8:'
                || lv_cogs_segment8);
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_cogs_segment1   := NULL;
                lv_cogs_segment2   := NULL;
                lv_cogs_segment3   := NULL;
                lv_cogs_segment4   := NULL;
                lv_cogs_segment5   := NULL;
                lv_cogs_segment6   := NULL;
                lv_cogs_segment7   := NULL;
                lv_cogs_segment8   := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Failed to fetch CCID segment values from COGS account'
                    || SQLERRM);
        END;

        p_cogs_segment1   := lv_cogs_segment1;
        p_cogs_segment2   := lv_cogs_segment2;
        p_cogs_segment3   := lv_cogs_segment3;
        p_cogs_segment4   := lv_cogs_segment4;
        p_cogs_segment5   := lv_cogs_segment5;
        p_cogs_segment6   := lv_cogs_segment6;
        p_cogs_segment7   := lv_cogs_segment7;
        p_cogs_segment8   := lv_cogs_segment8;
    END get_cogs_ccid_segments_prc;

    /***********************************************************************************************
    **************************** Function to get journal source ************************************
    ************ ************************************************************************************/

    FUNCTION get_journal_source
        RETURN VARCHAR2
    IS
        lv_je_source_name   VARCHAR2 (100);
    BEGIN
        BEGIN
            SELECT user_je_source_name
              INTO lv_je_source_name
              FROM gl_je_sources
             WHERE user_je_source_name = 'Markup' AND language = 'US';

            fnd_file.put_line (fnd_file.LOG,
                               'Journal Source is:' || lv_je_source_name);
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_je_source_name   := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Failed to fetch Journal source' || SQLERRM);
        END;

        RETURN lv_je_source_name;
    END get_journal_source;

    /***********************************************************************************************
    **************************** Function to get journal Category **********************************
    ************************************************************************************************/

    FUNCTION get_journal_category
        RETURN VARCHAR2
    IS
        lv_je_category   VARCHAR2 (200);
    BEGIN
        BEGIN
            SELECT user_je_category_name
              INTO lv_je_category
              FROM gl_je_categories
             WHERE user_je_category_name = 'Markup' AND language = 'US';

            fnd_file.put_line (fnd_file.LOG,
                               'Journal Category is:' || lv_je_category);
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_je_category   := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Failed to fetch Journal Category' || SQLERRM);
        END;

        RETURN lv_je_category;
    END get_journal_category;

    /***********************************************************************************************
    **************************** Function to get journal Name **************************************
    ************************************************************************************************/

    FUNCTION get_journal_name (p_currency_code IN VARCHAR2)
        RETURN VARCHAR2
    IS
        l_journal_name   VARCHAR2 (100);
    BEGIN
        BEGIN
            SELECT 'Markup' || TO_CHAR (SYSDATE, 'MMDDRRRR') || p_currency_code
              INTO l_journal_name
              FROM DUAL;

            fnd_file.put_line (fnd_file.LOG,
                               'Journal Name' || l_journal_name);
        EXCEPTION
            WHEN OTHERS
            THEN
                l_journal_name   := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Failed to derive Journal Name' || SQLERRM);
        END;

        RETURN l_journal_name;
    END get_journal_name;

    /***********************************************************************************************
    ************************** Function to Get Direct markup ***************************************
    ************************************************************************************************/
    FUNCTION get_direct_markup (p_transaction_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_direct_markup   NUMBER := 0;
    BEGIN
        BEGIN
            SELECT NVL (xph.entered_dr, 0) - NVL (xph.entered_cr, 0)     --1.1
              INTO ln_direct_markup
              FROM xxcp.xxcp_process_history xph, xxcp.xxcp_mtl_material_transactions xmmt, xxcp.xxcp_account_rules xar
             WHERE     xph.interface_id = xmmt.vt_interface_id
                   AND xph.rule_id = xar.rule_id
                   AND xar.rule_name IN
                           (SELECT ffvl.flex_value
                              FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                             WHERE     1 = 1
                                   AND ffvs.flex_value_set_name =
                                       'XXD_CM_DIRECT_MGN_TYPES_VS'
                                   AND ffvs.flex_value_set_id =
                                       ffvl.flex_value_set_id
                                   AND NVL (ffvl.enabled_flag, 'N') = 'Y'
                                   AND NVL (TRUNC (ffvl.start_date_active),
                                            TRUNC (SYSDATE)) <=
                                       TRUNC (SYSDATE)
                                   AND NVL (TRUNC (ffvl.end_date_active),
                                            TRUNC (SYSDATE)) >=
                                       TRUNC (SYSDATE))
                   AND xph.source_id = 18
                   AND vt_transaction_id = p_transaction_id;

            fnd_file.put_line (fnd_file.LOG,
                               'Direct Markup is:' || ln_direct_markup);
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_direct_markup   := NULL;
                fnd_file.put_line (fnd_file.LOG,
                                   'Failed to get Direct Markup:' || SQLERRM);
        END;

        RETURN ln_direct_markup;
    END get_direct_markup;

    /***********************************************************************************************
    **************************** Function to get ledger currency ***********************************
    ************************************************************************************************/
    FUNCTION get_ledger_currency (p_ledger_id IN NUMBER)
        RETURN VARCHAR2
    IS
        l_ledger_currency   VARCHAR2 (30);
    BEGIN
        BEGIN
            SELECT currency_code
              INTO l_ledger_currency
              FROM gl_ledgers
             WHERE ledger_id = p_ledger_id;

            fnd_file.put_line (fnd_file.LOG,
                               'Ledger urrency is:' || l_ledger_currency);
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Failed to get Ledger urrency:' || SQLERRM);
        END;

        RETURN l_ledger_currency;
    END get_ledger_currency;

    /***********************************************************************************************
    **************************** Function to insert into GL Interface ******************************
    ************************************************************************************************/

    PROCEDURE insert_gl_data (p_currency_code          IN VARCHAR2,
                              p_org_id                 IN NUMBER,
                              p_organization_id        IN NUMBER,
                              p_transaction_date       IN DATE,
                              p_markup                 IN NUMBER,
                              p_line_id                IN NUMBER,
                              p_vs_segment1            IN VARCHAR2,
                              p_vs_segment2            IN VARCHAR2,
                              p_vs_segment3            IN VARCHAR2,
                              p_vs_segment4            IN VARCHAR2,
                              p_vs_segment5            IN VARCHAR2,
                              p_vs_segment6            IN VARCHAR2,
                              p_vs_segment7            IN VARCHAR2,
                              p_vs_segment8            IN VARCHAR2,
                              p_transaction_id         IN NUMBER,
                              p_conversion_type        IN VARCHAR2,
                              p_cogs_natural_account   IN VARCHAR2)
    IS
        ln_ledger_id          NUMBER := 0;
        lv_period_name        VARCHAR2 (100);
        lv_order_line_type    VARCHAR2 (100);
        lv_cogs_segment1      gl_code_combinations.segment1%TYPE := NULL;
        lv_cogs_segment2      gl_code_combinations.segment2%TYPE := NULL;
        lv_cogs_segment3      gl_code_combinations.segment3%TYPE := NULL;
        lv_cogs_segment4      gl_code_combinations.segment4%TYPE := NULL;
        lv_cogs_segment5      gl_code_combinations.segment5%TYPE := NULL;
        lv_cogs_segment6      gl_code_combinations.segment6%TYPE := NULL;
        lv_cogs_segment7      gl_code_combinations.segment7%TYPE := NULL;
        lv_cogs_segment8      gl_code_combinations.segment8%TYPE := NULL;
        lv_segment1           gl_code_combinations.segment1%TYPE := NULL;
        lv_segment2           gl_code_combinations.segment2%TYPE := NULL;
        lv_segment3           gl_code_combinations.segment3%TYPE := NULL;
        lv_segment4           gl_code_combinations.segment4%TYPE := NULL;
        lv_segment5           gl_code_combinations.segment5%TYPE := NULL;
        lv_segment6           gl_code_combinations.segment6%TYPE := NULL;
        lv_segment7           gl_code_combinations.segment7%TYPE := NULL;
        lv_segment8           gl_code_combinations.segment8%TYPE := NULL;
        lv_journal_source     VARCHAR2 (200);
        lv_journal_category   VARCHAR2 (200);
        lv_journal_name       VARCHAR2 (200);
        lv_sysdate            VARCHAR2 (100);
        lv_ledger_currency    VARCHAR2 (100);
        lv_transaction_date   DATE;
    BEGIN
        -- Function to fetch ledger id based on OU
        ln_ledger_id   := get_ledger_id (p_organization_id);

        IF ln_ledger_id IS NULL
        THEN
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                'Failed to fetch ledger id skpping GL Interface Insertion...');
        ELSE
            -- Function to get ledger currency
            lv_ledger_currency   := get_ledger_currency (ln_ledger_id);

            IF lv_ledger_currency IS NULL
            THEN
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                    'Failed to fetch ledger currency skpping GL Interface Insertion...');
            ELSE
                -- Function to get period name
                lv_period_name   :=
                    get_period_name (ln_ledger_id, p_transaction_date);

                IF (lv_period_name IS NULL)
                THEN
                    lv_transaction_date   := TRUNC (SYSDATE);
                    lv_period_name        :=
                        get_period_name (ln_ledger_id, lv_transaction_date);
                ELSE
                    lv_transaction_date   := p_transaction_date;
                END IF;

                IF lv_period_name IS NULL
                THEN
                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                        'Failed to fetch period name skpping GL Interface Insertion...');
                ELSE
                    --Function to get line type (Shipment/Return)
                    lv_order_line_type   := get_order_line_type (p_line_id);

                    IF lv_order_line_type IS NULL
                    THEN
                        FND_FILE.PUT_LINE (
                            FND_FILE.LOG,
                            'Failed to fetch order line type skpping GL Interface Insertion...');
                    ELSE
                        -- Procedure to get COGS account CCID Segments
                        get_cogs_ccid_segments_prc (p_line_id, ln_ledger_id, lv_cogs_segment1, lv_cogs_segment2, lv_cogs_segment3, lv_cogs_segment4, lv_cogs_segment5, lv_cogs_segment6, lv_cogs_segment7
                                                    , lv_cogs_segment8);

                        IF    lv_cogs_segment1 IS NULL
                           OR lv_cogs_segment2 IS NULL
                           OR lv_cogs_segment3 IS NULL
                           OR lv_cogs_segment4 IS NULL
                           OR lv_cogs_segment5 IS NULL
                           OR lv_cogs_segment6 IS NULL
                           OR lv_cogs_segment7 IS NULL
                           OR lv_cogs_segment8 IS NULL
                        THEN
                            FND_FILE.PUT_LINE (
                                FND_FILE.LOG,
                                'Failed to fetch COGS Account segments skpping GL Interface Insertion...');
                        ELSE
                            -- Function to get journal source
                            lv_journal_source   := get_journal_source;

                            IF lv_journal_source IS NULL
                            THEN
                                FND_FILE.PUT_LINE (
                                    FND_FILE.LOG,
                                    'Failed to fetch journal source skpping GL Interface Insertion...');
                            ELSE
                                -- Function to get journal category
                                lv_journal_category   := get_journal_category;

                                IF lv_journal_category IS NULL
                                THEN
                                    FND_FILE.PUT_LINE (
                                        FND_FILE.LOG,
                                        'Failed to fetch journal category skpping GL Interface Insertion...');
                                ELSE
                                    -- Function to get journal name
                                    lv_journal_name   :=
                                        get_journal_name (p_currency_code);

                                    IF lv_journal_name IS NULL
                                    THEN
                                        FND_FILE.PUT_LINE (
                                            FND_FILE.LOG,
                                            'Failed to fetch journal Name skpping GL Interface Insertion...');
                                    ELSE
                                        BEGIN
                                            -- Debit line insertion into GL Interface
                                            IF lv_order_line_type =
                                               'SHIPMENT'
                                            THEN
                                                -- For Shipments and for debit line
                                                -- IF value set segment is null insert cogs CCID segment else insert value set segment
                                                IF p_vs_segment1 = -1
                                                THEN
                                                    lv_segment1   :=
                                                        lv_cogs_segment1;
                                                ELSE
                                                    lv_segment1   :=
                                                        p_vs_segment1;
                                                END IF;

                                                IF p_vs_segment2 = -1
                                                THEN
                                                    lv_segment2   :=
                                                        lv_cogs_segment2;
                                                ELSE
                                                    lv_segment2   :=
                                                        p_vs_segment2;
                                                END IF;

                                                IF p_vs_segment3 = -1
                                                THEN
                                                    lv_segment3   :=
                                                        lv_cogs_segment3;
                                                ELSE
                                                    lv_segment3   :=
                                                        p_vs_segment3;
                                                END IF;

                                                IF p_vs_segment4 = -1
                                                THEN
                                                    lv_segment4   :=
                                                        lv_cogs_segment4;
                                                ELSE
                                                    lv_segment4   :=
                                                        p_vs_segment4;
                                                END IF;

                                                IF p_vs_segment5 = -1
                                                THEN
                                                    lv_segment5   :=
                                                        lv_cogs_segment5;
                                                ELSE
                                                    lv_segment5   :=
                                                        p_vs_segment5;
                                                END IF;

                                                IF p_vs_segment6 = -1
                                                THEN
                                                    BEGIN
                                                        SELECT NVL (ffvl.flex_value, lv_cogs_segment6)
                                                          INTO lv_segment6 -- Start changes for V1.2
                                                          FROM fnd_flex_value_sets ffv, fnd_flex_values_vl ffvl
                                                         WHERE     ffv.flex_value_set_name =
                                                                   'XXD_CAP_MARKUP_ACC_DEP_VS'
                                                               AND ffv.flex_value_set_id =
                                                                   ffvl.flex_value_set_id
                                                               AND SYSDATE BETWEEN NVL (
                                                                                       ffvl.start_date_active,
                                                                                       SYSDATE)
                                                                               AND NVL (
                                                                                       ffvl.end_date_active,
                                                                                         SYSDATE
                                                                                       + 1)
                                                               AND ffvl.enabled_flag =
                                                                   'Y'
                                                               AND parent_flex_value_low =
                                                                   lv_cogs_segment6;
                                                    EXCEPTION
                                                        WHEN OTHERS
                                                        THEN
                                                            lv_segment6   :=
                                                                lv_cogs_segment6;
                                                    END;
                                                --lv_segment6 := lv_cogs_segment6;
                                                ELSE
                                                    --lv_segment6 := p_vs_segment6;
                                                    BEGIN
                                                        SELECT NVL (FFVL.flex_value, p_vs_segment6)
                                                          INTO lv_segment6
                                                          FROM fnd_flex_value_sets ffv, fnd_flex_values_vl ffvl
                                                         WHERE     ffv.flex_value_set_name =
                                                                   'XXD_CAP_MARKUP_ACC_DEP_VS'
                                                               AND ffv.flex_value_set_id =
                                                                   ffvl.flex_value_set_id
                                                               AND SYSDATE BETWEEN NVL (
                                                                                       ffvl.start_date_active,
                                                                                       SYSDATE)
                                                                               AND NVL (
                                                                                       ffvl.end_date_active,
                                                                                         SYSDATE
                                                                                       + 1)
                                                               AND ffvl.enabled_flag =
                                                                   'Y'
                                                               AND parent_flex_value_low =
                                                                   lv_cogs_segment6;
                                                    EXCEPTION
                                                        WHEN OTHERS
                                                        THEN
                                                            lv_segment6   :=
                                                                p_vs_segment6;
                                                    END;
                                                END IF;

                                                -- End changes for V1.2
                                                IF p_vs_segment7 = -1
                                                THEN
                                                    lv_segment7   :=
                                                        lv_cogs_segment7;
                                                ELSE
                                                    lv_segment7   :=
                                                        p_vs_segment7;
                                                END IF;

                                                IF p_vs_segment8 = -1
                                                THEN
                                                    lv_segment8   :=
                                                        lv_cogs_segment8;
                                                ELSE
                                                    lv_segment8   :=
                                                        p_vs_segment8;
                                                END IF;
                                            ELSE --IF l_order_line_type = 'RETURN'
                                                -- For Returns and for debit line
                                                -- Insert cogs CCID segments
                                                lv_segment1   :=
                                                    lv_cogs_segment1;
                                                lv_segment2   :=
                                                    lv_cogs_segment2;
                                                lv_segment3   :=
                                                    lv_cogs_segment3;
                                                lv_segment4   :=
                                                    lv_cogs_segment4;
                                                lv_segment5   :=
                                                    lv_cogs_segment5;

                                                IF p_cogs_natural_account =
                                                   -1
                                                THEN
                                                    lv_segment6   :=
                                                        lv_cogs_segment6;
                                                ELSE
                                                    lv_segment6   :=
                                                        p_cogs_natural_account;
                                                END IF;

                                                -- lv_segment6 := lv_cogs_segment6;
                                                lv_segment7   :=
                                                    lv_cogs_segment7;
                                                lv_segment8   :=
                                                    lv_cogs_segment8;
                                            END IF;

                                            -- Insert the Debit line
                                            -- Start changes for V1.2
                                            -- INSERT INTO gl.gl_interface (
                                            INSERT INTO xxdo.xxd_gl_markup_cap_postgl_stg_t (
                                                            transaction_id, -- Added for V1.2
                                                            organization_id, -- Added for V1.2
                                                            request_id, -- Added for V1.2
                                                            status,
                                                            ledger_id,   -- 1d
                                                            accounting_date, --10
                                                            currency_code, --9
                                                            date_created,
                                                            created_by,
                                                            actual_flag,
                                                            reference10, --description--21
                                                            entered_dr,   --19
                                                            user_je_source_name, --2
                                                            user_je_category_name, --3
                                                            GROUP_ID,      --4
                                                            reference1, -- batch Name-- 5
                                                            reference4, -- journal_name -- 6
                                                            period_name,  -- 8
                                                            segment1,     --11
                                                            segment2,     --12
                                                            segment3,     --13
                                                            segment4,     --14
                                                            segment5,     --15
                                                            segment6,     --16
                                                            segment7,     --17
                                                            segment8,     --18
                                                            currency_conversion_date,
                                                            user_currency_conversion_type)
                                                     VALUES (
                                                                p_transaction_id,
                                                                p_organization_id,
                                                                gn_request_id,
                                                                'NEW',
                                                                ln_ledger_id,
                                                                lv_transaction_date, --p_transaction_date,
                                                                p_currency_code,
                                                                SYSDATE,
                                                                fnd_global.user_id,
                                                                'A',
                                                                lv_journal_name,
                                                                p_markup,
                                                                lv_journal_source,
                                                                lv_journal_category,
                                                                99089, --group_id
                                                                lv_journal_name, --batch_name
                                                                lv_journal_name, --journal_name
                                                                lv_period_name,
                                                                lv_segment1,
                                                                lv_segment2,
                                                                lv_segment3,
                                                                lv_segment4,
                                                                lv_segment5,
                                                                lv_segment6,
                                                                lv_segment7,
                                                                lv_segment8,
                                                                CASE
                                                                    WHEN p_currency_code <>
                                                                         lv_ledger_currency
                                                                    THEN
                                                                        lv_transaction_date --p_transaction_date
                                                                    ELSE
                                                                        NULL
                                                                END,
                                                                CASE
                                                                    WHEN p_currency_code <>
                                                                         lv_ledger_currency
                                                                    THEN
                                                                        NVL (
                                                                            p_conversion_type,
                                                                            'Spot')
                                                                    ELSE
                                                                        NULL
                                                                END);

                                            COMMIT;
                                            fnd_file.put_line (
                                                fnd_file.LOG,
                                                'Successfully inserted  debit record in GL Interface');
                                        EXCEPTION
                                            WHEN OTHERS
                                            THEN
                                                fnd_file.put_line (
                                                    fnd_file.LOG,
                                                       'Inserting debit line into GL Interface failed'
                                                    || SQLERRM);
                                        END;

                                        -- Inserting the credit line into gl_interface

                                        BEGIN
                                            -- Debit line insertion into GL Interface
                                            IF lv_order_line_type = 'RETURN'
                                            THEN
                                                -- For Returns and for credit line
                                                -- IF value set segment is null insert cogs CCID segment else insert value set segment
                                                IF p_vs_segment1 = -1
                                                THEN
                                                    lv_segment1   :=
                                                        lv_cogs_segment1;
                                                ELSE
                                                    lv_segment1   :=
                                                        p_vs_segment1;
                                                END IF;

                                                IF p_vs_segment2 = -1
                                                THEN
                                                    lv_segment2   :=
                                                        lv_cogs_segment2;
                                                ELSE
                                                    lv_segment2   :=
                                                        p_vs_segment2;
                                                END IF;

                                                IF p_vs_segment3 = -1
                                                THEN
                                                    lv_segment3   :=
                                                        lv_cogs_segment3;
                                                ELSE
                                                    lv_segment3   :=
                                                        p_vs_segment3;
                                                END IF;

                                                IF p_vs_segment4 = -1
                                                THEN
                                                    lv_segment4   :=
                                                        lv_cogs_segment4;
                                                ELSE
                                                    lv_segment4   :=
                                                        p_vs_segment4;
                                                END IF;

                                                IF p_vs_segment5 = -1
                                                THEN
                                                    lv_segment5   :=
                                                        lv_cogs_segment5;
                                                ELSE
                                                    lv_segment5   :=
                                                        p_vs_segment5;
                                                END IF;

                                                IF p_vs_segment6 = -1
                                                THEN
                                                    BEGIN
                                                        SELECT NVL (FFVL.flex_value, lv_cogs_segment6)
                                                          INTO lv_segment6 -- Added as part of CCR0010170
                                                          FROM fnd_flex_value_sets ffv, fnd_flex_values_vl ffvl
                                                         WHERE     ffv.flex_value_set_name =
                                                                   'XXD_CAP_MARKUP_ACC_DEP_VS'
                                                               AND ffv.flex_value_set_id =
                                                                   ffvl.flex_value_set_id
                                                               AND SYSDATE BETWEEN NVL (
                                                                                       ffvl.start_date_active,
                                                                                       SYSDATE)
                                                                               AND NVL (
                                                                                       ffvl.end_date_active,
                                                                                         SYSDATE
                                                                                       + 1)
                                                               AND ffvl.enabled_flag =
                                                                   'Y'
                                                               AND parent_flex_value_low =
                                                                   lv_cogs_segment6;
                                                    EXCEPTION
                                                        WHEN OTHERS
                                                        THEN
                                                            lv_segment6   :=
                                                                lv_cogs_segment6;
                                                    END;
                                                ELSE
                                                    --lv_segment6 := p_vs_segment6;
                                                    BEGIN
                                                        SELECT NVL (FFVL.flex_value, p_vs_segment6)
                                                          INTO lv_segment6
                                                          FROM fnd_flex_value_sets ffv, fnd_flex_values_vl ffvl
                                                         WHERE     ffv.flex_value_set_name =
                                                                   'XXD_CAP_MARKUP_ACC_DEP_VS'
                                                               AND ffv.flex_value_set_id =
                                                                   ffvl.flex_value_set_id
                                                               AND SYSDATE BETWEEN NVL (
                                                                                       ffvl.start_date_active,
                                                                                       SYSDATE)
                                                                               AND NVL (
                                                                                       ffvl.end_date_active,
                                                                                         SYSDATE
                                                                                       + 1)
                                                               AND ffvl.enabled_flag =
                                                                   'Y'
                                                               AND parent_flex_value_low =
                                                                   lv_cogs_segment6;
                                                    EXCEPTION
                                                        WHEN OTHERS
                                                        THEN
                                                            lv_segment6   :=
                                                                p_vs_segment6;
                                                    END;
                                                END IF;

                                                IF p_vs_segment7 = -1
                                                THEN
                                                    lv_segment7   :=
                                                        lv_cogs_segment7;
                                                ELSE
                                                    lv_segment7   :=
                                                        p_vs_segment7;
                                                END IF;

                                                IF p_vs_segment8 = -1
                                                THEN
                                                    lv_segment8   :=
                                                        lv_cogs_segment8;
                                                ELSE
                                                    lv_segment8   :=
                                                        p_vs_segment8;
                                                END IF;
                                            ELSE --IF l_order_line_type = 'SHIPMENT'
                                                -- For shipment and for credit line
                                                -- Insert cogs CCID segments
                                                lv_segment1   :=
                                                    lv_cogs_segment1;
                                                lv_segment2   :=
                                                    lv_cogs_segment2;
                                                lv_segment3   :=
                                                    lv_cogs_segment3;
                                                lv_segment4   :=
                                                    lv_cogs_segment4;
                                                lv_segment5   :=
                                                    lv_cogs_segment5;

                                                IF p_cogs_natural_account =
                                                   -1
                                                THEN
                                                    lv_segment6   :=
                                                        lv_cogs_segment6;
                                                ELSE
                                                    lv_segment6   :=
                                                        p_cogs_natural_account;
                                                END IF;

                                                --lv_segment6 := lv_cogs_segment6;
                                                lv_segment7   :=
                                                    lv_cogs_segment7;
                                                lv_segment8   :=
                                                    lv_cogs_segment8;
                                            END IF;

                                            -- Insert the Credit line

                                            --INSERT INTO gl.gl_interface (
                                            INSERT INTO xxdo.xxd_gl_markup_cap_postgl_stg_t (
                                                            transaction_id, -- Added for V1.2
                                                            organization_id, -- Added for V1.2
                                                            request_id, -- Added for V1.2
                                                            status,
                                                            ledger_id,    -- 1
                                                            accounting_date, --10
                                                            currency_code, --9
                                                            date_created,
                                                            created_by,
                                                            actual_flag,
                                                            reference10, --description--21
                                                            entered_cr,   --19
                                                            user_je_source_name, --2
                                                            user_je_category_name, --3
                                                            GROUP_ID,      --4
                                                            reference1, -- batch Name-- 5
                                                            reference4, -- journal_name -- 6
                                                            period_name,  -- 8
                                                            segment1,     --11
                                                            segment2,     --12
                                                            segment3,     --13
                                                            segment4,     --14
                                                            segment5,     --15
                                                            segment6,     --16
                                                            segment7,     --17
                                                            segment8,     --18
                                                            currency_conversion_date,
                                                            user_currency_conversion_type)
                                                     VALUES (
                                                                p_transaction_id,
                                                                p_organization_id,
                                                                gn_request_id,
                                                                'NEW',
                                                                ln_ledger_id,
                                                                lv_transaction_date, -- p_transaction_date,
                                                                p_currency_code,
                                                                SYSDATE,
                                                                fnd_global.user_id,
                                                                'A',
                                                                lv_journal_name,
                                                                p_markup,
                                                                lv_journal_source,
                                                                lv_journal_category,
                                                                99089, --group_id
                                                                lv_journal_name, --batch_name
                                                                lv_journal_name, --journal_name
                                                                lv_period_name,
                                                                lv_segment1,
                                                                lv_segment2,
                                                                lv_segment3,
                                                                lv_segment4,
                                                                lv_segment5,
                                                                lv_segment6,
                                                                lv_segment7,
                                                                lv_segment8,
                                                                CASE
                                                                    WHEN p_currency_code <>
                                                                         lv_ledger_currency
                                                                    THEN
                                                                        lv_transaction_date --p_transaction_date
                                                                    ELSE
                                                                        NULL
                                                                END,
                                                                CASE
                                                                    WHEN p_currency_code <>
                                                                         lv_ledger_currency
                                                                    THEN
                                                                        NVL (
                                                                            p_conversion_type,
                                                                            'Spot')
                                                                    ELSE
                                                                        NULL
                                                                END);

                                            COMMIT;
                                            fnd_file.put_line (
                                                fnd_file.LOG,
                                                'Successfully inserted  credit record in GL Interface');

                                            -- Update the attribute15(Gl Interface inserted flag) in mtl_material_transactions
                                            BEGIN
                                                UPDATE mtl_material_transactions
                                                   SET attribute15 = 'Y', last_update_date = SYSDATE, last_updated_by = gn_user_id
                                                 WHERE transaction_id =
                                                       p_transaction_id;

                                                COMMIT;
                                                fnd_file.put_line (
                                                    fnd_file.LOG,
                                                       'Updation of attribute15-GL Interface inserted flag success for transaction_id:'
                                                    || p_transaction_id);
                                            EXCEPTION
                                                WHEN OTHERS
                                                THEN
                                                    fnd_file.put_line (
                                                        fnd_file.LOG,
                                                           'Updation of attribute15-GL Interface inserted flag failed for transaction_id:'
                                                        || p_transaction_id
                                                        || '-'
                                                        || SQLERRM);
                                            END;
                                        EXCEPTION
                                            WHEN OTHERS
                                            THEN
                                                fnd_file.put_line (
                                                    fnd_file.LOG,
                                                       'Inserting credit line into GL Interface failed'
                                                    || SQLERRM);
                                        END;
                                    END IF;       --IF lv_journal_name IS NULL
                                END IF;       --IF lv_journal_category IS NULL
                            END IF;             --IF lv_journal_source IS NULL
                        END IF;                 -- IF lv_cogs_segment1 IS NULL
                    END IF;                    --IF lv_order_line_type IS NULL
                END IF;                            --IF lv_period_name IS NULL
            END IF;                            --IF lv_ledger_currency IS NULL
        END IF;                                      --IF ln_ledger_id IS NULL
    EXCEPTION
        WHEN OTHERS
        THEN
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                'Failed to insert the data into Gl Interface...' || SQLERRM);
    END insert_gl_data;

    -- START chnages for V1.2
    /***********************************************************************************************
    ************************** Procedure to Insert into GL_INTERFACE *******************************
    ************************************************************************************************/
    PROCEDURE populate_gl_int
    IS
        CURSOR gl_intf_cr_data IS
              SELECT status, ledger_id,                                   -- 1
                                        TRUNC (accounting_date) accounting_date, --10
                     currency_code,                                        --9
                                    TRUNC (date_created) date_created, created_by,
                     actual_flag, reference10,               --description--21
                                               SUM (entered_cr) entered_cr, --19
                     user_je_source_name,                                  --2
                                          user_je_category_name,           --3
                                                                 GROUP_ID, --4
                     reference1,                             -- batch Name-- 5
                                 reference4,              -- journal_name -- 6
                                             period_name,                 -- 8
                     segment1,                                            --11
                               segment2,                                  --12
                                         segment3,                        --13
                     segment4,                                            --14
                               segment5,                                  --15
                                         segment6,                        --16
                     segment7,                                            --17
                               segment8,                                  --18
                                         TRUNC (currency_conversion_date) currency_conversion_date,
                     user_currency_conversion_type
                FROM xxd_gl_markup_cap_postgl_stg_t
               WHERE     1 = 1
                     AND request_id = gn_request_id
                     AND entered_cr IS NOT NULL
            GROUP BY status, ledger_id,                                   -- 1
                                        TRUNC (accounting_date),          --10
                     currency_code,                                        --9
                                    TRUNC (date_created), created_by,
                     actual_flag, reference10,               --description--21
                                               user_je_source_name,        --2
                     user_je_category_name,                                --3
                                            GROUP_ID,                      --4
                                                      reference1, -- batch Name-- 5
                     reference4,                          -- journal_name -- 6
                                 period_name,                             -- 8
                                              segment1,                   --11
                     segment2,                                            --12
                               segment3,                                  --13
                                         segment4,                        --14
                     segment5,                                            --15
                               segment6,                                  --16
                                         segment7,                        --17
                     segment8,                                            --18
                               TRUNC (currency_conversion_date), user_currency_conversion_type;

        CURSOR gl_intf_dr_data IS
              SELECT status, ledger_id,                                   -- 1
                                        TRUNC (accounting_date) accounting_date, --10
                     currency_code,                                        --9
                                    TRUNC (date_created) date_created, created_by,
                     actual_flag, reference10,               --description--21
                                               SUM (entered_dr) entered_dr, --19
                     user_je_source_name,                                  --2
                                          user_je_category_name,           --3
                                                                 GROUP_ID, --4
                     reference1,                             -- batch Name-- 5
                                 reference4,              -- journal_name -- 6
                                             period_name,                 -- 8
                     segment1,                                            --11
                               segment2,                                  --12
                                         segment3,                        --13
                     segment4,                                            --14
                               segment5,                                  --15
                                         segment6,                        --16
                     segment7,                                            --17
                               segment8,                                  --18
                                         TRUNC (currency_conversion_date) currency_conversion_date,
                     user_currency_conversion_type
                FROM xxd_gl_markup_cap_postgl_stg_t
               WHERE     1 = 1
                     AND request_id = gn_request_id
                     AND entered_dr IS NOT NULL
            GROUP BY status, ledger_id,                                   -- 1
                                        TRUNC (accounting_date),          --10
                     currency_code,                                        --9
                                    TRUNC (date_created), created_by,
                     actual_flag, reference10,               --description--21
                                               user_je_source_name,        --2
                     user_je_category_name,                                --3
                                            GROUP_ID,                      --4
                                                      reference1, -- batch Name-- 5
                     reference4,                          -- journal_name -- 6
                                 period_name,                             -- 8
                                              segment1,                   --11
                     segment2,                                            --12
                               segment3,                                  --13
                                         segment4,                        --14
                     segment5,                                            --15
                               segment6,                                  --16
                                         segment7,                        --17
                     segment8,                                            --18
                               TRUNC (currency_conversion_date), user_currency_conversion_type;

        ln_count             NUMBER := 0;
        ln_count1            NUMBER := 0;
        lv_ledger_currency   VARCHAR2 (10);
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Populate GL Interface');

        FOR gl_intf_data_dr_rec IN gl_intf_dr_data
        LOOP
            IF NVL (gl_intf_data_dr_rec.entered_dr, 0) <> 0
            THEN
                ln_count1   := ln_count1 + 1;

                INSERT INTO gl.gl_interface (status, ledger_id,           -- 1
                                                                accounting_date, --10
                                                                                 currency_code, --9
                                                                                                date_created, created_by, actual_flag, reference10, --description--21
                                                                                                                                                    entered_dr, --19
                                                                                                                                                                user_je_source_name, --2
                                                                                                                                                                                     user_je_category_name, --3
                                                                                                                                                                                                            GROUP_ID, --4
                                                                                                                                                                                                                      reference1, -- batch Name-- 5
                                                                                                                                                                                                                                  reference4, -- journal_name -- 6
                                                                                                                                                                                                                                              period_name, -- 8
                                                                                                                                                                                                                                                           segment1, --11
                                                                                                                                                                                                                                                                     segment2, --12
                                                                                                                                                                                                                                                                               segment3, --13
                                                                                                                                                                                                                                                                                         segment4, --14
                                                                                                                                                                                                                                                                                                   segment5, --15
                                                                                                                                                                                                                                                                                                             segment6, --16
                                                                                                                                                                                                                                                                                                                       segment7, --17
                                                                                                                                                                                                                                                                                                                                 segment8, --18
                                                                                                                                                                                                                                                                                                                                           currency_conversion_date
                                             , user_currency_conversion_type)
                         VALUES (
                                    'NEW',
                                    gl_intf_data_dr_rec.ledger_id,
                                    gl_intf_data_dr_rec.accounting_date, -- p_transaction_date,
                                    gl_intf_data_dr_rec.currency_code,
                                    SYSDATE,
                                    fnd_global.user_id,
                                    'A',
                                    gl_intf_data_dr_rec.reference10,
                                    gl_intf_data_dr_rec.entered_dr,
                                    gl_intf_data_dr_rec.user_je_source_name,
                                    gl_intf_data_dr_rec.user_je_category_name,
                                    99089,                          --group_id
                                    gl_intf_data_dr_rec.reference1, --batch_name
                                    gl_intf_data_dr_rec.reference4, --journal_name
                                    gl_intf_data_dr_rec.period_name,
                                    gl_intf_data_dr_rec.segment1,
                                    gl_intf_data_dr_rec.segment2,
                                    gl_intf_data_dr_rec.segment3,
                                    gl_intf_data_dr_rec.segment4,
                                    gl_intf_data_dr_rec.segment5,
                                    gl_intf_data_dr_rec.segment6,
                                    gl_intf_data_dr_rec.segment7,
                                    gl_intf_data_dr_rec.segment8,
                                    gl_intf_data_dr_rec.currency_conversion_date,
                                    gl_intf_data_dr_rec.user_currency_conversion_type);
            END IF;
        END LOOP;

        FOR gl_intf_data_cr_rec IN gl_intf_cr_data
        LOOP
            IF NVL (gl_intf_data_cr_rec.entered_cr, 0) <> 0
            THEN
                ln_count   := ln_count + 1;

                INSERT INTO gl.gl_interface (status, ledger_id,          -- 1d
                                                                accounting_date, --10
                                                                                 currency_code, --9
                                                                                                date_created, created_by, actual_flag, reference10, --description--21
                                                                                                                                                    entered_cr, -- 19
                                                                                                                                                                user_je_source_name, --2
                                                                                                                                                                                     user_je_category_name, --3
                                                                                                                                                                                                            GROUP_ID, --4
                                                                                                                                                                                                                      reference1, -- batch Name-- 5
                                                                                                                                                                                                                                  reference4, -- journal_name -- 6
                                                                                                                                                                                                                                              period_name, -- 8
                                                                                                                                                                                                                                                           segment1, --11
                                                                                                                                                                                                                                                                     segment2, --12
                                                                                                                                                                                                                                                                               segment3, --13
                                                                                                                                                                                                                                                                                         segment4, --14
                                                                                                                                                                                                                                                                                                   segment5, --15
                                                                                                                                                                                                                                                                                                             segment6, --16
                                                                                                                                                                                                                                                                                                                       segment7, --17
                                                                                                                                                                                                                                                                                                                                 segment8, --18
                                                                                                                                                                                                                                                                                                                                           currency_conversion_date
                                             , user_currency_conversion_type)
                         VALUES (
                                    'NEW',
                                    gl_intf_data_cr_rec.ledger_id,
                                    gl_intf_data_cr_rec.accounting_date, --p_transaction_date,
                                    gl_intf_data_cr_rec.currency_code,
                                    SYSDATE,
                                    fnd_global.user_id,
                                    'A',
                                    gl_intf_data_cr_rec.reference10,
                                    gl_intf_data_cr_rec.entered_cr,  -- Credit
                                    gl_intf_data_cr_rec.user_je_source_name,
                                    gl_intf_data_cr_rec.user_je_category_name,
                                    99089,                          --group_id
                                    gl_intf_data_cr_rec.reference1, --batch_name
                                    gl_intf_data_cr_rec.reference4, --journal_name
                                    gl_intf_data_cr_rec.period_name,
                                    gl_intf_data_cr_rec.segment1,
                                    gl_intf_data_cr_rec.segment2,
                                    gl_intf_data_cr_rec.segment3,
                                    gl_intf_data_cr_rec.segment4,
                                    gl_intf_data_cr_rec.segment5,
                                    gl_intf_data_cr_rec.segment6,
                                    gl_intf_data_cr_rec.segment7,
                                    gl_intf_data_cr_rec.segment8,
                                    gl_intf_data_cr_rec.currency_conversion_date,
                                    gl_intf_data_cr_rec.user_currency_conversion_type);
            END IF;
        END LOOP;

        fnd_file.put_line (
            fnd_file.LOG,
            'Successfully inserted  credit record in GL Interface');
        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Error in POPULATE_GL_INT:' || SQLERRM);
    END populate_gl_int;

    -- END Changes for V1.2
    /***********************************************************************************************
    ************************************* Main Procedure *******************************************
    ************************************************************************************************/

    PROCEDURE main (p_errbuf OUT VARCHAR2, p_retcode OUT NUMBER, p_inventory_org IN NUMBER, p_org_id IN NUMBER, p_date_from IN VARCHAR2, p_date_to IN VARCHAR2, --p_transaction_id              IN   NUMBER,--1.1
                                                                                                                                                                p_from_transaction_id IN NUMBER, --1.1
                                                                                                                                                                                                 p_to_transaction_id IN NUMBER, --1.1
                                                                                                                                                                                                                                p_material_transaction_type IN NUMBER, p_reprocess IN VARCHAR2, -- 1.1
                                                                                                                                                                                                                                                                                                P_Enable_Recalculate IN VARCHAR2, p_recalculate IN VARCHAR2
                    ,                                                    --1.1
                      p_calc_currency IN VARCHAR2,           -- Added for V1.2
                                                   p_rate_type IN VARCHAR2 -- Added for V1.2
                                                                          )
    AS
        ln_material_cost               NUMBER := 0;
        ln_material_cost_fact          NUMBER := 0;
        ln_duty                        NUMBER := 0;
        ln_duty_fct                    NUMBER := 0;
        ln_overhead_with_duty          NUMBER := 0;
        ln_overhead_with_duty_fact     NUMBER := 0;
        in_freight_with_duty           NUMBER := 0;
        ln_freight_with_duty_fct       NUMBER := 0;
        ln_freight_without_duty        NUMBER := 0;
        ln_freight_without_duty_fct    NUMBER := 0;
        ln_overhead_without_duty       NUMBER := 0;
        ln_overhead_without_duty_fct   NUMBER := 0;
        ln_markup                      NUMBER := 0;
        ln_item_list_price             NUMBER := 0;
        ln_exchange_rate               NUMBER := 0;
        ln_ship_from_org_id            NUMBER := 0;
        ln_avg_mrgn_cst_usd            NUMBER := 0;
        ln_record_count                NUMBER := 0;
        lv_status                      VARCHAR2 (10) := NULL;

        --        lv_org_id                      NUMBER;
        TYPE generic_rc IS REF CURSOR;

        transactions_to_update         generic_rc;
        lv_sql_statement               VARCHAR2 (32767);

        TYPE rec_transactions
            IS RECORD
        (
            transaction_id             mtl_material_transactions.transaction_id%TYPE,
            transaction_type_name      mtl_transaction_types.transaction_type_name%TYPE,
            inventory_item_id          mtl_material_transactions.inventory_item_id%TYPE,
            organization_id            mtl_material_transactions.organization_id%TYPE,
            currency_code              oe_order_headers_all.transactional_curr_code%TYPE,
            transaction_date           mtl_material_transactions.transaction_date%TYPE,
            order_number               oe_order_headers_all.order_number%TYPE,
            brand                      VARCHAR2 (50),
            order_type_id              oe_order_headers_all.order_type_id%TYPE,
            ship_to_orgn_id            oe_order_headers_all.order_type_id%TYPE,
            shipfrom_invorgid          oe_order_headers_all.order_type_id%TYPE,
            shipto_invorgid            oe_order_headers_all.order_type_id%TYPE,
            line_id                    oe_order_lines_all.line_id%TYPE,
            order_source               oe_order_sources.name%TYPE,
            vs_org_id                  VARCHAR2 (50),
            markup_type                VARCHAR2 (50),
            vs_company                 VARCHAR2 (50),
            vs_brand                   VARCHAR2 (50),
            vs_geo                     VARCHAR2 (50),
            vs_channel                 VARCHAR2 (50),
            vs_cost_centre             VARCHAR2 (50),
            vs_natural_account         VARCHAR2 (50),
            vs_inter_company           VARCHAR2 (50),
            vs_post_to_gl              VARCHAR2 (50),
            vs_future_use              VARCHAR2 (50),
            conversion_type            VARCHAR2 (50),
            vs_cogs_natural_account    VARCHAR2 (50),
            mmt_markup                 VARCHAR2 (50),                    --1.1
            transaction_quantity       NUMBER
        );

        i                              rec_transactions;
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
            'Deckers CM Capture Markup and Post to GL Program starts here...');
        fnd_file.put_line (
            fnd_file.LOG,
            'Program parameters Are...................................');
        fnd_file.put_line (
            fnd_file.LOG,
            '---------------------------------------------------------');
        fnd_file.put_line (
            fnd_file.LOG,
            'p_inventory_org             :' || p_inventory_org);
        fnd_file.put_line (fnd_file.LOG,
                           'p_org_id                    :' || p_org_id);
        fnd_file.put_line (fnd_file.LOG,
                           'p_date_from                 :' || p_date_from);
        fnd_file.put_line (fnd_file.LOG,
                           'p_date_to                   :' || p_date_to);
        --1.1 changes start
        --fnd_file.put_line(fnd_file.log, 'p_transaction_id            :'||p_transaction_id);
        fnd_file.put_line (
            fnd_file.LOG,
            'p_from_transaction_id       :' || p_from_transaction_id);
        fnd_file.put_line (
            fnd_file.LOG,
            'p_to_transaction_id         :' || p_to_transaction_id);
        --1.1 changes end
        fnd_file.put_line (
            fnd_file.LOG,
            'p_material_transaction_type :' || p_material_transaction_type);
        fnd_file.put_line (fnd_file.LOG,
                           'p_reprocess                 :' || p_reprocess); --1.1
        fnd_file.put_line (fnd_file.LOG,
                           'p_recalculate               :' || p_recalculate); --1.1

        IF p_from_transaction_id IS NULL AND p_to_transaction_id IS NOT NULL
        THEN
            FND_FILE.PUT_LINE (FND_FILE.LOG, '');
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'Please enter p_from_transaction_id');
            p_retcode   := 2;
            RETURN;
        END IF;

        IF p_from_transaction_id < 956595852
        THEN
            FND_FILE.PUT_LINE (FND_FILE.LOG, '');
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                'Please enter p_from_transaction_id Greater than or equal to 956595852');
            p_retcode   := 2;
            RETURN;
        END IF;

        -- START changes for V1.2
        gv_calc_currency   := p_calc_currency;
        gv_rate_type       := p_rate_type;

        DELETE FROM XXDO.XXD_GL_MARKUP_CAP_POSTGL_STG_T;

        COMMIT;

        -- END changes for V1.2
        -- Ref Cursor to get the eligible records
        IF NVL (p_reprocess, 'N') = 'N'
        THEN                                                             --1.1
            FOR rec_orgs
                IN (SELECT DISTINCT org_id
                      FROM OE_ORDER_lines_ALL
                     WHERE     ship_from_org_id =
                               NVL (p_inventory_org, ship_from_org_id)   --955
                           AND org_id = NVL (p_org_id, org_id))
            LOOP
                lv_sql_statement   :=
                       'SELECT
        /*+ use_nl leading (mmt) parallel(4) */
            mmt.transaction_id,
            mtt.transaction_type_name,
            mmt.inventory_item_id,
            mmt.organization_id,
            ooha.transactional_curr_code currency_code,
            mmt.transaction_date,
            ooha.order_number,
            ooha.attribute5         brand,
            ooha.order_type_id,
            ooha.org_id             ship_to_orgn_id,
            ooha.ship_from_org_id   shipfrom_invorgid,
            ooha.ship_to_org_id     shipto_invorgid,
            oola.line_id,
            oos.name                order_source,
            markup.vs_org_id,
            markup.markup_type,
            markup.vs_company,
            markup.vs_brand,
            markup.vs_geo,
            markup.vs_channel,
            markup.vs_cost_centre,
            markup.vs_natural_account,
            markup.vs_inter_company,
            markup.vs_post_to_gl,
			markup.vs_future_use,
			markup.conversion_type,
			markup.vs_cogs_natural_account	,
            NULL mmt_markup	,
            mmt.transaction_quantity 			
        FROM
            mtl_material_transactions   mmt,
            mtl_transaction_types       mtt,
            oe_order_headers_all        ooha,
            oe_order_lines_all          oola,
            oe_order_sources            oos,
            (
                SELECT
                    attribute1   vs_org_id,
                    attribute2   markup_type,
                    nvl(attribute3,'
                    || '''-1'''
                    || ') vs_company,
                    nvl(attribute4,'
                    || '''-1'''
                    || ') vs_brand,
                    nvl(attribute5,'
                    || '''-1'''
                    || ') vs_geo,
                    nvl(attribute6,'
                    || '''-1'''
                    || ') vs_channel,
                    nvl(attribute7,'
                    || '''-1'''
                    || ') vs_cost_centre,
                    nvl(attribute8,'
                    || '''-1'''
                    || ') vs_natural_account,
                    nvl(attribute9,'
                    || '''-1'''
                    || ') vs_inter_company,
                    nvl(attribute10,'
                    || '''N'''
                    || ') vs_post_to_gl,
					NVL(attribute11,'
                    || '''-1'''
                    || ') vs_future_use,
                    attribute12 cutoff_transaction_id,
                    attribute13 conversion_type,
                    NVL(attribute14,'
                    || '''-1'''
                    || ') vs_cogs_natural_account					
                FROM
                    apps.fnd_flex_value_sets   ffvs,
                    apps.fnd_flex_values_vl    ffvl
                WHERE
                    1 = 1
                    AND ffvs.flex_value_set_name ='
                    || '''XXD_CM_CAPTURE_MARGINS_VS'''
                    || ' '
                    || 'AND ffvs.flex_value_set_id = ffvl.flex_value_set_id
                    AND nvl(ffvl.enabled_flag,'
                    || '''Y'''
                    || ') ='
                    || '''Y'''
                    || ' '
                    || 'AND nvl(trunc(ffvl.start_date_active), trunc(SYSDATE)) <= trunc(SYSDATE)
                    AND nvl(trunc(ffvl.end_date_active), trunc(SYSDATE)) >= trunc(SYSDATE)
            ) markup
        WHERE
            mmt.transaction_type_id = mtt.transaction_type_id
            AND mmt.trx_source_line_id = oola.line_id
			AND mmt.inventory_item_id = oola.inventory_item_id
            AND oola.header_id = ooha.header_id
            AND ooha.order_source_id = oos.order_source_id
            AND oos.name NOT IN (SELECT
                                    source
                                FROM
                                TABLE ( xxd_gl_markup_cap_postgl_pkg.get_source_val_fnc ))
            AND mmt.costed_flag IS NULL
            AND transaction_type_name IN ('
                    || '''Sales order issue'''
                    || ','
                    || '''RMA Receipt'''
                    || ')
            AND markup.vs_org_id = ooha.org_id	';

                --            'AND oola.ship_from_org_id = '
                --   ||p_inventory_org;

                IF p_inventory_org IS NOT NULL
                THEN
                    lv_sql_statement   :=
                           lv_sql_statement
                        || ' AND oola.ship_from_org_id = '
                        || p_inventory_org;
                END IF;

                IF p_org_id IS NOT NULL
                THEN
                    lv_sql_statement   :=
                        lv_sql_statement || ' AND ooha.org_id = ' || p_org_id;
                ELSE
                    lv_sql_statement   :=
                           lv_sql_statement
                        || ' AND ooha.org_id='
                        || rec_orgs.org_id;
                END IF;

                IF p_date_from IS NOT NULL
                THEN
                    lv_sql_statement   :=
                           lv_sql_statement
                        || ' AND trunc(mmt.transaction_date)>=TO_DATE('''
                        || p_date_from
                        || ''',''YYYY/MM/DD HH24:MI:SS'')';
                END IF;

                IF p_date_to IS NOT NULL
                THEN
                    lv_sql_statement   :=
                           lv_sql_statement
                        || ' AND trunc(mmt.transaction_date)<=TO_DATE('''
                        || p_date_to
                        || ''',''YYYY/MM/DD HH24:MI:SS'')';
                END IF;

                --1.1 changes start
                IF     p_from_transaction_id IS NULL
                   AND p_to_transaction_id IS NULL
                THEN                                                     --1.1
                    lv_sql_statement   :=
                           lv_sql_statement
                        || ' AND mmt.transaction_id >= to_number(markup.cutoff_transaction_id)';
                ELSIF     p_from_transaction_id IS NOT NULL
                      AND p_to_transaction_id IS NULL
                THEN
                    lv_sql_statement   :=
                           lv_sql_statement
                        || ' AND mmt.transaction_id > '
                        || p_from_transaction_id;
                ELSIF     p_from_transaction_id IS NOT NULL
                      AND p_to_transaction_id IS NOT NULL
                THEN
                    lv_sql_statement   :=
                           lv_sql_statement
                        || ' AND mmt.transaction_id >= '
                        || p_from_transaction_id
                        || ' AND mmt.transaction_id <= '
                        || p_to_transaction_id;
                END IF;

                -- 1.1 changes end
                IF p_material_transaction_type IS NOT NULL
                THEN
                    lv_sql_statement   :=
                           lv_sql_statement
                        || ' AND mtt.transaction_type_id = '
                        || p_material_transaction_type;
                END IF;

                --1.1 changes start
                IF NVL (p_recalculate, 'N') = 'N'
                THEN
                    lv_sql_statement   :=
                           lv_sql_statement
                        || ' AND mmt.attribute14 IS NULL -- Markup
			AND mmt.attribute15 IS NULL';                  -- Gl Interface inserted flag
                ELSIF NVL (p_recalculate, 'N') = 'Y'
                THEN
                    lv_sql_statement   :=
                           lv_sql_statement
                        || '	AND mmt.attribute14 IS NOT NULL';       -- Markup
                END IF;

                --1.1 changes end

                fnd_file.put_line (fnd_file.LOG, ' SQL ' || lv_sql_statement);
                --        lv_org_id:=NULL;

                --   lv_org_id:=rec_orgs.org_id;
                fnd_file.put_line (fnd_file.LOG,
                                   ' lv_org_id Value ' || lv_org_id);

                OPEN transactions_to_update FOR lv_sql_statement;

                LOOP
                    FETCH transactions_to_update INTO i;

                    EXIT WHEN transactions_to_update%NOTFOUND;

                    ln_record_count   := ln_record_count + 1;

                    IF i.markup_type = 'On-hand Markup'
                    THEN
                        ln_avg_mrgn_cst_usd   :=
                            get_onhand_avg_margin (i.shipfrom_invorgid,
                                                   i.inventory_item_id,
                                                   i.transaction_date);
                        FND_FILE.PUT_LINE (
                            FND_FILE.LOG,
                               'Average Margin for On-hand Markup IS:'
                            || ln_avg_mrgn_cst_usd);

                        IF ln_avg_mrgn_cst_usd IS NULL
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Failed to get on-hand Markup for Transaction id:'
                                || i.transaction_id);

                            BEGIN
                                UPDATE mtl_material_transactions
                                   SET attribute14 = 'NA', last_update_date = SYSDATE, last_updated_by = gn_user_id
                                 WHERE transaction_id = i.transaction_id;

                                COMMIT;
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Updation of attribute15-GL Interface inserted flag success for transaction_id:'
                                    || i.transaction_id);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Updation of attribute15-GL Interface inserted flag failed for transaction_id:'
                                        || i.transaction_id
                                        || '-'
                                        || SQLERRM);
                            END;
                        ELSE
                            lv_status   :=
                                update_mmt_attr_fun (ln_avg_mrgn_cst_usd,
                                                     i.transaction_id);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Average Margin before multiply with quantity:'
                                || ln_avg_mrgn_cst_usd);
                            -- multiply the average margin with transaction quantity while posting
                            ln_avg_mrgn_cst_usd   :=
                                  NVL (ln_avg_mrgn_cst_usd, 0)
                                * ABS (NVL (i.transaction_quantity, 1));
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Transaction quantity :' || i.transaction_quantity);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Average Margin After multiply with quantity:'
                                || ln_avg_mrgn_cst_usd);
                        END IF;
                    ELSE
                        ln_avg_mrgn_cst_usd   :=
                            get_direct_markup (i.transaction_id);
                        FND_FILE.PUT_LINE (
                            FND_FILE.LOG,
                               'Average Margin for Direct Markup IS:'
                            || ln_avg_mrgn_cst_usd);

                        IF ln_avg_mrgn_cst_usd IS NULL
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Failed to get Direct Markup for Transaction id:'
                                || i.transaction_id);

                            BEGIN
                                UPDATE mtl_material_transactions
                                   SET attribute14 = 'NA', last_update_date = SYSDATE, last_updated_by = gn_user_id
                                 WHERE transaction_id = i.transaction_id;

                                COMMIT;
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Updation of attribute15-GL Interface inserted flag success for transaction_id:'
                                    || i.transaction_id);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Updation of attribute15-GL Interface inserted flag failed for transaction_id:'
                                        || i.transaction_id
                                        || '-'
                                        || SQLERRM);
                            END;
                        ELSE
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Average Margin for Direct Markup:'
                                || ln_avg_mrgn_cst_usd);
                            lv_status   :=
                                update_mmt_attr_fun (ln_avg_mrgn_cst_usd,
                                                     i.transaction_id);
                        END IF;
                    END IF;                                   --IF markup_type

                    IF NVL (lv_status, 'X') = 'E'
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Failed to update the Average Markup Cost for Transaction id:'
                            || i.transaction_id);
                    ELSIF     NVL (lv_status, 'X') = 'S'
                          AND NVL (i.vs_post_to_gl, 'N') = 'N'
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Post to Gl in the value set marked as No for this OU...Record will not be inserted into GL Interface');

                        BEGIN
                            UPDATE mtl_material_transactions
                               SET attribute15 = 'N', -- inserting into GL interface set as N in value set
                                                      last_update_date = SYSDATE, last_updated_by = gn_user_id
                             WHERE transaction_id = i.transaction_id;

                            COMMIT;
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Updation of attribute15-GL Interface inserted flag success for transaction_id:'
                                || i.transaction_id);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Updation of attribute15-GL Interface inserted flag failed for transaction_id:'
                                    || i.transaction_id
                                    || '-'
                                    || SQLERRM);
                        END;
                    ELSIF     NVL (lv_status, 'X') = 'S'
                          AND NVL (i.vs_post_to_gl, 'N') = 'Y'
                          AND ln_avg_mrgn_cst_usd <= 0
                    THEN                                   --1.1 changes start
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Markup value is zero or less than zero for transaction_id:'
                            || i.transaction_id
                            || '-'
                            || 'Skipping the GL insertion ');

                        BEGIN
                            UPDATE mtl_material_transactions
                               SET attribute15 = 'NA', -- inserting into GL interface set as N in value set
                                                       last_update_date = SYSDATE, last_updated_by = gn_user_id
                             WHERE transaction_id = i.transaction_id;

                            COMMIT;
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Updation of attribute15-GL Interface inserted flag success for transaction_id:'
                                || i.transaction_id);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Updation of attribute15-GL Interface inserted flag failed for transaction_id:'
                                    || i.transaction_id
                                    || '-'
                                    || SQLERRM);
                        END;
                    --1.1 changes end
                    ELSIF     NVL (lv_status, 'X') = 'S'
                          AND NVL (i.vs_post_to_gl, 'N') = 'Y'
                          AND ln_avg_mrgn_cst_usd > 0
                    THEN                                               --1 1.1
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Post to Gl in the value set marked as Yes for this OU...Record will be inserted into GL Interface');
                        insert_gl_data (i.currency_code,
                                        i.ship_to_orgn_id,
                                        i.shipfrom_invorgid,
                                        i.transaction_date,
                                        ln_avg_mrgn_cst_usd,
                                        i.line_id,
                                        i.vs_company,
                                        i.vs_brand,
                                        i.vs_geo,
                                        i.vs_channel,
                                        i.vs_cost_centre,
                                        i.vs_natural_account,
                                        i.vs_inter_company,
                                        i.vs_future_use,
                                        i.transaction_id,
                                        i.conversion_type,
                                        i.vs_cogs_natural_account);
                    END IF;
                END LOOP;
            END LOOP;

            IF ln_record_count = 0
            THEN
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                    'There is no eligible records for the Given parameters');
            END IF;

            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'SQL Statement:' || lv_sql_statement);
            populate_gl_int;                                 -- Added for V1.2
        --1.1 changes start
        ELSIF NVL (p_reprocess, 'N') = 'Y'
        THEN
            FOR rec_orgs
                IN (SELECT DISTINCT org_id
                      FROM OE_ORDER_lines_ALL
                     WHERE     ship_from_org_id =
                               NVL (p_inventory_org, ship_from_org_id)   --955
                           AND org_id = NVL (p_org_id, org_id))
            LOOP
                lv_sql_statement   :=
                       'SELECT
       /*+ use_nl leading (mmt) parallel(4) */
            mmt.transaction_id,
            mtt.transaction_type_name,
            mmt.inventory_item_id,
            mmt.organization_id,
            ooha.transactional_curr_code currency_code,
            mmt.transaction_date,
            ooha.order_number,
            ooha.attribute5         brand,
            ooha.order_type_id,
            ooha.org_id             ship_to_orgn_id,
            ooha.ship_from_org_id   shipfrom_invorgid,
            ooha.ship_to_org_id     shipto_invorgid,
            oola.line_id,
            oos.name                order_source,
            markup.vs_org_id,
            markup.markup_type,
            markup.vs_company,
            markup.vs_brand,
            markup.vs_geo,
            markup.vs_channel,
            markup.vs_cost_centre,
            markup.vs_natural_account,
            markup.vs_inter_company,
            markup.vs_post_to_gl,
			markup.vs_future_use,
			markup.conversion_type,
			markup.vs_cogs_natural_account,
			mmt.attribute14 mmt_markup, -- 1.1
			mmt.transaction_quantity
        FROM
            mtl_material_transactions   mmt,
            mtl_transaction_types       mtt,
            oe_order_headers_all        ooha,
            oe_order_lines_all          oola,
            oe_order_sources            oos,
            (
                SELECT
                    attribute1   vs_org_id,
                    attribute2   markup_type,
                    nvl(attribute3,'
                    || '''-1'''
                    || ') vs_company,
                    nvl(attribute4,'
                    || '''-1'''
                    || ') vs_brand,
                    nvl(attribute5,'
                    || '''-1'''
                    || ') vs_geo,
                    nvl(attribute6,'
                    || '''-1'''
                    || ') vs_channel,
                    nvl(attribute7,'
                    || '''-1'''
                    || ') vs_cost_centre,
                    nvl(attribute8,'
                    || '''-1'''
                    || ') vs_natural_account,
                    nvl(attribute9,'
                    || '''-1'''
                    || ') vs_inter_company,
                    nvl(attribute10,'
                    || '''N'''
                    || ') vs_post_to_gl,
					NVL(attribute11,'
                    || '''-1'''
                    || ') vs_future_use,
                    attribute12 cutoff_transaction_id,
                    attribute13 conversion_type,
                    NVL(attribute14,'
                    || '''-1'''
                    || ') vs_cogs_natural_account					
                FROM
                    apps.fnd_flex_value_sets   ffvs,
                    apps.fnd_flex_values_vl    ffvl
                WHERE
                    1 = 1
                    AND ffvs.flex_value_set_name ='
                    || '''XXD_CM_CAPTURE_MARGINS_VS'''
                    || ' '
                    || 'AND ffvs.flex_value_set_id = ffvl.flex_value_set_id
                    AND nvl(ffvl.enabled_flag,'
                    || '''Y'''
                    || ') ='
                    || '''Y'''
                    || ' '
                    || 'AND nvl(trunc(ffvl.start_date_active), trunc(SYSDATE)) <= trunc(SYSDATE)
                    AND nvl(trunc(ffvl.end_date_active), trunc(SYSDATE)) >= trunc(SYSDATE)
            ) markup
        WHERE
            mmt.transaction_type_id = mtt.transaction_type_id
            AND mmt.trx_source_line_id = oola.line_id
			AND mmt.inventory_item_id = oola.inventory_item_id
            AND oola.header_id = ooha.header_id
            AND ooha.order_source_id = oos.order_source_id
               AND oos.name NOT IN (SELECT
                                        source
                                    FROM
                                    TABLE ( xxd_gl_markup_cap_postgl_pkg.get_source_val_fnc ))
			AND mmt.attribute14 IS NOT NULL -- Markup
			AND mmt.attribute15 IS NULL -- Gl Interface inserted flag
			AND mmt.attribute14 <>'
                    || '''NA'''
                    || ' '
                    || 'AND mmt.costed_flag IS NULL
            AND transaction_type_name IN ('
                    || '''Sales order issue'''
                    || ','
                    || '''RMA Receipt'''
                    || ')
            AND markup.vs_org_id = ooha.org_id';

                --            AND oola.ship_from_org_id = '
                --   ||p_inventory_org;
                IF p_inventory_org IS NOT NULL
                THEN
                    lv_sql_statement   :=
                           lv_sql_statement
                        || ' AND oola.ship_from_org_id = '
                        || p_inventory_org;
                END IF;

                IF p_org_id IS NOT NULL
                THEN
                    lv_sql_statement   :=
                        lv_sql_statement || ' AND ooha.org_id = ' || p_org_id;
                ELSE
                    lv_sql_statement   :=
                           lv_sql_statement
                        || ' AND ooha.org_id='
                        || rec_orgs.org_id;
                END IF;

                IF p_date_from IS NOT NULL
                THEN
                    lv_sql_statement   :=
                           lv_sql_statement
                        || ' AND trunc(mmt.transaction_date)>= TRUNC(TO_DATE('''
                        || p_date_from
                        || ''',''YYYY/MM/DD HH24:MI:SS''))';
                END IF;

                IF p_date_to IS NOT NULL
                THEN
                    lv_sql_statement   :=
                           lv_sql_statement
                        || ' AND trunc(mmt.transaction_date)<=TRUNC(TO_DATE('''
                        || p_date_to
                        || ''',''YYYY/MM/DD HH24:MI:SS''))';
                END IF;

                --1.1 changes start
                IF     p_from_transaction_id IS NULL
                   AND p_to_transaction_id IS NULL
                THEN                                                     --1.1
                    lv_sql_statement   :=
                           lv_sql_statement
                        || 'AND mmt.transaction_id >= to_number(markup.cutoff_transaction_id)';
                ELSIF     p_from_transaction_id IS NOT NULL
                      AND p_to_transaction_id IS NULL
                THEN
                    lv_sql_statement   :=
                           lv_sql_statement
                        || ' AND mmt.transaction_id > '
                        || p_from_transaction_id;
                ELSIF     p_from_transaction_id IS NOT NULL
                      AND p_to_transaction_id IS NOT NULL
                THEN
                    lv_sql_statement   :=
                           lv_sql_statement
                        || ' AND mmt.transaction_id >= '
                        || p_from_transaction_id
                        || ' AND mmt.transaction_id <= '
                        || p_to_transaction_id;
                END IF;

                -- 1.1 changes end
                IF p_material_transaction_type IS NOT NULL
                THEN
                    lv_sql_statement   :=
                           lv_sql_statement
                        || ' AND mtt.transaction_type_id = '
                        || p_material_transaction_type;
                END IF;

                --        lv_org_id:=NULL;
                --   lv_org_id:=rec_orgs.org_id;
                OPEN transactions_to_update FOR lv_sql_statement;

                LOOP
                    FETCH transactions_to_update INTO i;

                    EXIT WHEN transactions_to_update%NOTFOUND;

                    ln_record_count   := ln_record_count + 1;

                    IF i.markup_type = 'On-hand Markup'
                    THEN
                        ln_avg_mrgn_cst_usd   :=
                              NVL (i.mmt_markup, 0)
                            * ABS (NVL (i.transaction_quantity, 1));
                    ELSE
                        ln_avg_mrgn_cst_usd   := NVL (i.mmt_markup, 0);
                    END IF;

                    IF NVL (i.vs_post_to_gl, 'N') = 'N'
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Post to Gl in the value set marked as No for this OU...Record will not be inserted into GL Interface');

                        BEGIN
                            UPDATE mtl_material_transactions
                               SET attribute15 = 'N', -- inserting into GL interface set as N in value set
                                                      last_update_date = SYSDATE, last_updated_by = gn_user_id
                             WHERE transaction_id = i.transaction_id;

                            COMMIT;
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Updation of attribute15-GL Interface inserted flag success for transaction_id:'
                                || i.transaction_id);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Updation of attribute15-GL Interface inserted flag failed for transaction_id:'
                                    || i.transaction_id
                                    || '-'
                                    || SQLERRM);
                        END;
                    ELSIF     NVL (i.vs_post_to_gl, 'N') = 'Y'
                          AND ln_avg_mrgn_cst_usd <= 0
                    THEN                                                 --1.1
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Markup value is zero or less than zero for transaction_id:'
                            || i.transaction_id
                            || '-'
                            || 'Skipping the GL insertion ');

                        BEGIN
                            UPDATE mtl_material_transactions
                               SET attribute15 = 'NA', last_update_date = SYSDATE, last_updated_by = gn_user_id
                             WHERE transaction_id = i.transaction_id;

                            COMMIT;
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Updation of attribute15-GL Interface inserted flag success for transaction_id:'
                                || i.transaction_id);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Updation of attribute15-GL Interface inserted flag failed for transaction_id:'
                                    || i.transaction_id
                                    || '-'
                                    || SQLERRM);
                        END;
                    ELSIF     NVL (i.vs_post_to_gl, 'N') = 'Y'
                          AND ln_avg_mrgn_cst_usd > 0
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Post to Gl in the value set marked as Yes for this OU...Record will be inserted into GL Interface');


                        insert_gl_data (i.currency_code,
                                        i.ship_to_orgn_id,
                                        i.shipfrom_invorgid,
                                        i.transaction_date,
                                        ln_avg_mrgn_cst_usd,
                                        i.line_id,
                                        i.vs_company,
                                        i.vs_brand,
                                        i.vs_geo,
                                        i.vs_channel,
                                        i.vs_cost_centre,
                                        i.vs_natural_account,
                                        i.vs_inter_company,
                                        i.vs_future_use,
                                        i.transaction_id,
                                        i.conversion_type,
                                        i.vs_cogs_natural_account);
                    END IF;
                END LOOP;
            END LOOP;

            IF ln_record_count = 0
            THEN
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                    'There is no eligible records for the Given parameters');
            END IF;

            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'SQL Statement:' || lv_sql_statement);
            populate_gl_int;                                 -- Added for V1.2
        END IF;
    --1.1 changes end

    END main;
END;                                                           -- Package Body
/
