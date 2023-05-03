--
-- XXD_ONT_ADV_SALES_REP_INT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:10 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_ADV_SALES_REP_INT_PKG"
AS
    /****************************************************************************************
    * Package      : xxd_ont_adv_sales_rep_int_pkg
    * Design       : This package will be used as Customer Sales Rep Interface to O9.
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 10-May-2021   1.0        Balavenu Rao        Initial Version (CCR0009135)
    ******************************************************************************************/
    -- ======================================================================================
    -- Set values for Global Variables
    -- ======================================================================================
    -- Modifed to init G variable from input params

    gn_user_id        NUMBER := fnd_global.user_id;
    gn_login_id       NUMBER := fnd_global.login_id;
    gn_request_id     NUMBER := fnd_global.conc_request_id;
    gc_debug_enable   VARCHAR2 (1);
    gc_delimiter      VARCHAR2 (100);

    -- ======================================================================================
    -- This procedure prints the Debug Messages in Log Or File
    -- ======================================================================================

    PROCEDURE debug_msg (p_msg IN VARCHAR2)
    AS
        lc_debug_mode   VARCHAR2 (1000);
    BEGIN
        fnd_file.put_line (fnd_file.LOG, gc_delimiter || p_msg);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Others Exception in DEBUG_MSG = ' || SQLERRM);
    END debug_msg;

    PROCEDURE set_last_extract_date (p_interface_name IN VARCHAR2, p_last_update_date OUT VARCHAR2, p_latest_update_date OUT VARCHAR2
                                     , p_file_path OUT VARCHAR2, x_status OUT NOCOPY VARCHAR2, x_message OUT NOCOPY VARCHAR2)
    IS
    BEGIN
        --Retrive Last Update Date
        SELECT tag
          INTO p_last_update_date
          FROM fnd_lookup_values
         WHERE     lookup_type = 'XXD_PO_O9_INTERFACES_LKP'
               AND lookup_code = p_interface_name
               AND NVL (start_date_active, SYSDATE) <= SYSDATE
               AND NVL (end_date_active, SYSDATE) >= SYSDATE
               AND NVL (enabled_flag, 'N') = 'Y'
               AND language = USERENV ('LANG');

        -- Retrive File Path Location
        SELECT meaning
          INTO p_file_path
          FROM fnd_lookup_values
         WHERE     lookup_type = 'XXD_PO_O9_INTERFACES_LKP'
               AND lookup_code = 'FILE_PATH_MASTER_DATA'
               AND NVL (start_date_active, SYSDATE) <= SYSDATE
               AND NVL (end_date_active, SYSDATE) >= SYSDATE
               AND NVL (enabled_flag, 'N') = 'Y'
               AND language = USERENV ('LANG');

        p_latest_update_date   := TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS');
        x_status               := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            x_status               := 'E';
            x_message              := SUBSTR (SQLERRM, 1, 2000);
            p_last_update_date     := NULL;
            p_latest_update_date   := NULL;
    END set_last_extract_date;

    PROCEDURE update_last_extract_date (p_interface_name IN VARCHAR2, p_latest_update_date IN VARCHAR2, x_status OUT NOCOPY VARCHAR2
                                        , x_message OUT NOCOPY VARCHAR2)
    IS
        CURSOR c1 IS
            SELECT lookup_type, lookup_code, enabled_flag,
                   security_group_id, view_application_id, tag,
                   meaning
              FROM fnd_lookup_values_vl
             WHERE     lookup_type = 'XXD_PO_O9_INTERFACES_LKP'
                   AND lookup_code = p_interface_name
                   AND NVL (start_date_active, SYSDATE) <= SYSDATE
                   AND NVL (end_date_active, SYSDATE) >= SYSDATE
                   AND NVL (enabled_flag, 'N') = 'Y';
    BEGIN
        FOR i IN c1
        LOOP
            BEGIN
                fnd_lookup_values_pkg.update_row (
                    x_lookup_type           => i.lookup_type,
                    x_security_group_id     => i.security_group_id,
                    x_view_application_id   => i.view_application_id,
                    x_lookup_code           => i.lookup_code,
                    x_tag                   => p_latest_update_date,
                    x_attribute_category    => NULL,
                    x_attribute1            => NULL,
                    x_attribute2            => NULL,
                    x_attribute3            => NULL,
                    x_attribute4            => NULL,
                    x_enabled_flag          => 'Y',
                    x_start_date_active     => NULL,
                    x_end_date_active       => NULL,
                    x_territory_code        => NULL,
                    x_attribute5            => NULL,
                    x_attribute6            => NULL,
                    x_attribute7            => NULL,
                    x_attribute8            => NULL,
                    x_attribute9            => NULL,
                    x_attribute10           => NULL,
                    x_attribute11           => NULL,
                    x_attribute12           => NULL,
                    x_attribute13           => NULL,
                    x_attribute14           => NULL,
                    x_attribute15           => NULL,
                    x_meaning               => i.meaning,
                    x_description           => i.tag,
                    x_last_update_date      => SYSDATE,
                    x_last_updated_by       => fnd_global.user_id,
                    x_last_update_login     => fnd_global.user_id);

                COMMIT;
                x_status   := 'S';
                debug_msg (i.lookup_code || ' Lookup has been Updated');
                debug_msg (' stard_date(description) :' || i.tag);
                debug_msg (
                    ' end_date(tag)           :' || p_latest_update_date);
            EXCEPTION
                WHEN OTHERS
                THEN
                    debug_msg (
                        i.lookup_code || ' - Inner Exception - ' || SQLERRM);
                    x_status   := 'E';
            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_status    := 'E';
            x_message   := SUBSTR (SQLERRM, 1, 2000);
    END update_last_extract_date;

    PROCEDURE set_status (p_status     IN VARCHAR2,
                          p_err_msg    IN VARCHAR2,
                          p_filename   IN VARCHAR2)
    AS
    BEGIN
        BEGIN
            UPDATE xxd_ont_adv_sales_rep_int_t
               SET status = p_status, file_name = p_filename, error_message = p_err_msg
             WHERE status = 'N' AND request_id = gn_request_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                debug_msg (
                       'Error While Updating Record Status and File Name: '
                    || SQLERRM);
        END;
    END set_status;

    PROCEDURE delete_records
    AS
    BEGIN
        BEGIN
            DELETE FROM xxd_ont_adv_sales_rep_int_t
                  WHERE request_id = gn_request_id;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                debug_msg ('Error While Deleting From Table: ' || SQLERRM);
        END;
    END delete_records;

    FUNCTION get_brand_val_fnc
        RETURN brand_tbl
        PIPELINED
    IS
        l_brand_tbl   brand_rec;
    BEGIN
        FOR l_brand_tbl
            IN (SELECT meaning
                  FROM fnd_lookup_values
                 WHERE     1 = 1
                       AND language = USERENV ('LANG')
                       AND enabled_flag = 'Y'
                       AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                       NVL (
                                                           start_date_active,
                                                           SYSDATE))
                                               AND TRUNC (
                                                       NVL (end_date_active,
                                                            SYSDATE))
                       AND lookup_type = 'XXD_ONT_O9_BRANDS_LKP')
        LOOP
            PIPE ROW (l_brand_tbl);
        END LOOP;

        RETURN;
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.put_line (
                'Others Exception in get_brand_val_fnc = ' || SQLERRM);
            NULL;
    END get_brand_val_fnc;

    -- ======================================================================================
    -- This Main procedure to collect the data and generate the .CSV file
    -- ======================================================================================

    PROCEDURE xxd_ont_sales_rep_int_prc (
        x_errbuf                OUT NOCOPY VARCHAR2,
        x_retcode               OUT NOCOPY VARCHAR2,
        p_create_file        IN            VARCHAR2,
        p_send_mail          IN            VARCHAR2,
        p_dummy_email        IN            VARCHAR2,
        p_email_id           IN            VARCHAR2,
        p_number_days_purg   IN            NUMBER,
        p_full_load          IN            VARCHAR2,
        p_dummy_val          IN            VARCHAR2,
        p_start_date         IN            VARCHAR2,
        p_debug_flag         IN            VARCHAR2)
    AS
        CURSOR c_inst (p_start_date DATE, p_end_date DATE)
        IS
            SELECT salesrep_id, salesrep_number, salesrep_name,
                   brand, customer_number, account_name,
                   TRUNC (start_date) start_date, TRUNC (end_date) end_date
              FROM (  SELECT drcam.salesrep_id, drcam.salesrep_number, drcam.salesrep_name,
                             drcam.brand, drcam.customer_number, hca.account_name,
                             MIN (drcam.start_date) start_date, MAX (drcam.end_date) end_date
                        FROM do_custom.do_rep_cust_assignment drcam, hz_cust_accounts hca
                       WHERE     1 = 1
                             AND drcam.last_update_date BETWEEN p_start_date
                                                            AND p_end_date
                             AND NVL (drcam.end_date, '31-Dec-2099') =
                                 (SELECT MAX (NVL (drsac.end_date, '31-Dec-2099'))
                                    FROM do_custom.do_rep_cust_assignment drsac
                                   WHERE     drsac.salesrep_id =
                                             drcam.salesrep_id
                                         AND drsac.customer_number =
                                             drcam.customer_number)
                             AND drcam.customer_id = hca.cust_account_id
                             AND drcam.brand IN
                                     (SELECT BRAND FROM TABLE (xxd_ont_adv_sales_rep_int_pkg.get_brand_val_fnc))
                    GROUP BY drcam.salesrep_id, drcam.salesrep_number, drcam.salesrep_name,
                             drcam.brand, drcam.customer_number, hca.account_name
                    UNION
                    SELECT DISTINCT hcsua.primary_salesrep_id salesrep_id, jtf.salesrep_number, jtf.salesrep_name,
                                    hcaa.attribute1 brand, hcaa.account_number customer_number, hcaa.account_name,
                                    jtf.start_date_active start_date, jtf.end_date_active end_date
                      FROM apps.hz_cust_site_uses_all hcsua,
                           apps.hz_cust_acct_sites_all hcasa,
                           apps.hz_cust_accounts_all hcaa,
                           (SELECT rs.salesrep_number, res.resource_name salesrep_name, hou.name org_name,
                                   rs.salesrep_id, rs.org_id, rs.start_date_active,
                                   rs.end_date_active, rs.last_update_date
                              FROM apps.jtf_rs_salesreps rs, apps.jtf_rs_resource_extns_vl res, apps.hr_organization_units hou
                             WHERE     hou.organization_id = rs.org_id
                                   AND rs.resource_id = res.resource_id) jtf
                     WHERE     hcsua.cust_acct_site_id =
                               hcasa.cust_acct_site_id
                           AND hcasa.cust_account_id = hcaa.cust_account_id
                           AND hcsua.site_use_code IN ('BILL_TO', 'SHIP_TO')
                           AND hcsua.primary_salesrep_id IS NOT NULL
                           AND hcsua.primary_salesrep_id = jtf.salesrep_id
                           AND hcaa.attribute1 IN
                                   (SELECT BRAND FROM TABLE (xxd_ont_adv_sales_rep_int_pkg.get_brand_val_fnc))
                           AND jtf.last_update_date BETWEEN p_start_date
                                                        AND p_end_date);


        CURSOR c_write IS
            SELECT *
              FROM xxd_ont_adv_sales_rep_int_t
             WHERE status = 'N' AND request_id = gn_request_id;

        TYPE xxd_ins_type IS TABLE OF c_inst%ROWTYPE;

        TYPE xxd_write_type IS TABLE OF c_write%ROWTYPE;

        v_ins_type              xxd_ins_type := xxd_ins_type ();
        v_write_type            xxd_write_type := xxd_write_type ();
        lv_write_file           UTL_FILE.file_type;
        filename                VARCHAR2 (100);
        lv_error_code           VARCHAR2 (4000) := NULL;
        ln_error_num            NUMBER;
        lv_error_msg            VARCHAR2 (4000) := NULL;
        lv_last_update_date     VARCHAR2 (200) := NULL;
        lv_latest_update_date   VARCHAR2 (200) := NULL;
        lv_status               VARCHAR2 (10) := 'S';
        lv_msg                  VARCHAR2 (4000) := NULL;
        le_bulk_inst_exe        EXCEPTION;
        lv_err_msg              VARCHAR2 (4000) := NULL;
        lv_start_date           DATE := NULL;
        lv_end_date             DATE := NULL;
        lv_param_start_date     DATE := NULL;
        lv_param_end_date       DATE := NULL;
        lv_mail_status          VARCHAR2 (200) := NULL;
        lv_mail_msg             VARCHAR2 (4000) := NULL;
        lv_instance_name        VARCHAR2 (200) := NULL;
        lv_create_file_flag     VARCHAR2 (10) := 'N';
        lv_file_path            VARCHAR2 (360) := NULL;
    BEGIN
        debug_msg (
               ' Parameters Are.....'
            || CHR (10)
            || '    p_create_file    :'
            || p_create_file
            || CHR (10)
            || '    p_send_mail      :'
            || p_send_mail
            || CHR (10));

        BEGIN
            SELECT name INTO lv_instance_name FROM v$database;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_instance_name   := NULL;
        END;

        BEGIN
            SELECT MEANING
              INTO XXDO_MAIL_PKG.pv_smtp_host
              FROM fnd_lookup_values
             WHERE     lookup_type = 'XXD_COMMON_MAIL_DTLS_LKP'
                   AND NVL (start_date_active, SYSDATE) <= SYSDATE
                   AND NVL (end_date_active, SYSDATE) >= SYSDATE
                   AND NVL (enabled_flag, 'N') = 'Y'
                   AND language = USERENV ('LANG')
                   AND LOOKUP_CODE = 'SMTP_HOST';

            SELECT MEANING
              INTO XXDO_MAIL_PKG.pv_smtp_port
              FROM fnd_lookup_values
             WHERE     lookup_type = 'XXD_COMMON_MAIL_DTLS_LKP'
                   AND NVL (start_date_active, SYSDATE) <= SYSDATE
                   AND NVL (end_date_active, SYSDATE) >= SYSDATE
                   AND NVL (enabled_flag, 'N') = 'Y'
                   AND language = USERENV ('LANG')
                   AND LOOKUP_CODE = 'SMTP_PORT';

            XXDO_MAIL_PKG.pv_smtp_domain   := NULL;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        set_last_extract_date ('SALESREP', lv_last_update_date, lv_latest_update_date
                               , lv_file_path, lv_status, lv_msg);

        IF (lv_status = 'S')
        THEN
            v_ins_type.delete;
            v_write_type.delete;

            IF (p_full_load = 'N')
            THEN
                lv_start_date   :=
                    TO_DATE (lv_last_update_date, 'DD-MON-YYYY HH24:MI:SS');
                lv_end_date   :=
                    TO_DATE (lv_latest_update_date, 'DD-MON-YYYY HH24:MI:SS');
            ELSE
                lv_start_date   :=
                    TO_DATE (p_start_date, 'DD-MON-YYYY HH24:MI:SS');
                --lv_end_date :=
                --TO_DATE (p_end_date, 'DD-MON-YYYY HH24:MI:SS');
                lv_end_date   :=
                    TO_DATE (TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'),
                             'DD-MON-YYYY HH24:MI:SS');
            END IF;

            debug_msg (' START_DATE :' || lv_start_date);
            debug_msg (' END_DATE :' || lv_end_date);

            -------------------------------
            -- Insert Logic
            -------------------------------
            BEGIN
                gc_delimiter   := CHR (9);
                debug_msg (
                       ' Start Insert At '
                    || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

                OPEN c_inst (lv_start_date, lv_end_date);

                LOOP
                    FETCH c_inst BULK COLLECT INTO v_ins_type LIMIT 10000;

                    BEGIN
                        IF (p_debug_flag = 'Y')
                        THEN
                            gc_delimiter   := CHR (9) || CHR (9);
                            debug_msg (
                                   ' Start Insert Record Count '
                                || v_ins_type.COUNT
                                || ' at '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        END IF;

                        IF (v_ins_type.COUNT > 0)
                        THEN
                            lv_create_file_flag   := 'Y';

                            FORALL i IN v_ins_type.FIRST .. v_ins_type.LAST
                              SAVE EXCEPTIONS
                                INSERT INTO xxd_ont_adv_sales_rep_int_t (
                                                file_name,
                                                salesrep_id,
                                                salesrep_number,
                                                salesrep_name,
                                                brand,
                                                customer_number,
                                                account_name,
                                                start_date,
                                                end_date,
                                                status,
                                                error_message,
                                                request_id,
                                                attribute1,
                                                attribute2,
                                                attribute3,
                                                attribute4,
                                                attribute5,
                                                attribute6,
                                                attribute7,
                                                attribute8,
                                                attribute9,
                                                attribute10,
                                                attribute11,
                                                attribute12,
                                                attribute13,
                                                attribute14,
                                                attribute15,
                                                creation_date,
                                                created_by,
                                                last_updated_by,
                                                last_update_date,
                                                last_update_login)
                                     VALUES (NULL, v_ins_type (i).salesrep_id, v_ins_type (i).salesrep_number, v_ins_type (i).salesrep_name, v_ins_type (i).brand, v_ins_type (i).customer_number, v_ins_type (i).account_name, v_ins_type (i).start_date, v_ins_type (i).end_date, 'N', NULL, gn_request_id, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, SYSDATE, gn_user_id, gn_user_id
                                             , SYSDATE, gn_login_id);

                            COMMIT;
                        END IF;

                        IF (p_debug_flag = 'Y')
                        THEN
                            debug_msg (
                                   ' End Insert Record Count '
                                || v_ins_type.COUNT
                                || ' at '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        END IF;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                            LOOP
                                ln_error_num   :=
                                    SQL%BULK_EXCEPTIONS (j).ERROR_INDEX;
                                lv_error_code   :=
                                    SQLERRM (
                                          -1
                                        * SQL%BULK_EXCEPTIONS (j).ERROR_CODE);
                                lv_error_msg   :=
                                    SUBSTR (
                                        (lv_error_msg || ' Error While Insert into Table ' || v_ins_type (ln_error_num).salesrep_number || ' ' || lv_error_code || CHR (10)),
                                        1,
                                        4000);

                                debug_msg (lv_error_msg);
                                lv_status   := 'E';
                            END LOOP;

                            IF (p_debug_flag = 'Y')
                            THEN
                                debug_msg (
                                       ' End Insert Record Count '
                                    || v_ins_type.COUNT
                                    || ' at '
                                    || TO_CHAR (SYSDATE,
                                                'DD-MON-YYYY HH24:MI:SS AM'));
                            END IF;

                            RAISE le_bulk_inst_exe;
                    END;

                    v_ins_type.delete;
                    EXIT WHEN c_inst%NOTFOUND;
                END LOOP;

                CLOSE c_inst;

                gc_delimiter   := CHR (9);
                debug_msg (
                       ' End Inserting At '
                    || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
            EXCEPTION
                WHEN le_bulk_inst_exe
                THEN
                    lv_status      := 'E';
                    set_status (
                        'E',
                        SUBSTR (
                               'Error While Bulk Inserting Into Table '
                            || SQLERRM,
                            1,
                            2000),
                        filename);

                    x_errbuf       :=
                        SUBSTR (
                            'Error While Inserting Into Table ' || SQLERRM,
                            1,
                            2000);
                    x_retcode      := 1;
                    gc_delimiter   := CHR (9);
                    debug_msg (' Error While Inserting ' || SQLERRM);
                    debug_msg (
                           ' End Inserting at '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
                WHEN OTHERS
                THEN
                    lv_status      := 'E';
                    set_status (
                        'E',
                        SUBSTR (
                            'Error While Inserting Into Table ' || SQLERRM,
                            1,
                            2000),
                        filename);

                    x_errbuf       :=
                        SUBSTR (
                            'Error While Inserting Into Table ' || SQLERRM,
                            1,
                            2000);
                    x_retcode      := 1;
                    gc_delimiter   := CHR (9);
                    debug_msg (' Error While Inserting ' || SQLERRM);
                    debug_msg (
                           ' End Inserting at '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
            END;

            -- --------------------------
            --  Writing to .TXT File Logic
            -- --------------------------
            IF (p_create_file = 'Y' AND lv_status = 'S')
            THEN
                IF (lv_create_file_flag = 'Y')
                THEN
                    BEGIN
                        debug_msg (RPAD ('=', 100, '='));
                        debug_msg (
                               ' Start Writing into File at '
                            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
                        filename       :=
                               'DECKERS_SALES_REP_'
                            || TO_CHAR (SYSDATE, 'DDMONYYYY_HH24MISS')
                            || '.txt';

                        EXECUTE IMMEDIATE 'alter session set nls_date_format=''YYYY/MM/DD''';

                        lv_write_file   :=
                            UTL_FILE.fopen (lv_file_path, filename, 'W');
                        UTL_FILE.put_line (
                            lv_write_file,
                            'SALESREP_ID|SALESREP_NUMBER|SALESREP_NAME|BRAND|ACCOUNT_NUMBER|ACCOUNT_NAME|START_DATE|END_DATE');

                        OPEN c_write;

                        LOOP
                            FETCH c_write
                                BULK COLLECT INTO v_write_type
                                LIMIT 10000;

                            IF (p_debug_flag = 'Y')
                            THEN
                                gc_delimiter   := CHR (9) || CHR (9);
                                debug_msg (
                                       ' Start Writing into file  Record Count '
                                    || v_write_type.COUNT
                                    || ' at '
                                    || TO_CHAR (SYSDATE,
                                                'DD-MON-YYYY HH24:MI:SS AM'));
                            END IF;

                            IF (v_write_type.COUNT > 0)
                            THEN
                                FOR i IN v_write_type.FIRST ..
                                         v_write_type.LAST
                                LOOP
                                    UTL_FILE.put_line (
                                        lv_write_file,
                                           v_write_type (i).salesrep_id
                                        || '|'
                                        || v_write_type (i).salesrep_number
                                        || '|'
                                        || v_write_type (i).salesrep_name
                                        || '|'
                                        || v_write_type (i).brand
                                        || '|'
                                        || v_write_type (i).customer_number
                                        || '|'
                                        || v_write_type (i).account_name
                                        || '|'
                                        || v_write_type (i).start_date
                                        || '|'
                                        || v_write_type (i).end_date);
                                END LOOP;
                            END IF;

                            IF (p_debug_flag = 'Y')
                            THEN
                                debug_msg (
                                       ' End Writing into file  Record Count '
                                    || v_write_type.COUNT
                                    || ' at '
                                    || TO_CHAR (SYSDATE,
                                                'DD-MON-YYYY HH24:MI:SS AM'));
                            END IF;

                            set_status ('P', NULL, filename);

                            v_write_type.delete;
                            EXIT WHEN c_write%NOTFOUND;
                        END LOOP;

                        CLOSE c_write;

                        UTL_FILE.fclose (lv_write_file);
                        gc_delimiter   := CHR (9);
                        debug_msg (
                               ' End Writing into File At '
                            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
                        debug_msg (' File Name Generated :  ' || filename);
                    EXCEPTION
                        WHEN UTL_FILE.invalid_path
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                'INVALID_PATH: File location or filename was invalid.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            x_retcode      := 1;
                            x_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        WHEN UTL_FILE.invalid_mode
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                'INVALID_MODE: The open_mode parameter in FOPEN was invalid.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            x_retcode      := 1;
                            x_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        WHEN UTL_FILE.invalid_filehandle
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                'INVALID_FILEHANDLE: The file handle was invalid.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            x_retcode      := 1;
                            x_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        WHEN UTL_FILE.invalid_operation
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                'INVALID_OPERATION: The file could not be opened or operated on as requested.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            x_retcode      := 1;
                            x_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        WHEN UTL_FILE.read_error
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                ' READ_ERROR: An operating system error occurred during the read operation.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            x_retcode      := 1;
                            x_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        WHEN UTL_FILE.write_error
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                ' WRITE_ERROR: An operating system error occurred during the write operation.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            x_retcode      := 1;
                            x_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        WHEN UTL_FILE.internal_error
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                'INTERNAL_ERROR: An unspecified error in PL/SQL.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            x_retcode      := 1;
                            x_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        WHEN UTL_FILE.invalid_filename
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                ' INVALID_FILENAME: The filename parameter is invalid.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            x_retcode      := 1;
                            x_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        WHEN OTHERS
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                SUBSTR (
                                       'Error while creating or writing the data into the file.'
                                    || SQLERRM,
                                    1,
                                    2000);
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            x_retcode      := 1;
                            x_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                    END;
                END IF;
            END IF;
        ELSE
            lv_status   := 'E';
            x_retcode   := 1;
            x_errbuf    :=
                SUBSTR ('Error While updating the Latest Date ' || lv_msg,
                        1,
                        2000);
        END IF;

        IF (lv_status = 'S' AND p_create_file = 'Y' AND p_full_load = 'N')
        THEN
            update_last_extract_date ('SALESREP', lv_latest_update_date, lv_status
                                      , lv_msg);
            COMMIT;
        END IF;

        IF (lv_status = 'S')
        THEN
            debug_msg (
                   ' start set_status TO P '
                || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
            set_status ('P', NULL, filename);
            debug_msg (
                   ' End set_status TO P '
                || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        END IF;

        IF (p_create_file = 'Y' AND lv_create_file_flag = 'Y')
        THEN
            IF (lv_status = 'S')
            THEN
                IF (p_send_mail = 'Y')
                THEN
                    XXDO_MAIL_PKG.send_mail ('Erp@deckers.com', p_email_id, NULL, lv_instance_name || ' - Deckers O9 Sales Rep Interface Completed at ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'), ' Hi,' || CHR (10) || CHR (10) || ' Deckers O9 Sales Rep File is generated. ' || CHR (10) || CHR (10) || '  ' || ' File Name: ' || filename || CHR (10) || CHR (10) || ' Sincerely,' || CHR (10) || ' Planning IT Team', NULL
                                             , lv_mail_status, lv_mail_msg);
                    debug_msg (
                           ' Mail Status '
                        || lv_mail_status
                        || ' Mail Message '
                        || lv_mail_msg);
                END IF;
            ELSE
                delete_records;

                IF (p_send_mail = 'Y')
                THEN
                    XXDO_MAIL_PKG.send_mail ('Erp@deckers.com', p_email_id, NULL, lv_instance_name || ' - Deckers O9 Sales Rep Interface Completed in Warning at ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'), ' Hi,' || CHR (10) || CHR (10) || ' Deckers O9 Sales Rep  Interface complete in Warning Please check log file of request id: ' || gn_request_id || ' for details ' || CHR (10) || CHR (10) || ' Sincerely,' || CHR (10) || ' Planning IT Team', NULL
                                             , lv_mail_status, lv_mail_msg);
                    debug_msg (
                           ' Mail Status '
                        || lv_mail_status
                        || ' Mail Message '
                        || lv_mail_msg);
                END IF;
            END IF;
        END IF;

        IF (p_send_mail = 'Y' AND lv_create_file_flag = 'N')
        THEN
            IF (lv_status = 'S')
            THEN
                XXDO_MAIL_PKG.send_mail ('Erp@deckers.com', p_email_id, NULL,
                                         lv_instance_name || ' - Deckers O9 Sales Rep Interface Completed at ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'), ' Hi,' || CHR (10) || CHR (10) || ' No data updates to send to O9 for Sales Rep. ' || CHR (10) || CHR (10) || '  ' || filename || CHR (10) || CHR (10) || ' Sincerely,' || CHR (10) || ' Planning IT Team', NULL
                                         , lv_mail_status, lv_mail_msg);
                debug_msg (
                       ' Mail Status '
                    || lv_mail_status
                    || ' Mail Message '
                    || lv_mail_msg);
            ELSE
                XXDO_MAIL_PKG.send_mail ('Erp@deckers.com', p_email_id, NULL,
                                         lv_instance_name || ' - Deckers O9 Sales Rep Interface Completed in Warning at ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'), ' Hi,' || CHR (10) || CHR (10) || ' Deckers O9 Sales Rep  Interface complete in Warning Please check log file of request id: ' || gn_request_id || ' for details ' || CHR (10) || CHR (10) || ' Sincerely,' || CHR (10) || ' Planning IT Team', NULL
                                         , lv_mail_status, lv_mail_msg);
                debug_msg (
                       ' Mail Status '
                    || lv_mail_status
                    || ' Mail Message '
                    || lv_mail_msg);
            END IF;
        END IF;

        IF p_number_days_purg IS NOT NULL
        THEN
            BEGIN
                DELETE FROM xxd_ont_adv_sales_rep_int_t
                      WHERE creation_date < SYSDATE - p_number_days_purg;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    debug_msg (
                        ' Error While Deleting The Records ' || SQLERRM);
            END;
        END IF;

        gc_delimiter   := '';
        debug_msg (
               ' End Interface '
            || ' at '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
    EXCEPTION
        WHEN OTHERS
        THEN
            delete_records;

            IF (p_send_mail = 'Y')
            THEN
                XXDO_MAIL_PKG.send_mail ('Erp@deckers.com', p_email_id, NULL,
                                         lv_instance_name || ' - Deckers O9 Sales Rep Interface Completed in Error at ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'), ' Hi,' || CHR (10) || CHR (10) || ' Deckers O9 Sales Rep Interface complete in Error Please check log file of request id: ' || gn_request_id || ' for details ' || CHR (10) || CHR (10) || ' Sincerely,' || CHR (10) || ' Planning IT Team', NULL
                                         , lv_mail_status, lv_mail_msg);
                debug_msg (
                       ' Mail Status '
                    || lv_mail_status
                    || ' Mail Message '
                    || lv_mail_msg);
            END IF;

            x_errbuf       :=
                SUBSTR ('Error While Processing The file ' || SQLERRM,
                        1,
                        2000);
            x_retcode      := 2;
            gc_delimiter   := '';
            debug_msg (
                   ' End Interface '
                || ' at '
                || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
    END xxd_ont_sales_rep_int_prc;
END xxd_ont_adv_sales_rep_int_pkg;
/
