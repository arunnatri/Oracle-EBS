--
-- XXDO_PO_IMPORT_EXCEPTION_REP  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:03 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_PO_IMPORT_EXCEPTION_REP"
IS
    /******************************************************************
     File Name : APPS.XXDO_PO_IMPORT_EXCEPTION_REP
      Created On   : 14-Sep-2014
      Created By   : C.M.Barath Kumar(Sunera Technologies)
      Purpose      : This  is used fetch po import unprocessed records
      latest changes 14-Sep-2014
       *************************************************************************
       Modification History:
       Version   Pointer         SCN#   By              Date             Comments
       1.0                                             14-Sep-2014       Initial Version
       *********************************************************************
       1.1    100      BT Changes   INFOSYS           15-Oct-2014
       ************************************************************************/
    l_ret_val           NUMBER := 0;
    v_out_line          VARCHAR2 (1000);
    v_def_mail_recips   do_mail_utils.tbl_recips;
    l_counter           NUMBER := 0;
    l_primary_email     VARCHAR2 (200);



    PROCEDURE XXDO_PO_IMPORT_EXCP_REP_PROC (p_run_date   IN VARCHAR2,
                                            P_REGION     IN VARCHAR2)
    IS
        CURSOR cur_po_imp_excp (p_run_date IN DATE, p_region IN VARCHAR2)
        IS
            SELECT ar.alloc_id, x26_2.distro_number, x26_2.item_id,
                   x26_2.requested_qty, x26_2.dest_id, x26_2.class,
                   x26_2.gender
              FROM alc_xref@xxdo_retail_rms ar, xxdo.xxdo_inv_int_026_stg2 x26_2
             WHERE     x26_2.distro_number = ar.xref_alloc_no
                   AND x26_2.status = 0
                   AND x26_2.requested_qty > 0
                   AND x26_2.dest_id IN (SELECT rms_store_id
                                           FROM xxd_retail_stores_v drs
                                          WHERE region = p_region);


        l_run_date   DATE;
    BEGIN
        IF p_run_date IS NOT NULL
        THEN
            l_run_date   := apps.fnd_date.canonical_to_date (p_run_date);
        ELSE
            l_run_date   := TRUNC (SYSDATE);
        END IF;

        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'l_run_date=' || l_run_date);
        v_def_mail_recips   := get_email_recips ('XXDO_EBS_RMS_ITEM_EMAIL');
        apps.do_mail_utils.send_mail_header (fnd_profile.VALUE ('DO_DEF_ALERT_SENDER'), v_def_mail_recips, 'Allocations not processed - ' || TO_CHAR (l_run_date, 'MM/DD/YYYY')
                                             , l_ret_val);
        apps.do_mail_utils.send_mail_line (
            'Content-Type: multipart/mixed; boundary=boundarystring',
            l_ret_val);
        apps.do_mail_utils.send_mail_line ('--boundarystring', l_ret_val);
        apps.do_mail_utils.send_mail_line ('Content-Type: text/plain',
                                           l_ret_val);
        apps.do_mail_utils.send_mail_line ('', l_ret_val);

        BEGIN
            SELECT meaning
              INTO l_primary_email
              FROM fnd_lookup_values_vl
             WHERE lookup_type = 'XXDO_EBS_RMS_ITEM_EMAIL' AND tag = 'P';
        EXCEPTION
            WHEN OTHERS
            THEN
                apps.fnd_file.put_line (apps.fnd_file.LOG,
                                        'Too many primary email addresses.');
        END;

        apps.do_mail_utils.send_mail_line (
            'See attachment for report details.',
            l_ret_val);
        apps.do_mail_utils.send_mail_line ('', l_ret_val);
        apps.do_mail_utils.send_mail_line (
            'Please contact ' || l_primary_email || ' for any queries.',
            l_ret_val);
        apps.do_mail_utils.send_mail_line ('--boundarystring', l_ret_val);
        apps.do_mail_utils.send_mail_line ('Content-Type:text/plain',
                                           l_ret_val);
        apps.do_mail_utils.send_mail_line (
            'Content-Disposition: attachment; filename="PO Import Unprocessed Allocations.csv"',
            l_ret_val);
        apps.do_mail_utils.send_mail_line ('', l_ret_val);


        apps.do_mail_utils.send_mail_line (
               'ALLOC_ID'
            || ','
            || 'DISTRO_NUMBER'
            || ','
            || 'ITEM_ID'
            || ','
            || 'STORE'
            || ','
            || 'REQUESTED_QTY'
            || ','
            || 'CLASS'
            || ','
            || 'GENDER'
            || ',',
            l_ret_val);

        FOR rec IN cur_po_imp_excp (l_run_date, p_region)
        LOOP
            v_out_line   := NULL;
            v_out_line   :=
                   rec.alloc_id
                || ','
                || rec.distro_number
                || ','
                || rec.item_id
                || ','
                || rec.dest_id
                || ','
                || rec.requested_qty
                || ','
                || rec.class
                || ','
                || rec.gender
                || ',';

            apps.do_mail_utils.send_mail_line (v_out_line, l_ret_val);
            l_counter    := l_counter + 1;
        END LOOP;

        IF l_counter >= 1
        THEN
            apps.do_mail_utils.send_mail_close (l_ret_val);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                fnd_file.LOG,
                'Exception in EBS_RMS_Item_mismatch_alert_proc ::' || SQLERRM);
            apps.do_mail_utils.send_mail_line (
                'There are no mismatched Items details in RMS and EBS.',
                l_ret_val);
            apps.do_mail_utils.send_mail_line ('', l_ret_val);
            apps.do_mail_utils.send_mail_line (
                'Please contact ' || l_primary_email || ' for any queries.',
                l_ret_val);
            apps.do_mail_utils.send_mail_close (l_ret_val);
    END XXDO_PO_IMPORT_EXCP_REP_PROC;


    FUNCTION get_email_recips (v_lookup_type VARCHAR2)
        RETURN do_mail_utils.tbl_recips
    IS
        v_def_mail_recips   do_mail_utils.tbl_recips;

        CURSOR c_recips IS
            SELECT lookup_code, meaning, description
              FROM apps.fnd_lookup_values
             WHERE     lookup_type = v_lookup_type
                   AND enabled_flag = 'Y'
                   AND LANGUAGE = USERENV ('LANG')
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
END xxdo_po_import_exception_rep;
/
