--
-- XXD_AR_CREDIT_APPL_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:30 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.xxd_ar_credit_appl_pkg
IS
    /*******************************************************************************
* $Header$
* Program Name : XXD_AR_CREDIT_APPL_PKG.pkb
* Language     : PL/SQL
* Description  :
* History      :
*
* WHO            WHAT                                    WHEN
* -------------- --------------------------------------- ---------------
* Jason Zhang    Original version.                       07-Jan-2015
*
*
*******************************************************************************/

    PROCEDURE send_mail_notification (x_errbuf OUT VARCHAR2, x_retcode OUT VARCHAR2, p_from_date IN VARCHAR2
                                      , p_to_date IN VARCHAR2)
    IS
        /*=============================================================================+
| PROCEDURE: send_mail_notification
|
| DESCRIPTION: Send mail notification to customers based on credit application status
|
| PARAMETERS:
|   IN: p_from_date,  p_to_date
|  OUT: errbuf,  retcode
|
| SCOPE: <PUBLIC or PRIVATE>
|
| DATA OBJECTS USED:
|   OWNER           NAME                           TYPE
|   --------------- ------------------------------ -----------
|   <name>          <name>                         <TABLE/VIEW/SEQUENCE>
|
| EXTERNAL PROCEDURES/FUNCTIONS USED:
|   OWNER           PACKAGE.NAME                   TYPE
|   --------------- ------------------------------ -----------
|   APPS            do_mail_utils.send_mail        procedure
|
| HISTORY:
|  WHO            WHAT                                    WHEN
|  -------------- --------------------------------------- ---------------
|  Jason Zhang    Original version.                       07-Jan-2015
|
+============================================================================*/

        --------------------------------------------------------
        -- Cursor lur_case_folds_rec which is used to pull out
        -- the values and fetch the case_folder_number, party_name,
        -- and all other case folder and customer information
        --------------------------------------------------------

        CURSOR lur_case_folds_rec (c_from_date DATE, c_to_date DATE)
        IS
              SELECT accf.case_folder_id,
                     accf.case_folder_number,
                     TO_CHAR (accf.creation_date_time, 'DD-Mon-YYYY')
                         application_date,
                     accf.limit_currency
                         currency,
                     accf.status,
                     hp.party_number,
                     hp.party_name,
                     email_contact.email_address,
                     (SELECT hca.account_number
                        FROM hz_cust_accounts hca
                       WHERE     hca.cust_account_id = accf.cust_account_id
                             AND hca.party_id = accf.party_id
                             AND hca.status = 'A')
                         account_number,
                     res.source_name
                         credit_analyst_name,
                     request.application_number,
                     request.trx_amount
                         amount_requested,
                     (SELECT recommendation_value2
                        FROM ar_cmgt_cf_recommends recommend
                       WHERE     recommend.case_folder_id = accf.case_folder_id
                             AND recommend.credit_recommendation =
                                 'CREDIT_LIMIT')
                         recommended_amount,
                     (SELECT SUM (score)
                        FROM ar_cmgt_cf_dtls detail
                       WHERE     detail.case_folder_id = accf.case_folder_id
                             AND detail.score IS NOT NULL)
                         credit_score
                /*                   (SELECT fu.user_name
    FROM   ar_cmgt_cf_recommends recommend1,
           fnd_user              fu
    WHERE  recommend1.case_folder_id = accf.case_folder_id
    AND    rownum = 1 -- get the max
    AND    fu.user_id = recommend1.last_updated_by) last_updated_user*/
                FROM ar_cmgt_case_folders accf, hz_parties hp, jtf_rs_resource_extns res,
                     ar_cmgt_credit_requests request, hz_contact_points email_contact
               WHERE     hp.party_id = accf.party_id
                     AND hp.status = 'A'
                     AND res.resource_id = accf.credit_analyst_id
                     AND request.credit_request_id = accf.credit_request_id
                     AND email_contact.owner_table_name(+) = 'HZ_PARTIES'
                     AND email_contact.primary_flag(+) = 'Y'
                     AND email_contact.contact_point_type(+) = 'EMAIL'
                     AND hp.party_id = email_contact.owner_table_id(+)
                     AND EXISTS
                             (SELECT 1
                                FROM ar_cmgt_cf_recommends accr
                               WHERE     accr.case_folder_id =
                                         accf.case_folder_id
                                     AND accr.status IN ('I', 'R')
                                     AND TRUNC (accr.last_update_date) BETWEEN c_from_date
                                                                           AND c_to_date)
            ORDER BY accf.case_folder_number;

        ----------------------

        -- Declaring Variables

        ----------------------
        ld_from_date             DATE;
        ld_to_date               DATE;
        lc_status                VARCHAR2 (15);
        lc_user_name             VARCHAR2 (100);
        lc_notification_status   VARCHAR2 (200);
        lc_mail_subject          VARCHAR2 (100);
        lc_mail_from             VARCHAR2 (100)
                                     := 'Creditdepartment@deckers.com';
        lc_mail_to               VARCHAR2 (100);
        lc_mail_body             VARCHAR2 (2000);
    ------------------------------

    -- Beginning of the procedure

    ------------------------------

    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           'Start the procedure send_mail_notification...');

        IF p_from_date IS NOT NULL
        THEN
            ld_from_date   := fnd_date.canonical_to_date (p_from_date);
        END IF;

        IF p_to_date IS NOT NULL
        THEN
            ld_to_date   := fnd_date.canonical_to_date (p_to_date);
        END IF;

        fnd_file.put_line (fnd_file.output, '');
        fnd_file.put_line (fnd_file.output,
                           '*' || RPAD ('-', 150, '-') || '*');
        fnd_file.put_line (
            fnd_file.output,
               RPAD ('Customer Name', 30, ' ')
            || RPAD ('Customer Number', 20, ' ')
            || RPAD ('Case Folder Number', 30, ' ')
            || RPAD ('Application Status', 30, ' ')
            || 'Notification Status');
        fnd_file.put_line (fnd_file.LOG, 'Start the cursor...');

        FOR l_case_folds_rec IN lur_case_folds_rec (ld_from_date, ld_to_date)
        LOOP
            lc_status                := NULL;
            lc_user_name             := NULL;
            lc_notification_status   := NULL;
            lc_mail_to               := NULL;
            lc_mail_body             := NULL;
            fnd_file.put_line (
                fnd_file.LOG,
                'Case folder number: ' || l_case_folds_rec.case_folder_number);

            IF l_case_folds_rec.email_address IS NULL
            THEN
                lc_notification_status   :=
                    'Email could not be sent since the customer contact is not found';
            ELSE
                --get status and the user name who approved /Rejected the case folders
                BEGIN
                    SELECT recommend.status, fu.user_name
                      INTO lc_status, lc_user_name
                      FROM ar_cmgt_cf_recommends recommend, fnd_user fu
                     WHERE     recommend.recommendation_id =
                               (SELECT MAX (recommend1.recommendation_id)
                                  FROM ar_cmgt_cf_recommends recommend1
                                 WHERE recommend1.case_folder_id =
                                       l_case_folds_rec.case_folder_id)
                           AND fu.user_id = recommend.last_updated_by;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'No user found who approved /Rejected the case folders: '
                            || l_case_folds_rec.case_folder_number);
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Exception occured when get the user name who approved /Rejected the case folders'
                            || SQLERRM);
                END;

                IF lc_status = 'I'
                THEN
                    lc_mail_subject   :=
                           'Credit Application '
                        || l_case_folds_rec.case_folder_number
                        || ' has been Approved';
                ELSIF lc_status = 'R'
                THEN
                    lc_mail_subject   :=
                           'Credit Application '
                        || l_case_folds_rec.case_folder_number
                        || ' has been Rejected';
                END IF;

                lc_mail_to               := l_case_folds_rec.email_address;

                IF lc_status = 'I'
                THEN
                    lc_mail_body   :=
                           'Credit Application '
                        || l_case_folds_rec.case_folder_number
                        || ' has been Approved by '
                        || lc_user_name
                        || CHR (10)
                        || CHR (10)
                        || CHR (10);
                ELSIF lc_status = 'R'
                THEN
                    lc_mail_body   :=
                           'Credit Application '
                        || l_case_folds_rec.case_folder_number
                        || ' has been Rejected by '
                        || lc_user_name
                        || CHR (10)
                        || CHR (10)
                        || CHR (10);
                END IF;

                lc_mail_body             :=
                       lc_mail_body
                    || 'Party Name: '
                    || l_case_folds_rec.party_name
                    || CHR (10);
                lc_mail_body             :=
                       lc_mail_body
                    || 'Party Number: '
                    || l_case_folds_rec.party_number
                    || CHR (10);
                lc_mail_body             :=
                       lc_mail_body
                    || 'Account Number: '
                    || l_case_folds_rec.account_number
                    || CHR (10);
                lc_mail_body             :=
                       lc_mail_body
                    || 'Application Date: '
                    || l_case_folds_rec.application_date
                    || CHR (10);
                lc_mail_body             :=
                       lc_mail_body
                    || 'Case Folder Number: '
                    || l_case_folds_rec.case_folder_number
                    || CHR (10);
                lc_mail_body             :=
                       lc_mail_body
                    || 'Requested Credit Amount: '
                    || l_case_folds_rec.amount_requested
                    || CHR (10);
                lc_mail_body             :=
                       lc_mail_body
                    || 'Recommended Credit Amount: '
                    || l_case_folds_rec.recommended_amount
                    || CHR (10);
                lc_mail_body             :=
                       lc_mail_body
                    || 'Requested Currency: '
                    || l_case_folds_rec.currency
                    || CHR (10);
                lc_mail_body             :=
                       lc_mail_body
                    || 'Credit Analyst: '
                    || l_case_folds_rec.credit_analyst_name
                    || CHR (10);
                lc_mail_body             :=
                       lc_mail_body
                    || 'Score: '
                    || l_case_folds_rec.credit_score
                    || CHR (10);
                --Invoke DO_MAIL_UTILS.SEND_MAIL to send mail notification
                do_mail_utils.send_mail (lc_mail_from, lc_mail_to, lc_mail_subject
                                         , lc_mail_body);

                lc_notification_status   := 'Successfully Sent';
            END IF;

            --output  details in output file for process
            fnd_file.put_line (fnd_file.output, '');
            fnd_file.put_line (
                fnd_file.output,
                   RPAD (l_case_folds_rec.party_name, 30, ' ')
                || RPAD (l_case_folds_rec.account_number, 20, ' ')
                || RPAD (l_case_folds_rec.case_folder_number, 30, ' ')
                || RPAD (l_case_folds_rec.status, 30, ' ')
                || lc_notification_status);
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_retcode   := 2;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected error in procedure send_mail_notification: '
                || SQLERRM);
    END send_mail_notification;
END xxd_ar_credit_appl_pkg;
/
