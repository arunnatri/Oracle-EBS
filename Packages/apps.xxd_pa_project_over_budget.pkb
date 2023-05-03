--
-- XXD_PA_PROJECT_OVER_BUDGET  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:59 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.xxd_pa_project_over_budget
AS
    /********************************************************************************************
       NAME     :   XXD_PA_PROJECT_OVER_BUDGET
       PURPOSE  :   Package called by program 'Deckers: Project Over Budget Alert'
                    Sends email to project managers and PMO with over budget project details

       REVISIONS:
      --------------------------------------------------------------------------------------------------------------------
       Ver No     Developer                                Date                             Description
      --------------------------------------------------------------------------------------------------------------------
       1.0       BT Technology Team                 11-Sep-2014         Created for sending emails to project managers
                                                                        and PMO with over budget project details
      *********************************************************************************************/
    /*****************************************************************************************
    * Procedure    : send_email
    * Description  : Sends email to the recipient.
    * Modifications:
    * Ver        Date          Author                   Description
    * ---------  ----------   ---------------     ------------------------------------
    * 1.0        11-Sep-2014   BT Technology Team         Created
    *****************************************************************************************/
    PROCEDURE send_email (p_sender          VARCHAR2,
                          p_recipient       VARCHAR2,
                          p_subject         VARCHAR2,
                          p_body            VARCHAR2,
                          x_status      OUT VARCHAR2,
                          x_message     OUT VARCHAR2)
    IS
        lc_Connection       UTL_SMTP.connection;
        lc_vrData           VARCHAR2 (32000);
        lc_error_status     VARCHAR2 (1) := 'E';
        lc_success_status   VARCHAR2 (1) := 'S';
        lc_port             NUMBER := 25;
        --Smtp Domain name derived from profile
        lc_host             VARCHAR2 (256)
                                := fnd_profile.VALUE ('FND_SMTP_HOST');
    BEGIN
        lc_Connection   := UTL_SMTP.open_connection (lc_host, lc_port);
        UTL_SMTP.helo (lc_Connection, lc_host);
        UTL_SMTP.mail (lc_Connection, p_sender);
        UTL_SMTP.rcpt (lc_Connection, p_recipient);
        UTL_SMTP.open_data (lc_Connection); /* ** Sending the header information */
        UTL_SMTP.write_data (lc_Connection,
                             'From: ' || p_sender || UTL_TCP.CRLF);
        UTL_SMTP.write_data (lc_Connection,
                             'To: ' || p_recipient || UTL_TCP.CRLF);
        UTL_SMTP.write_data (lc_Connection,
                             'Subject: ' || p_subject || UTL_TCP.CRLF);
        UTL_SMTP.write_data (lc_Connection,
                             'MIME-Version: ' || '1.0' || UTL_TCP.CRLF);
        UTL_SMTP.write_data (lc_Connection, 'Content-Type: ' || 'text/html;');
        UTL_SMTP.write_data (
            lc_Connection,
            'Content-Transfer-Encoding: ' || '"8Bit"' || UTL_TCP.CRLF);
        UTL_SMTP.write_data (lc_Connection, UTL_TCP.CRLF);
        UTL_SMTP.write_data (lc_Connection, UTL_TCP.CRLF || '');
        UTL_SMTP.write_data (lc_Connection, UTL_TCP.CRLF || '');
        UTL_SMTP.write_data (
            lc_Connection,
               UTL_TCP.CRLF
            || '<span style="color: black; font-family: Courier New;">'
            || p_body
            || '</span>');
        UTL_SMTP.write_data (lc_Connection, UTL_TCP.CRLF || '');
        UTL_SMTP.write_data (lc_Connection, UTL_TCP.CRLF || '');
        UTL_SMTP.close_data (lc_Connection);
        UTL_SMTP.quit (lc_Connection);

        x_status        := lc_success_status;
    EXCEPTION
        WHEN UTL_SMTP.INVALID_OPERATION
        THEN
            x_status   := lc_error_status;
            fnd_file.put_line (
                fnd_file.LOG,
                ' Invalid Operation in Mail attempt using UTL_SMTP.');
        WHEN UTL_SMTP.TRANSIENT_ERROR
        THEN
            x_status   := lc_error_status;
            fnd_file.put_line (fnd_file.LOG,
                               ' Temporary e-mail issue - try again');
        WHEN UTL_SMTP.PERMANENT_ERROR
        THEN
            x_status   := lc_error_status;
            fnd_file.put_line (fnd_file.LOG, ' Permanent Error Encountered.');
    END send_email;

    /*****************************************************************************************
    * Procedure    : main
    * Description  : Derives projects exceeding budget and calls send_email_user to send mails
    * Modifications:
    * Ver        Date         Author                   Description
    * ---------  ----------   ---------------    ------------------------------------
    * 1.0        10-Sep-2014  BT Technology Team         Created
    *****************************************************************************************/
    PROCEDURE main (x_errbuf          OUT VARCHAR2,
                    x_retcode         OUT NUMBER,
                    p_debug_flag   IN     VARCHAR2)
    IS
        lc_email_body            VARCHAR2 (32767);
        lc_email_subject         VARCHAR2 (1000) := 'Capital Project Budget Alert';
        lc_mime_type             VARCHAR2 (20) := 'text/html';
        lc_error_code            VARCHAR2 (10);
        lc_error_message         VARCHAR2 (4000);
        lc_status                VARCHAR2 (10);

        lc_pmo_email_body        VARCHAR2 (32767);
        lc_pmo_email_addresses   VARCHAR2 (1000) := NULL;
        lc_email_address         VARCHAR2 (100) := NULL;

        lc_from_address          VARCHAR2 (100);

        lc_email_body_hdr        VARCHAR2 (1500) := NULL;
        lc_email_body_footer     VARCHAR2 (150)
            := '</table><br> &nbsp;<br> &nbsp;<br> &nbsp;***************** CONFIDENTIAL *****************</body></html>';

        --Threshold value derived from profile
        lc_over_budget_pc        NUMBER
            := (fnd_profile.VALUE ('XXDO_PROJECT_BUDGET_ALERT_THRESHOLD_PCT'));

        lc_pm_name               VARCHAR2 (100) := NULL; -- To temporarily store project manager name.
        lc_override_email_id     VARCHAR2 (1996);


        lc_project_found         VARCHAR2 (1) := 'N';
        lc_main_exeption         EXCEPTION;
        lc_sysdate               DATE;
        lc_db_name               VARCHAR2 (50);


        CURSOR over_budget_project_cur IS
              SELECT xxdo_proj.project_number, xxdo_proj.project_name, xxdo_proj.operating_unit,
                     f.full_name prj_mgr, f.email_address, xxdo_proj.brand,
                     xxdo_proj.channel, xxdo_proj.geography geo, xxdo_proj.start_date,
                     xxdo_proj.total_budget, xxdo_proj.total_actuals, xxdo_proj.total_commitments,
                     (xxdo_proj.total_commitments + xxdo_proj.total_actuals) total_cost, DECODE ((xxdo_proj.total_commitments + xxdo_proj.total_actuals), 0, 0, DECODE (xxdo_proj.total_budget, 0, 100, ((xxdo_proj.total_commitments + xxdo_proj.total_actuals) / xxdo_proj.total_budget) * 100)) consumption_percentage
                FROM (SELECT ppa.segment1
                                 project_number,
                             ppa.NAME
                                 project_name,
                             ppa.start_date,
                             (SELECT NAME
                                FROM hr_all_organization_units
                               WHERE organization_id = ppa.org_id)
                                 operating_unit,
                             (SELECT class_code
                                FROM pa_project_classes ppc
                               WHERE     class_category = 'Brand'
                                     AND ppc.project_id = ppa.project_id)
                                 brand,
                             (SELECT class_code
                                FROM pa_project_classes ppc
                               WHERE     class_category = 'Channel'
                                     AND ppc.project_id = ppa.project_id)
                                 channel,
                             (SELECT class_code
                                FROM pa_project_classes ppc
                               WHERE     class_category = 'Geography'
                                     AND ppc.project_id = ppa.project_id)
                                 geography,
                             (SELECT NVL (SUM (pbl.burdened_cost), 0)
                                FROM pa_budget_lines pbl, pa_resource_assignments pra
                               WHERE     pra.project_id = ppa.project_id
                                     AND pra.resource_assignment_id =
                                         pbl.resource_assignment_id
                                     AND pra.budget_version_id =
                                         (SELECT MAX (budget_version_id)
                                            FROM pa_budget_versions
                                           WHERE     project_id =
                                                     pra.project_id
                                                 AND budget_status_code = 'B'
                                                 AND budget_type_code =
                                                     'Cost Budget'
                                                 AND current_flag = 'Y'))
                                 total_budget,
                             (SELECT NVL (SUM (acct_burdened_cost), 0)
                                FROM pa_commitment_txns_v
                               WHERE project_id = ppa.project_id)
                                 total_commitments,
                             (SELECT NVL (SUM (burden_cost), 0)
                                FROM pa_expenditure_items_all
                               WHERE project_id = ppa.project_id)
                                 total_actuals,
                             (SELECT ppp.person_id
                                FROM pa_project_players ppp
                               WHERE     ppp.project_role_type =
                                         'PROJECT MANAGER'
                                     AND ppp.project_id = ppa.project_id
                                     AND SYSDATE BETWEEN NVL (
                                                             START_DATE_ACTIVE,
                                                             SYSDATE)
                                                     AND NVL (END_DATE_ACTIVE,
                                                              SYSDATE))
                                 project_manager
                        FROM pa_projects_all ppa
                       WHERE     NVL (ppa.template_flag, 'N') = 'N'
                             AND NVL (ppa.enabled_flag, 'N') = 'Y'
                             AND ppa.project_status_code NOT IN
                                     ('SUBMITTED', 'CLOSED')) xxdo_proj,
                     per_all_people_f f
               WHERE     1 = 1
                     AND xxdo_proj.project_manager = f.person_id(+)
                     AND SYSDATE BETWEEN f.effective_start_date
                                     AND NVL (f.effective_end_date, SYSDATE)
                     AND xxdo_proj.project_manager IS NOT NULL
                     AND DECODE (
                             (xxdo_proj.total_commitments + xxdo_proj.total_actuals),
                             0, 0,
                             DECODE (
                                 xxdo_proj.total_budget,
                                 0, 100,
                                   ((xxdo_proj.total_commitments + xxdo_proj.total_actuals) / xxdo_proj.total_budget)
                                 * 100)) >=
                         lc_over_budget_pc
            ORDER BY f.full_name;

        --Cursor to fetch PMO email Address
        CURSOR pmo_email_address_cur IS
            SELECT meaning email_address
              FROM fnd_lookup_values
             WHERE     lookup_type = 'XXDO_PMO_MEMBER_DETAILS'
                   AND LANGUAGE = 'US'
                   AND ENABLED_FLAG = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (start_date_active,
                                                        SYSDATE))
                                           AND TRUNC (
                                                   NVL (end_date_active,
                                                        SYSDATE));
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Debug Flag :' || p_debug_flag);

        -- Fetch sysdate
        BEGIN
            SELECT TRUNC (SYSDATE) INTO lc_sysdate FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error when deriving sysdate - '
                    || SUBSTR (SQLCODE || ' : ' || SUBSTR (SQLERRM, 300),
                               1,
                               300));
                RAISE lc_main_exeption;
        END;

        --Email header
        lc_email_body_hdr      :=
               '<html><body>'
            || 'Total cost of the following projects have reached (or crossed) the threshold limit of '
            || lc_over_budget_pc
            || '% of the total budget amount as on date '
            || lc_sysdate
            || ': <br> &nbsp; '
            || '<table border="1" width="96%">'
            || '<tr><b>'
            || '<td width="13%" bgcolor="#909090" align="center" valign="middle">Project Number</td>'
            || '<td width="13%" bgcolor="#909090" align="center" valign="middle">Project Name</td>'
            || '<td width="13%" bgcolor="#909090" align="center" valign="middle">Operating Unit</td>'
            || '<td width="13%" bgcolor="#909090" align="center" valign="middle">Project Manager</td>'
            || '<td width="13%" bgcolor="#909090" align="center" valign="middle">Brand</td>'
            || '<td width="13%" bgcolor="#909090" align="center" valign="middle">Channel</td>'
            || '<td width="6%" bgcolor="#909090" align="center" valign="middle">Geo</td>'
            || '<td width="6%" bgcolor="#909090" align="center" valign="middle">Project Start Date</td>'
            || '<td width="6%" bgcolor="#909090" align="center" valign="middle">Total Budgeted Cost</td>'
            || '<td width="6%" bgcolor="#909090" align="center" valign="middle">ITD Actual Cost</td>'
            || '<td width="6%" bgcolor="#909090" align="center" valign="middle">ITD Commitment Cost</td>'
            || '<td width="6%" bgcolor="#909090" align="center" valign="middle">ITD Total Cost</td>'
            || '<td width="6%" bgcolor="#909090" align="center" valign="middle">% Consumption</td>'
            || '</b></tr>';

        lc_email_body          := NULL;
        lc_pmo_email_body      := NULL;

        --Get From Email Address
        BEGIN
            SELECT fscpv.parameter_value
              INTO lc_from_address
              FROM fnd_svc_comp_params_tl fscpt, fnd_svc_comp_param_vals fscpv, fnd_svc_components fsc
             WHERE     fscpt.parameter_id = fscpv.parameter_id
                   AND fscpv.component_id = fsc.component_id
                   AND fscpt.display_name = 'Reply-to Address'
                   AND fsc.component_name = 'Workflow Notification Mailer';

            IF (NVL (p_debug_flag, 'N') = 'Y')
            THEN
                fnd_file.put_line (fnd_file.LOG,
                                   'From email address :' || lc_from_address);
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error when From Address - '
                    || SUBSTR (SQLCODE || ' : ' || SUBSTR (SQLERRM, 300),
                               1,
                               300));
                RAISE lc_main_exeption;
        END;


        --------------------------------------------------------------------------------------
        --***Imlc_portant ***--
        --To avoid sending emails to actual email address from non Production environment,
        --derive overriding address from oracle workflow mail server
        --and send the email to those email address
        --For Production environment, skip this step
        --------------------------------------------------------------------------------------
        lc_override_email_id   := NULL;

        -- Find the environment from V$SESSION
        BEGIN
            SELECT SYS_CONTEXT ('userenv', 'db_name')
              INTO lc_db_name
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error when Fetching database name - '
                    || SUBSTR (SQLCODE || ' : ' || SUBSTR (SQLERRM, 300),
                               1,
                               300));
                RAISE lc_main_exeption;
        END;

        IF LOWER (lc_db_name) NOT LIKE '%prod%'
        THEN
            BEGIN
                --Fetch override email address for Non Prod Instances
                SELECT fscpv.parameter_value
                  INTO lc_override_email_id
                  FROM fnd_svc_comp_params_tl fscpt, fnd_svc_comp_param_vals fscpv, fnd_svc_components fsc
                 WHERE     fscpt.parameter_id = fscpv.parameter_id
                       AND fscpv.component_id = fsc.component_id
                       AND fscpt.display_name = 'Test Address'
                       AND fsc.component_name =
                           'Workflow Notification Mailer';

                IF (NVL (p_debug_flag, 'N') = 'Y')
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Override Email Address :' || lc_override_email_id);
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error while deriving override email address :'
                        || SUBSTR (SQLERRM, 300));
                    RAISE lc_main_exeption;
            END;
        END IF;



        FOR over_budget_project_rec IN over_budget_project_cur
        LOOP
            lc_project_found   := 'Y'; --Set to 'Y' when there are over budget projects

            IF (NVL (p_debug_flag, 'N') = 'Y')
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Project Manager :' || over_budget_project_rec.prj_mgr);
            END IF;

            --Send email to project manager(lc_pm_name) whenever
            --the project manager name(over_budget_project_rec.prj_mgr) changes
            IF (NVL (lc_pm_name, over_budget_project_rec.prj_mgr) <> over_budget_project_rec.prj_mgr)
            THEN
                lc_pmo_email_body   := lc_pmo_email_body || lc_email_body; --Form pmo email body
                lc_email_body       :=
                       lc_email_body_hdr
                    || lc_email_body
                    || lc_email_body_footer;

                IF (NVL (p_debug_flag, 'N') = 'Y')
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Sending email to :' || over_budget_project_rec.email_address);
                END IF;

                --Send email to previous manager - lc_email_address
                send_email (lc_from_address, NVL (lc_override_email_id, lc_email_address), lc_email_subject
                            , lc_email_body, lc_status, lc_error_message);

                IF (lc_status <> 'S')
                THEN
                    IF (NVL (p_debug_flag, 'N') = 'Y')
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error after call to send_email:'
                            || lc_error_message);
                    END IF;

                    RAISE lc_main_exeption;
                END IF;

                --Reset email body when project manager changes
                lc_email_body       := NULL;
            END IF;

            --Form email body
            lc_email_body      :=
                   lc_email_body
                || '<tr valign="middle">'
                || '<td width="13%">'
                || over_budget_project_rec.project_number
                || '</td>'
                || '<td width="13%">'
                || over_budget_project_rec.project_name
                || '</td>'
                || '<td width="13%">'
                || over_budget_project_rec.operating_unit
                || '</td>'
                || '<td width="13%">'
                || over_budget_project_rec.prj_mgr
                || '</td>'
                || '<td width="13%">'
                || over_budget_project_rec.brand
                || '</td>'
                || '<td width="13%">'
                || over_budget_project_rec.channel
                || '</td>'
                || '<td width="13%">'
                || over_budget_project_rec.geo
                || '</td>'
                || '<td width="13%">'
                || over_budget_project_rec.start_date
                || '</td>'
                || '<td width="6%" align="right">'
                || over_budget_project_rec.total_budget
                || '</td>'
                || '<td width="6%" align="right">'
                || over_budget_project_rec.total_actuals
                || '</td>'
                || '<td width="6%" align="right">'
                || over_budget_project_rec.total_commitments
                || '</td>'
                || '<td width="6%" align="right">'
                || over_budget_project_rec.total_cost
                || '</td>'
                || '<td width="6%" align="right">'
                || ROUND (over_budget_project_rec.consumption_percentage, 2)
                || '</td>'
                || '</tr>';
            lc_email_address   := over_budget_project_rec.email_address;
            lc_pm_name         := over_budget_project_rec.prj_mgr;
        END LOOP;

        --Send email to last project manager in the cursor and PMO
        --only if the lc_project_found flag is set to Y
        IF (lc_project_found = 'Y')
        THEN
            IF (NVL (p_debug_flag, 'N') = 'Y')
            THEN
                fnd_file.put_line (fnd_file.LOG,
                                   'Sending email to:' || lc_email_address);
            END IF;

            lc_pmo_email_body   := lc_pmo_email_body || lc_email_body; --Add last manager email content to PMO email body
            lc_email_body       :=
                lc_email_body_hdr || lc_email_body || lc_email_body_footer;
            --Send email to last manager in loop - lc_email_address
            send_email (lc_from_address, NVL (lc_override_email_id, lc_email_address), lc_email_subject
                        , lc_email_body, lc_status, lc_error_message);

            IF (lc_status <> 'S')
            THEN
                IF (NVL (p_debug_flag, 'N') = 'Y')
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Error after call to send_email:' || lc_error_message);
                END IF;

                RAISE lc_main_exeption;
            END IF;

            lc_pmo_email_body   :=
                   lc_email_body_hdr
                || lc_pmo_email_body
                || lc_email_body_footer;                 --Form PMO email body

            --Derive PMO email address
            FOR pmo_email_address_rec IN pmo_email_address_cur
            LOOP
                lc_pmo_email_addresses   :=
                       lc_pmo_email_addresses
                    || ' , '
                    || pmo_email_address_rec.email_address;
            END LOOP;

            IF (NVL (p_debug_flag, 'N') = 'Y')
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Sending email to PMO:' || lc_pmo_email_addresses);
            END IF;

            --Send email to PMO - lc_pmo_email_addresses
            send_email (lc_from_address, NVL (lc_override_email_id, lc_pmo_email_addresses), lc_email_subject
                        , lc_pmo_email_body, lc_status, lc_error_message);


            IF (lc_status <> 'S')
            THEN
                IF (NVL (p_debug_flag, 'N') = 'Y')
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error after call to send_email: '
                        || lc_error_message);
                END IF;

                RAISE lc_main_exeption;
            END IF;
        END IF;

        fnd_file.put_line (fnd_file.LOG, 'Program Completed :');
    EXCEPTION
        WHEN lc_main_exeption
        THEN
            IF (over_budget_project_cur%ISOPEN)
            THEN
                CLOSE over_budget_project_cur;
            END IF;

            IF (pmo_email_address_cur%ISOPEN)
            THEN
                CLOSE pmo_email_address_cur;
            END IF;

            fnd_file.put_line (fnd_file.LOG,
                               'Error :' || SUBSTR (SQLERRM, 300));
        WHEN OTHERS
        THEN
            IF (over_budget_project_cur%ISOPEN)
            THEN
                CLOSE over_budget_project_cur;
            END IF;

            IF (pmo_email_address_cur%ISOPEN)
            THEN
                CLOSE pmo_email_address_cur;
            END IF;

            x_errbuf    := 'Error in MAIN procedure:' || SUBSTR (SQLERRM, 300);
            x_retcode   := 2;

            fnd_file.put_line (
                fnd_file.LOG,
                   'Error in xxd_pa_project_over_budget.main'
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ());
    END main;
END xxd_pa_project_over_budget;
/
