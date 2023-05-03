--
-- XXDOAR_BPA_REP_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:23 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.xxdoar_bpa_rep_pkg
AS
    cr   CONSTANT CHAR (2) := ' ';

    FUNCTION build_where_clause
        RETURN BOOLEAN
    IS
    BEGIN
        p_where_clause   := NULL;

        IF ((p_cust_num_low IS NOT NULL) AND (p_cust_num_high IS NULL))
        THEN
            p_where_clause   :=
                   p_where_clause
                || ' AND con.account_number = :p_cust_num_low'
                || cr;
        ELSIF ((p_cust_num_high IS NOT NULL) AND (p_cust_num_low IS NULL))
        THEN
            p_where_clause   :=
                   p_where_clause
                || ' AND con.account_number = :p_cust_num_high '
                || cr;
        ELSIF ((p_cust_num_high IS NOT NULL) AND (p_cust_num_low IS NOT NULL))
        THEN
            p_where_clause   :=
                   p_where_clause
                || ' AND con.account_number >= :p_cust_num_low '
                || cr;
            p_where_clause   :=
                   p_where_clause
                || ' AND con.account_number <= :p_cust_num_high '
                || cr;
        END IF;

        IF ((p_bill_site_low IS NOT NULL) AND (p_bill_site_high IS NULL))
        THEN
            p_where_clause   :=
                   p_where_clause
                || ' AND con.site_use_id = :p_bill_site_low '
                || cr;
        ELSIF ((p_bill_site_high IS NOT NULL) AND (p_bill_site_low IS NULL))
        THEN
            p_where_clause   :=
                   p_where_clause
                || ' AND con.site_use_id = :p_bill_site_high '
                || cr;
        ELSIF ((p_bill_site_high IS NOT NULL) AND (p_bill_site_low IS NOT NULL))
        THEN
            p_where_clause   :=
                   p_where_clause
                || ' AND con.site_use_id >= :p_bill_site_low '
                || cr;
            p_where_clause   :=
                   p_where_clause
                || ' AND con.site_use_id <= :p_bill_site_high '
                || cr;
        END IF;

        p_where_clause   :=
               p_where_clause
            || ' AND billing_date between nvl(:p_bill_date_low, billing_date) and nvl(:p_bill_date_high, billing_date) '
            || cr;

        IF ((p_bill_num_low IS NOT NULL) AND (p_bill_num_high IS NULL))
        THEN
            p_where_clause   :=
                   p_where_clause
                || ' AND con.cons_billing_number = :p_bill_num_low '
                || cr;
        ELSIF ((p_bill_num_high IS NOT NULL) AND (p_bill_num_low IS NULL))
        THEN
            p_where_clause   :=
                   p_where_clause
                || ' AND con.cons_billing_number = :p_bill_num_high '
                || cr;
        ELSIF ((p_bill_num_low IS NOT NULL) AND (p_bill_num_high IS NOT NULL))
        THEN
            p_where_clause   :=
                   p_where_clause
                || ' AND con.cons_billing_number >= :p_bill_num_low '
                || cr;
            p_where_clause   :=
                   p_where_clause
                || ' AND con.cons_billing_number <= :p_bill_num_high '
                || cr;
        END IF;

        IF p_disp_zero = 'N'
        THEN
            p_where_clause   :=
                   p_where_clause
                || ' AND (con.begining_balance <> 0 OR con.ending_balance <> 0 OR con.total_receipt_amt <> 0 OR con.total_adjustment_amt <> 0
                        OR con.total_credits_amt <> 0 OR con.total_finance_charges_amt <> 0 OR con.total_trx_amt <> 0)'
                || cr;
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Test' || p_where_clause);
        END IF;

        -- p_where_clause :='1=1';
        fnd_file.put_line (fnd_file.LOG, p_where_clause);
        RETURN (TRUE);
    END;

    /*Start Added by BT Tech Team on 20-MAR-2015*/
    FUNCTION build_where_clause1 (p_brand IN VARCHAR2, p_bill_to_country VARCHAR2, p_column VARCHAR2)
        RETURN VARCHAR
    IS
        l_image_path     VARCHAR2 (300);
        l_company_chop   VARCHAR2 (300);
        l_company_logo   VARCHAR2 (300);
    BEGIN
        BEGIN
            SELECT '$[OA_MEDIA]' image_path, attribute11 company_chop, attribute12 company_logo
              INTO l_image_path, l_company_chop, l_company_logo
              FROM apps.fnd_lookup_values
             WHERE     lookup_type = 'XXDO_CUST_FAC_DOC_LKP'
                   AND attribute1 =
                       (SELECT country
                          FROM hr_organization_units_v
                         WHERE organization_id =
                               apps.fnd_profile.VALUE ('ORG_ID'))
                   AND attribute2 = NVL (p_bill_to_country, attribute1)
                   AND attribute5 = p_brand                       --:BRAND_VAL
                   AND attribute4 = 'Invoice'
                   AND LANGUAGE = USERENV ('LANG')
                   AND enabled_flag = 'Y'
                   AND SYSDATE BETWEEN start_date_active
                                   AND NVL (end_date_active, SYSDATE);
        EXCEPTION
            WHEN OTHERS
            THEN
                SELECT '$[OA_MEDIA]' image_path, attribute11 company_chop, attribute12 company_logo
                  INTO l_image_path, l_company_chop, l_company_logo
                  FROM apps.fnd_lookup_values
                 WHERE     lookup_type = 'XXDO_CUST_FAC_DOC_LKP'
                       AND attribute1 =
                           (SELECT country
                              FROM hr_organization_units_v
                             WHERE organization_id =
                                   apps.fnd_profile.VALUE ('ORG_ID'))
                       AND attribute2 = NVL (p_bill_to_country, attribute1)
                       AND attribute5 = 'ALL BRAND'               --:BRAND_VAL
                       AND attribute4 = 'Invoice'
                       AND LANGUAGE = USERENV ('LANG')
                       AND enabled_flag = 'Y'
                       AND SYSDATE BETWEEN start_date_active
                                       AND NVL (end_date_active, SYSDATE);
        END;

        IF p_column = 'IMAGE_PATH'
        THEN
            RETURN l_image_path;
        ELSIF p_column = 'COMPANY_CHOP'
        THEN
            RETURN l_company_chop;
        ELSIF p_column = 'COMPANY_LOGO'
        THEN
            RETURN l_company_logo;
        END IF;
    END;
/*End Added by BT Tech Team on 20-MAR-2015*/
END xxdoar_bpa_rep_pkg;
/
