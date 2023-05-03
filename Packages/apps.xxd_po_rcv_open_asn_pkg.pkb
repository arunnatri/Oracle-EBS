--
-- XXD_PO_RCV_OPEN_ASN_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:35 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_PO_RCV_OPEN_ASN_PKG"
IS
    --  ################################################################################################
    --  Package         : XXD_PO_RCV_OPEN_ASN_PKG.pkb
    --  System          : EBS
    --  Change          : CCR0008085
    --  Reference       : Enhancement Request Bug 18145354 -Doc ID 2213404.1
    --      (Unable To Update Expected Receipt Date for ASN thru Receiving Open Interface)
    --  Schema          : APPS
    --  Purpose         : Package is used for WebADI to Mass Update ASN Dates
    --  Change History
    --  --------------
    --  Date            Name                Version#      Comments
    --  ----------      --------------      --------      ---------------------
    --  21-Apr-2020    Aravind Kannuri     1.0           Initial Version
    --
    --  ################################################################################################

    gv_package_name   CONSTANT VARCHAR2 (30) := 'XXD_PO_RCV_OPEN_ASN_PKG';
    gn_user_id        CONSTANT NUMBER := fnd_global.user_id;
    gn_login_id       CONSTANT NUMBER := fnd_global.login_id;
    gn_org_id         CONSTANT NUMBER := fnd_profile.VALUE ('ORG_ID');
    gn_resp_id        CONSTANT NUMBER := fnd_global.resp_id;
    gn_resp_appl_id   CONSTANT NUMBER := fnd_global.resp_appl_id;
    gn_request_id     CONSTANT NUMBER := fnd_global.conc_request_id;


    --Procedure to Update ASN Expected Receipt Dates
    PROCEDURE update_asn_dates (p_ship_to_org_id NUMBER, p_shipment_header_id NUMBER, p_new_exp_receipt_date DATE
                                , p_seq_id NUMBER, px_return_status OUT VARCHAR2, px_error_msg OUT VARCHAR2)
    IS
        --Variables Declaration
        ln_seq_id       NUMBER := NULL;
        lv_err_msg      VARCHAR2 (2000) := NULL;
        lv_ret_status   VARCHAR2 (200) := 'S';
        lx_err_msg      VARCHAR2 (2000) := NULL;
        lx_ret_status   VARCHAR2 (200) := 'S';
    BEGIN
        --Direct Table Update(NO API available\Iface wont support to update Expected Receipt Dates)
        --Refer to Oracle Note ID:
        BEGIN
            UPDATE rcv_shipment_headers
               SET expected_receipt_date = p_new_exp_receipt_date, last_update_date = SYSDATE, last_updated_by = gn_user_id
             WHERE shipment_header_id = p_shipment_header_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lx_ret_status   := gv_ret_error;
                lx_err_msg      :=
                    'Expected Receipt Date Update Failed in RCV_SHIPMENT_HEADERS. ';
        END;

        BEGIN
            --Then update mtl_supply
            UPDATE mtl_supply
               SET receipt_date = p_new_exp_receipt_date, change_flag = 'Y', last_update_date = SYSDATE,
                   last_updated_by = gn_user_id
             WHERE     shipment_header_id = p_shipment_header_id
                   AND supply_type_code = 'SHIPMENT'
                   AND to_organization_id = p_ship_to_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lx_ret_status   := gv_ret_error;
                lx_err_msg      :=
                    'Receipt Date Update Failed in MTL_SUPPLY.  ';
        END;

        --        COMMIT;

        --Update Staging Table with API Process Status
        IF NVL (lx_ret_status, gv_ret_success) = gv_ret_success
        THEN
            BEGIN
                UPDATE xxdo.xxd_po_rcv_mass_upd_asn_t stg
                   SET status = gv_ret_success, last_update_date = SYSDATE, last_updated_by = gn_user_id
                 WHERE 1 = 1 AND stg.seq_id = p_seq_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lx_err_msg   :=
                           lx_err_msg
                        || SUBSTR (
                                  'Failed to update staging status with SUCCESS :'
                               || SQLERRM,
                               1,
                               2000);
            END;
        ELSE
            BEGIN
                UPDATE xxdo.xxd_po_rcv_mass_upd_asn_t stg
                   SET status = gv_ret_error, error_message = lx_err_msg, last_update_date = SYSDATE,
                       last_updated_by = gn_user_id
                 WHERE 1 = 1 AND stg.seq_id = p_seq_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lx_err_msg   :=
                           lx_err_msg
                        || SUBSTR (
                                  'Failed to update staging status with ERROR :'
                               || SQLERRM,
                               1,
                               2000);
            END;
        END IF;

        IF lx_ret_status = gv_ret_success
        THEN
            px_return_status   := SUBSTR (lx_ret_status, 1, 255);
            px_error_msg       := NULL;
        ELSE
            px_return_status   := gv_ret_error;
            px_error_msg       := SUBSTR (lx_err_msg, 1, 255);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            px_error_msg       :=
                   lx_err_msg
                || 'When Others Exception in UPDATE_ASN_DATES Procedure: '
                || SQLERRM;
            px_return_status   := gv_ret_error;
    END update_asn_dates;

    --Upload Procedure called by WebADI - MAIN
    PROCEDURE upload_proc (p_brand VARCHAR2, p_ship_to_org_code VARCHAR2, p_invoice_num VARCHAR2, p_container_num VARCHAR2, p_asn_number VARCHAR2, p_exp_receipt_date VARCHAR2, p_new_exp_receipt_date VARCHAR2, p_attribute_num1 NUMBER DEFAULT NULL, p_attribute_num2 NUMBER DEFAULT NULL, p_attribute_num3 NUMBER DEFAULT NULL, p_attribute_num4 NUMBER DEFAULT NULL, p_attribute_num5 NUMBER DEFAULT NULL, p_attribute_chr1 VARCHAR2 DEFAULT NULL, p_attribute_chr2 VARCHAR2 DEFAULT NULL, p_attribute_chr3 VARCHAR2 DEFAULT NULL, p_attribute_chr4 VARCHAR2 DEFAULT NULL, p_attribute_chr5 VARCHAR2 DEFAULT NULL, p_attribute_date1 DATE DEFAULT NULL
                           , p_attribute_date2 DATE DEFAULT NULL)
    IS
        lv_opr_mode                VARCHAR2 (30) := 'UPDATE';
        ln_seq_stg_id              NUMBER := 0;
        ln_ship_to_org_id          mtl_parameters.organization_id%TYPE := NULL;
        ln_shipment_hdr_id         rcv_shipment_headers.shipment_header_id%TYPE
                                       := NULL;

        lv_asn_number              rcv_shipment_headers.shipment_num%TYPE := NULL;
        lv_ship_to_org_code        mtl_parameters.organization_code%TYPE := NULL;
        ld_expected_receipt_date   rcv_shipment_headers.expected_receipt_date%TYPE
            := NULL;
        lv_invoice_num             rcv_shipment_headers.packing_slip%TYPE
                                       := NULL;
        lv_container_num           rcv_shipment_lines.container_num%TYPE
                                       := NULL;
        lv_brand                   VARCHAR2 (30) := NULL;
        lv_receipt_source_code     rcv_shipment_headers.receipt_source_code%TYPE
            := NULL;
        lv_vendor_name             ap_suppliers.vendor_name%TYPE := NULL;
        lv_vendor_site_code        ap_supplier_sites_all.vendor_site_code%TYPE
            := NULL;
        ln_source_org_id           mtl_parameters.organization_id%TYPE
                                       := NULL;
        ln_vendor_id               ap_suppliers.vendor_id%TYPE := NULL;
        ln_vendor_site_id          ap_supplier_sites_all.vendor_site_id%TYPE
                                       := NULL;
        lv_resp_sufix              fnd_responsibility.responsibility_key%TYPE
                                       := NULL;
        ln_asn_valid               NUMBER := 0;

        lv_error_message           VARCHAR2 (4000) := NULL;
        lv_upload_status           VARCHAR2 (1) := 'N';
        lv_return_status           VARCHAR2 (1) := NULL;
        lv_errbuf                  VARCHAR2 (4000) := NULL;
        lv_ret_code                NUMBER := 0;
        le_webadi_exception        EXCEPTION;
        ld_new_exp_rcpt_dt         DATE := NULL;
        lx_asn_upd_sts             VARCHAR2 (1) := NULL;
        lx_asn_upd_msg             VARCHAR2 (2000) := NULL;
    BEGIN
        -- WEBADI Validations Start

        --Validate Mandatory parameters
        IF ((p_ship_to_org_code IS NULL) OR (p_asn_number IS NULL) OR (p_new_exp_receipt_date IS NULL))
        THEN
            lv_error_message   :=
                'ASN Number or Ship to Organization or New-Expected Receipt Date missing. All these are MANDATORY. ';
            lv_upload_status   := gv_ret_error;
            RAISE le_webadi_exception;
        END IF;

        --Validate Responsibility (Region level) orgs
        BEGIN
            SELECT SUBSTR (responsibility_key,
                             INSTR (responsibility_key, '_', 3,
                                    3)
                           + 1)
              INTO lv_resp_sufix
              FROM fnd_responsibility_vl frt
             WHERE     1 = 1
                   AND responsibility_name LIKE 'Deckers Purchasing%'
                   AND responsibility_id = gn_resp_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_resp_sufix      := NULL;
                lv_error_message   :=
                       lv_error_message
                    || ' Not a valid Responsibility to Run Mass update Tool.';
                lv_upload_status   := gv_ret_error;
        END;

        --Validate Ship to Org by Region
        IF lv_resp_sufix IS NOT NULL AND p_ship_to_org_code IS NOT NULL
        THEN
            BEGIN
                SELECT mp.organization_id
                  INTO ln_ship_to_org_id
                  FROM apps.mtl_parameters mp, apps.fnd_lookup_values flv
                 WHERE     TO_NUMBER (flv.lookup_code) = mp.organization_id
                       AND flv.lookup_type = 'XXD_PO_MASS_UPDATE_ASN_ORGS'
                       AND flv.language = USERENV ('LANG')
                       AND flv.enabled_flag = 'Y'
                       AND mp.organization_code =
                           UPPER (TRIM (p_ship_to_org_code))
                       AND mp.attribute1 =
                           DECODE (lv_resp_sufix,
                                   'AMERICAS', 'US',
                                   'EMEA', 'EMEA',
                                   'APAC', 'APAC',
                                   'GLOBAL', mp.attribute1)
                       AND SYSDATE BETWEEN NVL (
                                               TRUNC (flv.start_date_active),
                                               SYSDATE)
                                       AND NVL (TRUNC (flv.end_date_active),
                                                SYSDATE + 1)
                       AND NVL (mp.attribute13, '0') = '2' --Trade Organziations
                UNION
                SELECT mp.organization_id
                  FROM apps.mtl_parameters mp, apps.fnd_lookup_values flv
                 WHERE     TO_NUMBER (flv.lookup_code) = mp.organization_id
                       AND flv.lookup_type = 'XXD_PO_MASS_UPDATE_ASN_ORGS'
                       AND flv.language = USERENV ('LANG')
                       AND flv.enabled_flag = 'Y'
                       AND mp.organization_code =
                           UPPER (TRIM (p_ship_to_org_code))
                       AND mp.attribute1 =
                           DECODE (lv_resp_sufix, 'AMERICAS', 'CA')
                       AND SYSDATE BETWEEN NVL (
                                               TRUNC (flv.start_date_active),
                                               SYSDATE)
                                       AND NVL (TRUNC (flv.end_date_active),
                                                SYSDATE + 1)
                       AND NVL (mp.attribute13, '0') = '2';
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_ship_to_org_id   := NULL;
                    lv_error_message    :=
                           lv_error_message
                        || ' '
                        || p_ship_to_org_code
                        || ' ASN can''t be updated from this responsibility.';
                    lv_upload_status    := gv_ret_error;
            END;
        END IF;

        --Validate ASN Number#
        IF ln_ship_to_org_id IS NOT NULL
        THEN
            BEGIN
                SELECT COUNT (1)
                  INTO ln_asn_valid
                  FROM rcv_shipment_headers rsh, rcv_shipment_lines rsl
                 WHERE     rsh.shipment_header_id = rsl.shipment_header_id
                       AND rsh.shipment_num = TRIM (p_asn_number)
                       AND rsl.to_organization_id = ln_ship_to_org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_asn_valid   := 0;
            END;

            IF ln_asn_valid = 0
            THEN
                lv_error_message   :=
                       lv_error_message
                    || ' Invalid ASN Number for Ship to Org.';
                lv_upload_status   := gv_ret_error;
            END IF;
        END IF;

        --Validate ASN Status#
        IF ln_ship_to_org_id IS NOT NULL
        THEN
            BEGIN
                SELECT shipment_header_id
                  INTO ln_shipment_hdr_id
                  FROM apps.xxd_po_rcv_open_asn_v r
                 WHERE     1 = 1
                       AND r.dest_org_id = ln_ship_to_org_id
                       AND r.asn_number = TRIM (p_asn_number);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_shipment_hdr_id   := NULL;
                    lv_error_message     :=
                           lv_error_message
                        || 'ASN is either FULLY RECEIVED or CANCELLED, Can not be updated.';
                    lv_upload_status     := gv_ret_error;
            END;
        END IF;

        --Validate New Expected Receipt Date
        IF p_new_exp_receipt_date IS NOT NULL
        THEN
            BEGIN
                SELECT TO_DATE (p_new_exp_receipt_date, 'DD-MON-YYYY')
                  INTO ld_new_exp_rcpt_dt
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    BEGIN
                        SELECT TO_DATE (p_new_exp_receipt_date, 'DD-MON-YY')
                          INTO ld_new_exp_rcpt_dt
                          FROM DUAL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            BEGIN
                                SELECT TO_DATE (p_new_exp_receipt_date, 'MM/DD/YYYY')
                                  INTO ld_new_exp_rcpt_dt
                                  FROM DUAL;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    BEGIN
                                        SELECT TO_DATE (p_new_exp_receipt_date, 'MM/DD/YY')
                                          INTO ld_new_exp_rcpt_dt
                                          FROM DUAL;
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            lv_error_message   :=
                                                SUBSTR (
                                                       lv_error_message
                                                    || 'New Expected Receipt Date should be in format. ',
                                                    1,
                                                    2000);
                                            lv_upload_status   :=
                                                gv_ret_error;
                                    END;
                            END;
                    END;
            END;
        END IF;

        --Validating New Expected Receipt Date Less than Current Date
        IF TRUNC (ld_new_exp_rcpt_dt) < TRUNC (SYSDATE)
        THEN
            lv_error_message   :=
                SUBSTR (
                       lv_error_message
                    || 'New Expected Receipt Date should not be less than Current Date. ',
                    1,
                    2000);
            lv_upload_status   := gv_ret_error;
        END IF;

        --Getting values from View
        IF ln_shipment_hdr_id IS NOT NULL
        THEN
            BEGIN
                SELECT r.asn_number, r.ship_to_org_code, r.invoice_num,
                       r.container_num, r.brand, r.expected_receipt_date,
                       r.receipt_source_code, r.vendor_name, r.vendor_site_code,
                       r.source_org_id, r.vendor_id, r.vendor_site_id
                  INTO lv_asn_number, lv_ship_to_org_code, lv_invoice_num, lv_container_num,
                                    lv_brand, ld_expected_receipt_date, lv_receipt_source_code,
                                    lv_vendor_name, lv_vendor_site_code, ln_source_org_id,
                                    ln_vendor_id, ln_vendor_site_id
                  FROM apps.xxd_po_rcv_open_asn_v r
                 WHERE     1 = 1
                       AND r.shipment_header_id = ln_shipment_hdr_id
                       AND r.dest_org_id = ln_ship_to_org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || ' Fetching data from View failed.',
                            1,
                            2000);
                    lv_upload_status   := gv_ret_error;
            END;
        END IF;

        IF lv_upload_status = gv_ret_error OR lv_error_message IS NOT NULL
        THEN
            RAISE le_webadi_exception;
        END IF;

        --To generate Sequence Id
        BEGIN
            SELECT xxdo.xxd_po_rcv_mass_upd_asn_s.NEXTVAL
              INTO ln_seq_stg_id
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_seq_stg_id      := 0;
                lv_upload_status   := gv_ret_error;
                lv_error_message   :=
                    SUBSTR (
                        lv_error_message || ' Unable to fetch Sequence ID ',
                        1,
                        2000);
        END;

        BEGIN
            -- Loading WebADI data to Staging table
            INSERT INTO xxdo.xxd_po_rcv_mass_upd_asn_t (brand, ship_to_org_code, invoice_num, container_num, asn_number, exp_receipt_date, new_exp_receipt_date, dest_org_id, source_org_id, shipment_header_id, vendor_name, vendor_site_code, vendor_id, vendor_site_id, receipt_source_code, opr_mode, num_attribute1, num_attribute2, num_attribute3, num_attribute4, num_attribute5, chr_attribute1, chr_attribute2, chr_attribute3, chr_attribute4, chr_attribute5, dt_attribute1, dt_attribute2, creation_date, created_by, last_update_date, last_updated_by, last_update_login, seq_id, request_id, status
                                                        , error_message)
                 VALUES (NVL (p_brand, lv_brand), lv_ship_to_org_code, NVL (p_invoice_num, lv_invoice_num), NVL (p_container_num, lv_container_num), lv_asn_number, ld_expected_receipt_date, ld_new_exp_rcpt_dt, ln_ship_to_org_id, ln_source_org_id, ln_shipment_hdr_id, lv_vendor_name, lv_vendor_site_code, ln_vendor_id, ln_vendor_site_id, lv_receipt_source_code, lv_opr_mode, p_attribute_num1, p_attribute_num2, p_attribute_num3, p_attribute_num4, p_attribute_num5, p_attribute_chr1, p_attribute_chr2, p_attribute_chr3, p_attribute_chr4, p_attribute_chr5, p_attribute_date1, p_attribute_date2, SYSDATE, gn_user_id, SYSDATE, gn_user_id, gn_login_id, ln_seq_stg_id, gn_request_id, 'N'
                         ,                                        --New Status
                           NULL                                --Error Message
                               );
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_message   :=
                    SUBSTR (
                           lv_error_message
                        || ' Error inserting into staging table: ',
                        1,
                        2000);
                RAISE le_webadi_exception;
        END;

        --Calling update ASN Procedure --START
        BEGIN
            --Calling Update ASN Dates procedure
            update_asn_dates (p_ship_to_org_id         => ln_ship_to_org_id,
                              p_shipment_header_id     => ln_shipment_hdr_id,
                              p_new_exp_receipt_date   => ld_new_exp_rcpt_dt,
                              p_seq_id                 => ln_seq_stg_id,
                              px_return_status         => lx_asn_upd_sts,
                              px_error_msg             => lx_asn_upd_msg);
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_message   :=
                    SUBSTR (
                           lx_asn_upd_msg
                        || ' Error calling UPDATE_ASN_DATES procedure ',
                        1,
                        2000);
                RAISE le_webadi_exception;
        END;

        --Calling update ASN Procedure --END

        --update_asn_dates procedure return status
        IF lx_asn_upd_sts <> gv_ret_success
        THEN
            lv_error_message   :=
                SUBSTR (lx_asn_upd_msg || ' ASN Update Failed ', 1, 2000);
            RAISE le_webadi_exception;
        END IF;
    EXCEPTION
        WHEN le_webadi_exception
        THEN
            lv_error_message   := SUBSTR (lv_error_message, 1, 2000);
            fnd_message.set_name ('XXDO', 'XXD_ORDER_UPLOAD_WEBADI_MSG'); --Using an existing Message as this is Just a place holder
            fnd_message.set_token ('ERROR_MESSAGE', lv_error_message);
            lv_error_message   := fnd_message.get ();
            raise_application_error (-20000, lv_error_message);
        WHEN OTHERS
        THEN
            lv_error_message   :=
                SUBSTR (lv_error_message || '.' || SQLERRM, 1, 2000);
            fnd_message.set_name ('XXDO', 'XXD_ORDER_UPLOAD_WEBADI_MSG'); --Using an existing Message as this is Just a place holder
            fnd_message.set_token ('ERROR_MESSAGE', lv_error_message);
            lv_error_message   := fnd_message.get ();
            raise_application_error (-20000, lv_error_message);
    END upload_proc;
END XXD_PO_RCV_OPEN_ASN_PKG;
/
