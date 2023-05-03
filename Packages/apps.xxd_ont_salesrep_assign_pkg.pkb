--
-- XXD_ONT_SALESREP_ASSIGN_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:22 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_SALESREP_ASSIGN_PKG"
AS
    /************************************************************************************************
    * Package      : XXD_ONT_SALESREP_ASSIGN_PKG
    * Design       : This WEBADI package is used for Salesrep insert/update
    * Notes        :
    * Modification :
    -- ==============================================================================================
    -- Date         Version#   Name                    Comments
    -- ==============================================================================================
    -- 01-Dec-2021  1.0        Gaurav Joshi            Initial Version
 -- 22-Jul-2022 1.1     Ramesh BR      CCR0010033 - Unable to update salesrep record
 --               which is created by WEBADI as last_update_login
 --               is populated with null value
    *************************************************************************************************/
    -- return N when flexvalue is not valid in the given valueset name
    FUNCTION validateFlexValue (P_value_set_name   IN VARCHAR2,
                                p_flex_value       IN VARCHAR2)
        RETURN VARCHAR2
    IS
        l_value   VARCHAR2 (240);
    BEGIN
        IF p_flex_value IS NOT NULL
        THEN
            SELECT ffv.flex_value
              INTO l_value
              FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv, fnd_flex_values_tl ffvt
             WHERE     ffvs.flex_value_set_id = ffv.flex_value_set_id
                   AND ffv.flex_value_id = ffvt.flex_value_id
                   AND ffvt.language = USERENV ('LANG')
                   AND flex_value_set_name = P_value_set_name
                   AND ffv.flex_value = p_flex_value
                   AND ffv.enabled_flag = 'Y';
        ELSE
            RETURN 'Y';
        END IF;

        RETURN 'Y';
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 'N';
    END validateFlexValue;

    PROCEDURE main (
        p_ou_name           IN DO_CUSTOM.DO_REP_CUST_ASSIGNMENT.ou_name%TYPE,
        p_customer_number   IN DO_CUSTOM.DO_REP_CUST_ASSIGNMENT.ou_name%TYPE,
        p_customer_site     IN DO_CUSTOM.DO_REP_CUST_ASSIGNMENT.customer_site%TYPE,
        p_site_use_code     IN DO_CUSTOM.DO_REP_CUST_ASSIGNMENT.site_use_code%TYPE,
        p_salesrep_name     IN DO_CUSTOM.DO_REP_CUST_ASSIGNMENT.salesrep_name%TYPE,
        p_brand             IN DO_CUSTOM.DO_REP_CUST_ASSIGNMENT.brand%TYPE,
        p_division          IN DO_CUSTOM.DO_REP_CUST_ASSIGNMENT.division%TYPE,
        p_department        IN DO_CUSTOM.DO_REP_CUST_ASSIGNMENT.department%TYPE,
        p_class             IN DO_CUSTOM.DO_REP_CUST_ASSIGNMENT.class%TYPE,
        p_subclass          IN DO_CUSTOM.DO_REP_CUST_ASSIGNMENT.sub_class%TYPE,
        p_styleNumber       IN DO_CUSTOM.DO_REP_CUST_ASSIGNMENT.style_number%TYPE,
        p_color_code        IN DO_CUSTOM.DO_REP_CUST_ASSIGNMENT.color_code%TYPE,
        p_startDate         IN DATE,
        P_endDate           IN DATE,
        p_flag              IN VARCHAR2)
    AS
        le_webadi_exception    EXCEPTION;
        lc_return_status       VARCHAR2 (10);
        lc_err_message         VARCHAR2 (4000);
        lc_ret_message         VARCHAR2 (4000);
        lc_error_msg           VARCHAR2 (4000);
        l_customer_site        DO_CUSTOM.DO_REP_CUST_ASSIGNMENT.customer_site%TYPE;
        l_count                NUMBER;
        l_operating_unit       DO_CUSTOM.DO_REP_CUST_ASSIGNMENT.ou_name%TYPE;
        l_customer_name        DO_CUSTOM.DO_REP_CUST_ASSIGNMENT.customer_name%TYPE;
        l_customer_number      DO_CUSTOM.DO_REP_CUST_ASSIGNMENT.customer_number%TYPE;
        l_account_name         DO_CUSTOM.DO_REP_CUST_ASSIGNMENT.account_name%TYPE;
        l_salesrep_name        DO_CUSTOM.DO_REP_CUST_ASSIGNMENT.salesrep_name%TYPE;
        l_salesrep_number      DO_CUSTOM.DO_REP_CUST_ASSIGNMENT.salesrep_number%TYPE;
        l_cust_account_id      DO_CUSTOM.DO_REP_CUST_ASSIGNMENT.customer_id%TYPE;
        l_salesrep_id          DO_CUSTOM.DO_REP_CUST_ASSIGNMENT.salesrep_id%TYPE;
        l_ORG_ID               DO_CUSTOM.DO_REP_CUST_ASSIGNMENT.org_id%TYPE;
        l_site_use_id          DO_CUSTOM.DO_REP_CUST_ASSIGNMENT.site_use_id%TYPE;
        l_flag                 VARCHAR2 (1);
        l_startdate            DATE;
        l_enddate              DATE;
        l_Startvaliddateflag   VARCHAR2 (1);
        l_Endvaliddateflag     VARCHAR2 (1);
        l_date                 DATE;
        l_party_id             NUMBER;
    BEGIN
        -- validate mode
        IF p_flag IS NULL
        THEN
            lc_err_message   := lc_err_message || 'Mode is Mandatory. ';
        END IF;

        -- validate p_startDate
        IF p_flag = 'INSERT'
        THEN
            IF p_startDate IS NULL
            THEN
                l_startdate            := TO_DATE (SYSDATE, 'DD-MON-YYYY');
                l_Startvaliddateflag   := 'Y';
            ELSE
                l_startdate   := TO_DATE (p_startDate, 'DD-MON-YYYY');

                -- start date is not null
                BEGIN
                    SELECT TO_DATE (l_startdate, 'DD-MON-YYYY')
                      INTO l_date
                      FROM DUAL;

                    l_Startvaliddateflag   := 'Y';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_Startvaliddateflag   := 'N';
                        lc_err_message         :=
                               lc_err_message
                            || 'Start Date is not a Valid Date. ';
                END;

                IF     l_Startvaliddateflag = 'Y'
                   AND l_startdate < TO_DATE (SYSDATE, 'DD-MON-YYYY')
                THEN
                    lc_err_message   :=
                           lc_err_message
                        || 'Start Date cannot be less than Sysdate. ';
                END IF;
            END IF;

            -- ELSIF p_flag='UPDATE' THEN
            --   NULL;
            --    END IF;

            -- validate endate
            BEGIN
                SELECT TO_DATE (p_enddate, 'DD-MON-YYYY')
                  INTO l_enddate
                  FROM DUAL;

                l_Endvaliddateflag   := 'Y';
            EXCEPTION
                WHEN OTHERS
                THEN
                    lc_err_message   :=
                        lc_err_message || 'End Date is not a valid date ';
            END;

            IF     l_Endvaliddateflag = 'Y'
               AND l_Startvaliddateflag = 'Y'
               AND l_enddate < l_startdate
            THEN
                lc_err_message   :=
                       lc_err_message
                    || 'End Date cannot be less than Start Date. ';
            END IF;
        ELSIF p_flag = 'UPDATE'
        THEN
            IF     p_startDate IS NOT NULL
               AND p_enddate IS NOT NULL
               AND TO_DATE (p_enddate, 'DD-MON-YYYY') <
                   TO_DATE (p_startDate, 'DD-MON-YYYY')
            THEN
                lc_err_message   :=
                       lc_err_message
                    || 'End Date cannot be less than Start Date. ';
            END IF;
        END IF;

        --  validate org id
        BEGIN
            SELECT organization_id
              INTO l_ORG_ID
              FROM hr_operating_units
             WHERE name = p_ou_name;
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_err_message   :=
                    lc_err_message || 'Operating unit is not valid. ';
        END;

        -- validate brand
        SELECT COUNT (*)
          INTO l_count
          FROM FND_LOOKUP_VALUES
         WHERE     lookup_type = 'DO_BRANDS'
               AND (SYSDATE BETWEEN NVL (start_date_active, SYSDATE) AND NVL (end_date_active, SYSDATE))
               AND NVL (enabled_flag, 'N') = 'Y'
               AND language = USERENV ('LANG')
               AND lookup_code NOT IN ('TSUBO', 'ALL BRAND', 'SEAVEES',
                                       'MOZO', 'DECKERS', 'SIMPLE')
               AND lookup_code = p_brand;

        IF l_count = 0
        THEN
            lc_err_message   := lc_err_message || 'Brand is not valid. ';
        END IF;

        --  validate customer
        BEGIN
            SELECT cust_account_id, account_name, party_id
              INTO l_cust_account_id, l_account_name, l_party_id
              FROM hz_cust_accounts hca
             WHERE     hca.status = 'A'
                   AND hca.attribute18 IS NULL
                   AND account_number = p_customer_number
                   AND hca.attribute1 = p_brand;

            SELECT account_name
              INTO l_CUSTOMER_name
              FROM hz_cust_accounts hca
             WHERE     hca.status = 'A'
                   AND hca.attribute1 = 'ALL BRAND'
                   AND party_id = l_party_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_err_message   :=
                    lc_err_message || 'Customer is not valid. ';
        END;


        -- purpose IS MANDAOTRY
        IF p_site_use_code IS NULL
        THEN
            lc_err_message   := lc_err_message || 'Purpose is not valid. ';
        END IF;


        --  validate  customer site
        BEGIN
            SELECT hcsu.site_use_id
              INTO l_site_use_id
              FROM hz_cust_accounts hca, hz_cust_acct_sites_all hcs, hz_cust_site_uses_all hcsu,
                   hz_party_sites hps, hz_locations loc
             WHERE     hca.cust_account_id = hcs.cust_account_id
                   AND hcs.cust_acct_site_id = hcsu.cust_acct_site_id
                   AND hps.party_site_id = hcs.party_site_id
                   AND hps.location_id = loc.location_id
                   AND NVL (hcs.STATUS, 'A') = 'A'
                   AND NVL (hca.status, 'A') = 'A'
                   AND NVL (hps.status, 'A') = 'A'
                   AND NVL (hcsu.status, 'A') = 'A'
                   AND NVL (hcs.status, 'A') = 'A'
                   AND hca.cust_account_id = l_cust_account_id
                   AND hcsu.location = p_customer_site
                   AND hcsu.SITE_USE_CODE = P_SITE_USE_CODE;
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_err_message   :=
                    lc_err_message || 'Customer site is not valid. ';
        END;

        IF    p_flag = 'INSERT'
           OR (p_flag = 'UPDATE' AND p_salesrep_name IS NOT NULL)
        THEN
            --  validate salesrep_id only in insert.
            BEGIN
                SELECT DISTINCT JRS.salesrep_id, JRS.Salesrep_number
                  INTO l_salesrep_id, l_salesrep_number
                  FROM jtf_rs_resource_extns_vl JRRE, jtf_rs_salesreps JRS
                 WHERE     1 = 1
                       AND Jrs.Resource_Id = Jrre.Resource_Id
                       AND JRRE.resource_name = p_salesrep_name;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lc_err_message   :=
                        lc_err_message || 'Salesrep is not valid. ';
            END;
        END IF;

        -- validate division
        l_flag   := validateFlexValue ('DO_DIVISION_CAT', p_division);

        IF l_flag = 'N'
        THEN
            lc_err_message   := lc_err_message || 'Division is not valid. ';
        END IF;

        --validate department
        l_flag   := validateFlexValue ('DO_DEPARTMENT_CAT', p_department);

        IF l_flag = 'N'
        THEN
            lc_err_message   := lc_err_message || 'Department is not valid. ';
        END IF;

        -- validate class
        l_flag   := validateFlexValue ('DO_CLASS_CAT', p_class);

        IF l_flag = 'N'
        THEN
            lc_err_message   := lc_err_message || 'Class is not valid. ';
        END IF;

        -- validate subclass
        l_flag   := validateFlexValue ('DO_SUBCLASS_CAT', p_subclass);

        IF l_flag = 'N'
        THEN
            lc_err_message   := lc_err_message || 'subclass is not valid. ';
        END IF;

        -- validate stylenumber
        l_flag   := validateFlexValue ('DO_STYLE_NUM', p_styleNumber);

        IF l_flag = 'N'
        THEN
            lc_err_message   :=
                lc_err_message || 'Style Number is not valid. ';
        END IF;

        -- vlaidate color code
        l_flag   := validateFlexValue ('DO_COLOR_CODE', p_color_code);

        IF l_flag = 'N'
        THEN
            lc_err_message   := lc_err_message || 'Color Code is not valid. ';
        END IF;

        IF lc_err_message IS NOT NULL
        THEN
            RAISE le_webadi_exception;
        ELSE
            IF P_FLAG = 'INSERT'
            THEN
                SELECT COUNT (*)
                  INTO l_count
                  FROM do_custom.do_rep_cust_assignment
                 WHERE     1 = 1
                       AND CUSTOMER_ID = l_cust_account_id
                       AND org_id = l_ORG_ID
                       AND SITE_USE_ID = l_SITE_USE_ID
                       AND SITE_USE_CODE = p_SITE_USE_CODE
                       AND BRAND = p_brand
                       AND NVL (DIVISION, '-99') = NVL (p_division, '-99')
                       AND NVL (DEPARTMENT, '-99') =
                           NVL (p_department, '-99')
                       AND NVL (CLASS, '-99') = NVL (p_class, '-99')
                       AND NVL (SUB_CLASS, '-99') = NVL (p_subclass, '-99')
                       AND NVL (STYLE_NUMBER, '-99') =
                           NVL (p_styleNumber, '-99')
                       AND NVL (COLOR_CODE, '-99') =
                           NVL (p_color_code, '-99')
                       AND TRUNC (SYSDATE) BETWEEN NVL (TRUNC (start_date),
                                                        TRUNC (SYSDATE))
                                               AND NVL (TRUNC (end_date),
                                                        TRUNC (SYSDATE));


                IF l_count > 0
                THEN
                    lc_err_message   :=
                           lc_err_message
                        || 'Record already exist.you may choose to update the existing record';
                    RAISE le_webadi_exception;
                END IF;

                -- VALIDATE AND THEN INSERT
                INSERT INTO do_custom.do_rep_cust_assignment (
                                CUSTOMER_ID,
                                SALESREP_ID,
                                SALESREP_NUMBER,
                                SALESREP_NAME,
                                BRAND,
                                SITE_USE_ID,
                                DIVISION,
                                DEPARTMENT,
                                CLASS,
                                SUB_CLASS,
                                CREATED_BY,
                                ORG_ID,
                                CREATION_DATE,
                                LAST_UPDATED_BY,
                                LAST_UPDATE_DATE,
                                LAST_UPDATE_LOGIN,
                                OU_NAME,
                                CUSTOMER_NAME,
                                CUSTOMER_NUMBER,
                                CUSTOMER_SITE,
                                SITE_USE_CODE,
                                ACCOUNT_NAME,
                                START_DATE,
                                END_DATE,
                                STYLE_NUMBER,
                                COLOR_CODE)
                     VALUES (l_cust_account_id, l_SALESREP_ID, L_SALESREP_NUMBER, P_SALESREP_NAME, P_BRAND, l_SITE_USE_ID, P_DIVISION, P_DEPARTMENT, P_CLASS, P_SUBCLASS, FND_GLOBAL.USER_ID, l_ORG_ID, SYSDATE, FND_GLOBAL.USER_ID, SYSDATE, --NULL,               -- LAST_UPDATE_LOGIN Commented as per CCR0010033
                                                                                                                                                                                                                                              FND_GLOBAL.LOGIN_ID, -- LAST_UPDATE_LOGIN Added as per CCR0010033
                                                                                                                                                                                                                                                                   p_ou_name, L_CUSTOMER_NAME, p_customer_number, p_CUSTOMER_SITE, p_SITE_USE_CODE, L_ACCOUNT_NAME, l_startDate, l_enddate
                             , P_STYLENUMBER, P_COLOR_CODE);
            ELSIF P_FLAG = 'UPDATE'
            THEN
                -- VALDIATE AND UPDATE RECROD
                -- update iS ONLY FOR salesrep,start or end date
                -- IF THE INTEND IS TO UPDATE SITE ID- LOCATION THEN INSERT A NEW RECORD
                SELECT COUNT (*)
                  INTO l_count
                  FROM do_custom.do_rep_cust_assignment
                 WHERE     1 = 1
                       AND CUSTOMER_ID = l_cust_account_id
                       AND org_id = l_ORG_ID
                       AND BRAND = p_brand
                       AND SITE_USE_CODE = p_site_use_code
                       AND SITE_USE_ID = l_site_use_id
                       AND NVL (DIVISION, '-99') = NVL (p_division, '-99')
                       AND NVL (DEPARTMENT, '-99') =
                           NVL (p_department, '-99')
                       AND NVL (CLASS, '-99') = NVL (p_class, '-99')
                       AND NVL (SUB_CLASS, '-99') = NVL (p_subclass, '-99')
                       AND NVL (STYLE_NUMBER, '-99') =
                           NVL (p_styleNumber, '-99')
                       AND TRUNC (SYSDATE) BETWEEN NVL (TRUNC (start_date),
                                                        TRUNC (SYSDATE))
                                               AND NVL (TRUNC (end_date),
                                                        TRUNC (SYSDATE))
                       AND NVL (COLOR_CODE, '-99') =
                           NVL (p_color_code, '-99');

                IF l_count = 0
                THEN
                    lc_err_message   :=
                           lc_err_message
                        || 'No Record exist for the given combination. you may choose to insert';
                    RAISE le_webadi_exception;
                ELSIF l_count = 1
                THEN
                    UPDATE do_custom.do_rep_cust_assignment
                       SET SALESREP_ID = l_salesrep_id, salesrep_name = p_salesrep_name, salesrep_number = NVL (l_salesrep_number, salesrep_number),
                           start_date = NVL (p_startDate, start_date), end_date = NVL (P_enddate, end_date), last_update_date = SYSDATE,
                           last_updated_by = fnd_global.user_id
                     WHERE     1 = 1
                           AND CUSTOMER_ID = l_cust_account_id
                           AND org_id = l_ORG_ID
                           AND BRAND = p_brand
                           AND SITE_USE_CODE = p_site_use_code
                           AND SITE_USE_ID = l_site_use_id
                           AND NVL (DIVISION, '-99') =
                               NVL (p_division, '-99')
                           AND NVL (DEPARTMENT, '-99') =
                               NVL (p_department, '-99')
                           AND NVL (CLASS, '-99') = NVL (p_class, '-99')
                           AND NVL (SUB_CLASS, '-99') =
                               NVL (p_subclass, '-99')
                           AND NVL (STYLE_NUMBER, '-99') =
                               NVL (p_styleNumber, '-99')
                           AND NVL (COLOR_CODE, '-99') =
                               NVL (p_color_code, '-99')
                           AND TRUNC (SYSDATE) BETWEEN NVL (
                                                           TRUNC (start_date),
                                                           TRUNC (SYSDATE))
                                                   AND NVL (TRUNC (end_date),
                                                            TRUNC (SYSDATE));
                ELSIF l_count > 1
                THEN
                    lc_err_message   :=
                           lc_err_message
                        || 'More than one Record exist for the given combination.pls use Maintaince page to update';
                    RAISE le_webadi_exception;
                END IF;
            END IF;
        END IF;
    --  COMMIT;
    EXCEPTION
        WHEN le_webadi_exception
        THEN
            fnd_message.set_name ('XXDO', 'XXD_ORDER_UPLOAD_WEBADI_MSG');
            fnd_message.set_token ('ERROR_MESSAGE', lc_err_message);
            lc_err_message   := fnd_message.get ();
            raise_application_error (-20000, lc_err_message);
        WHEN OTHERS
        THEN
            lc_err_message   := SQLERRM;
            raise_application_error (-20001, lc_err_message);
    END main;
END XXD_ONT_SALESREP_ASSIGN_PKG;
/
