--
-- XXDO_AP_INV_IMP_APPRV  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:32 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_AP_INV_IMP_APPRV"
/************************************************************************************************
       * Package         : XXDO_AP_INV_IMP_APPRV
       * Description     : This package is used to Fetch the payment data from  EDI staging tables and create in EBS
       * Notes           :
       * Modification    :
       *-----------------------------------------------------------------------------------------------
       * Date           Version#      Name                       Description
       *-----------------------------------------------------------------------------------------------
       *                1.0                                     Initial Version
    *                2.0          Showkath Ali               CCR0007979 changes for Macau
    * 29-JUL-20201   3.0          Srinath Siricilla          CCR0009458
       ************************************************************************************************/
AS
    PROCEDURE import_invoices (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY NUMBER, P_Validate_Only IN VARCHAR2 DEFAULT 'Y'
                               , P_Debug IN VARCHAR2 DEFAULT 'Y')
    IS
        CURSOR c_invoice_details IS
            (SELECT *
               FROM (  SELECT DISTINCT 0 selected, edih.inv_header_id, TRUNC (edih.creation_date) received_date,
                                       inv_org.name organization, inv_org.org_id, edih.invoice_number,
                                       v.vendor_name, edih.vendor_site_id, v.vendor_id,
                                       ROUND (edif.invoice_total, 2) invoice_total, DECODE (edih.approved,  'Y', 'Yes',  'N', 'No',  'Unknown') approved, DECODE (edih.process_status,  'A', 'Approved',  'R', 'Ready to Approve',  'C', 'Canceled/Rejected',  'I', 'Stuck in Interface',  'Y', 'Imported') status,
                                       edih.approved_on, usr.description approved_by, DECODE (edih.process_status, 'Y', TRUNC (apa.creation_date), NULL) imported_date,
                                       edih.source, DECODE (NVL (edih.chargeback_flag, '-1'),  'C', 'YES',  'N', 'NO',  'Y', 'NO',  'NO') is_chargeback_required, DECODE (NVL (edih.chargeback_flag, '-1'),  'Y', 'YES',  'N', 'NO',  'C', 'NO',  'NO') has_chargeback_required,
                                       --edih.inv_header_id,
                                       edif.carrier_scac, edif.carrier_name, edif.vessel_name,
                                       edif.bol_number, --edif.invoice_total,
                                                        edih.invoice_ref, edih.invoice_date,
                                       edih.PAY_GROUP_LOOKUP_CODE, edih.PAYMENT_METHOD_LOOKUP_CODE, DECODE (edih.chargeback_flag,  NULL, 1,  'N', 2,  'Y', 3,  'C', 4) processing_order,
                                       DECODE (NVL (edih.prepayment_application_flag, '-1'), -- Added Prepayment columns by Anil as part of GTN Phase2 changes
                                                                                              'Y', 'YES',  'N', 'NO',  'NO') has_prepayment, edih.prepayment_number, edih.prepayment_amount,
                                       edih.invoice_type_lookup_code, DECODE (UPPER (NVL (edih.invoice_type_lookup_code, 'COMMERCIAL')),  'PRESENTMENT', 'YES',  'COMMERCIAL', 'NO',  'NO') is_prepayment
                         FROM                             --apps.po_vendors v,
                              apps.ap_suppliers v,  -- Added as per CCR0009458
                              do_edi.do_edi810in_headers edih,
                              do_edi.do_edi810in_footers edif,
                              apps.ap_invoices_all apa,
                              apps.fnd_user usr,
                              (SELECT DISTINCT inv_header_id, hr.name, pha.org_id
                                 FROM do_edi.do_edi810in_items i, --                  apps.po_headers_all pha,
                                                                  apps.po_headers pha, -- To restrict the data set to be processed, based on the context in which program is running.
                                                                                       apps.hr_all_organization_units hr
                                WHERE     NVL2 (
                                              i.po_header_id,
                                              i.po_header_id,
                                              get_header_id (i.inv_header_id)) =
                                          pha.po_header_id -- Added function by Anil
                                      AND pha.org_id = hr.organization_id)
                              inv_org
                        WHERE     v.vendor_id = edih.vendor_id
                              AND edih.inv_header_id = inv_org.inv_header_id
                              AND edih.inv_header_id = edif.inv_header_id
                              AND edih.invoice_number = apa.invoice_num(+)
                              AND edih.approved_by = usr.user_id(+)
                              AND edih.Source = 'GTNEXUS'
                              AND process_status IN ('A')
                     ORDER BY DECODE (edih.chargeback_flag,  NULL, 1,  'N', 2,  'Y', 3,  'C', 4), edih.invoice_number));

        --Get cost details for all invoices
        CURSOR c_getCostDetails (p_inv_header_id IN DO_EDI.DO_EDI810IN_HEADERS.INV_HEADER_ID%TYPE, is_chargeback_required IN VARCHAR2, is_prepayment IN VARCHAR2) -- Added Prepayment parameter by Anil, as part of GTN Phase2 changes
        IS
            (SELECT 1 NEXTVAL, 0 ext_amount, ROUND (l.line_amount, 2) line_amount,
                    0 unit_price, 0 quantity, 'NONE' description,
                    l.gl_code, l.po_header_id, l.po_line_id,
                    l.po_line_location_id, l.inventory_item_id, f.bol_number
               FROM do_edi.do_edi810in_items l, do_edi.do_edi810in_headers h, do_edi.do_edi810in_footers f
              WHERE     l.INV_HEADER_ID = h.inv_header_id
                    AND l.INV_HEADER_ID = f.inv_header_id
                    AND h.inv_header_id = p_inv_header_id
                    AND is_chargeback_required = 'YES')
            UNION
            (SELECT 1 NEXTVAL, l.unit_price * l.quantity ext_amount, ROUND (ROUND (l.unit_price, 2) * l.quantity, 2) line_amount,
                    ROUND (l.unit_price, 2) unit_price, l.quantity, inv.description,
                    'NONE' gl_code, l.po_header_id, l.po_line_id,
                    l.po_line_location_id, l.inventory_item_id, f.bol_number
               FROM do_edi.do_edi810in_items l, do_edi.do_edi810in_headers h, do_edi.do_edi810in_footers f,
                    apps.mtl_system_items_b inv
              WHERE     l.inventory_item_id = inv.inventory_item_id
                    AND l.INV_HEADER_ID = h.inv_header_id
                    AND l.INV_HEADER_ID = f.inv_header_id
                    AND inv.organization_id =
                        (SELECT organization_id
                           FROM inv.mtl_parameters
                          WHERE organization_code =
                                fnd_profile.VALUE ('XXDO: ORGANIZATION CODE'))
                    AND h.inv_header_id = p_Inv_header_id
                    AND is_chargeback_required = 'NO'
                    AND is_prepayment = 'NO')
            UNION -- Added Prepayment query by Anil as part of GTN Phase2 changes
            (SELECT 1 NEXTVAL, 0 ext_amount, ROUND (l.line_amount, 2) line_amount,
                    0 unit_price, 0 quantity, 'NONE' description,
                    l.gl_code, l.po_header_id, l.po_line_id,
                    l.po_line_location_id, l.inventory_item_id, f.bol_number
               FROM do_edi.do_edi810in_items l, do_edi.do_edi810in_headers h, do_edi.do_edi810in_footers f
              WHERE     l.INV_HEADER_ID = h.inv_header_id
                    AND l.INV_HEADER_ID = f.inv_header_id
                    AND h.inv_header_id = p_inv_header_id
                    AND is_prepayment = 'YES');


        --Declare veriables

        l_ship_to_location_id          NUMBER := 0;
        l_ship_to_location_id_cnt      NUMBER := 0; -- Added by Anil as part of GTN Phase2 changes
        l_poh_org_id                   NUMBER := 0;
        l_return_value                 NUMBER := 0;
        l_return_val                   NUMBER := 0;
        l_invoice_id                   apps.ap_invoices_interface.invoice_id%TYPE
            := 0;
        l_vendor_site_code             apps.po_vendor_sites_all.vendor_site_code%TYPE
            := NULL;

        l_batch_error_flag             VARCHAR2 (100);
        l_invoices_fetched             NUMBER;
        l_invoices_created             NUMBER;
        l_total_invoice_amount         NUMBER;
        l_print_batch                  VARCHAR2 (100);
        l_holds_count                  NUMBER := 0;

        l_approval_status              VARCHAR2 (2000) := NULL;
        l_msg                          VARCHAR2 (2000) := NULL;

        l_Line_array_4                 do_edi.do_edi810in_items.line_amount%TYPE
                                           := 0;
        l_Line_array_5                 do_edi.do_edi810in_items.unit_price%TYPE
                                           := 0;
        l_Line_array_6                 do_edi.do_edi810in_items.quantity%TYPE
                                           := 0;
        l_Line_array_7                 apps.mtl_system_items_b.description%TYPE
                                           := NULL;
        l_Line_array_14                do_edi.do_edi810in_items.po_header_id%TYPE
            := 0;
        l_Line_array_15                do_edi.do_edi810in_items.po_line_id%TYPE
                                           := 0;
        l_Line_array_16                do_edi.do_edi810in_items.po_line_location_id%TYPE
            := 0;
        l_Line_array_17                apps.mtl_system_items_b.PRIMARY_UNIT_OF_MEASURE%TYPE
            := NULL;
        l_Line_array_18                do_edi.do_edi810in_items.inventory_item_id%TYPE
            := 0;
        l_Line_array_21                apps.gl_code_combinations.code_combination_id%TYPE
            := 0;
        l_Line_array_22                apps.gl_code_combinations.code_combination_id%TYPE
            := 0;
        l_attribute_category           apps.ap_invoices_interface.attribute_category%TYPE
            := NULL;
        l_Header_array_27              apps.ap_invoices_interface.attribute5%TYPE
            := NULL;
        l_Header_array_28              apps.ap_invoices_interface.attribute6%TYPE
            := NULL;
        l_group_id                     apps.ap_invoices_interface.GROUP_ID%TYPE
                                           := NULL;
        l_invoice_line_id              apps.ap_invoice_lines_interface.invoice_line_id%TYPE
            := 0;
        l_count_1                      NUMBER;
        l_count_2                      NUMBER;
        l_error_flag                   BOOLEAN := FALSE;

        l_total_inv_processed          NUMBER := 0;
        l_total_inv_failed             NUMBER := 0;
        l_total_eligible_inv           NUMBER := 0;
        l_total_inv_approved           NUMBER := 0;
        l_total_prepay_inv_processed   NUMBER := 0; -- Added  by Anil as part of GTN Phase2 changes
        l_total_inv_need_reapproval    NUMBER := 0;
        l_current_invoice              VARCHAR2 (100);
        lv_prepay_number               VARCHAR2 (240); -- Added Prepayment fields by Anil as part of GTN Phase2 changes
        lv_prepay_dist_number          VARCHAR2 (240) DEFAULT NULL;
        ln_prepay_apply_amount         NUMBER;
        ln_header_amount               NUMBER;               -- Added  by Anil

        --Hard coding values
        l_UOM                          apps.mtl_system_items_b.PRIMARY_UNIT_OF_MEASURE%TYPE
            := 'Pair';
        l_line_type_lookup_code        apps.ap_invoice_lines_interface.line_type_lookup_code%TYPE
            := 'ITEM';
        l_invoice_type_lookup_code     apps.ap_invoices_interface.invoice_type_lookup_code%TYPE
            := 'STANDARD';
        l_invoice_currency_code        apps.ap_invoices_interface.invoice_currency_code%TYPE
            := 'USD';
        l_terms_id                     apps.ap_invoices_interface.terms_id%TYPE;
    BEGIN
        BEGIN
            IF P_Debug = 'Y'
            THEN
                fnd_file.put_line (FND_FILE.LOG,
                                   'Interface processing started..');
            END IF;

            --Fetch all the Invoices to import
            IF P_DEBUG = 'Y'
            THEN
                fnd_file.put_line (FND_FILE.LOG, 'A1');
            END IF;

            -- Added by Lakshmi BTDEV Team on 24-DEC-2014

            -- Commented as per CCR0009458
            /* BEGIN
               SELECT term_id
                 INTO l_terms_id
                 FROM ap_terms
                WHERE NAME = 'DUE UPON RECEIPT'
                  AND enabled_flag = 'Y';
            EXCEPTION
               WHEN OTHERS
               THEN
                  l_terms_id := NULL;
                  fnd_file.put_line
                           (fnd_file.LOG,
                            'Error While Fetching Term ID For The Term: DUE UPON RECEIPT'
                           );
            END; */
            -- End of Change as per CCR0009458

            --

            FOR r_invoice_details IN c_invoice_details
            LOOP
                l_current_invoice      := NULL;
                SAVEPOINT start_process_loop;
                -----l_inv_not_processed := 0;

                l_total_eligible_inv   := l_total_eligible_inv + 1;
                l_error_flag           := FALSE;

                IF P_DEBUG = 'Y'
                THEN
                    fnd_file.put_line (FND_FILE.LOG, 'A2');
                END IF;

                SELECT apps.ap_invoices_interface_s.NEXTVAL
                  INTO l_invoice_id
                  FROM DUAL;

                IF P_DEBUG = 'Y'
                THEN
                    fnd_file.put_line (FND_FILE.LOG, 'A3');
                END IF;

                --Get invoice ship to location (error if more than one location is returned)
                --Get invoice ship to location (error if more than one location is returned)
                -- chargeback_flag will be 'C' for the is_chargeback_required flag to be 'YES'
                IF (UPPER (NVL (r_invoice_details.invoice_type_lookup_code, 'COMMERCIAL')) = 'COMMERCIAL' AND UPPER (r_invoice_details.is_chargeback_required) <> 'YES') -- Modified by Anil as part of GTN Phase2 changes
                THEN
                      SELECT COUNT (DISTINCT ship_to_location_id), ship_to_location_id
                        INTO l_ship_to_location_id_cnt, l_ship_to_location_id
                        FROM do_edi.do_edi810in_items i, apps.po_line_locations_all polla
                       WHERE     i.po_line_location_id = polla.line_location_id
                             AND i.inv_header_id =
                                 r_invoice_details.inv_header_id
                    GROUP BY ship_to_location_id; -- Added by Anil to derive ship to location id
                ELSE
                    l_ship_to_location_id_cnt   := 1;
                    l_ship_to_location_id       := -1;
                END IF;

                IF P_DEBUG = 'Y'
                THEN
                    fnd_file.put_line (FND_FILE.LOG, 'A4');
                END IF;

                --Get Invoice org (Fail if more than one is returned   -- Added by Anil to fix Chargeback Invoice
                IF (r_invoice_details.is_chargeback_required = 'YES')
                THEN
                    l_poh_org_id   := 1;
                ELSE
                    SELECT COUNT (DISTINCT poh.org_id)
                      INTO l_poh_org_id
                      FROM do_edi.do_edi810in_purchaseorders po, apps.po_headers_all poh
                     WHERE     po.po_header_id = poh.po_header_id
                           AND po.inv_header_id =
                               r_invoice_details.Inv_header_id;
                END IF;


                IF P_DEBUG = 'Y'
                THEN
                    fnd_file.put_line (FND_FILE.LOG, 'A5');
                END IF;


                -- fnd_file.put_line (FND_FILE.LOG, r_invoice_details.vendor_site_id);
                --fnd_file.put_line (FND_FILE.LOG, r_invoice_details.org_id);
                fnd_file.put_line (FND_FILE.LOG,
                                   r_invoice_details.invoice_number);

                SELECT vendor_site_code
                  INTO l_vendor_site_code
                  FROM apps.ap_supplier_sites_all        --po_vendor_sites_all
                 WHERE     1 = 1
                       AND vendor_site_id = r_invoice_details.vendor_site_id
                       AND org_id = r_invoice_details.org_id; -- Added by LakshmiBTDEV Team on 05-DEC-2014

                IF P_DEBUG = 'Y'
                THEN
                    fnd_file.put_line (FND_FILE.LOG, 'A6');
                END IF;

                IF UPPER (
                       NVL (r_invoice_details.invoice_type_lookup_code, 'X')) =
                   'PRESENTMENT' -- Added Invoice type condition by Anil as part of GTN Phase2 changes
                THEN
                    l_invoice_type_lookup_code   := 'PREPAYMENT';
                ELSIF     UPPER (
                              NVL (
                                  r_invoice_details.invoice_type_lookup_code,
                                  'COMMERCIAL')) =
                          'COMMERCIAL'
                      AND UPPER (r_invoice_details.is_chargeback_required) <>
                          'YES'
                THEN
                    l_invoice_type_lookup_code   := 'STANDARD';
                ELSIF UPPER (r_invoice_details.is_chargeback_required) =
                      'YES'
                THEN
                    l_invoice_type_lookup_code   := 'CREDIT';
                END IF;

                IF     UPPER (
                           NVL (r_invoice_details.invoice_type_lookup_code,
                                'COMMERCIAL')) =
                       'COMMERCIAL'
                   AND r_invoice_details.has_prepayment = 'YES' -- Added Prepayment values by Anil as part of GTN Phase2 changes
                THEN
                    lv_prepay_number   := r_invoice_details.prepayment_number;
                    ln_prepay_apply_amount   :=
                        r_invoice_details.prepayment_amount;
                ELSE
                    lv_prepay_number         := NULL;
                    ln_prepay_apply_amount   := NULL;
                END IF;


                IF l_ship_to_location_id_cnt = 1 AND l_poh_org_id = 1
                THEN
                    l_attribute_category   := 'Invoice Global Data Elements'; -- Defect# 3192, Added by Anil, to populate attribute catergory for Prepayments as well

                    IF r_invoice_details.has_chargeback_required = 'YES'
                    THEN
                        l_attribute_category   :=
                            'Invoice Global Data Elements'; --- Ranjan: This line is not there in the Greg's logic
                        l_Header_array_27   := 'Y';
                    ELSE
                        l_Header_array_27   := NULL;
                    END IF;

                    IF r_invoice_details.is_chargeback_required = 'YES'
                    THEN
                        l_attribute_category   :=
                            'Invoice Global Data Elements'; --- Ranjan: This line is not there in the Greg's logic
                        l_Header_array_28   := r_invoice_details.invoice_ref;
                    ELSE
                        l_Header_array_28   := NULL;
                    END IF;

                    -----------------------------  Added by Anil, to check the amount matches with line amount

                    ln_header_amount       :=
                        get_header_amount (r_invoice_details.inv_header_id);

                    fnd_file.put_line (
                        FND_FILE.LOG,
                        'Invoice Total:' || r_invoice_details.invoice_total);

                    fnd_file.put_line (
                        FND_FILE.LOG,
                        'Invoice Line Total' || ln_header_amount);

                    IF UPPER (
                           NVL (r_invoice_details.invoice_type_lookup_code,
                                'X')) =
                       'PRESENTMENT'
                    THEN
                        ln_header_amount   := r_invoice_details.invoice_total;
                    ELSIF UPPER (r_invoice_details.is_chargeback_required) =
                          'YES'
                    THEN
                        SELECT SUM (line_amount) -- Added SUM function by Anil, for chargeback there may be multiple lines
                          INTO ln_header_amount
                          FROM do_edi.do_edi810in_items
                         WHERE inv_header_id =
                               r_invoice_details.inv_header_id;
                    END IF;

                    fnd_file.put_line (FND_FILE.LOG,
                                       'Final Total' || ln_header_amount);

                    ------------------------------

                    l_group_id             :=
                        'EDI-' || TO_CHAR (SYSTIMESTAMP, 'hh24missFF');

                    -- Added as per CCR0009458

                    IF r_invoice_details.is_chargeback_required <> 'YES'
                    THEN
                        l_terms_id   := NULL;

                        BEGIN
                            SELECT apsa.terms_id
                              INTO l_terms_id
                              FROM apps.ap_supplier_sites_all apsa
                             WHERE     apsa.vendor_site_id =
                                       r_invoice_details.vendor_site_id
                                   AND apsa.org_id = r_invoice_details.org_id
                                   AND NVL (apsa.pay_site_flag, 'N') = 'Y';
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_terms_id   := NULL;
                        END;

                        IF l_terms_id IS NULL
                        THEN
                            BEGIN
                                SELECT asa.terms_id
                                  INTO l_terms_id
                                  FROM apps.ap_suppliers asa
                                 WHERE asa.vendor_id =
                                       r_invoice_details.vendor_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    l_terms_id   := NULL;
                            END;
                        END IF;

                        IF     l_terms_id IS NULL
                           AND r_invoice_details.is_prepayment <> 'YES'
                        THEN
                            l_terms_id   := NULL;

                            BEGIN
                                SELECT term_id
                                  INTO l_terms_id
                                  FROM apps.ap_terms tl, apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                                 WHERE     1 = 1
                                       AND ffvs.flex_value_set_id =
                                           ffvl.flex_value_set_id
                                       AND ffvl.enabled_flag = 'Y'
                                       AND SYSDATE BETWEEN NVL (
                                                               ffvl.start_date_active,
                                                               SYSDATE)
                                                       AND NVL (
                                                               ffvl.end_date_active,
                                                               SYSDATE + 1)
                                       AND ffvs.flex_value_set_name =
                                           'XXD_GTN_APINV_PAY_TERMS'
                                       AND UPPER (ffvl.attribute1) =
                                           UPPER (tl.name)
                                       AND ffvl.value_category =
                                           'XXD_GTN_APINV_PAY_TERMS'
                                       AND ffvl.flex_value = 'STANDARD';
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    l_terms_id   := NULL;
                            END;
                        ELSIF     l_terms_id IS NULL
                              AND r_invoice_details.is_prepayment = 'YES'
                        THEN
                            l_terms_id   := NULL;

                            BEGIN
                                SELECT term_id
                                  INTO l_terms_id
                                  FROM apps.ap_terms tl, apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                                 WHERE     1 = 1
                                       AND ffvs.flex_value_set_id =
                                           ffvl.flex_value_set_id
                                       AND ffvl.enabled_flag = 'Y'
                                       AND SYSDATE BETWEEN NVL (
                                                               ffvl.start_date_active,
                                                               SYSDATE)
                                                       AND NVL (
                                                               ffvl.end_date_active,
                                                               SYSDATE + 1)
                                       AND ffvs.flex_value_set_name =
                                           'XXD_GTN_APINV_PAY_TERMS'
                                       AND UPPER (ffvl.attribute1) =
                                           UPPER (tl.name)
                                       AND ffvl.value_category =
                                           'XXD_GTN_APINV_PAY_TERMS'
                                       AND ffvl.flex_value = 'PREPAYMENT';
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    l_terms_id   := NULL;
                            END;
                        END IF;
                    ELSIF r_invoice_details.is_chargeback_required = 'YES'
                    THEN
                        l_terms_id   := NULL;

                        BEGIN
                            SELECT term_id
                              INTO l_terms_id
                              FROM apps.ap_terms tl, apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                             WHERE     1 = 1
                                   AND ffvs.flex_value_set_id =
                                       ffvl.flex_value_set_id
                                   AND ffvl.enabled_flag = 'Y'
                                   AND SYSDATE BETWEEN NVL (
                                                           ffvl.start_date_active,
                                                           SYSDATE)
                                                   AND NVL (
                                                           ffvl.end_date_active,
                                                           SYSDATE + 1)
                                   AND ffvs.flex_value_set_name =
                                       'XXD_GTN_APINV_PAY_TERMS'
                                   AND UPPER (ffvl.attribute1) =
                                       UPPER (tl.name)
                                   AND ffvl.value_category =
                                       'XXD_GTN_APINV_PAY_TERMS'
                                   AND ffvl.flex_value = 'CREDIT';
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_terms_id   := NULL;
                        END;
                    END IF;


                    -- End of Change for CCR0009458

                    BEGIN
                        IF P_DEBUG = 'Y'
                        THEN
                            fnd_file.put_line (FND_FILE.LOG, 'A7');
                        END IF;

                        SELECT COUNT (*)
                          INTO l_count_1
                          FROM apps.ap_invoices_interface
                         WHERE     invoice_num =
                                   r_invoice_details.invoice_number
                               AND vendor_id = r_invoice_details.vendor_id
                               AND org_id = r_invoice_details.org_id;

                        IF P_DEBUG = 'Y'
                        THEN
                            fnd_file.put_line (FND_FILE.LOG, 'A8');
                        END IF;

                        SELECT COUNT (*)
                          INTO l_count_2
                          FROM AP.AP_INVOICES_ALL
                         WHERE     invoice_num =
                                   r_invoice_details.invoice_number
                               AND cancelled_date IS NULL
                               AND vendor_id = r_invoice_details.vendor_id
                               AND org_id = r_invoice_details.org_id;

                        IF P_DEBUG = 'Y'
                        THEN
                            fnd_file.put_line (FND_FILE.LOG, 'A9');
                        END IF;

                        IF l_count_1 = 0 AND l_count_2 = 0
                        THEN
                            INSERT INTO apps.ap_invoices_interface (
                                            invoice_id,
                                            invoice_num,
                                            invoice_type_lookup_code,
                                            invoice_date,
                                            vendor_id,
                                            vendor_site_id,
                                            invoice_amount,
                                            invoice_currency_code,
                                            terms_id,
                                            org_id,
                                            creation_date,
                                            last_update_date,
                                            created_by,
                                            last_updated_by,
                                            terms_date,
                                            ship_to_location,
                                            gl_date,
                                            source,
                                            GROUP_ID,
                                            invoice_received_date,
                                            remit_to_supplier_name,
                                            remit_to_supplier_id,
                                            remit_to_supplier_site,
                                            remit_to_supplier_site_id,
                                            pay_group_lookup_code,
                                            payment_method_lookup_code,
                                            attribute_category,
                                            attribute5,
                                            attribute6,
                                            payment_method_code,
                                            prepay_num, -- Added Prepayment fields by Anil as part of GTN Phase2 changes
                                            prepay_dist_num,
                                            prepay_apply_amount)
                                     VALUES (
                                                l_invoice_id,
                                                r_invoice_details.invoice_number,
                                                l_invoice_type_lookup_code,
                                                r_invoice_details.invoice_date,
                                                r_invoice_details.vendor_id,
                                                r_invoice_details.vendor_site_id,
                                                ln_header_amount, -- Modified by Anil, validated the amount with line amount
                                                l_invoice_currency_code,
                                                l_terms_id,
                                                r_invoice_details.org_id,
                                                SYSDATE,
                                                SYSDATE,
                                                fnd_global.user_id,
                                                fnd_global.user_id,
                                                r_invoice_details.invoice_date,
                                                l_ship_to_location_id,
                                                SYSDATE,
                                                r_invoice_details.source,
                                                l_group_id,
                                                r_invoice_details.received_date,
                                                r_invoice_details.vendor_name,
                                                r_invoice_details.vendor_id,
                                                l_vendor_site_code,
                                                r_invoice_details.vendor_site_id,
                                                r_invoice_details.pay_group_lookup_code,
                                                r_invoice_details.payment_method_lookup_code,
                                                l_attribute_category,
                                                l_Header_array_27,
                                                l_Header_array_28,
                                                r_invoice_details.pay_group_lookup_code, --Added by Anil, this was missed from Deckers Apps code
                                                lv_prepay_number, -- Added Prepayment fields by Anil as part of GTN Phase2 changes
                                                lv_prepay_dist_number,
                                                ln_prepay_apply_amount);

                            IF P_DEBUG = 'Y'
                            THEN
                                fnd_file.put_line (FND_FILE.LOG, 'A10');
                            END IF;
                        ELSIF (l_count_1 > 0)
                        THEN
                            fnd_file.put_line (
                                FND_FILE.LOG,
                                   'Invoice number '
                                || r_invoice_details.invoice_number
                                || ' already exists in the interface table');
                            l_error_flag   := TRUE;
                        ELSIF l_count_2 > 0
                        THEN
                            fnd_file.put_line (
                                FND_FILE.LOG,
                                   'Invoice '
                                || r_invoice_details.invoice_number
                                || ' already exists in Oracle');
                            l_error_flag   := TRUE;
                        END IF;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                FND_FILE.LOG,
                                   'Invoice number '
                                || r_invoice_details.invoice_number
                                || ' error while inserting into ap_invoices_interface '
                                || SQLERRM);
                            l_error_flag   := TRUE;
                    END;

                    IF NOT l_error_flag
                    THEN
                        IF P_DEBUG = 'Y'
                        THEN
                            fnd_file.put_line (FND_FILE.LOG, 'A11');
                        END IF;

                        FOR r_getCostDetails
                            IN c_getCostDetails (
                                   r_invoice_details.inv_header_id,
                                   r_invoice_details.is_chargeback_required,
                                   r_invoice_details.is_prepayment)
                        LOOP
                            IF (r_invoice_details.is_chargeback_required = 'YES' OR r_invoice_details.is_prepayment = 'YES') -- Added Prepayment condition by Anil as part of GTN Phase2 changes
                            THEN
                                IF P_DEBUG = 'Y'
                                THEN
                                    fnd_file.put_line (FND_FILE.LOG, 'A12');
                                END IF;

                                l_Line_array_4   :=
                                    r_getCostDetails.line_amount;
                                l_Line_array_5   := NULL;
                                l_Line_array_6   := NULL;
                                l_Line_array_7   := NULL;
                            ELSE
                                IF P_DEBUG = 'Y'
                                THEN
                                    fnd_file.put_line (FND_FILE.LOG, 'A13');
                                END IF;

                                l_Line_array_4   :=
                                    r_getCostDetails.line_amount;
                                l_Line_array_5   :=
                                    r_getCostDetails.unit_price;
                                l_Line_array_6   := r_getCostDetails.quantity;
                                l_Line_array_7   :=
                                    r_getCostDetails.description;
                            END IF;

                            IF (r_invoice_details.is_chargeback_required = 'YES' OR r_invoice_details.is_prepayment = 'YES') -- Added Prepayment condition by Anil as part of GTN Phase2 changes
                            THEN
                                IF P_DEBUG = 'Y'
                                THEN
                                    fnd_file.put_line (FND_FILE.LOG, 'A14');
                                END IF;

                                l_Line_array_14   := NULL;
                                l_Line_array_15   := NULL;
                                l_Line_array_16   := NULL;
                                l_Line_array_17   := NULL;
                                l_Line_array_18   := NULL;
                            ELSE
                                IF P_DEBUG = 'Y'
                                THEN
                                    fnd_file.put_line (FND_FILE.LOG, 'A15');
                                END IF;

                                l_Line_array_14   :=
                                    r_getCostDetails.po_header_id;
                                l_Line_array_15   :=
                                    r_getCostDetails.po_line_id;
                                l_Line_array_16   :=
                                    r_getCostDetails.po_line_location_id;
                                l_Line_array_17   := l_UOM;
                                l_Line_array_18   :=
                                    r_getCostDetails.inventory_item_id;
                            END IF;

                            IF (r_invoice_details.is_chargeback_required = 'YES' OR r_invoice_details.is_prepayment = 'YES') -- Added Prepayment condition by Anil as part of GTN Phase2 changes
                            THEN
                                IF P_DEBUG = 'Y'
                                THEN
                                    fnd_file.put_line (FND_FILE.LOG, 'A16');
                                END IF;

                                l_Line_array_21   :=
                                    apps.glcode_to_ccid (
                                        r_getCostDetails.GL_CODE);
                                l_Line_array_22   :=
                                    apps.glcode_to_ccid (
                                        r_getCostDetails.GL_CODE);
                            ELSE
                                l_Line_array_21   := NULL;
                                l_Line_array_22   := NULL;
                            END IF;

                            /* Deriving Ship to location id
                             If PO is a dropship PO, currently in BT(API), ship to location is dervied from Customer ship to location,
                               which is causing Ship to location required at line level issue.

                               To resolve this, we are deriving Ship to location based on Vendor site and passing to lines interface

                               Decect #2810
                           */
                            /* --CCR0007979 Changes start
                           BEGIN
                                SELECT ship_to_location_id
                                INTO l_ship_to_location_id
                                FROM apps.ap_supplier_sites_all
                                WHERE vendor_site_id =  r_invoice_details.vendor_site_id
                                and org_id = r_invoice_details.org_id;

                           EXCEPTION
                           WHEN OTHERS
                           THEN

                               fnd_file.put_line (FND_FILE.LOG, 'Erron in Line Cursor: While deriving Ship to location');


                           END;
                           */
                            BEGIN
                                SELECT get_ship_to_location (
                                           r_invoice_details.is_chargeback_required,
                                           r_getCostDetails.po_header_id,
                                           r_invoice_details.invoice_ref,
                                           r_invoice_details.vendor_id,
                                           r_invoice_details.vendor_site_id)
                                  INTO l_ship_to_location_id
                                  FROM DUAL;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    l_ship_to_location_id   := 0;
                                    fnd_file.put_line (
                                        FND_FILE.LOG,
                                        'Erron in Line Cursor: While deriving Ship to location');
                            END;



                            --CCR0007979 Changes end
                            BEGIN
                                IF P_DEBUG = 'Y'
                                THEN
                                    fnd_file.put_line (FND_FILE.LOG, 'A17');
                                END IF;

                                l_invoice_line_id   :=
                                    apps.ap_invoice_lines_interface_s.NEXTVAL;

                                IF P_DEBUG = 'Y'
                                THEN
                                    fnd_file.put_line (FND_FILE.LOG, 'A18');
                                END IF;

                                INSERT INTO apps.ap_invoice_lines_interface (
                                                invoice_id,
                                                invoice_line_id,
                                                line_type_lookup_code,
                                                amount,
                                                unit_price,
                                                quantity_invoiced,
                                                description,
                                                org_id,
                                                creation_date,
                                                last_update_date,
                                                created_by,
                                                last_updated_by,
                                                match_option,
                                                po_header_id,
                                                po_line_id,
                                                po_line_location_id,
                                                po_unit_of_measure,
                                                inventory_item_id,
                                                packing_slip,
                                                accounting_date,
                                                Default_dist_ccid,
                                                dist_code_combination_id,
                                                ship_to_location_id)
                                         VALUES (l_invoice_id,
                                                 l_invoice_line_id,
                                                 l_line_type_lookup_code, ---r_getCostDetails.line_type_lookup_code;
                                                 l_Line_array_4,     -- amount
                                                 l_Line_array_5, -- unit_price
                                                 l_Line_array_6, --quantity_invoiced
                                                 l_Line_array_7, --description
                                                 --   TO_CHAR (l_poh_org_id),
                                                 r_invoice_details.org_id,
                                                 SYSDATE,      --creation_date
                                                 SYSDATE,   --last_update_date
                                                 FND_GLOBAL.user_ID, --created_by
                                                 FND_GLOBAL.user_ID, --last_updated_by
                                                 NULL, ---comment 'match_option' --- Not sure what is this, will check this one.
                                                 l_Line_array_14, --po_header_id
                                                 l_Line_array_15, --po_line_id
                                                 l_Line_array_16, --po_line_location_id
                                                 l_Line_array_17, --po_unit_of_measure
                                                 l_Line_array_18, --inventory_item_id
                                                 r_getCostDetails.bol_number, --Packing Slip
                                                 SYSDATE,    --accounting_date
                                                 l_Line_array_21, --Default_dist_ccid
                                                 l_Line_array_21, --dist_code_combination_id
                                                 l_ship_to_location_id); --Defect#2810

                                IF P_DEBUG = 'Y'
                                THEN
                                    fnd_file.put_line (FND_FILE.LOG, 'A19');
                                END IF;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    IF P_Debug = 'Y'
                                    THEN
                                        fnd_file.put_line (
                                            FND_FILE.LOG,
                                               'Invoice Line ID '
                                            || l_invoice_line_id
                                            || ' error out while import in table ap_invoice_lines_interface');
                                    END IF;

                                    l_error_flag   := TRUE;
                            END;
                        END LOOP;
                    END IF;

                    IF (r_invoice_details.is_chargeback_required = 'YES' OR r_invoice_details.is_prepayment = 'YES')
                    THEN
                        IF l_Line_array_21 IS NULL -- Added by Anil, bug identified in UAT testing, if GL code is null for Prepayment/Chargeback then do not process
                        THEN
                            l_error_flag   := TRUE;

                            IF P_Debug = 'Y'
                            THEN
                                fnd_file.put_line (
                                    FND_FILE.LOG,
                                       'Invoice number '
                                    || r_invoice_details.invoice_number
                                    || 'has GL code NULL or GL code is not exisisting in Oracle');
                            END IF;

                            DELETE FROM apps.ap_invoices_interface
                                  WHERE invoice_id = l_invoice_id;

                            DELETE FROM apps.ap_invoice_lines_interface
                                  WHERE invoice_id = l_invoice_id;

                            UPDATE do_edi.DO_EDI810IN_headers
                               SET process_status   = 'E'
                             WHERE INV_HEADER_ID =
                                   r_invoice_details.inv_header_id;

                            COMMIT;

                            EXIT;
                        END IF;
                    END IF;

                    IF NOT l_error_flag
                    THEN
                        IF P_DEBUG = 'Y'
                        THEN
                            fnd_file.put_line (FND_FILE.LOG, 'A20');
                        END IF;

                        UPDATE do_edi.DO_EDI810IN_headers
                           SET process_status   = 'P'
                         WHERE     process_status IN ('A', 'R', 'E')
                               AND INV_HEADER_ID =
                                   r_invoice_details.inv_header_id;

                        IF P_DEBUG = 'Y'
                        THEN
                            fnd_file.put_line (FND_FILE.LOG, 'A21');
                            fnd_file.put_line (
                                FND_FILE.LOG,
                                'A21: l_group_id: ' || l_group_id);
                            fnd_file.put_line (
                                FND_FILE.LOG,
                                   'A21: r_invoice_details.source: '
                                || r_invoice_details.source);
                            fnd_file.put_line (
                                FND_FILE.LOG,
                                'A21: l_group_id: ' || l_group_id);
                            fnd_file.put_line (
                                FND_FILE.LOG,
                                   'A21: l_batch_error_flag: '
                                || l_batch_error_flag);
                            fnd_file.put_line (
                                FND_FILE.LOG,
                                   'A21: l_invoices_fetched: '
                                || l_invoices_fetched);
                            fnd_file.put_line (
                                FND_FILE.LOG,
                                   'A21: l_invoices_created: '
                                || l_invoices_created);
                            fnd_file.put_line (
                                FND_FILE.LOG,
                                   'A21: l_total_invoice_amount: '
                                || l_total_invoice_amount);
                            fnd_file.put_line (
                                FND_FILE.LOG,
                                'A21: l_print_batch: ' || l_print_batch);
                            fnd_file.put_line (
                                FND_FILE.LOG,
                                   'A21: fnd_global.conc_request_id: '
                                || fnd_global.conc_request_id);
                        END IF;



                        l_return_val   :=
                            APPS.DO_AP_UTILS.IMPORT_INVOICES (
                                p_batch_name         => l_group_id,
                                p_gl_date            => SYSDATE,
                                p_hold_code          => NULL,
                                p_hold_reason        => NULL,
                                p_commit_cycles      => NULL,
                                p_source             => r_invoice_details.source,
                                p_group_id           => l_group_id,
                                p_conc_request_id    => NULL,
                                p_debug_switch       => 'N',
                                p_batch_error_flag   => l_batch_error_flag,
                                p_invoices_fetched   => l_invoices_fetched,
                                p_invoices_created   => l_invoices_created,
                                p_total_invoice_amount   =>
                                    l_total_invoice_amount,
                                p_print_batch        => l_print_batch,
                                p_calling_sequence   => 200,
                                p_API_commit         => 'N',
                                p_org_id             =>
                                    r_invoice_details.org_id);

                        IF P_DEBUG = 'Y'
                        THEN
                            fnd_file.put_line (FND_FILE.LOG, 'A22');
                        END IF;

                        BEGIN
                            l_return_value   := 0;

                            IF P_DEBUG = 'Y'
                            THEN
                                fnd_file.put_line (FND_FILE.LOG, 'A23');
                            END IF;

                            SELECT COUNT (1)
                              INTO l_return_value
                              FROM apps.ap_invoices_all
                             WHERE     invoice_num =
                                       r_invoice_details.invoice_number
                                   AND org_id = r_invoice_details.org_id;

                            IF P_DEBUG = 'Y'
                            THEN
                                fnd_file.put_line (FND_FILE.LOG, 'A24');
                            END IF;

                            IF P_Debug = 'Y'
                            THEN
                                fnd_file.put_line (
                                    FND_FILE.LOG,
                                       'Return Value For Invoice Creation : '
                                    || l_return_value);
                            END IF;
                        END;


                        IF l_return_value = 0
                        THEN
                            IF P_Debug = 'Y'
                            THEN
                                fnd_file.put_line (
                                    FND_FILE.LOG,
                                       'Error while importing invoice number : '
                                    || r_invoice_details.invoice_number);

                                FOR cur_i
                                    IN (  SELECT parent_table, parent_id, reject_lookup_code
                                            FROM ap_interface_rejections
                                           WHERE    (parent_table = 'AP_INVOICES_INTERFACE' AND parent_id = l_invoice_id)
                                                 OR (parent_table = 'AP_INVOICE_LINES_INTERFACE' AND parent_id = l_invoice_line_id)
                                        ORDER BY PARENT_TABLE, PARENT_ID)
                                LOOP
                                    fnd_file.put_line (
                                        FND_FILE.LOG,
                                           cur_i.parent_table
                                        || ' : '
                                        || cur_i.parent_id
                                        || ' : '
                                        || cur_i.reject_lookup_code);
                                END LOOP;
                            END IF;
                        ELSIF l_return_value = 1
                        THEN
                            IF P_Debug = 'Y'
                            THEN
                                fnd_file.put_line (
                                    FND_FILE.LOG,
                                       'Invoice imported for invoice number : '
                                    || r_invoice_details.invoice_number);
                            END IF;
                        END IF;

                        IF l_return_value = 1
                        THEN
                            BEGIN
                                l_invoice_id   := 0;

                                IF P_DEBUG = 'Y'
                                THEN
                                    fnd_file.put_line (FND_FILE.LOG, 'A25');
                                END IF;

                                SELECT invoice_id
                                  INTO l_invoice_id
                                  FROM apps.ap_invoices_all
                                 WHERE     invoice_num =
                                           r_invoice_details.invoice_number
                                       AND org_id = r_invoice_details.org_id;

                                IF P_Debug = 'Y'
                                THEN
                                    fnd_file.put_line (
                                        FND_FILE.LOG,
                                        'Invoice ID : ' || l_invoice_id);
                                END IF;
                            END;

                            IF P_DEBUG = 'Y'
                            THEN
                                fnd_file.put_line (FND_FILE.LOG, 'A26');
                                fnd_file.put_line (
                                    FND_FILE.LOG,
                                    'A26: FND_GLOBAL.USER_ID: ' || FND_GLOBAL.USER_ID);
                                fnd_file.put_line (
                                    FND_FILE.LOG,
                                    'A26: l_invoice_id: ' || l_invoice_id);
                                fnd_file.put_line (
                                    FND_FILE.LOG,
                                    'A26: l_holds_count: ' || l_holds_count);
                                fnd_file.put_line (
                                    FND_FILE.LOG,
                                       'A26: l_approval_status: '
                                    || l_approval_status);
                                fnd_file.put_line (FND_FILE.LOG,
                                                   'A26: l_msg: ' || l_msg);
                            END IF;

                            IF UPPER (
                                   NVL (
                                       r_invoice_details.invoice_type_lookup_code,
                                       'COMMERCIAL')) =
                               'PRESENTMENT' -- Added Prepayment condition by Anil as part of GTN Phase2 changes
                            THEN
                                BEGIN
                                    APPS.MO_GLOBAL.set_policy_context (
                                        'S',
                                        r_invoice_details.org_id);

                                    APPS.AP_HOLDS_PKG.insert_single_hold (
                                        l_invoice_id,           --X_invoice_id
                                        'GTN Prepayment Hold', --X_hold_lookup_code
                                        NULL,                    --X_hold_type
                                        'GTNEXUS',             --X_hold_reason
                                        NULL,                      --X_held_by
                                        NULL              --X_calling_sequence
                                            );

                                    fnd_file.put_line (
                                        FND_FILE.LOG,
                                           'Invoice Holds Count for Prepayment invoice number : '
                                        || r_invoice_details.invoice_number
                                        || ': '
                                        || 1);
                                    fnd_file.put_line (
                                        FND_FILE.LOG,
                                           'Approval status for Prepayment invoice number : '
                                        || r_invoice_details.invoice_number
                                        || ': '
                                        || 'Unvalidated');


                                    l_total_prepay_inv_processed   :=
                                        l_total_prepay_inv_processed + 1;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        fnd_file.put_line (
                                            FND_FILE.LOG,
                                               'Failed in applying Invoice Hold for Prepayment invoice number : '
                                            || r_invoice_details.invoice_number);
                                END;

                                IF P_Validate_Only = 'N'
                                THEN
                                    COMMIT;
                                ELSE
                                    ROLLBACK TO start_process_loop;
                                END IF;
                            ELSE
                                --- Call invoice approval process
                                APPS.DO_AP_UTILS.AUTHORIZE_AP_INVOICE (
                                    p_UserID            => FND_GLOBAL.USER_ID,
                                    p_InvoiceID         => l_invoice_id,
                                    x_holds_count       => l_holds_count,
                                    x_approval_status   => l_approval_status,
                                    x_msg               => l_msg,
                                    p_API_commit        => 'N');

                                fnd_file.put_line (
                                    FND_FILE.LOG,
                                       'Holds Count for invoice number : '
                                    || r_invoice_details.invoice_number
                                    || ': '
                                    || l_holds_count);
                                fnd_file.put_line (
                                    FND_FILE.LOG,
                                       'Approval status for invoice number : '
                                    || r_invoice_details.invoice_number
                                    || ': '
                                    || l_approval_status);
                                fnd_file.put_line (FND_FILE.LOG,
                                                   'Message : ' || l_msg);

                                IF P_DEBUG = 'Y'
                                THEN
                                    fnd_file.put_line (FND_FILE.LOG, 'A27');
                                END IF;

                                IF l_approval_status IN
                                       ('APPROVED', 'NEEDS REAPPROVAL')
                                THEN
                                    IF P_Validate_Only = 'N'
                                    THEN
                                        COMMIT;
                                    ELSE
                                        ROLLBACK TO start_process_loop;
                                    END IF;

                                    IF l_approval_status IN
                                           ('NEEDS REAPPROVAL')
                                    THEN
                                        l_total_inv_need_reapproval   :=
                                            l_total_inv_need_reapproval + 1;
                                    ELSIF l_approval_status IN ('APPROVED')
                                    THEN
                                        l_total_inv_approved   :=
                                            l_total_inv_approved + 1;
                                    END IF;

                                    IF P_DEBUG = 'Y'
                                    THEN
                                        fnd_file.put_line (FND_FILE.LOG,
                                                           'A28');
                                    END IF;
                                END IF;
                            END IF;

                            l_current_invoice   :=
                                r_invoice_details.invoice_number;

                            IF P_DEBUG = 'Y'
                            THEN
                                fnd_file.put_line (FND_FILE.LOG, 'A29');
                            END IF;
                        END IF;
                    END IF;
                ELSE
                    IF P_DEBUG = 'Y'
                    THEN
                        fnd_file.put_line (FND_FILE.LOG, 'A30');
                    END IF;

                    IF l_ship_to_location_id > 1
                    THEN
                        fnd_file.put_line (
                            FND_FILE.LOG,
                               'multiple location attached with invoice number : '
                            || TO_CHAR (r_invoice_details.invoice_number));
                    END IF;

                    IF l_poh_org_id > 1
                    THEN
                        IF P_DEBUG = 'Y'
                        THEN
                            fnd_file.put_line (FND_FILE.LOG, 'A31');
                        END IF;

                        fnd_file.put_line (
                            FND_FILE.LOG,
                               'multiple organization attached with invoice number : '
                            || TO_CHAR (r_invoice_details.invoice_number));
                    END IF;
                END IF;

                IF P_DEBUG = 'Y'
                THEN
                    fnd_file.put_line (FND_FILE.LOG, 'A32');
                END IF;

                IF l_current_invoice <>
                   TO_CHAR (r_invoice_details.invoice_number)
                THEN
                    IF P_DEBUG = 'Y'
                    THEN
                        fnd_file.put_line (FND_FILE.LOG, 'A34');
                    END IF;

                    fnd_file.put_line (
                        FND_FILE.LOG,
                           'Invoice processing error out for invoice number : '
                        || TO_CHAR (r_invoice_details.invoice_number));
                END IF;

                IF P_DEBUG = 'Y'
                THEN
                    fnd_file.put_line (FND_FILE.LOG, 'A35');
                END IF;
            END LOOP;
        EXCEPTION
            WHEN OTHERS
            THEN
                ROLLBACK;

                IF P_Debug = 'Y'
                THEN
                    fnd_file.put_line (FND_FILE.LOG, ' Error: ' || SQLERRM);
                END IF;
        END;

        ROLLBACK;

        fnd_file.put_line (
            FND_FILE.OUTPUT,
            '==============================================================================');
        fnd_file.put_line (
            FND_FILE.OUTPUT,
            'Concurrent Program Name: XXDO GTN To EBS Invoice Import Approval');
        fnd_file.put_line (
            FND_FILE.OUTPUT,
            'Concurrent Request ID: ' || fnd_global.conc_request_id);
        fnd_file.put_line (FND_FILE.OUTPUT,
                           '    P_Validate_Only: ' || P_Validate_Only);
        fnd_file.put_line (FND_FILE.OUTPUT, '    P_Debug: ' || P_Debug);
        fnd_file.put_line (
            FND_FILE.OUTPUT,
            '==============================================================================');
        fnd_file.put_line (
            FND_FILE.OUTPUT,
            'Total invoice processed   : ' || TO_CHAR (l_total_eligible_inv));
        fnd_file.put_line (
            FND_FILE.OUTPUT,
               'Total Prepayment invoice processed: '
            || TO_CHAR (l_total_prepay_inv_processed));
        fnd_file.put_line (
            FND_FILE.OUTPUT,
            'Total invoice approved    : ' || TO_CHAR (l_total_inv_approved));
        fnd_file.put_line (
            FND_FILE.OUTPUT,
               'Total reapproval required : '
            || TO_CHAR (l_total_inv_need_reapproval));
        fnd_file.put_line (
            FND_FILE.OUTPUT,
               'Total invoice in error    : '
            || TO_CHAR (
                     l_total_eligible_inv
                   - l_total_inv_approved
                   - l_total_inv_need_reapproval));
        fnd_file.put_line (
            FND_FILE.OUTPUT,
            '==============================================================================');
        fnd_file.put_line (
            FND_FILE.OUTPUT,
            'For details of invoice processing refer to the concurrent request log file.');
        fnd_file.put_line (
            FND_FILE.OUTPUT,
            '==============================================================================');
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;

            IF P_Debug = 'Y'
            THEN
                fnd_file.put_line (FND_FILE.LOG, ' Error: ' || SQLERRM);
            END IF;
    END import_invoices;

    FUNCTION get_header_amount (
        p_inv_header_id IN DO_EDI.DO_EDI810IN_HEADERS.INV_HEADER_ID%TYPE) -- Added by Anil, to map sum of line amount to header
        RETURN NUMBER
    AS
        CURSOR cur_inv_lines IS
            SELECT ROUND (ROUND (l.unit_price, 2) * l.quantity, 2) line_amount
              FROM do_edi.do_edi810in_items l
             WHERE inv_header_id = p_inv_header_id;

        ln_amount   NUMBER := 0;
    BEGIN
        FOR rec_inv_lines IN cur_inv_lines
        LOOP
            ln_amount   := ln_amount + rec_inv_lines.line_amount;
        END LOOP;

        RETURN ln_amount;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
            fnd_file.put_line (
                FND_FILE.LOG,
                ' Error in Function get header amount: ' || SQLERRM);
    END get_header_amount;

    FUNCTION get_header_id (
        p_inv_header_id IN DO_EDI.DO_EDI810IN_HEADERS.INV_HEADER_ID%TYPE) -- Added by Anil, to get PO Header Id for Chargeback Invoices
        RETURN NUMBER
    AS
        ln_po_header_id   NUMBER := 0;
        lv_invoice_ref    VARCHAR2 (140);
    BEGIN
        SELECT DISTINCT invoice_ref
          INTO lv_invoice_ref
          FROM do_edi.do_edi810in_headers hl
         WHERE hl.inv_header_id = p_inv_header_id;

        SELECT po_header_id
          INTO ln_po_header_id
          FROM do_edi.do_edi810in_headers hk, do_edi.do_edi810in_items ik
         WHERE     1 = 1
               AND hk.chargeback_flag = 'Y'
               AND hk.invoice_ref = lv_invoice_ref
               AND ik.inv_header_id = hk.inv_header_id
               AND ROWNUM <= 1;

        RETURN ln_po_header_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
            fnd_file.put_line (
                FND_FILE.LOG,
                ' Error in Function get header id: ' || SQLERRM);
    END get_header_id;

    --CCR0007979 Changes start
    FUNCTION get_ship_to_location (is_chargeback_required   IN VARCHAR2,
                                   p_header_id              IN NUMBER,
                                   p_inv_num                IN VARCHAR2,
                                   p_vendor_id              IN VARCHAR2,
                                   p_vendor_site_id         IN NUMBER)
        RETURN NUMBER
    IS
        l_ship_to_location_id   NUMBER;
    BEGIN
        IF is_chargeback_required = 'NO'
        THEN
            BEGIN
                SELECT ship_to_location_id
                  INTO l_ship_to_location_id
                  FROM po_headers_all
                 WHERE po_header_id = p_header_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_ship_to_location_id   := 0;
            END;

            RETURN l_ship_to_location_id;
        ELSIF is_chargeback_required = 'YES'
        THEN
            BEGIN
                SELECT DISTINCT pha.ship_to_location_id
                  INTO l_ship_to_location_id
                  FROM ap.ap_invoices_all aia, ap.ap_invoice_distributions_all aida, po.po_distributions_all pda,
                       po.po_headers_all pha, po.po_lines_all pla
                 WHERE     aia.invoice_id = aida.invoice_id
                       AND aida.po_distribution_id =
                           pda.po_distribution_id(+)
                       AND pda.po_header_id = pha.po_header_id
                       AND pha.po_header_id = pla.po_header_id
                       AND pda.po_line_id = pla.po_line_id
                       AND pda.po_header_id IS NOT NULL
                       AND aia.invoice_num = p_inv_num
                       AND aia.vendor_id = p_vendor_id
                       AND aia.vendor_site_id = p_vendor_site_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_ship_to_location_id   := 0;
            END;

            RETURN l_ship_to_location_id;
        ELSE
            l_ship_to_location_id   := 0;
            RETURN l_ship_to_location_id;
        END IF;
    END get_ship_to_location;
--CCR0007979 Changes end
END XXDO_AP_INV_IMP_APPRV;
/
