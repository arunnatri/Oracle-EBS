--
-- XXD_FA_RETIRE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:30:38 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.xxd_fa_retire_pkg
AS
    /****************************************************************************************
    * Package      : XXD_FA_RETIRE_PKG
    * Author       : BT Technology Team
    * Created      : 09-SEP-2014
    * Program Name : Deckers Fixed Asset Retire - Web ADI
    * Description  : Package used by custom Web ADIs
    *                     1) Mass Asset Adjustments (Retirements)
    *
    * Modification :
    *--------------------------------------------------------------------------------------
    * Date          Developer           Version    Description
    *--------------------------------------------------------------------------------------
    * 09-SEP-2014   BT Technology Team  1.0       Created package body script for FA Retire
    * 25-NOV-2014   BT Technology Team  1.1       Modified email body for CRP3
    ****************************************************************************************/
    PROCEDURE printmessage (p_msgtoken IN VARCHAR2)
    IS
    BEGIN
        IF p_msgtoken IS NOT NULL
        THEN
            NULL;
        END IF;

        RETURN;
    END printmessage;

    PROCEDURE assets_retire (p_created_by IN VARCHAR2, p_book_type_code IN VARCHAR2 DEFAULT NULL, p_book_type_code_h IN VARCHAR2, p_custodian_name IN VARCHAR2 DEFAULT NULL, p_batch_name IN VARCHAR2 DEFAULT NULL, p_asset_number IN VARCHAR2 DEFAULT NULL, p_asset_number_h IN VARCHAR2, p_asset_description IN VARCHAR2 DEFAULT NULL, p_asset_category IN VARCHAR2 DEFAULT NULL, p_asset_tag_number IN VARCHAR2 DEFAULT NULL, p_asset_serial_number IN VARCHAR2 DEFAULT NULL, p_transaction_date IN DATE, p_transaction_description IN VARCHAR2 DEFAULT NULL, p_units_assigned IN NUMBER DEFAULT NULL, p_transaction_units IN NUMBER DEFAULT NULL, p_retirement_type IN VARCHAR2 DEFAULT NULL, p_asset_cost IN NUMBER DEFAULT NULL, p_asset_retire_cost IN NUMBER DEFAULT NULL, p_cost_of_removal IN NUMBER DEFAULT NULL, p_proceeds_of_sale IN NUMBER DEFAULT NULL, p_sold_to IN VARCHAR2 DEFAULT NULL
                             , p_distribution_id IN NUMBER DEFAULT NULL)
    IS
        /****************************************************************************************
        * Procedure : assets_retire
        * Design    : Mass Asset Adjustments (Retirements)
        * Notes     :
        * Return Values: None
        * Modification :
        * Date          Developer                  Version    Description
        *--------------------------------------------------------------------------------------
        * 07-JUL-2014   BT Technology Team         1.0        Created
        ****************************************************************************************/
        l_curr_message        VARCHAR2 (4000) := NULL;
        l_ret_message         VARCHAR2 (4000) := NULL;
        l_err_message         VARCHAR2 (4000) := NULL;

        ln_asset_id           fa_additions_b.asset_id%TYPE;
        l_asset_type          fa_additions_b.asset_type%TYPE;
        ln_mass_ext_ret_id    NUMBER := fa_mass_ext_retirements_s.NEXTVAL;
        ln_cost_retired       fa_retirements.cost_retired%TYPE;
        ln_current_cost       fa_books.cost%TYPE;
        ln_units_assigned     fa_distribution_history.units_assigned%TYPE;
        ln_created_by         NUMBER;

        le_webadi_exception   EXCEPTION;
    BEGIN
        printmessage ('p_created_by: ' || p_created_by);
        printmessage ('p_book_type_code_h: ' || p_book_type_code_h);
        printmessage ('p_custodian_name: ' || p_custodian_name);
        printmessage ('p_asset_number_h: ' || p_asset_number_h);
        printmessage ('p_asset_description: ' || p_asset_description);
        printmessage ('p_asset_category: ' || p_asset_category);
        printmessage ('p_asset_tag_number: ' || p_asset_tag_number);
        printmessage ('p_asset_serial_number: ' || p_asset_serial_number);
        printmessage ('p_transaction_date: ' || p_transaction_date);
        printmessage (
            'p_transaction_description: ' || p_transaction_description);
        printmessage ('p_distribution_id: ' || p_distribution_id);
        printmessage ('p_units_assigned: ' || p_units_assigned);
        printmessage ('p_transaction_units: ' || p_transaction_units);
        printmessage ('p_retirement_type: ' || p_retirement_type);
        printmessage ('p_asset_cost: ' || p_asset_cost);
        printmessage ('p_asset_retire_cost: ' || p_asset_retire_cost);
        printmessage ('p_cost_of_removal: ' || p_cost_of_removal);
        printmessage ('p_proceeds_of_sale: ' || p_proceeds_of_sale);
        printmessage ('p_sold_to: ' || p_sold_to);


        BEGIN
            SELECT user_id
              INTO ln_created_by
              FROM fnd_user
             WHERE user_name = p_created_by;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        IF (NVL (p_asset_number, p_asset_number_h) IS NULL)
        THEN
            l_curr_message   := 'Asset Number should not be null.';
            l_ret_message    := l_ret_message || l_curr_message;
            RAISE le_webadi_exception;
        END IF;

        -- Retrieving Asset_Id for the asset

        BEGIN
            SELECT asset_id
              INTO ln_asset_id
              FROM fa_additions_b
             WHERE asset_number = NVL (p_asset_number, p_asset_number_h);
        EXCEPTION
            WHEN OTHERS
            THEN
                l_curr_message   := 'Asset Number is not valid.';
                l_ret_message    := l_ret_message || l_curr_message;
        END;


        IF p_batch_name IS NULL
        THEN
            l_curr_message   := 'BATCH_NAME is required.';
            l_ret_message    := l_ret_message || l_curr_message;
        END IF;

        -- Validating if p_transaction_units, p_asset_retire_cost both are null
        IF (p_transaction_units IS NULL AND p_asset_retire_cost IS NULL)
        THEN
            l_curr_message   :=
                'Either TRANSACTION_UNITS or ASSET_RETIRE_COST is required';
            l_ret_message   := l_ret_message || l_curr_message;
        END IF;

        --Start Modification by BT Technology Team v1.1 on 25-NOV-2014
        IF p_retirement_type IS NULL
        THEN
            l_curr_message   := 'RETIREMENT_TYPE is required.';
            l_ret_message    := l_ret_message || l_curr_message;
        END IF;

        --End Modification by BT Technology Team v1.1 on 25-NOV-2014

        -- Retrieving Current Cost and Units assigned
        BEGIN
            SELECT fb.cost asset_cost, fdh.units_assigned
              INTO ln_current_cost, ln_units_assigned
              FROM fa_distribution_history fdh, fa_books fb
             WHERE     fb.asset_id = ln_asset_id
                   AND fdh.asset_id = fb.asset_id
                   AND fdh.date_ineffective IS NULL
                   AND fb.date_ineffective IS NULL
                   AND fb.book_type_code = p_book_type_code_h
                   AND fdh.distribution_id = p_distribution_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_current_cost     := 0;
                ln_units_assigned   := 0;
        END;


        IF NVL (p_transaction_units, 0) > 0
        THEN
            -- Validating TRANSACTION_UNITS
            IF (p_transaction_units > ln_units_assigned)
            THEN
                l_curr_message   :=
                    'TRANSACTION_UNITS should not be greater than UNITS_ASSIGNED';
                l_ret_message   := l_ret_message || l_curr_message;
            ELSE
                ln_cost_retired   :=
                    ROUND (
                          ln_current_cost
                        * (p_transaction_units / ln_units_assigned),
                        2);
            END IF;
        ELSE
            -- Validating ASSET_RETIRE_COST
            ln_cost_retired   := p_asset_retire_cost;

            IF (ln_cost_retired > ln_current_cost)
            THEN
                l_curr_message   :=
                    'ASSET_RETIRE_COST should not be greater than ASSET_COST';
                l_ret_message   := l_ret_message || l_curr_message;
            ELSE
                ln_cost_retired   := p_asset_retire_cost;
            END IF;
        END IF;

        IF (l_ret_message IS NULL)
        THEN
            BEGIN
                -- Insert into Mass retirement interface table
                INSERT INTO fa_mass_ext_retirements (batch_name,
                                                     mass_external_retire_id,
                                                     book_type_code,
                                                     review_status,
                                                     asset_id,
                                                     transaction_name,
                                                     date_retired,
                                                     cost_retired,
                                                     units,
                                                     cost_of_removal,
                                                     proceeds_of_sale,
                                                     retirement_type_code,
                                                     reference_num,
                                                     distribution_id,
                                                     sold_to,
                                                     calc_gain_loss_flag,
                                                     created_by,
                                                     creation_date,
                                                     last_updated_by,
                                                     last_update_date,
                                                     last_update_login)
                         VALUES (p_batch_name                    -- BATCH_NAME
                                             ,
                                 ln_mass_ext_ret_id -- MASS_EXTERNAL_RETIRE_ID
                                                   ,
                                 p_book_type_code_h          -- BOOK_TYPE_CODE
                                                   ,
                                 'POST'                       -- REVIEW_STATUS
                                       ,
                                 ln_asset_id                       -- ASSET_ID
                                            ,
                                 p_transaction_description  --TRANSACTION_NAME
                                                          ,
                                 p_transaction_date            -- DATE_RETIRED
                                                   ,
                                 ln_cost_retired               -- COST_RETIRED
                                                ,
                                 p_transaction_units                 --  UNITS
                                                    ,
                                 p_cost_of_removal         --  COST_OF_REMOVAL
                                                  ,
                                 p_proceeds_of_sale       --  PROCEEDS_OF_SALE
                                                   ,
                                 p_retirement_type    --  RETIREMENT_TYPE_CODE
                                                  ,
                                 NULL                        --  REFERENCE_NUM
                                     ,
                                 p_distribution_id,         -- DISTRIBUTION_ID
                                 p_sold_to                          -- SOLD_TO
                                          ,
                                 fnd_api.g_true        -- CALC_GAIN_ LOSS_FLAG
                                               ,
                                 ln_created_by                  --  CREATED_BY
                                              ,
                                 SYSDATE                      -- CREATION_DATE
                                        ,
                                 ln_created_by              -- LAST_UPDATED_BY
                                              ,
                                 SYSDATE                   -- LAST_UPDATE_DATE
                                        ,
                                 fnd_global.conc_login_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_curr_message   := 'Retirement failed - ' || SQLERRM;
                    l_ret_message    := l_ret_message || l_curr_message;
            END;
        END IF;

        -- If there are errors, throw error as exception
        IF l_ret_message IS NOT NULL
        THEN
            RAISE le_webadi_exception;
        END IF;
    EXCEPTION
        WHEN le_webadi_exception
        THEN
            fnd_message.set_name ('XXDO', 'XXD_FA_RETIRE_WEBADI_MSG');
            fnd_message.set_token ('ERROR_MESSAGE', l_ret_message);
            l_err_message   := fnd_message.get ();

            raise_application_error (-20000, l_ret_message);
        WHEN OTHERS
        THEN
            l_curr_message   := 'Unhandled Exception ' || SQLERRM;
            l_ret_message    := l_ret_message || l_curr_message;
    END;

    PROCEDURE send_email
    IS
        lc_connection          UTL_SMTP.connection;
        lc_error_status        VARCHAR2 (1) := 'E';
        lc_success_status      VARCHAR2 (1) := 'S';

        lc_from_address        VARCHAR2 (100);
        lc_override_email_id   VARCHAR2 (1996);
        lc_email_address       VARCHAR2 (100);
        l_batch_name           VARCHAR2 (30);
        --Start Modification by BT Technology Team v1.1 on 25-NOV-2014
        l_full_name            per_all_people_f.full_name%TYPE;
        l_user_name            fnd_user.user_name%TYPE;
        --End Modification by BT Technology Team v1.1 on 25-NOV-2014
        lc_db_name             VARCHAR2 (50);
        ln_org_id              NUMBER;
        lc_book_type_code      fa_book_controls.book_type_code%TYPE;
        lc_email_body          VARCHAR2 (32767);

        CURSOR email_address_cur IS
            SELECT fu.email_address, fu.employee_id
              FROM fnd_user fu, fnd_user_resp_groups fur, apps.fnd_profile_options_vl fpov,
                   apps.fnd_profile_option_values fpo, apps.fnd_responsibility fr, per_security_organizations pso
             WHERE     fu.user_id = fur.user_id
                   AND fr.application_id = fur.responsibility_application_id
                   AND fr.responsibility_id = fur.responsibility_id
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (fr.start_date)
                                           AND TRUNC (
                                                   NVL ((fr.end_date - 1),
                                                        SYSDATE))
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (fur.start_date)
                                           AND TRUNC (
                                                   NVL ((fur.end_date - 1),
                                                        SYSDATE))
                   AND fpo.application_id = fpov.application_id
                   AND fpo.profile_option_id = fpov.profile_option_id
                   AND fr.responsibility_id = fpo.level_value
                   AND fpov.user_profile_option_name LIKE
                           'FA: Security Profile'
                   AND pso.organization_id = ln_org_id
                   AND fpo.level_id = 10003               --For Responsibility
                   AND pso.security_profile_id = fpo.profile_option_value
                   AND pso.entry_type = 'I';

        le_mail_exception      EXCEPTION;
    BEGIN
        printmessage ('Sending email');

        BEGIN
            SELECT batch_name, book_type_code
              INTO l_batch_name, lc_book_type_code
              FROM (  SELECT batch_name, book_type_code
                        FROM fa_mass_ext_retirements
                       WHERE     TRUNC (creation_date) = TRUNC (SYSDATE)
                             AND created_by = fnd_global.user_id
                    ORDER BY creation_date DESC)
             WHERE ROWNUM = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                RAISE le_mail_exception;
        END;

        --Start Modification by BT Technology Team v1.1 on 25-NOV-2014
        --Derive user_name and full_name of initiator for email body
        BEGIN
            SELECT fu.user_name, ppf.full_name
              INTO l_user_name, l_full_name
              FROM fnd_user fu, per_all_people_f ppf
             WHERE     fu.employee_id = ppf.person_id
                   AND fu.user_id = fnd_global.user_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                SELECT user_name, NULL
                  INTO l_user_name, l_full_name
                  FROM fnd_user
                 WHERE user_id = fnd_global.user_id;
            WHEN OTHERS
            THEN
                RAISE le_mail_exception;
        END;

        --End Modification by BT Technology Team v1.1 on 25-NOV-2014
        BEGIN
            SELECT SYS_CONTEXT ('userenv', 'db_name')
              INTO lc_db_name
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                RAISE le_mail_exception;
        END;

        --Get From Email Address
        BEGIN
            SELECT fscpv.parameter_value
              INTO lc_from_address
              FROM fnd_svc_comp_params_tl fscpt, fnd_svc_comp_param_vals fscpv, fnd_svc_components fsc
             WHERE     fscpt.parameter_id = fscpv.parameter_id
                   AND fscpv.component_id = fsc.component_id
                   AND fscpt.display_name = 'Reply-to Address'
                   AND fsc.component_name = 'Workflow Notification Mailer';
        EXCEPTION
            WHEN OTHERS
            THEN
                RAISE le_mail_exception;
        END;

        --Start Modification by BT Technology Team v1.1 on 25-NOV-2014
        IF l_full_name IS NOT NULL
        THEN
            lc_email_body   :=
                   'Retirement Initiated for assets with Retirement Batch Name: '
                || l_batch_name
                || ', as on '
                || TRUNC (SYSDATE)
                || ' has been submitted by '
                || l_full_name
                || '('
                || l_user_name
                || ')'
                || '. To complete the retirement processes please review and then run the "Post Mass Retirements".';
        ELSE
            lc_email_body   :=
                   'Retirement Initiated for assets with Retirement Batch Name: '
                || l_batch_name
                || ', as on '
                || TRUNC (SYSDATE)
                || ' has been submitted by '
                || l_user_name
                || '. To complete the retirement processes please review and then run the "Post Mass Retirements".';
        END IF;

        printmessage (lc_email_body);

        --End Modification by BT Technology Team v1.1 on 25-NOV-2014
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

                lc_email_address   := lc_override_email_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    RAISE le_mail_exception;
            END;

            send_email_child (p_from_email_address   => lc_from_address,
                              p_to_email_address     => lc_email_address,
                              p_email_body           => lc_email_body);
        ELSE
            BEGIN
                SELECT org_id
                  INTO ln_org_id
                  FROM fa_book_controls
                 WHERE book_type_code = lc_book_type_code;
            EXCEPTION
                WHEN OTHERS
                THEN
                    RAISE le_mail_exception;
            END;

            FOR email_address_rec IN email_address_cur
            LOOP
                lc_email_address   := NULL;

                IF email_address_rec.employee_id IS NOT NULL
                THEN
                    BEGIN
                        SELECT email_address
                          INTO lc_email_address
                          FROM per_all_people_f ppf
                         WHERE     TRUNC (SYSDATE) BETWEEN TRUNC (
                                                               NVL (
                                                                   effective_start_date,
                                                                   SYSDATE))
                                                       AND TRUNC (
                                                               NVL (
                                                                   effective_end_date,
                                                                   SYSDATE))
                               AND ppf.person_id =
                                   email_address_rec.employee_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            RAISE le_mail_exception;
                    END;
                ELSE
                    lc_email_address   := email_address_rec.email_address;
                END IF;

                IF lc_email_address IS NOT NULL
                THEN
                    send_email_child (
                        p_from_email_address   => lc_from_address,
                        p_to_email_address     => lc_email_address,
                        p_email_body           => lc_email_body);
                END IF;
            END LOOP;
        END IF;
    EXCEPTION
        WHEN le_mail_exception
        THEN
            NULL;
    END send_email;

    PROCEDURE send_email_child (p_from_email_address VARCHAR2, p_to_email_address VARCHAR2, p_email_body VARCHAR2)
    IS
        lc_connection       UTL_SMTP.connection;
        lc_error_status     VARCHAR2 (1) := 'E';
        lc_success_status   VARCHAR2 (1) := 'S';
        lc_port             NUMBER := 25;
        --Smtp Domain name derived from profile
        lc_host             VARCHAR2 (256)
                                := fnd_profile.VALUE ('FND_SMTP_HOST');
        lc_from_address     VARCHAR2 (100);
        lc_email_address    VARCHAR2 (100);
        lc_email_subject    VARCHAR2 (1000)
            := 'Fixed Asset Retirement - Web ADI @' || SYSDATE;

        le_mail_exception   EXCEPTION;
    BEGIN
        printmessage ('Send email');

        lc_from_address    := p_from_email_address;
        lc_email_address   := p_to_email_address;

        lc_connection      := UTL_SMTP.open_connection (lc_host, lc_port);
        UTL_SMTP.helo (lc_connection, lc_host);
        UTL_SMTP.mail (lc_connection, lc_from_address);
        UTL_SMTP.rcpt (lc_connection, lc_email_address);
        UTL_SMTP.open_data (lc_connection); /* ** Sending the header information */
        UTL_SMTP.write_data (lc_connection,
                             'From: ' || lc_from_address || UTL_TCP.crlf);
        UTL_SMTP.write_data (lc_connection,
                             'To: ' || lc_email_address || UTL_TCP.crlf);
        UTL_SMTP.write_data (lc_connection,
                             'Subject: ' || lc_email_subject || UTL_TCP.crlf);
        UTL_SMTP.write_data (lc_connection,
                             'MIME-Version: ' || '1.0' || UTL_TCP.crlf);
        UTL_SMTP.write_data (lc_connection, 'Content-Type: ' || 'text/html;');
        UTL_SMTP.write_data (
            lc_connection,
            'Content-Transfer-Encoding: ' || '"8Bit"' || UTL_TCP.crlf);
        UTL_SMTP.write_data (lc_connection, UTL_TCP.crlf);
        UTL_SMTP.write_data (lc_connection, UTL_TCP.crlf || '');
        UTL_SMTP.write_data (lc_connection, UTL_TCP.crlf || '');
        UTL_SMTP.write_data (
            lc_connection,
               UTL_TCP.crlf
            || '<span style="color: black; font-family: Courier New;">'
            || p_email_body
            || '</span>');
        UTL_SMTP.write_data (lc_connection, UTL_TCP.crlf || '');
        UTL_SMTP.write_data (lc_connection, UTL_TCP.crlf || '');
        UTL_SMTP.close_data (lc_connection);
        UTL_SMTP.quit (lc_connection);
    EXCEPTION
        WHEN le_mail_exception
        THEN
            NULL;
        WHEN UTL_SMTP.invalid_operation
        THEN
            printmessage (
                ' Invalid Operation in Mail attempt using UTL_SMTP.');
        WHEN UTL_SMTP.transient_error
        THEN
            printmessage (' Temporary e-mail issue - try again');
        WHEN UTL_SMTP.permanent_error
        THEN
            printmessage (' Permanent Error Encountered.');
    END send_email_child;
END;
/
