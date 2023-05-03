--
-- XXDO_INTERFACE_MONITORING_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:50 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_INTERFACE_MONITORING_PKG"
AS
    /*
    ********************************************************************************************************************************
    **                                                                                                                             *
    **    Author          : Infosys                                                                                                *
    **    Created         : 20-AUG-2016                                                                                            *
    **    Application     : XXDO                                                                                                   *
    **    Description     : This package is used to send notification to mailer aliases of various subscribers                     *
    **                                                                                                                             *
    **History         :                                                                                                            *
    **------------------------------------------------------------------------------------------                                   *
    **Date        Author                        Version Change Notes                                                               *
    **----------- --------- ------- ------------------------------------------------------------                                   */
    /*********************************************************************************************************************
    * Type                : Procedure                                                                                    *
    * Name                : send_mail                                                                                      *
    * Purpose             : To Send Mail to the Users                                          *
    *********************************************************************************************************************/
    PROCEDURE send_mail (p_i_from_email    IN     VARCHAR2,
                         p_i_to_email      IN     VARCHAR2,
                         p_i_mail_format   IN     VARCHAR2 DEFAULT 'TEXT',
                         p_i_mail_server   IN     VARCHAR2,
                         p_i_subject       IN     VARCHAR2,
                         p_i_mail_body     IN     CLOB DEFAULT NULL,
                         p_o_status           OUT VARCHAR2,
                         p_o_error_msg        OUT VARCHAR2)
    IS
        --Local variable declaration
        l_mail_conn       UTL_SMTP.connection;
        l_chr_err_messg   VARCHAR2 (4000) := NULL;
        l_boundary        VARCHAR2 (255) := '----=*#abc1234321cba#*=';
        l_step            PLS_INTEGER := 12000;
        l_num_email_id    NUMBER;
        l_to_email_id     VARCHAR2 (50);
    BEGIN
        p_o_status    := 'S';
        l_mail_conn   := UTL_SMTP.open_connection (p_i_mail_server, 25);
        UTL_SMTP.helo (l_mail_conn, p_i_mail_server);
        UTL_SMTP.mail (l_mail_conn, p_i_from_email);

        --Counting the number of email_id passed
        SELECT (LENGTH (p_i_to_email) - LENGTH (REPLACE (p_i_to_email, ',', NULL)) + 1)
          INTO l_num_email_id
          FROM DUAL;

        FOR i IN 1 .. l_num_email_id
        LOOP
            SELECT REGEXP_SUBSTR (p_i_to_email, '[^,]+', 1,
                                  i)
              INTO l_to_email_id
              FROM DUAL;

            UTL_SMTP.rcpt (l_mail_conn, l_to_email_id);
        END LOOP;

        UTL_SMTP.open_data (l_mail_conn);
        UTL_SMTP.write_data (
            l_mail_conn,
               'Date: '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
            || UTL_TCP.crlf);
        UTL_SMTP.write_data (l_mail_conn,
                             'To: ' || p_i_to_email || UTL_TCP.crlf);
        UTL_SMTP.write_data (l_mail_conn,
                             'From: ' || p_i_from_email || UTL_TCP.crlf);
        UTL_SMTP.write_data (l_mail_conn,
                             'Subject: ' || p_i_subject || UTL_TCP.crlf);
        UTL_SMTP.write_data (l_mail_conn,
                             'Reply-To: ' || p_i_from_email || UTL_TCP.crlf);

        IF p_i_mail_format = 'HTML'
        THEN
            UTL_SMTP.write_data (l_mail_conn,
                                 'MIME-Version: 1.0' || UTL_TCP.crlf);
            UTL_SMTP.write_data (
                l_mail_conn,
                   'Content-Type: multipart/alternative; boundary="'
                || l_boundary
                || '"'
                || UTL_TCP.crlf
                || UTL_TCP.crlf);
            UTL_SMTP.write_data (l_mail_conn,
                                 '--' || l_boundary || UTL_TCP.crlf);
            UTL_SMTP.write_data (
                l_mail_conn,
                   'Content-Type: text/html; charset="iso-8859-1"'
                || UTL_TCP.crlf
                || UTL_TCP.crlf);
        END IF;

        FOR i IN 0 ..
                 TRUNC ((DBMS_LOB.getlength (p_i_mail_body) - 1) / l_step)
        LOOP
            UTL_SMTP.write_data (
                l_mail_conn,
                DBMS_LOB.SUBSTR (p_i_mail_body, l_step, i * l_step + 1));
        END LOOP;

        UTL_SMTP.write_data (l_mail_conn, UTL_TCP.crlf || UTL_TCP.crlf);

        IF p_i_mail_format = 'HTML'
        THEN
            UTL_SMTP.write_data (l_mail_conn,
                                 '--' || l_boundary || '--' || UTL_TCP.crlf);
        END IF;

        UTL_SMTP.close_data (l_mail_conn);
        UTL_SMTP.quit (l_mail_conn);
    EXCEPTION
        WHEN OTHERS
        THEN
            p_o_status   := 'E';
            p_o_error_msg   :=
                   'Error occurred in send_mail() procedure'
                || SQLERRM
                || ' - '
                || DBMS_UTILITY.format_error_backtrace;
            fnd_file.put_line (fnd_file.LOG,
                               'Exception in send_mail - ' || p_o_error_msg);
    END send_mail;

    /*********************************************************************************************************************
    * Type                : Procedure                                                                                 *
    * Name                : create_interface_dashboard                                                                                 *
    * Purpose             : To collect data and create the dashboard in HTML                                                                 *
    *********************************************************************************************************************/
    PROCEDURE create_interface_dashboard (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_i_from_emailid IN VARCHAR2)
    AS
        --Variables for O2C
        l_ord_shp_not_inv_us         NUMBER := 0;
        l_delv_not_int_us            NUMBER := 0;
        l_rti_rma_us                 NUMBER := 0;
        l_ord_shp_not_inv_china      NUMBER := 0;
        l_delv_not_int_china         NUMBER := 0;
        l_threepl_china_china        NUMBER := 0;
        l_rti_rma_china              NUMBER := 0;
        l_ord_shp_not_inv_eu         NUMBER := 0;
        l_delv_not_int_eu            NUMBER := 0;
        l_rti_rma_eu                 NUMBER := 0;
        l_wh_dist_us                 NUMBER := 0;
        l_wh_dist_china              NUMBER := 0;
        l_wh_dist_eu                 NUMBER := 0;
        --variables wms - for the table
        l_hj_rma_receipts            NUMBER := 0;
        l_rti_rma_hj_receipts        NUMBER := 0;
        l_hj_asn_receipts            NUMBER := 0;
        l_hj_ship_confirm            NUMBER := 0;
        l_hj_inv_transfers           NUMBER := 0;
        v_error                      VARCHAR2 (2000) := NULL;
        l_mtl_trx_int_us             NUMBER := 0;
        l_mtl_trx_int_china          NUMBER := 0;
        l_mtl_trx_int_eu             NUMBER := 0;
        l_rma_holds                  NUMBER := 0;
        ---p2p variables
        l_rti_po_us                  NUMBER := 0;
        l_rti_po_china               NUMBER := 0;
        l_rti_po_eu                  NUMBER := 0;
        ---variables
        l_edi_v_us                   NUMBER := 0;
        l_pl_int_us_pending          NUMBER := 0;
        l_pl_int_china_pending       NUMBER := 0;
        l_pl_int_eu_pending          NUMBER := 0;
        l_gtn_asn_us                 NUMBER := 0;
        l_gtn_asn_china              NUMBER := 0;
        l_gtn_asn_eu                 NUMBER := 0;
        l_gtn_ap_invoice_us          NUMBER := 0;
        l_gtn_ap_invoice_china       NUMBER := 0;
        l_gtn_ap_invoice_eu          NUMBER := 0;
        l_gtn_ap_payment_us          NUMBER := 0;
        l_gtn_ap_payment_china       NUMBER := 0;
        l_gtn_ap_payment_eu          NUMBER := 0;
        l_gtn_tpm_us                 NUMBER := 0;
        l_gtn_tpm_china              NUMBER := 0;
        l_gtn_tpm_eu                 NUMBER := 0;
        l_gtn_poc_us                 NUMBER := 0;
        l_gtn_poc_china              NUMBER := 0;
        l_gtn_poc_eu                 NUMBER := 0;
        l_gtn_po_poa_us              NUMBER := 0;
        l_gtn_po_poa_china           NUMBER := 0;
        l_gtn_po_poa_eu              NUMBER := 0;
        l_ap_interface_us            NUMBER := 0;
        l_ap_interface_china         NUMBER := 0;
        l_ap_interface_eu            NUMBER := 0;
        l_ar_interface_us            NUMBER := 0;
        l_ar_interface_china         NUMBER := 0;
        l_ar_interface_eu            NUMBER := 0;
        l_costing_us                 NUMBER := 0;
        l_costing_china              NUMBER := 0;
        l_costing_eu                 NUMBER := 0;
        l_projects_workfront_us      NUMBER := 0;
        l_projects_workfront_china   NUMBER := 0;
        l_projects_workfront_eu      NUMBER := 0;
        l_projects_ap_us             NUMBER := 0;
        l_projects_ap_china          NUMBER := 0;
        l_projects_ap_eu             NUMBER := 0;
        l_create_account_us          NUMBER := 0;
        l_create_account_china       NUMBER := 0;
        l_create_account_eu          NUMBER := 0;
        l_ap_us                      NUMBER := 0;
        l_ap_china                   NUMBER := 0;
        l_ap_eu                      NUMBER := 0;
        l_ar_us                      NUMBER := 0;
        l_ar_china                   NUMBER := 0;
        l_ar_eu                      NUMBER := 0;
        l_inventory_us               NUMBER := 0;
        l_inventory_china            NUMBER := 0;
        l_inventory_eu               NUMBER := 0;
        l_gl_interface_us            NUMBER := 0;
        l_gl_interface_china         NUMBER := 0;
        l_gl_interface_eu            NUMBER := 0;
        l_fa_mass_us                 NUMBER := 0;
        l_fa_mass_china              NUMBER := 0;
        l_fa_mass_eu                 NUMBER := 0;
        l_lockbox_us                 NUMBER := 0;
        l_lockbox_china              NUMBER := 0;
        l_lockbox_eu                 NUMBER := 0;
        l_wh_v_us                    NUMBER := 0;
        l_wh_v_china                 NUMBER := 0;
        l_wh_v_eu                    NUMBER := 0;
        l_rti_pending_us             NUMBER := 0;
        l_rti_pending_china          NUMBER := 0;
        l_rti_pending_eu             NUMBER := 0;
        l_mtl_tx_pending_us          NUMBER := 0;
        l_mtl_tx_pending_china       NUMBER := 0;
        l_mtl_tx_pending_eu          NUMBER := 0;
        l_del_not_int_china          NUMBER := 0;
        l_del_not_int_eu             NUMBER := 0;
        l_delv_not_int_pen_us        NUMBER := 0;
        l_rti_pending_int_us         NUMBER := 0;
        l_rti_pending_int_china      NUMBER := 0;
        l_rti_pending_int_eu         NUMBER := 0;
        l_mail_body                  CLOB;
        p_i_to_email                 VARCHAR2 (4000);
        l_error_msg                  VARCHAR2 (2000);
        l_return_status              VARCHAR2 (10);
        l_mail_server                VARCHAR2 (50);

        CURSOR lcur_subscriber IS
            SELECT meaning email_address
              FROM fnd_lookup_values flv
             WHERE     lookup_type = 'XXDO_MONITORING_INTERF_MAILER'
                   AND LANGUAGE = USERENV ('LANG')
                   AND enabled_flag = 'Y'
                   AND SYSDATE BETWEEN NVL (flv.start_date_active, SYSDATE)
                                   AND NVL (flv.end_date_active, SYSDATE);
    BEGIN
        ---START O2C - Count Fetching
        --START ::O2C --  Order Shipped but not Invoiced
        --US
        SELECT COUNT (DISTINCT (oeh.order_number))
          INTO l_ord_shp_not_inv_us
          FROM apps.oe_order_headers_all oeh, apps.oe_order_lines_all oel, apps.hr_all_organization_units o,
               apps.oe_order_holds_all ooh, apps.oe_hold_definitions ohd, apps.oe_hold_sources_all ohs
         WHERE     (oel.flow_status_code = ('INVOICE_HOLD') OR oel.flow_status_code = 'FULFILLED')
               AND oeh.header_id = oel.header_id
               AND oeh.header_id = ooh.header_id
               AND ooh.hold_source_id = ohs.hold_source_id
               AND ohs.hold_id = ohd.hold_id
               AND ooh.released_flag = 'N'
               AND oeh.org_id = o.organization_id
               AND NVL (o.name, 'None') LIKE '%US%';

        --CHINA
        SELECT COUNT (DISTINCT (oeh.order_number))
          INTO l_ord_shp_not_inv_china
          FROM apps.oe_order_headers_all oeh, apps.oe_order_lines_all oel, apps.hr_all_organization_units o,
               apps.oe_order_holds_all ooh, apps.oe_hold_definitions ohd, apps.oe_hold_sources_all ohs
         WHERE     (oel.flow_status_code = ('INVOICE_HOLD') OR oel.flow_status_code = 'FULFILLED')
               AND oeh.header_id = oel.header_id
               AND oeh.header_id = ooh.header_id
               AND ooh.hold_source_id = ohs.hold_source_id
               AND ohs.hold_id = ohd.hold_id
               AND ooh.released_flag = 'N'
               AND oeh.org_id = o.organization_id
               AND (NVL (o.name, 'None') LIKE '%CH%' OR NVL (o.name, 'None') LIKE '%JP%' OR NVL (o.name, 'None') LIKE '%HK%' OR NVL (o.name, 'None') LIKE '%APAC%' OR NVL (o.name, 'None') LIKE '%CN%' OR NVL (o.name, 'None') LIKE '%MC%');

        --Europe
        SELECT NVL (COUNT (DISTINCT (oeh.order_number)), 0)
          INTO l_ord_shp_not_inv_eu
          FROM apps.oe_order_headers_all oeh, apps.oe_order_lines_all oel, apps.hr_all_organization_units o,
               apps.oe_order_holds_all ooh, apps.oe_hold_definitions ohd, apps.oe_hold_sources_all ohs
         WHERE     (oel.flow_status_code = ('INVOICE_HOLD') OR oel.flow_status_code = 'FULFILLED')
               AND oeh.header_id = oel.header_id
               AND oeh.header_id = ooh.header_id
               AND ooh.hold_source_id = ohs.hold_source_id
               AND ohs.hold_id = ohd.hold_id
               AND ooh.released_flag = 'N'
               AND oeh.org_id = o.organization_id
               AND (NVL (o.name, 'None') LIKE '%EU%');

        --END ::O2C --  Order Shipped but not Invoiced
        --O2C RTI RMA - CHINA
        SELECT COUNT (*)
          INTO l_rti_rma_china
          FROM apps.rcv_transactions_interface rti, apps.hr_all_organization_units hr_org, apps.hr_all_organization_units hr_whs
         WHERE     rti.org_id = hr_org.organization_id(+)
               AND rti.to_organization_id = hr_whs.organization_id(+)
               AND rti.source_document_code = 'RMA'
               AND (rti.processing_status_code = 'ERROR' OR rti.processing_status_code = 'COMPLETED')
               AND (NVL (hr_whs.name, 'None') LIKE '%CH%' OR NVL (hr_whs.name, 'None') LIKE '%JP%' OR NVL (hr_whs.name, 'None') LIKE '%HK%' OR NVL (hr_whs.name, 'None') LIKE '%APAC%' OR NVL (hr_whs.name, 'None') LIKE '%CN%' OR NVL (hr_whs.name, 'None') LIKE '%MC%');

        -- O2C ::RTI Pending Count -CHINA
        SELECT COUNT (*) rec_count
          INTO l_pl_int_china_pending
          FROM apps.rcv_transactions_interface rti, apps.hr_all_organization_units hr_org, apps.hr_all_organization_units hr_whs
         WHERE     rti.org_id = hr_org.organization_id(+)
               AND rti.to_organization_id = hr_whs.organization_id(+)
               AND rti.source_document_code = 'RMA'
               AND (rti.processing_status_code = 'PENDING')
               AND (NVL (hr_whs.name, 'None') LIKE '%CH%' OR NVL (hr_whs.name, 'None') LIKE '%JP%' OR NVL (hr_whs.name, 'None') LIKE '%HK%' OR NVL (hr_whs.name, 'None') LIKE '%APAC%' OR NVL (hr_whs.name, 'None') LIKE '%CN%' OR NVL (hr_whs.name, 'None') LIKE '%MC%');

        --China Pending RMA
        SELECT COUNT (*) rec_count
          INTO l_rti_rma_us
          FROM apps.rcv_transactions_interface rti, apps.hr_all_organization_units hr_org, apps.hr_all_organization_units hr_whs
         WHERE     rti.org_id = hr_org.organization_id(+)
               AND rti.to_organization_id = hr_whs.organization_id(+)
               AND rti.source_document_code = 'RMA'
               AND (rti.processing_status_code = 'ERROR' OR rti.processing_status_code = 'COMPLETED')
               AND (NVL (hr_whs.name, 'None') LIKE '%US%');

        --US- PENDING
        SELECT COUNT (*) rec_count
          INTO l_rti_pending_us
          FROM apps.rcv_transactions_interface rti, apps.hr_all_organization_units hr_org, apps.hr_all_organization_units hr_whs
         WHERE     rti.org_id = hr_org.organization_id(+)
               AND rti.to_organization_id = hr_whs.organization_id(+)
               AND rti.source_document_code = 'RMA'
               AND (rti.processing_status_code = 'PENDING')
               AND (NVL (hr_whs.name, 'None') LIKE '%CH%' OR NVL (hr_whs.name, 'None') LIKE '%JP%' OR NVL (hr_whs.name, 'None') LIKE '%HK%' OR NVL (hr_whs.name, 'None') LIKE '%APAC%' OR NVL (hr_whs.name, 'None') LIKE '%CN%' OR NVL (hr_whs.name, 'None') LIKE '%MC%'); -- To add China con

        ---US
        SELECT COUNT (*) rec_count
          INTO l_rti_rma_us
          FROM apps.rcv_transactions_interface rti, apps.hr_all_organization_units hr_org, apps.hr_all_organization_units hr_whs
         WHERE     rti.org_id = hr_org.organization_id(+)
               AND rti.to_organization_id = hr_whs.organization_id(+)
               AND rti.source_document_code = 'RMA'
               AND (rti.processing_status_code = 'ERROR' OR rti.processing_status_code = 'COMPLETED')
               AND (NVL (hr_whs.name, 'None') LIKE '%US%');

        --US- PENDING
        SELECT COUNT (*) rec_count
          INTO l_rti_pending_us
          FROM apps.rcv_transactions_interface rti, apps.hr_all_organization_units hr_org, apps.hr_all_organization_units hr_whs
         WHERE     rti.org_id = hr_org.organization_id(+)
               AND rti.to_organization_id = hr_whs.organization_id(+)
               AND rti.source_document_code = 'RMA'
               AND (rti.processing_status_code = 'PENDING')
               AND (NVL (hr_whs.name, 'None') LIKE '%US%');

        --Europe
        SELECT COUNT (*) rec_count
          INTO l_rti_rma_eu
          FROM apps.rcv_transactions_interface rti, apps.hr_all_organization_units hr_org, apps.hr_all_organization_units hr_whs
         WHERE     rti.org_id = hr_org.organization_id(+)
               AND rti.to_organization_id = hr_whs.organization_id(+)
               AND rti.source_document_code = 'RMA'
               AND (rti.processing_status_code = 'ERROR' OR rti.processing_status_code = 'COMPLETED')
               AND (NVL (hr_whs.name, 'None') LIKE '%EU%');

        --O2C Europe Pending Records
        SELECT COUNT (*) rec_count
          INTO l_rti_pending_eu
          FROM apps.rcv_transactions_interface rti, apps.hr_all_organization_units hr_org, apps.hr_all_organization_units hr_whs
         WHERE     rti.org_id = hr_org.organization_id(+)
               AND rti.to_organization_id = hr_whs.organization_id(+)
               AND rti.source_document_code = 'RMA'
               AND (rti.processing_status_code = 'PENDING')
               AND (NVL (hr_whs.name, 'None') LIKE '%EU%');

        --O2C EDI
        --US
        SELECT COUNT (ooh.orig_sys_document_ref)
          INTO l_edi_v_us
          FROM apps.oe_order_sources oos, apps.oe_headers_iface_all ooh, apps.hz_cust_accounts hca,
               apps.hz_parties hzp, apps.hr_operating_units hou
         WHERE     oos.order_source_id = ooh.order_source_id
               AND ooh.sold_to_org_id = hca.cust_account_id
               AND hou.organization_id = ooh.org_id
               AND hca.party_id = hzp.party_id
               AND oos.name = 'EDI'
               AND NVL (hou.name, 'None') LIKE '%US%';

        --Hubsoft Wholesale - US
        SELECT COUNT (ooh.orig_sys_document_ref)
          INTO l_wh_v_us
          FROM apps.oe_order_sources oos, apps.oe_headers_iface_all ooh, apps.hz_cust_accounts hca,
               apps.hz_parties hzp, apps.hr_operating_units hou
         WHERE     oos.order_source_id = ooh.order_source_id
               AND ooh.sold_to_org_id = hca.cust_account_id
               AND hou.organization_id = ooh.org_id
               AND hca.party_id = hzp.party_id
               AND oos.name = 'Hubsoft - Wholesale'
               AND NVL (hou.name, 'None') LIKE '%US%';

        --Hubsoft - Distributor - US
        SELECT COUNT (ooh.orig_sys_document_ref)
          INTO l_wh_dist_us
          FROM apps.oe_order_sources oos, apps.oe_headers_iface_all ooh, apps.hz_cust_accounts hca,
               apps.hz_parties hzp, apps.hr_operating_units hou
         WHERE     oos.order_source_id = ooh.order_source_id
               AND ooh.sold_to_org_id = hca.cust_account_id
               AND hou.organization_id = ooh.org_id
               AND hca.party_id = hzp.party_id
               AND oos.name = 'Hubsoft - Distributor'
               AND NVL (hou.name, 'None') LIKE '%US%';

        --China Hubsoft Wholesale
        SELECT COUNT (ooh.orig_sys_document_ref)
          INTO l_wh_v_china
          FROM apps.oe_order_sources oos, apps.oe_headers_iface_all ooh, apps.hz_cust_accounts hca,
               apps.hz_parties hzp, apps.hr_operating_units hou
         WHERE     oos.order_source_id = ooh.order_source_id
               AND ooh.sold_to_org_id = hca.cust_account_id
               AND hou.organization_id = ooh.org_id
               AND hca.party_id = hzp.party_id
               AND oos.name = 'Hubsoft - Wholesale'
               AND (NVL (hou.name, 'None') LIKE '%CH%' OR NVL (hou.name, 'None') LIKE '%JP%' OR NVL (hou.name, 'None') LIKE '%HK%' OR NVL (hou.name, 'None') LIKE '%APAC%' OR NVL (hou.name, 'None') LIKE '%CN%' OR NVL (hou.name, 'None') LIKE '%MC%');

        --China Hubsoft Distributor
        SELECT COUNT (ooh.orig_sys_document_ref)
          INTO l_wh_dist_china
          FROM apps.oe_order_sources oos, apps.oe_headers_iface_all ooh, apps.hz_cust_accounts hca,
               apps.hz_parties hzp, apps.hr_operating_units hou
         WHERE     oos.order_source_id = ooh.order_source_id
               AND ooh.sold_to_org_id = hca.cust_account_id
               AND hou.organization_id = ooh.org_id
               AND hca.party_id = hzp.party_id
               AND oos.name = 'Hubsoft - Distributor'
               AND (NVL (hou.name, 'None') LIKE '%CH%' OR NVL (hou.name, 'None') LIKE '%JP%' OR NVL (hou.name, 'None') LIKE '%HK%' OR NVL (hou.name, 'None') LIKE '%APAC%' OR NVL (hou.name, 'None') LIKE '%CN%' OR NVL (hou.name, 'None') LIKE '%MC%');

        --Europe
        SELECT COUNT (ooh.orig_sys_document_ref)
          INTO l_wh_v_eu
          FROM apps.oe_order_sources oos, apps.oe_headers_iface_all ooh, apps.hz_cust_accounts hca,
               apps.hz_parties hzp, apps.hr_operating_units hou
         WHERE     oos.order_source_id = ooh.order_source_id
               AND ooh.sold_to_org_id = hca.cust_account_id
               AND hou.organization_id = ooh.org_id
               AND hca.party_id = hzp.party_id
               AND oos.name = 'Hubsoft - Wholesale'
               AND NVL (hou.name, 'None') LIKE '%EU%';

        SELECT COUNT (ooh.orig_sys_document_ref)
          INTO l_wh_dist_eu
          FROM apps.oe_order_sources oos, apps.oe_headers_iface_all ooh, apps.hz_cust_accounts hca,
               apps.hz_parties hzp, apps.hr_operating_units hou
         WHERE     oos.order_source_id = ooh.order_source_id
               AND ooh.sold_to_org_id = hca.cust_account_id
               AND hou.organization_id = ooh.org_id
               AND hca.party_id = hzp.party_id
               AND oos.name = 'Hubsoft - Distributor'
               AND NVL (hou.name, 'None') LIKE '%EU%';

        ---END O2C - Count Fetching
        ---START ::Finance Count Fetching
        -- AP Interface:
        SELECT COUNT (*)
          INTO l_ap_interface_us
          FROM ap_invoices_interface
         WHERE     status <> 'PROCESSED'
               AND INVOICE_CURRENCY_CODE IN ('USD', 'CAD');

        SELECT COUNT (*)
          INTO l_ap_interface_china
          FROM ap_invoices_interface
         WHERE     status <> 'PROCESSED'
               AND INVOICE_CURRENCY_CODE IN ('CNY', 'JPY', 'HKD',
                                             'MOP');

        SELECT COUNT (*)
          INTO l_ap_interface_eu
          FROM ap_invoices_interface
         WHERE     status <> 'PROCESSED'
               AND INVOICE_CURRENCY_CODE IN ('GBP', 'EUR');

        -------------------------------------------------------------------------------------------------------------------
        --AR Interface:
        SELECT COUNT (1)
          INTO l_ar_interface_us
          FROM apps.ra_interface_lines_all rila, gl_ledgers gl, ra_interface_errors_all rie
         WHERE     1 = 1
               AND rila.INTERFACE_LINE_ID = rie.INTERFACE_LINE_ID
               AND gl.ledger_id = rila.set_of_books_id
               AND gl.currency_code IN ('USD', 'CAD');

        SELECT COUNT (1)
          INTO l_ar_interface_china
          FROM apps.ra_interface_lines_all rila, gl_ledgers gl, ra_interface_errors_all rie
         WHERE     1 = 1
               AND rila.INTERFACE_LINE_ID = rie.INTERFACE_LINE_ID
               AND gl.ledger_id = rila.set_of_books_id
               AND gl.currency_code IN ('CNY', 'JPY', 'HKD',
                                        'MOP');

        SELECT COUNT (1)
          INTO l_ar_interface_eu
          FROM apps.ra_interface_lines_all rila, gl_ledgers gl, ra_interface_errors_all rie
         WHERE     1 = 1
               AND rila.INTERFACE_LINE_ID = rie.INTERFACE_LINE_ID
               AND gl.ledger_id = rila.set_of_books_id
               AND gl.currency_code IN ('GBP', 'EUR');

        -------------------------------------------------------------------------------------------------------------------
        --Costing:
        SELECT COUNT (*)
          INTO l_costing_us
          FROM MTL_TRANSACTIONS_INTERFACE mti, hr_organization_units hro, apps.org_organization_definitions ood,
               hr_operating_units hou, gl_ledgers gl
         WHERE     hro.organization_id = mti.organization_id
               AND hro.ORGANIZATION_ID = ood.ORGANIZATION_ID
               AND ood.OPERATING_UNIT = hou.ORGANIZATION_ID
               AND hou.SET_OF_BOOKS_ID = gl.LEDGER_ID
               AND gl.currency_code IN ('USD', 'CAD');

        SELECT COUNT (*)
          INTO l_costing_china
          FROM MTL_TRANSACTIONS_INTERFACE mti, hr_organization_units hro, apps.org_organization_definitions ood,
               hr_operating_units hou, gl_ledgers gl
         WHERE     hro.organization_id = mti.organization_id
               AND hro.ORGANIZATION_ID = ood.ORGANIZATION_ID
               AND ood.OPERATING_UNIT = hou.ORGANIZATION_ID
               AND hou.SET_OF_BOOKS_ID = gl.LEDGER_ID
               AND gl.currency_code IN ('CNY', 'JPY', 'HKD',
                                        'MOP');

        SELECT COUNT (*)
          INTO l_costing_eu
          FROM MTL_TRANSACTIONS_INTERFACE mti, hr_organization_units hro, apps.org_organization_definitions ood,
               hr_operating_units hou, gl_ledgers gl
         WHERE     hro.organization_id = mti.organization_id
               AND hro.ORGANIZATION_ID = ood.ORGANIZATION_ID
               AND ood.OPERATING_UNIT = hou.ORGANIZATION_ID
               AND hou.SET_OF_BOOKS_ID = gl.LEDGER_ID
               AND gl.currency_code IN ('GBP', 'EUR');

        ---------------------------------------------------------------------------------------------------------------------
        --Projects - Workfront:
        SELECT COUNT (*)
          INTO l_projects_workfront_us
          FROM apps.pa_transaction_interface_all pti, hr_operating_units hou, gl_ledgers gl
         WHERE     transaction_status_code <> 'P'
               AND PTI.ORG_ID = HOU.ORGANIZATION_ID
               AND HOU.SET_OF_BOOKS_ID = GL.LEDGER_ID
               AND gl.currency_code IN ('USD', 'CAD');

        SELECT COUNT (*)
          INTO l_projects_workfront_china
          FROM apps.pa_transaction_interface_all pti, hr_operating_units hou, gl_ledgers gl
         WHERE     transaction_status_code <> 'P'
               AND PTI.ORG_ID = HOU.ORGANIZATION_ID
               AND HOU.SET_OF_BOOKS_ID = GL.LEDGER_ID
               AND gl.currency_code IN ('CNY', 'JPY', 'HKD',
                                        'MOP');

        SELECT COUNT (*)
          INTO l_projects_workfront_eu
          FROM apps.pa_transaction_interface_all pti, hr_operating_units hou, gl_ledgers gl
         WHERE     transaction_status_code <> 'P'
               AND PTI.ORG_ID = HOU.ORGANIZATION_ID
               AND HOU.SET_OF_BOOKS_ID = GL.LEDGER_ID
               AND gl.currency_code IN ('GBP', 'EUR');

        -----------------------------------------------------------------------------------------------------------------------
        --Projects  AP
        l_projects_ap_us      := 0;                                -- Set to 0
        l_projects_ap_eu      := 0;
        l_projects_ap_china   := 0;

        -----------------------------------------------------------------------------------------------------------------------
        --START :: Create Accounting exceptions
        --US
        SELECT COUNT (*)
          INTO l_create_account_us
          FROM xla_events xe, xla_accounting_errors ae, xla.xla_transaction_entities xte,
               gl_ledgers led, hr_all_organization_units hro
         WHERE     ae.application_id IN (200, 222, 707)
               AND led.ledger_id = xte.ledger_id
               AND ae.event_id = xe.event_id
               AND xte.entity_id = xe.entity_id
               AND xte.ledger_id = ae.ledger_id
               AND hro.organization_id(+) = xte.security_id_int_1
               AND LED.CURRENCY_CODE IN ('USD', 'CAD');

        --CHINA
        SELECT COUNT (*)
          INTO l_create_account_china
          FROM xla_events xe, xla_accounting_errors ae, xla.xla_transaction_entities xte,
               gl_ledgers led, hr_all_organization_units hro
         WHERE     ae.application_id IN (200, 222, 707)
               AND led.ledger_id = xte.ledger_id
               AND ae.event_id = xe.event_id
               AND xte.entity_id = xe.entity_id
               AND xte.ledger_id = ae.ledger_id
               AND hro.organization_id(+) = xte.security_id_int_1
               AND LED.CURRENCY_CODE IN ('CNY', 'JPY', 'HKD',
                                         'MOP');

        --EU
        SELECT COUNT (*)
          INTO l_create_account_eu
          FROM xla_events xe, xla_accounting_errors ae, xla.xla_transaction_entities xte,
               gl_ledgers led, hr_all_organization_units hro
         WHERE     ae.application_id IN (200, 222, 707)
               AND led.ledger_id = xte.ledger_id
               AND ae.event_id = xe.event_id
               AND xte.entity_id = xe.entity_id
               AND xte.ledger_id = ae.ledger_id
               AND hro.organization_id(+) = xte.security_id_int_1
               AND LED.CURRENCY_CODE IN ('GBP', 'EUR');

        --END::Create Accounting exceptions
        --START ::Finance AP
        -- AP
        SELECT COUNT (*)
          INTO l_ap_us
          FROM xla_events xe, xla_accounting_errors ae, xla.xla_transaction_entities xte,
               gl_ledgers led, hr_all_organization_units hro
         WHERE     ae.application_id = 200
               AND led.ledger_id = xte.ledger_id
               AND ae.event_id = xe.event_id
               AND xte.entity_id = xe.entity_id
               AND xte.ledger_id = ae.ledger_id
               AND hro.organization_id(+) = xte.security_id_int_1
               AND LED.CURRENCY_CODE IN ('USD', 'CAD');

        --CHINA
        SELECT COUNT (*)
          INTO l_ap_china
          FROM xla_events xe, xla_accounting_errors ae, xla.xla_transaction_entities xte,
               gl_ledgers led, hr_all_organization_units hro
         WHERE     ae.application_id = 200
               AND led.ledger_id = xte.ledger_id
               AND ae.event_id = xe.event_id
               AND xte.entity_id = xe.entity_id
               AND xte.ledger_id = ae.ledger_id
               AND hro.organization_id(+) = xte.security_id_int_1
               AND LED.CURRENCY_CODE IN ('CNY', 'JPY', 'HKD',
                                         'MOP');

        --Europe
        SELECT COUNT (*)
          INTO l_ap_eu
          FROM xla_events xe, xla_accounting_errors ae, xla.xla_transaction_entities xte,
               gl_ledgers led, hr_all_organization_units hro
         WHERE     ae.application_id = 200
               AND led.ledger_id = xte.ledger_id
               AND ae.event_id = xe.event_id
               AND xte.entity_id = xe.entity_id
               AND xte.ledger_id = ae.ledger_id
               AND hro.organization_id(+) = xte.security_id_int_1
               AND LED.CURRENCY_CODE IN ('GBP', 'EUR');

        --END   ::Finance AP
        --START :: Finance AR
        -- US
        SELECT COUNT (*)
          INTO l_ar_us
          FROM xla_events xe, xla_accounting_errors ae, xla.xla_transaction_entities xte,
               gl_ledgers led, hr_all_organization_units hro
         WHERE     ae.application_id = 222
               AND led.ledger_id = xte.ledger_id
               AND ae.event_id = xe.event_id
               AND xte.entity_id = xe.entity_id
               AND xte.ledger_id = ae.ledger_id
               AND hro.organization_id(+) = xte.security_id_int_1
               AND LED.CURRENCY_CODE IN ('USD', 'CAD');

        --CHINA
        SELECT COUNT (*)
          INTO l_ar_china
          FROM xla_events xe, xla_accounting_errors ae, xla.xla_transaction_entities xte,
               gl_ledgers led, hr_all_organization_units hro
         WHERE     ae.application_id = 222
               AND led.ledger_id = xte.ledger_id
               AND ae.event_id = xe.event_id
               AND xte.entity_id = xe.entity_id
               AND xte.ledger_id = ae.ledger_id
               AND hro.organization_id(+) = xte.security_id_int_1
               AND LED.CURRENCY_CODE IN ('CNY', 'JPY', 'HKD',
                                         'MOP');

        --Europe
        SELECT COUNT (*)
          INTO l_ar_eu
          FROM xla_events xe, xla_accounting_errors ae, xla.xla_transaction_entities xte,
               gl_ledgers led, hr_all_organization_units hro
         WHERE     ae.application_id = 222
               AND led.ledger_id = xte.ledger_id
               AND ae.event_id = xe.event_id
               AND xte.entity_id = xe.entity_id
               AND xte.ledger_id = ae.ledger_id
               AND hro.organization_id(+) = xte.security_id_int_1
               AND LED.CURRENCY_CODE IN ('GBP', 'EUR');

        --END   :: Finance AR
        --START :: Finance Inventory
        --US
        SELECT COUNT (*)
          INTO l_inventory_us
          FROM xla_events xe, xla_accounting_errors ae, xla.xla_transaction_entities xte,
               gl_ledgers led, hr_all_organization_units hro
         WHERE     ae.application_id IN (260, 707)
               AND led.ledger_id = xte.ledger_id
               AND ae.event_id = xe.event_id
               AND xte.entity_id = xe.entity_id
               AND xte.ledger_id = ae.ledger_id
               AND hro.organization_id(+) = xte.security_id_int_1
               AND LED.CURRENCY_CODE IN ('USD', 'CAD');

        --CHINA
        SELECT COUNT (*)
          INTO l_inventory_china
          FROM xla_events xe, xla_accounting_errors ae, xla.xla_transaction_entities xte,
               gl_ledgers led, hr_all_organization_units hro
         WHERE     ae.application_id IN (260, 707)
               AND led.ledger_id = xte.ledger_id
               AND ae.event_id = xe.event_id
               AND xte.entity_id = xe.entity_id
               AND xte.ledger_id = ae.ledger_id
               AND hro.organization_id(+) = xte.security_id_int_1
               AND LED.CURRENCY_CODE IN ('CNY', 'JPY', 'HKD',
                                         'MOP');

        --Europe
        SELECT COUNT (*)
          INTO l_inventory_eu
          FROM xla_events xe, xla_accounting_errors ae, xla.xla_transaction_entities xte,
               gl_ledgers led, hr_all_organization_units hro
         WHERE     ae.application_id IN (260, 707)
               AND led.ledger_id = xte.ledger_id
               AND ae.event_id = xe.event_id
               AND xte.entity_id = xe.entity_id
               AND xte.ledger_id = ae.ledger_id
               AND hro.organization_id(+) = xte.security_id_int_1
               AND LED.CURRENCY_CODE IN ('GBP', 'EUR');

        --END   :: Finance Inventory
        --GL Interface  Subledgers exceptions:
        SELECT COUNT (*)
          INTO l_gl_interface_us
          FROM (SELECT led.name ledger_name, --  ae.encoded_msg,
                                             DECODE (ae.application_id,  '200', 'Payables',  '222', 'Receivables',  '260', 'Cash Management',  '275', 'Projects',  '707', 'Cost Management',  'Others'), xe.event_type_code,
                       DECODE (xe.event_status_code,  'I', 'INCOMPLETE',  'N', 'NO ACTION',  'U', 'UNPROCESSED'), DECODE (xe.process_status_code,  'I', 'INVALID',  'E', 'ERROR',  'D', 'DRAFT',  'U', 'UNPROCESSED',  'R', 'Related Event in Error',  'F', 'OTHERS'), xte.entity_code,
                       hro.name ORG_NAME, xte.transaction_number, xte.source_id_int_1,
                       xe.event_date, xte.entity_code
                  FROM xla_events xe, fnd_application ae, xla.xla_transaction_entities xte,
                       gl_ledgers led, hr_all_organization_units hro
                 WHERE     ae.application_id IN (200, 222, 260,
                                                 275, 707)
                       AND led.ledger_id = xte.ledger_id
                       AND ae.application_id = xe.application_id
                       AND xte.entity_id = xe.entity_id
                       -- AND xte.ledger_id = 2026
                       AND hro.organization_id(+) = xte.security_id_int_1
                       AND event_status_code IN ('I', 'U')
                       AND process_status_code IN ('U', 'D', 'E',
                                                   'R', 'I')
                       AND LED.CURRENCY_CODE IN ('USD', 'CAD')
                MINUS
                SELECT led.name ledger_name, --  ae.encoded_msg,
                                             DECODE (ae.application_id,  '200', 'Payables',  '222', 'Receivables',  '260', 'Cash Management',  '275', 'Projects',  '707', 'Cost Management',  'Others'), xe.event_type_code,
                       DECODE (xe.event_status_code,  'I', 'INCOMPLETE',  'N', 'NO ACTION',  'U', 'UNPROCESSED'), DECODE (xe.process_status_code,  'I', 'INVALID',  'E', 'ERROR',  'D', 'DRAFT',  'U', 'UNPROCESSED',  'R', 'Related Event in Error',  'F', 'OTHERS'), xte.entity_code,
                       hro.name ORG_NAME, xte.transaction_number, xte.source_id_int_1,
                       xe.event_date, xte.entity_code
                  FROM xla_events xe, fnd_application ae, xla.xla_transaction_entities xte,
                       gl_ledgers led, hr_all_organization_units hro
                 WHERE     ae.application_id IN (200, 222, 260,
                                                 275, 707)
                       AND led.ledger_id = xte.ledger_id
                       AND ae.application_id = xe.application_id
                       AND xte.entity_id = xe.entity_id
                       -- AND xte.ledger_id = 2026
                       AND hro.organization_id(+) = xte.security_id_int_1
                       AND LED.CURRENCY_CODE IN ('USD', 'CAD')
                       AND event_status_code IN ('U')
                       AND process_status_code IN ('U'));

        ----CHINA
        SELECT COUNT (*)
          INTO l_gl_interface_china
          FROM (SELECT led.name ledger_name, --  ae.encoded_msg,
                                             DECODE (ae.application_id,  '200', 'Payables',  '222', 'Receivables',  '260', 'Cash Management',  '275', 'Projects',  '707', 'Cost Management',  'Others'), xe.event_type_code,
                       DECODE (xe.event_status_code,  'I', 'INCOMPLETE',  'N', 'NO ACTION',  'U', 'UNPROCESSED'), DECODE (xe.process_status_code,  'I', 'INVALID',  'E', 'ERROR',  'D', 'DRAFT',  'U', 'UNPROCESSED',  'R', 'Related Event in Error',  'F', 'OTHERS'), xte.entity_code,
                       hro.name ORG_NAME, xte.transaction_number, xte.source_id_int_1,
                       xe.event_date, xte.entity_code
                  FROM xla_events xe, fnd_application ae, xla.xla_transaction_entities xte,
                       gl_ledgers led, hr_all_organization_units hro
                 WHERE     ae.application_id IN (200, 222, 260,
                                                 275, 707)
                       AND led.ledger_id = xte.ledger_id
                       AND ae.application_id = xe.application_id
                       AND xte.entity_id = xe.entity_id
                       -- AND xte.ledger_id = 2026
                       AND hro.organization_id(+) = xte.security_id_int_1
                       AND event_status_code IN ('I', 'U')
                       AND process_status_code IN ('U', 'D', 'E',
                                                   'R', 'I')
                       AND LED.CURRENCY_CODE IN ('CNY', 'JPY', 'HKD',
                                                 'MOP')
                MINUS
                SELECT led.name ledger_name, --  ae.encoded_msg,
                                             DECODE (ae.application_id,  '200', 'Payables',  '222', 'Receivables',  '260', 'Cash Management',  '275', 'Projects',  '707', 'Cost Management',  'Others'), xe.event_type_code,
                       DECODE (xe.event_status_code,  'I', 'INCOMPLETE',  'N', 'NO ACTION',  'U', 'UNPROCESSED'), DECODE (xe.process_status_code,  'I', 'INVALID',  'E', 'ERROR',  'D', 'DRAFT',  'U', 'UNPROCESSED',  'R', 'Related Event in Error',  'F', 'OTHERS'), xte.entity_code,
                       hro.name ORG_NAME, xte.transaction_number, xte.source_id_int_1,
                       xe.event_date, xte.entity_code
                  FROM xla_events xe, fnd_application ae, xla.xla_transaction_entities xte,
                       gl_ledgers led, hr_all_organization_units hro
                 WHERE     ae.application_id IN (200, 222, 260,
                                                 275, 707)
                       AND led.ledger_id = xte.ledger_id
                       AND ae.application_id = xe.application_id
                       AND xte.entity_id = xe.entity_id
                       -- AND xte.ledger_id = 2026
                       AND hro.organization_id(+) = xte.security_id_int_1
                       AND LED.CURRENCY_CODE IN ('CNY', 'JPY', 'HKD',
                                                 'MOP')
                       AND event_status_code IN ('U')
                       AND process_status_code IN ('U'));

        --EU
        SELECT COUNT (*)
          INTO l_gl_interface_eu
          FROM (SELECT led.name ledger_name, --  ae.encoded_msg,
                                             DECODE (ae.application_id,  '200', 'Payables',  '222', 'Receivables',  '260', 'Cash Management',  '275', 'Projects',  '707', 'Cost Management',  'Others'), xe.event_type_code,
                       DECODE (xe.event_status_code,  'I', 'INCOMPLETE',  'N', 'NO ACTION',  'U', 'UNPROCESSED'), DECODE (xe.process_status_code,  'I', 'INVALID',  'E', 'ERROR',  'D', 'DRAFT',  'U', 'UNPROCESSED',  'R', 'Related Event in Error',  'F', 'OTHERS'), xte.entity_code,
                       hro.name ORG_NAME, xte.transaction_number, xte.source_id_int_1,
                       xe.event_date, xte.entity_code
                  FROM xla_events xe, fnd_application ae, xla.xla_transaction_entities xte,
                       gl_ledgers led, hr_all_organization_units hro
                 WHERE     ae.application_id IN (200, 222, 260,
                                                 275, 707)
                       AND led.ledger_id = xte.ledger_id
                       AND ae.application_id = xe.application_id
                       AND xte.entity_id = xe.entity_id
                       -- AND xte.ledger_id = 2026
                       AND hro.organization_id(+) = xte.security_id_int_1
                       AND event_status_code IN ('I', 'U')
                       AND process_status_code IN ('U', 'D', 'E',
                                                   'R', 'I')
                       AND LED.CURRENCY_CODE IN ('GBP', 'EUR')
                MINUS
                SELECT led.name ledger_name, --  ae.encoded_msg,
                                             DECODE (ae.application_id,  '200', 'Payables',  '222', 'Receivables',  '260', 'Cash Management',  '275', 'Projects',  '707', 'Cost Management',  'Others'), xe.event_type_code,
                       DECODE (xe.event_status_code,  'I', 'INCOMPLETE',  'N', 'NO ACTION',  'U', 'UNPROCESSED'), DECODE (xe.process_status_code,  'I', 'INVALID',  'E', 'ERROR',  'D', 'DRAFT',  'U', 'UNPROCESSED',  'R', 'Related Event in Error',  'F', 'OTHERS'), xte.entity_code,
                       hro.name ORG_NAME, xte.transaction_number, xte.source_id_int_1,
                       xe.event_date, xte.entity_code
                  FROM xla_events xe, fnd_application ae, xla.xla_transaction_entities xte,
                       gl_ledgers led, hr_all_organization_units hro
                 WHERE     ae.application_id IN (200, 222, 260,
                                                 275, 707)
                       AND led.ledger_id = xte.ledger_id
                       AND ae.application_id = xe.application_id
                       AND xte.entity_id = xe.entity_id
                       -- AND xte.ledger_id = 2026
                       AND hro.organization_id(+) = xte.security_id_int_1
                       AND LED.CURRENCY_CODE IN ('GBP', 'EUR')
                       AND event_status_code IN ('U')
                       AND process_status_code IN ('U'));

        -----------------------------------------------------------------------------------------------------------------------
        --FA mass additions
        SELECT COUNT (*)
          INTO l_fa_mass_us
          FROM fa_mass_additions fma, FA_BOOK_CONTROLS fbc, gl_ledgers gl
         WHERE     posting_status <> 'POSTED'
               AND fma.BOOK_TYPE_CODE = fbc.BOOK_TYPE_CODE
               AND fbc.SET_OF_BOOKS_ID = gl.LEDGER_ID
               AND gl.CURRENCY_CODE IN ('USD', 'CAD');

        SELECT COUNT (*)
          INTO l_fa_mass_china
          FROM fa_mass_additions fma, FA_BOOK_CONTROLS fbc, gl_ledgers gl
         WHERE     posting_status <> 'POSTED'
               AND fma.BOOK_TYPE_CODE = fbc.BOOK_TYPE_CODE
               AND fbc.SET_OF_BOOKS_ID = gl.LEDGER_ID
               AND gl.CURRENCY_CODE IN ('CNY', 'JPY', 'HKD',
                                        'MOP');

        SELECT COUNT (*)
          INTO l_fa_mass_eu
          FROM fa_mass_additions fma, FA_BOOK_CONTROLS fbc, gl_ledgers gl
         WHERE     posting_status <> 'POSTED'
               AND fma.BOOK_TYPE_CODE = fbc.BOOK_TYPE_CODE
               AND fbc.SET_OF_BOOKS_ID = gl.LEDGER_ID
               AND gl.CURRENCY_CODE IN ('GBP', 'EUR');

        -----------------------------------------------------------------------------------------------------------------------
        --Lockbox:
        SELECT COUNT (*)
          INTO l_lockbox_US
          FROM Ar_payments_interface_all api, hr_operating_units hou, gl_ledgers gl
         WHERE     API.ORG_ID = HOU.ORGANIZATION_ID
               AND HOU.SET_OF_BOOKS_ID = GL.LEDGER_ID
               AND gl.currency_code IN ('USD', 'CAD');

        SELECT COUNT (*)
          INTO l_lockbox_china
          FROM Ar_payments_interface_all api, hr_operating_units hou, gl_ledgers gl
         WHERE     API.ORG_ID = HOU.ORGANIZATION_ID
               AND HOU.SET_OF_BOOKS_ID = GL.LEDGER_ID
               AND gl.currency_code IN ('CNY', 'JPY', 'HKD',
                                        'MOP');

        SELECT COUNT (*)
          INTO l_lockbox_EU
          FROM Ar_payments_interface_all api, hr_operating_units hou, gl_ledgers gl
         WHERE     API.ORG_ID = HOU.ORGANIZATION_ID
               AND HOU.SET_OF_BOOKS_ID = GL.LEDGER_ID
               AND gl.currency_code IN ('GBP', 'EUR');

          ---END   :: Finance Count Fetching
          -- RMA Receipt Queries
          SELECT COUNT (*)
            INTO l_hj_rma_receipts
            FROM apps.xxdo_ont_rma_line_stg xrl, apps.xxdo_ont_rma_hdr_stg xrh, apps.mtl_system_items_b msib,
                 apps.mtl_item_categories mic, apps.mtl_categories_b mc, apps.oe_order_headers_all ooh,
                 apps.hz_cust_accounts hca, apps.hz_parties hp, apps.fnd_user fu,
                 apps.JTF_RS_SALESREPS jrs, apps.JTF_RS_RESOURCE_EXTNS_VL jre
           WHERE     xrl.receipt_header_seq_id = xrh.receipt_header_seq_id
                 AND xrl.process_status = 'ERROR'
                 AND xrh.process_status = 'ERROR'
                 --and xrl.error_message like 'Open%'
                 AND xrl.item_number = msib.segment1
                 AND msib.organization_id = 107
                 AND msib.inventory_item_id = mic.inventory_item_id
                 AND msib.organization_id = mic.organization_id
                 AND mic.category_set_id = 1
                 AND mic.category_id = mc.category_id
                 AND xrh.rma_number = ooh.order_number
                 AND ooh.sold_to_org_id = hca.cust_account_id
                 AND hca.party_id = hp.party_id
                 AND ooh.created_by = fu.user_id
                 AND ooh.salesrep_id = jrs.salesrep_id
                 AND ooh.org_id = jrs.org_id
                 AND jrs.resource_id = jre.resource_id
        ORDER BY xrh.rma_number, xrh.receipt_header_seq_id;

        -- ASN Receipt Queries
        SELECT COUNT (*)
          INTO l_hj_asn_receipts
          FROM apps.xxdo_po_asn_receipt_head_stg head, apps.xxdo_po_asn_receipt_dtl_stg dtl
         WHERE     head.process_status = 'ERROR'
               AND dtl.process_status = 'ERROR'
               AND head.receipt_header_seq_id = dtl.receipt_header_seq_id;

        --Ship Confirm
        SELECT COUNT (*)
          INTO l_hj_ship_confirm
          FROM xxdo.xxdo_ont_ship_conf_cardtl_stg
         WHERE process_status = 'ERROR';

        --Inventory Host Transfer
        SELECT COUNT (*)
          INTO l_hj_inv_transfers
          FROM xxdo.xxdo_inv_trans_adj_dtl_stg
         WHERE process_status = 'ERROR';

        --MTL Transaction US
        SELECT NVL (SUM (alpha.row_count), 0) AS row_cnt
          INTO l_mtl_trx_int_us
          FROM (  SELECT 'INV - MTL Interface' SYSTEM, 'Sreeni/Karthik' Reported_by, 'MTL Trans. Interface' AS table_name,
                         TO_NUMBER (-1) AS org_id, TO_NUMBER (organization_id) AS warehouse_id, DECODE (ERROR_CODE, NULL, 'Pending', 'Error') AS status,
                         'Status1' AS status1, MIN (creation_date) AS min_creation_date, TRUNC (transaction_date) AS trx_date,
                         COUNT (2) AS row_count
                    FROM apps.mtl_transactions_interface
                GROUP BY organization_id, DECODE (ERROR_CODE, NULL, 'Pending', 'Error'), 'Status1',
                         TRUNC (transaction_date)) alpha,
               apps.hr_all_organization_units org_bu,
               apps.hr_all_organization_units org_io
         WHERE     org_bu.organization_id(+) = NVL (alpha.org_id, -1)
               AND org_io.organization_id(+) = alpha.warehouse_id
               AND (alpha.status = 'Error' -- OR alpha.status                 = 'Pending'
                                           OR alpha.status1 = 'Error')
               AND (NVL (org_io.name, 'None') LIKE '%US%');

        --- RMA Holds
        SELECT COUNT (*)
          INTO l_rma_holds
          FROM xxdo.xxdo_ont_rma_line_stg rl, xxdo.xxdo_ont_rma_hdr_stg rh
         WHERE     rl.receipt_header_seq_id = rh.receipt_header_seq_id
               AND rl.process_status = 'HOLD';

        --MTL Transaction Europe
        SELECT NVL (SUM (alpha.row_count), 0) AS row_cnt
          INTO l_mtl_trx_int_eu
          FROM (  SELECT 'INV - MTL Interface' SYSTEM, 'Sreeni/Karthik' Reported_by, 'MTL Trans. Interface' AS table_name,
                         TO_NUMBER (-1) AS org_id, TO_NUMBER (organization_id) AS warehouse_id, DECODE (ERROR_CODE, NULL, 'Pending', 'Error') AS status,
                         'Status1' AS status1, MIN (creation_date) AS min_creation_date, TRUNC (transaction_date) AS trx_date,
                         COUNT (2) AS row_count
                    FROM apps.mtl_transactions_interface
                GROUP BY organization_id, DECODE (ERROR_CODE, NULL, 'Pending', 'Error'), 'Status1',
                         TRUNC (transaction_date)) alpha,
               apps.hr_all_organization_units org_bu,
               apps.hr_all_organization_units org_io
         WHERE     org_bu.organization_id(+) = NVL (alpha.org_id, -1)
               AND org_io.organization_id(+) = alpha.warehouse_id
               AND (alpha.status = 'Error' --OR alpha.status                 = 'Pending'
                                           OR alpha.status1 = 'Error')
               AND (NVL (org_io.name, 'None') LIKE '%EU%');

        --MTL_Transaction CHINA
        SELECT NVL (SUM (alpha.row_count), 0) AS row_cnt
          INTO l_mtl_trx_int_china
          FROM (  SELECT 'INV - MTL Interface' SYSTEM, 'Sreeni/Karthik' Reported_by, 'MTL Trans. Interface' AS table_name,
                         TO_NUMBER (-1) AS org_id, TO_NUMBER (organization_id) AS warehouse_id, DECODE (ERROR_CODE, NULL, 'Pending', 'Error') AS status,
                         'Status1' AS status1, MIN (creation_date) AS min_creation_date, TRUNC (transaction_date) AS trx_date,
                         COUNT (2) AS row_count
                    FROM apps.mtl_transactions_interface
                GROUP BY organization_id, DECODE (ERROR_CODE, NULL, 'Pending', 'Error'), 'Status1',
                         TRUNC (transaction_date)) alpha,
               apps.hr_all_organization_units org_bu,
               apps.hr_all_organization_units org_io
         WHERE     org_bu.organization_id(+) = NVL (alpha.org_id, -1)
               AND org_io.organization_id(+) = alpha.warehouse_id
               AND (alpha.status = 'Error' --OR alpha.status                 = 'Pending'
                                           OR alpha.status1 = 'Error')
               AND (NVL (org_io.name, 'None') LIKE '%CH%' OR NVL (org_io.name, 'None') LIKE '%JP%' OR NVL (org_io.name, 'None') LIKE '%HK%' OR NVL (org_io.name, 'None') LIKE '%APAC%' OR NVL (org_io.name, 'None') LIKE '%CN%' OR NVL (org_io.name, 'None') LIKE '%MC%');

        ---High Jump Staging
        SELECT COUNT (rt.interface_transaction_id)
          INTO l_rti_rma_hj_receipts
          FROM rcv_transactions_interface rt, rcv_shipment_headers rsh, rcv_shipment_lines rsl,
               mtl_parameters mp, po_interface_errors pir
         WHERE     rt.shipment_header_id = rsh.shipment_header_id(+)
               AND rt.SHIPMENT_LINE_ID = rsl.SHIPMENT_LINE_ID(+)
               AND mp.organization_id = rt.to_organization_id
               AND pir.interface_line_id(+) = rt.interface_transaction_id
               AND rt.to_organization_id = '107'
               AND rt.source_document_code = 'RMA';

        -- START ::RMA Pending
        --Material transactions Pending Interface(US/CAD)
        SELECT NVL (SUM (alpha.row_count), 0)
          INTO l_mtl_tx_pending_us
          FROM (  SELECT 'INV - MTL PEND Interface' SYSTEM, 'Sreeni/Karthik' Reported_by, 'MTL Trans. Temp' AS table_name,
                         TO_NUMBER (NULL) AS org_id, organization_id AS warehouse_id, DECODE (PROCESS_FLAG, 'E', 'Error', PROCESS_FLAG) AS status,
                         DECODE (TRANSACTION_STATUS, 2, 'Y', 'Error') AS status1, MIN (creation_date) AS min_creation_date, TRUNC (transaction_date) AS trx_date,
                         COUNT (1) AS row_count
                    FROM apps.mtl_material_transactions_temp
                   WHERE (process_flag = 'E' OR NVL (TRANSACTION_STATUS, 0) <> 2)
                GROUP BY organization_id, DECODE (PROCESS_FLAG, 'E', 'Error', PROCESS_FLAG), DECODE (TRANSACTION_STATUS, 2, 'Y', 'Error'),
                         TRUNC (transaction_date)) alpha,
               apps.hr_all_organization_units org_bu,
               apps.hr_all_organization_units org_io
         WHERE     org_bu.organization_id(+) = NVL (alpha.org_id, -1)
               AND org_io.organization_id(+) = alpha.warehouse_id
               AND (                --alpha.status               = 'Error'  OR
                    alpha.status = 'Pending' --OR alpha.status1                = 'Error'
                                            )
               AND (NVL (org_io.name, 'None') LIKE '%US%');

        --Material transactions Pending Interface(CNY/JPY/HKD/MOP)
        SELECT NVL (SUM (alpha.row_count), 0) AS row_cnt
          INTO l_mtl_tx_pending_china
          FROM (  SELECT 'INV - MTL PEND Interface' SYSTEM, 'Sreeni/Karthik' Reported_by, 'MTL Trans. Temp' AS table_name,
                         TO_NUMBER (NULL) AS org_id, organization_id AS warehouse_id, DECODE (PROCESS_FLAG, 'E', 'Error', PROCESS_FLAG) AS status,
                         DECODE (TRANSACTION_STATUS, 2, 'Y', 'Error') AS status1, MIN (creation_date) AS min_creation_date, TRUNC (transaction_date) AS trx_date,
                         COUNT (1) AS row_count
                    FROM apps.mtl_material_transactions_temp
                   WHERE (process_flag = 'E' OR NVL (TRANSACTION_STATUS, 0) <> 2)
                GROUP BY organization_id, DECODE (PROCESS_FLAG, 'E', 'Error', PROCESS_FLAG), DECODE (TRANSACTION_STATUS, 2, 'Y', 'Error'),
                         TRUNC (transaction_date)) alpha,
               apps.hr_all_organization_units org_bu,
               apps.hr_all_organization_units org_io
         WHERE     org_bu.organization_id(+) = NVL (alpha.org_id, -1)
               AND org_io.organization_id(+) = alpha.warehouse_id
               AND (                 --alpha.status               = 'Error' OR
                    alpha.status = 'Pending' --OR alpha.status1                = 'Error'
                                            )
               AND (NVL (org_io.name, 'None') LIKE '%CH%' OR NVL (org_io.name, 'None') LIKE '%JP%' OR NVL (org_io.name, 'None') LIKE '%HK%' OR NVL (org_io.name, 'None') LIKE '%APAC%' OR NVL (org_io.name, 'None') LIKE '%CN%' OR NVL (org_io.name, 'None') LIKE '%MC%');

        --Material transactions Pending Interface(GBP/EUR)
        SELECT NVL (SUM (alpha.row_count), 0) AS row_cnt
          INTO l_mtl_tx_pending_eu
          FROM (  SELECT 'INV - MTL PEND Interface' SYSTEM, 'Sreeni/Karthik' Reported_by, 'MTL Trans. Temp' AS table_name,
                         TO_NUMBER (NULL) AS org_id, organization_id AS warehouse_id, DECODE (PROCESS_FLAG, 'E', 'Error', PROCESS_FLAG) AS status,
                         DECODE (TRANSACTION_STATUS, 2, 'Y', 'Error') AS status1, MIN (creation_date) AS min_creation_date, TRUNC (transaction_date) AS trx_date,
                         COUNT (1) AS row_count
                    FROM apps.mtl_material_transactions_temp
                   WHERE (process_flag = 'E' OR NVL (TRANSACTION_STATUS, 0) <> 2)
                GROUP BY organization_id, DECODE (PROCESS_FLAG, 'E', 'Error', PROCESS_FLAG), DECODE (TRANSACTION_STATUS, 2, 'Y', 'Error'),
                         TRUNC (transaction_date)) alpha,
               apps.hr_all_organization_units org_bu,
               apps.hr_all_organization_units org_io
         WHERE     org_bu.organization_id(+) = NVL (alpha.org_id, -1)
               AND org_io.organization_id(+) = alpha.warehouse_id
               AND (                 --alpha.status               = 'Error' OR
                    alpha.status = 'Pending' -- OR alpha.status1                = 'Error'
                                            )
               AND (NVL (org_io.name, 'None') LIKE '%EU%');

        --Deliveries not interfaced(Interface trip stop)(GBP/EUR)
        SELECT NVL (SUM (alpha.row_count), 0) AS row_cnt
          INTO l_delv_not_int_pen_us
          FROM (  SELECT 'WSH - DELIVERY' SYSTEM, 'Sreeni/Karthik' Reported_by, 'WSH Not Interfaced' AS table_name,
                         ooha.org_id AS org_id, wnd.organization_id AS warehouse_id, 'Error' AS status,
                         'status1' AS status1, MIN (wts.last_update_date) AS min_creation_date, TRUNC (wts.creation_date) trx_date,
                         COUNT (DISTINCT wnd.delivery_id) AS row_count
                    FROM apps.oe_order_headers_all ooha, apps.wsh_delivery_details wdd, apps.wsh_delivery_assignments wda,
                         apps.wsh_new_deliveries wnd, apps.wsh_delivery_legs wdl, apps.wsh_trip_stops wts
                   WHERE     wts.pending_interface_flag = 'Y'
                         AND wdl.pick_up_stop_id = wts.stop_id
                         AND wnd.delivery_id = wdl.delivery_id
                         AND wnd.initial_pickup_location_id =
                             wts.stop_location_id
                         AND wda.delivery_id = wnd.delivery_id
                         AND wdd.delivery_detail_id = wda.delivery_detail_id
                         AND wdd.source_code = 'OE'
                         AND ooha.header_id = wdd.source_header_id
                GROUP BY ooha.org_id, wnd.organization_id, 'Status1',
                         TRUNC (wts.creation_date)) alpha,
               apps.hr_all_organization_units org_bu,
               apps.hr_all_organization_units org_io
         WHERE     org_bu.organization_id(+) = NVL (alpha.org_id, -1)
               AND org_io.organization_id(+) = alpha.warehouse_id
               AND (                 --alpha.status               = 'Error' OR
                    alpha.status = 'Pending'                               --1
                                            --OR alpha.status1                = 'Error'
                                            )
               AND (NVL (org_io.name, 'None') LIKE '%EU%');

        --Deliveries not interfaced(Interface trip stop)(US/CAD)
        SELECT NVL (SUM (alpha.row_count), 0) AS row_cnt
          INTO l_delv_not_int_us
          FROM (  SELECT 'WSH - DELIVERY' SYSTEM, 'Sreeni/Karthik' Reported_by, 'WSH Not Interfaced' AS table_name,
                         ooha.org_id AS org_id, wnd.organization_id AS warehouse_id, 'Error' AS status,
                         'status1' AS status1, MIN (wts.last_update_date) AS min_creation_date, TRUNC (wts.creation_date) trx_date,
                         COUNT (DISTINCT wnd.delivery_id) AS row_count
                    FROM apps.oe_order_headers_all ooha, apps.wsh_delivery_details wdd, apps.wsh_delivery_assignments wda,
                         apps.wsh_new_deliveries wnd, apps.wsh_delivery_legs wdl, apps.wsh_trip_stops wts
                   WHERE     wts.pending_interface_flag = 'Y'
                         AND wdl.pick_up_stop_id = wts.stop_id
                         AND wnd.delivery_id = wdl.delivery_id
                         AND wnd.initial_pickup_location_id =
                             wts.stop_location_id
                         AND wda.delivery_id = wnd.delivery_id
                         AND wdd.delivery_detail_id = wda.delivery_detail_id
                         AND wdd.source_code = 'OE'
                         AND ooha.header_id = wdd.source_header_id
                GROUP BY ooha.org_id, wnd.organization_id, 'Status1',
                         TRUNC (wts.creation_date)) alpha,
               apps.hr_all_organization_units org_bu,
               apps.hr_all_organization_units org_io
         WHERE     org_bu.organization_id(+) = NVL (alpha.org_id, -1)
               AND org_io.organization_id(+) = alpha.warehouse_id
               AND (alpha.status = 'Error' OR     --  alpha.status = 'Pending'
                                              alpha.status1 = 'Error')
               AND (NVL (org_io.name, 'None') LIKE '%US%');

        --Deliveries not interfaced(Interface trip stop)(CNY/JPY/HKD/MOP)
        SELECT NVL (SUM (alpha.row_count), 0) AS row_cnt
          INTO l_delv_not_int_china
          FROM (  SELECT 'WSH - DELIVERY' SYSTEM, 'Sreeni/Karthik' Reported_by, 'WSH Not Interfaced' AS table_name,
                         ooha.org_id AS org_id, wnd.organization_id AS warehouse_id, 'Error' AS status,
                         'status1' AS status1, MIN (wts.last_update_date) AS min_creation_date, TRUNC (wts.creation_date) trx_date,
                         COUNT (DISTINCT wnd.delivery_id) AS row_count
                    FROM apps.oe_order_headers_all ooha, apps.wsh_delivery_details wdd, apps.wsh_delivery_assignments wda,
                         apps.wsh_new_deliveries wnd, apps.wsh_delivery_legs wdl, apps.wsh_trip_stops wts
                   WHERE     wts.pending_interface_flag = 'Y'
                         AND wdl.pick_up_stop_id = wts.stop_id
                         AND wnd.delivery_id = wdl.delivery_id
                         AND wnd.initial_pickup_location_id =
                             wts.stop_location_id
                         AND wda.delivery_id = wnd.delivery_id
                         AND wdd.delivery_detail_id = wda.delivery_detail_id
                         AND wdd.source_code = 'OE'
                         AND ooha.header_id = wdd.source_header_id
                GROUP BY ooha.org_id, wnd.organization_id, 'Status1',
                         TRUNC (wts.creation_date)) alpha,
               apps.hr_all_organization_units org_bu,
               apps.hr_all_organization_units org_io
         WHERE     org_bu.organization_id(+) = NVL (alpha.org_id, -1)
               AND org_io.organization_id(+) = alpha.warehouse_id
               AND (alpha.status = 'Error'        --  alpha.status = 'Pending'
                                           OR alpha.status1 = 'Error')
               AND (NVL (org_io.name, 'None') LIKE '%CH%' OR NVL (org_io.name, 'None') LIKE '%JP%' OR NVL (org_io.name, 'None') LIKE '%HK%' OR NVL (org_io.name, 'None') LIKE '%APAC%' OR NVL (org_io.name, 'None') LIKE '%CN%' OR NVL (org_io.name, 'None') LIKE '%MC%');

        SELECT NVL (SUM (alpha.row_count), 0) AS row_cnt
          INTO l_delv_not_int_eu
          FROM (  SELECT 'WSH - DELIVERY' SYSTEM, 'Sreeni/Karthik' Reported_by, 'WSH Not Interfaced' AS table_name,
                         ooha.org_id AS org_id, wnd.organization_id AS warehouse_id, 'Error' AS status,
                         'status1' AS status1, MIN (wts.last_update_date) AS min_creation_date, TRUNC (wts.creation_date) trx_date,
                         COUNT (DISTINCT wnd.delivery_id) AS row_count
                    FROM apps.oe_order_headers_all ooha, apps.wsh_delivery_details wdd, apps.wsh_delivery_assignments wda,
                         apps.wsh_new_deliveries wnd, apps.wsh_delivery_legs wdl, apps.wsh_trip_stops wts
                   WHERE     wts.pending_interface_flag = 'Y'
                         AND wdl.pick_up_stop_id = wts.stop_id
                         AND wnd.delivery_id = wdl.delivery_id
                         AND wnd.initial_pickup_location_id =
                             wts.stop_location_id
                         AND wda.delivery_id = wnd.delivery_id
                         AND wdd.delivery_detail_id = wda.delivery_detail_id
                         AND wdd.source_code = 'OE'
                         AND ooha.header_id = wdd.source_header_id
                GROUP BY ooha.org_id, wnd.organization_id, 'Status1',
                         TRUNC (wts.creation_date)) alpha,
               apps.hr_all_organization_units org_bu,
               apps.hr_all_organization_units org_io
         WHERE     org_bu.organization_id(+) = NVL (alpha.org_id, -1)
               AND org_io.organization_id(+) = alpha.warehouse_id
               AND (alpha.status = 'Error'         -- alpha.status = 'Pending'
                                           OR alpha.status1 = 'Error')
               AND (NVL (org_io.name, 'None') LIKE '%EU%');

        SELECT NVL (SUM (alpha.row_count), 0) AS row_cnt
          INTO l_del_not_int_china
          FROM (  SELECT 'WSH - DELIVERY' SYSTEM, 'Sreeni/Karthik' Reported_by, 'WSH Not Interfaced' AS table_name,
                         ooha.org_id AS org_id, wnd.organization_id AS warehouse_id, 'Error' AS status,
                         'status1' AS status1, MIN (wts.last_update_date) AS min_creation_date, TRUNC (wts.creation_date) trx_date,
                         COUNT (DISTINCT wnd.delivery_id) AS row_count
                    FROM apps.oe_order_headers_all ooha, apps.wsh_delivery_details wdd, apps.wsh_delivery_assignments wda,
                         apps.wsh_new_deliveries wnd, apps.wsh_delivery_legs wdl, apps.wsh_trip_stops wts
                   WHERE     wts.pending_interface_flag = 'Y'
                         AND wdl.pick_up_stop_id = wts.stop_id
                         AND wnd.delivery_id = wdl.delivery_id
                         AND wnd.initial_pickup_location_id =
                             wts.stop_location_id
                         AND wda.delivery_id = wnd.delivery_id
                         AND wdd.delivery_detail_id = wda.delivery_detail_id
                         AND wdd.source_code = 'OE'
                         AND ooha.header_id = wdd.source_header_id
                GROUP BY ooha.org_id, wnd.organization_id, 'Status1',
                         TRUNC (wts.creation_date)) alpha,
               apps.hr_all_organization_units org_bu,
               apps.hr_all_organization_units org_io
         WHERE     org_bu.organization_id(+) = NVL (alpha.org_id, -1)
               AND org_io.organization_id(+) = alpha.warehouse_id
               AND (               --alpha.status               = 'Error'   OR
                    alpha.status = 'Pending' -- OR alpha.status1                = 'Error'
                                            )
               AND (NVL (org_io.name, 'None') LIKE '%CH%' OR NVL (org_io.name, 'None') LIKE '%JP%' OR NVL (org_io.name, 'None') LIKE '%HK%' OR NVL (org_io.name, 'None') LIKE '%APAC%' OR NVL (org_io.name, 'None') LIKE '%CN%' OR NVL (org_io.name, 'None') LIKE '%MC%');

        SELECT NVL (SUM (alpha.row_count), 0) AS row_cnt
          INTO l_del_not_int_eu
          FROM (  SELECT 'WSH - DELIVERY' SYSTEM, 'Sreeni/Karthik' Reported_by, 'WSH Not Interfaced' AS table_name,
                         ooha.org_id AS org_id, wnd.organization_id AS warehouse_id, 'Error' AS status,
                         'status1' AS status1, MIN (wts.last_update_date) AS min_creation_date, TRUNC (wts.creation_date) trx_date,
                         COUNT (DISTINCT wnd.delivery_id) AS row_count
                    FROM apps.oe_order_headers_all ooha, apps.wsh_delivery_details wdd, apps.wsh_delivery_assignments wda,
                         apps.wsh_new_deliveries wnd, apps.wsh_delivery_legs wdl, apps.wsh_trip_stops wts
                   WHERE     wts.pending_interface_flag = 'Y'
                         AND wdl.pick_up_stop_id = wts.stop_id
                         AND wnd.delivery_id = wdl.delivery_id
                         AND wnd.initial_pickup_location_id =
                             wts.stop_location_id
                         AND wda.delivery_id = wnd.delivery_id
                         AND wdd.delivery_detail_id = wda.delivery_detail_id
                         AND wdd.source_code = 'OE'
                         AND ooha.header_id = wdd.source_header_id
                GROUP BY ooha.org_id, wnd.organization_id, 'Status1',
                         TRUNC (wts.creation_date)) alpha,
               apps.hr_all_organization_units org_bu,
               apps.hr_all_organization_units org_io
         WHERE     org_bu.organization_id(+) = NVL (alpha.org_id, -1)
               AND org_io.organization_id(+) = alpha.warehouse_id
               AND (               --alpha.status               = 'Error'   OR
                    alpha.status = 'Pending' -- OR alpha.status1                = 'Error'
                                            )
               AND (NVL (org_io.name, 'None')) LIKE '%EU%';

        --3PL Interface (CNY/JPY/HKD/MOP)
        SELECT NVL (SUM (alpha.row_cnt), 0) AS row_cnt
          INTO l_pl_int_china_pending
          FROM (  SELECT '3PL' SYSTEM, 'Sreeni/Karthik' Reported_by, '3PL Exceptions' || ' - ' || message_name Source,
                         '' Geography, organization_code warehouse, 'Error' status,
                         TRUNC (creation_date) trx_date, COUNT (*) row_cnt
                    FROM (  SELECT x.creation_date, x.message_name, site_id,
                                   x.record, SUBSTR (x.error_message, 1, 50) || '...' AS error_message, mp.organization_code
                              FROM xxdo.xxdo_wms_3pl_header_status_v x, apps.hr_locations_v hl, apps.mtl_parameters mp
                             WHERE     x.process_status IN ('P')
                                   AND hl.attribute1 = x.site_id
                                   AND hl.inventory_organization_id =
                                       mp.organization_id
                                   AND (organization_code LIKE '%CH%' OR organization_code LIKE '%HK%' OR organization_code LIKE '%JP%')
                          ORDER BY x.creation_date DESC)
                GROUP BY TRUNC (creation_date), message_name, organization_code
                ORDER BY source, trx_date, warehouse,
                         --org_id,
                         --warehouse_id,
                         status) alpha;

        --3PL Interface (GBP/EUR)
        SELECT NVL (SUM (alpha.row_cnt), 0) AS row_cnt
          INTO l_pl_int_eu_pending
          FROM (  SELECT '3PL' SYSTEM, 'Sreeni/Karthik' Reported_by, '3PL Exceptions' || ' - ' || message_name Source,
                         '' Geography, organization_code warehouse, 'Error' status,
                         TRUNC (creation_date) trx_date, COUNT (*) row_cnt
                    FROM (  SELECT x.creation_date, x.message_name, site_id,
                                   x.record, SUBSTR (x.error_message, 1, 50) || '...' AS error_message, mp.organization_code
                              FROM xxdo.xxdo_wms_3pl_header_status_v x, apps.hr_locations_v hl, apps.mtl_parameters mp
                             WHERE     x.process_status IN ('P')
                                   AND hl.attribute1 = x.site_id
                                   AND hl.inventory_organization_id =
                                       mp.organization_id
                                   AND (organization_code LIKE '%EU%')
                          ORDER BY x.creation_date DESC)
                GROUP BY TRUNC (creation_date), message_name, organization_code
                ORDER BY source, trx_date, warehouse,
                         --org_id,
                         --warehouse_id,
                         status) alpha;

        --3PL Interface (US/CAD)
        SELECT NVL (SUM (alpha.row_cnt), 0) AS row_cnt
          INTO l_pl_int_us_pending
          FROM (  SELECT '3PL' SYSTEM, 'Sreeni/Karthik' Reported_by, '3PL Exceptions' || ' - ' || message_name Source,
                         '' Geography, organization_code warehouse, 'Error' status,
                         TRUNC (creation_date) trx_date, COUNT (*) row_cnt
                    FROM (  SELECT x.creation_date, x.message_name, site_id,
                                   x.record, SUBSTR (x.error_message, 1, 50) || '...' AS error_message, mp.organization_code
                              FROM xxdo.xxdo_wms_3pl_header_status_v x, apps.hr_locations_v hl, apps.mtl_parameters mp
                             WHERE     x.process_status IN ('P')
                                   AND hl.attribute1 = x.site_id
                                   AND hl.inventory_organization_id =
                                       mp.organization_id
                                   AND (organization_code LIKE '%US%')
                          ORDER BY x.creation_date DESC)
                GROUP BY TRUNC (creation_date), message_name, organization_code
                ORDER BY source, trx_date, warehouse,
                         --org_id,
                         --warehouse_id,
                         status) alpha;

        --  END :: RMA Pending
        --- START ::P2P
        ---CHINA
        SELECT COUNT (1) AS row_count
          INTO l_rti_po_china
          FROM apps.rcv_transactions_interface rti, apps.org_organization_definitions ood, apps.hr_all_organization_units hou
         WHERE     processing_status_code = 'ERROR'
               AND receipt_source_code = 'VENDOR'
               AND transaction_type = 'SHIP'
               AND rti.to_organization_id(+) = ood.organization_id
               AND ood.operating_unit = hou.organization_id
               AND (NVL (hou.name, 'None') LIKE '%CH%' OR NVL (hou.name, 'None') LIKE '%JP%' OR NVL (hou.name, 'None') LIKE '%HK%' OR NVL (hou.name, 'None') LIKE '%APAC%' OR NVL (hou.name, 'None') LIKE '%CN%' OR NVL (hou.name, 'None') LIKE '%MC%');

        SELECT COUNT (1) AS row_count
          INTO l_rti_pending_int_china
          FROM apps.rcv_transactions_interface rti, apps.org_organization_definitions ood, apps.hr_all_organization_units hou
         WHERE     processing_status_code = 'PENDING'
               AND receipt_source_code = 'VENDOR'
               AND transaction_type = 'SHIP'
               AND rti.to_organization_id(+) = ood.organization_id
               AND ood.operating_unit = hou.organization_id
               AND (NVL (hou.name, 'None') LIKE '%CH%' OR NVL (hou.name, 'None') LIKE '%JP%' OR NVL (hou.name, 'None') LIKE '%HK%' OR NVL (hou.name, 'None') LIKE '%APAC%' OR NVL (hou.name, 'None') LIKE '%CN%' OR NVL (hou.name, 'None') LIKE '%MC%');

        ---- Europe
        SELECT COUNT (1) AS row_count
          INTO l_rti_po_eu
          FROM apps.rcv_transactions_interface rti, apps.org_organization_definitions ood, apps.hr_all_organization_units hou
         WHERE     processing_status_code = 'ERROR'
               AND receipt_source_code = 'VENDOR'
               AND transaction_type = 'SHIP'
               AND rti.to_organization_id(+) = ood.organization_id
               AND ood.operating_unit = hou.organization_id
               AND (NVL (hou.name, 'None') LIKE '%EU%');

        --PENDING
        SELECT COUNT (1) AS row_count
          INTO l_rti_pending_int_eu
          FROM apps.rcv_transactions_interface rti, apps.org_organization_definitions ood, apps.hr_all_organization_units hou
         WHERE     processing_status_code = 'PENDING'
               AND receipt_source_code = 'VENDOR'
               AND transaction_type = 'SHIP'
               AND rti.to_organization_id(+) = ood.organization_id
               AND ood.operating_unit = hou.organization_id
               AND (NVL (hou.name, 'None') LIKE '%EU%');

        ---- US
        SELECT COUNT (1) AS row_count
          INTO l_rti_po_us
          FROM apps.rcv_transactions_interface rti, apps.org_organization_definitions ood, apps.hr_all_organization_units hou
         WHERE     processing_status_code = 'ERROR'
               AND receipt_source_code = 'VENDOR'
               AND transaction_type = 'SHIP'
               AND rti.to_organization_id(+) = ood.organization_id
               AND ood.operating_unit = hou.organization_id
               AND (NVL (hou.name, 'None') LIKE '%US%');

        --PENDING
        SELECT COUNT (1) AS row_count
          INTO l_rti_pending_int_us
          FROM apps.rcv_transactions_interface rti, apps.org_organization_definitions ood, apps.hr_all_organization_units hou
         WHERE     processing_status_code = 'PENDING'
               AND receipt_source_code = 'VENDOR'
               AND transaction_type = 'SHIP'
               AND rti.to_organization_id(+) = ood.organization_id
               AND ood.operating_unit = hou.organization_id
               AND (NVL (hou.name, 'None') LIKE '%US%');

        --- END   ::P2P
        l_mail_body           :=
               '<html meta charset="UTF-8">
