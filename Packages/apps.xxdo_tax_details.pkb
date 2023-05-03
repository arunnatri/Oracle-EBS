--
-- XXDO_TAX_DETAILS  (Package Body) 
--
/* Formatted on 4/26/2023 4:32:13 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_TAX_DETAILS"
AS
    /***********************************************************************************
      *$header     :                                                                   *
      *                                                                                *
      * AUTHORS    :  Srinath Siricilla                                                *
      *                                                                                *
      * PURPOSE    :  Canada Tax Details Report - Deckers                                      *
      *                                                                                *
      * PARAMETERS :                                                                   *
      *                                                                                *
      * DATE       :  26-MAY-2017                                                      *
      *                                                                                *
      * Assumptions:                                                                   *
      *                                                                                *
      *                                                                                *
      * History                                                                        *
      * Vsn     Change Date  Changed By            Change Description                  *
      * -----   -----------  ------------------    ------------------------------------*
      * 1.0     26-MAY-2017  Srinath Siricilla     Initial Creation                    *
      * 1.1     02-OCT-2017  Infosys               Change as a part of CCR0006587
      * 1.2     25-APR-2020  Arun N Murthy         For CCR0008587                      *                                                *
      *********************************************************************************/

    FUNCTION MAIN
        RETURN BOOLEAN
    IS
        lv_from_date   DATE;
        lv_to_date     DATE;
        lv_org_id      NUMBER;
    BEGIN
        IF     p_from_date IS NOT NULL
           AND p_to_date IS NOT NULL
           AND p_org_id IS NOT NULL
        THEN
            lv_from_date   := fnd_date.canonical_to_date (p_from_date);
            lv_to_date     := fnd_date.canonical_to_date (p_to_date);
            lv_org_id      := p_org_id;
            apps.fnd_file.put_line (fnd_file.LOG,
                                    'date from --> ' || lv_from_date);
            apps.fnd_file.put_line (fnd_file.LOG,
                                    'Date to --> ' || lv_to_date);
            apps.fnd_file.put_line (fnd_file.LOG, 'Org ID --> ' || p_org_id);

            EXECUTE IMMEDIATE 'truncate table XXD_AR_CAN_SALES_TAX_DETAILS';

            insert_staging (lv_from_date, lv_to_date, lv_org_id);
        END IF;

        RETURN (TRUE);
    END MAIN;

    PROCEDURE insert_staging (cp_from_date   IN DATE,
                              cp_to_date     IN DATE,
                              cpn_org_id     IN NUMBER)
    IS
        CURSOR c_ins_cur (cp_from_date   IN DATE,
                          cp_to_date     IN DATE,
                          cpn_org_id     IN NUMBER)
        IS
              SELECT rct.trx_number
                         trx_number,
                     rct.trx_date
                         trx_date,
                     rct.customer_trx_id
                         customer_trx_id,
                     NVL (rctl.extended_amount, 0)
                         net_amount,
                     rct.bill_to_site_use_id
                         bill_to_site_use_id,
                     rct.ship_to_site_use_id
                         ship_to_site_use_id,
                     rct.bill_to_customer_id
                         bill_to_customer_id,
                     rctl.customer_trx_line_id
                         customer_trx_line_id,
                     rctl.ship_to_site_use_id
                         line_ship_to_site_use_id,
                     rctl.line_type,
                     NVL (msi.style_number, 'NA')
                         item_number,
                     NVL (msi.color_code, 'NA')
                         color,
                     /* Start of change as a part of CCR0006587 */
                     --          rcta1.trx_number asso_trx_number,
                     --          rcta1.customer_trx_id asso_trx_id,
                     (   ''''''
                      || TO_CHAR (
                             (SELECT RTRIM (XMLAGG (XMLELEMENT (e, rct1.trx_number || ',')).EXTRACT ('//text()'), ',')
                                FROM ra_customer_trx_all rct1, apps.ar_receivable_applications_all araa1
                               WHERE     ARAA1.CUSTOMER_TRX_ID =
                                         RCT.CUSTOMER_TRX_ID
                                     AND NVL (araa1.DISPLAY, 'Y') = 'Y'
                                     AND rct1.customer_trx_id =
                                         araa1.applied_customer_trx_id)))
                         asso_trx_number,
                     TO_CHAR (
                         (SELECT RTRIM (XMLAGG (XMLELEMENT (e, rct1.customer_trx_id || ',')).EXTRACT ('//text()'), ',')
                            FROM ra_customer_trx_all rct1, apps.ar_receivable_applications_all araa1
                           WHERE     ARAA1.CUSTOMER_TRX_ID =
                                     RCT.CUSTOMER_TRX_ID
                                 AND NVL (araa1.DISPLAY, 'Y') = 'Y'
                                 AND rct1.customer_trx_id =
                                     araa1.applied_customer_trx_id))
                         asso_trx_id,
                     /* End of change as a part of CCR0006587 */
                     apsa.class
                         transaction_type,
                     apsa.payment_schedule_id,
                     --rctla1.customer_trx_line_id asso_customer_trx_line_id,
                     /* Start of change as a part of CCR0006587 */
                     --          rcta1.bill_to_site_use_id asso_bill_to_site_use_id,
                     --          rcta1.ship_to_site_use_id asso_ship_to_site_use_id,
                     --          rctla1.ship_to_site_use_id asso_line_ship_to_site_use_id,
                     --          rcta1.bill_to_customer_id asso_bill_to_customer_id,

                     (SELECT rct1.bill_to_site_use_id
                        FROM ra_customer_trx_all rct1, apps.ar_receivable_applications_all araa1
                       WHERE     ARAA1.CUSTOMER_TRX_ID = RCT.CUSTOMER_TRX_ID
                             AND NVL (araa1.DISPLAY, 'Y') = 'Y'
                             AND rct1.customer_trx_id =
                                 araa1.applied_customer_trx_id
                             AND rct1.bill_to_site_use_id IS NOT NULL
                             AND ROWNUM = 1)
                         asso_bill_to_site_use_id,
                     (SELECT rct1.bill_to_site_use_id
                        FROM ra_customer_trx_all rct1, apps.ar_receivable_applications_all araa1
                       WHERE     ARAA1.CUSTOMER_TRX_ID = RCT.CUSTOMER_TRX_ID
                             AND NVL (araa1.DISPLAY, 'Y') = 'Y'
                             AND rct1.customer_trx_id =
                                 araa1.applied_customer_trx_id
                             AND rct1.bill_to_site_use_id IS NOT NULL
                             AND ROWNUM = 1)
                         asso_ship_to_site_use_id,
                     (SELECT rctl1.ship_to_site_use_id
                        FROM ra_customer_trx_all rct1, ra_customer_trx_lines_all rctl1, apps.ar_receivable_applications_all araa1
                       WHERE     ARAA1.CUSTOMER_TRX_ID = RCT.CUSTOMER_TRX_ID
                             AND RCTL1.CUSTOMER_TRX_ID = RCT1.CUSTOMER_TRX_ID
                             AND NVL (araa1.DISPLAY, 'Y') = 'Y'
                             AND rct1.customer_trx_id =
                                 araa1.applied_customer_trx_id
                             AND rctl1.ship_to_site_use_id IS NOT NULL
                             AND ROWNUM = 1)
                         asso_line_ship_to_site_use_id,
                     (SELECT rct1.bill_to_customer_id
                        FROM ra_customer_trx_all rct1, apps.ar_receivable_applications_all araa1
                       WHERE     ARAA1.CUSTOMER_TRX_ID = RCT.CUSTOMER_TRX_ID
                             AND NVL (araa1.DISPLAY, 'Y') = 'Y'
                             AND rct1.customer_trx_id =
                                 araa1.applied_customer_trx_id
                             AND rct1.bill_to_site_use_id IS NOT NULL
                             AND ROWNUM = 1)
                         asso_bill_to_customer_id,
                     /* End of change as a part of CCR0006587 */
                     hou.name,
                     hou.organization_id
                FROM apps.ra_customer_trx_all rct, apps.ra_customer_trx_lines_all rctl, apps.hr_operating_units hou,
                     apps.xxd_common_items_v msi, apps.ar_payment_schedules_all apsa
               /* Start of change as a part of CCR0006587 */
               --          ,apps.ar_receivable_applications_all araa
               --          ,apps.ar_payment_schedules_all apsa1
               --          ,apps.ra_customer_trx_all rcta1
               --          ,apps.ra_customer_trx_lines_all rctla1
               /* End of change as a part of CCR0006587 */
               WHERE     1 = 1
                     AND rct.customer_trx_id = rctl.customer_trx_id
                     AND rctl.line_type = 'LINE'
                     AND apsa.customer_trx_id = rct.customer_trx_id
                     AND apsa.org_id = hou.organization_id
                     AND apsa.class <> 'PMT'
                     AND rctl.inventory_item_id = msi.inventory_item_id(+)
                     AND msi.organization_id(+) = 106
                     AND rct.org_id = hou.organization_id
                     AND rctl.org_id = hou.organization_id
                     AND hou.organization_id = cpn_org_id
                     /* End of change as a part of CCR0006587 */
                     --      AND araa.payment_schedule_id(+) = apsa.payment_schedule_id
                     --      AND araa.applied_payment_schedule_id = apsa1.payment_schedule_id(+)
                     --      AND araa.applied_customer_trx_id = rcta1.customer_trx_id(+)
                     --      AND NVL(ARAA.DISPLAY, 'Y') = 'Y'  --Added as per CCR0006587
                     --      AND rcta1.customer_trx_id = rctla1.customer_trx_id(+)
                     --      AND rctla1.line_type(+) ='LINE'
                     /* End of change as a part of CCR0006587 */
                     AND NVL (rct.complete_flag, 'Y') = 'Y'
                     AND rct.trx_date BETWEEN cp_from_date AND cp_to_date
            GROUP BY rct.trx_number, rct.trx_date, rct.customer_trx_id,
                     rct.bill_to_site_use_id, rct.ship_to_site_use_id, rct.bill_to_customer_id,
                     rctl.ship_to_site_use_id, rctl.customer_trx_line_id, rctl.extended_amount,
                     rctl.line_type, msi.style_number, msi.color_code,
                     apsa.class, apsa.payment_schedule_id/* Start of change as a part of CCR0006587 */
                                                         -- , rcta1.trx_number
                                                         -- , rcta1.customer_trx_id
                                                         --, rcta1.bill_to_site_use_id
                                                         --, rcta1.ship_to_site_use_id
                                                         --, rctla1.ship_to_site_use_id
                                                         --, rcta1.bill_to_customer_id
                                                         /* End of change as a part of CCR0006587 */
                                                         , hou.name,
                     hou.organization_id, NVL (rctl.extended_amount, 0), NVL (msi.style_number, 'NA'),
                     NVL (msi.color_code, 'NA')
            UNION
              SELECT adj.adjustment_number, adj.APPLY_DATE, TO_NUMBER (NULL),
                     TO_NUMBER (NULL), TO_NUMBER (NULL), TO_NUMBER (NULL),
                     TO_NUMBER (NULL), TO_NUMBER (NULL), TO_NUMBER (NULL),
                     TO_CHAR (NULL), TO_CHAR (NULL), TO_CHAR (NULL),
                     TO_CHAR (rct.TRX_NUMBER), TO_CHAR (rct.customer_trx_id), 'ADJ',
                     TO_NUMBER (NULL), --rctl.customer_trx_line_id,
                                       rct.bill_to_site_use_id, rct.ship_to_site_use_id,
                     rctl.ship_to_site_use_id, rct.bill_to_customer_id, hou.name,
                     hou.organization_id
                FROM apps.ar_adjustments_all adj, apps.ra_customer_trx_all rct, apps.ra_customer_trx_lines_all rctl,
                     apps.hr_operating_units hou
               WHERE     adj.customer_trx_id = rct.customer_trx_id
                     AND rct.customer_trx_id = rctl.customer_trx_id
                     AND rctl.line_type(+) = 'LINE'
                     AND rct.org_id = rctl.org_id
                     AND hou.organization_id = rctl.org_id
                     AND adj.org_id = hou.organization_id
                     AND hou.organization_id = cpn_org_id
                     AND adj.apply_date BETWEEN cp_from_date AND cp_to_date
            GROUP BY adj.adjustment_number, adj.APPLY_DATE, rct.customer_trx_id,
                     --rctl.customer_trx_line_id,
                     rct.bill_to_site_use_id, rct.ship_to_site_use_id, rctl.ship_to_site_use_id,
                     rct.bill_to_customer_id, rct.trx_number, hou.name,
                     hou.organization_id;

        lv_ship_province        hz_locations.province%TYPE;
        lv_bill_province        hz_locations.province%TYPE;
        lv_asso_bill_province   hz_locations.province%TYPE;
        lv_asso_ship_province   hz_locations.province%TYPE;
        lv_party_name           hz_parties.party_name%TYPE;
        lv_rep_bill_Province    hz_locations.province%TYPE;
        lv_rep_ship_Province    hz_locations.province%TYPE;
    BEGIN
        apps.fnd_file.put_line (fnd_file.LOG,
                                'STEP1 --> Before Entering Loop');

        FOR i IN c_ins_cur (cp_from_date, cp_to_date, cpn_org_id)
        LOOP
            lv_ship_province        := NULL;
            lv_bill_province        := NULL;
            lv_asso_bill_province   := NULL;
            lv_asso_ship_province   := NULL;
            lv_party_name           := NULL;

            BEGIN
                SELECT trx_ship_to_province (NVL (i.line_ship_to_site_use_id, i.ship_to_site_use_id), i.organization_id)
                  INTO lv_ship_province
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_ship_province   := NULL;
            END;

            BEGIN
                SELECT trx_ship_to_province (NVL (i.asso_line_ship_to_site_use_id, i.asso_ship_to_site_use_id), i.organization_id)
                  INTO lv_asso_ship_province
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_asso_ship_province   := NULL;
            END;

            IF lv_ship_province IS NULL
            THEN
                lv_rep_ship_Province   :=
                    NVL (lv_ship_province, lv_asso_ship_province);
            END IF;

            BEGIN
                SELECT trx_bill_to_province (i.bill_to_site_use_id, i.organization_id)
                  INTO lv_bill_province
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_bill_province   := NULL;
            END;

            BEGIN
                SELECT trx_bill_to_province (i.asso_bill_to_site_use_id, i.organization_id)
                  INTO lv_asso_bill_province
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_asso_bill_province   := NULL;
            END;

            IF lv_bill_province IS NULL
            THEN
                lv_rep_bill_Province   :=
                    NVL (lv_bill_province, lv_asso_bill_province);
            END IF;

            BEGIN
                SELECT hzp.party_name
                  INTO lv_party_name
                  FROM apps.hz_parties hzp, apps.hz_cust_accounts hca
                 WHERE     hzp.party_id = hca.party_id
                       AND hca.cust_account_id =
                           NVL (i.bill_to_customer_id,
                                i.asso_bill_to_customer_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_party_name   := NULL;
            END;

            BEGIN
                INSERT INTO XXD_AR_CAN_SALES_TAX_DETAILS (
                                Operating_Unit,
                                Trx_Adj_Number,
                                trx_adj_date,
                                party_name,
                                Net_amount,
                                customer_trx_id,
                                bill_to_site_use_id,
                                ship_to_site_use_id,
                                cust_account_id,
                                customer_trx_line_id,
                                line_ship_to_site_use_id,
                                Item_number,
                                Item_color,
                                line_type,
                                Asso_trx_number,
                                asso_trx_id,
                                Transaction_Type,
                                payment_schedule_id,
                                --asso_customer_trx_line_id,
                                asso_bill_to_site_use_id,
                                asso_ship_to_site_use_id,
                                asso_line_ship_to_site_use_id,
                                asso_cust_account_id,
                                Bill_to_Province,
                                ship_to_province,
                                asso_Bill_to_Province,
                                asso_ship_to_province,
                                rep_bill_to_Province,
                                rep_ship_to_province)
                     VALUES (i.name, i.trx_number, i.trx_date,
                             lv_party_name, i.net_amount, i.customer_trx_id,
                             i.bill_to_site_use_id, i.ship_to_site_use_id, i.bill_to_customer_id, i.customer_trx_line_id, i.line_ship_to_site_use_id, i.Item_number, i.color, i.line_type, i.Asso_trx_number, i.Asso_trx_id, i.transaction_type, i.payment_schedule_id, --i.asso_customer_trx_line_id,
                                                                                                                                                                                                                                                                        i.asso_bill_to_site_use_id, i.asso_ship_to_site_use_id, i.asso_line_ship_to_site_use_id, i.asso_bill_to_customer_id, lv_bill_province, lv_ship_province, lv_asso_bill_province, lv_asso_ship_province, lv_bill_Province
                             , lv_ship_province);

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ROLLBACK;
                    apps.fnd_file.put_line (fnd_file.LOG,
                                            'STEP5 --> Perfomed Rollback');
            END;
        END LOOP;                                           -- End of For Loop
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END insert_staging;

    FUNCTION associated_Trx_number (pn_payment_schedule_id IN NUMBER)
        RETURN VARCHAR2
    IS
        pv_asso_trx_number   VARCHAR2 (60);
        lv_trx_number        VARCHAR2 (60);
    BEGIN
        --IF pv_trx_type IN ('CM','CB')
        --THEN
        BEGIN
            SELECT rcta.trx_number
              INTO pv_asso_trx_number
              FROM apps.ar_receivable_applications_all araa, apps.ra_customer_trx_all rcta, apps.ar_payment_schedules_all apsa
             WHERE     araa.applied_customer_trx_id = rcta.customer_trx_id
                   AND araa.applied_payment_schedule_id =
                       apsa.payment_schedule_id
                   AND araa.org_id = apsa.org_id
                   AND rcta.org_id = apsa.org_id
                   AND araa.payment_schedule_id = pn_payment_schedule_id;

            lv_trx_number   := pv_asso_trx_number;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_trx_number   := NULL;
        END;

        --ELSE
        -- lv_trx_number := NULL;
        ---END IF;
        RETURN lv_trx_number;
    END associated_Trx_number;

    FUNCTION trx_ship_to_province (pn_ship_to_site_use_id   IN NUMBER,
                                   pn_org_id                IN NUMBER)
        RETURN VARCHAR2
    IS
        ln_ship_province   hz_locations.province%TYPE;
    BEGIN
        ln_ship_province   := NULL;

        SELECT hl_ship.province
          INTO ln_ship_province
          FROM apps.hz_parties hp_ship, apps.hz_party_sites hps_ship, apps.hz_cust_acct_sites_all hcasa_ship,
               apps.hz_cust_site_uses_all hcsua_ship, apps.hz_locations hl_ship
         WHERE     1 = 1
               AND hps_ship.location_id = hl_ship.location_id(+)
               AND hps_ship.party_id = hp_ship.party_id(+)
               AND hcasa_ship.cust_acct_site_id(+) =
                   hcsua_ship.cust_acct_site_id
               AND hcasa_ship.party_site_id = hps_ship.party_site_id(+)
               AND hcsua_ship.site_use_code(+) = 'SHIP_TO'
               AND hcsua_ship.org_id = hcasa_ship.org_id
               AND hcsua_ship.site_use_id = pn_ship_to_site_use_id
               AND hcsua_ship.org_id = pn_org_id;

        RETURN ln_ship_province;
    EXCEPTION
        WHEN OTHERS
        THEN
            ln_ship_province   := NULL;
            RETURN ln_ship_province;
    END trx_ship_to_province;


    --StartChanges for CCR0008587
    FUNCTION get_lines_count (pn_customer_trx_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_lines_count   NUMBER;
    BEGIN
        SELECT COUNT (1)
          INTO ln_lines_count
          FROM ra_customer_trx_lines_all
         WHERE     1 = 1
               AND customer_trx_id = pn_customer_trx_id
               AND line_type = 'LINE';

        RETURN ln_lines_count;
    EXCEPTION
        WHEN OTHERS
        THEN
            ln_lines_count   := 0;
            RETURN ln_lines_count;
    END get_lines_count;

    FUNCTION get_tax_amount (pn_receivable_application_id   IN NUMBER,
                             P_TAX_TYPE                        VARCHAR2)
        RETURN NUMBER
    IS
        ln_tax_amount   NUMBER;
    BEGIN
        SELECT NVL (SUM (NVL (amount_dr, 0) - NVL (amount_cr, 0)), 0)
          INTO ln_tax_amount
          FROM AR_DISTRIBUTIONS_ALL a, gl_code_combinations_kfv b, fnd_lookup_values_vl flv
         WHERE     1 = 1
               AND a.code_combination_id = b.code_combination_id
               AND source_table = 'RA'
               AND source_type = ('TAX')
               AND b.segment6 = flv.description
               AND source_id = pn_receivable_application_id
               AND flv.lookup_type = 'XXD_ZX_TAX_TYPES_CANADA_LKP'
               AND TAG = P_TAX_TYPE
               AND SYSDATE BETWEEN NVL (flv.start_date_active, SYSDATE)
                               AND NVL (flv.end_date_active, SYSDATE + 1)
               AND flv.ENABLED_FLAG = 'Y';

        RETURN ln_tax_amount;
    EXCEPTION
        WHEN OTHERS
        THEN
            ln_tax_amount   := 0;
            RETURN ln_tax_amount;
    END get_tax_amount;

    --End Changes for CCR0008587

    FUNCTION trx_bill_to_province (pn_bill_to_site_use_id   IN NUMBER,
                                   pn_org_id                IN NUMBER)
        RETURN VARCHAR2
    IS
        ln_bill_province   hz_locations.province%TYPE;
    BEGIN
        ln_bill_province   := NULL;

        SELECT hl_bill.province
          INTO ln_bill_province
          FROM apps.hz_parties hp_bill, apps.hz_party_sites hps_bill, apps.hz_cust_acct_sites_all hcasa_bill,
               apps.hz_cust_site_uses_all hcsua_bill, apps.hz_locations hl_bill
         WHERE     1 = 1
               AND hps_bill.location_id = hl_bill.location_id(+)
               AND hps_bill.party_id = hp_bill.party_id(+)
               AND hcasa_bill.cust_acct_site_id(+) =
                   hcsua_bill.cust_acct_site_id
               AND hcasa_bill.party_site_id = hps_bill.party_site_id(+)
               AND hcsua_bill.site_use_code(+) = 'BILL_TO'
               AND hcsua_bill.org_id = hcasa_bill.org_id
               AND hcsua_bill.site_use_id = pn_bill_to_site_use_id
               AND hcsua_bill.org_id = pn_org_id;

        RETURN ln_bill_province;
    EXCEPTION
        WHEN OTHERS
        THEN
            ln_bill_province   := NULL;
            RETURN ln_bill_province;
    END trx_bill_to_province;
END XXDO_TAX_DETAILS;
/
