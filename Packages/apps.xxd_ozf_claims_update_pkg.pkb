--
-- XXD_OZF_CLAIMS_UPDATE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:04 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_OZF_CLAIMS_UPDATE_PKG"
IS
    --  ####################################################################################################
    -- Package      : XXD_OZF_CLAIMS_UPDATE_PKG
    -- Design       : Package is used to modify/update AR claims/deductions
    -- Notes        :
    -- Modification :
    --  --------------
    --  Date            Name                Ver     Change          Description
    --  ----------      --------------      -----   -------------   ---------------------
    --  10-Dec-2019     Kranthi Bollam      1.0     CCR0008344      Initial Version
    --  ####################################################################################################
    gv_package_name   CONSTANT VARCHAR2 (30) := 'XXD_OZF_CLAIMS_UPDATE_PKG';
    gn_user_id        CONSTANT NUMBER := fnd_global.user_id;
    gn_login_id       CONSTANT NUMBER := fnd_global.login_id;
    gn_org_id         CONSTANT NUMBER := fnd_profile.VALUE ('ORG_ID');
    gn_resp_id        CONSTANT NUMBER := fnd_global.resp_id;
    gn_resp_appl_id   CONSTANT NUMBER := fnd_global.resp_appl_id;
    gn_request_id     CONSTANT NUMBER := fnd_global.conc_request_id;

    --Purge Procedure
    PROCEDURE purge_data (pv_ret_message OUT VARCHAR2)
    IS
        ln_purge_days   NUMBER := 90;
    BEGIN
        DELETE FROM xxdo.xxd_ozf_claims_update_stg_t stg
              WHERE 1 = 1 AND stg.creation_date < SYSDATE - ln_purge_days;

        pv_ret_message   := NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_ret_message   :=
                SUBSTR ('Error in Purging Data. Error is: ' || SQLERRM,
                        1,
                        2000);
    END purge_data;

    --Main Procedure called by WebADI
    PROCEDURE upload_proc (pv_operating_unit        VARCHAR2,
                           pv_claim_number          VARCHAR2,
                           pv_auto_write_off_flag   VARCHAR2 DEFAULT NULL,
                           pv_claim_reason          VARCHAR2 DEFAULT NULL,
                           pv_claim_type            VARCHAR2 DEFAULT NULL,
                           pv_claim_owner           VARCHAR2 DEFAULT NULL,
                           pv_customer_reference    VARCHAR2 DEFAULT NULL,
                           pd_gl_date               DATE DEFAULT NULL,
                           pv_customer_reason       VARCHAR2 DEFAULT NULL,
                           pv_payment_method        VARCHAR2 DEFAULT NULL,
                           pv_claim_status          VARCHAR2 DEFAULT NULL)
    IS
        CURSOR claim_cur (cn_record_id IN NUMBER)
        IS
            SELECT stg.*, oca.object_version_number
              FROM xxdo.xxd_ozf_claims_update_stg_t stg, ozf.ozf_claims_all oca
             WHERE     1 = 1
                   AND stg.record_id = cn_record_id
                   AND stg.record_status = 'N'
                   AND stg.claim_id = oca.claim_id;

        ln_record_id               NUMBER := NULL;
        lv_error_message           VARCHAR2 (4000) := NULL;
        lv_operating_unit          VARCHAR2 (240) := NULL;
        ln_org_id                  NUMBER := NULL;
        lv_claim_status            VARCHAR2 (30) := NULL;
        ln_valid_status_cnt        NUMBER := NULL;
        ln_claim_id                NUMBER := NULL;
        ln_reason_code_id          NUMBER := NULL;
        ln_claim_type_id           NUMBER := NULL;
        ln_claim_owner_id          NUMBER := NULL;
        le_webadi_exception        EXCEPTION;
        lv_return_status           VARCHAR2 (1);
        ln_msg_count               NUMBER;
        lv_msg_data                VARCHAR2 (20000);
        lv_claim_pub_rec           ozf_claim_pub.claim_rec_type;
        lv_claim_line_pub_tbl      ozf_claim_pub.claim_line_tbl_type;
        lv_api_version    CONSTANT NUMBER := 1.0;
        lv_object_version_number   NUMBER;
        lv_msg                     VARCHAR2 (2000) := NULL;
        lv_ret_message             VARCHAR2 (2000) := NULL;
        lv_payment_method          VARCHAR2 (30) := NULL;
        ln_reason_code_id_claim    NUMBER := NULL; --Added on 17Apr2020 for UAT Defect#29
    BEGIN
        --Exit if all the parameters passed are NULL
        IF (pv_auto_write_off_flag IS NULL AND pv_claim_reason IS NULL AND pv_claim_type IS NULL AND pv_claim_owner IS NULL AND pv_customer_reference IS NULL AND pd_gl_date IS NULL AND pv_customer_reason IS NULL AND pv_payment_method IS NULL AND pv_claim_status IS NULL)
        THEN
            lv_error_message   :=
                'No values to Update. Provide atleast one value to update. ';
            RAISE le_webadi_exception;
        END IF;

        --Calling purge Procedure
        purge_data (pv_ret_message => lv_ret_message);

        --Getting org_id of the Operating Unit --START
        BEGIN
            SELECT hou.organization_id
              INTO ln_org_id
              FROM hr_operating_units hou
             WHERE hou.name = pv_operating_unit;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lv_error_message   :=
                    lv_error_message || 'Operating Unit does not exists. ';
                RAISE le_webadi_exception;
            WHEN OTHERS
            THEN
                lv_error_message   :=
                    SUBSTR (
                           lv_error_message
                        || 'Error While Validating Operating Unit. Error is: '
                        || SQLERRM
                        || '. ',
                        1,
                        2000);
                RAISE le_webadi_exception;
        END;

        --Getting org_id of the Operating Unit --END

        --Check if Claim Number Exists or Not --START
        BEGIN
            SELECT claim_id, oca.status_code
              INTO ln_claim_id, lv_claim_status
              FROM ozf.ozf_claims_all oca
             WHERE     1 = 1
                   AND UPPER (oca.claim_number) = UPPER (pv_claim_number)
                   AND oca.org_id = ln_org_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lv_error_message   :=
                    SUBSTR (
                        lv_error_message || 'Claim Number does not exists. ',
                        1,
                        2000);
                RAISE le_webadi_exception;
            WHEN OTHERS
            THEN
                lv_error_message   :=
                    SUBSTR (
                           lv_error_message
                        || 'Error getting Claim ID. Error is: '
                        || SQLERRM,
                        1,
                        2000);
                RAISE le_webadi_exception;
        END;

        --Check if Claim Number Exists or Not --END

        --Check if Existing Claim Status is VALID or Not --START
        IF     lv_claim_status IS NOT NULL
           AND lv_claim_status NOT IN ('NEW', 'OPEN', 'CANCELLED',
                                       'COMPLETE')
        THEN
            lv_error_message   :=
                SUBSTR (
                       lv_error_message
                    || 'Claim Status is '
                    || lv_claim_status
                    || '. Should be NEW, OPEN, CANCELLED or COMPLETE. ',
                    1,
                    2000);
            RAISE le_webadi_exception;
        END IF;

        --Check if Existing Claim Status is VALID or Not --END

        --Claim Status to COMPLETE validation --START
        IF     pv_claim_status IS NOT NULL
           AND pv_claim_status = 'COMPLETE'
           AND pv_payment_method IS NULL          --Settlement field in WEBADI
        THEN
            lv_error_message   :=
                SUBSTR (
                       lv_error_message
                    || 'SETTLEMENT METHOD is required to change Claim Status to COMPLETE. ',
                    1,
                    2000);
            RAISE le_webadi_exception;
        END IF;

        --Claim Status to COMPLETE validation --END

        --Claim Status in NEW can only be udpated to OPEN validation --START
        IF     lv_claim_status IS NOT NULL
           AND lv_claim_status = 'NEW'
           AND pv_claim_status IS NOT NULL
           AND pv_claim_status IN ('CANCELLED', 'COMPLETE')
        THEN
            lv_error_message   :=
                SUBSTR (
                       lv_error_message
                    || 'Existing Claim status is NEW and can only be updated to OPEN. ',
                    1,
                    2000);
            RAISE le_webadi_exception;
        END IF;

        --Claim Status in NEW can only be updated to OPEN validation --END

        --If Auto Writeoff Flag = Yes(T) then Claim Status can't be updated to CANCELLED validation --START
        IF     pv_auto_write_off_flag IS NOT NULL
           AND pv_auto_write_off_flag = 'T'
           AND pv_claim_status IS NOT NULL
           AND pv_claim_status = 'CANCELLED'
        THEN
            lv_error_message   :=
                SUBSTR (
                       lv_error_message
                    || 'Auto writeoff flag is Yes(T), Claim cannot be CANCELLED. ',
                    1,
                    2000);
            RAISE le_webadi_exception;
        END IF;

        --If Auto Writeoff Flag = Yes(T) then Claim Status can't be updated to CANCELLED validation --END

        --GL Date Validation --START
        IF pd_gl_date IS NOT NULL
        THEN
            IF pd_gl_date < TRUNC (SYSDATE)
            THEN
                lv_error_message   :=
                    SUBSTR (
                           lv_error_message
                        || 'GL Date must be greater than or equal to Current Date. ',
                        1,
                        2000);
            END IF;
        END IF;

        --GL Date Validation --END

        --Claim Reason Validation, Getting Claim Reason Code ID --START
        IF pv_claim_reason IS NOT NULL
        THEN
            BEGIN
                SELECT orc.reason_code_id
                  INTO ln_reason_code_id
                  FROM ozf.ozf_reason_codes_all_b orc, ozf.ozf_reason_codes_all_tl orct
                 WHERE     1 = 1
                       AND orc.org_id = ln_org_id
                       AND SYSDATE BETWEEN NVL (orc.start_date_active,
                                                SYSDATE)
                                       AND NVL (orc.end_date_active,
                                                SYSDATE + 1)
                       AND orc.reason_code_id = orct.reason_code_id
                       AND orc.org_id = orct.org_id
                       AND orct.language = 'US'
                       AND orct.name = pv_claim_reason;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || 'Claim Reason does not exists for the Operating Unit Selected. ',
                            1,
                            2000);
                WHEN OTHERS
                THEN
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || 'Error while validating Claim Reason. Error is: '
                            || SQLERRM
                            || '. ',
                            1,
                            2000);
            END;
        END IF;

        --Claim Reason Validation, Getting Claim Reason Code ID --END

        --Claim Type Validation, Getting Claim Type ID --START
        IF pv_claim_type IS NOT NULL
        THEN
            BEGIN
                SELECT oct.claim_type_id
                  INTO ln_claim_type_id
                  FROM ozf.ozf_claim_types_all_b oct, ozf.ozf_claim_types_all_tl octt
                 WHERE     1 = 1
                       AND oct.org_id = ln_org_id
                       AND SYSDATE BETWEEN NVL (oct.start_date, SYSDATE)
                                       AND NVL (oct.end_date, SYSDATE + 1)
                       AND oct.claim_type_id = octt.claim_type_id
                       AND oct.org_id = octt.org_id
                       AND octt.language = 'US'
                       AND oct.zd_edition_name = octt.zd_edition_name
                       AND octt.name = pv_claim_type;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || 'Claim Type does not exists for the Operating Unit Selected. ',
                            1,
                            2000);
                WHEN OTHERS
                THEN
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || 'Error while validating Claim Type. Error is: '
                            || SQLERRM
                            || '. ',
                            1,
                            2000);
            END;
        END IF;

        --Claim Type Validation, Getting Claim Type ID --END

        --Claim Owner Validation, Getting Claim Owner ID --START
        IF pv_claim_owner IS NOT NULL
        THEN
            BEGIN
                SELECT jret.resource_id
                  INTO ln_claim_owner_id
                  FROM apps.jtf_rs_resource_extns jre, apps.jtf_rs_resource_extns_tl jret
                 WHERE     1 = 1
                       AND jre.resource_id = jret.resource_id
                       AND SYSDATE BETWEEN NVL (jre.start_date_active,
                                                SYSDATE)
                                       AND NVL (jre.end_date_active,
                                                SYSDATE + 1)
                       AND jret.language = 'US'
                       AND UPPER (jret.resource_name) =
                           UPPER (TRIM (pv_claim_owner));
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || 'Claim Owner does not exists. ',
                            1,
                            2000);
                WHEN OTHERS
                THEN
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || 'Error while validating Claim Owner. Error is: '
                            || SQLERRM
                            || '. ',
                            1,
                            2000);
            END;
        END IF;

        --Claim Owner Validation, Getting Claim Owner ID --END

        --Customer Reason Validation --START
        IF pv_customer_reason IS NOT NULL
        THEN
            IF LENGTH (pv_customer_reason) > 30
            THEN
                lv_error_message   :=
                    SUBSTR (
                           lv_error_message
                        || 'Customer Reason cannot be more than 30 characters. ',
                        1,
                        2000);
            END IF;
        END IF;

        --Customer Reason Validation --END

        --Get Record ID --START
        IF lv_error_message IS NULL
        THEN
            BEGIN
                SELECT xxdo.xxd_ozf_claims_update_stg_s.NEXTVAL record_id
                  INTO ln_record_id
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || 'Error in generating Record ID from Sequence. Error is: '
                            || SQLERRM
                            || '. ',
                            1,
                            2000);
            END;
        END IF;

        --Get Record ID --END

        --If there are any errors then raise exception and exit
        IF lv_error_message IS NOT NULL
        THEN
            RAISE le_webadi_exception;
        END IF;

        --Now insert the validated data into the staging table
        BEGIN
            INSERT INTO xxdo.xxd_ozf_claims_update_stg_t (record_id, operating_unit, claim_number, write_off_flag, claim_reason, claim_type, claim_owner, customer_reference, gl_date, customer_reason, payment_method, claim_status, record_status, error_message, creation_date, created_by, last_update_date, last_updated_by, last_update_login, request_id, org_id, claim_id, claim_reason_code_id, claim_type_id
                                                          , claim_owner_id)
                SELECT ln_record_id record_id, pv_operating_unit operating_unit, pv_claim_number claim_number,
                       pv_auto_write_off_flag write_off_flag, pv_claim_reason claim_reason, pv_claim_type claim_type,
                       pv_claim_owner claim_owner, pv_customer_reference customer_reference, pd_gl_date gl_date,
                       pv_customer_reason customer_reason, pv_payment_method payment_method, pv_claim_status claim_status,
                       'N' record_status, NULL error_message, SYSDATE creation_date,
                       gn_user_id created_by, SYSDATE last_update_date, gn_user_id last_updated_by,
                       gn_login_id last_update_login, gn_request_id request_id, ln_org_id org_id,
                       ln_claim_id claim_id, ln_reason_code_id claim_reason_code_id, ln_claim_type_id claim_type_id,
                       ln_claim_owner_id claim_owner_id
                  FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_message   :=
                    SUBSTR (
                           'Error while inserting into staging table. Error is '
                        || SQLERRM,
                        1,
                        2000);
                RAISE le_webadi_exception;
        END;

        --Process the Claim/Deduction --START
        FOR claim_rec IN claim_cur (cn_record_id => ln_record_id)
        LOOP
            mo_global.set_policy_context ('S', claim_rec.org_id); --Setting the operating unit
            lv_claim_pub_rec.claim_id                := claim_rec.claim_id;
            lv_claim_pub_rec.object_version_number   :=
                claim_rec.object_version_number;
            lv_claim_pub_rec.last_updated_by         := gn_user_id;

            IF claim_rec.gl_date IS NOT NULL
            THEN
                lv_claim_pub_rec.gl_date   := claim_rec.gl_date;
            END IF;

            IF claim_rec.customer_reason IS NOT NULL
            THEN
                --lv_claim_pub_rec.customer_reason := claim_rec.customer_reason; --Commented for UAT Defect#29 on 17Apr2020
                --Added on 17Apr2020 for UAT Defect#29 --START
                IF claim_rec.claim_reason_code_id IS NOT NULL
                THEN
                    lv_claim_pub_rec.customer_reason   :=
                        claim_rec.customer_reason;
                ELSE
                    BEGIN
                        SELECT reason_code_id
                          INTO ln_reason_code_id_claim
                          FROM ozf.ozf_claims_all oca
                         WHERE     1 = 1
                               AND oca.claim_id = ln_claim_id
                               AND oca.org_id = ln_org_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_reason_code_id_claim   := NULL;
                    END;

                    IF ln_reason_code_id_claim IS NOT NULL
                    THEN
                        lv_claim_pub_rec.customer_reason   :=
                            claim_rec.customer_reason;
                        lv_claim_pub_rec.reason_code_id   :=
                            ln_reason_code_id_claim;
                    ELSE
                        lv_error_message   :=
                            SUBSTR (
                                'Claim Reason is MANDATORY for Customer Reason Update. There is no claim reason assigned to claim or passed in WEBADI',
                                1,
                                2000);
                        RAISE le_webadi_exception;
                    END IF;
                END IF;
            --Added on 17Apr2020 for UAT Defect#29 --END
            END IF;

            IF claim_rec.write_off_flag IS NOT NULL
            THEN
                lv_claim_pub_rec.write_off_flag   := claim_rec.write_off_flag;
            END IF;

            IF claim_rec.claim_reason_code_id IS NOT NULL
            THEN
                lv_claim_pub_rec.reason_code_id   :=
                    claim_rec.claim_reason_code_id;
            END IF;

            IF claim_rec.claim_type_id IS NOT NULL
            THEN
                lv_claim_pub_rec.claim_type_id   := claim_rec.claim_type_id;
            END IF;

            IF claim_rec.claim_owner_id IS NOT NULL
            THEN
                lv_claim_pub_rec.owner_id   := claim_rec.claim_owner_id;
            END IF;

            IF claim_rec.customer_reference IS NOT NULL
            THEN
                lv_claim_pub_rec.customer_ref_number   :=
                    claim_rec.customer_reference;
            END IF;

            IF claim_rec.claim_status IS NOT NULL
            THEN
                lv_claim_pub_rec.status_code   := claim_rec.claim_status;
            END IF;

            IF claim_rec.payment_method IS NOT NULL
            THEN
                --Get Settlement Method Code(Payment Method Code)
                BEGIN
                    SELECT lookup_code
                      INTO lv_payment_method
                      FROM apps.ozf_lookups ol
                     WHERE     1 = 1
                           AND ol.lookup_type = 'OZF_PAYMENT_METHOD'
                           AND ol.meaning = claim_rec.payment_method
                           AND NVL (ol.enabled_flag, 'N') = 'Y'
                           AND SYSDATE BETWEEN NVL (ol.start_date_active,
                                                    SYSDATE)
                                           AND NVL (ol.end_date_active,
                                                    SYSDATE + 1);

                    lv_claim_pub_rec.payment_method   := lv_payment_method;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_error_message   := 'Invalid Settlement Method. ';
                        RAISE le_webadi_exception;
                END;
            END IF;

            ------------------------------------- Update Claim API Call------------------------------------------
            ozf_claim_pub.update_claim (
                p_api_version_number      => lv_api_version,
                p_init_msg_list           => fnd_api.g_false,
                p_commit                  => fnd_api.g_false,
                p_validation_level        => fnd_api.g_valid_level_full,
                x_return_status           => lv_return_status,
                x_msg_count               => ln_msg_count,
                x_msg_data                => lv_msg_data,
                p_claim_rec               => lv_claim_pub_rec,
                p_claim_line_tbl          => lv_claim_line_pub_tbl,
                x_object_version_number   => lv_object_version_number);

            ------------------------------------------------------------------------------------------------------

            IF lv_return_status = fnd_api.g_ret_sts_success
            THEN
                BEGIN
                    UPDATE xxdo.xxd_ozf_claims_update_stg_t stg
                       SET stg.record_status = 'S', stg.last_updated_by = gn_user_id, stg.last_update_date = SYSDATE
                     WHERE 1 = 1 AND stg.record_id = ln_record_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_error_message   :=
                               'Claim Updated successfully. Error in updating staging table status to SUCCESS. Error is:'
                            || SUBSTR (SQLERRM, 1, 500);
                        RAISE le_webadi_exception;
                END;
            ELSE
                lv_error_message   := 'Claim Update Failed. ';

                FOR i IN 1 .. ln_msg_count
                LOOP
                    lv_msg   :=
                           lv_msg
                        || '.'
                        || SUBSTR (
                               fnd_msg_pub.get (p_msg_index   => i,
                                                p_encoded     => 'F'),
                               1,
                               254);
                END LOOP;

                lv_error_message   :=
                    lv_error_message || 'Error is: ' || lv_msg;

                BEGIN
                    UPDATE xxdo.xxd_ozf_claims_update_stg_t stg
                       SET stg.record_status = 'E', stg.error_message = SUBSTR (lv_error_message, 1, 4000), stg.last_updated_by = gn_user_id,
                           stg.last_update_date = SYSDATE
                     WHERE 1 = 1 AND stg.record_id = ln_record_id;

                    RAISE le_webadi_exception;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_error_message   :=
                               lv_error_message
                            || '. Staging table status update ERROR. Error is:'
                            || SUBSTR (SQLERRM, 1, 500);
                        RAISE le_webadi_exception;
                END;
            END IF;
        END LOOP;
    --Process the Claim/Deduction --END
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
END xxd_ozf_claims_update_pkg;
/