<p>
	<color="black"> Hi Team, 
</p>
<p>PFB the Interface Monitoring Dashboard Report for '
            || TO_CHAR (SYSDATE, 'DD-MON-YY')
            || '</p>

<body>
	<table style="color: black; background-color: #000000;">

		<TR bgcolor="#cc9900">

			<TH style="white-space: nowrap;">Track</th>
			<TH style="white-space: nowrap;">Type</th>
			<TH style="white-space: nowrap;">Interfaces</th>
			<TH style="white-space: nowrap;">USD/CAD</th>
			<TH style="white-space: nowrap;">CNY/JPY/HKD/MOP</th>
			<TH style="white-space: nowrap;">GBP/EUR</th>
			<TH style="white-space: nowrap;">Remarks</th>
		</tr>
		<TR>
			<td rowspan="4" bgcolor="#ffffb3">O2C</td>
			<td bgcolor="ffffb3">ERROR</td>
			<td bgcolor="#ffffb3">Order Shipped but not Invoiced</td>
			<td bgcolor="#ffffb3">'
            || l_ord_shp_not_inv_us
            || '</td>
			<td bgcolor="#ffffb3">'
            || l_ord_shp_not_inv_china
            || '</td>
			<td bgcolor="#ffffb3">'
            || l_ord_shp_not_inv_eu
            || '</td>
			<td bgcolor="#ffffb3"></td>
		</tr>

		<TR>
			<td bgcolor="ffffb3">ERROR</td>
			<td bgcolor="#ffffb3">Deliveries not interfaced(Interface trip
				stop)</td>
			<td bgcolor="#ffffb3">'
            || l_delv_not_int_us
            || '</td>
			<td bgcolor="#ffffb3">'
            || l_delv_not_int_china
            || '</td>
			<td bgcolor="#ffffb3">'
            || l_delv_not_int_eu
            || '</td>
			<td bgcolor="#ffffb3"></td>

		</tr>
		<TR>
			<td bgcolor="ffffb3">ERROR</td>
			<td bgcolor="#ffffb3">3PL China Demand consumption</td>
			<td bgcolor="#ffffb3">N/A</td>
			<td bgcolor="#ffffb3">'
            || l_threepl_china_china
            || '</td>
			<td bgcolor="#ffffb3">N/A</td>
			<td bgcolor="#ffffb3"></td>
		</tr>
		<TR>
			<td bgcolor="#ffffb3">ERROR</td>
			<td bgcolor="#ffffb3">RTI - RMA</td>
			<td bgcolor="#ffffb3">'
            || l_rti_rma_us
            || '</td>
			<td bgcolor="#ffffb3">'
            || l_rti_rma_china
            || '</td>
			<td bgcolor="#ffffb3">'
            || l_rti_rma_eu
            || '</td>
			<td bgcolor="#ffffb3"></td>

		</tr>


		<TR>
			<td rowspan="7" bgcolor="#e6fff2">WMS</td>
			<td bgcolor="#e6fff2">ERROR</td>

			<td bgcolor="#e6fff2">RTI - RMA (HJ staging table)</td>

			<td bgcolor="#e6fff2">'
            || l_rti_rma_hj_receipts
            || '</td>
			<td bgcolor="#e6fff2">N/A</td>
			<td bgcolor="#e6fff2">N/A</td>
			<td bgcolor="#e6fff2"></td>

		</tr>


		<TR>

			<td bgcolor="#e6fff2">ERROR</td>
			<td bgcolor="#e6fff2">HJ RMA Receipts</td>
			<td bgcolor="#e6fff2">'
            || l_hj_rma_receipts
            || '</td>
			<td bgcolor="#e6fff2">N/A</td>
			<td bgcolor="#e6fff2">N/A</td>
			<td bgcolor="#e6fff2"></td>

		</tr>
		<TR>
			<td bgcolor="#e6fff2">ERROR</td>
			<td bgcolor="#e6fff2">HJ ASN Receipts</td>
			<td bgcolor="#e6fff2">'
            || l_hj_asn_receipts
            || '</td>
			<td bgcolor="#e6fff2">N/A</td>
			<td bgcolor="#e6fff2">N/A</td>
			<td bgcolor="#e6fff2"></td>

		</tr>
		<TR>
			<td bgcolor="#e6fff2">ERROR</td>
			<td bgcolor="#e6fff2">HJ Ship Confirm</td>
			<td bgcolor="#e6fff2">'
            || l_hj_ship_confirm
            || '</td>
			<td bgcolor="#e6fff2">N/A</td>
			<td bgcolor="#e6fff2">N/A</td>
			<td bgcolor="#e6fff2"></td>

		</tr>
		<TR>
			<td bgcolor="#e6fff2">ERROR</td>
			<td bgcolor="#e6fff2">HJ Inv transfers</td>
			<td bgcolor="#e6fff2">'
            || l_hj_inv_transfers
            || '</td>
			<td bgcolor="#e6fff2">N/A</td>
			<td bgcolor="#e6fff2">N/A</td>
			<td bgcolor="#e6fff2"></td>

		</tr>
		<TR>
			<td bgcolor="#e6fff2">ERROR</td>
			<td bgcolor="#e6fff2">Material transactions Interface</td>
			<td bgcolor="#e6fff2">'
            || l_mtl_trx_int_us
            || '</td>
			<td bgcolor="#e6fff2">'
            || l_mtl_trx_int_china
            || '</td>
			<td bgcolor="#e6fff2">'
            || l_mtl_trx_int_eu
            || '</td>
			<td bgcolor="#e6fff2"></td>

		</tr>
		<TR>
			<td bgcolor="#e6fff2">HOLD</td>
			<td bgcolor="#e6fff2">RMA on Hold</td>
			<td bgcolor="#e6fff2">'
            || l_rma_holds
            || '</td>
			<td bgcolor="#e6fff2">N/A</td>
			<td bgcolor="#e6fff2">N/A</td>
			<td bgcolor="#e6fff2"></td>

		</tr>
		<TR>
			<td bgcolor="#ffffb3">P2P</td>
			<td bgcolor="#ffffb3">ERROR</td>
			<td bgcolor="#ffffb3">RTI-PO</td>
			<td bgcolor="#ffffb3">'
            || l_rti_po_us
            || '</td>
			<td bgcolor="#ffffb3">'
            || l_rti_po_china
            || '</td>
			<td bgcolor="#ffffb3">'
            || l_rti_po_eu
            || '</td>
			<td bgcolor="#ffffb3"></td>

		</tr>


		<TR>
			<td rowspan="12" bgcolor="#e6fff2">Finance</td>
			<td bgcolor="#e6fff2">ERROR</td>
			<td bgcolor="#e6fff2">AP Interface</td>
			<td bgcolor="#e6fff2">'
            || l_ap_Interface_us
            || '</td>
			<td bgcolor="#e6fff2">'
            || l_ap_Interface_china
            || '</td>
			<td bgcolor="#e6fff2">'
            || l_ap_Interface_eu
            || '</td>
			<td bgcolor="#e6fff2"></td>

		</tr>
		<TR>

			<td bgcolor="#e6fff2">ERROR</td>
			<td bgcolor="#e6fff2">AR Interface</td>
			<td bgcolor="#e6fff2">'
            || l_ar_Interface_us
            || '</td>
			<td bgcolor="#e6fff2">'
            || l_ar_Interface_china
            || '</td>
			<td bgcolor="#e6fff2">'
            || l_ar_Interface_eu
            || '</td>
			<td bgcolor="#e6fff2"></td>

		</tr>
		<TR>
			<td bgcolor="#e6fff2">ERROR</td>
			<td bgcolor="#e6fff2">Costing</td>
			<td bgcolor="#e6fff2">'
            || l_costing_us
            || '</td>
			<td bgcolor="#e6fff2">'
            || l_costing_china
            || '</td>
			<td bgcolor="#e6fff2">'
            || l_costing_eu
            || '</td>
			<td bgcolor="#e6fff2"></td>

		</tr>
		<TR>
			<td bgcolor="#e6fff2">ERROR</td>
			<td bgcolor="#e6fff2">Projects - Workfront</td>
			<td bgcolor="#e6fff2">'
            || l_projects_workfront_us
            || '</td>
			<td bgcolor="#e6fff2">'
            || l_projects_workfront_china
            || '</td>
			<td bgcolor="#e6fff2">'
            || l_projects_workfront_eu
            || '</td>
			<td bgcolor="#e6fff2"></td>

		</TR>
		<TR>
			<td bgcolor="#e6fff2">ERROR</td>
			<td bgcolor="#e6fff2">Projects - AP</td>
			<td bgcolor="#e6fff2">'
            || l_projects_ap_us
            || '</td>
			<td bgcolor="#e6fff2">'
            || l_projects_ap_china
            || '</td>
			<td bgcolor="#e6fff2">'
            || l_projects_ap_eu
            || '</td>
			<td bgcolor="#e6fff2"></td>

		</TR>
		<TR>
			<td bgcolor="#e6fff2">ERROR</td>
			<td bgcolor="#e6fff2">Create Accounting exceptions</td>
			<td bgcolor="#e6fff2">'
            || l_create_account_us
            || '</td>
			<td bgcolor="#e6fff2">'
            || l_create_account_china
            || '</td>
			<td bgcolor="#e6fff2">'
            || l_create_account_eu
            || '</td>
			<td bgcolor="#e6fff2"></td>

		</TR>
		<TR>
			<td bgcolor="#e6fff2">ERROR</td>
			<td bgcolor="#e6fff2">AP</td>
			<td bgcolor="#e6fff2">'
            || l_ap_us
            || '</td>
			<td bgcolor="#e6fff2">'
            || l_ap_china
            || '</td>
			<td bgcolor="#e6fff2">'
            || l_ap_eu
            || '</td>
			<td bgcolor="#e6fff2"></td>

		</TR>
		<TR>
			<td bgcolor="#e6fff2">ERROR</td>
			<td bgcolor="#e6fff2">AR</td>
			<td bgcolor="#e6fff2">'
            || l_ar_us
            || '</td>
			<td bgcolor="#e6fff2">'
            || l_ar_china
            || '</td>
			<td bgcolor="#e6fff2">'
            || l_ar_eu
            || '</td>
			<td bgcolor="#e6fff2"></td>

		</TR>
		<TR>
			<td bgcolor="#e6fff2">ERROR</td>
			<td bgcolor="#e6fff2">Inventory</td>
			<td bgcolor="#e6fff2">'
            || l_inventory_us
            || '</td>
			<td bgcolor="#e6fff2">'
            || l_inventory_china
            || '</td>
			<td bgcolor="#e6fff2">'
            || l_inventory_eu
            || '</td>
			<td bgcolor="#e6fff2"></td>

		</TR>
		<TR>
			<td bgcolor="#e6fff2">ERROR</td>
			<td bgcolor="#e6fff2">GL Interface Subledgers exceptions</td>
			<td bgcolor="#e6fff2">'
            || l_gl_interface_us
            || '</td>
			<td bgcolor="#e6fff2">'
            || l_gl_interface_china
            || '</td>
			<td bgcolor="#e6fff2">'
            || l_gl_interface_eu
            || '</td>
			<td bgcolor="#e6fff2"></td>

		</TR>
		<TR>
			<td bgcolor="#e6fff2">ERROR</td>
			<td bgcolor="#e6fff2">FA mass additions</td>
			<td bgcolor="#e6fff2">'
            || l_fa_mass_us
            || '</td>
			<td bgcolor="#e6fff2">'
            || l_fa_mass_china
            || '</td>
			<td bgcolor="#e6fff2">'
            || l_fa_mass_eu
            || '</td>
			<td bgcolor="#e6fff2"></td>

		</TR>
		<TR>
			<td bgcolor="#e6fff2">ERROR</td>
			<td bgcolor="#e6fff2">Lockbox</td>
			<td bgcolor="#e6fff2">'
            || l_lockbox_us
            || '</td>
			<td bgcolor="#e6fff2">'
            || l_lockbox_china
            || '</td>
			<td bgcolor="#e6fff2">'
            || l_lockbox_eu
            || '</td>
			<td bgcolor="#e6fff2"></td>

		</TR>
		<TR>
			<td rowspan="2" bgcolor="#ffffb3">O2C</td>
			<td bgcolor="#ffffb3">PENDING</td>
			<td bgcolor="#ffffb3">Order imports pending</td>
			<td bgcolor="#ffffb3">EDI : '
            || l_edi_v_us
            || '</br> Hubsoft -
				Wholesale :'
            || l_wh_v_us
            || '</br> Hubsoft - Distributor:'
            || l_wh_dist_us
            || '
			</td>
			<td bgcolor="#ffffb3">Hubsoft - Wholesale:'
            || l_wh_v_china
            || '</br>
				Hubsoft - Distributor:'
            || l_wh_dist_china
            || '
			</td>
			<td bgcolor="#ffffb3">Hubsoft - Wholesale:'
            || l_wh_v_eu
            || '</br>
				Hubsoft - Distributor:'
            || l_wh_dist_eu
            || '
			</td>
			<td bgcolor="#ffffb3"></td>

		</TR>
		<TR>
			<td bgcolor="#ffffb3">PENDING</td>
			<td bgcolor="#ffffb3">RTI Pending Interface(RMA)</td>
			<td bgcolor="#ffffb3">'
            || l_rti_pending_us
            || '</td>
			<td bgcolor="#ffffb3">'
            || l_rti_pending_china
            || '</td>
			<td bgcolor="#ffffb3">'
            || l_rti_pending_eu
            || '</td>
			<td bgcolor="#ffffb3"></td>

		</TR>
		<TR>
			<td rowspan="3" bgcolor="#e6fff2">WMS</td>
			<td bgcolor="#e6fff2">PENDING</td>
			<td bgcolor="#e6fff2">Material transactions Pending Interface</td>
			<td bgcolor="#e6fff2">'
            || l_mtl_tx_pending_us
            || '</td>
			<td bgcolor="#e6fff2">'
            || l_mtl_tx_pending_china
            || '</td>
			<td bgcolor="#e6fff2">'
            || l_mtl_tx_pending_eu
            || '</td>
			<td bgcolor="#e6fff2"></td>

		</TR>
		<TR>
			<td bgcolor="#e6fff2">PENDING</td>
			<td bgcolor="#e6fff2">Deliveries not intefaced(Interface trip
				stop)</td>
			<td bgcolor="#e6fff2">'
            || l_delv_not_int_pen_us
            || '</td>
			<td bgcolor="#e6fff2">'
            || l_del_not_int_china
            || '</td>
			<td bgcolor="#e6fff2">'
            || l_del_not_int_eu
            || '</td>
			<td bgcolor="#e6fff2"></td>

		</TR>
		<TR>
			<td bgcolor="#e6fff2">PENDING</td>
			<td bgcolor="#e6fff2">3PL Interface</td>
			<td bgcolor="#e6fff2">'
            || l_pl_int_us_pending
            || '</td>
			<td bgcolor="#e6fff2">'
            || l_pl_int_china_pending
            || '</td>
			<td bgcolor="#e6fff2">'
            || l_pl_int_eu_pending
            || '</td>
			<td bgcolor="#e6fff2"></td>

		</TR>

		<TR>
			<td bgcolor="#ffffb3">P2P</td>
			<td bgcolor="#ffffb3">PENDING</td>
			<td bgcolor="#ffffb3">RTI Pending Interface(PO)</td>
			<td bgcolor="#ffffb3">'
            || l_rti_pending_int_us
            || '</td>
			<td bgcolor="#ffffb3">'
            || l_rti_pending_int_china
            || '</td>
			<td bgcolor="#ffffb3">'
            || l_rti_pending_int_eu
            || '</td>
			<td bgcolor="#ffffb3"></td>

		</TR>

	</table>

