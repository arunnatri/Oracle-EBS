--
-- XXDOOE_GEN_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:50 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOOE_GEN_PKG"
AS
    /******************************************************************************
       NAME: OM_GEN_PKG
       General Functios in Order Management

       REVISIONS:
       Ver        Date        Author           Description
       ---------  ----------  ---------------  ------------------------------------
       1.0       04/24/2012     Shibu        1. Created this package for XXDOOE_GEN_PKG
       2.0       01/17/2014      Sarita       2. Changed the get_factory_Invoice function to handle the direct procurement AR invoices
    ******************************************************************************/
    FUNCTION GET_PARENT_ORD_DET (PN_SO_LINE_ID   NUMBER,
                                 PN_ORG_ID       NUMBER,
                                 PV_COL          VARCHAR2)
        RETURN VARCHAR2
    IS
        l_return   VARCHAR2 (100);
    BEGIN
        IF PV_COL = 'OO'
        THEN
            BEGIN
                SELECT ooha1.order_number
                  INTO l_return
                  FROM apps.oe_order_headers_all ooha1, apps.oe_order_lines_all oola
                 WHERE     oola.REFERENCE_HEADER_ID = ooha1.header_id
                       AND oola.line_id = PN_SO_LINE_ID
                       AND oola.org_id = PN_ORG_ID;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_return   := NULL;
            END;
        ELSIF PV_COL = 'OSD'
        THEN
            BEGIN
                SELECT oola1.actual_shipment_date
                  INTO l_return
                  FROM apps.oe_order_lines_all oola1, apps.oe_order_lines_all oola
                 WHERE     oola.line_id = PN_SO_LINE_ID
                       AND oola.org_id = PN_ORG_ID
                       AND oola.REFERENCE_LINE_ID = oola1.line_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_return   := NULL;
            END;
        ELSIF PV_COL = 'OI'
        THEN
            BEGIN
                SELECT /*+ index(rtl1  DO_RA_CUST_TRX_LINES_ALL_N1 , rtl1 RA_CUSTOMER_TRX_LINES_N9)  */
                       rt1.trx_number
                  INTO l_return
                  FROM apps.ra_customer_trx_lines_all rtl1, apps.ra_customer_trx_all rt1, apps.oe_order_lines_all oola,
                       apps.oe_order_headers_all ooha1
                 WHERE     oola.REFERENCE_HEADER_ID = ooha1.header_id
                       AND rt1.customer_trx_id = rtl1.customer_trx_id
                       AND rtl1.interface_line_attribute6 =
                           TO_CHAR (oola.REFERENCE_LINE_ID)
                       AND rtl1.interface_line_attribute1 =
                           TO_CHAR (ooha1.order_number)
                       AND rtl1.org_id = ooha1.org_id
                       AND oola.REFERENCE_LINE_ID IS NOT NULL
                       AND rtl1.sales_order IS NOT NULL
                       AND rtl1.interface_line_attribute6 IS NOT NULL
                       AND rtl1.interface_line_attribute1 IS NOT NULL
                       AND rtl1.sales_order = ooha1.order_number
                       AND oola.line_id = PN_SO_LINE_ID
                       AND oola.org_id = PN_ORG_ID;
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
    END GET_PARENT_ORD_DET;


    FUNCTION get_mmt_cost (pn_interface_line_attribute6 NUMBER, pn_interface_line_attribute7 NUMBER, pn_organization_id NUMBER
                           , pv_detail IN VARCHAR)
        RETURN NUMBER
    IS
        ln_cost   NUMBER;
    BEGIN
        IF NVL (pn_interface_line_attribute7, 0) = 0
        THEN
            IF pv_detail = 'TRANSCOST'
            THEN
                BEGIN
                    SELECT ROUND (NVL (transaction_cost, Actual_Cost), 2)
                      INTO ln_cost
                      FROM apps.mtl_material_transactions
                     WHERE     transaction_id IN
                                   (SELECT Transaction_id
                                      FROM apps.mtl_material_transactions mmto
                                     WHERE mmto.TRX_SOURCE_LINE_ID =
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
                            FROM apps.XLA_AE_LINES xal,
                                 (SELECT application_id, event_id, ae_header_id,
                                         ae_line_num
                                    FROM apps.XLA_DISTRIBUTION_LINKS
                                   WHERE     source_distribution_id_num_1 IN
                                                 (SELECT inv_sub_ledger_id
                                                    FROM apps.mTL_TRANSACTION_ACCOUNTS
                                                   WHERE transaction_id IN
                                                             (SELECT Transaction_id
                                                                FROM apps.mtl_material_transactions mmto
                                                               WHERE mmto.TRX_SOURCE_LINE_ID =
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
                                FROM apps.XLA_AE_LINES xal,
                                     (SELECT application_id, event_id, ae_header_id,
                                             ae_line_num
                                        FROM apps.XLA_DISTRIBUTION_LINKS
                                       WHERE     source_distribution_id_num_1 IN
                                                     (SELECT inv_sub_ledger_id
                                                        FROM apps.mTL_TRANSACTION_ACCOUNTS
                                                       WHERE transaction_id IN
                                                                 (SELECT Transaction_id
                                                                    FROM apps.mtl_material_transactions mmto
                                                                   WHERE mmto.TRX_SOURCE_LINE_ID =
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
                                    FROM apps.XLA_AE_LINES xal,
                                         (SELECT application_id, event_id, ae_header_id,
                                                 ae_line_num
                                            FROM apps.XLA_DISTRIBUTION_LINKS
                                           WHERE     source_distribution_id_num_1 IN
                                                         (SELECT inv_sub_ledger_id
                                                            FROM apps.mTL_TRANSACTION_ACCOUNTS
                                                           WHERE     transaction_id IN
                                                                         (SELECT Transaction_id
                                                                            FROM apps.mtl_material_transactions mmto
                                                                           WHERE mmto.TRX_SOURCE_LINE_ID =
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
                                        FROM apps.XLA_AE_LINES xal,
                                             (SELECT application_id, event_id, ae_header_id,
                                                     ae_line_num
                                                FROM apps.XLA_DISTRIBUTION_LINKS
                                               WHERE     source_distribution_id_num_1 IN
                                                             (SELECT inv_sub_ledger_id
                                                                FROM apps.mTL_TRANSACTION_ACCOUNTS
                                                               WHERE     transaction_id IN
                                                                             (SELECT Transaction_id
                                                                                FROM apps.mtl_material_transactions mmto
                                                                               WHERE mmto.TRX_SOURCE_LINE_ID =
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
                                            FROM apps.XLA_AE_LINES xal,
                                                 (SELECT application_id, event_id, ae_header_id,
                                                         ae_line_num
                                                    FROM apps.XLA_DISTRIBUTION_LINKS
                                                   WHERE     source_distribution_id_num_1 IN
                                                                 (SELECT inv_sub_ledger_id
                                                                    FROM apps.mTL_TRANSACTION_ACCOUNTS
                                                                   WHERE transaction_id IN
                                                                             (SELECT Transaction_id
                                                                                FROM apps.mtl_material_transactions mmto
                                                                               WHERE mmto.TRX_SOURCE_LINE_ID =
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
                    SELECT ROUND (NVL (transaction_cost, Actual_Cost), 2)
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
                            FROM apps.XLA_AE_LINES xal,
                                 (SELECT application_id, event_id, ae_header_id,
                                         ae_line_num
                                    FROM apps.XLA_DISTRIBUTION_LINKS
                                   WHERE     source_distribution_id_num_1 IN
                                                 (SELECT inv_sub_ledger_id
                                                    FROM apps.mTL_TRANSACTION_ACCOUNTS
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
                                FROM apps.XLA_AE_LINES xal,
                                     (SELECT application_id, event_id, ae_header_id,
                                             ae_line_num
                                        FROM apps.XLA_DISTRIBUTION_LINKS
                                       WHERE     source_distribution_id_num_1 IN
                                                     (SELECT inv_sub_ledger_id
                                                        FROM apps.mTL_TRANSACTION_ACCOUNTS
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
                                    FROM apps.XLA_AE_LINES xal,
                                         (SELECT application_id, event_id, ae_header_id,
                                                 ae_line_num
                                            FROM apps.XLA_DISTRIBUTION_LINKS
                                           WHERE     source_distribution_id_num_1 IN
                                                         (SELECT inv_sub_ledger_id
                                                            FROM apps.mTL_TRANSACTION_ACCOUNTS
                                                           WHERE     transaction_id =
                                                                     pn_interface_line_attribute7
                                                                 AND cost_ELEMENT_ID =
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
                                        FROM apps.XLA_AE_LINES xal,
                                             (SELECT application_id, event_id, ae_header_id,
                                                     ae_line_num
                                                FROM apps.XLA_DISTRIBUTION_LINKS
                                               WHERE     source_distribution_id_num_1 IN
                                                             (SELECT inv_sub_ledger_id
                                                                FROM apps.mTL_TRANSACTION_ACCOUNTS
                                                               WHERE     transaction_id =
                                                                         pn_interface_line_attribute7
                                                                     AND cost_ELEMENT_ID =
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
                                            FROM apps.XLA_AE_LINES xal,
                                                 (SELECT application_id, event_id, ae_header_id,
                                                         ae_line_num
                                                    FROM apps.XLA_DISTRIBUTION_LINKS
                                                   WHERE     source_distribution_id_num_1 IN
                                                                 (SELECT inv_sub_ledger_id
                                                                    FROM apps.mTL_TRANSACTION_ACCOUNTS
                                                                   WHERE     transaction_id =
                                                                             pn_interface_line_attribute7
                                                                         AND ACCOUNTING_LINE_TYPE =
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
                                                FROM apps.XLA_AE_LINES xal,
                                                     (SELECT application_id, event_id, ae_header_id,
                                                             ae_line_num
                                                        FROM apps.XLA_DISTRIBUTION_LINKS
                                                       WHERE     source_distribution_id_num_1 IN
                                                                     (SELECT inv_sub_ledger_id
                                                                        FROM apps.mTL_TRANSACTION_ACCOUNTS
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
                       AND cic.organization_id = pn_warehouse_id --(select ship_from_org_id from oe_order_lines_all where line_id=pn_interface_line_attribute6)
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
                       AND organization_id = pn_warehouse_id; --(select ship_from_org_id from oe_order_lines_all where line_id=pn_interface_line_attribute6);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_itemcost   := 0;
            END;

            RETURN ln_itemcost;
        END IF;
    END get_cic_item_cost;

    FUNCTION GET_FACTORY_INVOICE (p_Cust_Trx_ID   IN VARCHAR2,
                                  p_Style         IN VARCHAR2)
        RETURN VARCHAR2
    IS
        retval     VARCHAR2 (2000);
        l_po_num   VARCHAR2 (100);

        /*  01/17/2014 ---Sarita --Changed the function to match with the Get Factory Invoice function in package XXDO_AR_REPORTS*/
        CURSOR C1 (pn_custtrxid VARCHAR2)
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
                   AND rtla.customer_trx_id = TO_CHAR (pn_custtrxid) --      10089300
                   AND rcv.shipment_header_id = rsh.shipment_header_id
                   AND SUBSTR (TRIM (rcv.attribute1),
                               1,
                               INSTR (TRIM (rcv.attribute1), '-', 1) - 1) =
                       ship_intl.shipment_id(+)
                   AND SUBSTR (TRIM (rsh.shipment_num),
                               1,
                               INSTR (TRIM (rsh.shipment_num), '-', 1) - 1) =
                       ship_dc1.shipment_id(+);

        CURSOR C2 (pn_Cust_Trx_ID IN VARCHAR2, pv_Style IN VARCHAR2)
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
                   AND rtla.customer_trx_id = TO_CHAR (pn_Cust_Trx_ID)
                   AND mtl.segment1 = pv_Style
                   AND rcv.shipment_header_id = rsh.shipment_header_id
                   AND SUBSTR (TRIM (rcv.attribute1),
                               1,
                               INSTR (TRIM (rcv.attribute1), '-', 1) - 1) =
                       ship_intl.shipment_id(+)
                   AND SUBSTR (TRIM (rsh.shipment_num),
                               1,
                               INSTR (TRIM (rsh.shipment_num), '-', 1) - 1) =
                       ship_dc1.shipment_id(+);

        CURSOR C3 (pn_Cust_Trx_ID IN VARCHAR2)
        IS
              SELECT poh.segment1 po_num, rsh.packing_slip AS factory_invoice, SUM (rsl.quantity_received) rcvd_qty
                FROM apps.rcv_shipment_lines rsl, apps.rcv_shipment_headers rsh, apps.rcv_transactions rcv,
                     apps.mtl_system_items_b msi, apps.po_headers_all poh, apps.ra_customer_trx_all rcta
               WHERE     rsh.shipment_header_id = rsl.shipment_header_id
                     AND rsl.shipment_line_id = rcv.shipment_line_id
                     AND rcv.transaction_type = 'RECEIVE'
                     AND rsl.item_id = msi.inventory_item_id
                     AND msi.organization_id = 7
                     AND rsl.po_header_id = poh.po_header_id
                     AND rcta.purchase_order = poh.segment1
                     AND rcta.CUSTOMER_TRX_ID = TO_CHAR (pn_cust_trx_id)
            GROUP BY rcv.transaction_date, poh.segment1, msi.segment1,
                     rsh.packing_slip;

        CURSOR C4 (pn_Cust_Trx_ID IN VARCHAR2, pv_Style IN VARCHAR2)
        IS
              SELECT poh.segment1 po_num, rcv.transaction_date po_receipt_date, rsh.packing_slip AS factory_invoice,
                     SUM (rsl.quantity_received) rcvd_qty
                FROM apps.rcv_shipment_lines rsl, apps.rcv_shipment_headers rsh, apps.rcv_transactions rcv,
                     apps.mtl_system_items_b msi, apps.po_headers_all poh, apps.ra_customer_trx_all rcta
               WHERE     rsh.shipment_header_id = rsl.shipment_header_id
                     AND rsl.shipment_line_id = rcv.shipment_line_id
                     AND rcv.transaction_type = 'RECEIVE'
                     AND rsl.item_id = msi.inventory_item_id
                     AND msi.organization_id = 7
                     AND rsl.po_header_id = poh.po_header_id
                     AND rcta.purchase_order = poh.segment1
                     AND rcta.CUSTOMER_TRX_ID = TO_CHAR (pn_cust_trx_id)
                     AND msi.segment1 = pv_style
            GROUP BY rcv.transaction_date, poh.segment1, msi.segment1,
                     rsh.packing_slip;

        CURSOR c5 (pn_cust_trx_id   IN VARCHAR2,
                   pv_style         IN VARCHAR2,
                   PO_RCV_DATE         VARCHAR2)
        IS
            SELECT COUNT (DISTINCT rsh.packing_slip) style_cnt
              FROM apps.rcv_shipment_lines rsl, apps.rcv_shipment_headers rsh, apps.rcv_transactions rcv,
                   apps.mtl_system_items_b msi, apps.po_headers_all poh, apps.ra_customer_trx_all rcta
             WHERE     rsh.shipment_header_id = rsl.shipment_header_id
                   AND rsl.shipment_line_id = rcv.shipment_line_id
                   AND rcv.transaction_type = 'RECEIVE'
                   AND rsl.item_id = msi.inventory_item_id
                   AND msi.organization_id = 7
                   AND rsl.po_header_id = poh.po_header_id
                   AND rcta.purchase_order = poh.segment1
                   AND rcta.CUSTOMER_TRX_ID = TO_CHAR (pn_cust_trx_id)
                   AND msi.segment1 = pv_style                     --'1003321'
                   AND TRUNC (rcv.transaction_date) =
                       TRUNC (TO_DATE (PO_RCV_DATE, 'DD-MON-YY'));
    BEGIN
        BEGIN
            SELECT pha.segment1
              INTO l_po_num
              FROM apps.ra_customer_trx_all rcta, apps.po_headers_all pha
             WHERE     1 = 1
                   AND pha.segment1 = rcta.purchase_order
                   AND RCTA.ORG_ID = PHA.ORG_ID
                   AND rcta.customer_trx_id = TO_CHAR (p_cust_trx_id);
        EXCEPTION
            WHEN OTHERS
            THEN
                apps.fnd_file.put_line (apps.fnd_file.LOG,
                                        'In THE QUERY' || L_PO_NUM);
        END;



        IF l_po_num IS NULL
        THEN
            IF p_style IS NULL
            THEN
                retval   := NULL;

                FOR i IN c1 (TO_CHAR (p_Cust_Trx_ID))
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

                FOR j IN c2 (TO_CHAR (p_Cust_Trx_ID), p_Style)
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

                FOR l IN c3 (TO_CHAR (p_Cust_Trx_ID))
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

                FOR n IN c4 (TO_CHAR (p_Cust_Trx_ID), p_Style)
                LOOP
                    -- apps.fnd_file.put_line(apps.fnd_file.log,'DATE:   '||n.po_receipt_date);
                    FOR q
                        IN c5 (TO_CHAR (p_Cust_Trx_ID),
                               p_Style,
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
                || p_Cust_Trx_ID);
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'In When others exception of Get Factory Invoice then p_Style  :'
                || p_Style);
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'In When others exception of Get Factory Invoice then '
                || SQLCODE
                || SQLERRM);
            RETURN NULL;
    END GET_FACTORY_INVOICE;
END XXDOOE_GEN_PKG;
/


--
-- XXDOOE_GEN_PKG  (Synonym) 
--
CREATE OR REPLACE SYNONYM XXDO.XXDOOE_GEN_PKG FOR APPS.XXDOOE_GEN_PKG
/


GRANT EXECUTE ON APPS.XXDOOE_GEN_PKG TO XXDO
/
