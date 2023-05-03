--
-- XXDOAR_MULBR_CRLINE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:15 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.xxdoar_mulbr_crline_pkg
AS
    --------------------------------------------------------------------------------
    -- Created By              : Vijaya Reddy ( Suneara Technologies )
    -- Creation Date           : 25-MAY-2011
    -- File Name               : Executable : XXDOAR015 ,  XXDOAR016 and XXDOAR017
    -- Work Order Num          : Multi Brand Credit line Process
    --                                        Incident INC0089941
    -- Description             :
    -- Latest Version          : 1.0
    --
    -- Revision History:
    -- =============================================================================
    -- Date               Version#    Name                      Remarks
    -- =============================================================================
    -- 25-MAY-2011        1.0         Vijaya Reddy             Initial development.
    --                                Venkatesh R
    -- 26-NOV-2014        1.1        BT Technology Team       The Brand is taken from customer account Attribute instead from
    --                                                          the Order header Attribute5 and Transaction Attribute5 in the
    -- 08-DEC-2014        1.2        BT Technology Team         According to the functional Document added additional functionality in procedure get_overdue_brand
    -------------------------------------------------------------------------------
    PROCEDURE get_brand_exposure (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, pn_org_id NUMBER
                                  , pn_cust_id NUMBER)
    AS
        ln_count1              NUMBER;
        ln_count2              NUMBER;
        ln_count3              NUMBER;
        lv_error_message       VARCHAR2 (32000);
        ln_cnum                VARCHAR2 (30);
        lv_brand               VARCHAR2 (30);
        ln_cust_crlimit        NUMBER;
        ln_avlcr               NUMBER;
        ln_relflag             VARCHAR2 (5);
        ln_header_id           NUMBER;
        ln_hold_source_id      NUMBER;
        ln_hold_id             NUMBER;
        lv_return_status       VARCHAR2 (30);
        lv_msg_data            VARCHAR2 (4000);
        ln_msg_count           NUMBER;
        ln_order_tbl           apps.oe_holds_pvt.order_tbl_type;
        ln_exists              NUMBER;
        p_errbuf               VARCHAR2 (200);
        p_retcode              VARCHAR2 (50);

        ----------------------
        -- CURSOR DECLARATIONS
        ----------------------
        ----------------------------------------------------------------------------------
        -- CURSOR TO RETRIEVE CUSTOMER INFORMATION WHOSE CREDIT LIMIT <=100k
        ----------------------------------------------------------------------------------
        CURSOR c_cust_crlt_cur (cp_cust_id IN NUMBER)
        IS
              SELECT cust_acct.account_number AS customer_number, SUBSTRB (party.party_name, 1, 50) AS customer_name, hcpa.overall_credit_limit AS credit_limit
                FROM apps.hz_customer_profiles hcp, apps.hz_cust_profile_classes hcpc, apps.hz_parties party,
                     apps.hz_cust_accounts cust_acct, apps.hz_cust_profile_amts hcpa
               WHERE     hcp.status = 'A'
                     AND hcpc.status = 'A'
                     AND cust_acct.status = 'A'
                     AND hcp.profile_class_id = hcpc.profile_class_id
                     AND hcpa.cust_account_profile_id =
                         hcp.cust_account_profile_id
                     AND cust_acct.party_id = party.party_id
                     AND cust_acct.cust_account_id = hcp.cust_account_id
                     AND hcpc.NAME NOT IN
                             ('Employee', 'House', 'Promo Accounts')
                     AND hcp.site_use_id IS NULL
                     AND hcpa.overall_credit_limit <=
                         (SELECT meaning
                            FROM apps.fnd_lookup_values_vl
                           WHERE     lookup_type = 'XXDOAR_BRAND_CL'
                                 AND lookup_code = 'BRANDCL'
                                 AND enabled_flag = 'Y')
                     AND hcpa.currency_code NOT IN
                             (SELECT meaning
                                FROM apps.fnd_lookup_values_vl
                               WHERE     lookup_type = 'XXDOAR_BRAND_CL'
                                     AND lookup_code = 'BRANDCUR'
                                     AND enabled_flag = 'Y')
                     AND cust_acct.cust_account_id =
                         NVL (cp_cust_id, cust_acct.cust_account_id)
            ORDER BY SUBSTRB (party.party_name, 1, 50);

        -------------------------------------------------------------------------------------------
        ----------------------------------------------------------------------------------------------------------
        -- CURSOR TO RETRIEVE CUSTOMER WISE BRAND WISE SUM OF TOTAL OPEN SALES ORDERS WHICH ARE NOT ON HOLD
        --        + NET AR OPEN BALANCE AMOUNT WHICH ARE INVOICED
        ----------------------------------------------------------------------------------------------------------
        CURSOR c_cbr_snothold_narinv_cur (cp_org_id    IN NUMBER,
                                          cp_cust_id   IN NUMBER)
        IS
              SELECT customer_number, customer_name, brand,
                     SUM (open_release_order) open_release_order, org_id
                FROM (  SELECT cust_acct.account_number AS customer_number, SUBSTRB (party.party_name, 1, 50) AS customer_name, --ooha.attribute5 AS brand,                          --Commented by BT Technology Team on 26-NOV-2014 (version 1.1)
                                                                                                                                cust_acct.attribute1 AS brand, -- Added by BT Technology Team on 26-NOV-2014   (version 1.1)
                               /* NVL (SUM (oola.ordered_quantity * oola.unit_selling_price),
                                     0
                                    ) AS open_release_order,*/
                               NVL (SUM ((oola.ordered_quantity - NVL (oola.shipped_quantity, NVL (oola.fulfilled_quantity, 0))) * NVL (oola.unit_selling_price, 0)), 0) AS open_release_order, ooha.org_id AS org_id
                          FROM apps.oe_order_headers_all ooha, apps.oe_order_lines_all oola, apps.hz_parties party,
                               apps.hz_cust_accounts cust_acct
                         WHERE     oola.header_id = ooha.header_id
                               AND cust_acct.party_id = party.party_id
                               AND cust_acct.cust_account_id =
                                   ooha.sold_to_org_id
                               AND cust_acct.status = 'A'
                               AND oola.open_flag = 'Y'
                               AND ooha.open_flag = 'Y'
                               AND oola.booked_flag = 'Y'
                               AND oola.line_category_code <> 'RETURN'
                               AND NOT EXISTS
                                       (SELECT 1
                                          FROM apps.ra_customer_trx_lines_all rct
                                         WHERE rct.sales_order =
                                               TO_CHAR (ooha.order_number))
                               AND NOT EXISTS
                                       (SELECT 1
                                          FROM apps.ra_interface_lines_all ril
                                         WHERE ril.sales_order =
                                               TO_CHAR (ooha.order_number))
                               /*   AND NOT EXISTS (SELECT 1
                                                    FROM apps.oe_order_holds_all oohd
                                                   WHERE oohd.header_id = ooha.header_id
                                                   AND   oohd.released_flag = 'N')*/
                               AND NOT EXISTS
                                       (SELECT 1
                                          FROM apps.oe_order_holds_all oohold, apps.oe_hold_sources_all ohs, apps.oe_hold_definitions ohd
                                         WHERE     oohold.header_id =
                                                   oola.header_id
                                               AND NVL (oohold.line_id,
                                                        oola.line_id) =
                                                   oola.line_id
                                               AND oola.org_id = ooha.org_id
                                               AND oohold.hold_source_id =
                                                   ohs.hold_source_id
                                               AND ohs.hold_id = ohd.hold_id
                                               AND oohold.released_flag = 'N'
                                               AND ohd.type_code = 'CREDIT')
                               AND oola.flow_status_code IN
                                       ('PO_CREATED', 'BOOKED', 'AWAITING_SHIPPING',
                                        'AWAITING_RECEIPT', 'INVOICED', 'SUPPLY_ELIGIBLE',
                                        'PO_REQ_CREATED', 'PO_OPEN')
                               --AND oola.flow_status_code NOT IN ('CANCELLED', 'CLOSED')
                               AND ooha.flow_status_code NOT IN
                                       ('CANCELLED', 'CLOSED')
                               AND ooha.org_id = NVL (cp_org_id, ooha.org_id)
                               AND (ooha.request_date BETWEEN SYSDATE AND (SYSDATE + 45) OR (ooha.request_date < SYSDATE))
                               AND cust_acct.cust_account_id =
                                   NVL (cp_cust_id, cust_acct.cust_account_id)
                      GROUP BY cust_acct.account_number, SUBSTRB (party.party_name, 1, 50), --ooha.attribute5 ,                          --Commented by BT Technology Team on 26-NOV-2014 (version 1.1)
                                                                                            cust_acct.attribute1, -- Added by BT Technology Team on 26-NOV-2014 (version 1.1)
                               ooha.org_id
                      UNION ALL
                        SELECT cust_acct.account_number AS customer_number, SUBSTRB (party.party_name, 1, 50) AS customer_name, --   rcta.attribute5 AS brand,                           -- Commented by BT Technology Team on 26-NOV-2014 (version 1.1)
                                                                                                                                cust_acct.attribute1 AS brand, -- Added by BT Technology Team on 26-NOV-2014 (version 1.1)
                               SUM (arps.amount_due_remaining) open_release_order, arps.org_id AS org_id
                          FROM apps.hz_parties party, apps.hz_cust_accounts cust_acct, apps.ar_payment_schedules_all arps,
                               apps.ra_customer_trx_all rcta, apps.hr_all_organization_units hou
                         WHERE     cust_acct.status = 'A'
                               AND cust_acct.party_id = party.party_id
                               AND cust_acct.cust_account_id = arps.customer_id
                               AND arps.customer_trx_id = rcta.customer_trx_id
                               AND arps.org_id = hou.organization_id
                               AND arps.status = 'OP'
                               -- AND arps.class <> 'PMT'
                               AND arps.org_id = NVL (cp_org_id, arps.org_id)
                               AND cust_acct.cust_account_id =
                                   NVL (cp_cust_id, cust_acct.cust_account_id)
                      GROUP BY cust_acct.account_number, --  rcta.attribute5,                            -- Commented by BT Technology Team on 6-NOV-2014 (version 1.1)
                                                         cust_acct.attribute1, -- Added by BT Technology Team on 26-NOV-2014 (version 1.1)
                                                                               SUBSTRB (party.party_name, 1, 50),
                               arps.org_id) abc
            GROUP BY customer_number, customer_name, brand,
                     org_id;

        ------------------------------------------------------------------------
        -- CURSOR TO RETRIEVE CUSTOMER WISE BRAND WISE INDIVIDUAL
        --     OPEN SALES ORDERS WHICH ARE ON HOLD.
        ------------------------------------------------------------------------
        CURSOR c_cbr_shold_cur (cp_org_id IN NUMBER, cp_cust_id IN NUMBER)
        IS
              SELECT cust_acct.account_number AS customer_number, SUBSTRB (party.party_name, 1, 50) AS customer_name, --ooha.attribute5 AS brand,                        --Commented by BT Technology Team on 26-NOV-2014 (version 1.1)
                                                                                                                      cust_acct.attribute1 AS brand, -- Added by BT Technology Team on 26-NOV-2014 (version 1.1)
                     ooha.order_number AS salesorder, /* NVL (SUM (oola.ordered_quantity * oola.unit_selling_price),
                                                            0
                                                           ) AS Sales_order_value,*/
                                                      NVL (SUM ((oola.ordered_quantity - NVL (oola.shipped_quantity, NVL (oola.fulfilled_quantity, 0))) * NVL (oola.unit_selling_price, 0)), 0) AS sales_order_value, ooha.org_id AS org_id
                FROM apps.oe_order_headers_all ooha, apps.oe_order_lines_all oola, apps.hz_parties party,
                     apps.hz_cust_accounts cust_acct
               --,   apps.hz_cust_accounts hca
               WHERE     oola.header_id = ooha.header_id
                     AND cust_acct.party_id = party.party_id
                     AND cust_acct.cust_account_id = ooha.sold_to_org_id
                     AND cust_acct.status = 'A'
                     AND oola.open_flag = 'Y'
                     AND ooha.open_flag = 'Y'
                     AND oola.booked_flag = 'Y'
                     AND oola.line_category_code <> 'RETURN'
                     AND NOT EXISTS
                             (SELECT 1
                                FROM apps.ra_customer_trx_lines_all rct
                               WHERE rct.sales_order =
                                     TO_CHAR (ooha.order_number))
                     AND NOT EXISTS
                             (SELECT 1
                                FROM apps.ra_interface_lines_all ril
                               WHERE ril.sales_order =
                                     TO_CHAR (ooha.order_number))
                     /* AND EXISTS (SELECT 1
                                        FROM apps.oe_order_holds_all oohd
                                       WHERE oohd.header_id = ooha.header_id
                                       AND  oohd.released_flag = 'N')*/
                     AND EXISTS
                             (SELECT 1
                                FROM apps.oe_order_holds_all oohold, apps.oe_hold_sources_all ohs, apps.oe_hold_definitions ohd
                               WHERE     oohold.header_id = oola.header_id
                                     AND NVL (oohold.line_id, oola.line_id) =
                                         oola.line_id
                                     AND oola.org_id = ooha.org_id
                                     AND oohold.hold_source_id =
                                         ohs.hold_source_id
                                     AND ohs.hold_id = ohd.hold_id
                                     AND oohold.released_flag = 'N'
                                     AND ohd.type_code = 'CREDIT')
                     AND NOT EXISTS
                             (SELECT 1
                                FROM apps.oe_order_holds_all oohold, apps.oe_hold_sources_all ohs, apps.oe_hold_definitions ohd
                               WHERE     oohold.header_id = oola.header_id
                                     AND NVL (oohold.line_id, oola.line_id) =
                                         oola.line_id
                                     AND oola.org_id = ooha.org_id
                                     AND oohold.hold_source_id =
                                         ohs.hold_source_id
                                     AND ohs.hold_id = ohd.hold_id
                                     AND oohold.released_flag = 'Y'
                                     AND ohd.type_code = 'CREDIT')
                     --AND oola.flow_status_code NOT IN ('CANCELLED', 'CLOSED')
                     AND oola.flow_status_code IN ('PO_CREATED', 'BOOKED', 'AWAITING_SHIPPING',
                                                   'AWAITING_RECEIPT', 'INVOICED', 'SUPPLY_ELIGIBLE',
                                                   'PO_REQ_CREATED', 'PO_OPEN')
                     AND ooha.flow_status_code NOT IN ('CANCELLED', 'CLOSED')
                     AND ooha.org_id = NVL (cp_org_id, ooha.org_id)
                     AND cust_acct.cust_account_id =
                         NVL (cp_cust_id, cust_acct.cust_account_id)
            GROUP BY cust_acct.account_number, SUBSTRB (party.party_name, 1, 50), --ooha.attribute5,     -- Commented by BT Technology Team on 26-NOV-2014 (version 1.1)
                                                                                  cust_acct.attribute1, -- added by BT Technologynology Team on 26-NOV-2014 (version 1.1)
                     ooha.order_number, ooha.org_id
            ORDER BY SUBSTRB (party.party_name, 1, 50);

        --------------------------------------------------------------------------------
        -- CURSOR TO RETRIEVE  TEMP TABLE DATA: AVAILABLE CREDIT LIMIT FOR EACH BRAND.
        --AVAILABLE CREDIT LIMIT = CREDIT_LMIT - OPEN _RELEASE_ORDER_AMT
        --------------------------------------------------------------------------------
        CURSOR c_avl_crlimit_temp_cur (cp_org_id IN NUMBER)
        IS
              SELECT a.customer_number, b.brand, a.credit_limit credit_limit,
                     b.open_rel_order_amt, b.org_id, a.credit_limit - b.open_rel_order_amt available_cr_limit
                FROM xxdo.xxdoar_brndexp_cust_temp a, xxdo.xxdoar_brndexp_snh_nar_temp b
               WHERE     a.customer_number = b.customer_number
                     AND b.org_id = NVL (cp_org_id, b.org_id)
            ORDER BY a.customer_number, b.brand;

        --------------------------------------------------------------------------------
        -- CURSOR TO RETRIEVE TEMP TABLE DATA: CUSTOMER WISE BRAND WISE INDIVIDUAL
        --                 OPEN SALES ORDERS WHICH ARE ON HOLD
        --------------------------------------------------------------------------------
        CURSOR c_salsord_hold_temp_cur (cp_cust_num IN VARCHAR2, cp_brand IN VARCHAR2, cp_org_id IN NUMBER)
        IS
              SELECT c.customer_number, c.customer_name, c.brand,
                     c.sales_order_num, c.sales_order_value, c.org_id
                FROM xxdo.xxdoar_brndexp_shold_temp c
               WHERE     c.customer_number = cp_cust_num
                     AND c.brand = cp_brand
                     AND c.org_id = cp_org_id
            ORDER BY sales_order_value;

        --------------------------------------------------------------------------------
        -- CURSOR TO RETRIEVE HOLD_ID for a SALES ORDER
        --------------------------------------------------------------------------------
        CURSOR c_salsord_hold_api_cur (cp_sales_ordnum IN NUMBER)
        IS
            SELECT /*+ index(hld OE_ORDER_HOLDS_ALL_N1) index(hsrc OE_HOLD_SOURCES_U1)*/
                   hdr.header_id, hsrc.hold_source_id, hsrc.hold_id
              FROM apps.oe_order_headers_all hdr, apps.oe_order_holds_all hld, apps.oe_hold_sources_all hsrc,
                   apps.oe_hold_definitions hdef
             WHERE     hdr.header_id = hld.header_id
                   AND hld.hold_source_id = hsrc.hold_source_id
                   AND hsrc.hold_id = hdef.hold_id
                   AND hsrc.hold_id NOT IN
                           (SELECT hold_id
                              FROM apps.oe_hold_definitions
                             WHERE NAME IN
                                       ('Overdue for Brand - Hold Applied', 'Overdue Check Aggregate - Hold Applied', 'Deckers Custom Collection - Hold Applied'))
                   AND hdr.order_number = cp_sales_ordnum;

        ---------------------------------------------------------------------------------
        -- TYPE DECLARATIONS TO STORE THE FETCHED BRAND EXPOSURE RECORDS
        ---------------------------------------------------------------------------------
        TYPE cust_crlt_tabtype IS TABLE OF c_cust_crlt_cur%ROWTYPE
            INDEX BY PLS_INTEGER;

        cust_crlt_tbl          cust_crlt_tabtype;

        TYPE cbr_snothold_nar_tabtype
            IS TABLE OF c_cbr_snothold_narinv_cur%ROWTYPE
            INDEX BY PLS_INTEGER;

        cbr_snothold_nar_tbl   cbr_snothold_nar_tabtype;

        TYPE cbr_shold_tabtype IS TABLE OF c_cbr_shold_cur%ROWTYPE
            INDEX BY PLS_INTEGER;

        cbr_shold_tbl          cbr_shold_tabtype;
    BEGIN
        -------------------------------------
        -- To delete data from Custom Table
        -------------------------------------
        BEGIN
            DELETE FROM xxdo.xxdoar_brndexp_cust_temp;


            DELETE FROM xxdo.xxdoar_brndexp_snh_nar_temp;


            DELETE FROM xxdo.xxdoar_brndexp_shold_temp;


            COMMIT;
        END;

        -----------------------------------------------------
        -- Check whether the custom table is empty
        -----------------------------------------------------
        SELECT COUNT (1) INTO ln_count1 FROM xxdo.xxdoar_brndexp_cust_temp;

        IF ln_count1 = 0
        THEN
            -----------------------------------------------------------------
            -- RETRIEVE ALL CUSTOMER INFORMATION WHOSE CREDIT LIMIT <=100K
            -----------------------------------------------------------------
            gv_error_position   :=
                'BRAND EXPOSURE - Retrieve Cursor1 c_cust_crlt_cur Based on Input Parameter';

            OPEN c_cust_crlt_cur (cp_cust_id => pn_cust_id);

            LOOP
                FETCH c_cust_crlt_cur
                    BULK COLLECT INTO cust_crlt_tbl
                    LIMIT 1000;

                IF cust_crlt_tbl.COUNT > 0
                THEN
                    FOR x_cust_crlt IN cust_crlt_tbl.FIRST ..
                                       cust_crlt_tbl.LAST
                    LOOP
                        get_bexp_cust_crlmt (
                            pv_customer_number   =>
                                cust_crlt_tbl (x_cust_crlt).customer_number,
                            pv_customer_name   =>
                                cust_crlt_tbl (x_cust_crlt).customer_name,
                            pn_credit_limit   =>
                                cust_crlt_tbl (x_cust_crlt).credit_limit);
                        COMMIT;
                    END LOOP;                                   --Bulk Collect
                END IF;

                EXIT WHEN c_cust_crlt_cur%NOTFOUND;
            END LOOP;                                        --c_cust_crlt_cur

            CLOSE c_cust_crlt_cur;
        END IF;

        -----------------------------------------------------
        -- Check whether the custom table is empty
        -----------------------------------------------------
        SELECT COUNT (1) INTO ln_count2 FROM xxdo.xxdoar_brndexp_snh_nar_temp;

        IF ln_count2 = 0
        THEN
            -----------------------------------------------------------------------------------------------------
            -- RETRIEVE ALL CUSTOMER WISE BRAND WISE SUM OF TOTAL OPEN SALES ORDERS WHICH ARE NOT ON HOLD
            -----------------------------------------------------------------------------------------------------
            gv_error_position   :=
                'BRAND EXPOSURE - Retrieve Cursor2 c_cbr_snothold_narinv_cur Based on Input Parameter';

            OPEN c_cbr_snothold_narinv_cur (cp_org_id    => pn_org_id,
                                            cp_cust_id   => pn_cust_id);

            LOOP
                FETCH c_cbr_snothold_narinv_cur
                    BULK COLLECT INTO cbr_snothold_nar_tbl
                    LIMIT 1000;

                IF cbr_snothold_nar_tbl.COUNT > 0
                THEN
                    FOR x_cbr_snothold_nar IN cbr_snothold_nar_tbl.FIRST ..
                                              cbr_snothold_nar_tbl.LAST
                    LOOP
                        get_bexp_openrel_ordamt (
                            pv_customer_number   =>
                                cbr_snothold_nar_tbl (x_cbr_snothold_nar).customer_number,
                            pv_customer_name   =>
                                cbr_snothold_nar_tbl (x_cbr_snothold_nar).customer_name,
                            pv_brand   =>
                                cbr_snothold_nar_tbl (x_cbr_snothold_nar).brand,
                            pn_open_rel_order_amt   =>
                                cbr_snothold_nar_tbl (x_cbr_snothold_nar).open_release_order,
                            pn_org_id   =>
                                cbr_snothold_nar_tbl (x_cbr_snothold_nar).org_id);
                        COMMIT;
                    END LOOP;                                   --Bulk Collect
                END IF;

                EXIT WHEN c_cbr_snothold_narinv_cur%NOTFOUND;
            END LOOP;                              --c_cbr_snothold_narinv_cur

            CLOSE c_cbr_snothold_narinv_cur;
        END IF;

        -----------------------------------------------------
        -- Check whether the custom table is empty
        -----------------------------------------------------
        SELECT COUNT (1) INTO ln_count3 FROM xxdo.xxdoar_brndexp_shold_temp;


        IF ln_count3 = 0
        THEN
            ---------------------------------------------------------------------------------------
            -- RETRIEVE CUSTOMER WISE BRAND WISE INDIVIDUAL OPEN SALES ORDERS WHICH ARE ON HOLD
            ----------------------------------------------------------------------------------------
            gv_error_position   :=
                'BRAND EXPOSURE - Retrieve Cursor4 c_cbr_shold_cur Based on Input Parameter';

            OPEN c_cbr_shold_cur (cp_org_id    => pn_org_id,
                                  cp_cust_id   => pn_cust_id);

            LOOP
                FETCH c_cbr_shold_cur
                    BULK COLLECT INTO cbr_shold_tbl
                    LIMIT 1000;

                IF cbr_shold_tbl.COUNT > 0
                THEN
                    FOR x_cbr_shold IN cbr_shold_tbl.FIRST ..
                                       cbr_shold_tbl.LAST
                    LOOP
                        get_bexp_salord_hold (
                            pv_customer_number   =>
                                cbr_shold_tbl (x_cbr_shold).customer_number,
                            pv_customer_name   =>
                                cbr_shold_tbl (x_cbr_shold).customer_name,
                            pv_brand    => cbr_shold_tbl (x_cbr_shold).brand,
                            pn_sales_order_num   =>
                                cbr_shold_tbl (x_cbr_shold).salesorder,
                            pn_sales_order_value   =>
                                cbr_shold_tbl (x_cbr_shold).sales_order_value,
                            pn_org_id   => cbr_shold_tbl (x_cbr_shold).org_id);
                        COMMIT;
                    END LOOP;                                   --Bulk Collect
                END IF;

                EXIT WHEN c_cbr_shold_cur%NOTFOUND;
            END LOOP;                                        --c_cbr_shold_cur

            CLOSE c_cbr_shold_cur;
        END IF;

        apps.fnd_file.put_line (
            apps.fnd_file.output,
            '                                             DECKERS Outdoor Corporation                                         ');
        apps.fnd_file.put_line (
            apps.fnd_file.output,
            '                                            ******************************                                      ');
        apps.fnd_file.put_line (
            apps.fnd_file.output,
            '                                                                                                                  ');
        apps.fnd_file.put_line (
            apps.fnd_file.output,
            '                                   Multi Brand Credit line Process for Brand Exposure    ');
        apps.fnd_file.put_line (
            apps.fnd_file.output,
            '                                  ****************************************************  ');
        apps.fnd_file.put_line (
            apps.fnd_file.output,
            '                                                        ');
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD ('Customer Number', 17, ' ')
            || RPAD ('Customer Name', 30, ' ')
            || RPAD ('Customer Cr Limit', 20, ' ')
            || RPAD ('Brand', 20, ' ')
            || RPAD ('Available Cr Limit', 20, ' ')
            || RPAD ('Sales Order Num', 20, ' ')
            || RPAD ('Sales Order Amount', 20, ' ')
            || RPAD ('Released Flag', 20, ' '));
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD ('***************', 17, ' ')
            || RPAD ('*************', 30, ' ')
            || RPAD ('*****************', 20, ' ')
            || RPAD ('*****', 20, ' ')
            || RPAD ('******************', 20, ' ')
            || RPAD ('******************', 20, ' ')
            || RPAD ('*************', 20, ' ')
            || RPAD ('*************', 20, ' '));

        FOR avl_crdl IN c_avl_crlimit_temp_cur (cp_org_id => pn_org_id)
        LOOP
            ln_cust_crlimit   := avl_crdl.credit_limit;
            ln_avlcr          := avl_crdl.available_cr_limit;

            BEGIN
                SELECT DISTINCT 1
                  INTO ln_exists
                  FROM xxdo.xxdoar_brndexp_shold_temp
                 WHERE     customer_number = avl_crdl.customer_number
                       AND brand = avl_crdl.brand
                       AND org_id = avl_crdl.org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_errbuf    := SQLCODE || SQLERRM;
                    p_retcode   := -5;
                    apps.fnd_file.put_line (apps.fnd_file.LOG,
                                            'Program Terminated Abruptly');
                    apps.fnd_file.put_line (apps.fnd_file.LOG,
                                            'All Data is Not Processed');
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'Error while checking data exists in XXDOAR_BRNDEXP_SHOLD_TEMP '
                        || p_errbuf);
                    --ln_exists := NULL;
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'No Sales Orders for Customer:  '
                        || avl_crdl.customer_number
                        || ' and Brand:  '
                        || avl_crdl.brand);
            END;

            IF ln_exists != 1
            THEN
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                       'No Sales Orders for Customer:  '
                    || avl_crdl.customer_number
                    || ' and Brand:  '
                    || avl_crdl.brand);
            END IF;

            FOR salord_hold
                IN c_salsord_hold_temp_cur (avl_crdl.customer_number,
                                            avl_crdl.brand,
                                            avl_crdl.org_id)
            LOOP
                ln_relflag   := NULL;

                IF ln_avlcr > 0
                THEN
                    IF salord_hold.sales_order_value <= ln_avlcr
                    THEN
                        ln_relflag   := 'Y';
                        apps.fnd_global.apps_initialize (
                            apps.fnd_global.user_id,
                            apps.fnd_global.resp_id,
                            apps.fnd_global.resp_appl_id);
                        --apps.mo_global.init ('AR');                         -- Commented by BT Technology Team on 26-DEC-2014 (version 1.1)
                        apps.mo_global.set_policy_context ('S', pn_org_id); --  Added by BT Technology Team on 26-DEC-2014 (version 1.1)

                        FOR salsord_hold_api
                            IN c_salsord_hold_api_cur (
                                   salord_hold.sales_order_num)
                        LOOP
                            ln_order_tbl (1).header_id   :=
                                salsord_hold_api.header_id;
                            lv_return_status   := NULL;
                            lv_msg_data        := NULL;
                            ln_msg_count       := NULL;
                            apps.oe_holds_pub.release_holds (
                                p_api_version       => 1.0,
                                p_order_tbl         => ln_order_tbl,
                                p_hold_id           => salsord_hold_api.hold_id,
                                --ln_hold_id,
                                p_release_reason_code   =>
                                    'BRAND_EXP_REL_HOLD',
                                p_release_comment   =>
                                    'BRAND EXPOSURE RELEASE HOLD',
                                x_return_status     => lv_return_status,
                                x_msg_count         => ln_msg_count,
                                x_msg_data          => lv_msg_data);

                            IF lv_return_status =
                               apps.fnd_api.g_ret_sts_success
                            THEN
                                apps.fnd_file.put_line (
                                    apps.fnd_file.LOG,
                                       'Hold released for Sales Order Num: '
                                    || salord_hold.sales_order_num);
                                COMMIT;
                            ELSIF lv_return_status IS NULL
                            THEN
                                apps.fnd_file.put_line (apps.fnd_file.LOG,
                                                        'Status is null');
                            ELSE
                                apps.fnd_file.put_line (
                                    apps.fnd_file.LOG,
                                    'Failed: ' || lv_msg_data);
                            END IF;
                        END LOOP;

                        IF lv_return_status = apps.fnd_api.g_ret_sts_success
                        THEN --  Added by BT Technology Team on 26-DEC-2014 (version 1.1)
                            apps.fnd_file.put_line (
                                apps.fnd_file.output,
                                '                                                                                                                                                                                                                                                                                 ');
                            apps.fnd_file.put_line (
                                apps.fnd_file.output,
                                   RPAD (salord_hold.customer_number,
                                         17,
                                         ' ')
                                || RPAD (salord_hold.customer_name, 30, ' ')
                                || RPAD (
                                       TO_CHAR (ln_cust_crlimit, '999999.99'),
                                       20,
                                       ' ')
                                || RPAD (salord_hold.brand, 20, ' ')
                                || RPAD (TO_CHAR (ln_avlcr, '999999.99'),
                                         20,
                                         ' ')
                                || RPAD (salord_hold.sales_order_num,
                                         20,
                                         ' ')
                                || RPAD (
                                       TO_CHAR (
                                           salord_hold.sales_order_value,
                                           '999999.99'),
                                       20,
                                       ' ')
                                || RPAD (ln_relflag, 20, ' '));
                        END IF; --  Added by BT Technology Team on 26-DEC-2014 (version 1.1)
                    ELSE
                        ln_relflag   := 'N';
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                               'Customer '
                            || salord_hold.customer_number
                            || ' has Exceeded the Brand Credit Limit');
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                               RPAD ('Customer Number', 17, ' ')
                            || RPAD ('Customer Name', 30, ' ')
                            || RPAD ('Customer Cr Limit', 20, ' ')
                            || RPAD ('Brand', 20, ' ')
                            || RPAD ('Available Cr Limit', 20, ' ')
                            || RPAD ('Sales Order Num', 20, ' ')
                            || RPAD ('Sales Order Amount', 20, ' ')
                            || RPAD ('Released Flag', 20, ' '));
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            '                                                                                                                                                                                                                                                                                    ');
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                               RPAD (salord_hold.customer_number, 17, ' ')
                            || RPAD (salord_hold.customer_name, 30, ' ')
                            || RPAD (TO_CHAR (ln_cust_crlimit, '999999.99'),
                                     20,
                                     ' ')
                            || RPAD (salord_hold.brand, 20, ' ')
                            || RPAD (TO_CHAR (ln_avlcr, '999999.99'),
                                     20,
                                     ' ')
                            || RPAD (salord_hold.sales_order_num, 20, ' ')
                            || RPAD (
                                   TO_CHAR (salord_hold.sales_order_value,
                                            '999999.99'),
                                   20,
                                   ' ')
                            || RPAD (ln_relflag, 20, ' '));
                        ln_avlcr     :=
                            ln_avlcr - salord_hold.sales_order_value;
                    END IF;
                ELSE
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'Customer '
                        || salord_hold.customer_number
                        || ' has Exceeded the Brand Credit Limit');
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           RPAD ('Customer Number', 17, ' ')
                        || RPAD ('Customer Name', 30, ' ')
                        || RPAD ('Customer Cr Limit', 20, ' ')
                        || RPAD ('Brand', 20, ' ')
                        || RPAD ('Available Cr Limit', 20, ' ')
                        || RPAD ('Sales Order Num', 20, ' ')
                        || RPAD ('Sales Order Amount', 20, ' ')
                        || RPAD ('Released Flag', 20, ' '));
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                        '                                                                                                                                                                                                                                                                                    ');
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           RPAD (salord_hold.customer_number, 17, ' ')
                        || RPAD (salord_hold.customer_name, 30, ' ')
                        || RPAD (TO_CHAR (ln_cust_crlimit, '999999.99'),
                                 20,
                                 ' ')
                        || RPAD (salord_hold.brand, 20, ' ')
                        || RPAD (TO_CHAR (ln_avlcr, '999999.99'), 20, ' ')
                        || RPAD (salord_hold.sales_order_num, 20, ' ')
                        || RPAD (
                               TO_CHAR (salord_hold.sales_order_value,
                                        '999999.99'),
                               20,
                               ' ')
                        || RPAD (ln_relflag, 20, ' '));
                END IF;
            END LOOP;

            ln_avlcr          := 0;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_error_message   := SQLERRM;
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'Following Error Occured At ' || gv_error_position);
            raise_application_error (-20501, lv_error_message);
            RAISE;
    END get_brand_exposure;

    PROCEDURE get_bexp_cust_crlmt (pv_customer_number VARCHAR2, pv_customer_name VARCHAR2, pn_credit_limit NUMBER)
    IS
    --------------------------------------------------------------------------------
    -- Created By              : Vijaya Reddy
    -- Creation Date           : 25-MAY-2011
    -- Description             : To insert Customer Information whose credit limit <=100k
    --
    -- Input Parameters description:
    -- PV_CUSTOMER_NUMBER       : Customer Number
    -- PV_CUSTOMER_NAME         : Customer Name
    -- PN_CREDIT_LIMIT          : Credit Limit
    --
    -- Output Parameters description:
    --
    --------------------------------------------------------------------------------
    -- Revision History:
    -- =============================================================================
    -- Date               Version#    Name                Remarks
    -- =============================================================================
    -- 25-MAY-2011        1.0         Vijaya Reddy        Initial development.
    -------------------------------------------------------------------------------
    BEGIN
        ----------------------------
        -- INSERT INTO CUSTOM TABLE
        ----------------------------
        gv_error_position   :=
            'GET_CUST_CRLMT - Populate Custom Table with data';

        INSERT INTO xxdo.xxdoar_brndexp_cust_temp (customer_number, customer_name, credit_limit
                                                   , request_id)
             VALUES (pv_customer_number, pv_customer_name, pn_credit_limit,
                     apps.fnd_global.conc_request_id);
    END get_bexp_cust_crlmt;

    PROCEDURE get_bexp_openrel_ordamt (pv_customer_number      VARCHAR2,
                                       pv_customer_name        VARCHAR2,
                                       pv_brand                VARCHAR2,
                                       pn_open_rel_order_amt   NUMBER,
                                       pn_org_id               NUMBER)
    IS
    --------------------------------------------------------------------------------
    -- Created By              : Vijaya Reddy
    -- Creation Date           : 25-MAY-2011
    -- Description             : To insert  Customer wise Brand wise sum of total
    --                           Open Sales Orders which are not on Hold
    --                           + net AR open balance amount which is invoiced
    --
    -- Input Parameters description:
    -- PV_CUSTOMER_NUMBER       : Customer Number
    -- PV_CUSTOMER_NAME         : Customer Name
    -- PV_BRAND                 : Brand
    -- PN_OPEN_REL_ORDER_AMT    : Open Release Order Amount
    -- PV_ORG_ID                : Operating Unit ID
    --
    -- Output Parameters description:
    --
    --------------------------------------------------------------------------------
    -- Revision History:
    -- =============================================================================
    -- Date               Version#    Name                Remarks
    -- =============================================================================
    -- 25-MAY-2011        1.0         Vijaya Reddy        Initial development.
    -------------------------------------------------------------------------------
    BEGIN
        ----------------------------
        -- INSERT INTO CUSTOM TABLE
        ----------------------------
        gv_error_position   :=
            'GET_BEXP_OPENREL_ORDAMT - Populate Custom Table with data';

        INSERT INTO xxdo.xxdoar_brndexp_snh_nar_temp (customer_number,
                                                      customer_name,
                                                      brand,
                                                      open_rel_order_amt,
                                                      org_id,
                                                      request_id)
                 VALUES (pv_customer_number,
                         pv_customer_name,
                         pv_brand,
                         pn_open_rel_order_amt,
                         pn_org_id,
                         apps.fnd_global.conc_request_id);
    END get_bexp_openrel_ordamt;

    PROCEDURE get_bexp_salord_hold (pv_customer_number VARCHAR2, pv_customer_name VARCHAR2, pv_brand VARCHAR2
                                    , pn_sales_order_num NUMBER, pn_sales_order_value NUMBER, pn_org_id NUMBER)
    IS
    --------------------------------------------------------------------------------
    -- Created By              : Vijaya Reddy
    -- Creation Date           : 25-MAY-2011
    -- Description             : To insert Customer wise Brand wise Individual
    --                            Open Sales Orders which are on Hold
    --
    -- Input Parameters description:
    -- PV_CUSTOMER_NUMBER       : Customer Number
    -- PV_CUSTOMER_NAME         : Customer Name
    -- PN_SALES_ORDER_NUM       : Sales Order Number
    -- PN_SALES_ORDER_VALUE     : Sales Order Amount
    -- PN_ORG_ID                : Opearating Unit ID
    --
    -- Output Parameters description:
    --
    --------------------------------------------------------------------------------
    -- Revision History:
    -- =============================================================================
    -- Date               Version#    Name                Remarks
    -- =============================================================================
    -- 25-MAY-2011        1.0         Vijaya Reddy        Initial development.
    -------------------------------------------------------------------------------
    BEGIN
        ----------------------------
        -- INSERT INTO CUSTOM TABLE
        ----------------------------
        gv_error_position   :=
            'GET_BEXP_SALORD_HOLD - Populate Custom Table with data';

        INSERT INTO xxdo.xxdoar_brndexp_shold_temp (customer_number, customer_name, brand, sales_order_num, sales_order_value, org_id
                                                    , request_id)
             VALUES (pv_customer_number, pv_customer_name, pv_brand,
                     pn_sales_order_num, pn_sales_order_value, pn_org_id,
                     apps.fnd_global.conc_request_id);
    END get_bexp_salord_hold;


    PROCEDURE get_overdue_brand (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, pn_org_id NUMBER
                                 , pn_cust_id NUMBER)
    AS
        ln_count               NUMBER;
        lv_cust_num            VARCHAR2 (30);
        lv_cust_name           VARCHAR2 (50);
        ln_credit_limit        NUMBER;
        lv_return_status       VARCHAR2 (30);
        lv_msg_data            VARCHAR2 (4000);
        ln_msg_count           NUMBER;
        lv_hold_source_rec     apps.oe_holds_pvt.hold_source_rec_type;
        ln_hold_id             NUMBER;
        lv_hold_entity_code    VARCHAR2 (10) DEFAULT 'O';
        ln_header_id           NUMBER;
        p_errbuf               VARCHAR2 (200);
        p_retcode              VARCHAR2 (50);
        --Started Added by BT Technology team on 08-DEC-2014 (version 1.2)
        lv_past_due_qual_amt   NUMBER;
        lv_low_due_days        NUMBER;
        lv_hold_qual_amt       NUMBER;
        lv_put_hold_flag       VARCHAR2 (5);

        --Started Added by BT Technology team on 08-DEC-2014 (version 1.2)


        ----------------------
        -- CURSOR DECLARATIONS
        ----------------------
        ----------------------------------------------------------------------------------
        -- CURSOR TO RETRIEVE CUSTOMER INFORMATION WHOSE CREDIT LIMIT <=100k
        ----------------------------------------------------------------------------------
        CURSOR c_ob_cust_crlt_cur (cp_cust_id IN NUMBER)
        IS
              SELECT cust_acct.account_number AS customer_number, SUBSTRB (party.party_name, 1, 50) AS customer_name, hcpa.overall_credit_limit AS credit_limit
                FROM apps.hz_customer_profiles hcp, apps.hz_cust_profile_classes hcpc, apps.hz_parties party,
                     apps.hz_cust_accounts cust_acct, apps.hz_cust_profile_amts hcpa
               WHERE     hcp.status = 'A'
                     AND hcpc.status = 'A'
                     AND cust_acct.status = 'A'
                     AND hcp.profile_class_id = hcpc.profile_class_id
                     AND hcpa.cust_account_profile_id =
                         hcp.cust_account_profile_id
                     AND cust_acct.party_id = party.party_id
                     AND cust_acct.cust_account_id = hcp.cust_account_id
                     AND hcpc.NAME NOT IN
                             ('Employee', 'House', 'Promo Accounts')
                     AND hcp.site_use_id IS NULL
                     AND hcpa.overall_credit_limit <=
                         (SELECT meaning
                            FROM apps.fnd_lookup_values_vl
                           WHERE     lookup_type = 'XXDOAR_BRAND_CL'
                                 AND lookup_code = 'BRANDCL'
                                 AND enabled_flag = 'Y')
                     AND hcpa.currency_code NOT IN
                             (SELECT meaning
                                FROM apps.fnd_lookup_values_vl
                               WHERE     lookup_type = 'XXDOAR_BRAND_CL'
                                     AND lookup_code = 'BRANDCUR'
                                     AND enabled_flag = 'Y')
                     AND cust_acct.cust_account_id =
                         NVL (cp_cust_id, cust_acct.cust_account_id)
            ORDER BY SUBSTRB (party.party_name, 1, 50);

        ----------------------------------------------------------------------------------------------------------
        -- CURSOR TO RETRIEVE CUSTOMER WISE BRAND WISE AR OVERDUE AMOUNT WHERE DUE DATE >=31DAYS AND <=60DAYS
        ----------------------------------------------------------------------------------------------------------
        CURSOR c_cbr_ar_ovramt_cur (cp_org_id    IN NUMBER,
                                    cp_cust_id   IN NUMBER)
        IS
              SELECT cust_acct.cust_account_id, -- Added By BT Technology Team on 08-DEC-2014 (version1.2)
                                                cust_acct.account_number AS customer_number, SUBSTRB (party.party_name, 1, 50) AS customer_name,
                     -- rcta.attribute5 AS brand                                    -- Commented by BT Technology Team on 08-DEC-2014 (version 1.2)
                     cust_acct.ATTRIBUTE1 AS brand, -- Modified by BT Technology Team on 08-DEC-2014 (version 1.2)
                                                    SUM (arps.amount_due_remaining) AS ar_overdue_amount, arps.due_date,
                     arps.trx_number, arps.org_id
                FROM apps.hz_parties party, apps.hz_cust_accounts cust_acct, apps.ar_payment_schedules_all arps,
                     apps.ra_customer_trx_all rcta, apps.hr_all_organization_units hou
               WHERE     cust_acct.status = 'A'
                     AND cust_acct.party_id = party.party_id
                     AND cust_acct.cust_account_id = arps.customer_id
                     AND arps.customer_trx_id = rcta.customer_trx_id
                     AND arps.org_id = hou.organization_id
                     AND arps.status = 'OP'
                     --AND arps.class<> 'PMT'
                     AND arps.org_id = NVL (cp_org_id, arps.org_id)
                     AND cust_acct.cust_account_id =
                         NVL (cp_cust_id, cust_acct.cust_account_id)
                     -- AND SYSDATE >= (arps.due_date + 31)  AND SYSDATE<= (arps.due_date + 60)
                     AND (arps.amount_due_remaining) >
                         NVL (
                             apps.fnd_profile.VALUE (
                                 'MutliBrand_PastDue_Qual_Amt'),
                             0)
                     AND SYSDATE >=
                         (  arps.due_date
                          + (SELECT meaning
                               FROM apps.fnd_lookup_values_vl
                              WHERE     lookup_type = 'XXDOAR_BRAND_CL'
                                    AND lookup_code = 'BRANDOVERDUE'
                                    AND enabled_flag = 'Y'))
            --Started commented by BT Technology team on 08-DEC-2014 (version 1.2)
            /*             AND SYSDATE >=
                                 (  arps.due_date
                                  + (SELECT meaning
                                       FROM apps.fnd_lookup_values_vl
                                      WHERE lookup_type ='XXDOAR_BRAND_CL'
                                        AND lookup_code = 'BRANDOVERDUE'
                                        AND enabled_flag = 'Y')
                                 )
                            AND SYSDATE <=
                                 (  arps.due_date
                                  + (SELECT meaning
                                       FROM apps.fnd_lookup_values_vl
                                      WHERE lookup_type ='XXDOAR_BRAND_CL'
                                        AND lookup_code ='BRANDOVRALLOVERDUE'
                                        AND enabled_flag = 'Y')
                                 ) */
            --Ended commented by BT Technology team on 08-DEC-2014 (version 1.2)
            GROUP BY cust_acct.cust_account_id, -- Added By BT Technology Team on 08-DEC-2014 (version1.2)
                                                cust_acct.account_number, -- rcta.attribute5                                   -- Commented by BT Technology Team on 08-DEC-2014 (version 1.2)
                                                                          cust_acct.ATTRIBUTE1, -- Modified by BT Technology Team on 08-DEC-2014 (version 1.2)
                     SUBSTRB (party.party_name, 1, 50), arps.due_date, arps.org_id,
                     arps.trx_number
            ORDER BY SUBSTRB (party.party_name, 1, 50);

        ----------------------------------------------------------------------------------------------------------
        -- CURSOR TO RETRIEVE CUSTOMER WISE BRAND WISE ALL THE OPEN SALES ORDERS
        ----------------------------------------------------------------------------------------------------------
        CURSOR c_cbr_op_salord_cur (cp_cust_num IN VARCHAR2, cp_brand IN VARCHAR2, cp_org_id IN NUMBER)
        IS
            SELECT DISTINCT
                   ooha.order_number AS salesorder,
                   cust_acct.account_number AS customer_number,
                   SUBSTRB (party.party_name, 1, 50) AS customer_name,
                   -- ooha.attribute5 AS brand,                           -- Commented by BT Technology Team on 08-DEC-2014 (version 1.2)
                   cust_acct.ATTRIBUTE1 AS brand, -- Modified by BT Technology Team on 08-DEC-2014 (version 1.2)
                   ooha.header_id,
                   --Started added by BT Technology team on 08-DEC-2014 (version 1.2)
                   (SELECT SUM (i.ordered_quantity * i.unit_selling_price)
                      FROM apps.oe_order_lines_all i
                     WHERE i.header_id = ooha.header_id) AS order_amt, --For calculating order amount for sales order
                   ooha.org_id
              --Ended added by BT Technology team on 08-DEC-2014 (version 1.2)
              FROM apps.oe_order_headers_all ooha, apps.oe_order_lines_all oola, apps.hz_parties party,
                   apps.hz_cust_accounts cust_acct
             WHERE     oola.header_id = ooha.header_id
                   AND cust_acct.party_id = party.party_id
                   AND cust_acct.cust_account_id = ooha.sold_to_org_id
                   AND cust_acct.status = 'A'
                   AND oola.open_flag = 'Y'
                   AND ooha.open_flag = 'Y'
                   AND oola.booked_flag = 'Y'
                   AND oola.line_category_code <> 'RETURN'
                   --  AND ooha.order_type_id IN ( SELECT transaction_type_id FROM apps.oe_transaction_types_all WHERE transaction_type_code = 'ORDER')
                   AND NOT EXISTS
                           (SELECT 1
                              FROM apps.ra_customer_trx_lines_all rct
                             WHERE rct.sales_order =
                                   TO_CHAR (ooha.order_number))
                   AND NOT EXISTS
                           (SELECT 1
                              FROM apps.ra_interface_lines_all ril
                             WHERE ril.sales_order =
                                   TO_CHAR (ooha.order_number))
                   AND EXISTS
                           (SELECT 1
                              FROM apps.oe_order_holds_all oohd, apps.oe_hold_releases ohr
                             WHERE     oohd.header_id = ooha.header_id
                                   AND oohd.hold_release_id =
                                       ohr.hold_release_id
                                   AND oohd.released_flag = 'Y'
                                   AND ohr.release_reason_code NOT IN
                                           ('BRAND_EXP_REL_HOLD', 'MULTI_BRAND_CREDIT_REL'))
                   /* AND NOT EXISTS (
                           SELECT 1
                             FROM apps.oe_order_holds_all oohd
                              WHERE oohd.header_id = ooha.header_id
                              AND oohd.released_flag = 'N'  )  */
                   AND NOT EXISTS
                           (SELECT 1
                              FROM apps.oe_order_holds_all oohold, apps.oe_hold_sources_all ohs, apps.oe_hold_definitions ohd
                             WHERE     oohold.header_id = oola.header_id
                                   AND NVL (oohold.line_id, oola.line_id) =
                                       oola.line_id
                                   AND oola.org_id = ooha.org_id
                                   AND oohold.hold_source_id =
                                       ohs.hold_source_id
                                   AND ohs.hold_id = ohd.hold_id
                                   AND oohold.released_flag = 'N'
                                   AND ohd.type_code = 'CREDIT')
                   AND oola.flow_status_code IN ('PO_CREATED', 'BOOKED', 'AWAITING_SHIPPING',
                                                 'AWAITING_RECEIPT', 'INVOICED', 'SUPPLY_ELIGIBLE',
                                                 'PO_REQ_CREATED', 'PO_OPEN')
                   --   AND oola.flow_status_code NOT IN ('CANCELLED', 'CLOSED')
                   AND ooha.flow_status_code NOT IN ('CANCELLED', 'CLOSED')
                   AND cust_acct.account_number = cp_cust_num
                   -- AND ooha.attribute5 = cp_brand                           -- Commented by BT Technology Team on 08-DEC-2014 (version 1.2)
                   AND cust_acct.ATTRIBUTE1 = cp_brand -- Modified by BT Technology Team on 08-DEC-2014 (version 1.2)
                   AND ooha.org_id = NVL (cp_org_id, ooha.org_id)
            --   AND cust_acct.account_number = '3149'
            UNION
            SELECT DISTINCT
                   ooha.order_number AS salesorder,
                   cust_acct.account_number AS customer_number,
                   SUBSTRB (party.party_name, 1, 50) AS customer_name,
                   -- ooha.attribute5 AS brand ,                           -- Commented by BT Technology Team on 08-DEC-2014 (version 1.2)
                   cust_acct.ATTRIBUTE1 AS brand, -- Modified by BT Technology Team on 08-DEC-2014 (version 1.2)
                   ooha.header_id,
                   --Started added by BT Technology team on 08-DEC-2014 (version 1.2)
                   (SELECT SUM (i.ordered_quantity * i.unit_selling_price)
                      FROM apps.oe_order_lines_all i
                     WHERE i.header_id = ooha.header_id) AS order_amt, --For calculating order amount for sales order
                   ooha.org_id
              --Ended added by BT Technology team on 08-DEC-2014 (version 1.2)
              FROM apps.oe_order_headers_all ooha, apps.oe_order_lines_all oola, apps.hz_parties party,
                   apps.hz_cust_accounts cust_acct
             WHERE     oola.header_id = ooha.header_id
                   AND cust_acct.party_id = party.party_id
                   AND cust_acct.cust_account_id = ooha.sold_to_org_id
                   AND cust_acct.status = 'A'
                   AND oola.open_flag = 'Y'
                   AND ooha.open_flag = 'Y'
                   AND oola.booked_flag = 'Y'
                   AND oola.line_category_code <> 'RETURN'
                   --    AND ooha.order_type_id IN ( SELECT transaction_type_id FROM apps.oe_transaction_types_all WHERE transaction_type_code = 'ORDER')
                   AND NOT EXISTS
                           (SELECT 1
                              FROM apps.ra_customer_trx_lines_all rct
                             WHERE rct.sales_order =
                                   TO_CHAR (ooha.order_number))
                   AND NOT EXISTS
                           (SELECT 1
                              FROM apps.ra_interface_lines_all ril
                             WHERE ril.sales_order =
                                   TO_CHAR (ooha.order_number))
                   AND NOT EXISTS
                           (SELECT 1
                              FROM apps.oe_order_holds_all oohd
                             WHERE oohd.header_id = ooha.header_id)
                   AND oola.flow_status_code IN ('PO_CREATED', 'BOOKED', 'AWAITING_SHIPPING',
                                                 'AWAITING_RECEIPT', 'INVOICED', 'SUPPLY_ELIGIBLE',
                                                 'PO_REQ_CREATED', 'PO_OPEN')
                   --AND oola.flow_status_code NOT IN ('CANCELLED', 'CLOSED')
                   AND ooha.flow_status_code NOT IN ('CANCELLED', 'CLOSED')
                   AND cust_acct.account_number = cp_cust_num
                   -- AND ooha.attribute5 = cp_brand                          -- Commented by BT Technology Team on 07-DEC-2014 (version 1.2)
                   AND cust_acct.ATTRIBUTE1 = cp_brand -- Modified by BT Technology Team on 07-DEC-2014  (version 1.2)
                   AND ooha.org_id = NVL (cp_org_id, ooha.org_id);

        ---------------------------------------------------------------------------------
        -- TYPE DECLARATIONS TO STORE THE FETCHED OVERDUE FOR BRAND RECORDS
        ---------------------------------------------------------------------------------
        TYPE ob_cust_crlt_tabtype IS TABLE OF c_ob_cust_crlt_cur%ROWTYPE
            INDEX BY PLS_INTEGER;

        ob_cust_crlt_tbl       ob_cust_crlt_tabtype;

        ld_due_date            DATE;
        lc_trx_number          VARCHAR2 (100);
        ln_overdue_amount      NUMBER := 0;

        CURSOR c_cust_accnt_details (p_org_id IN NUMBER, p_cust_account_id IN NUMBER, p_brand IN VARCHAR2)
        IS
              SELECT 'Y', arps.due_date, arps.trx_number,
                     SUM (arps.amount_due_remaining)
                FROM apps.hz_parties party, apps.hz_cust_accounts cust_acct, apps.ar_payment_schedules_all arps,
                     apps.ra_customer_trx_all rcta, apps.hr_all_organization_units hou
               WHERE     cust_acct.status = 'A'
                     AND cust_acct.party_id = party.party_id
                     AND cust_acct.cust_account_id = arps.customer_id
                     AND arps.customer_trx_id = rcta.customer_trx_id
                     AND arps.org_id = hou.organization_id
                     AND arps.status = 'OP'
                     AND arps.org_id = p_org_id
                     AND cust_acct.cust_account_id <> p_cust_account_id
                     AND cust_acct.ATTRIBUTE1 <> p_brand
                     AND (arps.amount_due_remaining) >
                         NVL (
                             apps.fnd_profile.VALUE (
                                 'MutliBrand_PastDue_Qual_Amt'),
                             0)
                     AND SYSDATE >
                         (  arps.due_date
                          + (SELECT meaning
                               FROM apps.fnd_lookup_values_vl
                              WHERE     lookup_type = 'XXDOAR_BRAND_CL'
                                    AND lookup_code = 'BRANDOVRALLOVERDUE'
                                    AND enabled_flag = 'Y'))
            GROUP BY arps.due_date, arps.trx_number;
    BEGIN
        --------------------------------------------------------------------------------
        -- QUERY TO RETRIEVE HOLD_ID for a SALES ORDER
        --------------------------------------------------------------------------------
        BEGIN
            SELECT hold_id
              INTO ln_hold_id
              FROM apps.oe_hold_definitions
             WHERE NAME = 'Overdue for Brand - Hold Applied';
        EXCEPTION
            WHEN OTHERS
            THEN
                p_errbuf    := SQLCODE || SQLERRM;
                p_retcode   := -5;
                apps.fnd_file.put_line (apps.fnd_file.LOG,
                                        'Program Terminated Abruptly1');
                apps.fnd_file.put_line (apps.fnd_file.LOG,
                                        'All Data is Not Processed1');
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                       'HOLD_ID does not exists in OE_HOLD_DEFINITIONS '
                    || p_errbuf);
        END;

        -------------------------------------
        -- To delete data from Custom Table
        -------------------------------------
        BEGIN
            DELETE FROM xxdo.xxdoar_ovrdueb_cust_temp;

            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Custom table is deleted ');          --DD
            COMMIT;
        END;

        -----------------------------------------------------
        -- Check whether the custom table is empty
        -----------------------------------------------------
        SELECT COUNT (1) INTO ln_count FROM xxdo.xxdoar_ovrdueb_cust_temp;

        apps.fnd_file.put_line (apps.fnd_file.LOG, 'count :' || ln_count); --DD

        IF ln_count = 0
        THEN
            -----------------------------------------------------------------
            -- RETRIEVE ALL CUSTOMER INFORMATION WHOSE CREDIT LIMIT <=100K
            -----------------------------------------------------------------
            gv_error_position   :=
                'OVERDUE FOR BRAND - Retrieve Cursor1 c_ob_cust_crlt_cur Based on Input Parameter';

            OPEN c_ob_cust_crlt_cur (cp_cust_id => pn_cust_id);

            LOOP
                FETCH c_ob_cust_crlt_cur
                    BULK COLLECT INTO ob_cust_crlt_tbl
                    LIMIT 1000;

                IF ob_cust_crlt_tbl.COUNT > 0
                THEN
                    FOR x_ob_cust_crlt IN ob_cust_crlt_tbl.FIRST ..
                                          ob_cust_crlt_tbl.LAST
                    LOOP
                        get_overb_cust_crlmt (
                            pv_customer_number   =>
                                ob_cust_crlt_tbl (x_ob_cust_crlt).customer_number,
                            pv_customer_name   =>
                                ob_cust_crlt_tbl (x_ob_cust_crlt).customer_name,
                            pn_credit_limit   =>
                                ob_cust_crlt_tbl (x_ob_cust_crlt).credit_limit);

                        COMMIT;
                    END LOOP;                                   --Bulk Collect
                END IF;

                EXIT WHEN c_ob_cust_crlt_cur%NOTFOUND;
            END LOOP;                                     --c_ob_cust_crlt_cur

            CLOSE c_ob_cust_crlt_cur;
        END IF;

        apps.fnd_file.put_line (
            apps.fnd_file.output,
            '                                         DECKERS Outdoor Corporation                                                 ');
        apps.fnd_file.put_line (
            apps.fnd_file.output,
            '                                         ******************************                                              ');
        apps.fnd_file.put_line (
            apps.fnd_file.output,
            '                                                                                                                     ');
        apps.fnd_file.put_line (
            apps.fnd_file.output,
            '                                  Multi Brand Credit line Process for Overdue for Brand           ');
        apps.fnd_file.put_line (
            apps.fnd_file.output,
            '                                  ********************************************************         ');
        apps.fnd_file.put_line (
            apps.fnd_file.output,
            '                                                        ');
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD ('Customer Number', 17, ' ')
            || RPAD ('Customer Name', 30, ' ')
            || RPAD ('Customer Cr Limit', 20, ' ')
            || RPAD ('Brand', 20, ' ')
            || RPAD ('Invoice Number', 20, ' ')
            || RPAD ('Due Date', 12, ' ')
            || RPAD ('AR Overdue Amount', 20, ' ')
            || RPAD ('Sales Order Num', 20, ' '));
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD ('***************', 17, ' ')
            || RPAD ('*************', 30, ' ')
            || RPAD ('*****************', 20, ' ')
            || RPAD ('*****', 20, ' ')
            || RPAD ('**************', 20, ' ')
            || RPAD ('********', 12, ' ')
            || RPAD ('*****************', 20, ' ')
            || RPAD ('***************', 20, ' '));

        FOR ar_ovramt
            IN c_cbr_ar_ovramt_cur (cp_org_id    => pn_org_id,
                                    cp_cust_id   => pn_cust_id)
        --Started added by BT Technology team on 09-DEC-2014 (version 1.2)
        LOOP
            lv_past_due_qual_amt   := 0;

            BEGIN
                SELECT NVL (apps.fnd_profile.VALUE ('MutliBrand_PastDue_Qual_Amt'), 0)
                  INTO lv_past_due_qual_amt
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'Exception while determining lv_past_due_qual_amt. SQLERRM'
                        || SQLERRM);
            END;

            BEGIN
                SELECT meaning
                  INTO lv_low_due_days
                  FROM apps.fnd_lookup_values_vl
                 WHERE     lookup_type = 'XXDOAR_BRAND_CL'
                       AND lookup_code = 'BRANDOVERDUE'
                       AND enabled_flag = 'Y';
            EXCEPTION
                WHEN OTHERS
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'Exception while determining lv_low_due_days. SQLERRM'
                        || SQLERRM);
            END;


            lv_put_hold_flag       := 'N';

            --IF ar_ovramt.ar_overdue_amount >  lv_past_due_qual_amt AND (TRUNC(SYSDATE) - ar_ovramt.due_date) > lv_low_due_days
            IF c_cbr_ar_ovramt_cur%ROWCOUNT > 0
            THEN
                lv_put_hold_flag   := 'Y';
            ELSE
                BEGIN
                    OPEN c_cust_accnt_details (ar_ovramt.org_id,
                                               ar_ovramt.cust_account_id,
                                               ar_ovramt.brand);

                    FETCH c_cust_accnt_details INTO lv_put_hold_flag, ld_due_date, lc_trx_number, ln_overdue_amount;

                    CLOSE c_cust_accnt_details;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                               'There is NO overdue amount by more than 60 days for other brands. SQLERRM'
                            || SQLERRM);
                END;
            END IF;

            APPS.fnd_file.put_line (APPS.fnd_file.LOG,
                                    'lv_put_hold_flag' || lv_put_hold_flag);

            IF lv_put_hold_flag = 'Y'
            --Ended added by BT Technology team on 08-DEC-2014 (version 1.2)
            THEN
                BEGIN
                    SELECT customer_number, customer_name, credit_limit
                      INTO lv_cust_num, lv_cust_name, ln_credit_limit
                      FROM xxdo.xxdoar_ovrdueb_cust_temp
                     WHERE customer_number = ar_ovramt.customer_number;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        p_errbuf    := SQLCODE || SQLERRM;
                        p_retcode   := -5;
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'Program Terminated Abruptly2');
                        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                                'All Data is Not Processed2');
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                               'Error while checking data exists in XXDOAR_OVRDUEB_CUST_TEMP '
                            || p_errbuf);
                END;

                FOR op_salord
                    IN c_cbr_op_salord_cur (ar_ovramt.customer_number,
                                            ar_ovramt.brand,
                                            ar_ovramt.org_id)
                --Started added by BT Technology team on 09-DEC-2014 (version 1.2)
                LOOP
                    lv_hold_qual_amt   := 0;

                    BEGIN
                        SELECT NVL (apps.fnd_profile.VALUE ('MultiBrand_OrderHold_Qual_amt'), 0)
                          INTO lv_hold_qual_amt
                          FROM DUAL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            apps.fnd_file.put_line (
                                apps.fnd_file.LOG,
                                   'Exception while determining lv_past_due_qual_amt. SQLERRM'
                                || SQLERRM);
                    END;



                    IF op_salord.order_amt > lv_hold_qual_amt
                    -- Ended added by BT Technology team on 09-DEC-2014 (version 1.2)

                    THEN
                        -- Started commented by BT Technology team on 16-DEC-2014 (version 1.2)
                        /*apps.fnd_global.apps_initialize (apps.fnd_global.user_id,
                                                            apps.fnd_global.resp_id,
                                                            apps.fnd_global.resp_appl_id
                                                           );*/
                        -- Ended commented by BT Technology team on 16-DEC-2014 (version 1.2)
                        --    APPS.FND_GLOBAL.APPS_INITIALIZE(21352,20678,222);
                        --    apps.mo_global.init ('AR');                            --  commented by BT Technology team on 16-DEC-2014 (version 1.2)
                        apps.mo_global.set_policy_context ('S', pn_org_id); --  Added by BT Technology Team on 16-DEC-2014 (version 1.2)
                        lv_hold_source_rec                    :=
                            apps.oe_holds_pvt.g_miss_hold_source_rec;
                        lv_hold_source_rec.hold_id            := ln_hold_id;
                        lv_hold_source_rec.hold_entity_code   :=
                            lv_hold_entity_code;
                        lv_hold_source_rec.hold_entity_id     :=
                            op_salord.header_id;
                        lv_hold_source_rec.header_id          :=
                            op_salord.header_id;
                        lv_hold_source_rec.org_id             :=
                            op_salord.org_id; --  Added by BT Technology Team on 16-DEC-2014 (version 1.2)
                        lv_return_status                      := NULL;
                        lv_msg_data                           := NULL;
                        ln_msg_count                          := NULL;
                        apps.oe_holds_pub.apply_holds (
                            p_api_version       => 1.0,
                            p_init_msg_list     => apps.fnd_api.g_true,
                            p_commit            => apps.fnd_api.g_false,
                            p_hold_source_rec   => lv_hold_source_rec,
                            x_return_status     => lv_return_status,
                            x_msg_count         => ln_msg_count,
                            x_msg_data          => lv_msg_data);
                        apps.fnd_file.put_line (
                            apps.fnd_file.output,
                            '                                                                                               ');

                        apps.fnd_file.put_line (
                            apps.fnd_file.output,
                               RPAD (op_salord.customer_number, 17, ' ')
                            || RPAD (op_salord.customer_name, 30, ' ')
                            || RPAD (
                                   TO_CHAR (NVL (ln_credit_limit, 0),
                                            '999999.99'),
                                   20,
                                   ' ')
                            || RPAD (op_salord.brand, 20, ' ')
                            || RPAD (
                                   NVL (ar_ovramt.trx_number, lc_trx_number),
                                   20,
                                   ' ')
                            || RPAD (NVL (ar_ovramt.due_date, ld_due_date),
                                     12,
                                     ' ')
                            || RPAD (
                                   TO_CHAR (
                                       NVL (ar_ovramt.ar_overdue_amount,
                                            ln_overdue_amount),
                                       '999999.99'),
                                   20,
                                   ' ')
                            || RPAD (op_salord.salesorder, 20, ' '));



                        IF lv_return_status = apps.fnd_api.g_ret_sts_success
                        THEN
                            apps.fnd_file.put_line (
                                apps.fnd_file.output,
                                'Successfully Applied Hold on :' || op_salord.salesorder);
                            COMMIT;
                        ELSIF lv_return_status IS NULL
                        THEN
                            apps.fnd_file.put_line (
                                apps.fnd_file.LOG,
                                   'Applied Hold for :'
                                || op_salord.salesorder
                                || ' Status is null');
                        ELSE
                            apps.fnd_file.put_line (
                                apps.fnd_file.LOG,
                                   'Applied Hold for :'
                                || op_salord.salesorder
                                || ' failure:'
                                || lv_msg_data);
                        END IF;
                    END IF;
                END LOOP;
            END IF;
        END LOOP;
    END get_overdue_brand;

    PROCEDURE get_overb_cust_crlmt (pv_customer_number VARCHAR2, pv_customer_name VARCHAR2, pn_credit_limit NUMBER)
    IS
        --------------------------------------------------------------------------------
        -- Created By              : Vijaya Reddy
        -- Creation Date           : 01-JUN-2011
        -- Description             : To insert Customer Information whose credit limit <=100k
        --
        -- Input Parameters description:
        -- PV_CUSTOMER_NUMBER       : Customer Number
        -- PV_CUSTOMER_NAME         : Customer Name
        -- PN_CREDIT_LIMIT          : Credit Limit
        --
        -- Output Parameters description:
        --
        --------------------------------------------------------------------------------
        -- Revision History:
        -- =============================================================================
        -- Date               Version#    Name                Remarks
        -- =============================================================================
        -- 01-JUN-2011        1.0         Vijaya Reddy        Initial development.
        -------------------------------------------------------------------------------
        l_cnt   NUMBER;
    BEGIN
        ----------------------------
        -- INSERT INTO CUSTOM TABLE
        ----------------------------

        gv_error_position   :=
            'GET_OVERB_CUST_CRLMT - Populate Custom Table with data';

        INSERT INTO xxdo.xxdoar_ovrdueb_cust_temp (customer_number, customer_name, credit_limit
                                                   , request_id)
             VALUES (pv_customer_number, pv_customer_name, pn_credit_limit,
                     apps.fnd_global.conc_request_id);


        SELECT COUNT (*) INTO l_cnt FROM xxdo.xxdoar_ovrdueb_cust_temp;

        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
            'Inside get_overb_cust_crlmt count ' || l_cnt);
    END get_overb_cust_crlmt;

    PROCEDURE get_overdue_check_agg (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, pn_org_id IN NUMBER
                                     , pn_cust_id IN NUMBER)
    AS
        ln_count              NUMBER;
        lv_cust_num           VARCHAR2 (30);
        lv_cust_name          VARCHAR2 (50);
        ln_credit_limit       NUMBER;
        lv_return_status      VARCHAR2 (30);
        lv_msg_data           VARCHAR2 (4000);
        ln_msg_count          NUMBER;
        lv_hold_source_rec    apps.oe_holds_pvt.hold_source_rec_type;
        ln_hold_id            NUMBER;
        lv_hold_entity_code   VARCHAR2 (10) DEFAULT 'O';
        ln_header_id          NUMBER;
        p_errbuf              VARCHAR2 (200);
        p_retcode             VARCHAR2 (50);

        ----------------------
        -- CURSOR DECLARATIONS
        ----------------------
        ----------------------------------------------------------------------------------
        -- CURSOR TO RETRIEVE CUSTOMER INFORMATION WHOSE CREDIT LIMIT <=100k
        ----------------------------------------------------------------------------------
        CURSOR c_oca_cust_crlt_cur (cp_cust_id IN NUMBER)
        IS
              SELECT cust_acct.account_number AS customer_number, SUBSTRB (party.party_name, 1, 50) AS customer_name, hcpa.overall_credit_limit AS credit_limit
                FROM apps.hz_customer_profiles hcp, apps.hz_cust_profile_classes hcpc, apps.hz_parties party,
                     apps.hz_cust_accounts cust_acct, apps.hz_cust_profile_amts hcpa
               WHERE     hcp.status = 'A'
                     AND hcpc.status = 'A'
                     AND cust_acct.status = 'A'
                     AND hcp.profile_class_id = hcpc.profile_class_id
                     AND hcpa.cust_account_profile_id =
                         hcp.cust_account_profile_id
                     AND cust_acct.party_id = party.party_id
                     AND cust_acct.cust_account_id = hcp.cust_account_id
                     AND hcpc.NAME NOT IN
                             ('Employee', 'House', 'Promo Accounts')
                     AND hcp.site_use_id IS NULL
                     AND hcpa.overall_credit_limit <=
                         (SELECT meaning
                            FROM apps.fnd_lookup_values_vl
                           WHERE     lookup_type = 'XXDOAR_BRAND_CL'
                                 AND lookup_code = 'BRANDCL'
                                 AND enabled_flag = 'Y')              --<=100k
                     AND hcpa.currency_code NOT IN
                             (SELECT meaning
                                FROM apps.fnd_lookup_values_vl
                               WHERE     lookup_type = 'XXDOAR_BRAND_CL'
                                     AND lookup_code = 'BRANDCUR'
                                     AND enabled_flag = 'Y')
                     AND cust_acct.cust_account_id =
                         NVL (cp_cust_id, cust_acct.cust_account_id)
            ORDER BY SUBSTRB (party.party_name, 1, 50);

        ----------------------------------------------------------------------------------------------------------
        -- CURSOR TO RETRIEVE CUSTOMER WISE BRAND WISE AR OVERDUE AMOUNT WHERE DUE DATE > 60DAYS
        ----------------------------------------------------------------------------------------------------------
        CURSOR c_oca_ar_ovramt_cur (cp_org_id    IN NUMBER,
                                    cp_cust_id   IN NUMBER)
        IS
              SELECT cust_acct.account_number AS customer_number, SUBSTRB (party.party_name, 1, 50) AS customer_name, rcta.attribute5 AS brand,
                     SUM (arps.amount_due_remaining) AS ar_overdue_amount, arps.due_date, arps.trx_number,
                     arps.org_id
                FROM apps.hz_parties party, apps.hz_cust_accounts cust_acct, apps.ar_payment_schedules_all arps,
                     apps.ra_customer_trx_all rcta, apps.hr_all_organization_units hou
               WHERE     cust_acct.status = 'A'
                     AND cust_acct.party_id = party.party_id
                     AND cust_acct.cust_account_id = arps.customer_id
                     AND arps.customer_trx_id = rcta.customer_trx_id
                     AND arps.org_id = hou.organization_id
                     AND arps.status = 'OP'
                     --  AND arps.class<> 'PMT'
                     AND arps.org_id = NVL (cp_org_id, arps.org_id)
                     AND cust_acct.cust_account_id =
                         NVL (cp_cust_id, cust_acct.cust_account_id)
                     -- AND SYSDATE > (arps.due_date + 60)
                     AND SYSDATE >
                         (  arps.due_date
                          + (SELECT meaning
                               FROM apps.fnd_lookup_values_vl
                              WHERE     lookup_type = 'XXDOAR_BRAND_CL'
                                    AND lookup_code = 'BRANDOVRALLOVERDUE'
                                    AND enabled_flag = 'Y'))
            GROUP BY cust_acct.account_number, rcta.attribute5, SUBSTRB (party.party_name, 1, 50),
                     arps.due_date, arps.trx_number, arps.org_id
              HAVING SUM (arps.amount_due_remaining) > 0
            ORDER BY SUBSTRB (party.party_name, 1, 50);

        ----------------------------------------------------------------------------------------------------------
        -- CURSOR TO RETRIEVE DISTINCT CUSTOMER WISE AR OVERDUE AMOUNT WHERE DUE DATE > 60DAYS
        ----------------------------------------------------------------------------------------------------------
        CURSOR c_oca_cur (cp_org_id IN NUMBER, cp_cust_id IN NUMBER)
        IS
            SELECT DISTINCT a.customer_number, a.customer_name
              FROM (  SELECT cust_acct.account_number AS customer_number, SUBSTRB (party.party_name, 1, 50) AS customer_name, rcta.attribute5 AS brand,
                             SUM (arps.amount_due_remaining) AS ar_overdue_amount, arps.due_date, arps.org_id
                        FROM apps.hz_parties party, apps.hz_cust_accounts cust_acct, apps.ar_payment_schedules_all arps,
                             apps.ra_customer_trx_all rcta, apps.hr_all_organization_units hou
                       WHERE     cust_acct.status = 'A'
                             AND cust_acct.party_id = party.party_id
                             AND cust_acct.cust_account_id = arps.customer_id
                             AND arps.customer_trx_id = rcta.customer_trx_id
                             AND arps.org_id = hou.organization_id
                             AND arps.status = 'OP'
                             -- AND arps.class<> 'PMT'
                             AND arps.org_id = NVL (cp_org_id, arps.org_id)
                             AND cust_acct.cust_account_id =
                                 NVL (cp_cust_id, cust_acct.cust_account_id)
                             -- AND SYSDATE > (arps.due_date + 60)
                             AND SYSDATE >
                                 (  arps.due_date
                                  + (SELECT meaning
                                       FROM apps.fnd_lookup_values_vl
                                      WHERE     lookup_type = 'XXDOAR_BRAND_CL'
                                            AND lookup_code =
                                                'BRANDOVRALLOVERDUE'
                                            AND enabled_flag = 'Y'))
                    GROUP BY cust_acct.account_number, rcta.attribute5, SUBSTRB (party.party_name, 1, 50),
                             arps.due_date, arps.org_id
                      HAVING SUM (arps.amount_due_remaining) > 0
                    ORDER BY SUBSTRB (party.party_name, 1, 50)) a;

        ----------------------------------------------------------------------------------------------------------
        -- CURSOR TO RETRIEVE CUSTOMER WISE ALL THE OPEN SALES ORDERS
        ----------------------------------------------------------------------------------------------------------
        CURSOR c_oca_op_salord_cur (cp_cust_num   IN NUMBER,
                                    cp_org_id     IN NUMBER)
        IS
            SELECT DISTINCT ooha.order_number AS salesorder, cust_acct.account_number AS customer_number, SUBSTRB (party.party_name, 1, 50) AS customer_name,
                            ooha.header_id
              FROM apps.oe_order_headers_all ooha, apps.oe_order_lines_all oola, apps.hz_parties party,
                   apps.hz_cust_accounts cust_acct
             WHERE     oola.header_id = ooha.header_id
                   AND cust_acct.party_id = party.party_id
                   AND cust_acct.cust_account_id = ooha.sold_to_org_id
                   AND cust_acct.status = 'A'
                   AND oola.open_flag = 'Y'
                   AND ooha.open_flag = 'Y'
                   AND oola.booked_flag = 'Y'
                   AND oola.line_category_code <> 'RETURN'
                   AND NOT EXISTS
                           (SELECT 1
                              FROM apps.ra_customer_trx_lines_all rct
                             WHERE rct.sales_order =
                                   TO_CHAR (ooha.order_number))
                   AND NOT EXISTS
                           (SELECT 1
                              FROM apps.ra_interface_lines_all ril
                             WHERE ril.sales_order =
                                   TO_CHAR (ooha.order_number))
                   AND EXISTS
                           (SELECT 1
                              FROM apps.oe_order_holds_all oohd, apps.oe_hold_releases ohr
                             WHERE     oohd.header_id = ooha.header_id
                                   AND oohd.hold_release_id =
                                       ohr.hold_release_id
                                   AND oohd.released_flag = 'Y'
                                   AND ohr.release_reason_code NOT IN
                                           ('BRAND_EXP_REL_HOLD', 'MULTI_BRAND_CREDIT_REL'))
                   /*   AND NOT EXISTS (
                            SELECT 1
                              FROM apps.oe_order_holds_all oohd
                               WHERE oohd.header_id = ooha.header_id
                               AND oohd.released_flag = 'N'  )  */
                   AND NOT EXISTS
                           (SELECT 1
                              FROM apps.oe_order_holds_all oohold, apps.oe_hold_sources_all ohs, apps.oe_hold_definitions ohd
                             WHERE     oohold.header_id = oola.header_id
                                   AND NVL (oohold.line_id, oola.line_id) =
                                       oola.line_id
                                   AND oola.org_id = ooha.org_id
                                   AND oohold.hold_source_id =
                                       ohs.hold_source_id
                                   AND ohs.hold_id = ohd.hold_id
                                   AND oohold.released_flag = 'N'
                                   AND ohd.type_code = 'CREDIT')
                   AND oola.flow_status_code IN ('PO_CREATED', 'BOOKED', 'AWAITING_SHIPPING',
                                                 'AWAITING_RECEIPT', 'INVOICED', 'SUPPLY_ELIGIBLE',
                                                 'PO_REQ_CREATED', 'PO_OPEN')
                   -- AND oola.flow_status_code NOT IN ('CANCELLED', 'CLOSED')
                   AND ooha.flow_status_code NOT IN ('CANCELLED', 'CLOSED')
                   AND cust_acct.account_number = cp_cust_num
                   AND ooha.org_id = NVL (cp_org_id, ooha.org_id)
            UNION
            SELECT DISTINCT ooha.order_number AS salesorder, cust_acct.account_number AS customer_number, SUBSTRB (party.party_name, 1, 50) AS customer_name,
                            ooha.header_id
              FROM apps.oe_order_headers_all ooha, apps.oe_order_lines_all oola, apps.hz_parties party,
                   apps.hz_cust_accounts cust_acct
             WHERE     oola.header_id = ooha.header_id
                   AND cust_acct.party_id = party.party_id
                   AND cust_acct.cust_account_id = ooha.sold_to_org_id
                   AND cust_acct.status = 'A'
                   AND oola.open_flag = 'Y'
                   AND ooha.open_flag = 'Y'
                   AND oola.booked_flag = 'Y'
                   AND oola.line_category_code <> 'RETURN'
                   AND NOT EXISTS
                           (SELECT 1
                              FROM apps.ra_customer_trx_lines_all rct
                             WHERE rct.sales_order =
                                   TO_CHAR (ooha.order_number))
                   AND NOT EXISTS
                           (SELECT 1
                              FROM apps.ra_interface_lines_all ril
                             WHERE ril.sales_order =
                                   TO_CHAR (ooha.order_number))
                   AND NOT EXISTS
                           (SELECT 1
                              FROM apps.oe_order_holds_all oohd
                             WHERE oohd.header_id = ooha.header_id)
                   AND oola.flow_status_code IN ('PO_CREATED', 'BOOKED', 'AWAITING_SHIPPING',
                                                 'AWAITING_RECEIPT', 'INVOICED', 'SUPPLY_ELIGIBLE',
                                                 'PO_REQ_CREATED', 'PO_OPEN')
                   --AND oola.flow_status_code NOT IN ('CANCELLED', 'CLOSED')
                   AND ooha.flow_status_code NOT IN ('CANCELLED', 'CLOSED')
                   AND cust_acct.account_number = cp_cust_num
                   AND ooha.org_id = NVL (cp_org_id, ooha.org_id);

        ---------------------------------------------------------------------------------
        -- TYPE DECLARATIONS TO STORE THE FETCHED OVERDUE CHECK AGGREGATE RECORDS
        ---------------------------------------------------------------------------------
        TYPE oca_cust_crlt_tabtype IS TABLE OF c_oca_cust_crlt_cur%ROWTYPE
            INDEX BY PLS_INTEGER;

        oca_cust_crlt_tbl     oca_cust_crlt_tabtype;
    BEGIN
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
            'Cust Id and Org ID ' || pn_cust_id || '-' || pn_org_id);

        --------------------------------------------------------------------------------
        -- QUERY TO RETRIEVE HOLD_ID for a SALES ORDER
        --------------------------------------------------------------------------------
        BEGIN
            SELECT hold_id
              INTO ln_hold_id
              FROM apps.oe_hold_definitions
             WHERE NAME = 'Overdue Check Aggregate - Hold Applied';
        EXCEPTION
            WHEN OTHERS
            THEN
                p_errbuf    := SQLCODE || SQLERRM;
                p_retcode   := -5;
                apps.fnd_file.put_line (apps.fnd_file.LOG,
                                        'Program Terminated Abruptly');
                apps.fnd_file.put_line (apps.fnd_file.LOG,
                                        'All Data is Not Processed');
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                       'HOLD_ID does not exists in OE_HOLD_DEFINITIONS '
                    || p_errbuf);
        END;

        -------------------------------------
        -- To delete data from Custom Table
        -------------------------------------
        BEGIN
            DELETE FROM xxdo.xxdoar_ovrchka_cust_temp;

            COMMIT;
        END;

        -----------------------------------------------------
        -- Check whether the custom table is empty
        -----------------------------------------------------
        SELECT COUNT (1) INTO ln_count FROM xxdo.xxdoar_ovrchka_cust_temp;

        IF ln_count = 0
        THEN
            -----------------------------------------------------------------
            -- RETRIEVE ALL CUSTOMER INFORMATION WHOSE CREDIT LIMIT <=100K
            -----------------------------------------------------------------
            gv_error_position   :=
                'OVERDUE CHECK AGGREGATE - Retrieve Cursor1 c_oca_cust_crlt_cur Based on Input Parameter';

            OPEN c_oca_cust_crlt_cur (cp_cust_id => pn_cust_id);

            LOOP
                FETCH c_oca_cust_crlt_cur
                    BULK COLLECT INTO oca_cust_crlt_tbl
                    LIMIT 1000;

                IF oca_cust_crlt_tbl.COUNT > 0
                THEN
                    FOR x_oca_cust_crlt IN oca_cust_crlt_tbl.FIRST ..
                                           oca_cust_crlt_tbl.LAST
                    LOOP
                        get_overca_cust_crlmt (
                            pv_customer_number   =>
                                oca_cust_crlt_tbl (x_oca_cust_crlt).customer_number,
                            pv_customer_name   =>
                                oca_cust_crlt_tbl (x_oca_cust_crlt).customer_name,
                            pn_credit_limit   =>
                                oca_cust_crlt_tbl (x_oca_cust_crlt).credit_limit);
                        COMMIT;
                    END LOOP;                                   --Bulk Collect
                END IF;

                EXIT WHEN c_oca_cust_crlt_cur%NOTFOUND;
            END LOOP;                                    --c_oca_cust_crlt_cur

            CLOSE c_oca_cust_crlt_cur;
        END IF;

        apps.fnd_file.put_line (
            apps.fnd_file.output,
            '                                                     DECKERS Outdoor Corporation                                            ');
        apps.fnd_file.put_line (
            apps.fnd_file.output,
            '                                                     ******************************                                           ');
        apps.fnd_file.put_line (
            apps.fnd_file.output,
            '                                                                                                                               ');
        apps.fnd_file.put_line (
            apps.fnd_file.output,
            '                                           Multi Brand Credit line Process for Overdue Check Aggregate                                        ');
        apps.fnd_file.put_line (
            apps.fnd_file.output,
            '                                            **************************************************************                                     ');
        apps.fnd_file.put_line (
            apps.fnd_file.output,
            '                                                        ');
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD ('Customer Number', 17, ' ')
            || RPAD ('Customer Name', 30, ' ')
            || RPAD ('Customer Cr Limit', 20, ' ')
            || RPAD ('Brand', 20, ' ')
            || RPAD ('Invoice Number', 20, ' ')
            || RPAD ('Due Date', 12, ' ')
            || RPAD ('AR Overdue Amount', 20, ' '));
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD ('***************', 17, ' ')
            || RPAD ('*************', 30, ' ')
            || RPAD ('*****************', 20, ' ')
            || RPAD ('*****', 20, ' ')
            || RPAD ('**************', 20, ' ')
            || RPAD ('********', 12, ' ')
            || RPAD ('*****************', 20, ' '));

        FOR ar_ovramt
            IN c_oca_ar_ovramt_cur (cp_org_id    => pn_org_id,
                                    cp_cust_id   => pn_cust_id)
        LOOP
            BEGIN
                SELECT customer_number, customer_name, credit_limit
                  INTO lv_cust_num, lv_cust_name, ln_credit_limit
                  FROM xxdo.xxdoar_ovrchka_cust_temp
                 WHERE customer_number = ar_ovramt.customer_number;
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_errbuf    := SQLCODE || SQLERRM;
                    p_retcode   := -5;
                    apps.fnd_file.put_line (apps.fnd_file.LOG,
                                            'Program Terminated Abruptly');
                    apps.fnd_file.put_line (apps.fnd_file.LOG,
                                            'All Data is Not Processed');
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'Error while checking data exists in XXDOAR_OVRCHKA_CUST_TEMP '
                        || p_errbuf);
            END;

            apps.fnd_file.put_line (
                apps.fnd_file.output,
                '                                                                                                                                                                                                                        ');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   RPAD (ar_ovramt.customer_number, 17, ' ')
                || RPAD (ar_ovramt.customer_name, 30, ' ')
                || RPAD (TO_CHAR (ln_credit_limit, '999999.99'), 20, ' ')
                || RPAD (ar_ovramt.brand, 20, ' ')
                || RPAD (ar_ovramt.trx_number, 20, ' ')
                || RPAD (ar_ovramt.due_date, 12, ' ')
                || RPAD (TO_CHAR (ar_ovramt.ar_overdue_amount, '999999.99'),
                         20,
                         ' '));
        END LOOP;

        FOR c IN c_oca_cur (cp_org_id => pn_org_id, cp_cust_id => pn_cust_id)
        LOOP
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   RPAD ('Customer Number', 17, ' ')
                || RPAD ('Customer Name', 30, ' ')
                || RPAD ('Sales Order Number', 20, ' '));
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   RPAD ('***************', 17, ' ')
                || RPAD ('*************', 30, ' ')
                || RPAD ('******************', 20, ' '));

            FOR oca_salord
                IN c_oca_op_salord_cur (c.customer_number,
                                        cp_org_id   => pn_org_id)
            LOOP
                apps.fnd_global.apps_initialize (
                    apps.fnd_global.user_id,
                    apps.fnd_global.resp_id,
                    apps.fnd_global.resp_appl_id);
                -- FND_GLOBAL.APPS_INITIALIZE(21352,20678,222);
                apps.mo_global.init ('AR');
                lv_hold_source_rec                    :=
                    apps.oe_holds_pvt.g_miss_hold_source_rec;
                lv_hold_source_rec.hold_id            := ln_hold_id;
                lv_hold_source_rec.hold_entity_code   := lv_hold_entity_code;
                lv_hold_source_rec.hold_entity_id     := oca_salord.header_id;
                lv_hold_source_rec.header_id          := oca_salord.header_id;
                lv_return_status                      := NULL;
                lv_msg_data                           := NULL;
                ln_msg_count                          := NULL;
                apps.oe_holds_pub.apply_holds (p_api_version => 1.0, p_init_msg_list => apps.fnd_api.g_true, p_commit => apps.fnd_api.g_false, p_hold_source_rec => lv_hold_source_rec, x_return_status => lv_return_status, x_msg_count => ln_msg_count
                                               , x_msg_data => lv_msg_data);
                apps.fnd_file.put_line (
                    apps.fnd_file.output,
                    '                                                                                                                ');
                apps.fnd_file.put_line (
                    apps.fnd_file.output,
                       RPAD (oca_salord.customer_number, 17, ' ')
                    || RPAD (oca_salord.customer_name, 30, ' ')
                    || RPAD (oca_salord.salesorder, 20, ' '));

                IF lv_return_status = apps.fnd_api.g_ret_sts_success
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                        'Successfully Applied Hold on :' || oca_salord.salesorder);
                    COMMIT;
                ELSIF lv_return_status IS NULL
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'Applied Hold for :'
                        || oca_salord.salesorder
                        || ' Status is null');
                ELSE
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'Applied Hold for :'
                        || oca_salord.salesorder
                        || ' failure:'
                        || lv_msg_data);
                END IF;
            END LOOP;
        END LOOP;
    END get_overdue_check_agg;

    PROCEDURE get_overca_cust_crlmt (pv_customer_number VARCHAR2, pv_customer_name VARCHAR2, pn_credit_limit NUMBER)
    IS
    --------------------------------------------------------------------------------
    -- Created By              : Vijaya Reddy
    -- Creation Date           : 16-JUN-2011
    -- Description             : To insert Customer Information whose credit limit <=100k
    --
    -- Input Parameters description:
    -- PV_CUSTOMER_NUMBER       : Customer Number
    -- PV_CUSTOMER_NAME         : Customer Name
    -- PN_CREDIT_LIMIT          : Credit Limit
    --
    -- Output Parameters description:
    --
    --------------------------------------------------------------------------------
    -- Revision History:
    -- =============================================================================
    -- Date               Version#    Name                Remarks
    -- =============================================================================
    -- 16-JUN-2011        1.0         Venkatesh R          Initial development.
    -------------------------------------------------------------------------------
    BEGIN
        ----------------------------
        -- INSERT INTO CUSTOM TABLE
        ----------------------------
        gv_error_position   :=
            'GET_OVERCA_CUST_CRLMT - Populate Custom Table with data';

        INSERT INTO xxdo.xxdoar_ovrchka_cust_temp (customer_number, customer_name, credit_limit
                                                   , request_id)
             VALUES (pv_customer_number, pv_customer_name, pn_credit_limit,
                     apps.fnd_global.conc_request_id);
    END get_overca_cust_crlmt;
END xxdoar_mulbr_crline_pkg;
/