</body>

<body>

</body>
<p>****End of the Report ***</p>
<body>

	Thanks and Regards,
	<br> Deckers Support Team
</body>
<body>
	<br>Note :: This is a Auto Generated mail. Please do not reply
</body>
</p>
</html>';

        --Get To Email IDs

        FOR lrec_subscriber IN lcur_subscriber
        LOOP
            p_i_to_email   :=
                p_i_to_email || ',' || lrec_subscriber.email_address;
        END LOOP;

        p_i_to_email          := SUBSTR (p_i_to_email, 2);

        l_mail_server         :=
            NVL (fnd_profile.VALUE ('FND_SMTP_HOST'), 'mail.deckers.com');
        send_mail (
            p_i_from_email    => p_i_from_emailid,
            p_i_to_email      => p_i_to_email,
            p_i_mail_format   => 'HTML',
            p_i_mail_server   => l_mail_server,
            p_i_subject       =>
                   'Interface Monitoring Report '
                || TO_DATE (SYSDATE, 'DD-MON-YYYY'),
            p_i_mail_body     => l_mail_body,
            p_o_status        => l_return_status,
            p_o_error_msg     => l_error_msg);
        fnd_file.put_line (
            fnd_file.LOG,
               ' After sending email to - '
            || p_i_to_email
            || ' : Return Status - '
            || l_return_status
            || ' :l_error_msg -'
            || l_error_msg);
    EXCEPTION
        WHEN OTHERS
        THEN
            v_error   :=
                SUBSTR (
                    'Error ::' || SQLERRM || '  ::Backtace :' || DBMS_UTILITY.format_error_backtrace,
                    1,
                    2000);
            fnd_file.put_line (
                fnd_file.LOG,
                   ' Error In XXDO_INTERFACE_MONTORING_PKG.create_interface_dashboard - '
                || v_error);
    END create_interface_dashboard;
END XXDO_INTERFACE_MONITORING_PKG;
/
