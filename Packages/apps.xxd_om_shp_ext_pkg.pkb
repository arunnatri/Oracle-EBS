--
-- XXD_OM_SHP_EXT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:11 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.XXD_OM_SHP_EXT_PKG
IS
    v_def_mail_recips   do_mail_utils.tbl_recips;

    PROCEDURE shipping_data_extract_report (p_d1 OUT VARCHAR2, p_d2 OUT VARCHAR2, p_from_date IN VARCHAR2
                                            , p_to_date IN VARCHAR2)
    AS
        CURSOR c_shipping (v_from_date DATE, v_to_date DATE)
        IS
            SELECT DISTINCT ooha.order_number order_number, ooha.ordered_date order_date, TO_CHAR (TO_DATE (oola.attribute11, 'MM/DD/YYYY HH:MI:SS AM'), 'DD-Mon-YY') drop_date,
                            --ooha.attribute1 brand, --Commented By BT TECHNOLOGY TEAM ON 22-JAN-2015
                            hca.attribute1 brand, --Added By BT TECHNOLOGY TEAM ON 22-JAN-2015
                                                  --Commented Below By BT TECHNOLOGY TEAM ON 22-JAN-2015
                                                  /*    DECODE (rc.customer_number,
                                                              '4689', 'eCommerce',
                                                              DECODE (ottt.NAME,
                                                                      'Retail - US', 'Retail',
                                                                      'Wholesale'
                                                                     )
                                                             ) channel,*/
                                                  --Commented Above By BT TECHNOLOGY TEAM ON 22-JAN-2015
                                                  --Added Below By BT TECHNOLOGY TEAM ON 22-JAN-2015
                                                  DECODE (hca.attribute_category, 'Person', DECODE (hca.attribute18, NULL, NULL, 'eCommerce'), DECODE (ottt.NAME, 'Retail - US', 'Retail', 'Wholesale')) channel, --Added Above By BT TECHNOLOGY TEAM ON 22-JAN-2015
                                                                                                                                                                                                                  TRUNC (wnd.confirm_date) ship_date,
                            wdd.tracking_number tracking_num, DECODE (SUBSTR (wdd.ship_method_code, 1, 1), 'U', 'UPS', 'Fedex') carrier
              FROM apps.oe_order_headers_all ooha, apps.oe_order_lines_all oola, --START Modifications By BT TECHNOLOGY TEAM ON 22-JAN-2015
                                                                                 -- apps.ra_customers rc,
                                                                                 apps.XXD_RA_CUSTOMERS_V rc,
                   --END Modifications By BT TECHNOLOGY TEAM ON 22-JAN-2015
                   apps.oe_transaction_types_all otta, apps.oe_transaction_types_tl ottt, apps.wsh_delivery_details wdd,
                   apps.wsh_delivery_assignments wda, apps.wsh_new_deliveries wnd, apps.hz_cust_accounts_all hca -- Added by By BT TECHNOLOGY TEAM ON 22-JAN-2015
             WHERE     otta.transaction_type_id = ottt.transaction_type_id
                   AND ottt.LANGUAGE = USERENV ('LANG')
                   AND otta.transaction_type_code = 'ORDER'
                   AND otta.transaction_type_id = ooha.order_type_id
                   AND ooha.org_id = (SELECT organization_id
                                        FROM hr_operating_units
                                       --  WHERE NAME = 'Deckers US') --Commented By BT TECHNOLOGY TEAM ON 22-JAN-2015
                                       WHERE NAME = 'Deckers US OU') --Added By BT TECHNOLOGY TEAM ON 22-JAN-2015
                   AND hca.cust_account_id = rc.customer_id
                   AND ooha.sold_to_org_id = rc.customer_id
                   AND oola.header_id = ooha.header_id
                   AND wdd.source_line_id = oola.line_id
                   AND (wdd.ship_method_code LIKE 'U%' OR wdd.ship_method_code LIKE 'R0%')
                   AND wdd.source_code = 'OE'
                   AND wdd.tracking_number IS NOT NULL
                   AND wda.delivery_detail_id = wdd.delivery_detail_id
                   AND wnd.delivery_id = wda.delivery_id
                   AND wnd.status_code = 'CL'
                   AND TRUNC (wnd.confirm_date) BETWEEN v_from_date
                                                    AND v_to_date;

        l_from_ship_date    DATE;
        l_to_ship_date      DATE;
        ex_no_recips        EXCEPTION;
        v_def_mail_recips   do_mail_utils.tbl_recips;
        iretval             VARCHAR2 (4000);
    BEGIN
        l_from_ship_date    :=
            NVL (fnd_date.canonical_to_date (p_from_date),
                 TRUNC (SYSDATE) - 7);
        l_to_ship_date      :=
            NVL (fnd_date.canonical_to_date (p_to_date), TRUNC (SYSDATE));
        v_def_mail_recips   := get_email_recips ('DO_SHIP_DATA_EXTR');

        IF v_def_mail_recips.COUNT < 1
        THEN
            RAISE ex_no_recips;
        END IF;

        do_mail_utils.send_mail_header (fnd_profile.VALUE ('DO_DEF_ALERT_SENDER'), v_def_mail_recips, 'Shipping Data Extract - ' || TO_CHAR (SYSDATE, 'MM/DD/YYYY')
                                        , iretval);
        p_line ('Content-Type: multipart/mixed; boundary=boundarystring');
        p_line ('--boundarystring');
        p_line ('Content-Type: text/plain');
        p_line ('');
        p_line (
            'Please see the attachment for Deckers Shipping Data Extract.');
        p_line ('--boundarystring');
        p_line ('Content-Type: text/xls');
        p_line (
               'Content-Disposition: attachment; filename="Deckers_Shipments_'
            || TO_CHAR (l_to_ship_date, 'YYYYMMDD')
            || '.xls"');
        p_line ('');
        p_line (
               'Order Num'
            || CHR (9)
            || 'Order Date'
            || CHR (9)
            || 'Drop Date'
            || CHR (9)
            || 'Brand'
            || CHR (9)
            || 'Channel'
            || CHR (9)
            || 'Ship Date'
            || CHR (9)
            || 'Tracking Num'
            || CHR (9)
            || 'Carrier');

        FOR rec IN c_shipping (l_from_ship_date, l_to_ship_date)
        LOOP
            --p_line(rpad(to_char(rec.Order_Number),15,' ')||chr(9)||lpad(to_char(rec.Order_Date),11,' ')||chr(9)||lpad(to_char(rec.Drop_Date),11,' ')||chr(9)||lpad(rec.Brand,9,' ')||chr(9)||lpad(rec.Channel,15,' ')||chr(9)||lpad(to_char(rec.Ship_Date),13,' ')||chr(9)||lpad(rec.Tracking_num,20,' ')||chr(9)||lpad(rec.Carrier,8,' '));
            p_line (
                   TO_CHAR (rec.order_number)
                || CHR (9)
                || TO_CHAR (rec.order_date)
                || CHR (9)
                || TO_CHAR (rec.drop_date)
                || CHR (9)
                || rec.brand
                || CHR (9)
                || rec.channel
                || CHR (9)
                || TO_CHAR (rec.ship_date)
                || CHR (9)
                || ''''
                || rec.tracking_num
                || CHR (9)
                || rec.carrier);
        END LOOP;

        do_mail_utils.send_mail_close (iretval);
    END;

    PROCEDURE p_line (p_output VARCHAR2)
    AS
        iretval   VARCHAR2 (4000);
    BEGIN
        --     dbms_output.l
        do_mail_utils.send_mail_line (p_output, iretval);
    END;

    FUNCTION get_email_recips (v_lookup_type VARCHAR2)
        RETURN do_mail_utils.tbl_recips
    IS
        v_def_mail_recips   do_mail_utils.tbl_recips;

        CURSOR c_recips IS
            SELECT lookup_code, meaning, description
              FROM fnd_lookup_values
             WHERE     lookup_type = v_lookup_type
                   AND enabled_flag = 'Y'
                   AND LANGUAGE = 'US'
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
END XXD_OM_SHP_EXT_PKG;
/
