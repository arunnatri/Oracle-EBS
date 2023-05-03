--
-- XXDOAR_INVDETREG_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:17 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOAR_INVDETREG_PKG"
IS
    --------------------------------------------------------------------------------
    -- Created By : Vijaya Reddy ( Sunera Technologies )
    -- Creation Date : 14-SEP-2011
    -- File Name : XXDOAR019
    -- Work Order Num : Invoice Details Register - Deckers
    -- Incident INC0094675
    -- Enhancement ENHC0010241
    -- Description :
    -- Latest Version : 3.0
    --
    -- Revision History:
    -- =============================================================================
    -- Date Version# Name Remarks
    -- =============================================================================
    -- 14-SEP-2011 1.0 Vijaya Reddy Initial development.
    --01-MAY-2012 2.1 Shibu Alex have to add Macau Cost and Material Cost
    --9-Jul-2013 2.2 Murali Bachina Added Employee Order Classification
    --11-Sep-2013 2.3 Madhav Dhurjaty   Added function get_vat_number and new field zip_code
    --29-Dec-2014 3.0 BT Technology Team Retrofitted
    --26-Aug-2015 3.1 BT Technology Team CR 120
    --12-Nov-2015 3.2 BT Technology Team for UAT2 570
    --17-Dec-2015 3.3 BT Technology Team for UAT2 785
    --10-MAY-2016 3.4 BT Dev Team for Revenue amount fix
    --17-MAY-2016 3.5 BT Dev Team for Functional revenue amount fix and removing tabs from data.
    --03-AUG-2016 3.6 Infosys Added SHIP_TO_CITY column
    --10-SEP-2016 3.7 Infosys Modified for DFCT0011428 Functional Total amount
    --26-NOV-2018 4.0 Madhav Dhurjaty   Modified for CCR0007628 - IDR Delivery
    --20-MAR-2020 4.1 Greg Jensen Modified for Global-e project
    --26-MAY-2020 4.2 Showkath Modified for CCR0008574 to add Average Margin to the report.
    -------------------------------------------------------------------------------
    --Start Changes by BT tech team on 13-Nov-15 for defect# 570
    gc_delimeter   VARCHAR2 (10) := ' | ';

    --Start Changes by BT tech team on 18-Nov-15 for defect# 570
    FUNCTION get_account (p_trx_id       IN NUMBER,
                          p_sob_id       IN NUMBER,
                          p_gl_dist_id   IN NUMBER)
        RETURN VARCHAR2
    AS
        lc_cc   VARCHAR2 (200);
    BEGIN
        SELECT glc.concatenated_segments
          INTO lc_cc
          FROM xla.xla_ae_lines xal, xla.xla_ae_headers xah, xla.xla_transaction_entities xte,
               xla_distribution_links xdl, gl_code_combinations_kfv glc
         WHERE     xal.ae_header_id = xah.ae_header_id
               AND xal.application_id = xah.application_id
               AND xte.entity_id = xah.entity_id
               AND xte.entity_code = 'TRANSACTIONS'
               AND xte.ledger_id = xal.ledger_id
               AND xte.application_id = xal.application_id
               AND xdl.ae_line_num = xal.ae_line_num
               AND xal.code_combination_id = glc.code_combination_id
               AND NVL (xte.source_id_int_1, -99) = p_trx_id --rcta.customer_trx_id
               AND xal.ae_header_id = xdl.ae_header_id
               AND xah.ae_header_id = xdl.ae_header_id
               AND xdl.source_distribution_id_num_1 = p_gl_dist_id --rctd.cust_trx_line_gl_dist_id
               AND xal.ledger_id = p_sob_id;

        RETURN lc_cc;
    EXCEPTION
        WHEN OTHERS
        THEN
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'Exception in get_account' || SQLERRM);
            RETURN NULL;
    END get_account;

    --End Changes by BT tech team on 18-Nov-15 for defect# 570
    FUNCTION get_tax_details (p_trx_id        IN NUMBER,
                              p_trx_line_id   IN NUMBER,
                              p_mode          IN VARCHAR2)
        RETURN VARCHAR2
    AS
        CURSOR get_tax_amt_c IS
            SELECT SUM (tax_amt)
              FROM zx_lines
             WHERE     trx_id = p_trx_id
                   AND trx_line_id = p_trx_line_id
                   AND application_id = 222;

        CURSOR get_tax_rate_c IS
            SELECT SUM (tax_rate)
              FROM zx_lines
             WHERE     trx_id = p_trx_id
                   AND trx_line_id = p_trx_line_id
                   AND application_id = 222;

        CURSOR get_tax_rate_code_c IS
              SELECT tax_rate_code
                FROM zx_lines
               WHERE     trx_id = p_trx_id
                     AND trx_line_id = p_trx_line_id
                     AND application_id = 222
            ORDER BY tax_rate_code;

        ln_ret_value   VARCHAR2 (300);
    BEGIN
        ln_ret_value   := NULL;

        IF p_mode = 'TAX_RATE_CODE'
        THEN
            FOR lc_tax_rate_code IN get_tax_rate_code_c
            LOOP
                ln_ret_value   :=
                       ln_ret_value
                    || gc_delimeter
                    || lc_tax_rate_code.tax_rate_code;
            END LOOP;

            SELECT SUBSTR (ln_ret_value, 4) INTO ln_ret_value FROM DUAL;
        ELSIF p_mode = 'TAX_RATE'
        THEN
            OPEN get_tax_rate_c;

            FETCH get_tax_rate_c INTO ln_ret_value;

            CLOSE get_tax_rate_c;
        ELSIF p_mode = 'TAX_AMOUNT'
        THEN
            OPEN get_tax_amt_c;

            FETCH get_tax_amt_c INTO ln_ret_value;

            CLOSE get_tax_amt_c;

            ln_ret_value   := NVL (ln_ret_value, 0);
        END IF;

        RETURN ln_ret_value;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Error in get_tax_details' || SQLERRM);
            RETURN NULL;
    END get_tax_details;

    --End Changes by BT tech team on 13-Nov-15 for defect# 570

    -- Start changes by BT Technology Team v4.0 on 31-Dec-2014
    FUNCTION get_parent_ord_det (pn_so_line_id   NUMBER,
                                 pn_org_id       NUMBER,
                                 pv_col          VARCHAR2)
        RETURN VARCHAR2
    IS
        l_return   VARCHAR2 (100);
    BEGIN
        IF pv_col = 'OO'
        THEN
            BEGIN
                SELECT ooha1.order_number
                  INTO l_return
                  FROM apps.oe_order_headers_all ooha1, apps.oe_order_lines_all oola
                 WHERE     oola.reference_header_id = ooha1.header_id
                       AND oola.line_id = pn_so_line_id
                       AND oola.org_id = pn_org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_return   := NULL;
            END;
        ELSIF pv_col = 'OSD'
        THEN
            BEGIN
                SELECT oola1.actual_shipment_date
                  INTO l_return
                  FROM apps.oe_order_lines_all oola1, apps.oe_order_lines_all oola
                 WHERE     oola.line_id = pn_so_line_id
                       AND oola.org_id = pn_org_id
                       AND oola.reference_line_id = oola1.line_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_return   := NULL;
            END;
        ELSIF pv_col = 'OI'
        THEN
            BEGIN
                SELECT /*+ index(rtl1  DO_RA_CUST_TRX_LINES_ALL_N1 , rtl1 RA_CUSTOMER_TRX_LINES_N9)  */
                       rt1.trx_number
                  INTO l_return
                  FROM apps.ra_customer_trx_lines_all rtl1, apps.ra_customer_trx_all rt1, apps.oe_order_lines_all oola,
                       apps.oe_order_headers_all ooha1
                 WHERE     oola.reference_header_id = ooha1.header_id
                       AND rt1.customer_trx_id = rtl1.customer_trx_id
                       AND rtl1.interface_line_attribute6 =
                           TO_CHAR (oola.reference_line_id)
                       AND rtl1.interface_line_attribute1 =
                           TO_CHAR (ooha1.order_number)
                       AND rtl1.org_id = ooha1.org_id
                       AND oola.reference_line_id IS NOT NULL
                       AND rtl1.sales_order IS NOT NULL
                       AND rtl1.interface_line_attribute6 IS NOT NULL
                       AND rtl1.interface_line_attribute1 IS NOT NULL
                       AND rtl1.sales_order = ooha1.order_number
                       AND oola.line_id = pn_so_line_id
                       AND oola.org_id = pn_org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_return   := NULL;
            END;
        END IF;

        RETURN l_return;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_parent_ord_det;

    FUNCTION get_mmt_cost (pn_interface_line_attribute6 VARCHAR2, pn_interface_line_attribute7 VARCHAR2, pn_organization_id NUMBER
                           , pn_sob_id NUMBER, -- Added by BT Tech Team for defect# 570 on 17-Nov-15
                                               pv_detail IN VARCHAR)
        RETURN NUMBER
    IS
        ln_cost     NUMBER;
        ln_sob_id   NUMBER; -- Added by BT Tech Team for defect# 785 on 09-Dec-15
    BEGIN
        -- Started by BT Tech Team for defect# 785 on 09-Dec-15
        IF pn_organization_id IS NOT NULL
        THEN
            BEGIN
                SELECT set_of_books_id
                  INTO ln_sob_id
                  FROM org_organization_definitions
                 WHERE organization_id = pn_organization_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_sob_id   := pn_sob_id;
            END;
        ELSE
            ln_sob_id   := pn_sob_id;
        END IF;

        -- Ended by BT Tech Team for defect# 785 on 09-Dec-15
        IF NVL (pn_interface_line_attribute7, 0) = 0
        THEN
            IF pv_detail = 'TRANSCOST'
            THEN
                BEGIN
                    SELECT ROUND (NVL (transaction_cost, actual_cost), 2)
                      INTO ln_cost
                      FROM apps.mtl_material_transactions
                     WHERE     transaction_id IN
                                   (SELECT transaction_id
                                      FROM apps.mtl_material_transactions mmto
                                     WHERE mmto.trx_source_line_id =
                                           pn_interface_line_attribute6 --ola lineid
                                                                       )
                           AND organization_id = pn_organization_id
                           AND transaction_type_id IN (33, 62);

                    RETURN ln_cost;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_cost   := 0;
                    WHEN OTHERS
                    THEN
                        ln_cost   := 0;
                        RETURN ln_cost;
                END;
            ELSE
                IF pv_detail = 'COGSCCID'
                THEN
                    BEGIN
                          SELECT MAX (xal.code_combination_id)
                            INTO ln_cost
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
                                                                     pn_interface_line_attribute6 --ola lineid
                                                                                                 ))
                                         AND source_distribution_type =
                                             'MTL_TRANSACTION_ACCOUNTS' --and event_class_code = 'SALES_ORDER'
                                                                       ) aa
                           WHERE     aa.application_id = xal.application_id
                                 AND                                     --707
                                     aa.ae_header_id = xal.ae_header_id
                                 AND aa.ae_line_num = xal.ae_line_num
                                 AND xal.accounting_class_code IN
                                         ('OFFSET', 'COST_OF_GOODS_SOLD')
                                 --AND xal.ledger_id = pn_sob_id -- Added by BT Tech Team for defect# 570 on 17-Nov-15
                                 AND xal.ledger_id = ln_sob_id -- Added by BT Tech Team for defect# 785 on 09-Dec-15
                        GROUP BY xal.code_combination_id;

                        RETURN ln_cost;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            ln_cost   := 0;
                        WHEN OTHERS
                        THEN
                            ln_cost   := 0;
                            RETURN ln_cost;
                    END;
                ELSE
                    IF pv_detail = 'COGSAMT'
                    THEN
                        BEGIN
                              SELECT SUM (NVL (entered_dr, 0) - NVL (entered_cr, 0))
                                INTO ln_cost
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
                                                                         pn_interface_line_attribute6 --ola lineid
                                                                                                     ))
                                             AND source_distribution_type =
                                                 'MTL_TRANSACTION_ACCOUNTS' --and event_class_code = 'SALES_ORDER'
                                                                           ) aa
                               WHERE     aa.application_id = xal.application_id
                                     AND aa.ae_header_id = xal.ae_header_id
                                     AND aa.ae_line_num = xal.ae_line_num
                                     AND xal.accounting_class_code IN
                                             ('OFFSET', 'COST_OF_GOODS_SOLD')
                                     --AND xal.ledger_id = pn_sob_id -- Added by BT Tech Team for defect# 570 on 17-Nov-15
                                     AND xal.ledger_id = ln_sob_id -- Added by BT Tech Team for defect# 785 on 09-Dec-15
                            GROUP BY xal.code_combination_id;

                            RETURN ln_cost;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                ln_cost   := 0;
                            WHEN OTHERS
                            THEN
                                ln_cost   := 0;
                                RETURN ln_cost;
                        END;
                    ELSE
                        IF pv_detail = 'MATAMT'
                        THEN
                            BEGIN
                                  SELECT SUM (NVL (entered_dr, 0) - NVL (entered_cr, 0))
                                    INTO ln_cost
                                    FROM apps.xla_ae_lines xal,
                                         (SELECT application_id, event_id, ae_header_id,
                                                 ae_line_num
                                            FROM apps.xla_distribution_links
                                           WHERE     source_distribution_id_num_1 IN
                                                         (SELECT inv_sub_ledger_id
                                                            FROM apps.mtl_transaction_accounts
                                                           WHERE     transaction_id IN
                                                                         (SELECT transaction_id
                                                                            FROM apps.mtl_material_transactions mmto
                                                                           WHERE mmto.trx_source_line_id =
                                                                                 pn_interface_line_attribute6 --ola lineid
                                                                                                             )
                                                                 AND cost_element_id =
                                                                     1)
                                                 AND source_distribution_type =
                                                     'MTL_TRANSACTION_ACCOUNTS' --and event_class_code = 'SALES_ORDER'
                                                                               )
                                         aa
                                   WHERE     aa.application_id =
                                             xal.application_id
                                         AND aa.ae_header_id = xal.ae_header_id
                                         AND aa.ae_line_num = xal.ae_line_num
                                         AND xal.accounting_class_code IN
                                                 ('OFFSET', 'COST_OF_GOODS_SOLD')
                                         --AND xal.ledger_id = pn_sob_id -- Added by BT Tech Team for defect# 570 on 17-Nov-15
                                         AND xal.ledger_id = ln_sob_id -- Added by BT Tech Team for defect# 785 on 09-Dec-15
                                GROUP BY xal.code_combination_id;

                                RETURN ln_cost;
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    ln_cost   := 0;
                                WHEN OTHERS
                                THEN
                                    ln_cost   := 0;
                                    RETURN ln_cost;
                            END;
                        ELSE
                            IF pv_detail = 'INVMAT'
                            THEN
                                BEGIN
                                      SELECT SUM (NVL (entered_dr, 0) - NVL (entered_cr, 0))
                                        INTO ln_cost
                                        FROM apps.xla_ae_lines xal,
                                             (SELECT application_id, event_id, ae_header_id,
                                                     ae_line_num
                                                FROM apps.xla_distribution_links
                                               WHERE     source_distribution_id_num_1 IN
                                                             (SELECT inv_sub_ledger_id
                                                                FROM apps.mtl_transaction_accounts
                                                               WHERE     transaction_id IN
                                                                             (SELECT transaction_id
                                                                                FROM apps.mtl_material_transactions mmto
                                                                               WHERE mmto.trx_source_line_id =
                                                                                     pn_interface_line_attribute6 --ola lineid
                                                                                                                 )
                                                                     AND cost_element_id =
                                                                         1)
                                                     AND source_distribution_type =
                                                         'MTL_TRANSACTION_ACCOUNTS' --and event_class_code = 'SALES_ORDER'
                                                                                   )
                                             aa
                                       WHERE     aa.application_id =
                                                 xal.application_id
                                             AND aa.ae_header_id =
                                                 xal.ae_header_id
                                             AND aa.ae_line_num =
                                                 xal.ae_line_num
                                             AND xal.accounting_class_code =
                                                 'INVENTORY_VALUATION'
                                             --AND xal.ledger_id = pn_sob_id -- Added by BT Tech Team for defect# 570 on 17-Nov-15
                                             AND xal.ledger_id = ln_sob_id -- Added by BT Tech Team for defect# 785 on 09-Dec-15
                                    GROUP BY xal.code_combination_id;

                                    RETURN ln_cost;
                                EXCEPTION
                                    WHEN NO_DATA_FOUND
                                    THEN
                                        ln_cost   := 0;
                                    WHEN OTHERS
                                    THEN
                                        ln_cost   := 0;
                                        RETURN ln_cost;
                                END;
                            ELSE
                                IF pv_detail = 'INVAMT'
                                THEN
                                    BEGIN
                                          SELECT SUM (NVL (entered_dr, 0) - NVL (entered_cr, 0))
                                            INTO ln_cost
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
                                                                                     pn_interface_line_attribute6 --ola lineid
                                                                                                                 ))
                                                         AND source_distribution_type =
                                                             'MTL_TRANSACTION_ACCOUNTS' --and event_class_code = 'SALES_ORDER'
                                                                                       )
                                                 aa
                                           WHERE     aa.application_id =
                                                     xal.application_id
                                                 AND aa.ae_header_id =
                                                     xal.ae_header_id
                                                 AND aa.ae_line_num =
                                                     xal.ae_line_num
                                                 AND xal.accounting_class_code =
                                                     'INVENTORY_VALUATION'
                                                 --AND xal.ledger_id = pn_sob_id -- Added by BT Tech Team for defect# 570 on 17-Nov-15
                                                 AND xal.ledger_id = ln_sob_id -- Added by BT Tech Team for defect# 785 on 09-Dec-15
                                        GROUP BY xal.code_combination_id;

                                        RETURN ln_cost;
                                    EXCEPTION
                                        WHEN NO_DATA_FOUND
                                        THEN
                                            ln_cost   := 0;
                                        WHEN OTHERS
                                        THEN
                                            ln_cost   := 0;
                                            RETURN ln_cost;
                                    END;
                                END IF;
                            END IF;
                        END IF;
                    END IF;
                END IF;
            END IF;
        ELSE
            IF pv_detail = 'TRANSCOST'
            THEN
                BEGIN
                    SELECT ROUND (NVL (transaction_cost, actual_cost), 2)
                      INTO ln_cost
                      FROM apps.mtl_material_transactions
                     WHERE     transaction_id = pn_interface_line_attribute7
                           AND organization_id = pn_organization_id
                           AND transaction_type_id IN (33, 62);

                    RETURN ln_cost;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_cost   := 0;
                    WHEN OTHERS
                    THEN
                        ln_cost   := 0;
                        RETURN ln_cost;
                END;
            ELSE
                IF pv_detail = 'COGSCCID'
                THEN
                    BEGIN
                          SELECT MAX (xal.code_combination_id)
                            INTO ln_cost
                            FROM apps.xla_ae_lines xal,
                                 (SELECT application_id, event_id, ae_header_id,
                                         ae_line_num
                                    FROM apps.xla_distribution_links
                                   WHERE     source_distribution_id_num_1 IN
                                                 (SELECT inv_sub_ledger_id
                                                    FROM apps.mtl_transaction_accounts
                                                   WHERE transaction_id =
                                                         pn_interface_line_attribute7)
                                         AND source_distribution_type =
                                             'MTL_TRANSACTION_ACCOUNTS' --and event_class_code = 'SALES_ORDER'
                                                                       ) aa
                           WHERE     aa.application_id = xal.application_id
                                 AND                                     --707
                                     aa.ae_header_id = xal.ae_header_id
                                 AND aa.ae_line_num = xal.ae_line_num
                                 AND xal.accounting_class_code IN
                                         ('OFFSET', 'COST_OF_GOODS_SOLD')
                                 --AND xal.ledger_id = pn_sob_id -- Added by BT Tech Team for defect# 570 on 17-Nov-15
                                 AND xal.ledger_id = ln_sob_id -- Added by BT Tech Team for defect# 785 on 09-Dec-15
                        GROUP BY xal.code_combination_id;

                        RETURN ln_cost;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            ln_cost   := 0;
                        WHEN OTHERS
                        THEN
                            ln_cost   := 0;
                            RETURN ln_cost;
                    END;
                ELSE
                    IF pv_detail = 'COGSAMT'
                    THEN
                        BEGIN
                              SELECT SUM (NVL (entered_dr, 0) - NVL (entered_cr, 0))
                                INTO ln_cost
                                FROM apps.xla_ae_lines xal,
                                     (SELECT application_id, event_id, ae_header_id,
                                             ae_line_num
                                        FROM apps.xla_distribution_links
                                       WHERE     source_distribution_id_num_1 IN
                                                     (SELECT inv_sub_ledger_id
                                                        FROM apps.mtl_transaction_accounts
                                                       WHERE transaction_id =
                                                             pn_interface_line_attribute7)
                                             AND source_distribution_type =
                                                 'MTL_TRANSACTION_ACCOUNTS' --and event_class_code = 'SALES_ORDER'
                                                                           ) aa
                               WHERE     aa.application_id = xal.application_id
                                     AND aa.ae_header_id = xal.ae_header_id
                                     AND aa.ae_line_num = xal.ae_line_num
                                     AND xal.accounting_class_code IN
                                             ('OFFSET', 'COST_OF_GOODS_SOLD')
                                     --AND xal.ledger_id = pn_sob_id -- Added by BT Tech Team for defect# 570 on 17-Nov-15
                                     AND xal.ledger_id = ln_sob_id -- Added by BT Tech Team for defect# 785 on 09-Dec-15
                            GROUP BY xal.code_combination_id;

                            RETURN ln_cost;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                ln_cost   := 0;
                            WHEN OTHERS
                            THEN
                                ln_cost   := 0;
                                RETURN ln_cost;
                        END;
                    ELSE
                        IF pv_detail = 'MATAMT'
                        THEN
                            BEGIN
                                  SELECT SUM (NVL (entered_dr, 0) - NVL (entered_cr, 0))
                                    INTO ln_cost
                                    FROM apps.xla_ae_lines xal,
                                         (SELECT application_id, event_id, ae_header_id,
                                                 ae_line_num
                                            FROM apps.xla_distribution_links
                                           WHERE     source_distribution_id_num_1 IN
                                                         (SELECT inv_sub_ledger_id
                                                            FROM apps.mtl_transaction_accounts
                                                           WHERE     transaction_id =
                                                                     pn_interface_line_attribute7
                                                                 AND cost_element_id =
                                                                     1)
                                                 AND source_distribution_type =
                                                     'MTL_TRANSACTION_ACCOUNTS' --and event_class_code = 'SALES_ORDER'
                                                                               )
                                         aa
                                   WHERE     aa.application_id =
                                             xal.application_id
                                         AND aa.ae_header_id = xal.ae_header_id
                                         AND aa.ae_line_num = xal.ae_line_num
                                         AND xal.accounting_class_code IN
                                                 ('OFFSET', 'COST_OF_GOODS_SOLD')
                                         --AND xal.ledger_id = pn_sob_id -- Added by BT Tech Team for defect# 570 on 17-Nov-15
                                         AND xal.ledger_id = ln_sob_id -- Added by BT Tech Team for defect# 785 on 09-Dec-15
                                GROUP BY xal.code_combination_id;

                                RETURN ln_cost;
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    ln_cost   := 0;
                                WHEN OTHERS
                                THEN
                                    ln_cost   := 0;
                                    RETURN ln_cost;
                            END;
                        ELSE
                            IF pv_detail = 'INVMAT'
                            THEN
                                BEGIN
                                      SELECT SUM (NVL (entered_dr, 0) - NVL (entered_cr, 0))
                                        INTO ln_cost
                                        FROM apps.xla_ae_lines xal,
                                             (SELECT application_id, event_id, ae_header_id,
                                                     ae_line_num
                                                FROM apps.xla_distribution_links
                                               WHERE     source_distribution_id_num_1 IN
                                                             (SELECT inv_sub_ledger_id
                                                                FROM apps.mtl_transaction_accounts
                                                               WHERE     transaction_id =
                                                                         pn_interface_line_attribute7
                                                                     AND cost_element_id =
                                                                         1)
                                                     AND source_distribution_type =
                                                         'MTL_TRANSACTION_ACCOUNTS' --and event_class_code = 'SALES_ORDER'
                                                                                   )
                                             aa
                                       WHERE     aa.application_id =
                                                 xal.application_id
                                             AND aa.ae_header_id =
                                                 xal.ae_header_id
                                             AND aa.ae_line_num =
                                                 xal.ae_line_num
                                             AND xal.accounting_class_code =
                                                 'INVENTORY_VALUATION'
                                             --AND xal.ledger_id = pn_sob_id -- Added by BT Tech Team for defect# 570 on 17-Nov-15
                                             AND xal.ledger_id = ln_sob_id -- Added by BT Tech Team for defect# 785 on 09-Dec-15
                                    GROUP BY xal.code_combination_id;

                                    RETURN ln_cost;
                                EXCEPTION
                                    WHEN NO_DATA_FOUND
                                    THEN
                                        ln_cost   := 0;
                                    WHEN OTHERS
                                    THEN
                                        ln_cost   := 0;
                                        RETURN ln_cost;
                                END;
                            ELSE
                                IF pv_detail = 'REQMAT'
                                THEN
                                    BEGIN
                                          SELECT ((SUM (NVL (entered_dr, 0) - NVL (entered_cr, 0))))
                                            INTO ln_cost
                                            FROM apps.xla_ae_lines xal,
                                                 (SELECT application_id, event_id, ae_header_id,
                                                         ae_line_num
                                                    FROM apps.xla_distribution_links
                                                   WHERE     source_distribution_id_num_1 IN
                                                                 (SELECT inv_sub_ledger_id
                                                                    FROM apps.mtl_transaction_accounts
                                                                   WHERE     transaction_id =
                                                                             pn_interface_line_attribute7
                                                                         AND accounting_line_type =
                                                                             1
                                                                         AND cost_element_id =
                                                                             1)
                                                         AND source_distribution_type =
                                                             'MTL_TRANSACTION_ACCOUNTS' --and event_class_code = 'SALES_ORDER'
                                                                                       )
                                                 aa
                                           WHERE     aa.application_id =
                                                     xal.application_id
                                                 AND aa.ae_header_id =
                                                     xal.ae_header_id
                                                 AND aa.ae_line_num =
                                                     xal.ae_line_num
                                                 AND xal.accounting_class_code =
                                                     'INVENTORY_VALUATION'
                                                 --AND xal.ledger_id = pn_sob_id -- Added by BT Tech Team for defect# 570 on 17-Nov-15
                                                 AND xal.ledger_id = ln_sob_id -- Added by BT Tech Team for defect# 785 on 09-Dec-15
                                        GROUP BY xal.code_combination_id;

                                        RETURN ln_cost;
                                    EXCEPTION
                                        WHEN NO_DATA_FOUND
                                        THEN
                                            ln_cost   := 0;
                                        WHEN OTHERS
                                        THEN
                                            ln_cost   := 0;
                                            RETURN ln_cost;
                                    END;
                                ELSE
                                    IF pv_detail = 'INVAMT'
                                    THEN
                                        BEGIN
                                              SELECT SUM (NVL (entered_dr, 0) - NVL (entered_cr, 0))
                                                INTO ln_cost
                                                FROM apps.xla_ae_lines xal,
                                                     (SELECT application_id, event_id, ae_header_id,
                                                             ae_line_num
                                                        FROM apps.xla_distribution_links
                                                       WHERE     source_distribution_id_num_1 IN
                                                                     (SELECT inv_sub_ledger_id
                                                                        FROM apps.mtl_transaction_accounts
                                                                       WHERE transaction_id =
                                                                             pn_interface_line_attribute7)
                                                             AND source_distribution_type =
                                                                 'MTL_TRANSACTION_ACCOUNTS' --and event_class_code = 'SALES_ORDER'
                                                                                           )
                                                     aa
                                               WHERE     aa.application_id =
                                                         xal.application_id
                                                     AND aa.ae_header_id =
                                                         xal.ae_header_id
                                                     AND aa.ae_line_num =
                                                         xal.ae_line_num
                                                     AND xal.accounting_class_code =
                                                         'INVENTORY_VALUATION'
                                                     --AND xal.ledger_id = pn_sob_id -- Added by BT Tech Team for defect# 570 on 17-Nov-15
                                                     AND xal.ledger_id =
                                                         ln_sob_id -- Added by BT Tech Team for defect# 785 on 09-Dec-15
                                            GROUP BY xal.code_combination_id;

                                            RETURN ln_cost;
                                        EXCEPTION
                                            WHEN NO_DATA_FOUND
                                            THEN
                                                ln_cost   := 0;
                                            WHEN OTHERS
                                            THEN
                                                ln_cost   := 0;
                                                RETURN ln_cost;
                                        END;
                                    END IF;
                                END IF;
                            END IF;
                        END IF;
                    END IF;
                END IF;
            END IF;
        END IF;

        RETURN ln_cost;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Error in get_mmt_cost' || SQLERRM);
            RETURN 0;
    END get_mmt_cost;

    FUNCTION get_cic_item_cost (pn_warehouse_id NUMBER, pn_inventory_item_id NUMBER, pv_custom_cost IN VARCHAR2)
        RETURN NUMBER
    IS
        ln_itemcost   NUMBER;
    BEGIN
        IF pv_custom_cost = 'N'
        THEN
            BEGIN
                ln_itemcost   := NULL;

                SELECT MAX (cic.item_cost)
                  INTO ln_itemcost
                  FROM apps.cst_item_costs cic, apps.mtl_parameters mp
                 WHERE     cic.inventory_item_id = pn_inventory_item_id
                       AND cic.organization_id = pn_warehouse_id
                       --(select ship_from_org_id from oe_order_lines_all where line_id=pn_interface_line_attribute6)
                       AND cic.organization_id = mp.organization_id
                       AND cic.cost_type_id = mp.primary_cost_method;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_itemcost   := 0;
            END;

            RETURN ln_itemcost;
        ELSE
            BEGIN
                ln_itemcost   := NULL;

                SELECT landed_cost
                  INTO ln_itemcost
                  FROM xxdo.xxdocst_item_cost
                 WHERE     inventory_item_id = pn_inventory_item_id
                       AND organization_id = pn_warehouse_id;
            --(select ship_from_org_id from oe_order_lines_all where line_id=pn_interface_line_attribute6);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_itemcost   := 0;
            END;

            RETURN ln_itemcost;
        END IF;
    END get_cic_item_cost;

    FUNCTION get_factory_invoice (p_cust_trx_id   IN VARCHAR2,
                                  p_style         IN VARCHAR2)
        RETURN VARCHAR2
    IS
        retval     VARCHAR2 (2000);
        l_po_num   VARCHAR2 (100);

        /*  01/17/2014 ---Sarita --Changed the function to match with the Get Factory Invoice function in package XXDO_AR_REPORTS*/
        CURSOR c1 (pn_custtrxid VARCHAR2)
        IS
            SELECT DISTINCT
                   DECODE (ship_intl.invoice_num, NULL, DECODE (ship_dc1.invoice_num, NULL, rsh.packing_slip, ship_dc1.invoice_num), ship_intl.invoice_num) AS factory_invoice
              FROM apps.oe_drop_ship_sources dss, apps.rcv_shipment_lines rsl, apps.rcv_shipment_headers rsh,
                   apps.ra_customer_trx_lines_all rtla, apps.oe_order_lines_all oola, apps.mtl_system_items_b mtl,
                   custom.do_shipments ship_dc1, custom.do_shipments ship_intl, apps.rcv_transactions rcv
             WHERE     rsl.shipment_header_id = rsh.shipment_header_id
                   AND rsl.po_line_location_id =
                       NVL (TO_NUMBER (oola.attribute16),
                            dss.line_location_id)
                   AND dss.line_id(+) =
                       TO_NUMBER (rtla.interface_line_attribute6)
                   AND oola.line_id =
                       TO_NUMBER (rtla.interface_line_attribute6)
                   AND oola.inventory_item_id = mtl.inventory_item_id
                   AND rtla.customer_trx_id = TO_CHAR (pn_custtrxid)
                   --      10089300
                   AND rcv.shipment_header_id = rsh.shipment_header_id
                   AND SUBSTR (TRIM (rcv.attribute1),
                               1,
                               INSTR (TRIM (rcv.attribute1), '-', 1) - 1) =
                       ship_intl.shipment_id(+)
                   AND SUBSTR (TRIM (rsh.shipment_num),
                               1,
                               INSTR (TRIM (rsh.shipment_num), '-', 1) - 1) =
                       ship_dc1.shipment_id(+);

        CURSOR c2 (pn_cust_trx_id IN VARCHAR2, pv_style IN VARCHAR2)
        IS
            SELECT DISTINCT
                   DECODE (ship_intl.invoice_num, NULL, DECODE (ship_dc1.invoice_num, NULL, rsh.packing_slip, ship_dc1.invoice_num), ship_intl.invoice_num) AS factory_invoice
              FROM apps.oe_drop_ship_sources dss, apps.rcv_shipment_lines rsl, apps.rcv_shipment_headers rsh,
                   apps.ra_customer_trx_lines_all rtla, apps.oe_order_lines_all oola, apps.mtl_system_items_b mtl,
                   custom.do_shipments ship_dc1, custom.do_shipments ship_intl, apps.rcv_transactions rcv
             WHERE     rsl.shipment_header_id = rsh.shipment_header_id
                   AND rsl.po_line_location_id =
                       NVL (TO_NUMBER (oola.attribute16),
                            dss.line_location_id)
                   AND dss.line_id(+) =
                       TO_NUMBER (rtla.interface_line_attribute6)
                   AND oola.line_id =
                       TO_NUMBER (rtla.interface_line_attribute6)
                   AND oola.inventory_item_id = mtl.inventory_item_id
                   AND rtla.customer_trx_id = TO_CHAR (pn_cust_trx_id)
                   AND mtl.segment1 = pv_style
                   AND rcv.shipment_header_id = rsh.shipment_header_id
                   AND SUBSTR (TRIM (rcv.attribute1),
                               1,
                               INSTR (TRIM (rcv.attribute1), '-', 1) - 1) =
                       ship_intl.shipment_id(+)
                   AND SUBSTR (TRIM (rsh.shipment_num),
                               1,
                               INSTR (TRIM (rsh.shipment_num), '-', 1) - 1) =
                       ship_dc1.shipment_id(+);

        CURSOR c3 (pn_cust_trx_id IN VARCHAR2)
        IS
              SELECT poh.segment1 po_num, rsh.packing_slip AS factory_invoice, SUM (rsl.quantity_received) rcvd_qty
                FROM apps.rcv_shipment_lines rsl, apps.rcv_shipment_headers rsh, apps.rcv_transactions rcv,
                     apps.mtl_system_items_b msi, apps.po_headers_all poh, apps.ra_customer_trx_all rcta
               WHERE     rsh.shipment_header_id = rsl.shipment_header_id
                     AND rsl.shipment_line_id = rcv.shipment_line_id
                     AND rcv.transaction_type = 'RECEIVE'
                     AND rsl.item_id = msi.inventory_item_id
                     AND msi.organization_id IN
                             (SELECT organization_id
                                FROM org_organization_definitions
                               WHERE organization_code = 'MST')
                     AND rsl.po_header_id = poh.po_header_id
                     AND rcta.purchase_order = poh.segment1
                     AND rcta.customer_trx_id = TO_CHAR (pn_cust_trx_id)
            GROUP BY rcv.transaction_date, poh.segment1, msi.segment1,
                     rsh.packing_slip;

        CURSOR c4 (pn_cust_trx_id IN VARCHAR2, pv_style IN VARCHAR2)
        IS
              SELECT poh.segment1 po_num, rcv.transaction_date po_receipt_date, rsh.packing_slip AS factory_invoice,
                     SUM (rsl.quantity_received) rcvd_qty
                FROM apps.rcv_shipment_lines rsl, apps.rcv_shipment_headers rsh, apps.rcv_transactions rcv,
                     apps.mtl_system_items_b msi, apps.po_headers_all poh, apps.ra_customer_trx_all rcta
               WHERE     rsh.shipment_header_id = rsl.shipment_header_id
                     AND rsl.shipment_line_id = rcv.shipment_line_id
                     AND rcv.transaction_type = 'RECEIVE'
                     AND rsl.item_id = msi.inventory_item_id
                     AND msi.organization_id IN
                             (SELECT organization_id
                                FROM org_organization_definitions
                               WHERE organization_code = 'MST')
                     AND rsl.po_header_id = poh.po_header_id
                     AND rcta.purchase_order = poh.segment1
                     AND rcta.customer_trx_id = TO_CHAR (pn_cust_trx_id)
                     AND msi.segment1 = pv_style
            GROUP BY rcv.transaction_date, poh.segment1, msi.segment1,
                     rsh.packing_slip;

        CURSOR c5 (pn_cust_trx_id   IN VARCHAR2,
                   pv_style         IN VARCHAR2,
                   po_rcv_date         VARCHAR2)
        IS
            SELECT COUNT (DISTINCT rsh.packing_slip) style_cnt
              FROM apps.rcv_shipment_lines rsl, apps.rcv_shipment_headers rsh, apps.rcv_transactions rcv,
                   apps.mtl_system_items_b msi, apps.po_headers_all poh, apps.ra_customer_trx_all rcta
             WHERE     rsh.shipment_header_id = rsl.shipment_header_id
                   AND rsl.shipment_line_id = rcv.shipment_line_id
                   AND rcv.transaction_type = 'RECEIVE'
                   AND rsl.item_id = msi.inventory_item_id
                   AND msi.organization_id IN
                           (SELECT organization_id
                              FROM org_organization_definitions
                             WHERE organization_code = 'MST')
                   AND rsl.po_header_id = poh.po_header_id
                   AND rcta.purchase_order = poh.segment1
                   AND rcta.customer_trx_id = TO_CHAR (pn_cust_trx_id)
                   AND msi.segment1 = pv_style                     --'1003321'
                   AND TRUNC (rcv.transaction_date) =
                       TRUNC (TO_DATE (po_rcv_date, 'DD-MON-YY'));
    BEGIN
        BEGIN
            SELECT pha.segment1
              INTO l_po_num
              FROM apps.ra_customer_trx_all rcta, apps.po_headers_all pha
             WHERE     1 = 1
                   AND pha.segment1 = rcta.purchase_order
                   AND rcta.org_id = pha.org_id
                   AND rcta.customer_trx_id = TO_CHAR (p_cust_trx_id);
        EXCEPTION
            WHEN OTHERS
            THEN
                --apps.fnd_file.put_line(apps.fnd_file.log,'In THE QUERY'||L_PO_NUM);
                NULL;
        END;

        IF l_po_num IS NULL
        THEN
            IF p_style IS NULL
            THEN
                retval   := NULL;

                FOR i IN c1 (TO_CHAR (p_cust_trx_id))
                LOOP
                    IF retval IS NULL
                    THEN
                        retval   := i.factory_invoice;
                    ELSE
                        retval   := i.factory_invoice || ',' || retval;
                    END IF;
                END LOOP;
            ELSE
                retval   := NULL;

                FOR j IN c2 (TO_CHAR (p_cust_trx_id), p_style)
                LOOP
                    IF retval IS NULL
                    THEN
                        retval   := j.factory_invoice;
                    ELSE
                        retval   := j.factory_invoice || ',' || retval;
                    END IF;
                END LOOP;
            END IF;
        ELSE
            IF p_style IS NULL
            THEN
                retval   := NULL;

                FOR l IN c3 (TO_CHAR (p_cust_trx_id))
                LOOP
                    IF retval IS NULL
                    THEN
                        retval   := l.factory_invoice;
                    ELSE
                        retval   :=
                               l.factory_invoice
                            || '('
                            || l.rcvd_qty
                            || ')'
                            || ','
                            || retval;
                    END IF;
                END LOOP;
            ELSE
                retval   := NULL;

                FOR n IN c4 (TO_CHAR (p_cust_trx_id), p_style)
                LOOP
                    -- apps.fnd_file.put_line(apps.fnd_file.log,'DATE:   '||n.po_receipt_date);
                    FOR q
                        IN c5 (TO_CHAR (p_cust_trx_id),
                               p_style,
                               n.po_receipt_date)
                    LOOP
                        IF q.style_cnt <= 1
                        THEN
                            IF retval IS NULL
                            THEN
                                retval   := n.factory_invoice;
                            -- apps.fnd_file.put_line(apps.fnd_file.log,'received quantity if value1111111 :   '||n.rcvd_qty||':::#######'||retval);
                            END IF;
                        ELSE
                            --apps.fnd_file.put_line(apps.fnd_file.log,'count quantity else:   '||q.style_cnt);
                            IF retval IS NULL
                            THEN
                                retval   :=
                                       n.factory_invoice
                                    || '('
                                    || n.rcvd_qty
                                    || ')';
                            ELSE
                                retval   :=
                                       n.factory_invoice
                                    || '('
                                    || n.rcvd_qty
                                    || ')'
                                    || ','
                                    || retval;
                            END IF;
                        END IF;
                    END LOOP;
                END LOOP;
            /* if l_count >1 then
             retval := retval||'('||l_qty||')';
             else
             retval := retval;
             end if;*/
            END IF;
        END IF;

        RETURN retval;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'In When No Data found exception ' || SQLCODE || SQLERRM);
            RETURN NULL;
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'In When others exception of Get Factory Invoice then p_Cust_Trx_ID : '
                || p_cust_trx_id);
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'In When others exception of Get Factory Invoice then p_Style  :'
                || p_style);
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'In When others exception of Get Factory Invoice then '
                || SQLCODE
                || SQLERRM);
            RETURN NULL;
    END get_factory_invoice;

    PROCEDURE print_log_prc (p_msg IN VARCHAR2)
    IS
    BEGIN
        IF p_msg IS NOT NULL
        THEN
            fnd_file.put_line (fnd_file.LOG, p_msg);
        END IF;

        RETURN;
    END print_log_prc;

    -- End changes by BT Technology Team v4.0 on 31-Dec-2014
    FUNCTION get_price (pn_so_line_id   VARCHAR2,
                        pn_org_id       NUMBER,
                        pv_col          VARCHAR2)
        RETURN NUMBER
    IS
        ln_unit_selling_price   NUMBER;
        ln_unit_list_price      NUMBER;
    BEGIN
        SELECT NVL (oola.unit_selling_price, 0), NVL (oola.unit_list_price, 0)
          INTO ln_unit_selling_price, ln_unit_list_price
          FROM apps.oe_order_lines_all oola
         WHERE oola.line_id = pn_so_line_id AND oola.org_id = pn_org_id;

        IF pv_col = 'SP'
        THEN
            RETURN ln_unit_selling_price;
        ELSIF pv_col = 'LP'
        THEN
            RETURN ln_unit_list_price;
        ELSE
            RETURN 0;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END get_price;

    FUNCTION get_email_recips (v_lookup_type VARCHAR2)
        RETURN apps.do_mail_utils.tbl_recips
    IS
        v_def_mail_recips   apps.do_mail_utils.tbl_recips;

        CURSOR c_recips IS
            SELECT lookup_code, meaning, description
              FROM apps.fnd_lookup_values
             WHERE     lookup_type = v_lookup_type
                   AND enabled_flag = 'Y'
                   AND SYSDATE BETWEEN TRUNC (
                                           NVL (start_date_active, SYSDATE))
                                   AND TRUNC (
                                           NVL (end_date_active, SYSDATE) + 1);
    BEGIN
        v_def_mail_recips.DELETE;

        FOR c_recip IN c_recips
        LOOP
            v_def_mail_recips (v_def_mail_recips.COUNT + 1)   :=
                c_recip.meaning;
        END LOOP;

        RETURN v_def_mail_recips;
    END;

    FUNCTION get_invoice_gl_code (p_customer_trx_id   IN NUMBER,
                                  p_style             IN VARCHAR2)
        RETURN VARCHAR2
    IS
        l_gl_acct_id   NUMBER;
        l_ret          VARCHAR2 (240);
    BEGIN
        SELECT DECODE (MIN (rctlgda.code_combination_id), MAX (rctlgda.code_combination_id), MAX (rctlgda.code_combination_id), MIN (rctlgda.code_combination_id)) AS gl_acct_id
          INTO l_gl_acct_id
          FROM apps.ra_customer_trx_all rcta, apps.ra_customer_trx_lines_all rctla, apps.ra_cust_trx_line_gl_dist_all rctlgda,
               apps.mtl_system_items_b msib
         WHERE     rctla.customer_trx_id = rcta.customer_trx_id
               AND rctla.line_type = 'LINE'
               AND NVL (rctla.interface_line_attribute11, '0') = '0'
               AND rctlgda.customer_trx_id(+) = rctla.customer_trx_id
               AND rctlgda.customer_trx_line_id(+) =
                   rctla.customer_trx_line_id
               AND msib.organization_id(+) = rctla.warehouse_id
               AND msib.inventory_item_id(+) = rctla.inventory_item_id
               AND rcta.customer_trx_id = p_customer_trx_id
               AND rctlgda.account_class = 'REV'
               AND NVL (msib.segment1, rctla.description) = p_style;

        IF l_gl_acct_id IS NOT NULL
        THEN
            SELECT gcc.segment1 || '.' || gcc.segment2 || '.' || gcc.segment3 || '.' || gcc.segment4
              INTO l_ret
              FROM apps.gl_code_combinations gcc
             WHERE gcc.code_combination_id = l_gl_acct_id;
        ELSE
            l_ret   := NULL;
        END IF;

        RETURN l_ret;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN NULL;
    END get_invoice_gl_code;

    FUNCTION get_vat_number (p_customer_id IN NUMBER, pn_ou IN NUMBER)
        RETURN VARCHAR2
    IS
        l_vat_num_bill   VARCHAR2 (240);
        l_vat_num_ship   VARCHAR2 (240);
    BEGIN
        SELECT DISTINCT tax_reference
          INTO l_vat_num_bill
          FROM apps.zx_party_tax_profile pro, apps.hz_cust_acct_sites_all sites, apps.hz_cust_site_uses_all uses
         WHERE     pro.party_type_code = 'THIRD_PARTY_SITE'
               AND pro.party_id = sites.party_site_id
               AND sites.cust_acct_site_id = uses.cust_acct_site_id
               AND uses.site_use_code = 'BILL_TO'
               AND sites.bill_to_flag = 'P'
               AND sites.org_id = uses.org_id
               AND sites.org_id = pn_ou
               AND sites.cust_account_id = p_customer_id;

        IF l_vat_num_bill IS NULL
        THEN
            BEGIN
                SELECT DISTINCT tax_reference
                  INTO l_vat_num_ship
                  FROM apps.zx_party_tax_profile pro, apps.hz_cust_acct_sites_all sites, apps.hz_cust_site_uses_all uses
                 WHERE     pro.party_type_code = 'THIRD_PARTY_SITE'
                       AND pro.party_id = sites.party_site_id
                       AND sites.cust_acct_site_id = uses.cust_acct_site_id
                       AND uses.site_use_code = 'SHIP_TO'
                       AND sites.bill_to_flag = 'P'
                       AND sites.org_id = uses.org_id
                       AND sites.org_id = pn_ou
                       AND sites.cust_account_id = p_customer_id;

                RETURN l_vat_num_ship;
            EXCEPTION
                WHEN OTHERS
                THEN
                    RETURN NULL;
            END;
        END IF;

        RETURN l_vat_num_bill;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_vat_number;

    /* Start 4.2  CCR0008574 */
    FUNCTION XXD_REMOVE_JUNK_CHAR_FNC (p_input IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_output   VARCHAR2 (32767) := NULL;
    BEGIN
        IF p_input IS NOT NULL
        THEN
            SELECT REPLACE (REPLACE (REPLACE (REPLACE (REPLACE (p_input, CHR (9), ''), CHR (10), ''), '|', ' '), CHR (13), ''), ',', '')
              INTO lv_output
              FROM DUAL;
        ELSE
            RETURN NULL;
        END IF;

        RETURN lv_output;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END XXD_REMOVE_JUNK_CHAR_FNC;

    /* End 4.2  CCR0008574 */
    PROCEDURE intl_invoices (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_from_date IN VARCHAR2:= NULL, p_to_date IN VARCHAR2:= NULL, pv_show_land_cost IN VARCHAR2, pv_custom_cost IN VARCHAR2, pv_regions IN VARCHAR2, pn_region_ou IN VARCHAR2, pn_price_list IN NUMBER, pn_inv_org IN NUMBER, pn_elim_org IN NUMBER, pv_brand IN VARCHAR2
                             , pv_disc_len IN NUMBER, pv_send_to_bl IN VARCHAR2, --Added for CCR0007628
                                                                                 pv_file_path IN VARCHAR2) --Added for CCR0007628
    IS
        l_include_style         VARCHAR2 (10) := 'Y';
        l_ret_val               NUMBER := 0;
        l_from_date             DATE;
        l_to_date               DATE;
        l_show_land_cost        VARCHAR2 (30);
        l_custom_cost           VARCHAR2 (20);
        l_regions               VARCHAR2 (20);
        --l_region_ou         VARCHAR2 (20); Defect 611
        l_region_ou             VARCHAR2 (240);
        v_subject               VARCHAR2 (100);
        l_style                 VARCHAR2 (240);
        l_style_code            VARCHAR2 (240);
        v_employee_order        VARCHAR2 (30);
        v_discount_code         VARCHAR2 (30);
        v_def_mail_recips       apps.do_mail_utils.tbl_recips;
        ex_no_recips            EXCEPTION;
        ex_no_sender            EXCEPTION;
        ex_no_data_found        EXCEPTION;

        CURSOR c_invoices IS
              SELECT brand,
                     organization_name,
                     warehouse_name,
                     country,
                     customer_trx_id,
                     invoice_number,
                     transaction_number,
                     invoice_date,
                     sales_order,
                     factory_inv,
                     sell_to_customer_name,
                     invoice_currency_code,
                     series,
                     style,
                     color,
                     --Start modification for CR 92 by BT Technology Team on 31-Jul-15
                     item_type,
                     --End modification for CR 92 by BT Technology Team on 31-Jul-15
                     cogs_acct,
                     SUM (NVL (invoice_total, 0))
                         invoice_total,
                     SUM (NVL (pre_conv_inv_total, 0))
                         pre_conv_inv_total,
                     SUM (NVL (invoiced_qty, 0))
                         invoiced_qty,
                     ROUND (NVL (SUM (ship_landed_cost_of_goods), 0), 2)
                         ship_landed_cost_of_goods,
                     ROUND (NVL (SUM (trans_landed_cost_of_goods), 0), 2)
                         trans_landed_cost_of_goods,
                     ROUND (
                         NVL (
                               SUM (unit_selling_price * invoiced_qty)
                             / (DECODE (SUM (invoiced_qty), 0, 1, SUM (invoiced_qty))),
                             0),
                         2)
                         unit_selling_price,
                     ROUND (
                         NVL (
                               SUM (unit_list_price * invoiced_qty)
                             / (DECODE (SUM (invoiced_qty), 0, 1, SUM (invoiced_qty))),
                             0),
                         2)
                         unit_list_price,
                       ROUND (
                           NVL (
                                 SUM (unit_list_price * invoiced_qty)
                               / (DECODE (SUM (invoiced_qty), 0, 1, SUM (invoiced_qty))),
                               0),
                           2)
                     - ROUND (
                           NVL (
                                 SUM (unit_selling_price * invoiced_qty)
                               / (DECODE (SUM (invoiced_qty), 0, 1, SUM (invoiced_qty))),
                               0),
                           2)
                         discount,
                     (ROUND (NVL (SUM (unit_list_price * invoiced_qty), 0), 2) - ROUND (NVL (SUM (unit_selling_price * invoiced_qty), 0), 2))
                         ext_discount,
                     tax_rate_code,
                     tax_rate,
                     SUM (NVL (pre_conv_tax_amt, 0))
                         pre_conv_tax_amt,
                     SUM (NVL (pre_conv_total_amt, 0))
                         pre_conv_total_amt,
                     SUM (NVL (total_amt, 0))
                         total_amt,
                     ACCOUNT,
                     ROUND (
                         NVL (
                               SUM (wholesale_price * invoiced_qty)
                             / (DECODE (SUM (invoiced_qty), 0, 1, SUM (invoiced_qty))),
                             0),
                         2)
                         wholesale_price,
                     purchase_order,
                     party_site_number,
                     REPLACE (
                         REPLACE (REPLACE (order_type, CHR (10)), CHR (13)),
                         CHR (9))
                         order_type,
                     ar_type,
                     SUM (NVL (usd_revenue_total, 0))
                         usd_revenue_total,
                     vat_number,
                     zip_code,
                     state,
                     address2,
                     address1,
                     city,                      --Modified against ENHC0012592
                     gender,
                     address_key,
                     original_order,
                     original_shipment_date,
                     commodity_code,
                     term_name,
                     order_class,
                     SUM (NVL (macau_cost, 0))
                         macau_cost,
                     SUM (NVL (material_cost, 0))
                         material_cost,
                     (CASE
                          WHEN (SUM (NVL (material_cost, 0)) - SUM (NVL (macau_cost, 0))) <
                               0
                          THEN
                              ROUND (NVL (SUM (trans_landed_cost_of_goods), 0),
                                     2)
                          ELSE
                              (ROUND (NVL (SUM (trans_landed_cost_of_goods), 0), 2) - SUM (NVL (material_cost, 0)) + SUM (NVL (macau_cost, 0)))
                      END)
                         consolidated_cost,
                     customer_number,
                     current_season,
                     sub_group,
                     employee_order,
                     discount_code,
                     sub_class, --Added by BT Technology Team v3.0 on 29-Dec-2014
                     account_type, -- Added by BT Tech Team for defect# 570 on 17-Nov-15
                     --ROUND( sum(average_margin)/count(1),2) average_margin --4.2
                     ROUND (SUM (average_margin), 2)
                         average_margin                                  --4.2
                FROM (SELECT * FROM xxdo.xxdoar_invoice_det)
            GROUP BY brand, organization_name, warehouse_name,
                     country, customer_trx_id, invoice_number,
                     transaction_number, invoice_date, sales_order,
                     factory_inv, sell_to_customer_name, invoice_currency_code,
                     series, style, color,
                     --Start modification for CR 92 by BT Technology Team on 31-Jul-15
                     item_type, --End modification for CR 92 by BT Technology Team on 31-Jul-15
                                tax_rate_code, tax_rate,
                     ACCOUNT, purchase_order, cogs_acct,
                     party_site_number, order_type, ar_type,
                     zip_code, vat_number, state,
                     address2, address1, city,  --Modified against ENHC0012592
                     gender, address_key, original_order,
                     original_shipment_date, commodity_code, term_name,
                     order_class, customer_number, current_season,
                     sub_group, employee_order, discount_code,
                     sub_class, --Added by BT Technology Team v3.0 on 29-Dec-2014
                                account_type
            --                  , -- Added by BT Tech Team for defect# 570 on 17-Nov-15
            --      average_margin -- 4.2
            ORDER BY brand, organization_name, warehouse_name,
                     invoice_date, invoice_number, style,
                     color;

        CURSOR c_det (cp_style_grouping IN VARCHAR2, cp_from_date IN DATE, cp_to_date IN DATE, cpv_show_land_cost IN VARCHAR2, cpv_custom_cost IN VARCHAR2, cpn_region_ou VARCHAR2
                      , pn_price_list NUMBER, pv_regions VARCHAR2)
        IS
              SELECT NVL (
                         rt.attribute5,
                         xxdo.get_item_details ('NA',
                                                rtl.inventory_item_id,
                                                'BRAND'))
                         AS brand,
                     xxdo.get_item_details ('NA',
                                            rtl.inventory_item_id,
                                            'GENDER')
                         AS gender,
                     get_vat_number (custs.customer_id, rt.org_id)
                         AS vat_number,
                     addr.postal_code
                         AS zip_code,
                     NVL (addr.state, addr.province)
                         state,
                     addr.address2,
                     addr.address1,
                     addr.address_key,
                     addr.city,                 --Modified against ENHC0012592
                     org_name.NAME
                         AS organization_name,
                     MAX (wh_name.NAME)
                         AS warehouse_name,
                     MAX (addr.country)
                         AS country,
                     rt.customer_trx_id,
                     NVL (rt.attribute2, rt.trx_number)
                         AS invoice_number,                         --Global e
                     rt.trx_number
                         AS transaction_number,
                     rt.trx_date
                         AS invoice_date,
                     -- Start changes by BT Technology Team on 17-Dec-2015 for Defect 785
                     -- MAX (rt.interface_header_attribute1) AS sales_order,
                     MAX (rtl.sales_order)
                         AS sales_order,
                     -- End changes by BT Technology Team on 17-Dec-2015 for Defect 785
                     DECODE (
                         cp_style_grouping,
                         'Y', get_factory_invoice (
                                  rt.customer_trx_id,
                                  DECODE (
                                      cp_style_grouping,
                                      'Y', NVL (msib.segment1, rtl.description),
                                      NULL)),
                         get_factory_invoice (rt.customer_trx_id, NULL))
                         AS factory_inv,
                     custs.customer_name
                         AS sell_to_customer_name,
                     rt.invoice_currency_code,
                     NVL (
                         xxdo.get_item_details ('NA',
                                                rtl.inventory_item_id,
                                                'PRODUCT'),
                         DECODE (
                             cp_style_grouping,
                             'Y', NVL (
                                      xxdo.get_item_details (
                                          'NA',
                                          rtl.inventory_item_id,
                                          'STYLE'),
                                      rtl.description),
                             NULL))
                         AS series,
                     DECODE (
                         cp_style_grouping,
                         'Y', NVL (
                                  DECODE (
                                      xxdo.get_item_details (
                                          'NA',
                                          rtl.inventory_item_id,
                                          'STYLE'),
                                      'NA', rtl.description,
                                      xxdo.get_item_details (
                                          'NA',
                                          rtl.inventory_item_id,
                                          'STYLE')),
                                  rtl.description),
                         NULL)                                          -- 4.2
                         AS style,
                     xxdo.get_item_details ('NA',
                                            rtl.inventory_item_id,
                                            'COLOR')
                         AS color,
                     --Start modification for CR 92 by BT Technology Team on 31-Jul-15
                     xxdo.get_item_details ('NA',
                                            rtl.inventory_item_id,
                                            'ITEM_TYPE')
                         AS item_type,
                     --End modification for CR 92 by BT Technology Team on 31-Jul-15
                     --   SUM (NVL (rtl.extended_amount, 0) * NVL (rt.exchange_rate, 1)) AS invoice_total,
                     SUM (NVL (gl_dist.amount, 0) * NVL (rt.exchange_rate, 1))
                         AS invoice_total,  -- Modified by BT Dev Team for 3.5
                     --   SUM (NVL (rtl.extended_amount, 0)) AS pre_conv_inv_total,
                     SUM (NVL (gl_dist.amount, 0))
                         AS pre_conv_inv_total, -- Modified by BT Dev Team for 3.4
                     SUM (
                         DECODE (
                             rtl.line_type,
                             'LINE', DECODE (
                                         NVL (rtl.interface_line_attribute11,
                                              0),
                                         0, NVL (
                                                quantity_invoiced,
                                                NVL (rtl.quantity_credited, 0)))))
                         AS invoiced_qty,
                     DECODE (
                         cpv_show_land_cost,
                         'Y', SUM (
                                    NVL -- Start changes by BT Technology Team v3.0 on 29-Dec-2014
                                        --(xxdo.get_mmt_cost
                                        (
                                        get_mmt_cost -- End changes by BT Technology Team v3.0 on 29-Dec-2014
                                                     (
                                            rtl.interface_line_attribute6,
                                            rtl.interface_line_attribute7,
                                            rtl.warehouse_id,
                                            rt.set_of_books_id, -- Added by BT Tech Team for defect# 570 on 17-Nov-15
                                            'COGSAMT'),
                                        0)
                                  * DECODE (
                                        rtl.line_type,
                                        'LINE', DECODE (
                                                    NVL (
                                                        rtl.interface_line_attribute11,
                                                        0),
                                                    0, 1,
                                                    0),
                                        0)),
                         NULL)
                         AS trans_landed_cost_of_goods,
                     DECODE (
                         rtl.line_type,
                         'LINE', DECODE (
                                     NVL (rtl.interface_line_attribute11, 0),
                                     0, NVL (
                                            (SELECT concatenated_segments
                                               FROM apps.gl_code_combinations_kfv
                                              WHERE code_combination_id =
                                                    -- Start changes by BT Technology Team v3.0 on 29-Dec-2014
                                                    --xxdo.get_mmt_cost
                                                    get_mmt_cost -- End changes by BT Technology Team v3.0 on 29-Dec-2014
                                                                 (
                                                        rtl.interface_line_attribute6,
                                                        rtl.interface_line_attribute7,
                                                        rtl.warehouse_id,
                                                        rt.set_of_books_id, -- Added by BT Tech Team for defect# 570 on 17-Nov-15
                                                        'COGSCCID')),
                                            'NA'),
                                     0),
                         0)
                         cogs_acct,
                     DECODE (
                         cpv_show_land_cost,
                         'Y', SUM (
                                    NVL (
                                        get_cic_item_cost (
                                            rtl.warehouse_id,
                                            rtl.inventory_item_id,
                                            cpv_custom_cost),
                                        0)
                                  * DECODE (
                                        rtl.line_type,
                                        'LINE', DECODE (
                                                    NVL (
                                                        rtl.interface_line_attribute11,
                                                        0),
                                                    0, NVL (
                                                           rtl.quantity_invoiced,
                                                           NVL (
                                                               rtl.quantity_credited,
                                                               0)),
                                                    0),
                                        0)),
                         NULL)
                         AS ship_landed_cost_of_goods,
                     ---added
                     get_price (rtl.interface_line_attribute6,
                                rtl.org_id,
                                'SP')
                         unit_selling_price,
                     get_price (rtl.interface_line_attribute6,
                                rtl.org_id,
                                'LP')
                         unit_list_price,
                       get_price (rtl.interface_line_attribute6,
                                  rtl.org_id,
                                  'LP')
                     - get_price (rtl.interface_line_attribute6,
                                  rtl.org_id,
                                  'SP')
                         discount,
                     (NVL (SUM (DECODE (rtl.line_type, 'LINE', DECODE (NVL (rtl.interface_line_attribute11, 0), 0, NVL (rtl.quantity_invoiced, rtl.quantity_credited), 0), 0)), 0) * (get_price (rtl.interface_line_attribute6, rtl.org_id, 'LP') - get_price (rtl.interface_line_attribute6, rtl.org_id, 'SP')))
                         ext_discount,
                     --Start Changes by BT tech team on 13-Nov-15 for defect# 570
                     --zl.tax_rate_code, zl.tax_rate,
                     --SUM (NVL (zl.tax_amt, 0)) AS pre_conv_tax_amt,
                     get_tax_details (rt.customer_trx_id,
                                      rtl.customer_trx_line_id,
                                      'TAX_RATE_CODE')
                         tax_rate_code,
                     get_tax_details (rt.customer_trx_id,
                                      rtl.customer_trx_line_id,
                                      'TAX_RATE')
                         tax_rate,
                     get_tax_details (rt.customer_trx_id,
                                      rtl.customer_trx_line_id,
                                      'TAX_AMOUNT')
                         pre_conv_tax_amt,
                       --sum(nvl(zl.TAXABLE_AMT,0)) AS TAXABLE_AMT
                       --  SUM (NVL (rtl.extended_amount, 0))
                       SUM (NVL (gl_dist.amount, 0))       -- Modified for 3.7
                     --+ SUM (NVL (zl.tax_amt, 0)) AS pre_conv_total_amt,
                     + get_tax_details (rt.customer_trx_id,
                                        rtl.customer_trx_line_id,
                                        'TAX_AMOUNT')
                         AS pre_conv_total_amt,
                     ROUND (
                           --       (  SUM (NVL (rtl.extended_amount, 0))
                           (SUM (NVL (gl_dist.amount, 0))  -- Modified for 3.7
                                                          --+ SUM (NVL (zl.tax_amt, 0))
                                                          + get_tax_details (rt.customer_trx_id, rtl.customer_trx_line_id, 'TAX_AMOUNT') --End Changes by BT tech team on 13-Nov-15 for defect# 570
                                                                                                                                        )
                         * NVL (rt.exchange_rate, 1),
                         2)
                         AS total_amt,
                     -- Added below by BT Tech Team for defect# 570 on 17-Nov-15
                     NVL (
                         get_account (rt.customer_trx_id,
                                      rt.set_of_books_id,
                                      gl_dist.cust_trx_line_gl_dist_id),
                         (SELECT glc.concatenated_segments
                            FROM apps.gl_code_combinations_kfv glc
                           WHERE gl_dist.code_combination_id =
                                 glc.code_combination_id))
                         ACCOUNT,
                     -- Added above by BT Tech Team for defect# 570 on 17-Nov-15
                     hsoe.get_price_list_value (pn_price_list,
                                                rtl.inventory_item_id)
                         wholesale_price,
                     rt.purchase_order,
                     addr.site_number
                         party_site_number,
                     rt.interface_header_attribute2
                         order_type,
                     rtt.NAME
                         ar_type,
                     SUM (
                         ROUND (
                               NVL (rtl.extended_amount, 0)
                             * (SELECT conversion_rate
                                  FROM apps.gl_daily_rates
                                 WHERE     conversion_type = 'Corporate'
                                       AND from_currency =
                                           rt.invoice_currency_code
                                       AND to_currency = 'USD'
                                       AND conversion_date =
                                           TRUNC (rt.trx_date)),
                             2))
                         usd_revenue_total,
                     get_parent_ord_det (rtl.interface_line_attribute6,
                                         rtl.org_id,
                                         'OO')
                         original_order,
                     get_parent_ord_det (rtl.interface_line_attribute6,
                                         rtl.org_id,
                                         'OSD')
                         original_shipment_date,
                     (SELECT MIN (tc.harmonized_tariff_code)
                        FROM do_custom.do_harmonized_tariff_codes tc
                       WHERE     tc.country = pv_regions
                             AND tc.style_number = msib.segment1)
                         commodity_code,
                     terms.NAME
                         term_name,
                     ooha.attribute2
                         order_class,
                     DECODE (
                         cpv_show_land_cost,
                         'Y', SUM (
                                    NVL (
                                        get_cic_item_cost (
                                            pn_elim_org,
                                            rtl.inventory_item_id,
                                            'N'),
                                        0)
                                  * DECODE (
                                        rtl.line_type,
                                        'LINE', DECODE (
                                                    NVL (
                                                        rtl.interface_line_attribute11,
                                                        0),
                                                    0, NVL (
                                                           rtl.quantity_invoiced,
                                                           NVL (
                                                               rtl.quantity_credited,
                                                               0)),
                                                    0),
                                        0)),
                         NULL)
                         AS macau_cost,
                     DECODE (
                         cpv_show_land_cost,
                         'Y', SUM (
                                    NVL -- Start changes by BT Technology Team v3.0 on 29-Dec-2014
                                        --(xxdo.get_mmt_cost
                                        (
                                        get_mmt_cost -- End changes by BT Technology Team v3.0 on 29-Dec-2014
                                                     (
                                            rtl.interface_line_attribute6,
                                            rtl.interface_line_attribute7,
                                            rtl.warehouse_id,
                                            rt.set_of_books_id, -- Added by BT Tech Team for defect# 570 on 17-Nov-15
                                            'MATAMT'),
                                        0)
                                  * DECODE (
                                        rtl.line_type,
                                        'LINE', DECODE (
                                                    NVL (
                                                        rtl.interface_line_attribute11,
                                                        0),
                                                    0, 1,
                                                    0),
                                        0)),
                         NULL)
                         material_cost,
                     custs.customer_number,
                     xxdo.get_item_details ('NA',
                                            rtl.inventory_item_id,
                                            'CURRENT')
                         AS current_season,
                     xxdo.get_item_details ('NA',
                                            rtl.inventory_item_id,
                                            'SUB_GROUP')
                         AS sub_group,
                     -- Start changes by BT Technology Team v3.0 on 29-Dec-2014
                     xxdo.get_item_details ('NA',
                                            rtl.inventory_item_id,
                                            'INTRO')
                         AS sub_class,
                     -- End changes by BT Technology Team v3.0 on 29-Dec-2014
                     rtl.interface_line_attribute6
                         line_num,                           --Added by Sarita
                     gl_dist.account_class, -- Added by BT Tech Team for defect# 570 on 17-Nov-15
                     -- get_parent_ord_det(rtl.interface_line_attribute6,rtl.org_id,'OI') Original_Invoice
                     rtl.interface_line_attribute11,          -- Added for 4.2
                     DECODE (rtl.inventory_item_id, NULL, 'N', 'Y')
                         avg_mrg_flag,                        -- Added for 4.2
                     rtl.interface_line_attribute3            -- Added for 4.2
                FROM apps.hr_all_organization_units_tl wh_name, apps.hr_all_organization_units_tl org_name, -- Start changes by BT Technology Team v3.0 on 29-Dec-2014
                                                                                                            --apps.ra_site_uses_all rasu,
                                                                                                            --apps.ra_customers custs,
                                                                                                            xxd_ra_site_uses_morg_v rasu,
                     xxd_ra_customers_v custs, -- End changes by BT Technology Team v3.0 on 29-Dec-2014
                                               apps.mtl_system_items_b msib, -- Start changes by BT Technology Team v3.0 on 29-Dec-2014
                                                                             --apps.ra_addresses_all addr,
                                                                             xxd_ra_addresses_morg_v addr,
                     -- End changes by BT Technology Team v3.0 on 29-Dec-2014
                     apps.ra_cust_trx_types_all rtt, apps.ra_customer_trx_lines_all rtl, apps.ra_customer_trx_all rt,
                     apps.oe_order_headers_all ooha, --apps.zx_lines zl, ----Commented by BT tech team on 13-Nov-15 for defect# 570
                                                     apps.ra_cust_trx_line_gl_dist_all gl_dist, apps.ra_terms_tl terms,
                     apps.ra_batch_sources_all rbs
               WHERE     rt.trx_date BETWEEN cp_from_date AND cp_to_date
                     AND rbs.batch_source_id = rt.batch_source_id
                     AND rbs.NAME <> 'Trade Management'
                     --                  and rt.trx_number = ('100007581')
                     AND rbs.org_id = rt.org_id
                     -- AND rt.org_id = cpn_region_ou
                     AND org_name.NAME = cpn_region_ou -- Added on 05-May-2015
                     -- AND rt.interface_header_context ='ORDER ENTRY' -- Added on 05-May-2015
                     AND gl_dist.customer_trx_line_id =
                         rtl.customer_trx_line_id
                     -- Start modification for CR 120 by BT Technology Team on 26-Aug-2015
                     --AND gl_dist.account_class = ('REV')
                     AND gl_dist.account_class IN ('REV', 'FREIGHT')
                     -- End modification for CR 120 by BT Technology Team on 26-Aug-2015
                     AND gl_dist.account_set_flag = 'N'
                     AND gl_dist.org_id = rtl.org_id
                     AND addr.address_id(+) = rasu.address_id
                     --    AND addr.address_id = rtl.ship_to_address_id  --Modified against ENHC0012592 -- Commented on 12-SEP-2016
                     AND custs.customer_id = rt.bill_to_customer_id
                     AND rtl.customer_trx_id = rt.customer_trx_id
                     AND rtt.cust_trx_type_id = rt.cust_trx_type_id
                     AND rtt.org_id = rt.org_id
                     AND rt.complete_flag = 'Y'
                     AND rtl.line_type IN ('LINE', 'FREIGHT', 'CHARGES')
                     AND org_name.LANGUAGE = USERENV ('LANG')
                     AND org_name.organization_id = rt.org_id
                     AND wh_name.LANGUAGE(+) = USERENV ('LANG')
                     AND wh_name.organization_id(+) = rtl.warehouse_id
                     AND rasu.site_use_id(+) = rt.ship_to_site_use_id
                     AND msib.organization_id(+) = rtl.warehouse_id
                     AND msib.inventory_item_id(+) = rtl.inventory_item_id
                     AND rtl.interface_line_attribute1 =
                         TO_CHAR (ooha.order_number(+))
                     AND rtl.org_id = ooha.org_id(+)
                     AND rtl.sales_order = ooha.order_number(+)
                     --Start Changes by BT tech team on 13-Nov-15 for defect# 570
                     --AND zl.application_id(+) = 222
                     --AND zl.trx_line_id(+) = rtl.customer_trx_line_id
                     --AND zl.trx_id(+) = rtl.customer_trx_id
                     --End Changes by BT tech team on 13-Nov-15 for defect# 570
                     AND rt.term_id = terms.term_id(+)
                     AND terms.LANGUAGE(+) = 'US'
                     AND NVL (rtl.warehouse_id, 1) =
                         NVL (pn_inv_org, NVL (rtl.warehouse_id, 1))
                     AND NVL (
                             rt.attribute5,
                             xxdo.get_item_details ('NA',
                                                    rtl.inventory_item_id,
                                                    'BRAND')) =
                         NVL (
                             pv_brand,
                             NVL (
                                 rt.attribute5,
                                 xxdo.get_item_details ('NA',
                                                        rtl.inventory_item_id,
                                                        'BRAND')))
            GROUP BY org_name.NAME, rt.attribute5, rt.customer_trx_id,
                     rt.attribute2, rt.trx_number, rt.trx_date,
                     custs.customer_name, /*    DECODE (cp_style_grouping,
                                                      'Y', NVL (msib.segment1, rtl.description),
                                                      NULL
                                                     ),*/
                                          rtl.description, rt.invoice_currency_code,
                     msib.segment1, rtl.uom_code, --Start Changes by BT tech team on 13-Nov-15 for defect# 570
                                                  --zl.tax_rate_code,
                                                  --zl.tax_rate,
                                                  --tax_rate_code,
                                                  --tax_rate,
                                                  --End Changes by BT tech team on 13-Nov-15 for defect# 570
                                                  rt.exchange_rate,
                     --  msib.segment2,
                     gl_dist.code_combination_id, rt.purchase_order, rt.ship_to_site_use_id,
                     ooha.order_type_id, rtt.NAME, rtl.interface_line_attribute6,
                     rtl.interface_line_attribute7, rtl.org_id, rtl.line_type,
                     rtl.interface_line_attribute11, rtl.warehouse_id, rtl.inventory_item_id,
                     addr.country, addr.postal_code, addr.state,
                     addr.province, addr.address2, addr.address1,
                     addr.city,                 --Modified against ENHC0012592
                                addr.address_key, terms.NAME,
                     ooha.attribute2, rt.interface_header_attribute2, addr.site_number,
                     custs.customer_number, custs.customer_id, rt.org_id,
                     rtl.customer_trx_line_id, -- Added below by BT Tech Team for defect# 570 on 17-Nov-15
                                               gl_dist.account_class, rt.set_of_books_id,
                     gl_dist.cust_trx_line_gl_dist_id, rtl.interface_line_attribute3 -- Added for 4.2
            -- Added above by BT Tech Team for defect# 570 on 17-Nov-15
            UNION ALL
              SELECT NVL (
                         rt.attribute5,
                         xxdo.get_item_details ('NA',
                                                rtl.inventory_item_id,
                                                'BRAND'))
                         AS brand,
                     xxdo.get_item_details ('NA',
                                            rtl.inventory_item_id,
                                            'GENDER')
                         AS gender,
                     get_vat_number (custs.customer_id, rt.org_id)
                         AS vat_number,
                     addr.postal_code
                         AS zip_code,
                     NVL (addr.state, addr.province)
                         state,
                     addr.address2,
                     addr.address1,
                     addr.city,                 --Modified against ENHC0012592
                     addr.address_key,
                     org_name.NAME
                         AS organization_name,
                     MAX (wh_name.NAME)
                         AS warehouse_name,
                     MAX (addr.country)
                         AS country,
                     rt.customer_trx_id,
                     NVL (rt.attribute2, rt.trx_number)
                         AS invoice_number,                         --Global e
                     rt.trx_number
                         AS transaction_number,
                     rt.trx_date
                         AS invoice_date,
                     -- Start changes by BT Technology Team on 17-Dec-2015 for Defect 785
                     -- MAX (rt.interface_header_attribute1) AS sales_order,
                     MAX (rtl.sales_order)
                         AS sales_order,
                     -- End changes by BT Technology Team on 17-Dec-2015 for Defect 785
                     NULL
                         AS factory_inv,
                     custs.customer_name
                         AS sell_to_customer_name,
                     rt.invoice_currency_code,
                     NVL (
                         xxdo.get_item_details ('NA',
                                                rtl.inventory_item_id,
                                                'PRODUCT'),
                         DECODE (
                             cp_style_grouping,
                             'Y', NVL (
                                      xxdo.get_item_details (
                                          'NA',
                                          rtl.inventory_item_id,
                                          'STYLE'),
                                      rtl.description),
                             NULL))
                         AS series,
                     DECODE (
                         cp_style_grouping,
                         'Y', NVL (
                                  DECODE (
                                      xxdo.get_item_details (
                                          'NA',
                                          rtl.inventory_item_id,
                                          'STYLE'),
                                      'NA', rtl.description,
                                      xxdo.get_item_details (
                                          'NA',
                                          rtl.inventory_item_id,
                                          'STYLE')),
                                  rtl.description),
                         NULL)                                          -- 4.2
                         AS style,
                     xxdo.get_item_details ('NA',
                                            rtl.inventory_item_id,
                                            'COLOR')
                         AS color,
                     --Start modification for CR 92 by BT Technology Team on 31-Jul-15
                     xxdo.get_item_details ('NA',
                                            rtl.inventory_item_id,
                                            'ITEM_TYPE')
                         AS item_type,
                     --End modification for CR 92 by BT Technology Team on 31-Jul-15
                     --     SUM (NVL (rtl.extended_amount, 0) * NVL (rt.exchange_rate, 1)) AS invoice_total,
                     SUM (NVL (gl_dist.amount, 0) * NVL (rt.exchange_rate, 1))
                         AS invoice_total, -- Modified by BT Dev Team on 10-MAY-2016 for 3.5
                     --     SUM (NVL (rtl.extended_amount, 0)) AS pre_conv_inv_total,
                     SUM (NVL (gl_dist.amount, 0))
                         AS pre_conv_inv_total, -- Modified by BT Dev Team on 10-MAY-2016 for 3.4
                     NULL
                         AS invoiced_qty,
                     NULL
                         AS trans_landed_cost_of_goods,
                     NULL
                         cogs_acct,
                     NULL
                         AS ship_landed_cost_of_goods,
                     NULL
                         unit_selling_price,
                     NULL
                         unit_list_price,
                     NULL
                         discount,
                     NULL
                         ext_discount,
                     --Start Changes by BT tech team on 13-Nov-15 for defect# 570
                     --zl.tax_rate_code,
                     --zl.tax_rate, SUM (NVL (zl.tax_amt, 0)) AS pre_conv_tax_amt,
                     get_tax_details (rt.customer_trx_id,
                                      rtl.customer_trx_line_id,
                                      'TAX_RATE_CODE')
                         tax_rate_code,
                     get_tax_details (rt.customer_trx_id,
                                      rtl.customer_trx_line_id,
                                      'TAX_RATE')
                         tax_rate,
                     get_tax_details (rt.customer_trx_id,
                                      rtl.customer_trx_line_id,
                                      'TAX_AMOUNT')
                         pre_conv_tax_amt,
                       --sum(nvl(zl.TAXABLE_AMT,0)) AS TAXABLE_AMT
                       --    SUM (NVL (rtl.extended_amount, 0))
                       SUM (NVL (gl_dist.amount, 0))       -- Modified for 3.7
                     --+ SUM (NVL (zl.tax_amt, 0)) AS pre_conv_total_amt,
                     + get_tax_details (rt.customer_trx_id,
                                        rtl.customer_trx_line_id,
                                        'TAX_AMOUNT')
                         AS pre_conv_total_amt,
                     ROUND (
                           --    (  SUM (NVL (rtl.extended_amount, 0))
                           (SUM (NVL (gl_dist.amount, 0))  -- Modified for 3.7
                                                          --+ SUM (NVL (zl.tax_amt, 0))
                                                          + get_tax_details (rt.customer_trx_id, rtl.customer_trx_line_id, 'TAX_AMOUNT') --End Changes by BT tech team on 13-Nov-15 for defect# 570
                                                                                                                                        )
                         * NVL (rt.exchange_rate, 1),
                         2)
                         AS total_amt,
                     -- Added below by BT Tech Team for defect# 570 on 17-Nov-15
                     NVL (
                         get_account (rt.customer_trx_id,
                                      rt.set_of_books_id,
                                      gl_dist.cust_trx_line_gl_dist_id),
                         (SELECT glc.concatenated_segments
                            FROM apps.gl_code_combinations_kfv glc
                           WHERE gl_dist.code_combination_id =
                                 glc.code_combination_id))
                         ACCOUNT,
                     -- Added above by BT Tech Team for defect# 570 on 17-Nov-15
                     hsoe.get_price_list_value (pn_price_list,
                                                rtl.inventory_item_id)
                         wholesale_price,
                     rt.purchase_order,
                     addr.site_number
                         party_site_number,
                     rt.interface_header_attribute2
                         order_type,
                     rtt.NAME
                         ar_type,
                     SUM (
                         ROUND (
                               NVL (rtl.extended_amount, 0)
                             * (SELECT conversion_rate
                                  FROM apps.gl_daily_rates
                                 WHERE     conversion_type = 'Corporate'
                                       AND from_currency =
                                           rt.invoice_currency_code
                                       AND to_currency = 'USD'
                                       AND conversion_date =
                                           TRUNC (rt.trx_date)),
                             2))
                         usd_revenue_total,
                     NULL
                         original_order,
                     NULL
                         original_shipment_date,
                     NULL
                         commodity_code,
                     terms.NAME
                         term_name,
                     NULL
                         order_class,
                     NULL
                         AS macau_cost,
                     NULL
                         material_cost,
                     custs.customer_number,
                     NULL
                         AS current_season,
                     NULL
                         AS sub_group,
                     -- Start changes by BT Technology Team v3.0 on 29-Dec-2014
                     NULL
                         AS sub_class,
                     -- End changes by BT Technology Team v3.0 on 29-Dec-2014
                     NULL
                         line_num,                           --Added by Sarita
                     gl_dist.account_class, -- Added by BT Tech Team for defect# 570 on 17-Nov-15
                     -- get_parent_ord_det(rtl.interface_line_attribute6,rtl.org_id,'OI') Original_Invoice
                     rtl.interface_line_attribute11,          -- Added for 4.2
                     DECODE (rtl.inventory_item_id, NULL, 'N', 'Y')
                         avg_mrg_flag,                        -- Added for 4.2
                     rtl.interface_line_attribute3            -- Added for 4.2
                FROM apps.hr_all_organization_units_tl wh_name, apps.hr_all_organization_units_tl org_name, -- Start changes by BT Technology Team v3.0 on 29-Dec-2014
                                                                                                            --apps.ra_site_uses_all rasu,
                                                                                                            --apps.ra_customers custs,
                                                                                                            xxd_ra_site_uses_morg_v rasu,
                     xxd_ra_customers_v custs, -- End changes by BT Technology Team v3.0 on 29-Dec-2014
                                               apps.mtl_system_items_b msib, -- Start changes by BT Technology Team v3.0 on 29-Dec-2014
                                                                             --apps.ra_addresses_all addr,
                                                                             xxd_ra_addresses_morg_v addr,
                     -- End changes by BT Technology Team v3.0 on 29-Dec-2014
                     apps.ra_cust_trx_types_all rtt, apps.ra_customer_trx_lines_all rtl, apps.ra_customer_trx_all rt,
                     apps.oe_order_headers_all ooha, --apps.zx_lines zl, --Commented by BT tech team on 13-Nov-15 for defect# 570
                                                     apps.ra_cust_trx_line_gl_dist_all gl_dist, apps.ra_terms_tl terms,
                     apps.ra_batch_sources_all rbs
               WHERE     rt.trx_date BETWEEN cp_from_date AND cp_to_date
                     AND rbs.batch_source_id = rt.batch_source_id
                     AND rbs.NAME = 'Trade Management'
                     AND rbs.org_id = rt.org_id
                     AND org_name.NAME = cpn_region_ou -- Added on 05-May-2015
                     -- AND rt.interface_header_context ='ORDER ENTRY' -- Added on 05-May-2015
                     AND gl_dist.customer_trx_line_id =
                         rtl.customer_trx_line_id
                     AND gl_dist.account_class = 'REV'
                     AND gl_dist.account_set_flag = 'N'
                     AND gl_dist.org_id = rtl.org_id
                     AND addr.address_id(+) = rasu.address_id
                     --    AND addr.ADDRESS_ID = rtl.SHIP_TO_ADDRESS_ID --Modified against ENHC0012592 -- Commented on 21-SEP-2016
                     AND custs.customer_id = rt.bill_to_customer_id
                     AND rtl.customer_trx_id = rt.customer_trx_id
                     AND rtt.cust_trx_type_id = rt.cust_trx_type_id
                     AND rtt.org_id = rt.org_id
                     AND rt.complete_flag = 'Y'
                     AND rtl.line_type IN ('LINE', 'FREIGHT', 'CHARGES')
                     AND org_name.LANGUAGE = USERENV ('LANG')
                     AND org_name.organization_id = rt.org_id
                     AND wh_name.LANGUAGE(+) = USERENV ('LANG')
                     AND wh_name.organization_id(+) = rtl.warehouse_id
                     AND rasu.site_use_id(+) = rt.ship_to_site_use_id
                     AND msib.organization_id(+) = rtl.warehouse_id
                     AND msib.inventory_item_id(+) = rtl.inventory_item_id
                     AND rtl.interface_line_attribute1 =
                         TO_CHAR (ooha.order_number(+))
                     AND rtl.org_id = ooha.org_id(+)
                     AND rtl.sales_order = ooha.order_number(+)
                     --Start Changes by BT tech team on 13-Nov-15 for defect# 570
                     --AND zl.application_id(+) = 222
                     --AND zl.trx_line_id(+) = rtl.customer_trx_line_id
                     --AND zl.trx_id(+) = rtl.customer_trx_id
                     --End Changes by BT tech team on 13-Nov-15 for defect# 570
                     AND rt.term_id = terms.term_id(+)
                     AND terms.LANGUAGE(+) = 'US'
                     AND NVL (rtl.warehouse_id, 1) =
                         NVL (pn_inv_org, NVL (rtl.warehouse_id, 1))
                     AND NVL (
                             rt.attribute5,
                             xxdo.get_item_details ('NA',
                                                    rtl.inventory_item_id,
                                                    'BRAND')) =
                         NVL (
                             pv_brand,
                             NVL (
                                 rt.attribute5,
                                 xxdo.get_item_details ('NA',
                                                        rtl.inventory_item_id,
                                                        'BRAND')))
            GROUP BY org_name.NAME, rt.attribute5, rt.customer_trx_id,
                     rt.attribute2, rt.trx_number, rt.trx_date,
                     custs.customer_name, /*    DECODE (cp_style_grouping,
                                                      'Y', NVL (msib.segment1, rtl.description),
                                                      NULL
                                                     ),*/
                                          rtl.description, rt.invoice_currency_code,
                     msib.segment1, rtl.uom_code, --Start Changes by BT tech team on 13-Nov-15 for defect# 570
                                                  --zl.tax_rate_code,
                                                  --zl.tax_rate,
                                                  --tax_rate_code,
                                                  --tax_rate,
                                                  --End Changes by BT tech team on 13-Nov-15 for defect# 570
                                                  rt.exchange_rate,
                     --  msib.segment2,
                     gl_dist.code_combination_id, rt.purchase_order, rt.ship_to_site_use_id,
                     ooha.order_type_id, rtt.NAME, rtl.interface_line_attribute6,
                     rtl.interface_line_attribute7, rtl.org_id, rtl.line_type,
                     rtl.interface_line_attribute11, rtl.warehouse_id, rtl.inventory_item_id,
                     addr.country, addr.postal_code, addr.state,
                     addr.province, addr.address2, addr.address1,
                     addr.city,                 --Modified against ENHC0012592
                                addr.address_key, terms.NAME,
                     ooha.attribute2, rt.interface_header_attribute2, addr.site_number,
                     custs.customer_number, custs.customer_id, rt.org_id,
                     rtl.customer_trx_line_id, -- Added below by BT Tech Team for defect# 570 on 17-Nov-15
                                               gl_dist.account_class, rt.set_of_books_id,
                     gl_dist.cust_trx_line_gl_dist_id, rtl.interface_line_attribute3; -- Added for 4.2;

        -- Added above by BT Tech Team for defect# 570 on 17-Nov-15

        TYPE c_det_tabtype IS TABLE OF c_det%ROWTYPE
            INDEX BY PLS_INTEGER;

        det_tbl                 c_det_tabtype;

        CURSOR c_ou (cpv_regions VARCHAR2, cpn_region_ou VARCHAR2)
        IS
            SELECT ffv.flex_value
              FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values ffv
             WHERE     ffvs.flex_value_set_id = ffv.flex_value_set_id
                   AND ffvs.flex_value_set_name = 'XXDO_REGION_BASED_OU'
                   AND ffv.parent_flex_value_low = cpv_regions
                   AND ffv.flex_value = NVL (cpn_region_ou, ffv.flex_value)
                   AND ffv.enabled_flag = 'Y';

        -- Commented below by BT Tech Team for defect# 570 on 17-Nov-15
        --Start modification for CR 120 by BT Technology Team on 26-Aug-2015
        /* CURSOR lcr_get_acct_type (
            p_cust_trx_id    NUMBER,
            p_account        VARCHAR2)
         IS
            SELECT DISTINCT gl_dist.account_class
              FROM ra_cust_trx_line_gl_dist_all gl_dist,
                   ra_customer_trx_lines_all rtl
             WHERE     gl_dist.customer_trx_line_id = rtl.customer_trx_line_id
                   AND gl_dist.account_set_flag = 'N'
                   AND gl_dist.org_id = rtl.org_id
                   AND gl_dist.code_combination_id IN
                          (SELECT code_combination_id
                             FROM gl_code_combinations_kfv
                            WHERE concatenated_segments = p_account)
                   AND rtl.customer_trx_id = p_cust_trx_id;*/
        -- Commented above by BT Tech Team for defect# 570 on 17-Nov-15

        --End modification for CR 120 by BT Technology Team on 26-Aug-2015
        l_start_date            DATE;
        l_end_date              DATE;
        ld_date                 DATE;
        --lc_acct_type        VARCHAR2 (30);-- Commented by BT Tech Team for defect# 570 on 17-Nov-15

        --Parameters Added for
        lv_file_path            VARCHAR2 (360) := pv_file_path;
        lv_output_file          UTL_FILE.file_type;
        lv_outbound_file        VARCHAR2 (360)
            :=    'IDR_'
               || FND_GLOBAL.CONC_REQUEST_ID
               || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS');
        lv_ver                  VARCHAR2 (32767) := NULL;
        lv_line                 VARCHAR2 (32767) := NULL;
        lv_delimiter            VARCHAR2 (1) := CHR (9);
        lv_file_delimiter       VARCHAR2 (1) := ',';
        ln_average_margin       NUMBER := 0;                            -- 4.2
        ln_consolidated_cost    NUMBER := 0;                            -- 4.2
        lv_markup_type          VARCHAR2 (100) := NULL;                  --4.2
        ln_freight_count        NUMBER := 0;
        ln_disc_count           NUMBER := 0;
        lv_line_category_code   oe_order_lines_all.line_category_code%TYPE;
    BEGIN
        EXECUTE IMMEDIATE 'truncate table XXDO.XXDOAR_INVOICE_DET';

        print_log_prc (
            'p_from_date: ' || fnd_conc_date.string_to_date (p_from_date));
        print_log_prc (
            'p_to_date: ' || fnd_conc_date.string_to_date (p_to_date));
        print_log_prc ('pv_show_land_cost: ' || pv_show_land_cost);
        print_log_prc ('pv_custom_cost: ' || pv_custom_cost);
        print_log_prc ('pv_regions: ' || pv_regions);
        print_log_prc ('pn_region_ou: ' || pn_region_ou);
        print_log_prc ('pn_inv_org: ' || pn_inv_org);
        print_log_prc ('pn_price_list: ' || pn_price_list);
        print_log_prc ('pn_elim_org: ' || pn_elim_org);
        print_log_prc ('pv_brand: ' || pv_brand);
        print_log_prc ('pv_disc_len: ' || pv_disc_len);
        l_from_date        := fnd_conc_date.string_to_date (p_from_date);
        l_to_date          := fnd_conc_date.string_to_date (p_to_date);
        l_show_land_cost   := pv_show_land_cost;
        l_custom_cost      := pv_custom_cost;
        l_regions          := pv_regions;
        l_region_ou        := pn_region_ou;
        --c_invoice_tbl := get_invoices(l_include_style, l_from_date, l_to_date,l_show_land_cost,l_custom_cost,l_regions,l_region_ou,pn_price_list);
        apps.do_debug_utils.set_level (1);

        IF apps.fnd_profile.VALUE ('DO_DEF_ALERT_SENDER') IS NULL
        THEN
            RAISE ex_no_sender;
        END IF;

        IF NVL (l_include_style, 'N') = 'Y'
        THEN
            l_style   := 'Style' || CHR (9);
        ELSE
            l_style   := '';
        END IF;

        FOR ou_i IN c_ou (pv_regions, pn_region_ou)
        LOOP
            ld_date   := fnd_conc_date.string_to_date (p_from_date);

            WHILE fnd_conc_date.string_to_date (p_to_date) >= ld_date
            LOOP
                IF fnd_conc_date.string_to_date (p_to_date) >= ld_date + 5
                THEN
                    -- if someone chages 5 to x then CHANGE_PROPAGATION_SETS below to x and below to x+1
                    l_start_date   := ld_date;
                    l_end_date     := ld_date + 5;
                ELSE
                    l_start_date   := ld_date;
                    l_end_date     :=
                        fnd_conc_date.string_to_date (p_to_date);
                END IF;

                OPEN c_det (cp_style_grouping    => l_include_style,
                            cp_from_date         => l_start_date,
                            cp_to_date           => l_end_date,
                            cpv_show_land_cost   => pv_show_land_cost,
                            cpv_custom_cost      => pv_custom_cost,
                            cpn_region_ou        => ou_i.flex_value,
                            pn_price_list        => pn_price_list,
                            pv_regions           => pv_regions);

                LOOP
                    FETCH c_det BULK COLLECT INTO det_tbl LIMIT 20000;

                    IF det_tbl.COUNT > 0
                    THEN
                        FOR i IN det_tbl.FIRST .. det_tbl.LAST
                        LOOP
                            /* Added by Murali */
                            v_employee_order    := NULL;

                            BEGIN
                                SELECT DISTINCT 'Employee Order'
                                  INTO v_employee_order
                                  FROM apps.oe_price_adjustments opa, apps.oe_order_headers_all ooh
                                 WHERE     opa.header_id(+) = ooh.header_id
                                       AND ooh.cancelled_flag <> 'Y'
                                       AND opa.list_line_type_code = 'DIS'
                                       AND (UPPER (
                                                CASE
                                                    WHEN opa.list_line_type_code =
                                                         'DIS'
                                                    THEN
                                                        opa.attribute1
                                                    ELSE
                                                        NULL
                                                END) LIKE
                                                '%EMP%')
                                       AND ooh.order_number =
                                           det_tbl (i).sales_order
                                       AND opa.line_id = det_tbl (i).line_num;
                            --Added to capture line level discount code
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    /*   apps.fnd_file.put_line
                                          (apps.fnd_file.LOG,
                                              'unable to find if employee_order or not based on Discount Code :'
                                           || SQLERRM
                                          );*/
                                    NULL;
                            END;

                            /* Added by murali to get discount_code*/
                            v_discount_code     := NULL;

                            BEGIN
                                SELECT SUBSTR (opa.attribute1, 1, pv_disc_len)
                                  --Changed by Sarita to restrict the characters to be displayed  for the discount code
                                  INTO v_discount_code
                                  FROM apps.oe_price_adjustments opa, apps.oe_order_headers_all ooh
                                 WHERE     opa.header_id = ooh.header_id
                                       -- and opa.header_id=24456865
                                       AND ooh.cancelled_flag <> 'Y'
                                       AND opa.list_line_type_code = 'DIS'
                                       AND ooh.order_number =
                                           det_tbl (i).sales_order
                                       AND opa.line_id = det_tbl (i).line_num
                                       AND opa.price_adjustment_id =
                                           det_tbl (i).interface_line_attribute11
                                       --Added to capture line level discount code
                                       AND ROWNUM = 1;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    --v_discount_code:=null;
                                    /*    apps.fnd_file.put_line
                                                       (apps.fnd_file.LOG,
                                                           'unable to find discount_code:'
                                                        || SQLERRM
                                                       );*/
                                    NULL;
                            END;

                            /*Added by Sarita*/
                            IF v_employee_order IS NULL
                            THEN
                                BEGIN
                                    SELECT DECODE (hcpc.NAME, 'Employee', 'Employee Order', '')
                                      INTO v_employee_order
                                      FROM apps.hz_cust_accounts hca, apps.hz_customer_profiles hcp, apps.hz_cust_profile_classes hcpc
                                     WHERE     hca.cust_account_id =
                                               hcp.cust_account_id
                                           --added by murali
                                           AND hcp.profile_class_id =
                                               hcpc.profile_class_id
                                           --added by murali
                                           AND hcp.site_use_id IS NULL
                                           AND hca.account_number =
                                               det_tbl (i).customer_number;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        /*  apps.fnd_file.put_line
                                             (apps.fnd_file.LOG,
                                                 'unable to find if employee_order or not based on profile Class :'
                                              || SQLERRM
                                             );*/
                                        NULL;
                                END;
                            END IF;

                            /* end of code change Sarita*/

                            /* end of code change murali*/
                            -- 4.2 changes start

                            -- exclusing freight
                            ln_average_margin   := NULL;

                            IF (det_tbl (i).line_num IS NOT NULL AND det_tbl (i).avg_mrg_flag = 'Y')
                            THEN
                                SELECT COUNT (1)
                                  INTO ln_freight_count
                                  FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                                 WHERE     1 = 1
                                       AND ffvs.flex_value_set_name =
                                           'XXD_GL_AR_MARKUP_ACCT_TYPE_VS'
                                       AND ffvs.flex_value_set_id =
                                           ffvl.flex_value_set_id
                                       AND NVL (ffvl.enabled_flag, 'Y') = 'Y'
                                       AND NVL (
                                               TRUNC (ffvl.start_date_active),
                                               TRUNC (SYSDATE)) <=
                                           TRUNC (SYSDATE)
                                       AND NVL (TRUNC (ffvl.end_date_active),
                                                TRUNC (SYSDATE)) >=
                                           TRUNC (SYSDATE)
                                       AND ffvl.flex_value =
                                           det_tbl (i).account_class;

                                /*fnd_file.put_line(fnd_file.log,'det_tbl (i).account_class'||det_tbl (i).account_class);
                             fnd_file.put_line(fnd_file.log,'ln_freight_count'||ln_freight_count);
                             fnd_file.put_line(fnd_file.log,'det_tbl (i).invoice_number'||det_tbl (i).invoice_number);*/

                                -- exclusing discout
                                IF (v_discount_code IS NULL)
                                THEN
                                    BEGIN
                                        SELECT COUNT (1)
                                          INTO ln_disc_count
                                          FROM apps.oe_price_adjustments opa
                                         WHERE     1 = 1
                                               AND opa.list_line_type_code =
                                                   'DIS'
                                               AND opa.price_adjustment_id =
                                                   det_tbl (i).interface_line_attribute11;
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            ln_disc_count   := 0;
                                    END;
                                END IF;

                                ln_average_margin   := NULL;


                                IF     ln_freight_count = 0
                                   AND v_discount_code IS NULL
                                   AND ln_disc_count = 0
                                THEN
                                    BEGIN
                                        SELECT attribute2 markup_type
                                          INTO lv_markup_type
                                          FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                                         WHERE     1 = 1
                                               AND ffvs.flex_value_set_name =
                                                   'XXD_CM_CAPTURE_MARGINS_VS'
                                               AND ffvs.flex_value_set_id =
                                                   ffvl.flex_value_set_id
                                               AND NVL (ffvl.enabled_flag,
                                                        'Y') =
                                                   'Y'
                                               AND NVL (
                                                       TRUNC (
                                                           ffvl.start_date_active),
                                                       TRUNC (SYSDATE)) <=
                                                   TRUNC (SYSDATE)
                                               AND NVL (
                                                       TRUNC (
                                                           ffvl.end_date_active),
                                                       TRUNC (SYSDATE)) >=
                                                   TRUNC (SYSDATE)
                                               AND attribute1 =
                                                   (SELECT organization_id
                                                      FROM hr_operating_units
                                                     WHERE name =
                                                           det_tbl (i).organization_name);
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            lv_markup_type   := NULL;
                                    END;



                                    IF NVL (lv_markup_type, 'N') =
                                       'On-hand Markup'
                                    THEN
                                        BEGIN
                                            print_log_prc (
                                                   ' On-hand Markup ln_Avg_margin - '
                                                || ln_average_margin
                                                || '  for trx_number --'
                                                || det_tbl (i).invoice_number);

                                            SELECT -- SUM(to_number(mmt.attribute14)* NVL( det_tbl (i).invoiced_qty,1))--Average Margin
                                                   MAX (TO_NUMBER (mmt.attribute14)) * NVL (det_tbl (i).invoiced_qty, 1)
                                              INTO ln_average_margin
                                              FROM mtl_material_transactions mmt, mtl_transaction_types mtt
                                             WHERE     mmt.transaction_type_id =
                                                       mtt.transaction_type_id
                                                   AND transaction_type_name IN
                                                           ('Sales order issue', 'RMA Receipt')
                                                   AND trx_source_line_id =
                                                       det_tbl (i).line_num; -- oola.line_id

                                            /*fnd_file.put_line
                                                      (apps.fnd_file.LOG,
                                                          'Average Margin is:'||ln_average_margin||'-'||'for line:'||det_tbl (i).line_num
                                                      );*/
                                            print_log_prc (
                                                   ' On-hand Markup ln_Avg_margin after - '
                                                || ln_average_margin
                                                || '  for trx_number --'
                                                || det_tbl (i).invoice_number);
                                        EXCEPTION
                                            WHEN OTHERS
                                            THEN
                                                ln_average_margin   := NULL;
                                        /*fnd_file.put_line
                                                     (apps.fnd_file.LOG,
                                                         'unable to find Average Margin'
                                                      || SQLERRM||'-'||'for line:'||det_tbl (i).line_num
                                                     );*/
                                        END;
                                    ELSIF NVL (lv_markup_type, 'N') =
                                          'Direct Markup'
                                    THEN
                                        BEGIN
                                            --      print_log_prc(' Direct Markup ln_Avg_margin - '||ln_average_margin||'  for trx_number --'||det_tbl(i).invoice_number);
                                            BEGIN
                                                SELECT line_category_code
                                                  INTO lv_line_category_code
                                                  FROM apps.oe_order_lines_all ool
                                                 WHERE ool.line_id =
                                                       det_tbl (i).line_num;
                                            EXCEPTION
                                                WHEN OTHERS
                                                THEN
                                                    lv_line_category_code   :=
                                                        NULL;
                                            END;

                                            IF (lv_line_category_code = 'RETURN')
                                            THEN
                                                SELECT --MAX(to_number(mmt.attribute14))--Average Margin
                                                       SUM (TO_NUMBER (mmt.attribute14))
                                                  INTO ln_average_margin
                                                  FROM mtl_material_transactions mmt, mtl_transaction_types mtt
                                                 WHERE     mmt.transaction_type_id =
                                                           mtt.transaction_type_id
                                                       AND transaction_type_name IN
                                                               ('Sales order issue', 'RMA Receipt')
                                                       AND trx_source_line_id =
                                                           det_tbl (i).line_num; -- oola.line_id

                                                /*fnd_file.put_line
                             (apps.fnd_file.LOG,
                              'Average Margin is:'||ln_average_margin||'-'||'for line:'||det_tbl (i).line_num
                             );*/
                                                print_log_prc (
                                                       ' Direct Markup ln_Avg_margin - '
                                                    || ln_average_margin
                                                    || '  for trx_number --'
                                                    || det_tbl (i).invoice_number
                                                    || ' Line num'
                                                    || det_tbl (i).line_num
                                                    || ' ORDER_NUMBER '
                                                    || det_tbl (i).sales_order);
                                            ELSE
                                                SELECT --MAX(to_number(mmt.attribute14))--Average Margin
                                                       SUM (TO_NUMBER (mmt.attribute14))
                                                  INTO ln_average_margin
                                                  FROM mtl_material_transactions mmt, mtl_transaction_types mtt
                                                 WHERE     mmt.transaction_type_id =
                                                           mtt.transaction_type_id
                                                       AND transaction_type_name IN
                                                               ('Sales order issue', 'RMA Receipt')
                                                       AND trx_source_line_id =
                                                           det_tbl (i).line_num
                                                       AND trx_source_delivery_id =
                                                           det_tbl (i).interface_line_attribute3; -- oola.line_id

                                                /*fnd_file.put_line
                             (apps.fnd_file.LOG,
                              'Average Margin is:'||ln_average_margin||'-'||'for line:'||det_tbl (i).line_num
                             );*/
                                                print_log_prc (
                                                       ' Direct Markup ln_Avg_margin - '
                                                    || ln_average_margin
                                                    || '  for trx_number --'
                                                    || det_tbl (i).invoice_number
                                                    || ' Line num'
                                                    || det_tbl (i).line_num
                                                    || ' ORDER_NUMBER '
                                                    || det_tbl (i).sales_order);
                                            END IF;
                                        EXCEPTION
                                            WHEN OTHERS
                                            THEN
                                                ln_average_margin   := NULL;
                                                /*fnd_file.put_line
                                                             (apps.fnd_file.LOG,
                                                                 'unable to find Average Margin'
                                                              || SQLERRM||'-'||'for line:'||det_tbl (i).line_num
                                                             );*/
                                                fnd_file.put_line (
                                                    apps.fnd_file.LOG,
                                                       'unable to find Average Margin'
                                                    || SQLERRM
                                                    || '-'
                                                    || 'for line:'
                                                    || det_tbl (i).line_num
                                                    || ' ORDER_NUMBER '
                                                    || det_tbl (i).sales_order);
                                        END;
                                    END IF;
                                END IF;
                            --4.2 chnges end
                            END IF;

                            BEGIN
                                INSERT INTO xxdo.xxdoar_invoice_det (
                                                brand,
                                                organization_name,
                                                warehouse_name,
                                                address1,
                                                address2,
                                                city,
                                                state,
                                                country,
                                                gender,
                                                address_key,
                                                customer_trx_id,
                                                invoice_number,
                                                transaction_number,
                                                invoice_date,
                                                sales_order,
                                                factory_inv,
                                                customer_number,
                                                employee_order,
                                                discount_code,
                                                sell_to_customer_name,
                                                invoice_currency_code,
                                                series,
                                                style,
                                                color,
                                                --Start modification for CR 92 by BT Technology Team on 31-Jul-15
                                                item_type,
                                                --End modification for CR 92 by BT Technology Team on 31-Jul-15
                                                invoice_total,
                                                pre_conv_inv_total,
                                                invoiced_qty,
                                                trans_landed_cost_of_goods,
                                                cogs_acct,
                                                ship_landed_cost_of_goods,
                                                unit_selling_price,
                                                unit_list_price,
                                                discount,
                                                ext_discount,
                                                tax_rate_code,
                                                tax_rate,
                                                pre_conv_tax_amt,
                                                pre_conv_total_amt,
                                                total_amt,
                                                ACCOUNT,
                                                wholesale_price,
                                                purchase_order,
                                                party_site_number,
                                                order_type,
                                                ar_type,
                                                usd_revenue_total,
                                                original_order,
                                                original_shipment_date,
                                                commodity_code,
                                                term_name,
                                                order_class,
                                                macau_cost,
                                                material_cost,
                                                current_season,
                                                sub_group,
                                                sub_class,
                                                --Added by BT Technology Team v3.0 on 29-Dec-2014
                                                vat_number,
                                                zip_code,
                                                account_type, -- Added by BT Tech Team for defect# 570 on 17-Nov-15
                                                average_margin)          --4.2
                                         VALUES (
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).brand),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).organization_name),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).warehouse_name),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).address1),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).address2),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).city),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).state),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).country),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).gender),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).address_key),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).customer_trx_id),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).invoice_number),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).transaction_number),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).invoice_date),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).sales_order),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).factory_inv),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).customer_number),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        v_employee_order),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        v_discount_code),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).sell_to_customer_name),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).invoice_currency_code),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).series),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).style),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).color),
                                                    --Start modification for CR 92 by BT Technology Team on 31-Jul-15
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).item_type),
                                                    --End modification for CR 92 by BT Technology Team on 31-Jul-15
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).invoice_total),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).pre_conv_inv_total),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).invoiced_qty),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        DECODE (
                                                            pv_show_land_cost,
                                                            'Y', det_tbl (i).trans_landed_cost_of_goods,
                                                            0)),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).cogs_acct),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        DECODE (
                                                            pv_show_land_cost,
                                                            'Y', det_tbl (i).ship_landed_cost_of_goods,
                                                            0)),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).unit_selling_price),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).unit_list_price),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).discount),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).ext_discount),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).tax_rate_code),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).tax_rate),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).pre_conv_tax_amt),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).pre_conv_total_amt),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).total_amt),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).ACCOUNT),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).wholesale_price),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).purchase_order),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).party_site_number),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).order_type),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).ar_type),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).usd_revenue_total),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).original_order),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).original_shipment_date),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).commodity_code),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).term_name),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).order_class),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).macau_cost),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).material_cost),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).current_season),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).sub_group),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).sub_class),
                                                    --Added by BT Technology Team v3.0 on 29-Dec-2014
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).vat_number),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).zip_code),
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        det_tbl (i).account_class), -- Added by BT Tech Team for defect# 570 on 17-Nov-15
                                                    XXD_REMOVE_JUNK_CHAR_FNC (
                                                        ln_average_margin) -- 4.2
                                                                          );

                                COMMIT;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    apps.fnd_file.put_line (
                                        apps.fnd_file.LOG,
                                           'Unexpected Error Encountered : '
                                        || SQLCODE
                                        || '-'
                                        || SQLERRM);
                                    ROLLBACK; --TO SAVEPOINT before_newfobitem
                            END;
                        END LOOP;
                    END IF;

                    EXIT WHEN c_det%NOTFOUND;
                END LOOP;

                CLOSE c_det;

                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                       'Start-Date '
                    || l_start_date
                    || ' End-Date '
                    || l_end_date);
                ld_date   := ld_date + 6;
            -- if p_to_date >= ld_date Then
            -- EXIT;
            -- end if;
            END LOOP;                                             --While End;
        END LOOP;                                                  -- OU Loop;

        --Added for CCR0007628 -- Start
        lv_delimiter       := CHR (9);
        lv_ver             :=
               'Brand'
            || lv_delimiter
            || 'Organization'
            || lv_delimiter
            || 'Warehouse'
            || lv_delimiter
            || 'Invoice Num'
            || lv_delimiter
            || 'Transaction Num'                           -- Global E Project
            || lv_delimiter
            || 'AR Type'
            || lv_delimiter
            || 'Invoice Date'
            || lv_delimiter
            || 'Order Num'
            || lv_delimiter
            || 'Order Type'
            || lv_delimiter
            || 'Factory Inv Num '
            || lv_delimiter
            || 'Customer Number'
            || lv_delimiter
            || 'Customer'
            || lv_delimiter
            || 'Employee Order'
            || lv_delimiter
            || 'Discount Code'
            || lv_delimiter
            || 'Party Site Number'
            || lv_delimiter
            || 'Address Name'
            || lv_delimiter
            || 'ADDRESS1'
            || lv_delimiter
            || 'ADDRESS2'
            || lv_delimiter
            || 'SHIP_TO_CITY'                   --Modified against ENHC0012592
            || lv_delimiter
            || 'STATE'
            || lv_delimiter
            || 'Country'
            || lv_delimiter
            || 'Zip Code'
            || lv_delimiter
            || 'Vat Number'
            || lv_delimiter
            || 'Product Group'
            || lv_delimiter
            || 'Sub Group'
            -- Start changes by BT Technology Team v3.0 on 29-Dec-2014
            || lv_delimiter
            || 'Sub Class'
            -- End changes by BT Technology Team v3.0 on 29-Dec-2014
            || lv_delimiter
            || 'Gender'
            || lv_delimiter
            || 'Current Season'
            || lv_delimiter
            || l_style
            || 'Color'
            --Start modification for CR 92 by BT Technology Team on 31-Jul-15
            || lv_delimiter
            || 'Item Type'
            --End modification for CR 92 by BT Technology Team on 31-Jul-15
            || lv_delimiter
            || 'Commodity Code'
            --Start modification for CR 120 by BT Technology Team on 26-Aug-2015
            || lv_delimiter
            || 'Account Type'
            --End modification for CR 120 by BT Technology Team on 26-Aug-2015
            || lv_delimiter
            || 'Revenue Amount'
            || lv_delimiter
            || 'Currency'
            || lv_delimiter
            || 'Functional Revenue Amount'
            || lv_delimiter
            || 'Quantity'
            || lv_delimiter
            || 'Current Landed Cost'
            || lv_delimiter
            || 'Transaction Landed Cost'
            || lv_delimiter
            || 'Unit Selling Price'
            || lv_delimiter
            || 'Unit List Price'
            || lv_delimiter
            || 'Discount'
            || lv_delimiter
            || 'Ext Discount'
            || lv_delimiter
            || 'Tax Rate Code'
            || lv_delimiter
            || 'Tax Rate'
            || lv_delimiter
            || 'Entered Tax Amt'
            || lv_delimiter
            || 'Entered Total Amt'
            || lv_delimiter
            || 'Functional Total Amt'
            || lv_delimiter
            || 'Wholesale price'
            || lv_delimiter
            || 'Revenue Account'
            || lv_delimiter
            || 'COGS ACCT'
            || lv_delimiter
            || 'Purchase Order'
            || lv_delimiter
            || 'Original Order'
            || lv_delimiter
            || 'Original Shipment Date'
            || lv_delimiter
            || 'USD Revenue Total'
            || lv_delimiter
            || 'Term Name'
            || lv_delimiter
            || 'Order Class'
            || lv_delimiter
            || 'MACAU Cost'
            || lv_delimiter
            || 'Material Cost'
            || lv_delimiter
            || 'Consolidated Cost'
            || lv_delimiter                                             -- 4.2
            || 'Average Margin';                                         --4.2

        --Printing Output
        apps.fnd_file.put_line (apps.fnd_file.output, lv_ver);

        --Writing into a file
        IF pv_send_to_bl = 'Y'
        THEN
            lv_output_file   :=
                UTL_FILE.fopen (lv_file_path, lv_outbound_file || '.tmp', 'W' --opening the file in write mode
                                , 32767);

            IF UTL_FILE.is_open (lv_output_file)
            THEN
                lv_ver   := REPLACE (lv_ver, lv_delimiter, lv_file_delimiter);
                UTL_FILE.put_line (lv_output_file, lv_ver);
            END IF;
        END IF;

        --Added for CCR0007628 -- End

        /* LOOP THROUGH INVOICES */
        FOR i IN c_invoices
        LOOP
            BEGIN
                IF NVL (l_include_style, 'N') = 'Y'
                THEN
                    l_style   := SUBSTR (i.style, 1, 239) || CHR (9);
                ELSE
                    l_style   := '';
                END IF;

                --4.2 changes start
                --ln_consolidated_cost := (NVL(i.trans_landed_cost_of_goods,0)-NVL(i.average_margin,0));
                --ln_consolidated_cost := (NVL(i.consolidated_cost,0)-NVL(i.average_margin,0));
                ln_consolidated_cost   :=
                    ROUND (
                        (NVL (i.trans_landed_cost_of_goods, 0) - (NVL (i.average_margin, 0) * i.invoiced_qty)),
                        2);

                IF ln_consolidated_cost <= 0
                THEN
                    ln_consolidated_cost   := 0;
                END IF;

                --4.2 changes end

                -- Commented below by BT Tech Team for defect# 570 on 17-Nov-15
                --Start modification for CR 120 by BT Technology Team on 26-Aug-2015
                /* OPEN lcr_get_acct_type (i.customer_trx_id, i.account);

                 FETCH lcr_get_acct_type INTO lc_acct_type;

                 CLOSE lcr_get_acct_type;*/
                -- Commented above by BT Tech Team for defect# 570 on 17-Nov-15

                --End modification for CR 120 by BT Technology Team on 26-Aug-2015
                lv_delimiter   := CHR (9);
                lv_line        :=
                       -- START : Modified by Infosys for 3.5.
                       REPLACE (i.brand, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.organization_name, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.warehouse_name, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.invoice_number, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.transaction_number, CHR (9), ' ') -- Global E Project
                    || lv_delimiter
                    || REPLACE (i.ar_type, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (TO_CHAR (i.invoice_date, 'MM/DD/YYYY'),
                                CHR (9),
                                ' ')
                    || lv_delimiter
                    || REPLACE (i.sales_order, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.order_type, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.factory_inv, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.customer_number, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.sell_to_customer_name, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.employee_order, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.discount_code, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.party_site_number, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.address_key, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.address1, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.address2, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.city, CHR (9), ' ') --Modified against ENHC0012592
                    || lv_delimiter
                    || REPLACE (i.state, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.country, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.zip_code, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.vat_number, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.series, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.sub_group, CHR (9), ' ')
                    -- Start changes by BT Technology Team v3.0 on 29-Dec-2014
                    || lv_delimiter
                    || REPLACE (i.sub_class, CHR (9), ' ')
                    -- End changes by BT Technology Team v3.0 on 29-Dec-2014
                    || lv_delimiter
                    || REPLACE (i.gender, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.current_season, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (l_style, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.color, CHR (9), ' ')
                    --Start modification for CR 92 by BT Technology Team on 31-Jul-15
                    || lv_delimiter
                    || REPLACE (i.item_type, CHR (9), ' ')
                    --End modification for CR 92 by BT Technology Team on 31-Jul-15
                    || lv_delimiter
                    || REPLACE (i.commodity_code, CHR (9), ' ')
                    --Start modification for CR 120 by BT Technology Team on 26-Aug-2015
                    || lv_delimiter
                    -- || lc_acct_type-- Commented by BT Tech Team for defect# 570 on 17-Nov-15
                    || REPLACE (i.account_type, CHR (9), ' ') -- Added by BT Tech Team for defect# 570 on 17-Nov-15
                    --End modification for CR 120 by BT Technology Team on 26-Aug-2015
                    || lv_delimiter
                    || REPLACE (i.pre_conv_inv_total, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.invoice_currency_code, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.invoice_total, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.invoiced_qty, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.ship_landed_cost_of_goods, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.trans_landed_cost_of_goods, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.unit_selling_price, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.unit_list_price, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.discount, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.ext_discount, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.tax_rate_code, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.tax_rate, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.pre_conv_tax_amt, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.pre_conv_total_amt, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.total_amt, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.wholesale_price, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.ACCOUNT, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.cogs_acct, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.purchase_order, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.original_order, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.original_shipment_date, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.usd_revenue_total, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.term_name, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.order_class, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.macau_cost, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.material_cost, CHR (9), ' ')
                    || lv_delimiter
                    --|| REPLACE (i.consolidated_cost, CHR (9), ' ') -- 4.2
                    || REPLACE (ln_consolidated_cost, CHR (9), ' ')      --4.2
                    || lv_delimiter
                    || REPLACE (i.average_margin, CHR (9), ' ');         --4.2


                apps.fnd_file.put_line (apps.fnd_file.output, lv_line);

                --   fnd_file.put_line (fnd_file.LOG,  i.USD_REVENUE_TOTAL);

                --Added for CCR0007628 -- Start
                --Writing into a file
                IF pv_send_to_bl = 'Y'
                THEN
                    IF UTL_FILE.is_open (lv_output_file)
                    THEN
                        lv_line   :=
                            REPLACE (lv_line,
                                     lv_delimiter,
                                     lv_file_delimiter);
                        UTL_FILE.put_line (lv_output_file, lv_line);
                    END IF;
                END IF;
            --Added for CCR0007628 -- End
            EXCEPTION
                WHEN OTHERS
                THEN
                    apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, -- Start changes by BT Technology Team v3.0 on 29-Dec-2014
                                                                                                     --v_application_id      => 'XXDO.XXDOAR_INVDETREG_PKG.INTL_INVOICES',
                                                                                                     v_application_id => 'XXDOAR_INVDETREG_PKG.INTL_INVOICES', -- End changes by BT Technology Team v3.0 on 29-Dec-2014
                                                                                                                                                               v_debug_text => CHR (10) || 'Global exception handler hit (' || SQLCODE || '): ' || SQLERRM || 'Invoice Number :' || i.invoice_number
                                               , l_debug_level => 1);
            END;
        END LOOP;

        IF pv_send_to_bl = 'Y'
        THEN
            UTL_FILE.fclose (lv_output_file);
            UTL_FILE.frename (src_location    => lv_file_path,
                              src_filename    => lv_outbound_file || '.tmp',
                              dest_location   => lv_file_path,
                              dest_filename   => lv_outbound_file || '.csv',
                              overwrite       => TRUE);
        END IF;
    EXCEPTION
        WHEN UTL_FILE.invalid_path
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXDOAR_INVDETREG_PKG.INTL_INVOICES', v_debug_text => CHR (10) || 'INVALID_PATH: File location or filename was invalid.'
                                       , l_debug_level => 1);
        WHEN UTL_FILE.invalid_mode
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXDOAR_INVDETREG_PKG.INTL_INVOICES', v_debug_text => CHR (10) || 'INVALID_MODE: The open_mode parameter in FOPEN was invalid.'
                                       , l_debug_level => 1);
        WHEN UTL_FILE.invalid_filehandle
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXDOAR_INVDETREG_PKG.INTL_INVOICES', v_debug_text => CHR (10) || 'INVALID_FILEHANDLE: The file handle was invalid.'
                                       , l_debug_level => 1);
        WHEN UTL_FILE.invalid_operation
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXDOAR_INVDETREG_PKG.INTL_INVOICES', v_debug_text => CHR (10) || 'INVALID_OPERATION: The file could not be opened or operated on as requested.'
                                       , l_debug_level => 1);
        WHEN UTL_FILE.read_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXDOAR_INVDETREG_PKG.INTL_INVOICES', v_debug_text => CHR (10) || 'READ_ERROR: An operating system error occurred during the read operation.'
                                       , l_debug_level => 1);
        WHEN UTL_FILE.write_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXDOAR_INVDETREG_PKG.INTL_INVOICES', v_debug_text => CHR (10) || 'WRITE_ERROR: An operating system error occurred during the write operation.'
                                       , l_debug_level => 1);
        WHEN UTL_FILE.internal_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXDOAR_INVDETREG_PKG.INTL_INVOICES', v_debug_text => CHR (10) || 'INTERNAL_ERROR: An unspecified error in PL/SQL.'
                                       , l_debug_level => 1);
        WHEN UTL_FILE.invalid_filename
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXDOAR_INVDETREG_PKG.INTL_INVOICES', v_debug_text => CHR (10) || 'INVALID_FILENAME: The filename parameter is invalid.'
                                       , l_debug_level => 1);
        WHEN ex_no_data_found
        THEN
            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, -- Start changes by BT Technology Team v3.0 on 29-Dec-2014
                                                                                             -- v_application_id      => 'XXDO.XXDOAR_INVDETREG_PKG.INTL_INVOICES',
                                                                                             v_application_id => 'XXDOAR_INVDETREG_PKG.INTL_INVOICES', -- End changes by BT Technology Team v3.0 on 29-Dec-2014
                                                                                                                                                       v_debug_text => CHR (10) || 'There are no international invoices for the specified month.'
                                       , l_debug_level => 1);
        WHEN ex_no_recips
        THEN
            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, -- Start changes by BT Technology Team v3.0 on 29-Dec-2014
                                                                                             --v_application_id      => 'XXDO.XXDOAR_INVDETREG_PKG.INTL_INVOICES',
                                                                                             v_application_id => 'XXDOAR_INVDETREG_PKG.INTL_INVOICES', -- End changes by BT Technology Team v3.0 on 29-Dec-2014
                                                                                                                                                       v_debug_text => CHR (10) || 'There were no recipients configured to receive the alert'
                                       , l_debug_level => 1);
        WHEN ex_no_sender
        THEN
            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, -- Start changes by BT Technology Team v3.0 on 29-Dec-2014
                                                                                             -- v_application_id      => 'XXDO.XXDOAR_INVDETREG_PKG.INTL_INVOICES',
                                                                                             v_application_id => 'XXDOAR_INVDETREG_PKG.INTL_INVOICES', -- End changes by BT Technology Team v3.0 on 29-Dec-2014
                                                                                                                                                       v_debug_text => CHR (10) || 'There is no sender configured. Check the profile value DO_DEF_ALERT_SENDER'
                                       , l_debug_level => 1);
        WHEN OTHERS
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, -- Start changes by BT Technology Team v3.0 on 29-Dec-2014
                                                                                             -- v_application_id      => 'XXDO.XXDOAR_INVDETREG_PKG.INTL_INVOICES',
                                                                                             v_application_id => 'XXDOAR_INVDETREG_PKG.INTL_INVOICES', -- End changes by BT Technology Team v3.0 on 29-Dec-2014
                                                                                                                                                       v_debug_text => CHR (10) || 'Global exception handler hit (' || SQLCODE || '): ' || SQLERRM
                                       , l_debug_level => 1);
    END;

    PROCEDURE pending_edi_invoices (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, v_send_none_msg IN VARCHAR2:= 'N')
    IS
        l_width_brand      CONSTANT NUMBER := 8;
        l_width_trxnum     CONSTANT NUMBER := 12;
        l_width_trxdate    CONSTANT NUMBER := 12;
        l_width_custname   CONSTANT NUMBER := 30;
        l_width_ordnum     CONSTANT NUMBER := 10;
        l_width_picknum    CONSTANT NUMBER := 10;
        l_width_qty        CONSTANT NUMBER := 11;
        l_width_amt        CONSTANT NUMBER := 13;
        l_ret_val                   NUMBER := 0;
        v_def_mail_recips           apps.do_mail_utils.tbl_recips;
        ex_no_recips                EXCEPTION;
        ex_no_sender                EXCEPTION;
        ex_no_data_found            EXCEPTION;

        TYPE c_inv_rec IS RECORD
        (
            brand                 VARCHAR (10),
            trx_number            VARCHAR (20),
            trx_date              DATE,
            customer_name         VARCHAR (50),
            order_number          VARCHAR (30),
            pick_ticket_number    VARCHAR (30),
            invoiced_quantity     NUMBER,
            invoiced_amount       NUMBER
        );

        TYPE c_inv_tbl IS TABLE OF c_inv_rec
            INDEX BY BINARY_INTEGER;

        c_invoice_tbl               c_inv_tbl;

        FUNCTION get_invoices
            RETURN c_inv_tbl
        IS
            p_ret   c_inv_tbl;

            CURSOR c_invoices IS
                  SELECT rta.attribute5 AS brand, custs.customer_name, rta.trx_date,
                         rta.trx_number, rta.interface_header_attribute1 AS order_number, rta.interface_header_attribute3 AS pick_ticket_number,
                         SUM (rtla.quantity_invoiced) AS invoiced_quantity, SUM (extended_amount) AS invoiced_amount
                    FROM apps.ra_customer_trx_lines_all rtla, -- Start changes by BT Technology Team v3.0 on 29-Dec-2014
                                                              --apps.ra_customers custs,
                                                              xxd_ra_customers_v custs, -- End changes by BT Technology Team v3.0 on 29-Dec-2014
                                                                                        apps.ra_cust_trx_types_all rtta,
                         apps.ra_customer_trx_all rta
                   WHERE     rtta.cust_trx_type_id = rta.cust_trx_type_id
                         AND rtta.org_id = rta.org_id
                         AND rtla.customer_trx_id = rta.customer_trx_id
                         AND rtla.line_type = 'LINE'
                         AND rtla.interface_line_attribute11 = 0
                         AND custs.customer_id = rta.bill_to_customer_id
                         AND rtta.TYPE = 'INV'                 --Invoices Only
                         AND rta.edi_processed_flag IS NULL --Unprocessed Invoices
                         AND SUBSTR (custs.attribute9, 2, 1) = '1'
                         --Only extract invoices for customers with EDI inv flag set
                         AND rta.customer_trx_id >
                             ( --Start with CUSTOMER_TRX_ID after last processed invoice
                              SELECT MAX (customer_trx_id)
                                FROM apps.ra_customer_trx_all
                               WHERE edi_processed_flag = 'Y')
                GROUP BY rta.attribute5, custs.customer_name, rta.trx_date,
                         rta.trx_number, rta.interface_header_attribute1, rta.interface_header_attribute3;
        BEGIN
            FOR c_inv IN c_invoices
            LOOP
                p_ret (p_ret.COUNT + 1).brand       := c_inv.brand;
                p_ret (p_ret.COUNT).trx_number      := c_inv.trx_number;
                p_ret (p_ret.COUNT).trx_date        := c_inv.trx_date;
                p_ret (p_ret.COUNT).customer_name   := c_inv.customer_name;
                p_ret (p_ret.COUNT).order_number    := c_inv.order_number;
                p_ret (p_ret.COUNT).pick_ticket_number   :=
                    c_inv.pick_ticket_number;
                p_ret (p_ret.COUNT).invoiced_quantity   :=
                    c_inv.invoiced_quantity;
                p_ret (p_ret.COUNT).invoiced_amount   :=
                    c_inv.invoiced_amount;
            END LOOP;

            RETURN p_ret;
        END;
    BEGIN
        c_invoice_tbl       := get_invoices;
        apps.do_debug_utils.set_level (1);

        IF apps.fnd_profile.VALUE ('DO_DEF_ALERT_SENDER') IS NULL
        THEN
            RAISE ex_no_sender;
        END IF;

        apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'APPS.DO_OM_REPORT.PENDING_EDI_INVOICES', v_debug_text => 'Recipients...'
                                   , l_debug_level => 1);
        v_def_mail_recips   := get_email_recips ('apps.DO_EDI_ALERTS');

        FOR i IN 1 .. v_def_mail_recips.COUNT
        LOOP
            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'APPS.DO_OM_REPORT.PENDING_EDI_INVOICES', v_debug_text => v_def_mail_recips (i)
                                       , l_debug_level => 1);
        END LOOP;

        IF v_def_mail_recips.COUNT < 1
        THEN
            RAISE ex_no_recips;
        END IF;

        IF c_invoice_tbl.COUNT < 1
        THEN
            --No data.
            RAISE ex_no_data_found;
        END IF;

        /* E-MAIL HEADER */
        apps.do_mail_utils.send_mail_header (apps.fnd_profile.VALUE ('DO_DEF_ALERT_SENDER'), v_def_mail_recips, 'Invoices Pending EDI Extraction - ' || TO_CHAR (SYSDATE, 'MM/DD/YYYY')
                                             , l_ret_val);
        apps.do_mail_utils.send_mail_line (
               RPAD ('Brand', l_width_brand, ' ')
            || RPAD ('Customer', l_width_custname, ' ')
            || LPAD ('Inv. Date', l_width_trxdate, ' ')
            || LPAD ('Invoice #', l_width_trxnum, ' ')
            || LPAD ('Order #', l_width_ordnum, ' ')
            || LPAD ('Pick #', l_width_picknum, ' ')
            || LPAD ('Quantity', l_width_qty, ' ')
            || LPAD ('Amount', l_width_amt, ' '),
            l_ret_val);
        apps.do_mail_utils.send_mail_line (
            RPAD (
                '=',
                  l_width_brand
                + l_width_trxdate
                + l_width_trxnum
                + l_width_custname
                + l_width_ordnum
                + l_width_picknum
                + l_width_qty
                + l_width_amt,
                '='),
            l_ret_val);
        apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'apps.DO_OM_REPORT.PENDING_EDI_INVOICES', v_debug_text => CHR (10) || RPAD ('Brand', l_width_brand, ' ') || RPAD ('Customer', l_width_custname, ' ') || LPAD ('Inv. Date', l_width_trxdate, ' ') || LPAD ('Invoice #', l_width_trxnum, ' ') || LPAD ('Order #', l_width_ordnum, ' ') || LPAD ('Pick #', l_width_picknum, ' ') || LPAD ('Quantity', l_width_qty, ' ') || LPAD ('Amount', l_width_amt, ' ')
                                   , l_debug_level => 100);
        apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'apps.DO_OM_REPORT.PENDING_EDI_INVOICES', v_debug_text => RPAD ('=', l_width_brand + l_width_trxdate + l_width_trxnum + l_width_custname + l_width_ordnum + l_width_picknum + l_width_qty + l_width_amt, '=')
                                   , l_debug_level => 100);

        /* LOOP THROUGH PICK TICKETS */
        FOR i IN 1 .. c_invoice_tbl.COUNT
        LOOP
            apps.do_mail_utils.send_mail_line (
                   RPAD (c_invoice_tbl (i).brand, l_width_brand, ' ')
                || RPAD (c_invoice_tbl (i).customer_name,
                         l_width_custname,
                         ' ')
                || LPAD (TO_CHAR (c_invoice_tbl (i).trx_date, 'MM/DD/YYYY'),
                         l_width_trxdate,
                         ' ')
                || LPAD (c_invoice_tbl (i).trx_number, l_width_trxnum, ' ')
                || LPAD (c_invoice_tbl (i).order_number, l_width_ordnum, ' ')
                || LPAD (c_invoice_tbl (i).pick_ticket_number,
                         l_width_picknum,
                         ' ')
                || LPAD (c_invoice_tbl (i).invoiced_quantity,
                         l_width_qty,
                         ' ')
                || LPAD (
                       TO_CHAR (c_invoice_tbl (i).invoiced_amount,
                                'FML999,999,990.00'),
                       l_width_amt,
                       ' '),
                l_ret_val);
            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'APPS.DO_OM_REPORT.PENDING_EDI_INVOICES', v_debug_text => RPAD (c_invoice_tbl (i).brand, l_width_brand, ' ') || RPAD (c_invoice_tbl (i).customer_name, l_width_custname, ' ') || LPAD (TO_CHAR (c_invoice_tbl (i).trx_date, 'MM/DD/YYYY'), l_width_trxdate, ' ') || LPAD (c_invoice_tbl (i).trx_number, l_width_trxnum, ' ') || LPAD (c_invoice_tbl (i).order_number, l_width_ordnum, ' ') || LPAD (c_invoice_tbl (i).pick_ticket_number, l_width_picknum, ' ') || LPAD (c_invoice_tbl (i).invoiced_quantity, l_width_qty, ' ') || LPAD (TO_CHAR (c_invoice_tbl (i).invoiced_amount, 'FML999,999,990.00'), l_width_amt, ' ')
                                       , l_debug_level => 100);
        END LOOP;

        apps.do_mail_utils.send_mail_close (l_ret_val);
    EXCEPTION
        WHEN ex_no_data_found
        THEN
            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'APPS..DO_OM_REPORT.PENDING_EDI_INVOICES', v_debug_text => CHR (10) || 'There are no invoices pending extraction.'
                                       , l_debug_level => 1);

            IF v_send_none_msg = 'Y'
            THEN
                apps.do_mail_utils.send_mail_header (apps.fnd_profile.VALUE ('DO_DEF_ALERT_SENDER'), v_def_mail_recips, 'Invoices Pending EDI Extraction - ' || TO_CHAR (SYSDATE, 'MM/DD/YYYY')
                                                     , l_ret_val);
                apps.do_mail_utils.send_mail_line (
                    'There are no invoices pending extraction.',
                    l_ret_val);
                apps.do_mail_utils.send_mail_close (l_ret_val);      --Be Safe
            END IF;
        WHEN ex_no_recips
        THEN
            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'apps.DO_OM_REPORT.PENDING_EDI_INVOICES', v_debug_text => CHR (10) || 'There were no recipients configured to receive the alert'
                                       , l_debug_level => 1);
            apps.do_mail_utils.send_mail_close (l_ret_val);          --Be Safe
        WHEN ex_no_sender
        THEN
            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'apps.DO_OM_REPORT.PENDING_EDI_INVOICES', v_debug_text => CHR (10) || 'There is no sender configured. Check the profile value DO_DEF_ALERT_SENDER'
                                       , l_debug_level => 1);
            apps.do_mail_utils.send_mail_close (l_ret_val);          --Be Safe
        WHEN OTHERS
        THEN
            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'apps.DO_OM_REPORT.PENDING_EDI_INVOICES', v_debug_text => CHR (10) || 'Global exception handler hit (' || SQLCODE || '): ' || SQLERRM
                                       , l_debug_level => 1);
            apps.do_mail_utils.send_mail_close (l_ret_val);          --Be Safe
            ROLLBACK;
    END;

    PROCEDURE new_accounts (errbuf               OUT VARCHAR2,
                            retcode              OUT VARCHAR2,
                            v_send_none_msg   IN     VARCHAR2 := 'N')
    IS
        l_width_customer_name     CONSTANT NUMBER := 30;
        l_width_customer_number   CONSTANT NUMBER := 30;
        l_width_creation_date     CONSTANT NUMBER := 12;
        l_width_user_name         CONSTANT NUMBER := 50;
        l_ret_val                          NUMBER := 0;
        l_use_month                        DATE := ADD_MONTHS (SYSDATE, -1);
        l_from_date                        DATE;
        l_to_date                          DATE;
        v_def_mail_recips                  apps.do_mail_utils.tbl_recips;
        v_subject                          VARCHAR2 (100);
        ex_no_recips                       EXCEPTION;
        ex_no_sender                       EXCEPTION;
        ex_no_data_found                   EXCEPTION;

        TYPE c_new_acct_rec IS RECORD
        (
            customer_name      VARCHAR (100),
            customer_number    VARCHAR (30),
            creation_date      DATE,
            user_name          VARCHAR (50)
        );

        TYPE c_new_account_tbl IS TABLE OF c_new_acct_rec
            INDEX BY BINARY_INTEGER;

        c_new_acct_tbl                     c_new_account_tbl;

        FUNCTION get_new_accounts (p_from_date IN DATE, p_to_date IN DATE)
            RETURN c_new_account_tbl
        IS
            p_ret   c_new_account_tbl;

            CURSOR c_new_accts IS
                  SELECT customer_name, customer_number, creation_date,
                         user_name
                    FROM do_custom.do_ar_new_accounts_v
                   WHERE     creation_date >= p_from_date
                         AND creation_date < p_to_date + 1
                ORDER BY creation_date, customer_id;
        BEGIN
            FOR c_new_acct IN c_new_accts
            LOOP
                p_ret (p_ret.COUNT + 1).customer_name   :=
                    c_new_acct.customer_name;
                p_ret (p_ret.COUNT).customer_number   :=
                    c_new_acct.customer_number;
                p_ret (p_ret.COUNT).creation_date   :=
                    c_new_acct.creation_date;
                p_ret (p_ret.COUNT).user_name   := c_new_acct.user_name;
            END LOOP;

            RETURN p_ret;
        END;
    BEGIN
        l_from_date      := TRUNC (l_use_month, 'MM');
        l_to_date        := TRUNC (LAST_DAY (l_use_month));
        v_subject        :=
               'New Accounts for '
            || TO_CHAR (l_from_date, 'MM/DD/YYYY')
            || ' to '
            || TO_CHAR (l_to_date, 'MM/DD/YYYY');
        c_new_acct_tbl   := get_new_accounts (l_from_date, l_to_date);
        apps.do_debug_utils.set_level (1);

        IF apps.fnd_profile.VALUE ('DO_DEF_ALERT_SENDER') IS NULL
        THEN
            RAISE ex_no_sender;
        END IF;

        apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, -- Start changes by BT Technology Team v3.0 on 29-Dec-2014
                                                                                         -- v_application_id      => 'XXDO.XXDOAR_INVDETREG_PKG.NEW_ACCOUNTS',
                                                                                         v_application_id => 'XXDOAR_INVDETREG_PKG.NEW_ACCOUNTS', -- End changes by BT Technology Team v3.0 on 29-Dec-2014
                                                                                                                                                  v_debug_text => 'Recipients...'
                                   , l_debug_level => 1);
        v_def_mail_recips   :=
            get_email_recips ('apps.DO_AR_NEW_ACCOUNTS_ALERT');

        FOR i IN 1 .. v_def_mail_recips.COUNT
        LOOP
            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, -- Start changes by BT Technology Team v3.0 on 29-Dec-2014
                                                                                             -- v_application_id      => 'XXDO.XXDOAR_INVDETREG_PKG.NEW_ACCOUNTS',
                                                                                             v_application_id => 'XXDOAR_INVDETREG_PKG.NEW_ACCOUNTS', -- End changes by BT Technology Team v3.0 on 29-Dec-2014
                                                                                                                                                      v_debug_text => v_def_mail_recips (i)
                                       , l_debug_level => 1);
        END LOOP;

        IF v_def_mail_recips.COUNT < 1
        THEN
            RAISE ex_no_recips;
        END IF;

        /* E-MAIL HEADER */
        apps.do_mail_utils.send_mail_header (apps.fnd_profile.VALUE ('apps.DO_DEF_ALERT_SENDER'), v_def_mail_recips, v_subject
                                             , l_ret_val);
        apps.do_mail_utils.send_mail_line (
            'Content-Type: multipart/mixed; boundary=boundarystring',
            l_ret_val);
        apps.do_mail_utils.send_mail_line ('--boundarystring', l_ret_val);
        apps.do_mail_utils.send_mail_line ('Content-Type: text/plain',
                                           l_ret_val);
        apps.do_mail_utils.send_mail_line ('', l_ret_val);
        apps.do_mail_utils.send_mail_line (
            'See attachment for a list of new accounts.',
            l_ret_val);
        apps.do_mail_utils.send_mail_line ('--boundarystring', l_ret_val);
        apps.do_mail_utils.send_mail_line ('Content-Type: text/xls',
                                           l_ret_val);
        apps.do_mail_utils.send_mail_line (
            'Content-Disposition: attachment; filename="newaccts.xls"',
            l_ret_val);
        apps.do_mail_utils.send_mail_line ('', l_ret_val);
        apps.do_mail_utils.send_mail_line (
               'Customer Name'
            || CHR (9)
            || 'Customer Number'
            || CHR (9)
            || 'Account Created'
            || CHR (9)
            || 'Created By',
            l_ret_val);
        apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, -- Start changes by BT Technology Team v3.0 on 29-Dec-2014
                                                                                         --v_application_id      => 'XXDO.XXDOAR_INVDETREG_PKG.NEW_ACCOUNTS',
                                                                                         v_application_id => 'XXDOAR_INVDETREG_PKG.NEW_ACCOUNTS', -- End changes by BT Technology Team v3.0 on 29-Dec-2014
                                                                                                                                                  v_debug_text => CHR (10) || RPAD ('Customer Name', l_width_customer_name, ' ') || RPAD ('Customer Number', l_width_customer_number, ' ') || RPAD ('Account Created', l_width_creation_date, ' ') || RPAD ('Created By', l_width_user_name, ' ')
                                   , l_debug_level => 100);

        FOR i IN 1 .. c_new_acct_tbl.COUNT
        LOOP
            apps.do_mail_utils.send_mail_line (
                   c_new_acct_tbl (i).customer_name
                || CHR (9)
                || c_new_acct_tbl (i).customer_number
                || CHR (9)
                || TO_CHAR (c_new_acct_tbl (i).creation_date, 'MM/DD/YYYY')
                || CHR (9)
                || c_new_acct_tbl (i).user_name,
                l_ret_val);
            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, -- Start changes by BT Technology Team v3.0 on 29-Dec-2014
                                                                                             -- v_application_id      => 'XXDO.XXDOAR_INVDETREG_PKG.NEW_ACCOUNTS',
                                                                                             v_application_id => 'XXDOAR_INVDETREG_PKG.NEW_ACCOUNTS', -- End changes by BT Technology Team v3.0 on 29-Dec-2014
                                                                                                                                                      v_debug_text => RPAD (c_new_acct_tbl (i).customer_name, l_width_customer_name, ' ') || RPAD (c_new_acct_tbl (i).customer_number, l_width_customer_number, ' ') || RPAD (TO_CHAR (c_new_acct_tbl (i).creation_date, 'MM/DD/YYYY'), l_width_creation_date, ' ') || RPAD (c_new_acct_tbl (i).user_name, l_width_user_name, ' ')
                                       , l_debug_level => 100);
        END LOOP;

        apps.do_mail_utils.send_mail_line ('--boundarystring--', l_ret_val);
        apps.do_mail_utils.send_mail_close (l_ret_val);
    EXCEPTION
        WHEN ex_no_data_found
        THEN
            apps.do_debug_utils.WRITE -- Start changes by BT Technology Team v3.0 on 29-Dec-2014
                                      /*(l_debug_loc           => 'XXDO.XXDOAR_INVDETREG_PKG.NEW_ACCOUNTS',
                                       v_application_id      => 'XXDO.XXDOAR_INVDETREG_PKG.INTL_INVOICES',*/
                                      (l_debug_loc => 'XXDOAR_INVDETREG_PKG.NEW_ACCOUNTS', v_application_id => 'XXDOAR_INVDETREG_PKG.INTL_INVOICES', -- End changes by BT Technology Team v3.0 on 29-Dec-2014
                                                                                                                                                     v_debug_text => CHR (10) || 'There are no new accounts for the specified month.'
                                       , l_debug_level => 1);

            IF v_send_none_msg = 'Y'
            THEN
                apps.do_mail_utils.send_mail_header (apps.fnd_profile.VALUE ('DO_DEF_ALERT_SENDER'), v_def_mail_recips, v_subject
                                                     , l_ret_val);
                apps.do_mail_utils.send_mail_line (
                    'There are no international invoices for the specified month.',
                    l_ret_val);
                apps.do_mail_utils.send_mail_close (l_ret_val);      --Be Safe
            END IF;
        WHEN ex_no_recips
        THEN
            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, -- Start changes by BT Technology Team v3.0 on 29-Dec-2014
                                                                                             --v_application_id      => 'XXDO.XXDOAR_INVDETREG_PKG.NEW_ACCOUNTS',
                                                                                             v_application_id => 'XXDOAR_INVDETREG_PKG.NEW_ACCOUNTS', -- End changes by BT Technology Team v3.0 on 29-Dec-2014
                                                                                                                                                      v_debug_text => CHR (10) || 'There were no recipients configured to receive the alert'
                                       , l_debug_level => 1);
            apps.do_mail_utils.send_mail_close (l_ret_val);          --Be Safe
        WHEN ex_no_sender
        THEN
            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, -- Start changes by BT Technology Team v3.0 on 29-Dec-2014
                                                                                             --v_application_id      => 'XXDO.XXDOAR_INVDETREG_PKG.NEW_ACCOUNTS',
                                                                                             v_application_id => 'XXDOAR_INVDETREG_PKG.NEW_ACCOUNTS', -- End changes by BT Technology Team v3.0 on 29-Dec-2014
                                                                                                                                                      v_debug_text => CHR (10) || 'There is no sender configured. Check the profile value DO_DEF_ALERT_SENDER'
                                       , l_debug_level => 1);
            apps.do_mail_utils.send_mail_close (l_ret_val);          --Be Safe
        WHEN OTHERS
        THEN
            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, -- Start changes by BT Technology Team v3.0 on 29-Dec-2014
                                                                                             -- v_application_id      => 'XXDO.XXDOAR_INVDETREG_PKG.NEW_ACCOUNTS',
                                                                                             v_application_id => 'XXDOAR_INVDETREG_PKG.NEW_ACCOUNTS', -- End changes by BT Technology Team v3.0 on 29-Dec-2014
                                                                                                                                                      v_debug_text => CHR (10) || 'Global exception handler hit (' || SQLCODE || '): ' || SQLERRM
                                       , l_debug_level => 1);
            apps.do_mail_utils.send_mail_close (l_ret_val);          --Be Safe
    END;
END xxdoar_invdetreg_pkg;
/
