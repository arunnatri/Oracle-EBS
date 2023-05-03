--
-- XXD_BOM_UNINV_RPT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:11 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_BOM_UNINV_RPT_PKG"
AS
    /**************************************************************************************************
     * Package         : XXD_BOM_UNINV_RPT_PKG
     * Description     : This package is used for Inventory Aging Details Report - Deckers
     * Notes           : Oracle apps custom reports, output file excel
     * Modification    :
     *-------------------------------------------------------------------------------------------------
     * Date         Version#   Name                  Description
     *-------------------------------------------------------------------------------------------------
     * 20-JUN-2017  1.0        Greg Jensen           Initial Version(copied from stg pkg) - CCR0006335
     * 17-Jan-2022  1.1        Aravind Kannuri       Changes for CCR0009783
     *
     **************************************************************************************************/

    G_PKG_NAME            CONSTANT VARCHAR2 (30) := 'XXD_BOM_UNINV_RPT_PKG';
    G_LOG_LEVEL           CONSTANT NUMBER := FND_LOG.G_CURRENT_RUNTIME_LEVEL;

    G_GL_APPLICATION_ID   CONSTANT NUMBER := 101;
    G_PO_APPLICATION_ID   CONSTANT NUMBER := 201;

    --Start Changes for 1.1
    gn_user_id            CONSTANT NUMBER := fnd_global.user_id;
    gn_login_id           CONSTANT NUMBER := fnd_global.login_id;
    gn_org_id             CONSTANT NUMBER := fnd_global.org_id;
    gn_resp_id            CONSTANT NUMBER := fnd_global.resp_id;
    gn_resp_appl_id       CONSTANT NUMBER := fnd_global.resp_appl_id;
    gn_request_id         CONSTANT NUMBER := fnd_global.conc_request_id;
    gd_date               CONSTANT DATE := SYSDATE;

    --End Changes for 1.1

    -----------------------------------------------------------------------------
    -- FUNCTION (private) :   get_qty_precision
    -----------------------------------------------------------------------------
    FUNCTION get_qty_precision (qty_precision IN NUMBER, x_return_status OUT NOCOPY VARCHAR2, x_msg_count OUT NOCOPY NUMBER
                                , x_msg_data OUT NOCOPY VARCHAR2)
        RETURN VARCHAR2
    IS
    BEGIN
        x_return_status   := fnd_api.g_ret_sts_success;

        IF qty_precision = 0
        THEN
            RETURN ('999G999G999G990');
        ELSIF qty_precision = 1
        THEN
            RETURN ('999G999G999G990D0');
        ELSIF qty_precision = 2
        THEN
            RETURN ('999G999G999G990D00');
        ELSIF qty_precision = 3
        THEN
            RETURN ('999G999G999G990D000');
        ELSIF qty_precision = 4
        THEN
            RETURN ('999G999G999G990D0000');
        ELSIF qty_precision = 5
        THEN
            RETURN ('999G999G999G990D00000');
        ELSIF qty_precision = 6
        THEN
            RETURN ('999G999G999G990D000000');
        ELSIF qty_precision = 7
        THEN
            RETURN ('999G999G999G990D0000000');
        ELSIF qty_precision = 8
        THEN
            RETURN ('999G999G999G990D00000000');
        ELSIF qty_precision = 9
        THEN
            RETURN ('999G999G999G990D000000000');
        ELSIF qty_precision = 10
        THEN
            RETURN ('999G999G999G990D0000000000');
        ELSIF qty_precision = 11
        THEN
            RETURN ('999G999G999G990D00000000000');
        ELSIF qty_precision = 12
        THEN
            RETURN ('999G999G999G990D000000000000');
        ELSIF qty_precision = 13
        THEN
            RETURN ('999G999G999G990D0000000000000');
        ELSE
            RETURN ('999G999G999G990D00');
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_return_status   := FND_API.g_ret_sts_unexp_error;
            x_msg_data        := SQLERRM;
            FND_MSG_PUB.count_and_get (p_count   => x_msg_count,
                                       p_data    => x_msg_data);
            fnd_file.put_line (
                FND_FILE.LOG,
                'Error in: XXD_BOM_UNINVOICED_RPT.get_qty_precision()');
    END get_qty_precision;

    --Start Changes for 1.1
    --Get USD Conversion per Spotrate
    FUNCTION get_usd_conversion (p_currency IN VARCHAR2, p_cutoff_date IN VARCHAR2, p_accrual_amount IN NUMBER)
        RETURN NUMBER
    IS
        lv_currency              VARCHAR2 (50) := p_currency;
        ld_cutoff_date           DATE
            := NVL (fnd_date.canonical_to_date (p_cutoff_date), SYSDATE);
        ln_func_curr_spot_rate   NUMBER;
        ln_func_usd_amt          NUMBER;
    BEGIN
        BEGIN
            SELECT conversion_rate
              INTO ln_func_curr_spot_rate
              FROM gl_daily_rates
             WHERE     from_currency = lv_currency
                   AND to_currency = 'USD'
                   AND TRUNC (conversion_date) = TRUNC (ld_cutoff_date)
                   AND conversion_type = 'Spot';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_func_curr_spot_rate   := NULL;
        END;

        IF NVL (lv_currency, 'USD') <> 'USD'
        THEN
            IF NVL (ln_func_curr_spot_rate, 0) = 0
            THEN
                ln_func_usd_amt   := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'GL Daily Rates are not defined for Conversion Date :'
                    || TRUNC (ld_cutoff_date));
            ELSE
                ln_func_usd_amt   :=
                    p_accrual_amount * NVL (ln_func_curr_spot_rate, 1);
            END IF;
        ELSE
            ln_func_usd_amt   := p_accrual_amount;
        END IF;

        --fnd_file.put_line (fnd_file.log, 'ln_func_usd_amount :'||ROUND(ln_func_usd_amt,2));
        RETURN ROUND (ln_func_usd_amt, 2);
    EXCEPTION
        WHEN OTHERS
        THEN
            ln_func_usd_amt   := NULL;
            fnd_file.put_line (fnd_file.LOG,
                               'Exp-ln_func_usd_amount :' || SQLERRM);
            RETURN ln_func_usd_amt;
    END get_usd_conversion;

    --Get Invoice Age for MAX Receipt PO
    FUNCTION get_invoice_age (p_po_header_id IN NUMBER, p_po_line_id IN NUMBER, p_cutoff_date IN VARCHAR2)
        RETURN NUMBER
    IS
        ld_max_receipt_date   DATE;
        ln_invoice_age        NUMBER;
        ld_cutoff_date        DATE
            := NVL (fnd_date.canonical_to_date (p_cutoff_date), SYSDATE);
    BEGIN
        BEGIN
            SELECT MAX (rt.transaction_date)
              INTO ld_max_receipt_date
              FROM rcv_shipment_lines rsl, rcv_transactions rt
             WHERE     rsl.po_header_id = p_po_header_id
                   AND rsl.po_line_id = p_po_line_id
                   AND rsl.shipment_header_id = rt.shipment_header_id
                   AND rsl.shipment_line_id = rt.shipment_line_id
                   AND rt.transaction_type = 'RECEIVE';
        EXCEPTION
            WHEN OTHERS
            THEN
                ld_max_receipt_date   := NULL;
        END;

        IF ld_max_receipt_date IS NOT NULL
        THEN
            ln_invoice_age   :=
                ABS (ROUND ((ld_max_receipt_date - ld_cutoff_date), 0));
        ELSE
            ln_invoice_age   := 1;
        END IF;

        --fnd_file.put_line (fnd_file.log, 'ln_invoice_age :'||ln_invoice_age);
        RETURN ln_invoice_age;
    EXCEPTION
        WHEN OTHERS
        THEN
            ln_invoice_age   := -1;
            fnd_file.put_line (fnd_file.LOG,
                               'Exp-ln_invoice_age :' || SQLERRM);
            RETURN ln_invoice_age;
    END get_invoice_age;

    --Get Preparer for PO
    FUNCTION get_po_preparer (p_po_header_id IN NUMBER)
        RETURN VARCHAR2
    IS
        lv_preparer   VARCHAR2 (240);
    BEGIN
        SELECT DISTINCT ppf.full_name
          INTO lv_preparer
          FROM po_requisition_headers_all prh, po_requisition_lines_all prl, po_req_distributions_all prd,
               per_all_people_f ppf, po_headers_all poh, po_distributions_all pda
         WHERE     prh.requisition_header_id = prl.requisition_header_id
               AND ppf.person_id = prh.preparer_id
               AND prh.type_lookup_code = 'PURCHASE'
               AND prd.requisition_line_id = prl.requisition_line_id
               AND pda.req_distribution_id = prd.distribution_id
               AND pda.po_header_id = poh.po_header_id
               AND poh.po_header_id = p_po_header_id;                  --17047

        --AND prd.distribution_id = p_po_distribution_id; --184005

        --fnd_file.put_line (fnd_file.log, 'PO Preparer :'||lv_preparer);
        RETURN lv_preparer;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_preparer   := NULL;
            fnd_file.put_line (fnd_file.LOG,
                               'Exp - PO Preparer :' || SQLERRM);
            RETURN lv_preparer;
    END get_po_preparer;

    --Get Last Receipt Receiver for PO
    FUNCTION get_rcpt_receiver (p_po_header_id   IN NUMBER,
                                p_po_line_id     IN NUMBER)
        RETURN VARCHAR2
    IS
        lv_receiver   VARCHAR2 (240);
    BEGIN
        SELECT DISTINCT papf.full_name
          INTO lv_receiver
          FROM rcv_shipment_lines rsl, rcv_transactions rt, per_all_people_f papf
         WHERE     rsl.po_header_id = p_po_header_id
               AND rsl.po_line_id = p_po_line_id
               AND rsl.shipment_header_id = rt.shipment_header_id
               AND rsl.shipment_line_id = rt.shipment_line_id
               AND rt.employee_id = papf.person_id
               AND rt.transaction_type = 'RECEIVE'
               AND rt.transaction_date =
                   (SELECT MAX (rt1.transaction_date)
                      FROM rcv_shipment_lines rsl1, rcv_transactions rt1
                     WHERE     rsl1.po_header_id = p_po_header_id
                           AND rsl1.po_line_id = p_po_line_id
                           AND rsl1.shipment_header_id =
                               rt1.shipment_header_id
                           AND rsl1.shipment_line_id = rt1.shipment_line_id
                           AND rt1.transaction_type = 'RECEIVE');

        --fnd_file.put_line (fnd_file.log, 'Last Receipt Receiver :'||lv_receiver);
        RETURN lv_receiver;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_receiver   := NULL;
            fnd_file.put_line (fnd_file.LOG,
                               'Exp - Last Receipt Receiver :' || SQLERRM);
            RETURN lv_receiver;
    END get_rcpt_receiver;

    --End Changes for 1.1

    -----------------------------------------------------------------------------
    -- PROCEDURE    :   Start_Process
    -- DESCRIPTION  :   Starting point for Uninvoiced Receipt Report
    -----------------------------------------------------------------------------

    PROCEDURE Start_Process (
        errbuf                     OUT NOCOPY VARCHAR2,
        retcode                    OUT NOCOPY NUMBER,
        p_title                 IN            VARCHAR2,
        p_accrued_receipts      IN            VARCHAR2,
        p_inc_online_accruals   IN            VARCHAR2,
        p_inc_closed_pos        IN            VARCHAR2,
        p_struct_num            IN            NUMBER,
        p_category_from         IN            VARCHAR2,
        p_category_to           IN            VARCHAR2,
        p_min_accrual_amount    IN            NUMBER,
        p_period_name           IN            VARCHAR2,
        p_vendor_from           IN            VARCHAR2,
        p_vendor_to             IN            VARCHAR2,
        p_orderby               IN            VARCHAR2,
        p_age_greater_then      IN            VARCHAR2,        --Added for 1.1
        p_cut_off_date          IN            VARCHAR2,        --Added for 1.1
        p_qty_precision         IN            NUMBER := 2)
    IS
        --Start Changes for 1.1
        CURSOR cur_inv (pn_sob_id NUMBER, pv_age_type VARCHAR2)
        IS
              SELECT NVL (poh.clm_document_number, poh.segment1) po_number, --Changed as a part of CLM
                                                                            porl.release_num po_release_number, poh.po_header_id po_header_id,
                     pol.po_line_id po_line_id, SUM (ROUND (NVL (cpea.quantity_received, 0), p_qty_precision)) OVER (PARTITION BY pol.po_line_id) tot_rcv, SUM (ROUND (NVL (cpea.quantity_billed, 0), p_qty_precision)) OVER (PARTITION BY pol.po_line_id) tot_billed,
                     cpea.shipment_id po_shipment_id, cpea.distribution_id po_distribution_id, plt.line_type line_type,
                     NVL (POL.LINE_NUM_DISPLAY, TO_CHAR (POL.LINE_NUM)) line_num, --Changed as a part of CLM
                                                                                  msi.concatenated_segments item_name, mca.concatenated_segments category,
                     pol.item_description item_description, pov.vendor_name vendor_name, fnc2.currency_code accrual_currency_code,
                     poll.shipment_num shipment_number, poll.unit_meas_lookup_code uom_code, pod.distribution_num distribution_num,
                     ROUND (NVL (cpea.quantity_received, 0), p_qty_precision) quantity_received, ROUND (NVL (cpea.quantity_billed, 0), p_qty_precision) quantity_billed, ROUND (NVL (cpea.accrual_quantity, 0), p_qty_precision) quantity_accrued,
                     ROUND (cpea.unit_price, NVL (fnc2.extended_precision, 2)) po_unit_price, cpea.currency_code po_currency_code, ROUND (DECODE (NVL (fnc1.minimum_accountable_unit, 0), 0, cpea.unit_price * cpea.currency_conversion_rate, (cpea.unit_price / fnc1.minimum_accountable_unit) * cpea.currency_conversion_rate * fnc1.minimum_accountable_unit), NVL (fnc1.extended_precision, 2)) func_unit_price,
                     gcc1.concatenated_segments charge_account, gcc1.segment2 charge_brand, gcc2.concatenated_segments accrual_account,
                     gcc2.code_combination_id accrual_ccid, cpea.accrual_amount accrual_amount, ROUND (DECODE (NVL (fnc1.minimum_accountable_unit, 0), 0, cpea.accrual_amount * cpea.currency_conversion_rate, (cpea.accrual_amount / fnc1.minimum_accountable_unit) * cpea.currency_conversion_rate * fnc1.minimum_accountable_unit), NVL (fnc1.precision, 2)) * -1 func_accrual_amount,
                     NVL (fnc2.extended_precision, 2) PO_PRECISION, NVL (fnc1.extended_precision, 2) PO_FUNC_PRECISION, NVL (fnc1.precision, 2) ACCR_PRECISION,
                     get_invoice_age (pol.po_header_id, pol.po_line_id, p_cut_off_date) age, get_usd_conversion (cpea.currency_code, --fnc2.currency_code,
                                                                                                                                     p_cut_off_date, cpea.accrual_amount) usd_accrual_amount, --usd_balances
                                                                                                                                                                                              get_po_preparer (pol.po_header_id) preparer,
                     get_rcpt_receiver (pol.po_header_id, pol.po_line_id) receipt_receiver
                FROM cst_per_end_accruals_temp cpea, po_headers_all poh, po_lines_all pol,
                     po_line_locations_all poll, po_distributions_all pod, ap_suppliers pov,
                     po_line_types plt, po_releases_all porl, mtl_system_items_kfv msi,
                     fnd_currencies fnc1, fnd_currencies fnc2, mtl_categories_kfv mca,
                     gl_code_combinations_kfv gcc1, gl_code_combinations_kfv gcc2, gl_ledgers sob
               WHERE     pod.po_distribution_id = cpea.distribution_id
                     AND poh.po_header_id = pol.po_header_id
                     AND pol.po_line_id = poll.po_line_id
                     AND poll.line_location_id = pod.line_location_id
                     AND pol.line_type_id = plt.line_type_id
                     AND porl.po_release_id(+) = poll.po_release_id
                     AND poh.vendor_id = pov.vendor_id
                     AND msi.inventory_item_id(+) = pol.item_id
                     AND (msi.organization_id IS NULL OR (msi.organization_id = poll.ship_to_organization_id AND msi.organization_id IS NOT NULL))
                     AND fnc1.currency_code = cpea.currency_code
                     AND fnc2.currency_code = sob.currency_code
                     AND cpea.category_id = mca.category_id(+)
                     AND gcc1.code_combination_id = pod.code_combination_id
                     AND gcc2.code_combination_id = pod.accrual_account_id
                     AND sob.ledger_id = pn_sob_id
                     --Start Changes for 1.1
                     AND ((pv_age_type = 'GREATER_THEN' AND get_invoice_age (pol.po_header_id, pol.po_line_id, p_cut_off_date) > ABS (p_age_greater_then)) OR (pv_age_type = 'LESS_THEN' AND get_invoice_age (pol.po_header_id, pol.po_line_id, p_cut_off_date) < ABS (p_age_greater_then)) OR (pv_age_type = 'ZERO' AND 1 = 1))
            --End Changes for 1.1
            ORDER BY DECODE (p_orderby,  'Category', mca.concatenated_segments,  'vendor', pov.vendor_name,  NVL (poh.CLM_DOCUMENT_NUMBER, poh.SEGMENT1)), NVL (poh.CLM_DOCUMENT_NUMBER, poh.SEGMENT1), NVL (POL.LINE_NUM_DISPLAY, TO_CHAR (POL.LINE_NUM)),
                     poll.shipment_num, pod.distribution_num;

        --End Changes for 1.1

        l_api_name       CONSTANT VARCHAR2 (30) := 'Start_Process';
        l_api_version    CONSTANT NUMBER := 1.0;
        l_return_status           VARCHAR2 (1);

        l_full_name      CONSTANT VARCHAR2 (60)
                                      := G_PKG_NAME || '.' || l_api_name ;
        l_module         CONSTANT VARCHAR2 (60) := 'cst.plsql.' || l_full_name;

        /* Log Severities*/
        /* 6- UNEXPECTED */
        /* 5- ERROR      */
        /* 4- EXCEPTION  */
        /* 3- EVENT      */
        /* 2- PROCEDURE  */
        /* 1- STATEMENT  */

        /* In general, we should use the following:
        G_LOG_LEVEL    CONSTANT NUMBER := FND_LOG.G_CURRENT_RUNTIME_LEVEL;
        l_uLog         CONSTANT BOOLEAN := FND_LOG.TEST(FND_LOG.LEVEL_UNEXPECTED, l_module) AND (FND_LOG.LEVEL_UNEXPECTED >= G_LOG_LEVEL);
        l_errorLog     CONSTANT BOOLEAN := l_uLog AND (FND_LOG.LEVEL_ERROR >= G_LOG_LEVEL);
        l_exceptionLog CONSTANT BOOLEAN := l_errorLog AND (FND_LOG.LEVEL_EXCEPTION >= G_LOG_LEVEL);
        l_eventLog     CONSTANT BOOLEAN := l_exceptionLog AND (FND_LOG.LEVEL_EVENT >= G_LOG_LEVEL);
        l_pLog         CONSTANT BOOLEAN := l_eventLog AND (FND_LOG.LEVEL_PROCEDURE >= G_LOG_LEVEL);
        l_sLog         CONSTANT BOOLEAN := l_pLog AND (FND_LOG.LEVEL_STATEMENT >= G_LOG_LEVEL);
        */

        l_uLog           CONSTANT BOOLEAN
            :=     FND_LOG.TEST (FND_LOG.LEVEL_UNEXPECTED, l_module)
               AND (FND_LOG.LEVEL_UNEXPECTED >= G_LOG_LEVEL) ;
        l_exceptionLog   CONSTANT BOOLEAN
            := l_uLog AND (FND_LOG.LEVEL_EXCEPTION >= G_LOG_LEVEL) ;
        l_pLog           CONSTANT BOOLEAN
            := l_exceptionLog AND (FND_LOG.LEVEL_PROCEDURE >= G_LOG_LEVEL) ;
        l_sLog           CONSTANT BOOLEAN
            := l_pLog AND (FND_LOG.LEVEL_STATEMENT >= G_LOG_LEVEL) ;

        l_msg_count               NUMBER;
        l_msg_data                VARCHAR2 (240);

        l_header_ref_cur          SYS_REFCURSOR;
        l_body_ref_cur            SYS_REFCURSOR;
        l_row_tag                 VARCHAR2 (100);
        l_row_set_tag             VARCHAR2 (100);
        l_xml_header              CLOB;
        l_xml_body                CLOB;
        l_xml_report              CLOB;

        l_conc_status             BOOLEAN;
        l_return                  BOOLEAN;
        l_status                  VARCHAR2 (1);
        l_industry                VARCHAR2 (1);
        l_schema                  VARCHAR2 (30);
        l_application_id          NUMBER;
        l_legal_entity            NUMBER;
        l_end_date                DATE;
        l_sob_id                  NUMBER;
        l_order_by                VARCHAR2 (50);
        l_multi_org_flag          VARCHAR2 (1);
        l_accrued_receipts        VARCHAR2 (20);
        l_inc_online_accruals     VARCHAR2 (20);
        l_inc_closed_pos          VARCHAR2 (20);

        l_stmt_num                NUMBER;
        l_row_count               NUMBER;

        l_qty_precision           VARCHAR2 (50);

        --End Changes for 1.1
        TYPE tb_rec_inv IS TABLE OF cur_inv%ROWTYPE;

        v_tb_rec_inv              tb_rec_inv;

        l_count                   NUMBER;
        lv_ret_code               VARCHAR2 (30) := NULL;
        v_bulk_limit              NUMBER := 500;

        lv_age_type               VARCHAR2 (50) := NULL;
        ln_age                    NUMBER := 0;
    --End Changes for 1.1

    BEGIN
        EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_NUMERIC_CHARACTERS=''.,''';

        l_stmt_num        := 0;

        -- Procedure level log message for Entry point
        -- Added 2 new parameters(p_age_greater_then, p_cut_off_date) for 1.1
        IF (l_pLog)
        THEN
            FND_LOG.STRING (
                FND_LOG.LEVEL_PROCEDURE,
                l_module || '.begin',
                   'Start_Process <<'
                || 'p_title = '
                || p_title
                || ','
                || 'p_accrued_receipts = '
                || p_accrued_receipts
                || ','
                || 'p_inc_online_accruals = '
                || p_inc_online_accruals
                || ','
                || 'p_inc_closed_pos = '
                || p_inc_closed_pos
                || ','
                || 'p_struct_num = '
                || p_struct_num
                || ','
                || 'p_category_from = '
                || p_category_from
                || ','
                || 'p_category_to = '
                || p_category_to
                || ','
                || 'p_min_accrual_amount = '
                || p_min_accrual_amount
                || ','
                || 'p_period_name = '
                || p_period_name
                || ','
                || 'p_vendor_from = '
                || p_vendor_from
                || ','
                || 'p_vendor_to = '
                || p_vendor_to
                || ','
                || 'p_orderby = '
                || p_orderby
                || ','
                || 'p_age_greater_then = '
                || p_age_greater_then
                || ','
                || 'p_cut_off_date = '
                || p_cut_off_date
                || ','
                || 'p_qty_precision = '
                || p_qty_precision);
        END IF;

        --Start Changes for 1.1
        mo_global.set_policy_context ('S', fnd_global.org_id);
        fnd_global.apps_initialize (user_id        => fnd_global.user_id,
                                    resp_id        => fnd_global.resp_id,
                                    resp_appl_id   => fnd_global.resp_appl_id);
        --End Changes for 1.1

        -- Initialize message list if p_init_msg_list is set to TRUE.
        FND_MSG_PUB.initialize;

        --  Initialize API return status to success
        l_return_status   := FND_API.G_RET_STS_SUCCESS;

        -- Check whether GL is installed
        l_stmt_num        := 10;
        l_return          :=
            FND_INSTALLATION.GET_APP_INFO ('SQLGL', l_status, l_industry,
                                           l_schema);

        IF (l_status = 'I')
        THEN
            l_application_id   := G_GL_APPLICATION_ID;
        ELSE
            l_application_id   := G_PO_APPLICATION_ID;
        END IF;

        -- Convert Accrual Cutoff date from Legal entity timezone to
        -- Server timezone
        l_stmt_num        := 20;

        SELECT set_of_books_id
          INTO l_sob_id
          FROM financials_system_parameters;

        SELECT TO_NUMBER (org_information2)
          INTO l_legal_entity
          FROM hr_organization_information
         WHERE     organization_id = MO_GLOBAL.GET_CURRENT_ORG_ID
               AND org_information_context = 'Operating Unit Information';

        l_stmt_num        := 30;

        SELECT INV_LE_TIMEZONE_PUB.GET_SERVER_DAY_TIME_FOR_LE (gps.end_date, l_legal_entity)
          INTO l_end_date
          FROM gl_period_statuses gps
         WHERE     gps.application_id = l_application_id
               AND gps.set_of_books_id = l_sob_id
               AND gps.period_name =
                   NVL (
                       p_period_name,
                       (SELECT gp.period_name
                          FROM gl_periods gp, gl_ledgers sob --Updated CCR0006335
                         WHERE     sob.ledger_id = l_sob_id
                               AND sob.period_set_name = gp.period_set_name
                               AND sob.accounted_period_type = gp.period_type
                               AND gp.ADJUSTMENT_PERIOD_FLAG = 'N'
                               AND gp.start_date <= TRUNC (SYSDATE)
                               AND gp.end_date >= TRUNC (SYSDATE)));

        ---------------------------------------------------------------------
        -- Call the common API CST_PerEndAccruals_PVT.Create_PerEndAccruals
        -- This API creates period end accrual entries in the temporary
        -- table CST_PER_END_ACCRUALS_TEMP.
        ---------------------------------------------------------------------
        l_stmt_num        := 60;
        CST_PerEndAccruals_PVT.Create_PerEndAccruals (
            p_api_version          => 1.0,
            p_init_msg_list        => FND_API.G_FALSE,
            p_commit               => FND_API.G_FALSE,
            p_validation_level     => FND_API.G_VALID_LEVEL_FULL,
            x_return_status        => l_return_status,
            x_msg_count            => l_msg_count,
            x_msg_data             => l_msg_data,
            p_min_accrual_amount   => p_min_accrual_amount,
            p_vendor_from          => p_vendor_from,
            p_vendor_to            => p_vendor_to,
            p_category_from        => p_category_from,
            p_category_to          => p_category_to,
            p_end_date             => l_end_date,
            p_accrued_receipt      => NVL (p_accrued_receipts, 'N'),
            p_online_accruals      => NVL (p_inc_online_accruals, 'N'),
            p_closed_pos           => NVL (p_inc_closed_pos, 'N'),
            p_calling_api          =>
                CST_PerEndAccruals_PVT.G_UNINVOICED_RECEIPT_REPORT);

        -- If return status is not success, add message to the log
        IF (l_return_status <> FND_API.G_RET_STS_SUCCESS)
        THEN
            l_msg_data   :=
                'Failed generating Period End Accrual information';
            RAISE FND_API.G_EXC_UNEXPECTED_ERROR;
        END IF;

        l_stmt_num        := 90;
        DBMS_LOB.createtemporary (l_xml_header, TRUE);
        DBMS_LOB.createtemporary (l_xml_body, TRUE);
        DBMS_LOB.createtemporary (l_xml_report, TRUE);

        -- Count the no. of rows in the accrual temp table
        -- l_row_count will be part of report header information
        l_stmt_num        := 100;

        SELECT COUNT ('X')
          INTO l_row_count
          FROM CST_PER_END_ACCRUALS_TEMP
         WHERE ROWNUM = 1;

        l_stmt_num        := 101;

        l_order_by        := p_orderby;

        l_stmt_num        := 102;

        IF (p_accrued_receipts = 'Y' OR p_accrued_receipts = 'N')
        THEN
            SELECT meaning
              INTO l_accrued_receipts
              FROM fnd_lookups
             WHERE     lookup_type = 'YES_NO'
                   AND lookup_code = p_accrued_receipts;
        ELSE
            l_accrued_receipts   := ' ';
        END IF;

        l_stmt_num        := 103;

        IF (p_inc_online_accruals = 'Y' OR p_inc_online_accruals = 'N')
        THEN
            SELECT meaning
              INTO l_inc_online_accruals
              FROM fnd_lookups
             WHERE     lookup_type = 'YES_NO'
                   AND lookup_code = p_inc_online_accruals;
        ELSE
            l_inc_online_accruals   := ' ';
        END IF;

        l_stmt_num        := 104;

        IF (p_inc_closed_pos = 'Y' OR p_inc_closed_pos = 'N')
        THEN
            SELECT meaning
              INTO l_inc_closed_pos
              FROM fnd_lookups
             WHERE lookup_type = 'YES_NO' AND lookup_code = p_inc_closed_pos;
        ELSE
            l_inc_closed_pos   := ' ';
        END IF;

        -------------------------------------------------------------------------
        -- Open reference cursor for fetching data related to report header
        -------------------------------------------------------------------------
        l_stmt_num        := 105;
        l_qty_precision   :=
            get_qty_precision (qty_precision => p_qty_precision, x_return_status => l_return_status, x_msg_count => l_msg_count
                               , x_msg_data => l_msg_data);

        IF (l_return_status <> FND_API.G_RET_STS_SUCCESS)
        THEN
            l_msg_data   := 'Failed getting qty precision';
            RAISE FND_API.G_EXC_UNEXPECTED_ERROR;
        END IF;

        --Gl_legers reference updated CCR0006335
        l_stmt_num        := 110;

        --Added 2 new columns(age_greater_then, cut_off_date) for 1.1
        OPEN l_header_ref_cur FOR
            'SELECT gsb.name                        company_name,
                :p_title                        report_title,
                SYSDATE                         report_date,
                :l_accrued_receipts             accrued_receipt,
                :l_inc_online_accruals          include_online_accruals,
                :l_inc_closed_pos               include_closed_pos,
                :p_category_from                category_from,
                :p_category_to                  category_to,
                :p_min_accrual_amount           minimum_accrual_amount,
                :p_period_name                  period_name,
                :p_vendor_from                  vendor_from,
                :p_vendor_to                    vendor_to,
                :l_order_by                     order_by,
                :l_row_count                    row_count,
				:p_age_greater_then             age_greater_then,
                :p_cut_off_date                 cut_off_date,				
                :l_qty_precision                qty_precision
        FROM    gl_ledgers gsb  
        WHERE   gsb.ledger_id = :l_sob_id'
            USING p_title, l_accrued_receipts, l_inc_online_accruals,
        l_inc_closed_pos, p_category_from, p_category_to,
        p_min_accrual_amount, p_period_name, p_vendor_from,
        p_vendor_to, l_order_by, l_row_count,
        p_age_greater_then, p_cut_off_date, l_qty_precision,
        l_sob_id;

        -- Set row_tag as HEADER for report header data
        l_row_tag         := 'HEADER';
        l_row_set_tag     := NULL;

        -- Generate XML data for header part
        l_stmt_num        := 120;
        Generate_XML (p_api_version => 1.0, p_init_msg_list => FND_API.G_FALSE, p_validation_level => FND_API.G_VALID_LEVEL_FULL, x_return_status => l_return_status, x_msg_count => l_msg_count, x_msg_data => l_msg_data, p_ref_cur => l_header_ref_cur, p_row_tag => l_row_tag, p_row_set_tag => l_row_set_tag
                      , x_xml_data => l_xml_header);

        -- If return status is not success, add message to the log
        IF (l_return_status <> FND_API.G_RET_STS_SUCCESS)
        THEN
            l_msg_data   := 'Failed generating XML data to the report output';
            RAISE FND_API.G_EXC_UNEXPECTED_ERROR;
        END IF;

        -- If row_count is 0, no need to open body_ref_cursor
        IF (l_row_count > 0)
        THEN
            --Start Changes for 1.1
            l_stmt_num      := 121;

            IF NVL (p_age_greater_then, 0) IN (60, 180)
            THEN
                lv_age_type   := 'GREATER_THEN';
            ELSIF NVL (p_age_greater_then, 0) IN (-60, -180)
            THEN
                lv_age_type   := 'LESS_THEN';
            ELSE
                lv_age_type   := 'ZERO';          --p_age_greater_then IS NULL
            END IF;

            l_stmt_num      := 122;

            OPEN cur_inv (l_sob_id, lv_age_type);

            LOOP
                FETCH cur_inv
                    BULK COLLECT INTO v_tb_rec_inv
                    LIMIT v_bulk_limit;

                BEGIN
                    FORALL i IN 1 .. v_tb_rec_inv.COUNT
                        INSERT INTO xxdo.xxd_ap_uninv_rcpt_t (
                                        request_id,
                                        po_number,
                                        release_num,
                                        line_type,
                                        line_num,
                                        category,
                                        item_name,
                                        item_desc,
                                        vendor_name,
                                        acc_currency,
                                        shipment_num,
                                        qty_received,
                                        qty_billed,
                                        po_unit_price,
                                        func_unit_price,
                                        uom,
                                        dist_num,
                                        charge_account,
                                        acc_account,
                                        acc_ccid,
                                        acc_amount,
                                        func_acc_amount,
                                        charge_brand,
                                        usd_balances,
                                        age,
                                        preparer,
                                        last_receipt_receiver,
                                        creation_date,
                                        created_by,
                                        last_update_date,
                                        last_updated_by)
                             VALUES (gn_request_id, v_tb_rec_inv (i).po_number, v_tb_rec_inv (i).po_release_number, v_tb_rec_inv (i).line_type, v_tb_rec_inv (i).line_num, v_tb_rec_inv (i).category, v_tb_rec_inv (i).item_name, v_tb_rec_inv (i).item_description, v_tb_rec_inv (i).vendor_name, v_tb_rec_inv (i).po_currency_code, --accrual_currency_code,
                                                                                                                                                                                                                                                                                                                                      v_tb_rec_inv (i).shipment_number, v_tb_rec_inv (i).quantity_received, v_tb_rec_inv (i).quantity_billed, v_tb_rec_inv (i).po_unit_price, v_tb_rec_inv (i).func_unit_price, v_tb_rec_inv (i).uom_code, v_tb_rec_inv (i).distribution_num, v_tb_rec_inv (i).charge_account, v_tb_rec_inv (i).accrual_account, v_tb_rec_inv (i).accrual_ccid, v_tb_rec_inv (i).accrual_amount, v_tb_rec_inv (i).func_accrual_amount, v_tb_rec_inv (i).charge_brand, v_tb_rec_inv (i).usd_accrual_amount, --usd_balances
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           v_tb_rec_inv (i).age, v_tb_rec_inv (i).preparer, v_tb_rec_inv (i).receipt_receiver, gd_date, gn_user_id, gd_date
                                     , gn_user_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'insertion failed for  Table' || SQLERRM);
                END;

                COMMIT;
                EXIT WHEN cur_inv%NOTFOUND;
            END LOOP;

            --End Changes for 1.1

            ---------------------------------------------------------------------
            -- Open reference cursor for fetching data related to report body
            ---------------------------------------------------------------------
            l_stmt_num      := 140;

            /*  --gl_ledgers/ap_suppliers updated per CCR0006335
      OPEN l_body_ref_cur FOR
               'SELECT NVL(poh.CLM_DOCUMENT_NUMBER,poh.SEGMENT1) po_number,--Changed as a part of CLM
                       porl.release_num                        po_release_number,
                       poh.po_header_id                        po_header_id,
                       pol.po_line_id                          po_line_id,
                       sum(round(nvl(cpea.quantity_received, 0), :p_qty_precision)) over (partition by pol.po_line_id) tot_rcv,
                       sum(round(nvl(cpea.quantity_billed, 0), :p_qty_precision) ) over (partition by pol.po_line_id) tot_billed,
                       cpea.shipment_id                        po_shipment_id,
                       cpea.distribution_id                    po_distribution_id,
                       plt.line_type                           line_type,
                        nvl(POL.LINE_NUM_DISPLAY, to_char(POL.LINE_NUM)) line_num,--Changed as a part of CLM
                       msi.concatenated_segments               item_name,
                       mca.concatenated_segments               category,
                       pol.item_description                    item_description,
                       pov.vendor_name                         vendor_name,
                       fnc2.currency_code                      accrual_currency_code,
                       poll.shipment_num                       shipment_number,
                       poll.unit_meas_lookup_code              uom_code,
                       pod.distribution_num                    distribution_num,
                       round(nvl(cpea.quantity_received, 0), :p_qty_precision)                  quantity_received,
                       round(nvl(cpea.quantity_billed, 0), :p_qty_precision)                    quantity_billed,
                       round(nvl(cpea.accrual_quantity, 0), :p_qty_precision)                   quantity_accrued,
                       ROUND(cpea.unit_price,
                               NVL(fnc2.extended_precision, 2))         po_unit_price,
                       cpea.currency_code                      po_currency_code,
                       ROUND(DECODE(NVL(fnc1.minimum_accountable_unit, 0),
                                        0, cpea.unit_price * cpea.currency_conversion_rate,
                                        (cpea.unit_price / fnc1.minimum_accountable_unit)
                                           * cpea.currency_conversion_rate
                                           * fnc1.minimum_accountable_unit),
                                             NVL(fnc1.extended_precision, 2))
                                                               func_unit_price,
                       gcc1.concatenated_segments              charge_account,
                       gcc2.concatenated_segments              accrual_account,
                       cpea.accrual_amount                     accrual_amount,
                       ROUND(DECODE(NVL(fnc1.minimum_accountable_unit, 0),
                                        0, cpea.accrual_amount * cpea.currency_conversion_rate,
                                        (cpea.accrual_amount / fnc1.minimum_accountable_unit)
                                           * cpea.currency_conversion_rate
                                           * fnc1.minimum_accountable_unit), NVL(fnc1.precision, 2))
                                                               func_accrual_amount,
                     nvl(fnc2.extended_precision,2)  PO_PRECISION,
                     nvl(fnc1.extended_precision,2)  PO_FUNC_PRECISION,
                     nvl(fnc1.precision,2)           ACCR_PRECISION
               FROM    cst_per_end_accruals_temp   cpea,
                       po_headers_all              poh,
                       po_lines_all                pol,
                       po_line_locations_all       poll,
                       po_distributions_all        pod,
                       ap_suppliers                  pov,
                       po_line_types               plt,
                       po_releases_all             porl,
                       mtl_system_items_kfv        msi,
                       fnd_currencies              fnc1,
                       fnd_currencies              fnc2,
                       mtl_categories_kfv          mca,
                       gl_code_combinations_kfv    gcc1,
                       gl_code_combinations_kfv    gcc2,
                       gl_ledgers sob
               WHERE   pod.po_distribution_id = cpea.distribution_id
               AND     poh.po_header_id = pol.po_header_id
               AND     pol.po_line_id = poll.po_line_id
               AND     poll.line_location_id = pod.line_location_id
               AND     pol.line_type_id = plt.line_type_id
               AND     porl.po_release_id (+)  = poll.po_release_id
               AND     poh.vendor_id = pov.vendor_id
               AND     msi.inventory_item_id (+)  = pol.item_id
               AND     (msi.organization_id IS NULL
                       OR
                       (msi.organization_id = poll.ship_to_organization_id AND msi.organization_id IS NOT NULL))
               AND     fnc1.currency_code =  cpea.currency_code
               AND     fnc2.currency_code = sob.currency_code
               AND     cpea.category_id = mca.category_id(+)
               AND     gcc1.code_combination_id = pod.code_combination_id
               AND     gcc2.code_combination_id = pod.accrual_account_id
               AND     sob.ledger_id = :l_sob_id
               ORDER BY DECODE(:p_orderby,
                               ''Category'', mca.concatenated_segments,
                               ''vendor'', pov.vendor_name,
                                NVL(poh.CLM_DOCUMENT_NUMBER,poh.SEGMENT1)),
                        NVL(poh.CLM_DOCUMENT_NUMBER,poh.SEGMENT1),
                        nvl(POL.LINE_NUM_DISPLAY, to_char(POL.LINE_NUM)),
                       poll.shipment_num,
                       pod.distribution_num'
               USING p_qty_precision,
                     p_qty_precision,
                     p_qty_precision,
                     p_qty_precision,
                     p_qty_precision,
                     l_sob_id,
                     p_orderby;  */

            OPEN l_body_ref_cur FOR 'SELECT
						po_number,
						release_num       po_release_number,
						line_type,
						line_num,
						category,
						item_name,         
						item_desc         item_description,
						vendor_name,
						acc_currency      accrual_currency_code,
						shipment_num      shipment_number,
						qty_received      quantity_received,
						qty_billed        quantity_billed,
						po_unit_price,
						func_unit_price,
						uom               uom_code,
						dist_num          distribution_num,
						charge_account,
						acc_account       accrual_account,
						acc_ccid          accrual_ccid,
						acc_amount        accrual_amount,
						func_acc_amount   func_accrual_amount,
						charge_brand,
						usd_balances 	  usd_accrual_amount,
						age,
						preparer,
						last_receipt_receiver receipt_receiver,
						creation_date,
						created_by,
						last_update_date,
						last_updated_by
					FROM
						xxdo.xxd_ap_uninv_rcpt_t
					WHERE
						request_id = :gn_request_id' USING gn_request_id;

            l_row_tag       := 'BODY';
            l_row_set_tag   := 'ACCRUAL_INFO';

            -- Generate XML data for report body
            l_stmt_num      := 150;
            Generate_XML (p_api_version => 1.0, p_init_msg_list => FND_API.G_FALSE, p_validation_level => FND_API.G_VALID_LEVEL_FULL, x_return_status => l_return_status, x_msg_count => l_msg_count, x_msg_data => l_msg_data, p_ref_cur => l_body_ref_cur, p_row_tag => l_row_tag, p_row_set_tag => l_row_set_tag
                          , x_xml_data => l_xml_body);

            -- If return status is not success, add message to the log
            IF (l_return_status <> FND_API.G_RET_STS_SUCCESS)
            THEN
                l_msg_data   :=
                    'Failed generating XML data to the report output';
                RAISE FND_API.G_EXC_UNEXPECTED_ERROR;
            END IF;
        END IF;

        -- Merge the header part with the body part.
        -- 'ACR_REPORT' will be used as root tag for resultant XML data
        l_stmt_num        := 160;
        Merge_XML (p_api_version => 1.0, p_init_msg_list => FND_API.G_FALSE, p_validation_level => FND_API.G_VALID_LEVEL_FULL, x_return_status => l_return_status, x_msg_count => l_msg_count, x_msg_data => l_msg_data, p_xml_src1 => l_xml_header, p_xml_src2 => l_xml_body, p_root_tag => 'ACR_REPORT'
                   , x_xml_doc => l_xml_report);

        -- If return status is not success, add message to the log
        IF (l_return_status <> FND_API.G_RET_STS_SUCCESS)
        THEN
            l_msg_data   := 'Failed generating XML data to the report output';
            RAISE FND_API.G_EXC_UNEXPECTED_ERROR;
        END IF;

        -- Print the XML data to the report output
        l_stmt_num        := 170;
        Print_ClobOutput (p_api_version => 1.0, p_init_msg_list => FND_API.G_FALSE, p_validation_level => FND_API.G_VALID_LEVEL_FULL, x_return_status => l_return_status, x_msg_count => l_msg_count, x_msg_data => l_msg_data
                          , p_xml_data => l_xml_report);

        -- If return status is not success, add message to the log
        IF (l_return_status <> FND_API.G_RET_STS_SUCCESS)
        THEN
            l_msg_data   := 'Failed writing XML data to the report output';
            RAISE FND_API.G_EXC_UNEXPECTED_ERROR;
        END IF;

        -- Write log messages to request log
        l_stmt_num        := 180;
        CST_UTILITY_PUB.writelogmessages (
            p_api_version     => 1.0,
            p_msg_count       => l_msg_count,
            p_msg_data        => l_msg_data,
            x_return_status   => l_return_status);

        -- If return status is not success, add message to the log
        IF (l_return_status <> FND_API.G_RET_STS_SUCCESS)
        THEN
            l_msg_data   := 'Failed writing log messages';
            RAISE FND_API.G_EXC_UNEXPECTED_ERROR;
        END IF;

        -- Procedure level log message for exit point
        IF (l_pLog)
        THEN
            FND_LOG.STRING (FND_LOG.LEVEL_PROCEDURE,
                            l_module || '.end',
                            'Start_Process >>');
        END IF;
    EXCEPTION
        WHEN FND_API.G_EXC_UNEXPECTED_ERROR
        THEN
            IF (l_exceptionLog)
            THEN
                FND_LOG.STRING (FND_LOG.LEVEL_EXCEPTION,
                                l_module || '.' || l_stmt_num,
                                l_msg_data);
            END IF;

            -- Write log messages to request log
            CST_UTILITY_PUB.writelogmessages (
                p_api_version     => 1.0,
                p_msg_count       => l_msg_count,
                p_msg_data        => l_msg_data,
                x_return_status   => l_return_status);

            -- Set concurrent program status to error
            l_conc_status   :=
                FND_CONCURRENT.SET_COMPLETION_STATUS ('ERROR', l_msg_data);
        WHEN OTHERS
        THEN
            -- Unexpected level log message for FND log
            IF (l_uLog)
            THEN
                FND_LOG.STRING (FND_LOG.LEVEL_UNEXPECTED,
                                l_module || '.' || l_stmt_num,
                                SQLERRM);
            END IF;

            IF FND_MSG_PUB.Check_Msg_Level (
                   FND_MSG_PUB.G_MSG_LVL_UNEXP_ERROR)
            THEN
                FND_MSG_PUB.Add_Exc_Msg (
                    G_PKG_NAME,
                    l_api_name,
                       '('
                    || TO_CHAR (l_stmt_num)
                    || ') : '
                    || SUBSTRB (SQLERRM, 1, 230));
            END IF;

            -- Write log messages to request log
            CST_UTILITY_PUB.writelogmessages (
                p_api_version     => 1.0,
                p_msg_count       => l_msg_count,
                p_msg_data        => l_msg_data,
                x_return_status   => l_return_status);

            -- Set concurrent program status to error
            l_conc_status   :=
                FND_CONCURRENT.SET_COMPLETION_STATUS (
                    'ERROR',
                    'An unexpected error has occurred, please contact System Administrator. ');
    END Start_Process;


    -----------------------------------------------------------------------------
    -- PROCEDURE    :   Generate_XML
    -- DESCRIPTION  :   The procedure generates and returns the XML data for
    --                  the reference cursor passed by the calling API.
    -----------------------------------------------------------------------------
    PROCEDURE Generate_XML (p_api_version IN NUMBER, p_init_msg_list IN VARCHAR2, p_validation_level IN NUMBER, x_return_status OUT NOCOPY VARCHAR2, x_msg_count OUT NOCOPY NUMBER, x_msg_data OUT NOCOPY VARCHAR2, p_ref_cur IN SYS_REFCURSOR, p_row_tag IN VARCHAR2, p_row_set_tag IN VARCHAR2
                            , x_xml_data OUT NOCOPY CLOB)
    IS
        l_api_name      CONSTANT VARCHAR2 (30) := 'Generate_XML';
        l_api_version   CONSTANT NUMBER := 1.0;
        l_return_status          VARCHAR2 (1);
        l_full_name     CONSTANT VARCHAR2 (60)
                                     := G_PKG_NAME || '.' || l_api_name ;
        l_module        CONSTANT VARCHAR2 (60) := 'cst.plsql.' || l_full_name;

        l_uLog          CONSTANT BOOLEAN
            :=     FND_LOG.TEST (FND_LOG.LEVEL_UNEXPECTED, l_module)
               AND (FND_LOG.LEVEL_UNEXPECTED >= G_LOG_LEVEL) ;
        l_pLog          CONSTANT BOOLEAN
            := l_uLog AND (FND_LOG.LEVEL_PROCEDURE >= G_LOG_LEVEL) ;
        l_sLog          CONSTANT BOOLEAN
            := l_pLog AND (FND_LOG.LEVEL_STATEMENT >= G_LOG_LEVEL) ;

        l_stmt_num               NUMBER;
        l_ctx                    DBMS_XMLGEN.CTXHANDLE;
    BEGIN
        l_stmt_num        := 0;

        -- Procedure level log message for Entry point
        IF (l_pLog)
        THEN
            FND_LOG.STRING (FND_LOG.LEVEL_PROCEDURE,
                            l_module || '.begin',
                            'Generate_XML <<');
        END IF;

        -- Standard call to check for call compatibility.
        IF NOT FND_API.Compatible_API_Call (l_api_version, p_api_version, l_api_name
                                            , G_PKG_NAME)
        THEN
            RAISE FND_API.G_EXC_UNEXPECTED_ERROR;
        END IF;

        -- Initialize message list if p_init_msg_list is set to TRUE.
        IF FND_API.to_Boolean (p_init_msg_list)
        THEN
            FND_MSG_PUB.initialize;
        END IF;

        --  Initialize API return status to success
        x_return_status   := FND_API.G_RET_STS_SUCCESS;
        l_return_status   := FND_API.G_RET_STS_SUCCESS;

        -- create a new context with the SQL query
        l_stmt_num        := 10;
        l_ctx             := DBMS_XMLGEN.newContext (p_ref_cur);

        -- Add tag names for rows and row sets
        l_stmt_num        := 20;
        DBMS_XMLGEN.setRowSetTag (l_ctx, p_row_tag);
        DBMS_XMLGEN.setRowTag (l_ctx, p_row_set_tag);

        -- generate XML data
        l_stmt_num        := 30;
        x_xml_data        := DBMS_XMLGEN.getXML (l_ctx);

        -- close the context
        l_stmt_num        := 40;
        DBMS_XMLGEN.CLOSECONTEXT (l_ctx);

        -- Procedure level log message for exit point
        IF (l_pLog)
        THEN
            FND_LOG.STRING (FND_LOG.LEVEL_PROCEDURE,
                            l_module || '.end',
                            'Generate_XML >>');
        END IF;

        -- Get message count and if 1, return message data.
        FND_MSG_PUB.Count_And_Get (p_count   => x_msg_count,
                                   p_data    => x_msg_data);
    EXCEPTION
        WHEN FND_API.G_EXC_UNEXPECTED_ERROR
        THEN
            x_return_status   := FND_API.G_RET_STS_UNEXP_ERROR;

            FND_MSG_PUB.Count_And_Get (p_count   => x_msg_count,
                                       p_data    => x_msg_data);
        WHEN OTHERS
        THEN
            x_return_status   := FND_API.G_RET_STS_UNEXP_ERROR;

            -- Unexpected level log message
            IF (l_uLog)
            THEN
                FND_LOG.STRING (FND_LOG.LEVEL_UNEXPECTED,
                                l_module || '.' || l_stmt_num,
                                SQLERRM);
            END IF;

            IF FND_MSG_PUB.Check_Msg_Level (
                   FND_MSG_PUB.G_MSG_LVL_UNEXP_ERROR)
            THEN
                FND_MSG_PUB.Add_Exc_Msg (
                    G_PKG_NAME,
                    l_api_name,
                       '('
                    || TO_CHAR (l_stmt_num)
                    || ') : '
                    || SUBSTRB (SQLERRM, 1, 230));
            END IF;

            FND_MSG_PUB.Count_And_Get (p_count   => x_msg_count,
                                       p_data    => x_msg_data);
    END Generate_XML;

    -----------------------------------------------------------------------------
    -- PROCEDURE    :   Merge_XML
    -- DESCRIPTION  :   The procedure merges data from two XML objects into a
    --                  single XML object and adds a root tag to the resultant
    --                  XML data.
    -----------------------------------------------------------------------------
    PROCEDURE Merge_XML (p_api_version IN NUMBER, p_init_msg_list IN VARCHAR2, p_validation_level IN NUMBER, x_return_status OUT NOCOPY VARCHAR2, x_msg_count OUT NOCOPY NUMBER, x_msg_data OUT NOCOPY VARCHAR2, p_xml_src1 IN CLOB, p_xml_src2 IN CLOB, p_root_tag IN VARCHAR2
                         , x_xml_doc OUT NOCOPY CLOB)
    IS
        l_api_name      CONSTANT VARCHAR2 (30) := 'Merge_XML';
        l_api_version   CONSTANT NUMBER := 1.0;
        l_return_status          VARCHAR2 (1);
        l_full_name     CONSTANT VARCHAR2 (60)
                                     := G_PKG_NAME || '.' || l_api_name ;
        l_module        CONSTANT VARCHAR2 (60) := 'cst.plsql.' || l_full_name;

        l_uLog          CONSTANT BOOLEAN
            :=     FND_LOG.TEST (FND_LOG.LEVEL_UNEXPECTED, l_module)
               AND (FND_LOG.LEVEL_UNEXPECTED >= G_LOG_LEVEL) ;
        l_pLog          CONSTANT BOOLEAN
            := l_uLog AND (FND_LOG.LEVEL_PROCEDURE >= G_LOG_LEVEL) ;
        l_sLog          CONSTANT BOOLEAN
            := l_pLog AND (FND_LOG.LEVEL_STATEMENT >= G_LOG_LEVEL) ;

        l_ctx                    DBMS_XMLGEN.CTXHANDLE;
        l_offset                 NUMBER;
        l_stmt_num               NUMBER;
        l_length_src1            NUMBER;
        l_length_src2            NUMBER;
        /*Bug 7282242*/
        l_encoding               VARCHAR2 (20);
        l_xml_header             VARCHAR2 (100);
    BEGIN
        l_stmt_num        := 0;

        -- Procedure level log message for Entry point
        IF (l_pLog)
        THEN
            FND_LOG.STRING (FND_LOG.LEVEL_PROCEDURE,
                            l_module || '.begin',
                            'Merge_XML <<');
        END IF;

        -- Standard call to check for call compatibility.
        IF NOT FND_API.Compatible_API_Call (l_api_version, p_api_version, l_api_name
                                            , G_PKG_NAME)
        THEN
            RAISE FND_API.G_EXC_UNEXPECTED_ERROR;
        END IF;

        -- Initialize message list if p_init_msg_list is set to TRUE.
        IF FND_API.to_Boolean (p_init_msg_list)
        THEN
            FND_MSG_PUB.initialize;
        END IF;

        --  Initialize API return status to success
        x_return_status   := FND_API.G_RET_STS_SUCCESS;
        l_return_status   := FND_API.G_RET_STS_SUCCESS;

        l_stmt_num        := 10;
        l_length_src1     := DBMS_LOB.GETLENGTH (p_xml_src1);
        l_length_src2     := DBMS_LOB.GETLENGTH (p_xml_src2);

        l_stmt_num        := 20;
        DBMS_LOB.createtemporary (x_xml_doc, TRUE);

        IF (l_length_src1 > 0)
        THEN
            -- Get the first occurence of XML header
            l_stmt_num     := 30;
            l_offset       :=
                DBMS_LOB.INSTR (lob_loc => p_xml_src1, pattern => '>', offset => 1
                                , nth => 1);

            -- Copy XML header part to the destination XML doc
            l_stmt_num     := 40;

            /*Bug 7282242*/
            /*Remove the header (21 characters)*/
            --DBMS_LOB.copy (x_xml_doc, p_xml_src1, l_offset + 1);

            /*The following 3 lines of code ensures that XML data generated here uses the right encoding*/
            l_encoding     := fnd_profile.VALUE ('ICX_CLIENT_IANA_ENCODING');
            l_xml_header   :=
                '<?xml version="1.0" encoding="' || l_encoding || '"?>';
            DBMS_LOB.writeappend (x_xml_doc,
                                  LENGTH (l_xml_header),
                                  l_xml_header);

            -- Append the root tag to the XML doc
            l_stmt_num     := 50;
            DBMS_LOB.writeappend (x_xml_doc,
                                  LENGTH (p_root_tag) + 2,
                                  '<' || p_root_tag || '>');

            -- Append the 1st XML doc to the destination XML doc
            l_stmt_num     := 60;
            DBMS_LOB.COPY (x_xml_doc, p_xml_src1, l_length_src1 - l_offset,
                           DBMS_LOB.GETLENGTH (x_xml_doc) + 1, l_offset + 1);

            -- Append the 2nd XML doc to the destination XML doc
            IF (l_length_src2 > 0)
            THEN
                l_stmt_num   := 70;
                DBMS_LOB.COPY (x_xml_doc,
                               p_xml_src2,
                               l_length_src2 - l_offset,
                               DBMS_LOB.GETLENGTH (x_xml_doc) + 1,
                               l_offset + 1);
            END IF;

            -- Append the root tag to the end of XML doc
            l_stmt_num     := 80;
            DBMS_LOB.writeappend (x_xml_doc,
                                  LENGTH (p_root_tag) + 3,
                                  '</' || p_root_tag || '>');
        END IF;

        -- Procedure level log message for exit point
        IF (l_pLog)
        THEN
            FND_LOG.STRING (FND_LOG.LEVEL_PROCEDURE,
                            l_module || '.end',
                            'Merge_XML >>');
        END IF;

        -- Get message count and if 1, return message data.
        FND_MSG_PUB.Count_And_Get (p_count   => x_msg_count,
                                   p_data    => x_msg_data);
    EXCEPTION
        WHEN FND_API.G_EXC_UNEXPECTED_ERROR
        THEN
            x_return_status   := FND_API.G_RET_STS_UNEXP_ERROR;

            FND_MSG_PUB.Count_And_Get (p_count   => x_msg_count,
                                       p_data    => x_msg_data);
        WHEN OTHERS
        THEN
            x_return_status   := FND_API.G_RET_STS_UNEXP_ERROR;

            -- Unexpected level log message
            IF (l_uLog)
            THEN
                FND_LOG.STRING (FND_LOG.LEVEL_UNEXPECTED,
                                l_module || '.' || l_stmt_num,
                                SQLERRM);
            END IF;

            IF FND_MSG_PUB.Check_Msg_Level (
                   FND_MSG_PUB.G_MSG_LVL_UNEXP_ERROR)
            THEN
                FND_MSG_PUB.Add_Exc_Msg (
                    G_PKG_NAME,
                    l_api_name,
                       '('
                    || TO_CHAR (l_stmt_num)
                    || ') : '
                    || SUBSTRB (SQLERRM, 1, 230));
            END IF;

            FND_MSG_PUB.Count_And_Get (p_count   => x_msg_count,
                                       p_data    => x_msg_data);
    END Merge_XML;

    -----------------------------------------------------------------------------
    -- PROCEDURE    :   Merge_XML
    -- DESCRIPTION  :   The procedure writes the XML data to the report output
    --                  file. The XML publisher picks the data from this output
    --                  file to display the data in user specified format.
    -----------------------------------------------------------------------------
    PROCEDURE Print_ClobOutput (p_api_version IN NUMBER, p_init_msg_list IN VARCHAR2, p_validation_level IN NUMBER, x_return_status OUT NOCOPY VARCHAR2, x_msg_count OUT NOCOPY NUMBER, x_msg_data OUT NOCOPY VARCHAR2
                                , p_xml_data IN CLOB)
    IS
        l_api_name      CONSTANT VARCHAR2 (30) := 'Print_ClobOutput';
        l_api_version   CONSTANT NUMBER := 1.0;
        l_return_status          VARCHAR2 (1);
        l_full_name     CONSTANT VARCHAR2 (60)
                                     := G_PKG_NAME || '.' || l_api_name ;
        l_module        CONSTANT VARCHAR2 (60) := 'cst.plsql.' || l_full_name;

        l_uLog          CONSTANT BOOLEAN
            :=     FND_LOG.TEST (FND_LOG.LEVEL_UNEXPECTED, l_module)
               AND (FND_LOG.LEVEL_UNEXPECTED >= G_LOG_LEVEL) ;
        l_pLog          CONSTANT BOOLEAN
            := l_uLog AND (FND_LOG.LEVEL_PROCEDURE >= G_LOG_LEVEL) ;
        l_sLog          CONSTANT BOOLEAN
            := l_pLog AND (FND_LOG.LEVEL_STATEMENT >= G_LOG_LEVEL) ;

        l_stmt_num               NUMBER;
        l_amount                 NUMBER;
        l_offset                 NUMBER;
        l_length                 NUMBER;
        l_data                   VARCHAR2 (32767);
    BEGIN
        l_stmt_num        := 0;

        -- Procedure level log message for Entry point
        IF (l_pLog)
        THEN
            FND_LOG.STRING (FND_LOG.LEVEL_PROCEDURE,
                            l_module || '.begin',
                            'Print_ClobOutput <<');
        END IF;

        -- Standard call to check for call compatibility.
        IF NOT FND_API.Compatible_API_Call (l_api_version, p_api_version, l_api_name
                                            , G_PKG_NAME)
        THEN
            RAISE FND_API.G_EXC_UNEXPECTED_ERROR;
        END IF;

        -- Initialize message list if p_init_msg_list is set to TRUE.
        IF FND_API.to_Boolean (p_init_msg_list)
        THEN
            FND_MSG_PUB.initialize;
        END IF;

        --  Initialize API return status to success
        x_return_status   := FND_API.G_RET_STS_SUCCESS;
        l_return_status   := FND_API.G_RET_STS_SUCCESS;

        -- Get length of the CLOB p_xml_data
        l_stmt_num        := 10;
        l_length          := NVL (DBMS_LOB.getlength (p_xml_data), 0);

        -- Set the offset point to be the start of the CLOB data
        l_offset          := 1;

        -- l_amount will be used to read 32KB of data once at a time
        l_amount          := 16383;                  --Changed for bug 6954937

        -- Loop until the length of CLOB data is zero
        l_stmt_num        := 20;

        LOOP
            EXIT WHEN l_length <= 0;

            -- Read 32 KB of data and print it to the report output
            DBMS_LOB.read (p_xml_data, l_amount, l_offset,
                           l_data);

            FND_FILE.PUT (FND_FILE.OUTPUT, l_data);

            l_length   := l_length - l_amount;
            l_offset   := l_offset + l_amount;
        END LOOP;

        -- Procedure level log message for exit point
        IF (l_pLog)
        THEN
            FND_LOG.STRING (FND_LOG.LEVEL_PROCEDURE,
                            l_module || '.end',
                            'Print_ClobOutput >>');
        END IF;

        -- Get message count and if 1, return message data.
        FND_MSG_PUB.Count_And_Get (p_count   => x_msg_count,
                                   p_data    => x_msg_data);
    EXCEPTION
        WHEN FND_API.G_EXC_UNEXPECTED_ERROR
        THEN
            x_return_status   := FND_API.G_RET_STS_UNEXP_ERROR;

            FND_MSG_PUB.Count_And_Get (p_count   => x_msg_count,
                                       p_data    => x_msg_data);
        WHEN OTHERS
        THEN
            x_return_status   := FND_API.G_RET_STS_UNEXP_ERROR;

            -- Unexpected level log message
            IF (l_uLog)
            THEN
                FND_LOG.STRING (FND_LOG.LEVEL_UNEXPECTED,
                                l_module || '.' || l_stmt_num,
                                SQLERRM);
            END IF;

            IF FND_MSG_PUB.Check_Msg_Level (
                   FND_MSG_PUB.G_MSG_LVL_UNEXP_ERROR)
            THEN
                FND_MSG_PUB.Add_Exc_Msg (
                    G_PKG_NAME,
                    l_api_name,
                       '('
                    || TO_CHAR (l_stmt_num)
                    || ') : '
                    || SUBSTRB (SQLERRM, 1, 230));
            END IF;

            FND_MSG_PUB.Count_And_Get (p_count   => x_msg_count,
                                       p_data    => x_msg_data);
    END Print_ClobOutput;
END XXD_BOM_UNINV_RPT_PKG;
/
