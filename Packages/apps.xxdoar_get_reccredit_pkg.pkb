--
-- XXDOAR_GET_RECCREDIT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:18 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOAR_GET_RECCREDIT_PKG"
AS
    --------------------------------------------------------------------------------
    -- Created By              : Vijaya Reddy
    -- Creation Date           : 15-APR-2011
    -- File Name               : XXDOAR012.pkb
    -- Work Order Num          : 72995
    -- Description             :
    -- Latest Version          : 1.2
    --
    -- Revision History:
    -- =============================================================================
    -- Date               Version#    Name                Remarks
    -- =============================================================================
    -- 15-APR-2011        1.0         Vijaya Reddy        Initial development.
    -- 18-APR-2011        1.1         Venkatesh R
    -- 02-MAY-2011        1.2         Vijaya Reddy
    -- 02-NOV-2016                    Infosys             Added three new Brands(Sanuk,Koolaburra,Hoka)
    -- 20-Jan-2022        1.4         Balavenu Rao        Query Performance Improvement  CCR0009769 CCR# 12282
    -------------------------------------------------------------------------------
    FUNCTION Get_beforereport
        RETURN BOOLEAN
    IS
        --------------------------------------------------------------------------------
        -- Created By              : Vijaya Reddy
        -- Creation Date           : 15-APR-2011
        -- Description             : To insert into custom table
        --
        --
        -- Input Parameters description:
        --
        -- Output Parameters description:
        --
        --------------------------------------------------------------------------------
        -- Revision History:
        -- =============================================================================
        -- Date               Version#    Name                Remarks
        -- =============================================================================
        -- 15-APR-2011        1.0         Vijaya Reddy        Initial development.
        -- 20-APR-2011        1.1         Vijaya Reddy        Modified the second cursor
        -------------------------------------------------------------------------------
        -----------------------
        -- GENERAL VARIABLES
        -----------------------
        ln_count                NUMBER;
        ln_count_bal            NUMBER;
        lv_error_message        VARCHAR2 (32000);

        ----------------------
        -- CURSOR DECLARATIONS
        ----------------------
        ----------------------------------------------------------------------------------
        -- CURSOR TO RETRIEVE RECEIVABLE CREDIT LINE INFORAMTION BASED ON INPUT PARAMETER
        ----------------------------------------------------------------------------------
        CURSOR c_input_rcredit1_cur (cp_operating_unit_id IN NUMBER)
        IS
              SELECT cust_acct.account_number AS customer_number, NVL (SUM (obl.UNIT_SELLING_PRICE -- kp.unit_selling_price
                                                                                                   * DECODE (obh.attribute6, 'SIMPLE', NVL (OBLE.blanket_max_quantity, 0) - NVL (OBLE.released_quantity, 0), 0)), 0) AS simple_amount, NVL (SUM (obl.UNIT_SELLING_PRICE -- kp.unit_selling_price
                                                                                                                                                                                                                                                                        * DECODE (obh.attribute6, 'TEVA', NVL (OBLE.blanket_max_quantity, 0) - NVL (OBLE.released_quantity, 0), 0)), 0) AS teva_amount,
                     NVL (SUM (obl.UNIT_SELLING_PRICE -- kp.unit_selling_price
                                                      * DECODE (obh.attribute6, 'UGG', NVL (OBLE.blanket_max_quantity, 0) - NVL (OBLE.released_quantity, 0), 0)), 0) AS ugg_amount, NVL (SUM (obl.UNIT_SELLING_PRICE -- kp.unit_selling_price
                                                                                                                                                                                                                     * DECODE (obh.attribute6, 'AHNU', NVL (OBLE.blanket_max_quantity, 0) - NVL (OBLE.released_quantity, 0), 0)), 0) AS ahnu_amount, NVL (SUM (obl.UNIT_SELLING_PRICE -- kp.unit_selling_price
                                                                                                                                                                                                                                                                                                                                                                                      * DECODE (obh.attribute6, 'TSUBO', NVL (OBLE.blanket_max_quantity, 0) - NVL (OBLE.released_quantity, 0), 0)), 0) AS tsubo_amount,
                     NVL (SUM (obl.UNIT_SELLING_PRICE -- kp.unit_selling_price
                                                      * DECODE (obh.attribute6, 'DECKERS', NVL (OBLE.blanket_max_quantity, 0) - NVL (OBLE.released_quantity, 0), 0)), 0) AS deckers_amount, NVL (SUM (obl.UNIT_SELLING_PRICE -- kp.unit_selling_price
                                                                                                                                                                                                                             * DECODE (obh.attribute6, 'SANUK', NVL (OBLE.blanket_max_quantity, 0) - NVL (OBLE.released_quantity, 0), 0)), 0) AS sanuk_amount, NVL (SUM (obl.UNIT_SELLING_PRICE -- kp.unit_selling_price
                                                                                                                                                                                                                                                                                                                                                                                                * DECODE (obh.attribute6, 'HOKA', NVL (OBLE.blanket_max_quantity, 0) - NVL (OBLE.released_quantity, 0), 0)), 0) AS hoka_amount,
                     NVL (SUM (obl.UNIT_SELLING_PRICE -- kp.unit_selling_price
                                                      * DECODE (obh.attribute6, 'KOOLABURRA', NVL (OBLE.blanket_max_quantity, 0) - NVL (OBLE.released_quantity, 0), 0)), 0) AS koolaburra_amount, NVL (SUM ( --kp.unit_selling_price
                                                                                                                                                                                                            obl.UNIT_SELLING_PRICE * DECODE ( --kh.brand,
                                                                                                                                                                                                                                             obh.attribute6,  NULL, --current_quantity,
                                                                                                                                                                                                                                                                    NVL (OBLE.blanket_max_quantity, 0) - NVL (OBLE.released_quantity, 0),  'TEVA', 0,  'UGG', 0,  'AHNU', 0,  'SANUK', 0,  'HOKA', 0,  'KOOLABURRA', 0,  --current_quantity
                                                                                                                                                                                                                                                                                                                                                                                                                         NVL (OBLE.blanket_max_quantity, 0) - NVL (OBLE.released_quantity, 0) --unreleased_quantity
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             )), 0) AS others_amount, 0 AS open_release_amount
                FROM                                  --do_kco.do_kco_line kl,
                                                     --do_kco.do_kco_price kp,
                                                    --do_kco.do_kco_header kh,
                apps.hz_parties party, apps.hz_cust_accounts cust_acct, apps.OE_BLANKET_HEADERS_ALL obh,
                apps.OE_BLANKET_LINES_ALL obl, apps.OE_BLANKET_LINES_EXT OBLE
               WHERE     1 = 1
                     AND obh.header_id = obl.header_id
                     AND cust_acct.cust_account_id = obh.SOLD_TO_ORG_ID
                     AND obl.line_id = oble.line_id
                     AND obl.open_flag = 'Y'
                     --             and kl.kco_header_id = kh.kco_header_id
                     --             AND kp.kco_header_id = kl.kco_header_id
                     --             AND kp.inventory_item_id = kl.inventory_item_id
                     AND cust_acct.party_id = party.party_id
                     --             AND cust_acct.cust_account_id = kh.customer_id
                     AND cust_acct.status = 'A'
            --             AND current_quantity > 0
            --             AND kh.enabled_flag = 1
            --             AND kh.open_flag = 1
            --             AND kh.atp_flag = 1
            --             AND kl.enabled_flag = 1
            --             AND kl.open_flag = 1
            --             AND kl.atp_flag = 1
            --             AND TRUNC (NVL (kl.kco_line_disable_date, SYSDATE) + 1) > SYSDATE
            --             AND TRUNC (NVL (kh.kco_disable_date, SYSDATE) + 1) > SYSDATE
            --             AND kco_schedule_date >= SYSDATE
            --             AND kl.org_id NOT IN (SELECT organization_id
            --                                       FROM apps.hr_all_organization_units
            --                                      WHERE NAME LIKE '%eCommerce%')
            --             AND kh.report_visible_flag = 1
            --            AND kl.org_id = NVL(cp_operating_unit_id,kl.org_id)
            GROUP BY cust_acct.account_number;

        ----------------------------------------------------------------------------------
        -- CURSOR
        ----------------------------------------------------------------------------------
        CURSOR c_input_rcredit2_cur (cp_operating_unit_id IN NUMBER)
        IS
              SELECT cust_acct.account_number AS customer_number,
                     NVL (
                         SUM (
                             DECODE (
                                 ooha.attribute5,
                                 'SIMPLE', oola.ordered_quantity * oola.unit_selling_price,
                                 0)),
                         0) AS simple_amount,
                     NVL (
                         SUM (
                             DECODE (
                                 ooha.attribute5,
                                 'TEVA', oola.ordered_quantity * oola.unit_selling_price,
                                 0)),
                         0) AS teva_amount,
                     NVL (
                         SUM (
                             DECODE (
                                 ooha.attribute5,
                                 'UGG', oola.ordered_quantity * oola.unit_selling_price,
                                 0)),
                         0) AS ugg_amount,
                     NVL (
                         SUM (
                             DECODE (
                                 ooha.attribute5,
                                 'AHNU', oola.ordered_quantity * oola.unit_selling_price,
                                 0)),
                         0) AS ahnu_amount,
                     NVL (
                         SUM (
                             DECODE (
                                 ooha.attribute5,
                                 'TSUBO', oola.ordered_quantity * oola.unit_selling_price,
                                 0)),
                         0) AS tsubo_amount,
                     NVL (
                         SUM (
                             DECODE (
                                 ooha.attribute5,
                                 'DECKERS', oola.ordered_quantity * oola.unit_selling_price,
                                 0)),
                         0) AS deckers_amount,
                     NVL (
                         SUM (
                             DECODE (
                                 ooha.attribute5,
                                 'SANUK', oola.ordered_quantity * oola.unit_selling_price,
                                 0)),
                         0) AS sanuk_amount,
                     NVL (
                         SUM (
                             DECODE (
                                 ooha.attribute5,
                                 'HOKA', oola.ordered_quantity * oola.unit_selling_price,
                                 0)),
                         0) AS hoka_amount,
                     NVL (
                         SUM (
                             DECODE (
                                 ooha.attribute5,
                                 'KOOLABURRA', oola.ordered_quantity * oola.unit_selling_price,
                                 0)),
                         0) AS koolaburra_amount,
                     NVL (
                         SUM (
                             DECODE (
                                 ooha.attribute5,
                                 NULL, oola.ordered_quantity * oola.unit_selling_price,
                                 'TEVA', 0,
                                 'UGG', 0,
                                 'AHNU', 0,
                                 'SANUK', 0,
                                 'HOKA', 0,
                                 'KOOLABURRA', 0,
                                 oola.ordered_quantity * oola.unit_selling_price)),
                         0) AS others_amount,
                     (SELECT NVL (SUM (ROUND ((ool.ordered_quantity - NVL (ool.shipped_quantity, NVL (ool.fulfilled_quantity, 0))) * NVL (ool.unit_selling_price, 0), apps.xxdo_iex_profile_summary_pkg.get_precision (ool.header_id))), 0) open_rel_ord
                        FROM apps.oe_order_lines_all ool, oe_order_headers_all ooh --Added CCR0009769 CCR# 12282
                       WHERE     1 = 1
                             AND ooh.header_id = ool.header_id
                             --AND ool.sold_to_org_id = cust_acct.CUST_ACCOUNT_ID --Commented CCR0009769 CCR# 12282
                             AND ooh.sold_to_org_id = cust_acct.CUST_ACCOUNT_ID --Added CCR0009769 CCR# 12282
                             AND ool.flow_status_code IN
                                     ('PO_CREATED', 'BOOKED', 'AWAITING_SHIPPING',
                                      'AWAITING_RECEIPT', 'INVOICED', 'SUPPLY_ELIGIBLE',
                                      'PO_REQ_CREATED', 'PO_OPEN')
                             AND ool.open_flag = 'Y'
                             AND ooh.open_flag = 'Y'
                             AND ool.booked_flag = 'Y'
                             AND ool.line_category_code <> 'RETURN'
                             AND ool.org_id = cp_operating_unit_id
                             AND NOT EXISTS
                                     (SELECT 'Y'
                                        FROM apps.oe_order_holds_all oohold, apps.oe_hold_sources_all ohs, apps.oe_hold_definitions ohd
                                       WHERE     oohold.header_id =
                                                 ool.header_id
                                             AND NVL (oohold.line_id,
                                                      ool.line_id) =
                                                 ool.line_id
                                             AND ool.org_id =
                                                 cp_operating_unit_id
                                             AND oohold.hold_source_id =
                                                 ohs.hold_source_id
                                             AND ohs.hold_id = ohd.hold_id
                                             AND oohold.released_flag = 'N'
                                             AND ohd.type_code = 'CREDIT')) open_release_amount
                FROM apps.OE_ORDER_HEADERS_ALL ooha, apps.oe_order_lines_all oola, apps.hz_parties party,
                     apps.hz_cust_accounts cust_acct
               WHERE     oola.header_id = ooha.header_id
                     AND cust_acct.party_id = party.party_id
                     AND cust_acct.cust_account_id = ooha.sold_to_org_id
                     AND cust_acct.status = 'A'
                     AND oola.open_flag = 'Y'
                     AND ooha.open_flag = 'Y'
                     AND NOT EXISTS
                             (SELECT 1
                                FROM apps.ra_customer_trx_lines_all rct
                               WHERE rct.sales_order =
                                     TO_CHAR (ooha.order_number))
                     AND NOT EXISTS
                             (SELECT 1
                                FROM ar.ra_interface_lines_all ril
                               WHERE ril.sales_order =
                                     TO_CHAR (ooha.order_number))
                     AND EXISTS
                             (SELECT 1
                                FROM APPS.oe_order_holds_all oohold, APPS.oe_hold_sources_all ohs, APPS.oe_hold_definitions ohd
                               WHERE     oohold.header_id = oola.header_id
                                     AND NVL (oohold.line_id, oola.line_id) =
                                         oola.line_id
                                     AND oola.org_id = ooha.org_id
                                     AND oohold.hold_source_id =
                                         ohs.hold_source_id
                                     AND ohs.hold_id = ohd.hold_id
                                     AND oohold.released_flag = 'N'
                                     AND ohd.type_code = 'CREDIT')
                     AND oola.flow_status_code NOT IN ('CANCELLED', 'CLOSED')
                     AND ooha.flow_status_code NOT IN ('CANCELLED', 'CLOSED')
                     AND ooha.org_id NOT IN
                             (SELECT organization_id
                                FROM apps.hr_all_organization_units
                               WHERE NAME LIKE '%eCommerce%')
                     AND ooha.org_id = NVL (cp_operating_unit_id, ooha.org_id)
            GROUP BY cust_acct.account_number, cust_acct.cust_account_id;

        ----------------------------------------------------------------------------------
        -- CURSOR TO RETRIEVE  PAST DUE BALANCE INFORAMTION BASED ON INPUT PARAMETER
        ----------------------------------------------------------------------------------
        CURSOR c_pastdue_bal_cur (cp_operating_unit_id IN NUMBER)
        IS
              SELECT arp.customer_id, arp.org_id, SUM (arp.amount_due_remaining) past_due_balance
                FROM apps.ar_payment_schedules_all arp, apps.hz_parties party, apps.hz_cust_accounts cust_acct
               WHERE     arp.customer_id = cust_acct.cust_account_id
                     AND cust_acct.party_id = party.party_id
                     AND arp.org_id NOT IN
                             (SELECT organization_id
                                FROM apps.hr_all_organization_units
                               WHERE NAME LIKE '%eCommerce%')
                     AND cust_acct.status = 'A'
                     AND arp.due_date < TRUNC (SYSDATE)
                     AND arp.org_id = NVL (cp_operating_unit_id, arp.org_id)
            GROUP BY arp.customer_id, arp.org_id;

        ---------------------------------------------------------------------------------
        -- TYPE DECLARATIONS TO STORE THE FETCHED RECEIVABLE CREDIT LINE RECORDS
        ---------------------------------------------------------------------------------
        TYPE input_rcredit1_tabtype IS TABLE OF c_input_rcredit1_cur%ROWTYPE
            INDEX BY PLS_INTEGER;

        input_rcredit1_tbl      input_rcredit1_tabtype;

        TYPE input_rcredit2_tabtype IS TABLE OF c_input_rcredit2_cur%ROWTYPE
            INDEX BY PLS_INTEGER;

        input_rcredit2_tbl      input_rcredit2_tabtype;

        TYPE input_pastdue_bal_tabtype IS TABLE OF c_pastdue_bal_cur%ROWTYPE
            INDEX BY PLS_INTEGER;

        input_pastdue_bal_tbl   input_pastdue_bal_tabtype;
    BEGIN
        -----------------------------------
        -- To delete data from Custom Table
        -----------------------------------

        BEGIN
            DELETE FROM xxdo.XXDOAR_RECV_CR_LINE_TEMP;

            DELETE FROM xxdo.XXDOAR_PASTDUE_BAL_TEMP;

            COMMIT;
        END;

        -----------------------------------------------------
        -- Check whether the custom table is empty
        -----------------------------------------------------


        SELECT COUNT (1) INTO ln_count FROM xxdo.xxdoar_recv_cr_line_temp;



        IF ln_count = 0
        THEN
            -------------------------------------------------------------
            -- RETRIEVE RECEIVABLES CREDIT LINE BASED ON INPUT PARAMETERS
            -------------------------------------------------------------
            GV_ERROR_POSITION   :=
                'BEFOREREPORT - Retrieve Cursor1 c_input_rcredit1_cur Based on Input Parameter';

            OPEN c_input_rcredit1_cur (
                cp_operating_unit_id => pn_operating_unit_id);

            LOOP
                FETCH c_input_rcredit1_cur
                    BULK COLLECT INTO input_rcredit1_tbl
                    LIMIT 1000;

                IF input_rcredit1_tbl.COUNT > 0
                THEN
                    FOR x_input_rcredit1 IN input_rcredit1_tbl.FIRST ..
                                            input_rcredit1_tbl.LAST
                    LOOP
                        Get_rec_credit (
                            PV_CUSTOMER_NUMBER   =>
                                input_rcredit1_tbl (x_input_rcredit1).customer_number,
                            PN_SIMPLE_AMOUNT   =>
                                input_rcredit1_tbl (x_input_rcredit1).simple_amount,
                            PN_TEVA_AMOUNT   =>
                                input_rcredit1_tbl (x_input_rcredit1).teva_amount,
                            PN_UGG_AMOUNT   =>
                                input_rcredit1_tbl (x_input_rcredit1).ugg_amount,
                            PN_AHNU_AMOUNT   =>
                                input_rcredit1_tbl (x_input_rcredit1).ahnu_amount,
                            PN_TSUBO_AMOUNT   =>
                                input_rcredit1_tbl (x_input_rcredit1).tsubo_amount,
                            PN_DECKERS_AMOUNT   =>
                                input_rcredit1_tbl (x_input_rcredit1).deckers_amount,
                            PN_SANUK_AMOUNT   =>
                                input_rcredit1_tbl (x_input_rcredit1).sanuk_amount,
                            PN_HOKA_AMOUNT   =>
                                input_rcredit1_tbl (x_input_rcredit1).hoka_amount,
                            PN_KOOLABURRA_AMOUNT   =>
                                input_rcredit1_tbl (x_input_rcredit1).koolaburra_amount,
                            PN_OTHERS_AMOUNT   =>
                                input_rcredit1_tbl (x_input_rcredit1).others_amount,
                            PN_OPEN_RELEASE_AMOUNT   =>
                                input_rcredit1_tbl (x_input_rcredit1).open_release_amount);


                        COMMIT;
                    END LOOP;                                   --Bulk Collect
                END IF;

                EXIT WHEN c_input_rcredit1_cur%NOTFOUND;
            END LOOP;                                   --c_input_rcredit1_cur

            CLOSE c_input_rcredit1_cur;

            GV_ERROR_POSITION   :=
                'BEFOREREPORT - Retrieve Cursor2 c_input_rcredit2_cur Based on Input Parameter';

            OPEN c_input_rcredit2_cur (
                cp_operating_unit_id => pn_operating_unit_id);

            LOOP
                FETCH c_input_rcredit2_cur
                    BULK COLLECT INTO input_rcredit2_tbl
                    LIMIT 1000;

                IF input_rcredit2_tbl.COUNT > 0
                THEN
                    FOR x_input_rcredit2 IN input_rcredit2_tbl.FIRST ..
                                            input_rcredit2_tbl.LAST
                    LOOP
                        Get_rec_credit (
                            PV_CUSTOMER_NUMBER   =>
                                input_rcredit2_tbl (x_input_rcredit2).customer_number,
                            PN_SIMPLE_AMOUNT   =>
                                input_rcredit2_tbl (x_input_rcredit2).simple_amount,
                            PN_TEVA_AMOUNT   =>
                                input_rcredit2_tbl (x_input_rcredit2).teva_amount,
                            PN_UGG_AMOUNT   =>
                                input_rcredit2_tbl (x_input_rcredit2).ugg_amount,
                            PN_AHNU_AMOUNT   =>
                                input_rcredit2_tbl (x_input_rcredit2).ahnu_amount,
                            PN_TSUBO_AMOUNT   =>
                                input_rcredit2_tbl (x_input_rcredit2).tsubo_amount,
                            PN_DECKERS_AMOUNT   =>
                                input_rcredit2_tbl (x_input_rcredit2).deckers_amount,
                            PN_SANUK_AMOUNT   =>
                                input_rcredit2_tbl (x_input_rcredit2).sanuk_amount,
                            PN_HOKA_AMOUNT   =>
                                input_rcredit2_tbl (x_input_rcredit2).hoka_amount,
                            PN_KOOLABURRA_AMOUNT   =>
                                input_rcredit2_tbl (x_input_rcredit2).koolaburra_amount,
                            PN_OTHERS_AMOUNT   =>
                                input_rcredit2_tbl (x_input_rcredit2).others_amount,
                            PN_OPEN_RELEASE_AMOUNT   =>
                                input_rcredit2_tbl (x_input_rcredit2).open_release_amount);

                        COMMIT;
                    END LOOP;                                   --Bulk Collect
                END IF;

                EXIT WHEN c_input_rcredit2_cur%NOTFOUND;
            END LOOP;                                   --c_input_rcredit2_cur

            CLOSE c_input_rcredit2_cur;
        END IF;

        ---------------------------------------------------------
        -- Check whether the pastdue balance custom table is empty
        ----------------------------------------------------------


        SELECT COUNT (1) INTO ln_count_bal FROM xxdo.xxdoar_pastdue_bal_temp;

        IF ln_count_bal = 0
        THEN
            -------------------------------------------------------------
            -- RETRIEVE  PASTDUE BALANCE BASED ON INPUT PARAMETERS
            -------------------------------------------------------------
            GV_ERROR_POSITION   :=
                'BEFOREREPORT - Retrieve Cursor3 c_pastdue_bal_cur Based on Input Parameter';

            OPEN c_pastdue_bal_cur (
                cp_operating_unit_id => pn_operating_unit_id);

            LOOP
                FETCH c_pastdue_bal_cur
                    BULK COLLECT INTO input_pastdue_bal_tbl
                    LIMIT 1000;

                IF input_pastdue_bal_tbl.COUNT > 0
                THEN
                    FOR x_input_pastdue_bal IN input_pastdue_bal_tbl.FIRST ..
                                               input_pastdue_bal_tbl.LAST
                    LOOP
                        Get_Pastdue_balance (
                            PN_CUSTOMER_ID   =>
                                input_pastdue_bal_tbl (x_input_pastdue_bal).customer_id,
                            PN_ORG_ID   =>
                                input_pastdue_bal_tbl (x_input_pastdue_bal).org_id,
                            PN_PASTDUE_BAL   =>
                                input_pastdue_bal_tbl (x_input_pastdue_bal).past_due_balance);


                        COMMIT;
                    END LOOP;                                   --Bulk Collect
                END IF;

                EXIT WHEN c_pastdue_bal_cur%NOTFOUND;
            END LOOP;                                      --c_pastdue_bal_cur

            CLOSE c_pastdue_bal_cur;
        END IF;

        RETURN (TRUE);
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_error_message   := SQLERRM;
            apps.FND_FILE.PUT_LINE (
                apps.FND_FILE.LOG,
                'Following Error Occured At ' || GV_ERROR_POSITION);
            RAISE_APPLICATION_ERROR (-20501, lv_error_message);
            RAISE;
    END Get_beforereport;


    PROCEDURE Get_rec_credit (PV_CUSTOMER_NUMBER VARCHAR2, PN_SIMPLE_AMOUNT NUMBER, PN_TEVA_AMOUNT NUMBER, PN_UGG_AMOUNT NUMBER, PN_AHNU_AMOUNT NUMBER, PN_TSUBO_AMOUNT NUMBER, PN_DECKERS_AMOUNT NUMBER, PN_SANUK_AMOUNT NUMBER, PN_HOKA_AMOUNT NUMBER
                              , PN_KOOLABURRA_AMOUNT NUMBER, PN_OTHERS_AMOUNT NUMBER, PN_OPEN_RELEASE_AMOUNT NUMBER)
    IS
    --------------------------------------------------------------------------------
    -- Created By              : Vijaya Reddy
    -- Creation Date           : 15-APR-2011
    -- Description             : To insert receivables credit line
    --
    -- Input Parameters description:
    -- PV_CUSTOMER_NUMBER       : Customer Number
    -- PN_SIMPLE_AMOUNT         : Simple Amount
    -- PN_TEVA_AMOUNT           : Teva Amount
    -- PN_UGG_AMOUNT            : Ugg Amount
    -- PN_AHNU_AMOUNT           : Ahnu Amount
    -- PN_TSUBO_AMOUNT          : Tsubo Amount
    -- PN_DECKERS_AMOUNT        : Deckers Amount
    -- PN_OTHERS_AMOUNT        : Others Amount

    --
    -- Output Parameters description:
    --
    --------------------------------------------------------------------------------
    -- Revision History:
    -- =============================================================================
    -- Date               Version#    Name                Remarks
    -- =============================================================================
    -- 15-APR-2011        1.0         Vijaya Reddy        Initial development.
    -------------------------------------------------------------------------------

    BEGIN
        ----------------------------
        -- INSERT INTO CUSTOM TABLE
        ----------------------------

        GV_ERROR_POSITION   :=
            'GET_REC_CREDIT - Populate Custom Table with data';

        INSERT INTO xxdo.xxdoar_recv_cr_line_temp (customer_number, simple_amount, teva_amount, ugg_amount, ahnu_amount, tsubo_amount, deckers_amount, sanuk_amount, hoka_amount, koolaburra_amount, others_amount, open_rel_bal
                                                   , request_id/*   , last_update_date
                                                                  , last_updated_by
                                                                  , creation_date
                                                                  , created_by
                                                                  , last_update_login
                                                                  , request_id
                                                                  , program_application_id
                                                                  , program_id
                                                                  , program_update_date*/
                                                               )
             VALUES (PV_CUSTOMER_NUMBER, PN_SIMPLE_AMOUNT, PN_TEVA_AMOUNT,
                     PN_UGG_AMOUNT, PN_AHNU_AMOUNT, PN_TSUBO_AMOUNT,
                     PN_DECKERS_AMOUNT, PN_SANUK_AMOUNT, PN_HOKA_AMOUNT,
                     PN_KOOLABURRA_AMOUNT, PN_OTHERS_AMOUNT, PN_OPEN_RELEASE_AMOUNT
                     , apps.fnd_global.conc_request_id/*  , SYSDATE
                                                        , fnd_global.user_id
                                                        , SYSDATE
                                                        , fnd_global.user_id
                                                        , fnd_global.login_id
                                                        , fnd_global.conc_request_id
                                                        , fnd_global.prog_appl_id
                                                        , fnd_global.conc_program_id
                                                        , SYSDATE*/
                                                      );
    END Get_rec_credit;

    PROCEDURE Get_Pastdue_balance (PN_CUSTOMER_ID   NUMBER,
                                   PN_ORG_ID        NUMBER,
                                   PN_PASTDUE_BAL   NUMBER)
    IS
    --------------------------------------------------------------------------------
    -- Created By              : Vijaya Reddy
    -- Creation Date           : 04-MAY-2011
    -- Description             : To insert pastdue balance
    --
    -- Input Parameters description:
    -- PN_CUSTOMER_ID      : Customer ID
    -- PN_ORG_ID           : Org ID
    -- PN_PASTDUE_BAL      : Pastdue Balance
    -- Output Parameters description:
    --
    --------------------------------------------------------------------------------
    -- Revision History:
    -- =============================================================================
    -- Date               Version#    Name                Remarks
    -- =============================================================================
    -- 04-MAY-2011        1.0         Vijaya Reddy        Initial development.
    -------------------------------------------------------------------------------

    BEGIN
        ----------------------------
        -- INSERT INTO CUSTOM TABLE
        ----------------------------

        GV_ERROR_POSITION   :=
            'GET_PASTDUE_BALANCE - Populate Custom Table with data';

        INSERT INTO xxdo.xxdoar_pastdue_bal_temp (customer_id, org_id, pastdue_bal
                                                  , request_id)
             VALUES (PN_CUSTOMER_ID, PN_ORG_ID, PN_PASTDUE_BAL,
                     apps.fnd_global.conc_request_id);
    END Get_Pastdue_balance;


    FUNCTION Get_afterreport
        RETURN BOOLEAN
    IS
    --------------------------------------------------------------------------------
    -- Created By              : Vijaya Reddy
    -- Creation Date           : 15-APR-2011
    -- Description             : To delete data from Custom Table
    --
    -- Input Parameters description:
    --
    -- Output Parameters description:
    --
    --------------------------------------------------------------------------------
    -- Revision History:
    -- =============================================================================
    -- Date               Version#    Name                Remarks
    -- =============================================================================
    -- 15-APR-2011        1.0         Vijaya Reddy      Initial development.
    -------------------------------------------------------------------------------
    BEGIN
        RETURN (TRUE);
    END Get_afterreport;
END XXDOAR_GET_RECCREDIT_PKG;
/
