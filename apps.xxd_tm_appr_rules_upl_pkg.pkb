--
-- XXD_TM_APPR_RULES_UPL_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:08 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_TM_APPR_RULES_UPL_PKG"
IS
    --  ####################################################################################################
    --  Author(s)       : Aravind Kannuri
    --  System          : Oracle Applications
    --  Subsystem       : EBS
    --  Change          : CCR0007546
    --  Schema          : APPS
    --  Purpose         : Package is used for WebADI to Create\Edit of AMS Approval Rules
    --  Dependency      : None
    --  Change History
    --  --------------
    --  Date            Name                Ver     Change          Description
    --  ----------      --------------      -----   -------------   ---------------------
    --  23-Oct-2018     Aravind Kannuri     1.0     NA              Initial Version
    --  10-Dec-2019     Showkath Ali        1.1     CCR0008340      Added Setup Type
    --
    --  ####################################################################################################

    gv_package_name   CONSTANT VARCHAR2 (30) := 'XXD_TM_APPR_RULES_UPL_PKG';
    gn_user_id        CONSTANT NUMBER := fnd_global.user_id;
    gn_login_id       CONSTANT NUMBER := fnd_global.login_id;
    gn_org_id         CONSTANT NUMBER := fnd_profile.VALUE ('ORG_ID');
    gn_resp_id        CONSTANT NUMBER := fnd_global.resp_id;
    gn_resp_appl_id   CONSTANT NUMBER := fnd_global.resp_appl_id;
    gn_request_id     CONSTANT NUMBER := fnd_global.conc_request_id;


    --Upload Procedure called by WebADI - MAIN
    PROCEDURE upload_proc (pv_mode VARCHAR2, pv_ou_name VARCHAR2, pv_old_appr_rule_name VARCHAR2, pv_appr_rule_name VARCHAR2, pv_approval_type VARCHAR2, pv_claim_type VARCHAR2, pv_reason VARCHAR2, pv_start_date VARCHAR2, pv_end_date VARCHAR2, pv_currency VARCHAR2, pn_min_amount NUMBER, pn_max_amount NUMBER, pv_description VARCHAR2, pv_appr_order NUMBER, pv_approver_type VARCHAR2, pv_appr_user_role VARCHAR2, pv_appr_start_date VARCHAR2, pv_appr_end_date VARCHAR2, pv_attribute_num1 NUMBER DEFAULT NULL, pv_attribute_num2 NUMBER DEFAULT NULL, pv_attribute_num3 NUMBER DEFAULT NULL, pv_attribute_num4 NUMBER DEFAULT NULL, --pv_attribute_chr1         VARCHAR2  DEFAULT NULL, --CCR0008340
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               pv_attribute_chr1 VARCHAR2, --CCR0008340
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           pv_attribute_chr2 VARCHAR2 DEFAULT NULL, pv_attribute_chr3 VARCHAR2 DEFAULT NULL, pv_attribute_chr4 VARCHAR2 DEFAULT NULL, pv_attribute_date1 DATE DEFAULT NULL
                           , pv_attribute_date2 DATE DEFAULT NULL)
    IS
        ln_appr_rule_exists       NUMBER := 0;
        ln_old_appr_rule_exists   NUMBER := 0;
        l_new_appr_rule_exists    NUMBER := 0;
        lv_opr_mode               VARCHAR2 (30)
                                      := NVL (UPPER (TRIM (pv_mode)), 'NEW'); -- NEW\EDIT
        ln_org_id                 hr_operating_units.organization_id%TYPE
                                      := NULL;
        ln_approval_detail_id     ams_approval_details_vl.approval_detail_id%TYPE
            := NULL;
        ln_claim_type_id          ozf_claim_types_all_tl.claim_type_id%TYPE
                                      := NULL;
        ln_reason_code_id         ozf_reason_codes_all_tl.reason_code_id%TYPE
                                      := NULL;
        ln_user_role_id           jtf_rs_resource_extns_vl.resource_id%TYPE
                                      := NULL;
        lv_appr_user_role         jtf_rs_resource_extns_vl.resource_name%TYPE
                                      := NULL;
        lv_currency_code          fnd_currencies_tl.currency_code%TYPE
                                      := NULL;
        lv_error_message          VARCHAR2 (4000) := NULL;
        lv_upload_status          VARCHAR2 (1) := 'N';
        lv_return_status          VARCHAR2 (1) := NULL;
        le_webadi_exception       EXCEPTION;
        ln_setup_id               ams_custom_setups_tl.custom_setup_id%TYPE
                                      := NULL;                    --CCR0008340
    BEGIN
        -- WEBADI Validations Start

        -- Validate Mode
        IF ((lv_opr_mode IS NULL) OR (pv_ou_name IS NULL))
        THEN
            lv_error_message   :=
                'Mandatory Columns are Missing : Mode or Operating Unit, For Mode to choose NEW or EDIT. ';
            lv_upload_status   := 'E';
            RAISE le_webadi_exception;
        END IF;

        --Validate if MODE = NEW
        IF lv_opr_mode = 'NEW'
        THEN
            IF ((pv_appr_rule_name IS NULL) OR (pv_approval_type IS NULL) OR (pv_claim_type IS NULL) OR (pv_start_date IS NULL) OR (pv_currency IS NULL))
            THEN
                lv_error_message   :=
                    'Mandatory Columns are Missing: New Approval Rule Name, Approval Type, Claim Type, Start Date OR Currency. ';
                lv_upload_status   := 'E';
                RAISE le_webadi_exception;
            END IF;
        END IF;

        --Validate Operating unit
        IF pv_ou_name IS NOT NULL
        THEN
            BEGIN
                SELECT organization_id
                  INTO ln_org_id
                  FROM hr_operating_units
                 WHERE NAME = TRIM (pv_ou_name);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_org_id          := NULL;
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || 'Invalid Operating unit : '
                            || pv_ou_name
                            || ' '
                            || SQLERRM
                            || '. ',
                            1,
                            2000);
                    lv_upload_status   := 'E';
            END;
        END IF;

        --CCR0008340 Changes Start
        --Validate Setup Type
        IF pv_attribute_chr1 IS NOT NULL
        THEN
            BEGIN
                SELECT custom_setup_id
                  INTO ln_setup_id
                  FROM ams_custom_setups_tl
                 WHERE     setup_name = TRIM (pv_attribute_chr1)
                       AND language = 'US';
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_setup_id        := NULL;
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || 'Invalid Setup Type: '
                            || pv_attribute_chr1
                            || ' '
                            || SQLERRM
                            || '. ',
                            1,
                            2000);
                    lv_upload_status   := 'E';
            END;
        END IF;

        --CCR0008340 Changes end

        --Validate Claim Type
        IF pv_claim_type IS NOT NULL
        THEN
            BEGIN
                SELECT claim_type_id
                  INTO ln_claim_type_id
                  FROM ozf_claim_types_all_tl
                 WHERE     NAME = TRIM (pv_claim_type)
                       AND org_id = ln_org_id
                       AND LANGUAGE = USERENV ('LANG');
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_claim_type_id   := NULL;
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || 'Invalid Claim Type : '
                            || pv_claim_type
                            || ' '
                            || SQLERRM
                            || '. ',
                            1,
                            2000);
                    lv_upload_status   := 'E';
            END;
        END IF;

        --Validate Approval Start Date
        IF pv_start_date IS NOT NULL
        THEN
            IF TO_DATE (pv_start_date, 'DD-MON-YYYY') < TRUNC (SYSDATE)
            THEN
                lv_error_message   :=
                    SUBSTR (
                           lv_error_message
                        || 'Approval Start Date must be greater than or equal to SYSDATE. ',
                        1,
                        2000);
                lv_upload_status   := 'E';
            END IF;
        END IF;

        --Validate Approval End Date
        IF pv_end_date IS NOT NULL
        THEN
            IF TO_DATE (pv_end_date, 'DD-MON-YYYY') <
               NVL (TO_DATE (pv_start_date, 'DD-MON-YYYY'), TRUNC (SYSDATE))
            THEN
                lv_error_message   :=
                    SUBSTR (
                           lv_error_message
                        || 'Approval End Date must be greater then Approval Start Date\Sysdate. ',
                        1,
                        2000);
                lv_upload_status   := 'E';
            END IF;
        END IF;

        --Validate Approvers Details
        IF lv_opr_mode = 'NEW'
        THEN
            IF ((pv_appr_order IS NOT NULL) OR (pv_approver_type IS NOT NULL) OR (pv_appr_start_date IS NOT NULL) OR (pv_appr_end_date IS NOT NULL))
            THEN
                IF pv_appr_user_role IS NULL
                THEN
                    lv_error_message   :=
                        'NEW-Approver User Role should be Mandatory if Approvers details exists. ';
                    lv_upload_status   := 'E';
                    RAISE le_webadi_exception;
                ELSE
                    IF ((pv_appr_order IS NULL) OR (pv_approver_type IS NULL))
                    THEN
                        lv_error_message   :=
                            'NEW-Approver Order\Approver Type should not be NULL if Approver User Role exists. ';
                        lv_upload_status   := 'E';
                        RAISE le_webadi_exception;
                    END IF;
                END IF;
            END IF;
        ELSE                                             --lv_opr_mode ='EDIT'
            IF ((pv_appr_user_role IS NOT NULL) OR (pv_appr_start_date IS NOT NULL) OR (pv_appr_end_date IS NOT NULL))
            THEN
                IF ((pv_appr_order IS NULL) OR (pv_approver_type IS NULL))
                THEN
                    lv_error_message   :=
                        'EDIT-Approver Order\Approver Type should not be NULL if Approvers detail exists. ';
                    lv_upload_status   := 'E';
                    RAISE le_webadi_exception;
                END IF;
            ELSIF ((pv_appr_user_role IS NULL) AND (pv_appr_start_date IS NULL) AND (pv_appr_end_date IS NULL))
            THEN
                IF ((pv_appr_order IS NOT NULL) OR (pv_approver_type IS NOT NULL))
                THEN
                    lv_error_message   :=
                        'EDIT-Approvers details should not be NULL if Approver Order\Approver Type exists. ';
                    lv_upload_status   := 'E';
                    RAISE le_webadi_exception;
                END IF;
            END IF;
        END IF;

        --Validate Approvers Start Date
        IF pv_appr_start_date IS NOT NULL
        THEN
            IF (TO_DATE (pv_appr_start_date, 'DD-MON-YYYY') < TRUNC (SYSDATE) AND TO_DATE (pv_appr_start_date, 'DD-MON-YYYY') < NVL (TO_DATE (pv_start_date, 'DD-MON-YYYY'), TRUNC (SYSDATE)))
            THEN
                lv_error_message   :=
                    SUBSTR (
                           lv_error_message
                        || 'Approver Start Date must be greater than or equal to Sysdate\Approval Start Date. ',
                        1,
                        2000);
                lv_upload_status   := 'E';
            END IF;
        END IF;

        --Validate Approver End Date
        IF pv_appr_end_date IS NOT NULL
        THEN
            IF TO_DATE (pv_appr_end_date, 'DD-MON-YYYY') <
               NVL (TO_DATE (pv_appr_start_date, 'DD-MON-YYYY'),
                    TRUNC (SYSDATE))
            THEN
                lv_error_message   :=
                    SUBSTR (
                           lv_error_message
                        || 'Approver End Date must be greater then Approver Start Date\Sysdate. ',
                        1,
                        2000);
                lv_upload_status   := 'E';
            END IF;

            IF pv_end_date IS NOT NULL
            THEN
                IF TO_DATE (pv_appr_end_date, 'DD-MON-YYYY') >
                   TO_DATE (pv_end_date, 'DD-MON-YYYY')
                THEN
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || 'Approver End Date must be lesser then Approval End Date. ',
                            1,
                            2000);
                    lv_upload_status   := 'E';
                END IF;
            END IF;
        END IF;

        --Validate Currency
        IF pv_currency IS NOT NULL
        THEN
            BEGIN
                SELECT currency_code
                  INTO lv_currency_code
                  FROM fnd_currencies_tl
                 WHERE     UPPER (currency_code) = UPPER (TRIM (pv_currency))
                       AND LANGUAGE = USERENV ('LANG');
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_currency_code   := NULL;
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || 'Invalid Currency Code : '
                            || pv_currency
                            || ' '
                            || SQLERRM
                            || '. ',
                            1,
                            2000);
                    lv_upload_status   := 'E';
            END;
        END IF;

        --Validate Reason code
        IF pv_reason IS NOT NULL
        THEN
            BEGIN
                SELECT reason_code_id
                  INTO ln_reason_code_id
                  FROM ozf_reason_codes_all_tl
                 WHERE     NAME = TRIM (pv_reason)
                       AND org_id = ln_org_id
                       AND LANGUAGE = USERENV ('LANG');
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_reason_code_id   := NULL;
                    lv_error_message    :=
                        SUBSTR (
                               lv_error_message
                            || 'Invalid Reason Code : '
                            || pv_reason
                            || ' '
                            || SQLERRM
                            || '. ',
                            1,
                            2000);
                    lv_upload_status    := 'E';
            END;
        END IF;

        --Validate Approver User Role
        IF pv_appr_user_role IS NOT NULL
        THEN
            BEGIN
                SELECT resource_id, resource_name
                  INTO ln_user_role_id, lv_appr_user_role
                  FROM jtf_rs_resource_extns_vl
                 WHERE     1 = 1
                       AND CATEGORY = 'EMPLOYEE'
                       AND UPPER (resource_name) =
                           UPPER (TRIM (pv_appr_user_role))
                       AND NVL (end_date_active, TRUNC (SYSDATE)) >=
                           TRUNC (SYSDATE);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_user_role_id     := NULL;
                    lv_appr_user_role   := NULL;
                    lv_error_message    :=
                        SUBSTR (
                               lv_error_message
                            || 'Invalid Approver User Role : '
                            || pv_appr_user_role
                            || ' '
                            || SQLERRM
                            || '. ',
                            1,
                            2000);
                    lv_upload_status    := 'E';
            END;
        END IF;

        --Validate Approval Rule Name by MODE
        IF lv_opr_mode = 'NEW'
        THEN
            --Verify Approval Rule Exists or Not
            BEGIN
                SELECT COUNT (1)
                  INTO ln_appr_rule_exists
                  FROM ams_approval_details_vl
                 WHERE     1 = 1
                       AND NAME = TRIM (pv_appr_rule_name)
                       AND organization_id = ln_org_id;

                IF ln_appr_rule_exists <> 0
                THEN
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || 'Approval Rule Name already Exists. ',
                            1,
                            2000);
                    lv_upload_status   := 'E';
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || 'Approval Rule Name Validation failed : '
                            || pv_appr_rule_name
                            || ' '
                            || SQLERRM
                            || '. ',
                            1,
                            2000);
                    lv_upload_status   := 'E';
            END;
        ELSE                                         -- IF lv_opr_mode ='EDIT'
            ---------------------------
            --EDIT MODE for Updation
            ---------------------------
            IF pv_old_appr_rule_name IS NULL
            THEN
                lv_error_message   :=
                    SUBSTR (
                           lv_error_message
                        || 'OLD Approval Rule Name should not be NULL, its mandatory if Mode=EDIT . ',
                        1,
                        2000);
                lv_upload_status   := 'E';
            ELSE                       -- IF pv_old_appr_rule_name IS NOT NULL
                BEGIN
                    SELECT COUNT (1)
                      INTO ln_old_appr_rule_exists
                      FROM ams_approval_details_vl
                     WHERE     1 = 1
                           AND NAME = TRIM (pv_old_appr_rule_name)
                           AND organization_id = ln_org_id;

                    IF ln_old_appr_rule_exists <> 0
                    THEN
                        SELECT DISTINCT approval_detail_id
                          INTO ln_approval_detail_id
                          FROM ams_approval_details_vl
                         WHERE     1 = 1
                               AND NAME = TRIM (pv_old_appr_rule_name)
                               AND organization_id = ln_org_id;
                    ELSE
                        lv_error_message   :=
                            SUBSTR (
                                   lv_error_message
                                || 'OLD Approval Rule Name is INVALID : '
                                || pv_old_appr_rule_name,
                                1,
                                2000);
                        lv_upload_status   := 'E';
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_approval_detail_id   := NULL;
                        lv_error_message        :=
                            SUBSTR (
                                   lv_error_message
                                || 'Old Approval Rule Name Validation failed : '
                                || pv_old_appr_rule_name
                                || ' '
                                || SQLERRM
                                || '. ',
                                1,
                                2000);
                        lv_upload_status        := 'E';
                END;

                --Verify New provided Approval Rule name exists or not
                IF ((ln_approval_detail_id IS NOT NULL) AND (pv_appr_rule_name IS NOT NULL))
                THEN
                    BEGIN
                        SELECT COUNT (1)
                          INTO l_new_appr_rule_exists
                          FROM ams_approval_details_vl
                         WHERE     1 = 1
                               AND NAME = TRIM (pv_appr_rule_name)
                               AND organization_id = ln_org_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_new_appr_rule_exists   := 0;
                            DBMS_OUTPUT.put_line (
                                   'EDIT Mode -New Approval Rule Name Validation Error =>'
                                || l_new_appr_rule_exists);
                    END;

                    IF l_new_appr_rule_exists <> 0
                    THEN
                        lv_error_message   :=
                            SUBSTR (
                                   lv_error_message
                                || 'EDIT Mode -New Approval Rule Name already Exists - Invalid : '
                                || pv_appr_rule_name
                                || ' '
                                || SQLERRM
                                || '. ',
                                1,
                                2000);
                        lv_upload_status   := 'E';
                    END IF;
                END IF;      -- End of IF for Approval Rule name exists or not
            END IF;                        -- END IF for pv_old_appr_rule_name
        END IF;                                    ---- END IF for lv_opr_mode

        IF lv_upload_status <> 'E' AND lv_error_message IS NULL
        THEN
            BEGIN
                -- Loading WebADI data to Staging table
                INSERT INTO xxdo.xxd_ams_approval_upload_tbl (
                                operating_unit,
                                old_appr_rule_name,
                                approval_rule_name,
                                approval_type,
                                claim_type,
                                reason,
                                start_date,
                                end_date,
                                currency,
                                minimum_amount,
                                maximum_amount,
                                description,
                                approver_order,
                                approver_type,
                                approver_user_role,
                                approver_start_date,
                                approver_end_date,
                                opr_mode,
                                org_id,
                                claim_type_id,
                                reason_code_id,
                                approver_user_role_id,
                                approval_detail_id,
                                status,
                                error_message,
                                request_id,
                                creation_date,
                                created_by,
                                last_update_date,
                                last_updated_by,
                                last_update_login,
                                attribute_num1                   -- CCR0008340
                                              )
                     VALUES (pv_ou_name, pv_old_appr_rule_name, pv_appr_rule_name, UPPER (TRIM (pv_approval_type)), pv_claim_type, pv_reason, pv_start_date, pv_end_date, lv_currency_code, pn_min_amount, pn_max_amount, pv_description, pv_appr_order, UPPER (TRIM (pv_approver_type)), lv_appr_user_role, pv_appr_start_date, pv_appr_end_date, lv_opr_mode, ln_org_id, ln_claim_type_id, ln_reason_code_id, ln_user_role_id, ln_approval_detail_id, lv_upload_status, lv_error_message, gn_request_id, SYSDATE, gn_user_id, SYSDATE, gn_user_id
                             , gn_login_id, ln_setup_id          -- CCR0008340
                                                       );
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || ' Error while inserting into Staging Table: '
                            || SQLERRM,
                            1,
                            2000);
                    RAISE le_webadi_exception;
            END;
        ELSE
            RAISE le_webadi_exception;
        END IF;
    EXCEPTION
        WHEN le_webadi_exception
        THEN
            lv_error_message   := SUBSTR (lv_error_message, 1, 2000);
            fnd_message.set_name ('XXDO', 'XXD_AMS_APPR_UPL_WEBADI_MSG');
            fnd_message.set_token ('ERROR_MESSAGE', lv_error_message);
            lv_error_message   := fnd_message.get ();
            raise_application_error (-20000, lv_error_message);
        WHEN OTHERS
        THEN
            lv_error_message   :=
                SUBSTR (lv_error_message || '.' || SQLERRM, 1, 2000);
            fnd_message.set_name ('XXDO', 'XXD_AMS_APPR_UPL_WEBADI_MSG');
            fnd_message.set_token ('ERROR_MESSAGE', lv_error_message);
            lv_error_message   := fnd_message.get ();
            raise_application_error (-20000, lv_error_message);
    END;

    --API Procedure to create Approval Details
    PROCEDURE create_approval_dtls (p_operating_unit VARCHAR2, p_org_id NUMBER, p_approval_rule_name VARCHAR2, p_approval_type VARCHAR2, p_claim_type VARCHAR2, p_claim_type_id NUMBER, p_reason VARCHAR2, p_reason_code_id NUMBER, p_start_date DATE, p_end_date DATE, p_currency VARCHAR2, p_minimum_amount NUMBER, p_maximum_amount NUMBER, p_description VARCHAR2, p_batch_id NUMBER, px_approval_detail_id OUT NUMBER, px_cr_return_status OUT VARCHAR2, px_cr_error_msg OUT VARCHAR2
                                    , p_setup_type NUMBER         --CCR0008340
                                                         )
    IS
        --Variables Declaration
        l_api_version             CONSTANT NUMBER := 1.0;
        l_object_version_number   CONSTANT NUMBER := 1;
        l_init_msg_list                    VARCHAR2 (200) := fnd_api.g_false;
        l_commit                           VARCHAR2 (200) := fnd_api.g_false;
        l_validation_level                 NUMBER
                                               := fnd_api.g_valid_level_full;
        l_approver_id                      NUMBER := NULL;
        l_approval_dtl_id                  NUMBER := NULL;
        l_organization_id                  NUMBER := p_org_id;
        l_approval_object                  ams_approval_details.approval_object%TYPE
            := 'CLAM';
        l_approval_object_type             ams_approval_details.approval_object_type%TYPE
            := p_claim_type_id;
        l_approval_type                    ams_approval_details.approval_type%TYPE
            := p_approval_type;
        l_approval_priority                ams_approval_details.approval_priority%TYPE
            := p_reason_code_id;
        l_approval_limit_to                NUMBER := p_maximum_amount;
        l_approval_limit_from              NUMBER := p_minimum_amount;
        l_currency_code                    ams_approval_details.currency_code%TYPE
            := p_currency;
        l_name                             ams_approval_details_tl.NAME%TYPE
                                               := p_approval_rule_name;
        l_description                      VARCHAR2 (200) := p_description;
        lv_cr_err_msg                      VARCHAR2 (2000) := NULL;
        p_approval_details_rec             ams_approval_details_pvt.approval_details_rec_type;
        lx_return_status                   VARCHAR2 (200) := NULL;
        lx_msg_count                       NUMBER := 0;
        lx_msg_data                        VARCHAR2 (2000) := NULL;
        lx_approvers_id                    NUMBER := NULL;
        lx_approval_detail_id              NUMBER := NULL;
        ln_batch_id                        NUMBER := NULL;
        l_approval_details_rec             ams_approval_details_pvt.approval_details_rec_type;
    BEGIN
        BEGIN
            SELECT ams_approval_details_s.NEXTVAL
              INTO l_approval_dtl_id
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_approval_dtl_id   := NULL;
                lv_cr_err_msg       :=
                    'SEQ-ams_approval_details_s.NEXTVAL returns NULL ';
                fnd_file.put_line (fnd_file.LOG, lv_cr_err_msg);
        END;

        p_approval_details_rec.approval_detail_id     := l_approval_dtl_id;
        p_approval_details_rec.start_date_active      := p_start_date;
        p_approval_details_rec.end_date_active        := p_end_date;
        p_approval_details_rec.organization_id        := l_organization_id;
        p_approval_details_rec.approval_object        := l_approval_object;
        p_approval_details_rec.approval_object_type   :=
            l_approval_object_type;
        p_approval_details_rec.approval_type          := l_approval_type;
        p_approval_details_rec.approval_priority      := l_approval_priority;
        p_approval_details_rec.approval_limit_to      := l_approval_limit_to;
        p_approval_details_rec.approval_limit_from    :=
            l_approval_limit_from;
        p_approval_details_rec.seeded_flag            := 'N';
        p_approval_details_rec.active_flag            := 'Y';
        p_approval_details_rec.currency_code          := l_currency_code;
        p_approval_details_rec.NAME                   := l_name;
        p_approval_details_rec.description            := l_description;
        p_approval_details_rec.creation_date          := SYSDATE;
        p_approval_details_rec.created_by             := gn_user_id;
        p_approval_details_rec.last_update_date       := SYSDATE;
        p_approval_details_rec.last_updated_by        := gn_user_id;
        p_approval_details_rec.last_update_login      := gn_login_id;
        p_approval_details_rec.custom_setup_id        := p_setup_type; -- CCR0008340
        l_approval_details_rec                        :=
            p_approval_details_rec;

        --Calling API to create Approval Rule details
        ams_approval_details_pvt.create_approval_details (
            p_api_version            => l_api_version,
            p_init_msg_list          => l_init_msg_list,
            p_commit                 => l_commit,
            p_validation_level       => l_validation_level,
            x_return_status          => lx_return_status,
            x_msg_count              => lx_msg_count,
            x_msg_data               => lx_msg_data,
            p_approval_details_rec   => l_approval_details_rec,
            x_approval_detail_id     => lx_approval_detail_id);
        COMMIT;

        IF lx_msg_count > 1
        THEN
            FOR i IN 1 .. lx_msg_count
            LOOP
                lx_msg_data   :=
                       lx_msg_data
                    || SUBSTR (fnd_msg_pub.get (p_encoded => fnd_api.g_false),
                               1,
                               255);
            END LOOP;
        END IF;

        --Update Staging Table with Approval Rule API Status
        IF lx_return_status = 'S'
        THEN
            BEGIN
                UPDATE xxdo.xxd_ams_approval_upload_tbl stg
                   SET approval_detail_id = lx_approval_detail_id, status = 'S'
                 WHERE     1 = 1
                       AND stg.opr_mode = 'NEW'
                       AND stg.org_id = p_org_id
                       AND stg.request_id = gn_request_id
                       AND stg.batch_id = p_batch_id
                       AND stg.approval_rule_name = p_approval_rule_name
                       AND stg.approval_type = p_approval_type
                       AND stg.claim_type_id = p_claim_type_id
                       AND stg.start_date = p_start_date
                       AND stg.currency = p_currency;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_cr_err_msg   :=
                           lv_cr_err_msg
                        || SUBSTR (
                                  ' API Approval Rule Staging update status'
                               || SQLERRM,
                               1,
                               2000);
            END;
        ELSE                                         --lx_return_status <> 'S'
            BEGIN
                UPDATE xxdo.xxd_ams_approval_upload_tbl stg
                   SET status = 'E', error_message = 'NEW: ' || lv_cr_err_msg || SUBSTR (lx_msg_data, 1, 255)
                 WHERE     1 = 1
                       AND stg.opr_mode = 'NEW'
                       AND stg.batch_id = p_batch_id
                       AND stg.request_id = gn_request_id
                       AND stg.org_id = p_org_id
                       AND stg.approval_rule_name = p_approval_rule_name
                       AND stg.approval_type = p_approval_type
                       AND stg.claim_type_id = p_claim_type_id
                       AND stg.start_date = p_start_date
                       AND stg.currency = p_currency;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_cr_err_msg   :=
                           lv_cr_err_msg
                        || SUBSTR (
                                  ' EXP- Staging update API Approval Rule '
                               || SQLERRM,
                               1,
                               2000);
            END;
        END IF;

        px_cr_error_msg                               :=
            lv_cr_err_msg || SUBSTR (lx_msg_data, 1, 255);
        px_cr_return_status                           :=
            SUBSTR (lx_return_status, 1, 255);
        px_approval_detail_id                         :=
            lx_approval_detail_id;
        fnd_file.put_line (
            fnd_file.LOG,
               'NEW: Approval Rule Status> '
            || px_cr_return_status
            || ' Message> '
            || px_cr_error_msg);
    EXCEPTION
        WHEN OTHERS
        THEN
            px_cr_error_msg         :=
                   lv_cr_err_msg
                || 'create_approval_dtls proc failure '
                || SQLERRM;
            px_cr_return_status     := 'E';
            px_approval_detail_id   := NULL;
            fnd_file.put_line (
                fnd_file.LOG,
                   'NEW: Approval Rule Status and Message> '
                || px_cr_return_status
                || ' and '
                || px_cr_error_msg
                || SQLERRM);
    END create_approval_dtls;

    --API Procedure to create Approvers
    PROCEDURE create_approvers (p_org_id                      NUMBER,
                                p_approval_dtl_id             NUMBER,
                                p_approver_order              NUMBER,
                                p_approver_type               VARCHAR2,
                                p_approver_user_role_id       NUMBER,
                                p_approver_start_date         DATE,
                                p_approver_end_date           DATE,
                                p_batch_id                    NUMBER,
                                px_approvers_id           OUT NUMBER,
                                px_return_status          OUT VARCHAR2,
                                px_error_msg              OUT VARCHAR2)
    IS
        --Variables Declaration
        l_api_version             CONSTANT NUMBER := 1.0;
        l_object_version_number   CONSTANT NUMBER := 1;
        l_init_msg_list                    VARCHAR2 (200) := Fnd_Api.g_false;
        l_commit                           VARCHAR2 (200) := Fnd_Api.g_false;
        l_validation_level                 NUMBER
                                               := Fnd_Api.g_valid_level_full;
        l_approver_id                      NUMBER := 0;
        l_approval_dtl_id                  NUMBER := p_approval_dtl_id;
        l_approver_type                    VARCHAR2 (100)
            := NVL (p_approver_type, 'USER');
        lv_err_msg                         VARCHAR2 (2000) := NULL;
        p_approvers_rec                    AMS_APPROVERS_PVT.Approvers_Rec_Type;
        lx_return_status                   VARCHAR2 (200);
        lx_msg_count                       NUMBER := 0;
        lx_msg_data                        VARCHAR2 (2000) := NULL;
        lx_approvers_id                    NUMBER := NULL;

        l_approvers_rec                    AMS_APPROVERS_PVT.Approvers_Rec_Type;
    BEGIN
        BEGIN
            SELECT ams_approvers_s.NEXTVAL INTO l_approver_id FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_approver_id   := NULL;
                lv_err_msg      :=
                    'SEQ-ams_approvers_s.NEXTVAL returns NULL ';
                fnd_file.put_line (fnd_file.LOG, lv_err_msg);
        END;

        p_approvers_rec.approver_id              := l_approver_id;
        p_approvers_rec.seeded_flag              := 'N';
        p_approvers_rec.active_flag              := 'Y';
        p_approvers_rec.start_date_active        := p_approver_start_date;
        p_approvers_rec.end_date_active          := p_approver_end_date;
        p_approvers_rec.object_version_number    := l_object_version_number;
        p_approvers_rec.ams_approval_detail_id   := l_approval_dtl_id;
        p_approvers_rec.approver_seq             := p_approver_order;
        p_approvers_rec.approver_type            := l_approver_type;
        p_approvers_rec.object_approver_id       := p_approver_user_role_id;
        p_approvers_rec.creation_date            := SYSDATE;
        p_approvers_rec.created_by               := gn_user_id;
        p_approvers_rec.last_update_date         := SYSDATE;
        p_approvers_rec.last_updated_by          := gn_user_id;
        p_approvers_rec.last_update_login        := gn_login_id;
        l_approvers_rec                          := p_approvers_rec;

        --Calling API to create Approvers
        AMS_APPROVERS_PVT.Create_approvers (
            p_api_version        => l_api_version,
            p_init_msg_list      => l_init_msg_list,
            p_commit             => l_commit,
            p_validation_level   => l_validation_level,
            x_return_status      => lx_return_status,
            x_msg_count          => lx_msg_count,
            x_msg_data           => lx_msg_data,
            p_approvers_rec      => l_approvers_rec,
            x_approver_id        => lx_approvers_id);
        COMMIT;

        IF lx_msg_count > 1
        THEN
            FOR i IN 1 .. lx_msg_count
            LOOP
                lx_msg_data   :=
                       lx_msg_data
                    || SUBSTR (fnd_msg_pub.get (p_encoded => fnd_api.g_false),
                               1,
                               255);
            END LOOP;
        END IF;

        --Update Staging Table with Approver API Status
        IF lx_return_status = 'S'
        THEN
            BEGIN
                UPDATE xxdo.xxd_ams_approval_upload_tbl stg
                   SET approver_id = lx_approvers_id, status = 'S'
                 WHERE     1 = 1
                       AND stg.opr_mode = 'NEW'
                       AND stg.org_id = p_org_id
                       AND stg.request_id = gn_request_id
                       AND stg.batch_id = p_batch_id
                       AND stg.approval_detail_id = p_approval_dtl_id
                       AND stg.approver_order = p_approver_order;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_err_msg   :=
                           lv_err_msg
                        || SUBSTR (
                                  'EXP- Create Approvers Staging update :'
                               || SQLERRM,
                               1,
                               2000);
            END;
        ELSE                                         --lx_return_status <> 'S'
            BEGIN
                UPDATE xxdo.xxd_ams_approval_upload_tbl stg
                   SET status = 'E', error_message = 'NEW: Approvers - ' || lv_err_msg || SUBSTR (lx_msg_data, 1, 255)
                 WHERE     1 = 1
                       AND stg.opr_mode = 'NEW'
                       AND stg.org_id = p_org_id
                       AND stg.request_id = gn_request_id
                       AND stg.batch_id = p_batch_id
                       AND stg.approval_detail_id = p_approval_dtl_id
                       AND stg.approver_order = p_approver_order;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_err_msg   :=
                           lv_err_msg
                        || SUBSTR ('EXP- NEW: Approvers :' || SQLERRM,
                                   1,
                                   2000);
            END;
        END IF;

        IF lx_return_status = 'S'
        THEN
            px_return_status   := SUBSTR (lx_return_status, 1, 255);
            px_error_msg       := NULL;
            px_approvers_id    := lx_approvers_id;
        ELSE
            px_return_status   := 'E';
            px_error_msg       := lv_err_msg || SUBSTR (lx_msg_data, 1, 255);
            px_approvers_id    := lx_approvers_id;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            px_error_msg       :=
                lv_err_msg || ' EXP-OTHERS NEW: Approvers ' || SQLERRM;
            px_return_status   := 'E';
            px_approvers_id    := NULL;
            fnd_file.put_line (
                fnd_file.LOG,
                   'NEW: Approvers API Status => '
                || px_return_status
                || ' and Message => '
                || px_error_msg
                || '-'
                || SQLERRM);
    END create_approvers;

    --API Procedure to Update Approval Details
    PROCEDURE update_approval_dtls (p_operating_unit VARCHAR2, p_org_id NUMBER, p_approval_detail_id NUMBER, p_old_appr_rule_name VARCHAR2, p_approval_rule_name VARCHAR2, p_start_date DATE, p_end_date DATE, p_currency VARCHAR2, p_claim_type_id NUMBER, p_reason_code_id NUMBER, p_minimum_amount NUMBER, p_maximum_amount NUMBER, p_description VARCHAR2, p_batch_id NUMBER, px_approval_detail_id OUT NUMBER
                                    , px_edit_return_status OUT VARCHAR2, px_edit_error_msg OUT VARCHAR2, p_setup_type NUMBER --CCR0008340
                                                                                                                             )
    IS
        --Variables Declaration
        l_api_version    CONSTANT NUMBER := 1.0;
        l_object_version_number   NUMBER := 0;
        l_old_approval_name       VARCHAR2 (200) := p_old_appr_rule_name;
        l_new_approval_name       VARCHAR2 (200) := p_approval_rule_name;
        l_init_msg_list           VARCHAR2 (200) := fnd_api.g_false;
        l_commit                  VARCHAR2 (200) := fnd_api.g_false;
        l_validation_level        NUMBER := fnd_api.g_valid_level_full;
        l_old_approval_dtl_id     NUMBER := NULL;
        l_appr_rule_start_date    DATE := NULL;
        l_new_appr_rule_exists    NUMBER := 0;
        l_start_date              DATE := p_start_date;
        l_end_date                DATE := p_end_date;
        l_organization_id         NUMBER := p_org_id;
        l_approval_limit_to       NUMBER := p_maximum_amount;
        l_approval_limit_from     NUMBER := p_minimum_amount;
        l_currency_code           ams_approval_details.currency_code%TYPE
                                      := p_currency;
        l_description             VARCHAR2 (500) := p_description;
        l_approval_priority       ams_approval_details.approval_type%TYPE
                                      := TO_CHAR (p_reason_code_id);
        l_approval_object_type    ams_approval_details.approval_object_type%TYPE
            := TO_CHAR (p_claim_type_id);
        l_old_currency_code       ams_approval_details.currency_code%TYPE
                                      := NULL;
        l_old_approval_object     ams_approval_details.approval_object%TYPE
                                      := 'CLAM';
        l_old_approval_type       ams_approval_details.approval_type%TYPE
                                      := NULL;
        l_old_appr_object_type    ams_approval_details.approval_object_type%TYPE
            := NULL;
        l_old_approval_priority   ams_approval_details.approval_type%TYPE
                                      := NULL;
        l_appr_rule_end_date      DATE := NULL;
        l_old_appr_limit_to       NUMBER := NULL;
        l_old_appr_limit_from     NUMBER := NULL;
        l_old_description         VARCHAR2 (500) := NULL;
        lv_edit_error_msg         VARCHAR2 (2000) := NULL;
        p_approval_details_rec    ams_approval_details_pvt.approval_details_rec_type;
        lx_return_status          VARCHAR2 (200) := NULL;
        lx_msg_count              NUMBER := 0;
        lx_msg_data               VARCHAR2 (2000) := NULL;
        lx_approvers_id           NUMBER := NULL;
        lx_approval_detail_id     NUMBER := NULL;
        ln_batch_id               NUMBER := NULL;
        l_old_setup_id            NUMBER;                         --CCR0008340
        l_new_setup_id            NUMBER := p_setup_type;       ----CCR0008340
        l_approval_details_rec    ams_approval_details_pvt.approval_details_rec_type;
    BEGIN
        BEGIN
            SELECT approval_detail_id, object_version_number, start_date_active,
                   currency_code, approval_object, approval_type,
                   approval_object_type, approval_priority, end_date_active,
                   approval_limit_to, approval_limit_from, description,
                   custom_setup_id                                --CCR0008340
              INTO l_old_approval_dtl_id, l_object_version_number, l_appr_rule_start_date, l_old_currency_code,
                                        l_old_approval_object, l_old_approval_type, l_old_appr_object_type,
                                        l_old_approval_priority, l_appr_rule_end_date, l_old_appr_limit_to,
                                        l_old_appr_limit_from, l_old_description, l_old_setup_id --CCR0008340
              FROM ams_approval_details_vl stg
             WHERE     1 = 1
                   AND NAME = TRIM (l_old_approval_name)
                   AND organization_id = l_organization_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_old_approval_dtl_id     := NULL;
                l_object_version_number   := NULL;
                l_appr_rule_start_date    := NULL;
                l_old_approval_object     := NULL;
                l_old_approval_type       := NULL;
                l_old_appr_object_type    := NULL;
                l_old_approval_priority   := NULL;
                l_appr_rule_end_date      := NULL;
                l_old_appr_limit_to       := NULL;
                l_old_appr_limit_from     := NULL;
                l_old_description         := NULL;
                lv_edit_error_msg         :=
                       'EDIT: Approval Rule - OLD Approval Rule Name is Invalid :'
                    || l_old_approval_name;
                fnd_file.put_line (
                    fnd_file.LOG,
                       ' EDIT: Approval Rule - OLD Approval Rule Name is Invalid :'
                    || l_old_approval_name);
        END;

        --Verify New provided Approval Rule name exists or not
        BEGIN
            SELECT COUNT (1)
              INTO l_new_appr_rule_exists
              FROM ams_approval_details_vl
             WHERE     1 = 1
                   AND NAME = TRIM (l_new_approval_name)
                   AND organization_id = l_organization_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_new_appr_rule_exists   := -1;
                lv_edit_error_msg        :=
                       'EDIT: New Approval Rule Name already Exists =>'
                    || l_new_appr_rule_exists;
                fnd_file.put_line (fnd_file.LOG, lv_edit_error_msg);
        END;

        fnd_file.put_line (
            fnd_file.LOG,
               'EDIT: OLD Approval Rule Name-  object_version_no=>'
            || l_old_approval_name
            || ' - '
            || l_object_version_number);

        IF l_old_approval_dtl_id IS NOT NULL
        THEN
            p_approval_details_rec.approval_detail_id   :=
                l_old_approval_dtl_id;
            p_approval_details_rec.object_version_number   :=
                l_object_version_number;

            IF ((l_new_approval_name IS NOT NULL) AND (NVL (l_new_appr_rule_exists, 0) = 0))
            THEN
                p_approval_details_rec.name   := l_new_approval_name;
            END IF;

            IF l_approval_object_type IS NOT NULL
            THEN
                p_approval_details_rec.approval_object_type   :=
                    l_approval_object_type;
            ELSIF     l_approval_object_type IS NULL
                  AND l_old_appr_object_type IS NOT NULL
            THEN
                p_approval_details_rec.approval_object_type   :=
                    l_old_appr_object_type;
            END IF;

            IF l_approval_priority IS NOT NULL
            THEN
                p_approval_details_rec.approval_priority   :=
                    l_approval_priority;
            ELSIF     l_approval_priority IS NULL
                  AND l_old_approval_priority IS NOT NULL
            THEN
                p_approval_details_rec.approval_priority   :=
                    l_old_approval_priority;
            END IF;

            IF l_description IS NOT NULL
            THEN
                p_approval_details_rec.description   := l_description;
            ELSIF l_description IS NULL AND l_old_description IS NOT NULL
            THEN
                p_approval_details_rec.description   := l_old_description;
            END IF;

            IF l_start_date IS NOT NULL
            THEN
                IF l_appr_rule_start_date IS NULL
                THEN
                    p_approval_details_rec.start_date_active   :=
                        l_start_date;
                ELSIF ((l_start_date > l_appr_rule_start_date) AND (l_start_date >= TRUNC (SYSDATE)))
                THEN
                    p_approval_details_rec.start_date_active   :=
                        l_start_date;
                ELSE
                    p_approval_details_rec.start_date_active   :=
                        l_appr_rule_start_date;
                END IF;
            ELSE
                p_approval_details_rec.start_date_active   :=
                    l_appr_rule_start_date;
            END IF;

            IF l_end_date IS NOT NULL
            THEN
                p_approval_details_rec.end_date_active   := l_end_date;
            ELSIF l_end_date IS NULL AND l_appr_rule_end_date IS NOT NULL
            THEN
                p_approval_details_rec.end_date_active   :=
                    l_appr_rule_end_date;
            END IF;

            IF l_approval_limit_to IS NOT NULL
            THEN
                p_approval_details_rec.approval_limit_to   :=
                    l_approval_limit_to;
            ELSIF     l_approval_limit_to IS NULL
                  AND l_old_appr_limit_to IS NOT NULL
            THEN
                p_approval_details_rec.approval_limit_to   :=
                    l_old_appr_limit_to;
            END IF;

            IF l_approval_limit_from IS NOT NULL
            THEN
                p_approval_details_rec.approval_limit_from   :=
                    l_approval_limit_from;
            ELSIF     l_approval_limit_from IS NULL
                  AND l_old_appr_limit_from IS NOT NULL
            THEN
                p_approval_details_rec.approval_limit_from   :=
                    l_old_appr_limit_from;
            END IF;

            IF l_currency_code IS NOT NULL
            THEN
                p_approval_details_rec.currency_code   := l_currency_code;
            ELSIF l_currency_code IS NULL AND l_old_currency_code IS NOT NULL
            THEN
                p_approval_details_rec.currency_code   := l_old_currency_code;
            END IF;

            --CCR0008340 changes start
            IF l_new_setup_id IS NOT NULL
            THEN
                p_approval_details_rec.custom_setup_id   := l_new_setup_id;
            ELSIF l_new_setup_id IS NULL AND l_old_setup_id IS NOT NULL
            THEN
                p_approval_details_rec.custom_setup_id   := l_old_setup_id;
            END IF;

            --CCR0008340 changes end
            p_approval_details_rec.organization_id     := l_organization_id;
            p_approval_details_rec.seeded_flag         := 'N';
            p_approval_details_rec.active_flag         := 'Y';
            p_approval_details_rec.creation_date       := SYSDATE;
            p_approval_details_rec.created_by          := gn_user_id;
            p_approval_details_rec.last_update_date    := SYSDATE;
            p_approval_details_rec.last_updated_by     := gn_user_id;
            p_approval_details_rec.last_update_login   := gn_login_id;
            l_approval_details_rec                     :=
                p_approval_details_rec;

            --Calling API to Update Approval Rule details
            ams_approval_details_pvt.update_approval_details (
                p_api_version            => l_api_version,
                p_init_msg_list          => l_init_msg_list,
                p_commit                 => l_commit,
                p_validation_level       => l_validation_level,
                x_return_status          => lx_return_status,
                x_msg_count              => lx_msg_count,
                x_msg_data               => lx_msg_data,
                p_approval_details_rec   => l_approval_details_rec);
            COMMIT;

            IF lx_msg_count > 1
            THEN
                FOR i IN 1 .. lx_msg_count
                LOOP
                    lx_msg_data   :=
                           lx_msg_data
                        || SUBSTR (
                               fnd_msg_pub.get (p_encoded => fnd_api.g_false),
                               1,
                               255);
                END LOOP;
            END IF;

            --Update Staging Table with Approval Rule API Status
            IF lx_return_status = 'S'
            THEN
                BEGIN
                    UPDATE xxdo.xxd_ams_approval_upload_tbl stg
                       SET approval_detail_id = l_old_approval_dtl_id, status = 'S'
                     WHERE     1 = 1
                           AND stg.opr_mode = 'EDIT'
                           AND stg.org_id = p_org_id
                           AND stg.request_id = gn_request_id
                           AND stg.batch_id = p_batch_id
                           AND stg.old_appr_rule_name = p_old_appr_rule_name;

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_edit_error_msg   :=
                               lv_edit_error_msg
                            || SUBSTR (
                                      'EXP- EDIT: Update Approver Rules API proc Status '
                                   || SQLERRM,
                                   1,
                                   2000);
                END;
            ELSE                                     --lx_return_status <> 'S'
                BEGIN
                    UPDATE xxdo.xxd_ams_approval_upload_tbl stg
                       SET status = 'E', error_message = lv_edit_error_msg || SUBSTR (lx_msg_data, 1, 255)
                     WHERE     1 = 1
                           AND stg.opr_mode = 'EDIT'
                           AND stg.batch_id = p_batch_id
                           AND stg.request_id = gn_request_id
                           AND stg.org_id = p_org_id
                           AND stg.approval_rule_name = p_approval_rule_name
                           AND stg.old_appr_rule_name = p_old_appr_rule_name
                           AND stg.description = p_description
                           AND stg.start_date = p_start_date
                           AND stg.start_date = p_end_date;

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_edit_error_msg   :=
                               lv_edit_error_msg
                            || SUBSTR (
                                      ' EXP- EDIT: Update Approver Rules API proc Status-E'
                                   || SQLERRM,
                                   1,
                                   2000);
                END;
            END IF;

            px_edit_error_msg                          :=
                lv_edit_error_msg || SUBSTR (lx_msg_data, 1, 255);
            px_edit_return_status                      :=
                SUBSTR (lx_return_status, 1, 255);
            px_approval_detail_id                      :=
                l_old_approval_dtl_id;
        ELSE                                  -- l_old_approval_dtl_id IS NULL
            px_edit_error_msg       :=
                   lv_edit_error_msg
                || 'EDIT: Old Approval Rule Name is Invalid';
            px_edit_return_status   := 'E';
            px_approval_detail_id   := l_old_approval_dtl_id;
        END IF;                    -- End of l_old_approval_dtl_id IS NOT NULL
    EXCEPTION
        WHEN OTHERS
        THEN
            px_edit_error_msg       :=
                   lv_edit_error_msg
                || ' EXP -update_approval_dtls proc -OTHERS '
                || SQLERRM;
            px_edit_return_status   := 'E';
            px_approval_detail_id   := NULL;
    END update_approval_dtls;

    --API Procedure to Update Approvers
    PROCEDURE update_approvers (p_org_id                    NUMBER,
                                p_approval_dtl_id           NUMBER,
                                p_approver_id               NUMBER,
                                p_approver_order            NUMBER,
                                p_user_role_id              NUMBER,
                                p_approver_start_date       DATE,
                                p_approver_end_date         DATE,
                                p_batch_id                  NUMBER,
                                px_approvers_id         OUT NUMBER,
                                px_return_status        OUT VARCHAR2,
                                px_error_msg            OUT VARCHAR2)
    IS
        --Variables Declaration
        l_api_version    CONSTANT NUMBER := 1.0;
        l_object_version_number   NUMBER := 0;
        l_init_msg_list           VARCHAR2 (200) := Fnd_Api.g_false;
        l_commit                  VARCHAR2 (200) := Fnd_Api.g_false;
        l_validation_level        NUMBER := Fnd_Api.g_valid_level_full;
        l_approver_id             NUMBER := p_approver_id;
        l_approval_dtl_id         NUMBER := p_approval_dtl_id;
        l_base_appr_start_date    DATE := NULL;
        l_base_appr_end_date      DATE := NULL;
        l_base_user_role_id       NUMBER := NULL;
        --l_approver_type             VARCHAR2(100)    := NVL(p_approver_type, 'USER');
        lv_err_msg                VARCHAR2 (2000) := NULL;
        p_approvers_rec           AMS_APPROVERS_PVT.Approvers_Rec_Type;
        lx_return_status          VARCHAR2 (200);
        lx_msg_count              NUMBER := 0;
        lx_msg_data               VARCHAR2 (2000) := NULL;
        lx_approvers_id           NUMBER := NULL;

        l_approvers_rec           AMS_APPROVERS_PVT.Approvers_Rec_Type;
    BEGIN
        BEGIN
            SELECT object_version_number, start_date_active, end_date_active,
                   object_approver_id
              INTO l_object_version_number, l_base_appr_start_date, l_base_appr_end_date, l_base_user_role_id
              FROM ams_approvers
             WHERE     ams_approval_detail_id = l_approval_dtl_id
                   AND approver_id = l_approver_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_object_version_number   := 0;
                l_base_appr_start_date    := NULL;
                l_base_appr_end_date      := NULL;
                l_base_user_role_id       := NULL;
                lv_err_msg                :=
                       'EXP- EDIT: Approvers- Object Version Number Validaton Failed =>'
                    || l_object_version_number;
                fnd_file.put_line (fnd_file.LOG, lv_err_msg);
        END;

        IF p_approver_start_date IS NOT NULL
        THEN
            IF p_approver_start_date >=
               NVL (l_base_appr_start_date, TRUNC (SYSDATE))
            THEN
                p_approvers_rec.start_date_active   := p_approver_start_date;
            ELSE
                p_approvers_rec.start_date_active   := l_base_appr_start_date;
            END IF;
        ELSIF     p_approver_start_date IS NULL
              AND l_base_appr_start_date IS NOT NULL
        THEN
            p_approvers_rec.start_date_active   := l_base_appr_start_date;
        END IF;

        IF p_approver_end_date IS NOT NULL
        THEN
            IF p_approver_end_date >=
               (NVL (p_approver_start_date, NVL (l_base_appr_start_date, TRUNC (SYSDATE))))
            THEN
                p_approvers_rec.end_date_active   := p_approver_end_date;
            ELSE
                p_approvers_rec.end_date_active   := l_base_appr_end_date;
            END IF;
        ELSIF     p_approver_end_date IS NULL
              AND l_base_appr_end_date IS NOT NULL
        THEN
            p_approvers_rec.end_date_active   := l_base_appr_end_date;
        END IF;

        IF p_user_role_id IS NOT NULL
        THEN
            p_approvers_rec.object_approver_id   := p_user_role_id;
        ELSIF p_user_role_id IS NULL AND l_base_user_role_id IS NOT NULL
        THEN
            p_approvers_rec.object_approver_id   := l_base_user_role_id;
        END IF;

        p_approvers_rec.approver_id              := l_approver_id;
        p_approvers_rec.seeded_flag              := 'N';
        p_approvers_rec.active_flag              := 'Y';
        p_approvers_rec.object_version_number    := l_object_version_number;
        p_approvers_rec.ams_approval_detail_id   := l_approval_dtl_id;
        p_approvers_rec.approver_seq             := p_approver_order;
        p_approvers_rec.creation_date            := SYSDATE;
        p_approvers_rec.created_by               := gn_user_id;
        p_approvers_rec.last_update_date         := SYSDATE;
        p_approvers_rec.last_updated_by          := gn_user_id;
        p_approvers_rec.last_update_login        := gn_login_id;
        l_approvers_rec                          := p_approvers_rec;

        --Calling API to Update Approvers
        AMS_APPROVERS_PVT.Update_approvers (
            p_api_version        => l_api_version,
            p_init_msg_list      => l_init_msg_list,
            p_commit             => l_commit,
            p_validation_level   => l_validation_level,
            x_return_status      => lx_return_status,
            x_msg_count          => lx_msg_count,
            x_msg_data           => lx_msg_data,
            p_approvers_rec      => l_approvers_rec);
        COMMIT;

        IF lx_msg_count > 1
        THEN
            FOR i IN 1 .. lx_msg_count
            LOOP
                lx_msg_data   :=
                       lx_msg_data
                    || SUBSTR (fnd_msg_pub.get (p_encoded => fnd_api.g_false),
                               1,
                               255);
            END LOOP;
        END IF;

        --Update Staging Table with Approver API Status
        IF lx_return_status = 'S'
        THEN
            BEGIN
                UPDATE xxdo.xxd_ams_approval_upload_tbl stg
                   SET approver_id = l_approver_id, status = 'S'
                 WHERE     1 = 1
                       AND stg.opr_mode = 'EDIT'
                       AND stg.org_id = p_org_id
                       AND stg.request_id = gn_request_id
                       AND stg.batch_id = p_batch_id
                       AND stg.approval_detail_id = p_approval_dtl_id
                       AND stg.approver_order = p_approver_order;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_err_msg   :=
                           lv_err_msg
                        || SUBSTR (
                                  'EXP- EDIT: Update Approvers API proc Status'
                               || SQLERRM,
                               1,
                               2000);
            END;
        ELSE                                         --lx_return_status <> 'S'
            BEGIN
                UPDATE xxdo.xxd_ams_approval_upload_tbl stg
                   SET status = 'E', error_message = lv_err_msg || SUBSTR (lx_msg_data, 1, 255)
                 WHERE     1 = 1
                       AND stg.opr_mode = 'EDIT'
                       AND stg.org_id = p_org_id
                       AND stg.request_id = gn_request_id
                       AND stg.batch_id = p_batch_id
                       AND stg.approval_detail_id = p_approval_dtl_id
                       AND stg.approver_order = p_approver_order;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_err_msg   :=
                           lv_err_msg
                        || SUBSTR (
                                  'EXP- EDIT: Update Approvers API proc Status-E'
                               || SQLERRM,
                               1,
                               2000);
            END;
        END IF;

        IF lx_return_status = 'S'
        THEN
            px_return_status   := SUBSTR (lx_return_status, 1, 255);
            px_error_msg       := NULL;
            px_approvers_id    := l_approver_id;
        ELSE
            px_return_status   := 'E';
            px_error_msg       := lv_err_msg || SUBSTR (lx_msg_data, 1, 255);
            px_approvers_id    := NULL;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            px_error_msg       :=
                lv_err_msg || 'EXP-OTHERS EDIT: Approvers ' || SQLERRM;
            px_return_status   := 'E';
            px_approvers_id    := NULL;
            fnd_file.put_line (
                fnd_file.LOG,
                   'EDIT: Approvers API Status => '
                || px_return_status
                || ' Message and Approvers ID => '
                || px_error_msg
                || '-'
                || SQLERRM
                || ' and '
                || px_approvers_id);
    END update_approvers;


    --Generate and Update Batch ID
    PROCEDURE update_stg_batch_id (p_mode                 IN     VARCHAR2,
                                   p_org_id               IN     NUMBER,
                                   p_approval_rule_name   IN     VARCHAR2,
                                   p_approval_type        IN     VARCHAR2,
                                   p_claim_type_id        IN     NUMBER,
                                   p_start_date           IN     DATE,
                                   p_currency             IN     VARCHAR2,
                                   px_batch_id               OUT NUMBER)
    IS
        ln_batch_id   NUMBER := NULL;
    BEGIN
        BEGIN
            ln_batch_id   := xxdo.xxd_ams_appr_upl_tbl_seq_no.NEXTVAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_batch_id   := -99;
        END;

        UPDATE xxdo.xxd_ams_approval_upload_tbl stg
           SET batch_id   = ln_batch_id
         WHERE     stg.status = 'N'
               AND stg.opr_mode = p_mode
               AND stg.request_id = gn_request_id
               AND stg.org_id = p_org_id
               AND stg.approval_rule_name = p_approval_rule_name
               AND stg.approval_type = p_approval_type
               AND stg.claim_type_id = p_claim_type_id
               AND stg.start_date = p_start_date
               AND stg.currency = p_currency;

        COMMIT;
        px_batch_id   := ln_batch_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            ln_batch_id   := -99;

            UPDATE xxdo.xxd_ams_approval_upload_tbl stg
               SET batch_id   = ln_batch_id
             WHERE     stg.status = 'N'
                   AND stg.opr_mode = p_mode
                   AND stg.request_id = gn_request_id
                   AND stg.org_id = p_org_id
                   AND stg.approval_rule_name = p_approval_rule_name
                   AND stg.approval_type = p_approval_type
                   AND stg.claim_type_id = p_claim_type_id
                   AND stg.start_date = p_start_date
                   AND stg.currency = p_currency;

            COMMIT;
            px_batch_id   := ln_batch_id;
    END update_stg_batch_id;

    --Generate and Update Batch ID -EDIT
    PROCEDURE edit_stg_batch_id (p_mode                 IN     VARCHAR2,
                                 p_org_id               IN     NUMBER,
                                 p_old_appr_rule_name   IN     VARCHAR2,
                                 p_approval_rule_name   IN     VARCHAR2,
                                 p_description          IN     VARCHAR2,
                                 p_start_date           IN     DATE,
                                 p_end_date             IN     DATE,
                                 px_batch_id               OUT NUMBER)
    IS
        ln_batch_id   NUMBER := NULL;
    BEGIN
        BEGIN
            ln_batch_id   := xxdo.xxd_ams_appr_upl_tbl_seq_no.NEXTVAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_batch_id   := -99;
        END;

        UPDATE xxdo.xxd_ams_approval_upload_tbl stg
           SET batch_id   = ln_batch_id
         WHERE     stg.status = 'N'
               AND stg.opr_mode = p_mode
               AND stg.request_id = gn_request_id
               AND stg.org_id = p_org_id
               AND stg.old_appr_rule_name = p_old_appr_rule_name;

        COMMIT;
        px_batch_id   := ln_batch_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            ln_batch_id   := -99;

            UPDATE xxdo.xxd_ams_approval_upload_tbl stg
               SET batch_id   = ln_batch_id
             WHERE     stg.status = 'N'
                   AND stg.opr_mode = p_mode
                   AND stg.request_id = gn_request_id
                   AND stg.org_id = p_org_id
                   AND stg.old_appr_rule_name = p_old_appr_rule_name;

            COMMIT;
            px_batch_id   := ln_batch_id;
    END edit_stg_batch_id;

    PROCEDURE import_proc (pv_errbuf OUT VARCHAR2, pv_retcode OUT NUMBER)
    IS
        CURSOR c_approval_dtls IS
              SELECT stg.operating_unit, stg.opr_mode, stg.batch_id,
                     stg.org_id, stg.approval_rule_name, stg.approval_type,
                     stg.claim_type, stg.claim_type_id, stg.reason,
                     stg.reason_code_id, stg.start_date, stg.end_date end_date,
                     stg.currency, stg.minimum_amount minimum_amount, stg.maximum_amount maximum_amount,
                     stg.description description, stg.attribute_num1 -- CCR0008340
                FROM xxdo.xxd_ams_approval_upload_tbl stg
               WHERE     1 = 1
                     AND NVL (stg.status, 'N') = 'N'
                     AND stg.opr_mode = 'NEW'
                     AND stg.request_id = gn_request_id
            GROUP BY stg.operating_unit, stg.opr_mode, stg.batch_id,
                     stg.org_id, stg.approval_rule_name, stg.approval_type,
                     stg.claim_type, stg.claim_type_id, stg.reason,
                     stg.reason_code_id, stg.start_date, stg.end_date,
                     stg.currency, stg.minimum_amount, stg.maximum_amount,
                     stg.description, stg.attribute_num1;        -- CCR0008340

        CURSOR c_approvers (p_batch_id IN NUMBER, p_org_id IN NUMBER, p_approval_rule_name IN VARCHAR2, p_approval_type IN VARCHAR2, p_claim_type_id IN NUMBER, p_start_date IN DATE
                            , p_currency IN VARCHAR2)
        IS
              SELECT org_id, approval_detail_id, batch_id,
                     approver_order, approver_type, approver_user_role_id,
                     approver_start_date, approver_end_date
                FROM xxdo.xxd_ams_approval_upload_tbl stg
               WHERE     1 = 1
                     AND stg.opr_mode = 'NEW'
                     AND stg.request_id = gn_request_id
                     AND stg.batch_id = p_batch_id
                     AND stg.org_id = p_org_id
                     AND stg.approval_rule_name = p_approval_rule_name
                     AND stg.approval_type = p_approval_type
                     AND stg.claim_type_id = p_claim_type_id
                     AND stg.start_date = p_start_date
                     AND stg.currency = p_currency
            ORDER BY org_id, approval_detail_id, batch_id,
                     approver_order;

        --Pick Approval details for EDIT
        CURSOR c_approval_dtls_upd IS
              SELECT stg.operating_unit, stg.opr_mode, stg.batch_id,
                     stg.approval_detail_id, stg.org_id, stg.old_appr_rule_name,
                     stg.approval_rule_name, stg.start_date, stg.end_date,
                     stg.currency, stg.claim_type_id, stg.reason_code_id,
                     stg.minimum_amount minimum_amount, stg.maximum_amount maximum_amount, stg.description description,
                     stg.attribute_num1                          -- CCR0008340
                FROM xxdo.xxd_ams_approval_upload_tbl stg
               WHERE     1 = 1
                     AND NVL (stg.status, 'N') = 'N'
                     AND stg.opr_mode = 'EDIT'
                     AND stg.request_id = gn_request_id
            GROUP BY stg.operating_unit, stg.opr_mode, stg.batch_id,
                     stg.approval_detail_id, stg.org_id, stg.old_appr_rule_name,
                     stg.approval_rule_name, stg.start_date, stg.end_date,
                     stg.currency, stg.claim_type_id, stg.reason_code_id,
                     stg.minimum_amount, stg.maximum_amount, stg.description,
                     stg.attribute_num1;                         -- CCR0008340

        --Pick Approvers for EDIT
        CURSOR c_approvers_upd (p_batch_id IN NUMBER, p_org_id IN NUMBER, p_approval_detail_id IN NUMBER
                                , p_approval_rule_name IN VARCHAR2, p_start_date IN DATE, p_end_date IN DATE)
        IS
              SELECT stg.org_id, stg.approval_detail_id, appr.approver_id,
                     stg.batch_id, stg.opr_mode, stg.approver_order,
                     stg.approver_type, stg.approver_user_role_id, stg.approver_start_date,
                     stg.approver_end_date
                FROM xxdo.xxd_ams_approval_upload_tbl stg, ams_approvers appr
               WHERE     1 = 1
                     AND stg.approval_detail_id =
                         appr.ams_approval_detail_id(+)
                     AND stg.approver_order = appr.approver_seq(+)
                     AND stg.opr_mode = 'EDIT'
                     AND stg.batch_id = p_batch_id
                     AND stg.request_id = gn_request_id
                     AND stg.org_id = p_org_id
                     AND stg.approval_detail_id = p_approval_detail_id
            ORDER BY stg.org_id, stg.request_id, stg.batch_id,
                     stg.approval_detail_id, stg.approver_order;

        --Local Variables Declaration
        lx_appr_rule_det_cr_sts     VARCHAR2 (1) := NULL;
        lx_appr_rule_det_cr_msg     VARCHAR2 (2000) := NULL;
        lx_appr_rule_det_edit_sts   VARCHAR2 (2000) := NULL;
        lx_appr_rule_det_edit_msg   VARCHAR2 (2000) := NULL;
        ln_new_rec_cnt              NUMBER := 0;
        ln_edit_rec_cnt             NUMBER := 0;
        ln_user_role_exists         NUMBER := 0;
        ln_max_appr_seqno           NUMBER := 0;
        ln_chk_object_approver_id   NUMBER := 0;
        lx_cr_approval_dtl_id       NUMBER := 0;
        lx_approvers_id             NUMBER := 0;
        lx_batch_id                 NUMBER := 0;
        lx_approvers_cr_sts         VARCHAR2 (1) := NULL;
        lx_approvers_cr_msg         VARCHAR2 (2000) := NULL;
        lx_approvers_edit_sts       VARCHAR2 (1) := NULL;
        lx_approvers_edit_msg       VARCHAR2 (2000) := NULL;
        lx_edit_approval_dtl_id     NUMBER := 0;
        lx_edit_approvers_id        NUMBER := 0;
        ln_object_ver_no            NUMBER := 0;
        lv_error_message            VARCHAR2 (2000);
        lv_return_status            VARCHAR2 (1) := NULL;
        lv_proc_error_msg           VARCHAR2 (2000);
        le_proc_error_exception     EXCEPTION;
    BEGIN
        --Initialization
        mo_global.init ('AMS');

        --Updating staging table with request_id
        BEGIN
            UPDATE xxdo.xxd_ams_approval_upload_tbl
               SET request_id   = gn_request_id
             WHERE     status = 'N'
                   AND created_by = gn_user_id
                   AND TRUNC (creation_date) = TRUNC (SYSDATE)
                   AND request_id = -1;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_return_status   := gv_ret_error;
                lv_error_message   :=
                    SUBSTR (
                           'Error while updation of Staging with request id. Error is: '
                        || SQLERRM,
                        1,
                        2000);
                fnd_file.put_line (fnd_file.LOG, lv_error_message);
                pv_retcode         := gn_error;                           --2;
                pv_errbuf          := lv_error_message;
                RAISE;
        END;

        BEGIN
            SELECT COUNT (*)
              INTO ln_new_rec_cnt
              FROM xxdo.xxd_ams_approval_upload_tbl stg
             WHERE     1 = 1
                   AND NVL (stg.status, 'N') = 'N'
                   AND stg.request_id = gn_request_id
                   AND stg.opr_mode = 'NEW';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_new_rec_cnt   := 0;
        END;

        BEGIN
            SELECT COUNT (*)
              INTO ln_edit_rec_cnt
              FROM xxdo.xxd_ams_approval_upload_tbl stg
             WHERE     1 = 1
                   AND NVL (stg.status, 'N') = 'N'
                   AND stg.request_id = gn_request_id
                   AND stg.opr_mode = 'EDIT';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_edit_rec_cnt   := 0;
        END;

        fnd_file.put_line (fnd_file.LOG,
                           'NEW Records Count => ' || ln_new_rec_cnt);
        fnd_file.put_line (fnd_file.LOG,
                           'EDIT Records Count => ' || ln_edit_rec_cnt);

        IF ln_new_rec_cnt = 0 AND ln_edit_rec_cnt = 0
        THEN
            lv_proc_error_msg   := 'No NEW\EDIT records to process ';
            RAISE le_proc_error_exception;
        END IF;

        IF ln_new_rec_cnt > 0
        THEN
            FOR r_approval_dtls IN c_approval_dtls
            LOOP
                --Calling Procedure to update Batch ID
                BEGIN
                    update_stg_batch_id (
                        p_mode            => r_approval_dtls.opr_mode,
                        p_org_id          => r_approval_dtls.org_id,
                        p_approval_rule_name   =>
                            r_approval_dtls.approval_rule_name,
                        p_approval_type   => r_approval_dtls.approval_type,
                        p_claim_type_id   => r_approval_dtls.claim_type_id,
                        p_start_date      => r_approval_dtls.start_date,
                        p_currency        => r_approval_dtls.currency,
                        px_batch_id       => lx_batch_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lx_batch_id   := -99;
                END;

                IF ((lx_batch_id = -99) OR (lx_batch_id <= 0))
                THEN
                    lv_proc_error_msg   :=
                           lv_proc_error_msg
                        || ' NEW: Batch Sequence failure, BatchID => '
                        || lx_batch_id;
                END IF;

                fnd_file.put_line (
                    fnd_file.LOG,
                       'NEW- Org ID => '
                    || r_approval_dtls.org_id
                    || ' and Batch Id => '
                    || lx_batch_id);

                IF lx_batch_id > 0
                THEN
                    BEGIN
                        --Calling Create Approval Rule Details API procedure
                        create_approval_dtls (
                            p_operating_unit        =>
                                r_approval_dtls.operating_unit,
                            p_org_id                => r_approval_dtls.org_id,
                            p_approval_rule_name    =>
                                r_approval_dtls.approval_rule_name,
                            p_approval_type         => r_approval_dtls.approval_type,
                            p_claim_type            => r_approval_dtls.claim_type,
                            p_claim_type_id         => r_approval_dtls.claim_type_id,
                            p_reason                => r_approval_dtls.reason,
                            p_reason_code_id        =>
                                r_approval_dtls.reason_code_id,
                            p_start_date            => r_approval_dtls.start_date,
                            p_end_date              => r_approval_dtls.end_date,
                            p_currency              => r_approval_dtls.currency,
                            p_minimum_amount        =>
                                r_approval_dtls.minimum_amount,
                            p_maximum_amount        =>
                                r_approval_dtls.maximum_amount,
                            p_description           => r_approval_dtls.description,
                            p_batch_id              =>
                                NVL (r_approval_dtls.batch_id, lx_batch_id),
                            px_approval_detail_id   => lx_cr_approval_dtl_id,
                            px_cr_return_status     => lx_appr_rule_det_cr_sts,
                            px_cr_error_msg         => lx_appr_rule_det_cr_msg,
                            p_setup_type            =>
                                r_approval_dtls.attribute_num1   -- CCR0008340
                                                              );
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'NEW-Approval Details API Proc Failure ');
                            lx_appr_rule_det_cr_sts   := 'E';
                            lx_appr_rule_det_cr_msg   :=
                                   lx_appr_rule_det_cr_msg
                                || 'EXP: NEW- Approval Details API Proc Failure- '
                                || SQLERRM;
                    END;
                END IF;

                fnd_file.put_line (
                    fnd_file.LOG,
                       'NEW-Approval Rule Details API Status => '
                    || lx_appr_rule_det_cr_sts
                    || ' and Message => '
                    || lx_appr_rule_det_cr_msg);

                --Create Approval rule details is success then loop to create approvers
                IF lx_appr_rule_det_cr_sts = 'S'
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'NEW- Org ID => '
                        || r_approval_dtls.org_id
                        || ' and Approval Rule Name => '
                        || r_approval_dtls.approval_rule_name);

                    FOR r_approvers
                        IN c_approvers (
                               p_batch_id     => lx_batch_id,
                               p_org_id       => r_approval_dtls.org_id,
                               p_approval_rule_name   =>
                                   r_approval_dtls.approval_rule_name,
                               p_approval_type   =>
                                   r_approval_dtls.approval_type,
                               p_claim_type_id   =>
                                   r_approval_dtls.claim_type_id,
                               p_start_date   => r_approval_dtls.start_date,
                               p_currency     => r_approval_dtls.currency)
                    LOOP
                        IF ((r_approvers.approval_detail_id IS NOT NULL) AND (r_approvers.approver_order IS NOT NULL) AND (r_approvers.approver_type IS NOT NULL))
                        THEN
                            --Calling Create Approvers API Procedure
                            create_approvers (
                                p_org_id              => r_approvers.org_id,
                                p_approval_dtl_id     =>
                                    r_approvers.approval_detail_id,
                                p_approver_order      =>
                                    r_approvers.approver_order,
                                p_approver_type       => r_approvers.approver_type,
                                p_approver_user_role_id   =>
                                    r_approvers.approver_user_role_id,
                                p_approver_start_date   =>
                                    r_approvers.approver_start_date,
                                p_approver_end_date   =>
                                    r_approvers.approver_end_date,
                                p_batch_id            => r_approvers.batch_id,
                                px_approvers_id       => lx_approvers_id,
                                px_return_status      => lx_approvers_cr_sts,
                                px_error_msg          => lx_approvers_cr_msg);
                        ELSE
                            lx_approvers_cr_sts   := lx_appr_rule_det_cr_sts;
                        END IF;

                        IF lx_approvers_cr_sts = 'S'
                        THEN
                            --Update Stagging table with Approvers API Status 'S'
                            UPDATE xxdo.xxd_ams_approval_upload_tbl stg
                               SET stg.status   = 'S'
                             WHERE     1 = 1
                                   AND stg.opr_mode =
                                       r_approval_dtls.opr_mode
                                   AND stg.org_id = r_approvers.org_id
                                   AND stg.batch_id = lx_batch_id
                                   AND stg.request_id = gn_request_id
                                   AND stg.approval_detail_id =
                                       r_approvers.approval_detail_id
                                   AND stg.approver_order =
                                       r_approvers.approver_order
                                   AND stg.approver_type =
                                       r_approvers.approver_type;

                            COMMIT;
                        ELSE
                            --Update Stagging table with Approvers API Status 'E'
                            lv_proc_error_msg   :=
                                   lv_proc_error_msg
                                || ' Approvers API status Failure- '
                                || lx_approvers_cr_msg;

                            UPDATE xxdo.xxd_ams_approval_upload_tbl stg
                               SET stg.status = 'E', error_message = lv_proc_error_msg
                             WHERE     1 = 1
                                   --AND stg.status                 = 'N'
                                   AND stg.opr_mode =
                                       r_approval_dtls.opr_mode
                                   AND stg.org_id = r_approvers.org_id
                                   AND stg.batch_id = lx_batch_id
                                   AND stg.request_id = gn_request_id
                                   AND stg.approval_detail_id =
                                       r_approvers.approval_detail_id
                                   AND stg.approver_order =
                                       r_approvers.approver_order
                                   AND stg.approver_type =
                                       r_approvers.approver_type;

                            COMMIT;
                        -- RAISE le_proc_error_exception;
                        END IF;            -- Approvers creation success endif
                    END LOOP;                --End loop for c_approvers cursor
                ELSE
                    --Update Stagging table with Approval Rule API Status 'E'
                    lv_proc_error_msg   :=
                           lv_proc_error_msg
                        || ' Approval Rules API status Failure- '
                        || lx_appr_rule_det_cr_msg;

                    UPDATE xxdo.xxd_ams_approval_upload_tbl stg
                       SET stg.status = 'E', error_message = lv_proc_error_msg
                     WHERE     1 = 1
                           AND stg.opr_mode = r_approval_dtls.opr_mode
                           AND stg.org_id = r_approval_dtls.org_id
                           AND stg.batch_id = lx_batch_id
                           AND stg.request_id = gn_request_id
                           AND stg.approval_rule_name =
                               r_approval_dtls.approval_rule_name
                           AND stg.approval_type =
                               r_approval_dtls.approval_type
                           AND stg.claim_type_id =
                               r_approval_dtls.claim_type_id
                           AND stg.start_date = r_approval_dtls.start_date
                           AND stg.currency = r_approval_dtls.currency;

                    COMMIT;
                -- RAISE le_proc_error_exception;
                END IF;          --Approval rule detail creation success endif
            END LOOP;                    --End loop for c_approval_dtls cursor
        END IF;                                        --ln_new_rec_cnt end if

        ------------------------------------------------------
        --Started Approval Rule Details and Approvers --EDIT
        ------------------------------------------------------
        IF ln_edit_rec_cnt > 0
        THEN
            FOR r_approval_dtls_upd IN c_approval_dtls_upd
            LOOP
                --Calling Procedure to update Batch ID
                BEGIN
                    --Calling to update Batch ID for EDIT Mode
                    edit_stg_batch_id (
                        p_mode          => r_approval_dtls_upd.opr_mode,
                        p_org_id        => r_approval_dtls_upd.org_id,
                        p_old_appr_rule_name   =>
                            r_approval_dtls_upd.old_appr_rule_name,
                        p_approval_rule_name   =>
                            r_approval_dtls_upd.approval_rule_name,
                        p_description   => r_approval_dtls_upd.description,
                        p_start_date    => r_approval_dtls_upd.start_date,
                        p_end_date      => r_approval_dtls_upd.end_date,
                        px_batch_id     => lx_batch_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lx_batch_id   := -99;
                END;

                IF ((lx_batch_id = -99) OR (lx_batch_id <= 0))
                THEN
                    lv_proc_error_msg   :=
                           lv_proc_error_msg
                        || ' EDIT-Batch Sequence failure => '
                        || lx_batch_id;
                END IF;

                fnd_file.put_line (fnd_file.LOG,
                                   'EDIT-Batch Id => ' || lx_batch_id);

                IF lx_batch_id > 0
                THEN
                    BEGIN
                        --Calling Update Approval Rule Details API procedure
                        update_approval_dtls (
                            p_operating_unit        =>
                                r_approval_dtls_upd.operating_unit,
                            p_org_id                => r_approval_dtls_upd.org_id,
                            p_approval_detail_id    =>
                                r_approval_dtls_upd.approval_detail_id,
                            p_old_appr_rule_name    =>
                                r_approval_dtls_upd.old_appr_rule_name,
                            p_approval_rule_name    =>
                                r_approval_dtls_upd.approval_rule_name,
                            p_start_date            => r_approval_dtls_upd.start_date,
                            p_end_date              => r_approval_dtls_upd.end_date,
                            p_currency              => r_approval_dtls_upd.currency,
                            p_claim_type_id         =>
                                r_approval_dtls_upd.claim_type_id,
                            p_reason_code_id        =>
                                r_approval_dtls_upd.reason_code_id,
                            p_minimum_amount        =>
                                r_approval_dtls_upd.minimum_amount,
                            p_maximum_amount        =>
                                r_approval_dtls_upd.maximum_amount,
                            p_description           => r_approval_dtls_upd.description,
                            p_batch_id              =>
                                NVL (r_approval_dtls_upd.batch_id,
                                     lx_batch_id),
                            px_approval_detail_id   => lx_edit_approval_dtl_id,
                            px_edit_return_status   =>
                                lx_appr_rule_det_edit_sts,
                            px_edit_error_msg       =>
                                lx_appr_rule_det_edit_msg,
                            p_setup_type            =>
                                r_approval_dtls_upd.attribute_num1 --CCR0008340
                                                                  );
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Approval Details API Proc Failure ');
                            lx_appr_rule_det_edit_sts   := 'E';
                            lv_proc_error_msg           :=
                                   lv_proc_error_msg
                                || 'EXP: EDIT- Approval Details API Proc Failure- '
                                || SQLERRM;
                    END;
                END IF;

                fnd_file.put_line (
                    fnd_file.LOG,
                       'EDIT-Approval Rule Details API Status => '
                    || lx_appr_rule_det_edit_sts
                    || ' and Message => '
                    || lx_appr_rule_det_edit_msg);

                --Update Approval rule details is success then loop to Update approvers
                IF lx_appr_rule_det_edit_sts = 'S'
                THEN
                    FOR r_approvers_upd
                        IN c_approvers_upd (
                               p_batch_id     => lx_batch_id --r_approval_dtls.batch_id
                                                            ,
                               p_org_id       => r_approval_dtls_upd.org_id,
                               p_approval_detail_id   =>
                                   r_approval_dtls_upd.approval_detail_id,
                               p_approval_rule_name   =>
                                   r_approval_dtls_upd.old_appr_rule_name,
                               p_start_date   =>
                                   r_approval_dtls_upd.start_date,
                               p_end_date     => r_approval_dtls_upd.end_date)
                    LOOP
                        --Validate Approver User Role Exists or Not
                        IF r_approvers_upd.approver_user_role_id IS NOT NULL
                        THEN
                            BEGIN
                                SELECT COUNT (1)
                                  INTO ln_user_role_exists
                                  FROM ams_approvers
                                 WHERE     ams_approval_detail_id =
                                           r_approvers_upd.approval_detail_id
                                       AND object_approver_id =
                                           r_approvers_upd.approver_user_role_id
                                       AND active_flag = 'Y';
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    ln_user_role_exists   := 0;
                            END;
                        ELSE
                            ln_user_role_exists   := 0;
                        END IF;

                        IF ((r_approvers_upd.approval_detail_id IS NOT NULL) AND (r_approvers_upd.approver_id IS NOT NULL))
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'EDIT- Org ID => '
                                || r_approvers_upd.org_id
                                || ' \ Old Approver Seq => '
                                || r_approvers_upd.approver_order
                                || ' and User Role Exists => '
                                || ln_user_role_exists);

                            --Validate Approver User Role Exists in Approver SEQ
                            BEGIN
                                SELECT object_approver_id
                                  INTO ln_chk_object_approver_id
                                  FROM ams_approvers
                                 WHERE     ams_approval_detail_id =
                                           r_approvers_upd.approval_detail_id
                                       AND object_approver_id =
                                           r_approvers_upd.approver_user_role_id
                                       AND approver_id =
                                           r_approvers_upd.approver_id
                                       AND active_flag = 'Y';
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    ln_chk_object_approver_id   := 0;
                            END;

                            IF ((ln_user_role_exists > 0) AND (ln_chk_object_approver_id <> r_approvers_upd.approver_user_role_id))
                            THEN
                                lx_approvers_edit_sts   := 'E';
                                lx_approvers_edit_msg   :=
                                       'Validation: Approver-User Role already Exists, Change User Role and Proceed for Approver Order_No => '
                                    || r_approvers_upd.approver_order;

                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Validation: Approver-User Role already Exists, Change User Role and Proceed for Approver Order_No => '
                                    || r_approvers_upd.approver_order);
                            ELSE
                                --Calling Update Approvers API procedure
                                update_approvers (
                                    p_org_id          => r_approvers_upd.org_id,
                                    p_approval_dtl_id   =>
                                        r_approvers_upd.approval_detail_id,
                                    p_approver_id     =>
                                        r_approvers_upd.approver_id,
                                    p_approver_order   =>
                                        r_approvers_upd.approver_order,
                                    p_user_role_id    =>
                                        r_approvers_upd.approver_user_role_id,
                                    p_approver_start_date   =>
                                        r_approvers_upd.approver_start_date,
                                    p_approver_end_date   =>
                                        r_approvers_upd.approver_end_date,
                                    p_batch_id        => r_approvers_upd.batch_id,
                                    px_approvers_id   => lx_approvers_id,
                                    px_return_status   =>
                                        lx_approvers_edit_sts,
                                    px_error_msg      => lx_approvers_edit_msg);
                            END IF;
                        ELSIF ((r_approvers_upd.approval_detail_id IS NOT NULL) AND (r_approvers_upd.approver_id IS NULL) AND (r_approvers_upd.approver_order IS NOT NULL))
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'EDIT-New Approver Creation for Org ID => '
                                || r_approvers_upd.org_id
                                || ' and Approver Seq => '
                                || r_approvers_upd.approver_order);

                            BEGIN
                                SELECT MAX (approver_seq)
                                  INTO ln_max_appr_seqno
                                  FROM ams_approvers
                                 WHERE     ams_approval_detail_id =
                                           r_approvers_upd.approval_detail_id
                                       AND active_flag = 'Y';
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    ln_max_appr_seqno   := 0;
                            END;

                            IF ((ln_max_appr_seqno <> 0) AND (r_approvers_upd.approver_order >= ln_max_appr_seqno + 10))
                            THEN
                                ln_max_appr_seqno   := ln_max_appr_seqno + 10;
                            ELSE
                                ln_max_appr_seqno   :=
                                    r_approvers_upd.approver_order;
                            END IF;

                            IF ln_user_role_exists > 0
                            THEN
                                lx_approvers_edit_sts   := 'E';
                                lx_approvers_edit_msg   :=
                                       'Validation: New Approver-User Role already Exists, Change User Role and Proceed for Approver Order_No => '
                                    || r_approvers_upd.approver_order;

                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Validation: New Approver-User Role already Exists, Change User Role and Proceed for Approver Order_No => '
                                    || r_approvers_upd.approver_order);
                            ELSE
                                --Calling Create Approvers API Procedure in EDIT mode
                                create_approvers (
                                    p_org_id           => r_approvers_upd.org_id,
                                    p_approval_dtl_id   =>
                                        r_approvers_upd.approval_detail_id,
                                    p_approver_order   => ln_max_appr_seqno, --r_approvers_upd.approver_order,
                                    p_approver_type    =>
                                        r_approvers_upd.approver_type,
                                    p_approver_user_role_id   =>
                                        r_approvers_upd.approver_user_role_id,
                                    p_approver_start_date   =>
                                        r_approvers_upd.approver_start_date,
                                    p_approver_end_date   =>
                                        r_approvers_upd.approver_end_date,
                                    p_batch_id         =>
                                        r_approvers_upd.batch_id,
                                    px_approvers_id    => lx_edit_approvers_id,
                                    px_return_status   =>
                                        lx_approvers_edit_sts,
                                    px_error_msg       =>
                                        lx_approvers_edit_msg);
                            END IF;
                        ELSE
                            lx_approvers_edit_sts   :=
                                lx_appr_rule_det_edit_sts;

                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'EDIT-No Approver details for Approval Rule- OrgID => '
                                || r_approvers_upd.org_id
                                || ' and Approval detail ID => '
                                || r_approvers_upd.approval_detail_id);
                        END IF;

                        --Updation of Approver ID
                        IF r_approvers_upd.approver_id IS NOT NULL
                        THEN
                            lx_edit_approvers_id   :=
                                r_approvers_upd.approver_id;
                        ELSE
                            lx_edit_approvers_id   := lx_edit_approvers_id;
                        END IF;

                        FND_FILE.PUT_LINE (
                            FND_FILE.LOG,
                               'EDIT- Approvers API Status =>'
                            || lx_approvers_edit_sts
                            || ' for Approver ID: '
                            || lx_edit_approvers_id);

                        IF lx_approvers_edit_sts = 'S'
                        THEN
                            --EDIT: Stagging table update with Approvers API Status 'S'
                            UPDATE xxdo.xxd_ams_approval_upload_tbl stg
                               SET stg.status = 'S', stg.approver_id = lx_edit_approvers_id
                             WHERE     1 = 1
                                   AND stg.opr_mode =
                                       r_approvers_upd.opr_mode
                                   AND stg.org_id = r_approvers_upd.org_id
                                   AND stg.batch_id = lx_batch_id
                                   AND stg.request_id = gn_request_id
                                   AND stg.approval_detail_id =
                                       r_approvers_upd.approval_detail_id
                                   AND stg.approver_order =
                                       r_approvers_upd.approver_order;

                            COMMIT;
                        ELSE
                            --EDIT: Stagging table update with Approvers API Status 'E'
                            lv_proc_error_msg   :=
                                   'EDIT- Approvers API Status Failure - '
                                || lx_approvers_edit_msg;

                            UPDATE xxdo.xxd_ams_approval_upload_tbl stg
                               SET stg.status = 'E', error_message = lv_proc_error_msg
                             WHERE     1 = 1
                                   AND stg.opr_mode =
                                       r_approvers_upd.opr_mode
                                   AND stg.org_id = r_approvers_upd.org_id
                                   AND stg.batch_id = lx_batch_id
                                   AND stg.request_id = gn_request_id
                                   AND stg.approval_detail_id =
                                       r_approvers_upd.approval_detail_id
                                   AND stg.approver_order =
                                       r_approvers_upd.approver_order;

                            COMMIT;
                        -- RAISE le_proc_error_exception;
                        END IF;            -- Approvers updation success endif
                    END LOOP;            --End loop for c_approvers_upd cursor
                ELSE
                    --Update Stagging table with Approval Rule API Status 'E'
                    lv_proc_error_msg   :=
                           lv_proc_error_msg
                        || ' EDIT- Approval Rules API status Failure -'
                        || lx_appr_rule_det_edit_msg;

                    BEGIN
                        UPDATE xxdo.xxd_ams_approval_upload_tbl stg
                           SET stg.status = 'E', error_message = lv_proc_error_msg
                         WHERE     1 = 1
                               AND stg.opr_mode =
                                   r_approval_dtls_upd.opr_mode
                               AND stg.org_id = r_approval_dtls_upd.org_id
                               AND stg.batch_id = lx_batch_id
                               AND stg.request_id = gn_request_id
                               AND stg.old_appr_rule_name =
                                   r_approval_dtls_upd.old_appr_rule_name;

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_proc_error_msg   := lv_proc_error_msg;
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'EDIT- Approval Rules Status update in Staging Err:'
                                || SQLERRM);
                    END;
                --RAISE le_proc_error_exception;
                END IF;          --Approval rule detail creation success endif
            END LOOP;                    --End loop for c_approval_dtls cursor
        END IF;                                       --ln_edit_rec_cnt end if

        BEGIN
            --Calling Status Report
            status_report (pv_error_msg => lv_proc_error_msg);

            IF lv_proc_error_msg IS NOT NULL
            THEN
                RAISE le_proc_error_exception;
            END IF;
        END;

        pv_errbuf    := NULL;
        pv_retcode   := gn_success;
    EXCEPTION
        WHEN le_proc_error_exception
        THEN
            COMMIT;
            raise_application_error (-20000, lv_proc_error_msg);
        WHEN OTHERS
        THEN
            COMMIT;
            lv_proc_error_msg   :=
                SUBSTR (lv_proc_error_msg || SQLERRM, 1, 2000);
            fnd_file.put_line (fnd_file.LOG, lv_proc_error_msg);
            pv_retcode   := gn_error;                                     --2;
            RAISE;
    END;

    -- Report for Verification
    PROCEDURE status_report (pv_error_msg OUT VARCHAR2)
    IS
        CURSOR c_status_rep IS
              SELECT opr_mode, operating_unit, old_appr_rule_name,
                     approval_rule_name, approval_type, claim_type,
                     reason, start_date, end_date,
                     currency, minimum_amount, maximum_amount,
                     description, approver_order, approver_type,
                     approver_user_role, approver_start_date, approver_end_date,
                     approval_detail_id, approver_id, DECODE (stg.status,  'S', 'Success',  'E', 'Error',  'N', 'Not Processed',  'Error') status,
                     stg.error_message, attribute_num1           -- CCR0008340
                FROM xxdo.xxd_ams_approval_upload_tbl stg
               WHERE stg.request_id = gn_request_id
            ORDER BY approval_detail_id, approver_id;

        ln_setup_name   VARCHAR2 (100);                           --CCR0008340
    BEGIN
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD ('Mode', 5, ' ')
            || CHR (9)
            || RPAD ('Operating_unit', 20, ' ')
            || CHR (9)
            || RPAD ('Old_Approval_rule_name', 30, ' ')
            || CHR (9)
            || RPAD ('Approval_rule_name', 30, ' ')
            || CHR (9)
            || RPAD ('Approval_type', 20, ' ')
            || CHR (9)
            || RPAD ('Claim_type', 30, ' ')
            || CHR (9)
            || RPAD ('Setup_type', 53, ' ')                      -- CCR0008340
            || CHR (9)
            || RPAD ('Reason', 25, ' ')
            || CHR (9)
            || RPAD ('Currency', 10, ' ')
            || CHR (9)
            || RPAD ('Aproval_detail_id', 20, ' ')
            || CHR (9)
            || RPAD ('approver_id', 20, ' ')
            || CHR (9)
            || RPAD ('Status', 15, ' ')
            || CHR (9)
            || RPAD ('Error Message', 1000, ' ')
            || CHR (9));

        FOR c_status_rep_rec IN c_status_rep
        LOOP
            --CCR0008340 Changes Start
            --Validate Setup Type

            BEGIN
                SELECT setup_name
                  INTO ln_setup_name
                  FROM ams_custom_setups_tl
                 WHERE     custom_setup_id = c_status_rep_rec.attribute_num1
                       AND LANGUAGE = 'US';
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_setup_name   := NULL;
            END;

            --CCR0008340 Changes end
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   RPAD (c_status_rep_rec.opr_mode, 5, ' ')
                || CHR (9)
                || RPAD (c_status_rep_rec.operating_unit, 20, ' ')
                || CHR (9)
                || RPAD (
                       TRIM (
                           NVL (c_status_rep_rec.old_appr_rule_name, 'NULL')),
                       30,
                       ' ')
                || CHR (9)
                || RPAD (
                       TRIM (
                           NVL (c_status_rep_rec.approval_rule_name, 'NULL')),
                       30,
                       ' ')
                || CHR (9)
                || RPAD (NVL (c_status_rep_rec.approval_type, 'NULL'),
                         20,
                         ' ')
                || CHR (9)
                || RPAD (NVL (c_status_rep_rec.claim_type, 'NULL'), 30, ' ')
                || CHR (9)
                || RPAD (NVL (ln_setup_name, 'NULL'), 53, ' ')   -- CCR0008340
                || CHR (9)
                || RPAD (NVL (c_status_rep_rec.reason, 'NULL'), 25, ' ')
                || CHR (9)
                || RPAD (NVL (c_status_rep_rec.currency, 'NULL'), 10, ' ')
                || CHR (9)
                || RPAD (NVL (c_status_rep_rec.approval_detail_id, -1),
                         20,
                         ' ')
                || CHR (9)
                || RPAD (NVL (c_status_rep_rec.approver_id, -1), 20, ' ')
                || CHR (9)
                || RPAD (NVL (c_status_rep_rec.status, 'NULL'), 15, ' ')
                || CHR (9)
                || RPAD (c_status_rep_rec.error_message, 1000, ' ')
                || CHR (9));
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_msg   :=
                SUBSTR ('Error in Status Report Proc' || SQLERRM, 1, 2000);
    END status_report;
END XXD_TM_APPR_RULES_UPL_PKG;
/
