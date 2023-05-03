--
-- XXDO_APINVOICE_ATTACHMENT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:35 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_APINVOICE_ATTACHMENT_PKG"
AS
    /****************************************************************************
    **
    NAME:       XXDO_AP_INVOICE_ATTACHMENT_PKG
    PURPOSE:    This package contains procedure for Invoice Attachment which
                generates an extract for any specific period
    REVISIONS:
    Ver        Date        Author           Description
    ---------  ----------  ---------------  ------------------------------------
    1.0        10/11/2016   Infosys           1. Created this package.
    ******************************************************************************/
    --Global Varialble
    g_num_org_id    NUMBER;
    g_num_resp_id   NUMBER;

    PROCEDURE Main (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, P_Inv_Frm IN VARCHAR2
                    , P_Inv_To IN VARCHAR2)
    AS
        lv_global_flag    VARCHAR2 (1);
        lv_resp_name      VARCHAR2 (100);
        lv_hdata_record   VARCHAR2 (32767);

        CURSOR c_inv_Att IS
              SELECT DISTINCT OPERATING_UNIT, TRADING_PARTNER, INVOICE_DATE,
                              INVOICE_NUM, CREATED_BY, CREATION_DATE,
                              LAST_UPDATED_BY, LAST_UPDATE_DATE, VALIDATED_BY,
                              VALIDATED_DATE
                FROM (SELECT Hou.name
                                 operating_unit,
                             SUBSTR (NVL (pv.vendor_name, hp.party_name),
                                     1,
                                     20)
                                 Trading_partner,
                             TO_CHAR (aia1.invoice_date, 'DD-MON-YY')
                                 invoice_date,
                             aia1.invoice_num
                                 Invoice_num,
                             SUBSTR (fucr.user_name, 1, 12)
                                 created_by,
                             TO_CHAR (aia1.creation_date, 'DD-MON-YY')
                                 creation_date,
                             SUBSTR (fup.user_name, 1, 12)
                                 Last_updated_by,
                             TO_CHAR (aia1.last_update_date, 'DD-MON-YY')
                                 Last_update_date,
                             SUBSTR (fub.user_name, 1, 12)
                                 validated_By,
                             TO_CHAR (aila.last_update_date, 'DD-MON-YY')
                                 validated_date,
                             DECODE (APPS.Ap_Invoices_Pkg.GET_APPROVAL_STATUS (
                                         aia1.INVOICE_ID,
                                         aia1.INVOICE_AMOUNT,
                                         aia1.PAYMENT_STATUS_FLAG,
                                         aia1.INVOICE_TYPE_LOOKUP_CODE),
                                     'NEVER APPROVED', 'Y',
                                     'NEEDS REAPPROVAL', 'Y',
                                     'N')
                                 Parked
                        -- 'N' Parked
                        FROM apps.ap_invoices_all aia1, apps.ap_invoice_lines_all aila, apps.ap_suppliers PV,
                             apps.hz_parties hp, apps.fnd_user fucr, apps.fnd_user fup,
                             apps.fnd_user fub, apps.hr_operating_units hou
                       WHERE     aila.invoice_id = aia1.invoice_id
                             AND aia1.party_id = hp.party_id
                             AND pv.vendor_id(+) = aia1.vendor_id
                             AND fucr.user_id = aia1.created_by
                             AND fup.user_id = aia1.last_updated_by
                             AND fub.user_id = aila.last_updated_by
                             AND hou.organization_id = aia1.org_id
                             AND hou.organization_id =
                                 NVL (g_num_org_id, hou.organization_id)
                             AND aia1.payment_method_code != 'GTNEXUS'
                             AND aia1.invoice_id NOT IN
                                     (SELECT fad.pk1_value
                                        FROM apps.fnd_attached_documents fad
                                       WHERE fad.entity_name = 'AP_INVOICES')
                             AND aia1.cancelled_date IS NULL
                             AND aia1.creation_date BETWEEN fnd_date.canonical_to_date (
                                                                P_Inv_Frm)
                                                        AND fnd_date.canonical_to_date (
                                                                P_Inv_To))
               WHERE PARKED = 'N'
            ORDER BY creation_Date;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Begin Main procedure');
        --
        --
        lv_global_flag   := 'N';
        lv_resp_name     := NULL;
        g_num_org_id     := MO_GLOBAL.get_current_org_id;
        g_num_resp_id    := FND_GLOBAL.RESP_ID;

        BEGIN
            SELECT responsibility_name, 'Y'
              INTO lv_resp_name, lv_global_flag
              FROM fnd_responsibility_tl
             WHERE     responsibility_id = g_num_resp_id
                   AND responsibility_name LIKE '%Payables%Global%'
                   AND language = 'US';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_resp_name     := NULL;
                lv_global_flag   := 'N';
        END;

        --Set org_id as NULL if it is a global responsibility
        IF lv_global_flag = 'Y'
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Responsibility Name        - ' || lv_resp_name);
            g_num_org_id   := NULL;
        ELSE
            fnd_file.put_line (
                fnd_file.LOG,
                'Operating Unit Name        - ' || MO_GLOBAL.get_ou_name (g_num_org_id));
        END IF;

        fnd_file.put_line (
            fnd_file.output,
               'OPERATING_UNIT'
            || CHR (9)
            || 'TRADING_PARTNER'
            || CHR (9)
            || 'INVOICE_DATE'
            || CHR (9)
            || 'INVOICE_NUM'
            || CHR (9)
            || 'CREATED_BY'
            || CHR (9)
            || 'CREATION_DATE'
            || CHR (9)
            || 'LAST_UPDATED_BY'
            || CHR (9)
            || 'LAST_UPDATE_DATE'
            || CHR (9)
            || 'VALIDATED_BY'
            || CHR (9)
            || 'VALIDATED_DATE');

        --Loop to write the extract to the output file
        FOR rec_inv_Att IN c_inv_Att
        LOOP
            lv_hdata_record   :=
                   rec_inv_Att.OPERATING_UNIT
                || CHR (9)
                || rec_inv_Att.TRADING_PARTNER
                || CHR (9)
                || rec_inv_Att.INVOICE_DATE
                || CHR (9)
                || rec_inv_Att.INVOICE_NUM
                || CHR (9)
                || rec_inv_Att.CREATED_BY
                || CHR (9)
                || rec_inv_Att.CREATION_DATE
                || CHR (9)
                || rec_inv_Att.LAST_UPDATED_BY
                || CHR (9)
                || rec_inv_Att.LAST_UPDATE_DATE
                || CHR (9)
                || rec_inv_Att.VALIDATED_BY
                || CHR (9)
                || rec_inv_Att.VALIDATED_DATE;
            fnd_file.put_line (fnd_file.output, lv_hdata_record);
        END LOOP;

        fnd_file.put_line (fnd_file.LOG, 'End of Main procedure');
    --
    --
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Exception in main procedure ::' || SQLERRM);
    END Main;
END XXDO_APINVOICE_ATTACHMENT_PKG;
/
