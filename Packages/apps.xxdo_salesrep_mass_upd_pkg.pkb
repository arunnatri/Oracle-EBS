--
-- XXDO_SALESREP_MASS_UPD_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:32:21 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_SALESREP_MASS_UPD_PKG"
AS
    --------------------------------------------------------------------------------
    -- Created By              : Infosys
    -- Creation Date           : 10-May-2016
    -- Description             : Batch program to update salesreps for order lines on hold
    -- =============================================================================
    -- Date               Version#    Name            Remarks
    -- =============================================================================
    -- 10-May-2016        1.0         Infosys        Initial Version
    -- 03-Jan-2017        1.1        Mithun Mathew  Modified for CCR0005785
    -- =============================================================================
    gc_multi_salesrep      VARCHAR2 (100);
    gc_no_salesrep         VARCHAR2 (100);
    gc_hold_name           VARCHAR2 (100);
    gc_hold_profile        VARCHAR2 (100);
    gc_hold_profile_val    VARCHAR2 (100);
    g_num_no_salesrep_id   NUMBER;


    c_num_debug            NUMBER := 0;
    c_dte_sysdate          DATE := SYSDATE;
    g_num_user_id          NUMBER := fnd_global.user_id;
    g_num_resp_id          NUMBER := fnd_global.resp_id;
    g_num_resp_appl_id     NUMBER := fnd_global.resp_appl_id;
    g_num_login_id         NUMBER := fnd_global.login_id;
    g_num_request_id       NUMBER := fnd_global.conc_request_id;
    g_num_prog_appl_id     NUMBER := fnd_global.prog_appl_id;
    g_dt_current_date      DATE := SYSDATE;
    g_num_rec_count        NUMBER := 0;                         /*LAUNCH_XML*/



    PROCEDURE msg (in_chr_message VARCHAR2)
    IS
    BEGIN
        IF c_num_debug = 1
        THEN
            fnd_file.put_line (fnd_file.LOG, in_chr_message);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Unexpected Error: ' || SQLERRM);
    END;



    PROCEDURE ASSIGN_DEFAULTS
    IS
        CURSOR get_salesrep_defaults_c IS
            SELECT DISTINCT attribute1, attribute2, attribute3,
                            attribute4
              FROM fnd_lookup_values
             WHERE lookup_type = 'XXDO_SALESREP_DEFAULTS';


        CURSOR get_proifle_val_c IS
            SELECT fpov.PROFILE_OPTION_VALUE
              FROM fnd_profile_options fpo, fnd_profile_option_values fpov
             WHERE     profile_option_name =
                       'XXDO_SALESREP_MATRIX_EXCLUDE_HOLD'
                   AND fpov.profile_option_id = fpo.profile_option_id
                   AND level_value = FND_PROFILE.VALUE ('ORG_ID');

        lc_profile_val   VARCHAR2 (1);
    BEGIN
        OPEN get_salesrep_defaults_c;

        FETCH get_salesrep_defaults_c INTO gc_hold_name, gc_hold_profile, gc_multi_salesrep, gc_no_salesrep;

        CLOSE get_salesrep_defaults_c;

        OPEN get_proifle_val_c;

        FETCH get_proifle_val_c INTO lc_profile_val;

        CLOSE get_proifle_val_c;

        gc_hold_profile_val   := NVL (lc_profile_val, 'N');
    END ASSIGN_DEFAULTS;



    FUNCTION RET_HSALESREP (in_num_sold_to_org_id IN NUMBER, in_num_invoice_to_org_id IN NUMBER, in_num_ship_to_org_id NUMBER
                            , in_num_org_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_ret     NUMBER;
        ln_brand   VARCHAR2 (50);
    BEGIN
        IF in_num_sold_to_org_id IS NULL
        THEN
            RETURN NULL;
        END IF;

        ASSIGN_DEFAULTS;

        IF in_num_sold_to_org_id IS NOT NULL
        THEN
            BEGIN
                SELECT hca.attribute1
                  INTO ln_brand
                  FROM hz_cust_accounts_all hca, fnd_lookup_values flv
                 WHERE     hca.cust_account_id = in_num_sold_to_org_id
                       AND flv.lookup_type = 'CUSTOMER CLASS'
                       AND flv.language = USERENV ('LANG')
                       AND hca.customer_class_code = flv.lookup_code
                       AND flv.meaning IN
                               ('Wholesale', 'Dealer Employee', 'Consumer Direct');
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    ln_brand   := NULL;
                    RETURN NULL;
            END;
        END IF;


        SELECT salesrep_id
          INTO ln_ret
          FROM apps.hz_cust_site_uses_all hcsua, do_custom.do_rep_cust_assignment drca
         WHERE     hcsua.site_use_id = drca.site_use_id
               AND drca.customer_id = NVL (in_num_sold_to_org_id, -1)
               AND drca.site_use_id IN
                       (NVL (in_num_invoice_to_org_id, -1), NVL (in_num_ship_to_org_id, -1))
               AND drca.brand = NVL (ln_brand, '--none--')
               AND TRUNC (SYSDATE) BETWEEN NVL (TRUNC (drca.start_date),
                                                TRUNC (SYSDATE))
                                       AND NVL (TRUNC (drca.end_date),
                                                TRUNC (SYSDATE))
               AND drca.org_id = in_num_org_id;

        RETURN ln_ret;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            SELECT salesrep_id
              INTO ln_ret
              FROM jtf_rs_salesreps
             WHERE name = gc_no_salesrep AND org_id = in_num_ORG_ID;

            RETURN ln_ret;
        WHEN TOO_MANY_ROWS
        THEN
            SELECT jrs.salesrep_id
              INTO ln_ret
              FROM jtf_rs_resource_extns_vl jrr, jtf_rs_salesreps jrs
             WHERE     jrr.resource_id = jrs.resource_id
                   AND resource_name = gc_multi_salesrep
                   AND org_id = in_num_ORG_ID;

            RETURN ln_ret;
        WHEN OTHERS
        THEN
            SELECT salesrep_id
              INTO ln_ret
              FROM jtf_rs_salesreps
             WHERE name = gc_no_salesrep AND org_id = in_num_ORG_ID;

            RETURN ln_ret;
    END RET_HSALESREP;


    FUNCTION RET_LSALESREP (order_line_rec IN order_line_cur%ROWTYPE)
        RETURN NUMBER
    IS
        CURSOR get_product_det_c (p_inv_item_id IN NUMBER)
        IS
            SELECT DISTINCT brand, division, department,
                            master_class, sub_class, style_number, --Added for CCR0005785
                            color_code                  --Added for CCR0005785
              FROM xxd_common_items_v
             WHERE inventory_item_id = p_inv_item_id;

        CURSOR get_nosales_rep_det (p_org_id IN NUMBER)
        IS
            SELECT salesrep_id
              FROM jtf_rs_salesreps
             WHERE name = gc_no_salesrep AND org_id = p_org_id;

        CURSOR get_order_excl_flag_c (p_order_type_id IN NUMBER)
        IS
            SELECT NVL (attribute15, 'N')
              FROM oe_transaction_types_all
             WHERE transaction_type_id = p_order_type_id;

        lcu_product_det      get_product_det_c%ROWTYPE;
        ln_salesrep_id       NUMBER := NULL;
        lc_order_excl_flag   VARCHAR2 (10);
        ln_no_salesrep_id    NUMBER;
        ln_brand             VARCHAR2 (50);
    BEGIN
        ln_salesrep_id      := NULL;
        ln_no_salesrep_id   := NULL;
        lcu_product_det     := NULL;

        IF order_line_rec.sold_to_org_id IS NULL
        THEN
            RETURN NULL;
        END IF;

        ASSIGN_DEFAULTS;

        BEGIN
            -- Added to restrict at line level also depending on customer level
            SELECT hca.attribute1
              INTO ln_brand
              FROM hz_cust_accounts_all hca, fnd_lookup_values flv
             WHERE     hca.cust_account_id = order_line_rec.sold_to_org_id
                   AND flv.lookup_type = 'CUSTOMER CLASS'
                   AND flv.language = USERENV ('LANG')
                   AND hca.customer_class_code = flv.lookup_code
                   AND flv.meaning IN
                           ('Wholesale', 'Dealer Employee', 'Consumer Direct');
        --AND flv.meaning IN ('Wholesale','Distributor','Consumer Direct'); Commented as per Inputs from Functional 09-jun-2015

        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                RETURN NULL;
        END;


        IF order_line_rec.order_type_id IS NOT NULL
        THEN
            OPEN get_order_excl_flag_c (order_line_rec.order_type_id);

            FETCH get_order_excl_flag_c INTO lc_order_excl_flag;

            CLOSE get_order_excl_flag_c;
        END IF;

        OPEN get_nosales_rep_det (order_line_rec.org_id);

        FETCH get_nosales_rep_det INTO ln_no_salesrep_id;

        CLOSE get_nosales_rep_det;

        IF UPPER (lc_order_excl_flag) = 'Y'
        THEN
            ln_salesrep_id   := NULL;

            RETURN ln_salesrep_id;
        ELSE
            IF order_line_rec.inventory_item_id IS NOT NULL
            THEN
                OPEN get_product_det_c (order_line_rec.inventory_item_id);

                FETCH get_product_det_c INTO lcu_product_det;

                CLOSE get_product_det_c;

                IF     order_line_rec.org_id IS NOT NULL
                   AND order_line_rec.sold_to_org_id IS NOT NULL
                   AND lcu_product_det.brand IS NOT NULL
                   AND order_line_rec.invoice_to_org_id IS NOT NULL
                THEN
                    ln_salesrep_id   :=
                        XXD_OE_SALESREP_ASSN_PKG.GET_SALES_REP (
                            order_line_rec.org_id,
                            order_line_rec.sold_to_org_id,
                            order_line_rec.invoice_to_org_id,
                            lcu_product_det.brand,
                            lcu_product_det.division,
                            lcu_product_det.department,
                            lcu_product_det.master_class,
                            lcu_product_det.sub_class,
                            lcu_product_det.style_number, --Added for CCR0005785
                            lcu_product_det.color_code  --Added for CCR0005785
                                                      );
                END IF;

                IF     order_line_rec.org_id IS NOT NULL
                   AND order_line_rec.sold_to_org_id IS NOT NULL
                   AND order_line_rec.ship_to_org_id IS NOT NULL
                   AND lcu_product_det.brand IS NOT NULL
                   AND ln_salesrep_id IS NULL
                THEN
                    ln_salesrep_id   :=
                        XXD_OE_SALESREP_ASSN_PKG.GET_SALES_REP (
                            order_line_rec.org_id,
                            order_line_rec.sold_to_org_id,
                            order_line_rec.ship_to_org_id,
                            lcu_product_det.brand,
                            lcu_product_det.division,
                            lcu_product_det.department,
                            lcu_product_det.master_class,
                            lcu_product_det.sub_class,
                            lcu_product_det.style_number, --Added for CCR0005785
                            lcu_product_det.color_code  --Added for CCR0005785
                                                      );
                END IF;
            END IF;

            IF ln_salesrep_id IS NOT NULL
            THEN
                RETURN ln_salesrep_id;
            ELSE
                RETURN NULL;
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END RET_LSALESREP;


    PROCEDURE update_hdr_salesrep (in_num_header_id NUMBER)
    IS
        l_num_sold_to_org_id      NUMBER;
        l_num_ship_to_org_id      NUMBER;
        l_num_invoice_to_org_id   NUMBER;
        l_num_org_id              NUMBER;
        l_num_old_rep             NUMBER;
        l_num_new_rep             NUMBER;
        l_chr_salesrep            VARCHAR2 (100);
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
               'Start of update hdr salesrep for header id :'
            || in_num_header_id);

        SELECT sold_to_org_id, ship_to_org_id, invoice_to_org_id,
               org_id, salesrep_id
          INTO l_num_sold_to_org_id, l_num_ship_to_org_id, l_num_invoice_to_org_id, l_num_org_id,
                                   l_num_old_rep
          FROM oe_order_Headers_all
         WHERE header_id = in_num_header_id;

        IF g_num_no_salesrep_id <> l_num_old_rep
        THEN
            msg ('Order already has valid sales rep. No need to update');
            RETURN;
        END IF;


        l_num_new_rep   := -1;
        l_num_new_rep   :=
            RET_HSALESREP (l_num_sold_to_org_id, l_num_invoice_to_org_id, l_num_ship_to_org_id
                           , l_num_org_id);


        msg ('old salesrep id:' || l_num_old_rep);
        msg ('new salesrep id:' || l_num_new_rep);

        IF l_num_new_rep <> l_num_old_rep
        THEN
            msg ('calling header sales person update ');


            SELECT res.resource_name
              INTO l_chr_salesrep
              FROM JTF_RS_SALESREPS s2, JTF_RS_RESOURCE_EXTNS_VL RES
             WHERE     s2.salesrep_id = l_num_new_rep
                   AND s2.resource_id = res.resource_id
                   AND ROWNUM = 1;

            msg ('sales person name :' || l_chr_salesrep);

            XXD_OE_SALESREP_ASSN_PKG.update_salesrep ('HEADER', in_num_header_id, NULL
                                                      , l_chr_salesrep);
            COMMIT;
        END IF;

        fnd_file.put_line (
            fnd_file.LOG,
            'End of update hdr salesrep for header id :' || in_num_header_id);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error in update hdr salesrep for header id :'
                || in_num_header_id);
    END update_hdr_salesrep;


    PROCEDURE release_hold (in_num_header_id NUMBER, in_num_line_id NUMBER, in_num_hold_id NUMBER
                            , in_chr_Reason VARCHAR2)
    IS
        l_order_tbl       OE_HOLDS_PVT.order_tbl_type;
        l_return_status   VARCHAR2 (30);
        l_msg_data        VARCHAR2 (256);
        l_msg_count       NUMBER;
    BEGIN
        l_order_tbl (1).header_id   := in_num_header_id;

        IF in_num_line_id IS NOT NULL
        THEN
            l_order_tbl (1).line_id   := in_num_line_id;
        END IF;

        OE_Holds_PUB.Release_Holds (
            p_api_version           => 1.0,
            p_order_tbl             => l_order_tbl,
            p_hold_id               => in_num_hold_id,
            p_release_reason_code   => in_chr_reason,
            p_release_comment       => 'Batch Program',
            x_return_status         => l_return_status,
            x_msg_count             => l_msg_count,
            x_msg_data              => l_msg_data);

        -- Check Return Status
        IF l_return_status = FND_API.G_RET_STS_SUCCESS
        THEN
            msg ('success');
            COMMIT;
            update_hdr_salesrep (in_num_header_id);
        ELSE
            msg ('Error');
            ROLLBACK;
        END IF;

        -- Display Return Status
        msg ('ret status IS: ' || l_return_status);
        msg ('msg data IS: ' || l_msg_data);
        msg ('msg COUNT IS: ' || l_msg_count);
    END release_hold;


    PROCEDURE Main (errbuf OUT VARCHAR2, retcode OUT NUMBER, p_ou IN NUMBER,
                    p_order_source IN NUMBER, p_organization IN NUMBER, p_so_number IN NUMBER, p_cust_number IN VARCHAR2, p_cust_name IN VARCHAR2, p_chr_reason IN VARCHAR2
                    , p_debug_level IN VARCHAR2)
    IS
        CURSOR hold_cur IS
              SELECT DISTINCT ooh.header_id, oh.line_id, ooh.order_number,
                              ohs.hold_id
                FROM apps.oe_order_holds_all oh, apps.OE_HOLD_SOURCES_ALL ohs, apps.oe_hold_definitions ohd,
                     apps.oe_order_headers_all ooh, apps.oe_order_lines_all ool, apps.mtl_parameters mp
               WHERE     oh.released_flag = 'N'
                     AND oh.hold_source_id = ohs.hold_source_id
                     AND ohs.hold_id = ohd.hold_id
                     AND ohd.name = 'Salesrep Assignment Hold'
                     AND oh.header_id = ooh.header_id
                     AND NVL (oh.line_id, ool.line_id) = ool.line_id
                     AND ooh.header_id = ool.header_id
                     AND ooh.order_number = NVL (p_so_number, ooh.order_number)
                     AND ool.org_id = NVL (P_OU, ool.org_id)
                     AND ool.order_source_id =
                         NVL (P_ORDER_SOURCE, ool.order_source_id)
                     AND ool.ship_from_org_id = mp.organization_id
                     AND mp.organization_id =
                         NVL (p_organization, mp.organization_id)
                     AND NOT EXISTS
                             (SELECT 1
                                FROM JTF_RS_SALESREPS s2, oe_order_lines_all ool1, JTF_RS_RESOURCE_EXTNS_VL RES
                               WHERE     ool1.header_id = ooh.header_id
                                     AND ool1.salesrep_id = s2.salesrep_id
                                     AND RES.resource_id = s2.resource_id
                                     AND ool.org_id = s2.org_id
                                     AND RES.resource_name = 'No Sales Credit')
            ORDER BY ooh.header_id;

        l_num_header_id    NUMBER := -999;
        l_num_hold_id      NUMBER := 0;
        l_num_count        NUMBER;
        l_num_cur_rep_id   NUMBER;
        l_chr_reason       VARCHAR2 (100) := p_chr_reason;



        l_line_rec         order_line_cur%ROWTYPE;
        l_chr_salesrep     VARCHAR2 (100);
    BEGIN
        errbuf    := '';
        retcode   := '0';

        /*set the debug value - global variable. This controls the complete log throughout the program */
        IF p_debug_level = 'Y'
        THEN
            c_num_debug   := 1;
        ELSE
            c_num_debug   := 0;
        END IF;

        fnd_file.put_line (fnd_file.LOG,
                           'Start of the program : ' || SYSDATE);
        fnd_file.put_line (fnd_file.LOG, 'Operating Unid ID : ' || p_ou);
        fnd_file.put_line (fnd_file.LOG,
                           'Order Source ID: ' || p_order_source);
        fnd_file.put_line (fnd_file.LOG, 'Order Number : ' || p_so_number);
        fnd_file.put_line (fnd_file.LOG, 'Warehouse ID : ' || p_organization);
        fnd_file.put_line (fnd_file.LOG,
                           'Account Number : ' || p_cust_number);
        fnd_file.put_line (fnd_file.LOG, 'Customer Name: ' || p_cust_name);
        fnd_file.put_line (fnd_file.LOG, 'Debug mode : ' || p_debug_level);

        SELECT salesrep_id
          INTO g_num_no_salesrep_id
          FROM JTF_RS_SALESREPS
         WHERE name = 'No Sales Credit' AND ROWNUM = 1;

        fnd_file.put_line (
            fnd_file.LOG,
            'Salesrep Id for No Sales Credit: ' || g_num_no_salesrep_id);

        FOR order_line_rec
            IN order_line_cur (p_ou, p_order_source, p_organization
                               , p_so_number, p_cust_name, p_cust_number)
        LOOP
            msg ('Processing Order Number:' || order_line_rec.order_number);
            msg ('Processing Order Line:' || order_line_rec.line_number);

            l_num_header_id    := order_line_rec.header_id;
            l_num_hold_id      := order_line_rec.hold_id;
            l_line_rec         := order_line_rec;
            l_num_cur_rep_id   := 0;
            l_num_cur_rep_id   := RET_LSALESREP (order_line_rec);
            msg ('New salesrep ID:' || l_num_cur_rep_id);

            IF g_num_no_salesrep_id <> l_num_cur_rep_id
            THEN
                msg ('Preparing for line ID ' || order_line_rec.line_id);
                l_chr_salesrep   := NULL;

                BEGIN
                    SELECT res.resource_name
                      INTO l_chr_salesrep
                      FROM JTF_RS_SALESREPS s2, JTF_RS_RESOURCE_EXTNS_VL RES
                     WHERE     s2.salesrep_id = l_num_cur_rep_id
                           AND s2.resource_id = res.resource_id
                           AND ROWNUM = 1;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Unable to get salerep name for salerep id:'
                            || l_num_cur_rep_id);
                END;

                msg ('sales person name :' || l_chr_salesrep);

                IF l_chr_salesrep IS NOT NULL
                THEN
                    XXD_OE_SALESREP_ASSN_PKG.update_salesrep (
                        'LINE',
                        order_line_rec.header_id,
                        order_line_rec.line_id,
                        l_chr_salesrep);
                    COMMIT;
                END IF;
            END IF;
        END LOOP;


        FOR hold_rec IN hold_cur
        LOOP
            msg (
                'releasing hold for order number: ' || hold_rec.order_number);
            release_hold (hold_rec.header_id, hold_rec.line_id, hold_rec.hold_id
                          , l_chr_reason);
            COMMIT;
        END LOOP;

        fnd_file.put_line (fnd_file.LOG, 'End of the program : ' || SYSDATE);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Unexpected error: ' || SQLERRM);
            retcode   := '2';
    END Main;
END XXDO_SALESREP_MASS_UPD_PKG;
/
