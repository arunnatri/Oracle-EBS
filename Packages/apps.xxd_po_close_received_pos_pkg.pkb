--
-- XXD_PO_CLOSE_RECEIVED_POS_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:54 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_PO_CLOSE_RECEIVED_POS_PKG"
IS
    --  ####################################################################################################
    --  Package      : xxd_po_close_pkg
    --  Design       : Package is used to Automate PO Closing for TQ PO's and SFS PO's.
    --  Notes        :
    --  Modification :
    --  ======================================================================================
    --  Date            Version#   Name                    Comments
    --  ======================================================================================
    --  21-May-2020     1.0        Showkath Ali             Initial Version
    --  ####################################################################################################
    gv_package_name   CONSTANT VARCHAR2 (30)
                                   := 'XXD_PO_CLOSE_RECEIVED_POS_PKG' ;
    gn_user_id        CONSTANT NUMBER := fnd_global.user_id;
    gn_login_id       CONSTANT NUMBER := fnd_global.login_id;
    gn_org_id         CONSTANT NUMBER := fnd_global.org_id;
    gn_resp_id        CONSTANT NUMBER := fnd_global.resp_id;
    gn_resp_appl_id   CONSTANT NUMBER := fnd_global.resp_appl_id;
    gn_request_id     CONSTANT NUMBER := fnd_global.conc_request_id;

    --Procedure to print messages into either log or output files
    --Parameters
    --PV_MSG        Message to be printed
    --PV_TIME       Print time or not. Default is no.
    --PV_FILE       Print to LOG or OUTPUT file. Default write it to LOG file

    PROCEDURE msg (pv_msg    IN VARCHAR2,
                   pv_time   IN VARCHAR2 DEFAULT 'N',
                   pv_file   IN VARCHAR2 DEFAULT 'LOG')
    IS
        --Local Variables
        lv_proc_name    VARCHAR2 (30) := 'MSG';
        lv_msg          VARCHAR2 (32767) := NULL;
        lv_time_stamp   VARCHAR2 (20)
                            := TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS');
    BEGIN
        IF pv_time = 'Y'
        THEN
            lv_msg   := pv_msg || '. Timestamp: ' || lv_time_stamp;
        ELSE
            lv_msg   := pv_msg;
        END IF;

        IF UPPER (pv_file) = 'OUT'
        THEN
            IF gn_user_id = -1
            THEN
                DBMS_OUTPUT.put_line (lv_msg);
            ELSE
                fnd_file.put_line (fnd_file.output, lv_msg);
            END IF;
        ELSE
            IF gn_user_id = -1
            THEN
                DBMS_OUTPUT.put_line (lv_msg);
            ELSE
                fnd_file.put_line (fnd_file.LOG, lv_msg);
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'In When Others exception in '
                || gv_package_name
                || '.'
                || lv_proc_name
                || ' procedure. Error is: '
                || SQLERRM);
    END msg;

    /***********************************************************************************************
    *********** fetch_tq_po_prc procedure called by main procedure to close/Print TQ POs ***********
    ************************************************************************************************/
    PROCEDURE fetch_tq_po_prc (pv_run_mode       IN     VARCHAR2,
                               pv_po_from_date   IN     VARCHAR2,
                               pv_po_to_date     IN     VARCHAR2,
                               pv_po_number      IN     VARCHAR2,
                               pn_tq_po_count       OUT NUMBER)
    IS
        CURSOR fetch_tq_po_cur IS
              SELECT pha.po_header_id,
                     pha.org_id,
                     po_line_data.brand,
                     pha.segment1 PO_Number,
                     mp.organization_code,
                     (SELECT DISTINCT full_name
                        FROM per_all_people_f papf
                       WHERE papf.person_id = pha.agent_id) buyer_name,
                     aps.vendor_name,
                     apss.vendor_site_code supplier_site,
                     po_line_data.po_quantity,
                     NVL (
                           (SELECT SUM (quantity)
                              FROM rcv_transactions rt
                             WHERE     pha.po_header_id = rt.po_header_id
                                   AND transaction_type = 'RECEIVE')
                         - NVL (
                               (SELECT SUM (quantity)
                                  FROM rcv_transactions rt
                                 WHERE     pha.po_header_id = rt.po_header_id
                                       AND transaction_type =
                                           'RETURN TO RECEIVING'),
                               0),
                         0) received_quantity,
                     (  po_line_data.po_quantity
                      - NVL (
                              (SELECT SUM (quantity)
                                 FROM rcv_transactions rt
                                WHERE     pha.po_header_id = rt.po_header_id
                                      AND transaction_type = 'RECEIVE')
                            - NVL (
                                  (SELECT SUM (quantity)
                                     FROM rcv_transactions rt
                                    WHERE     pha.po_header_id =
                                              rt.po_header_id
                                          AND transaction_type =
                                              'RETURN TO RECEIVING'),
                                  0),
                            0)) open_quantity,
                     pha.agent_id,
                     pdt.document_subtype,
                     pdt.document_type_code,
                     pha.closed_code,
                     pha.closed_date
                FROM po.po_headers_all pha,
                     (SELECT DISTINCT po_header_id, ship_to_organization_id, NVL (drop_ship_flag, 'N') drop_ship_flag
                        FROM po_line_locations_all plla) po_line_loc_data,
                     (  SELECT DISTINCT attribute1 brand, po_header_id, SUM (quantity) po_quantity
                          FROM po_lines_all pla
                      GROUP BY attribute1, po_header_id) po_line_data,
                     hr_all_organization_units hrou,
                     mtl_parameters mp,
                     ap_suppliers aps,
                     ap_supplier_sites_all apss,
                     apps.po_document_types_all pdt
               WHERE     1 = 1
                     AND pha.type_lookup_code = pdt.document_subtype
                     AND pha.org_id = pdt.org_id
                     AND pdt.document_type_code = 'PO'
                     AND pha.authorization_status = 'APPROVED'
                     AND pha.org_id = hrou.organization_id(+)
                     AND pha.vendor_id = aps.vendor_id(+)
                     AND pha.vendor_site_id = apss.vendor_site_id(+)
                     AND pha.po_header_id = po_line_loc_data.po_header_id
                     AND pha.po_header_id = po_line_data.po_header_id
                     AND po_line_loc_data.ship_to_organization_id =
                         mp.organization_id
                     AND aps.vendor_type_lookup_code = 'TQ PROVIDER'
                     AND NVL (closed_code, 'OPEN') = 'OPEN'
                     AND (SELECT SUM (quantity - quantity_cancelled)
                            FROM po_line_locations_all plla
                           WHERE plla.po_header_id = pha.po_header_id) =
                         NVL (
                               (SELECT SUM (quantity)
                                  FROM rcv_transactions rt
                                 WHERE     pha.po_header_id = rt.po_header_id
                                       AND transaction_type = 'RECEIVE')
                             - NVL (
                                   (SELECT SUM (quantity)
                                      FROM rcv_transactions rt
                                     WHERE     pha.po_header_id =
                                               rt.po_header_id
                                           AND transaction_type =
                                               'RETURN TO RECEIVING'),
                                   0),
                             0)
                     AND pha.segment1 = NVL (pv_po_number, pha.segment1)
                     AND TRUNC (pha.creation_date) BETWEEN NVL (
                                                               TRUNC (
                                                                   TO_DATE (
                                                                       pv_po_from_date,
                                                                       'YYYY/MM/DD HH24:MI:SS')),
                                                               TRUNC (
                                                                   pha.creation_date))
                                                       AND NVL (
                                                               TRUNC (
                                                                   TO_DATE (
                                                                       pv_po_to_date,
                                                                       'YYYY/MM/DD HH24:MI:SS')),
                                                               TRUNC (
                                                                   pha.creation_date))
            ORDER BY pha.creation_date;

        x_action         CONSTANT VARCHAR2 (20) := 'CLOSE'; -- Change this parameter as per requirement
        x_calling_mode   CONSTANT VARCHAR2 (2) := 'PO';
        x_conc_flag      CONSTANT VARCHAR2 (1) := 'N';
        x_return_code_h           VARCHAR2 (100);
        x_auto_close     CONSTANT VARCHAR2 (1) := 'N';
        x_origin_doc_id           NUMBER;
        x_returned                BOOLEAN;
        lv_status                 VARCHAR2 (10);
        lv_error_message          VARCHAR2 (32767);
        ln_po_count               NUMBER := 0;
        lv_operating_unit         VARCHAR2 (300);
    BEGIN
        IF pv_run_mode = 'REPORT'
        THEN
            FOR i IN fetch_tq_po_cur
            LOOP
                ln_po_count   := ln_po_count + 1;

                --Query to fetch operating unit based on org_id
                BEGIN
                    SELECT name
                      INTO lv_operating_unit
                      FROM hr_operating_units
                     WHERE organization_id = i.org_id;

                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                        'Operating Unit:' || lv_operating_unit);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_operating_unit   := NULL;
                        FND_FILE.PUT_LINE (
                            FND_FILE.LOG,
                            'Failed to fetch Operating Unit:' || SQLERRM);
                END;

                MSG (
                       lv_operating_unit
                    || CHR (9)
                    || i.brand
                    || CHR (9)
                    || i.PO_Number
                    || CHR (9)
                    || i.organization_code
                    || CHR (9)
                    || i.buyer_name
                    || CHR (9)
                    || i.vendor_name
                    || CHR (9)
                    || i.supplier_site
                    || CHR (9)
                    || i.po_quantity
                    || CHR (9)
                    || i.received_quantity
                    || CHR (9)
                    || i.open_quantity
                    || CHR (9),
                    'N',
                    'OUT');
            END LOOP;
        ELSE
            FOR i IN fetch_tq_po_cur
            LOOP
                ln_po_count   := ln_po_count + 1;

                --Query to fetch operating unit based on org_id
                BEGIN
                    SELECT name
                      INTO lv_operating_unit
                      FROM hr_operating_units
                     WHERE organization_id = i.org_id;

                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                        'Operating Unit:' || lv_operating_unit);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_operating_unit   := NULL;
                        FND_FILE.PUT_LINE (
                            FND_FILE.LOG,
                            'Failed to fetch Operating Unit:' || SQLERRM);
                END;

                x_returned    :=
                    po_actions.close_po (p_docid => i.po_header_id, p_doctyp => i.document_type_code, p_docsubtyp => i.document_subtype, p_lineid => NULL, p_shipid => NULL, p_action => x_action, p_reason => NULL, p_calling_mode => x_calling_mode, p_conc_flag => x_conc_flag, p_return_code => x_return_code_h, p_auto_close => x_auto_close, p_action_date => SYSDATE
                                         , p_origin_doc_id => NULL);

                IF x_returned = TRUE
                THEN
                    lv_status          := 'Success';
                    lv_error_message   := NULL;
                    msg (
                           'Purchase Order which just got Finally Closed is '
                        || i.PO_Number);
                    COMMIT;
                ELSE
                    lv_status   := 'Fail';
                    lv_error_message   :=
                           'API Failed to Finally Close the Purchase Order:'
                        || SQLERRM;
                    msg (lv_error_message);
                    msg ('Return Code is:' || x_return_code_h);
                END IF;

                MSG (
                       lv_operating_unit
                    || CHR (9)
                    || i.brand
                    || CHR (9)
                    || i.PO_Number
                    || CHR (9)
                    || i.organization_code
                    || CHR (9)
                    || i.buyer_name
                    || CHR (9)
                    || i.vendor_name
                    || CHR (9)
                    || i.supplier_site
                    || CHR (9)
                    || i.po_quantity
                    || CHR (9)
                    || i.received_quantity
                    || CHR (9)
                    || i.open_quantity
                    || CHR (9)
                    || 'TQ PO'
                    || CHR (9)
                    || lv_status
                    || CHR (9)
                    || lv_error_message
                    || CHR (9),
                    'N',
                    'OUT');
            END LOOP;
        END IF;

        pn_tq_po_count   := ln_po_count;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_error_message   :=
                'API Failed to Finally Close the Purchase Order:' || SQLERRM;
            msg (lv_error_message);
    END fetch_tq_po_prc;

    /***********************************************************************************************
    *********** fetch_tq_po_prc procedure called by main procedure to close/Print TQ POs ***********
    ************************************************************************************************/
    PROCEDURE fetch_sfs_po_prc (pv_run_mode       IN     VARCHAR2,
                                pv_po_from_date   IN     VARCHAR2,
                                pv_po_to_date     IN     VARCHAR2,
                                pv_po_number      IN     VARCHAR2,
                                pn_sfs_po_count      OUT NUMBER)
    IS
        CURSOR fetch_sfs_po_cur IS
              SELECT pha.po_header_id,
                     pha.org_id,
                     po_line_data.brand,
                     pha.segment1 po_number,
                     mp.organization_code,
                     (SELECT DISTINCT full_name
                        FROM per_all_people_f papf
                       WHERE papf.person_id = pha.agent_id) buyer_name,
                     aps.vendor_name,
                     apss.vendor_site_code supplier_site,
                     po_line_data.po_quantity,
                     NVL (
                           (SELECT SUM (quantity)
                              FROM rcv_transactions rt
                             WHERE     pha.po_header_id = rt.po_header_id
                                   AND transaction_type = 'RECEIVE')
                         - NVL (
                               (SELECT SUM (quantity)
                                  FROM rcv_transactions rt
                                 WHERE     pha.po_header_id = rt.po_header_id
                                       AND transaction_type =
                                           'RETURN TO RECEIVING'),
                               0),
                         0) received_quantity,
                     (  po_line_data.po_quantity
                      - NVL (
                              (SELECT SUM (quantity)
                                 FROM rcv_transactions rt
                                WHERE     pha.po_header_id = rt.po_header_id
                                      AND transaction_type = 'RECEIVE')
                            - NVL (
                                  (SELECT SUM (quantity)
                                     FROM rcv_transactions rt
                                    WHERE     pha.po_header_id =
                                              rt.po_header_id
                                          AND transaction_type =
                                              'RETURN TO RECEIVING'),
                                  0),
                            0)) open_quantity,
                     pha.agent_id,
                     pdt.document_subtype,
                     pdt.document_type_code,
                     pha.closed_code,
                     pha.closed_date
                FROM po.po_headers_all pha,
                     (SELECT DISTINCT po_header_id, ship_to_organization_id, NVL (drop_ship_flag, 'N') drop_ship_flag
                        FROM po_line_locations_all plla) po_line_loc_data,
                     (  SELECT DISTINCT attribute1 brand, po_header_id, SUM (quantity) po_quantity
                          FROM po_lines_all pla
                      GROUP BY attribute1, po_header_id) po_line_data,
                     hr_all_organization_units hrou,
                     mtl_parameters mp,
                     ap_suppliers aps,
                     ap_supplier_sites_all apss,
                     apps.po_document_types_all pdt
               WHERE     1 = 1
                     AND pha.type_lookup_code = pdt.document_subtype
                     AND pha.org_id = pdt.org_id
                     AND pdt.document_type_code = 'PO'
                     AND pha.authorization_status = 'APPROVED'
                     AND pha.org_id = hrou.organization_id(+)
                     AND pha.vendor_id = aps.vendor_id(+)
                     AND pha.vendor_site_id = apss.vendor_site_id(+)
                     AND pha.po_header_id = po_line_loc_data.po_header_id
                     AND pha.po_header_id = po_line_data.po_header_id
                     AND po_line_loc_data.ship_to_organization_id =
                         mp.organization_id
                     AND aps.vendor_name = 'Deckers Retail Stores'
                     AND pha.attribute10 = 'SFS'
                     AND NVL (closed_code, 'OPEN') = 'OPEN'
                     AND (SELECT SUM (quantity - quantity_cancelled)
                            FROM po_line_locations_all plla
                           WHERE plla.po_header_id = pha.po_header_id) =
                         NVL (
                               (SELECT SUM (quantity)
                                  FROM rcv_transactions rt
                                 WHERE     pha.po_header_id = rt.po_header_id
                                       AND transaction_type = 'RECEIVE')
                             - NVL (
                                   (SELECT SUM (quantity)
                                      FROM rcv_transactions rt
                                     WHERE     pha.po_header_id =
                                               rt.po_header_id
                                           AND transaction_type =
                                               'RETURN TO RECEIVING'),
                                   0),
                             0)
                     AND pha.segment1 = NVL (pv_po_number, pha.segment1)
                     AND TRUNC (pha.creation_date) BETWEEN NVL (
                                                               TRUNC (
                                                                   TO_DATE (
                                                                       pv_po_from_date,
                                                                       'YYYY/MM/DD HH24:MI:SS')),
                                                               TRUNC (
                                                                   pha.creation_date))
                                                       AND NVL (
                                                               TRUNC (
                                                                   TO_DATE (
                                                                       pv_po_to_date,
                                                                       'YYYY/MM/DD HH24:MI:SS')),
                                                               TRUNC (
                                                                   pha.creation_date))
            ORDER BY pha.creation_date;

        x_action         CONSTANT VARCHAR2 (20) := 'CLOSE'; -- Change this parameter as per requirement
        x_calling_mode   CONSTANT VARCHAR2 (2) := 'PO';
        x_conc_flag      CONSTANT VARCHAR2 (1) := 'N';
        x_return_code_h           VARCHAR2 (100);
        x_auto_close     CONSTANT VARCHAR2 (1) := 'N';
        x_origin_doc_id           NUMBER;
        x_returned                BOOLEAN;
        lv_status                 VARCHAR2 (10);
        lv_error_message          VARCHAR2 (32767);
        ln_po_count               NUMBER := 0;
        lv_operating_unit         VARCHAR2 (500);
    BEGIN
        IF pv_run_mode = 'REPORT'
        THEN
            FOR i IN fetch_sfs_po_cur
            LOOP
                ln_po_count   := ln_po_count + 1;

                --Query to fetch operating unit based on org_id
                BEGIN
                    SELECT name
                      INTO lv_operating_unit
                      FROM hr_operating_units
                     WHERE organization_id = i.org_id;

                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                        'Operating Unit:' || lv_operating_unit);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_operating_unit   := NULL;
                        FND_FILE.PUT_LINE (
                            FND_FILE.LOG,
                            'Failed to fetch Operating Unit:' || SQLERRM);
                END;

                msg (
                       lv_operating_unit
                    || CHR (9)
                    || i.brand
                    || CHR (9)
                    || i.PO_Number
                    || CHR (9)
                    || i.organization_code
                    || CHR (9)
                    || i.buyer_name
                    || CHR (9)
                    || i.vendor_name
                    || CHR (9)
                    || i.supplier_site
                    || CHR (9)
                    || i.po_quantity
                    || CHR (9)
                    || i.received_quantity
                    || CHR (9)
                    || i.open_quantity
                    || CHR (9),
                    'N',
                    'OUT');
            END LOOP;
        ELSE
            FOR i IN fetch_sfs_po_cur
            LOOP
                ln_po_count   := ln_po_count + 1;

                --Query to fetch operating unit based on org_id
                BEGIN
                    SELECT name
                      INTO lv_operating_unit
                      FROM hr_operating_units
                     WHERE organization_id = i.org_id;

                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                        'Operating Unit:' || lv_operating_unit);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_operating_unit   := NULL;
                        FND_FILE.PUT_LINE (
                            FND_FILE.LOG,
                            'Failed to fetch Operating Unit:' || SQLERRM);
                END;

                x_returned    :=
                    po_actions.close_po (p_docid => i.po_header_id, p_doctyp => i.document_type_code, p_docsubtyp => i.document_subtype, p_lineid => NULL, p_shipid => NULL, p_action => x_action, p_reason => NULL, p_calling_mode => x_calling_mode, p_conc_flag => x_conc_flag, p_return_code => x_return_code_h, p_auto_close => x_auto_close, p_action_date => SYSDATE
                                         , p_origin_doc_id => NULL);

                IF x_returned = TRUE
                THEN
                    lv_status          := 'Success';
                    lv_error_message   := NULL;
                    msg (
                           'Purchase Order which just got Finally Closed is '
                        || i.PO_Number);
                    COMMIT;
                ELSE
                    lv_status   := 'Fail';
                    lv_error_message   :=
                           'API Failed to Finally Close the Purchase Order:'
                        || SQLERRM;
                    msg (lv_error_message);
                    msg ('Return Code is:' || x_return_code_h);
                END IF;

                MSG (
                       lv_operating_unit
                    || CHR (9)
                    || i.brand
                    || CHR (9)
                    || i.PO_Number
                    || CHR (9)
                    || i.organization_code
                    || CHR (9)
                    || i.buyer_name
                    || CHR (9)
                    || i.vendor_name
                    || CHR (9)
                    || i.supplier_site
                    || CHR (9)
                    || i.po_quantity
                    || CHR (9)
                    || i.received_quantity
                    || CHR (9)
                    || i.open_quantity
                    || CHR (9)
                    || 'SFS PO'
                    || CHR (9)
                    || lv_status
                    || CHR (9)
                    || lv_error_message
                    || CHR (9),
                    'N',
                    'OUT');
            END LOOP;
        END IF;

        pn_sfs_po_count   := ln_po_count;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_error_message   :=
                'API Failed to Finally Close the Purchase Order:' || SQLERRM;
            msg (lv_error_message);
    END fetch_sfs_po_prc;

    /***********************************************************************************************
    ***** Main procedure called by concurrent program "Deckers Program to Close Received POs" ******
    ************************************************************************************************/
    PROCEDURE main_prc (pv_errbuf OUT VARCHAR2, pn_retcode OUT NUMBER, pv_run_mode IN VARCHAR2, pv_po_type IN VARCHAR2, pv_po_from_date IN VARCHAR2, pv_po_to_date IN VARCHAR2
                        , pv_po_number IN VARCHAR2)
    IS
        --Local Variables Declaration
        lv_proc_name      VARCHAR2 (30) := 'MAIN_PRC';
        lv_error_msg      VARCHAR2 (2000) := NULL;
        ln_retcode        NUMBER := 0;
        lv_report_date    VARCHAR2 (30);
        ln_tq_po_count    NUMBER := 0;
        ln_sfs_po_count   NUMBER := 0;
    BEGIN
        BEGIN
            SELECT TO_CHAR (SYSDATE, 'DD-MON-YYYY')
              INTO lv_report_date
              FROM sys.DUAL;
        END;

        -- Print the parameters in the report
        msg ('Report Name :Deckers Program to Close Received POs',
             'N',
             'OUT');
        msg ('Report Date - :' || lv_report_date, 'N', 'OUT');
        msg ('Report Parameters:', 'N', 'OUT');
        msg ('pv_run_mode: ' || pv_run_mode, 'N', 'OUT');
        msg ('pv_po_type: ' || pv_po_type, 'N', 'OUT');
        msg ('pv_po_from_date: ' || pv_po_from_date, 'N', 'OUT');
        msg ('pv_po_to_date: ' || pv_po_to_date, 'N', 'OUT');
        msg ('pv_po_number: ' || pv_po_number, 'N', 'OUT');
        msg ('', 'N', 'OUT');
        msg ('START - Deckers Program to Close Received POs: ', 'Y');

        IF pv_run_mode = 'REPORT'
        THEN
            MSG (
                   'Operating Unit'
                || CHR (9)
                || 'Brand'
                || CHR (9)
                || 'PO Number'
                || CHR (9)
                || 'Ship to Org'
                || CHR (9)
                || 'Buyer Name'
                || CHR (9)
                || 'Vendor'
                || CHR (9)
                || 'Vendor Site'
                || CHR (9)
                || 'PO Quantity'
                || CHR (9)
                || 'Received Quantity'
                || CHR (9)
                || 'Open Quantity'
                || CHR (9),
                'N',
                'OUT');
        ELSIF pv_run_mode = 'EXECUTE'
        THEN
            MSG (
                   'Operating Unit'
                || CHR (9)
                || 'Brand'
                || CHR (9)
                || 'PO Number'
                || CHR (9)
                || 'Ship to Org'
                || CHR (9)
                || 'Buyer Name'
                || CHR (9)
                || 'Vendor'
                || CHR (9)
                || 'Vendor Site'
                || CHR (9)
                || 'PO Quantity'
                || CHR (9)
                || 'Received Quantity'
                || CHR (9)
                || 'Open Quantity'
                || CHR (9)
                || 'PO Type'
                || CHR (9)
                || 'Status'
                || CHR (9)
                || 'Error message'
                || CHR (9),
                'N',
                'OUT');
        END IF;

        IF pv_po_type = 'TQ PO'
        THEN
            fetch_tq_po_prc (pv_run_mode, pv_po_from_date, pv_po_to_date,
                             pv_po_number, ln_tq_po_count);

            IF ln_tq_po_count = 0
            THEN
                MSG (' TQ PO count:' || ln_tq_po_count);
                msg ('', 'N', 'OUT');
                msg (
                    'There are no eligible Purchase Orders for the given parameters');
                msg (
                    'There are no eligible Purchase Orders for the given parameters',
                    'N',
                    'OUT');
            END IF;
        ELSIF pv_po_type = 'SFS PO'
        THEN
            fetch_sfs_po_prc (pv_run_mode, pv_po_from_date, pv_po_to_date,
                              pv_po_number, ln_sfs_po_count);

            IF ln_sfs_po_count = 0
            THEN
                MSG (' SFS PO count:' || ln_sfs_po_count);
                msg ('', 'N', 'OUT');
                msg (
                    'There are no eligible Purchase Orders for the given parameters');
                msg (
                    'There are no eligible Purchase Orders for the given parameters',
                    'N',
                    'OUT');
            END IF;
        ELSIF pv_po_type = 'ALL'
        THEN
            fetch_tq_po_prc (pv_run_mode, pv_po_from_date, pv_po_to_date,
                             pv_po_number, ln_tq_po_count);
            fetch_sfs_po_prc (pv_run_mode, pv_po_from_date, pv_po_to_date,
                              pv_po_number, ln_sfs_po_count);

            IF ln_tq_po_count = 0 AND ln_sfs_po_count = 0
            THEN
                MSG (
                       ' TQ PO count:'
                    || ln_tq_po_count
                    || '-'
                    || 'SFS PO Count:'
                    || ln_sfs_po_count);
                msg ('', 'N', 'OUT');
                msg (
                    'There are no eligible Purchase Orders for the given parameters');
                msg (
                    'There are no eligible Purchase Orders for the given parameters',
                    'N',
                    'OUT');
            END IF;
        END IF;

        msg ('END - Deckers Program to Close Received POs: ', 'Y');
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_error_msg   :=
                SUBSTR (
                       'In When Others exception in '
                    || gv_package_name
                    || '.'
                    || lv_proc_name
                    || ' procedure. Error is: '
                    || SQLERRM,
                    1,
                    2000);
            ln_retcode   := gn_error;
            pv_errbuf    := lv_error_msg;
            pn_retcode   := ln_retcode;
            msg (lv_error_msg);
    END main_prc;
END xxd_po_close_received_pos_pkg;
/
