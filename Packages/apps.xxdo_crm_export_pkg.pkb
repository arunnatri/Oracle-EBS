--
-- XXDO_CRM_EXPORT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:08 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_CRM_EXPORT_PKG"
AS
    /****************************************************************************************
    * Package      : XXDO_CRM_EXPORT_PKG
    * Author       : BT Technology Team
    * Created      : 25-NOV-2014
    * Program Name :
    * Description  : CRMCOD Integration outbound from EBS to CRM
    *
    * Modification :
    *--------------------------------------------------------------------------------------
    * Date          Developer     Version    Description
    *--------------------------------------------------------------------------------------
    * 25-NOV-2014   BT Technology Team         1.00       Initial BT Version
    ****************************************************************************************/

    FUNCTION get_brandrep (p_customer_id IN NUMBER)
        RETURN VARCHAR2
    IS
        v_salesrep   VARCHAR2 (2000);

        CURSOR c1 IS
              SELECT DISTINCT salesrep_name brand_rep, brand
                FROM do_custom.do_rep_cust_assignment
               WHERE customer_id = p_customer_id
            ORDER BY brand;
    BEGIN
        FOR r1 IN c1
        LOOP
            IF v_salesrep IS NOT NULL
            THEN
                v_salesrep   :=
                    v_salesrep || ' /   ' || r1.brand || ': ' || r1.brand_rep;
            ELSE
                v_salesrep   := r1.brand || ': ' || r1.brand_rep;
            END IF;
        END LOOP;

        RETURN v_salesrep;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;



    FUNCTION get_contact_latest (p_rel_party_id IN NUMBER, p_line_type IN VARCHAR2, p_country_code IN VARCHAR2)
        RETURN VARCHAR2
    IS
        v_contact_info         VARCHAR2 (2000);
        v_phone_country_code   VARCHAR2 (15);
        v_country_code         VARCHAR2 (15);
    BEGIN
        --to get parent account's country code
        BEGIN
            SELECT country
              INTO v_country_code
              FROM hz_parties
             WHERE     1 = 1
                   AND party_id =
                       (SELECT object_id
                          FROM hz_relationships
                         WHERE     party_id = p_rel_party_id
                               AND object_type = 'ORGANIZATION')
                   AND ROWNUM < 2;
        EXCEPTION
            WHEN OTHERS
            THEN
                v_country_code   := NULL;
        END;

        IF v_country_code IS NOT NULL
        THEN
            BEGIN
                SELECT phone_country_code
                  INTO v_phone_country_code
                  FROM xxdood_ebscrm_country_code
                 WHERE     1 = 1
                       AND ebs_short_name = v_country_code
                       AND ROWNUM < 2;

                --WHERE   1 = 1 AND ebs_short_name = p_country_code AND ROWNUM < 2;

                IF v_phone_country_code IS NOT NULL
                THEN
                    v_phone_country_code   :=
                        '+' || v_phone_country_code || '-';
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    v_phone_country_code   := NULL;
            END;
        END IF;

        IF p_line_type = 'GEN'
        THEN
            BEGIN
                SELECT --DECODE (hcp.PHONE_COUNTRY_CODE, '', '', hcp.PHONE_COUNTRY_CODE || '-' || '') commented on 20Dec2010
                       DECODE (hcp.PHONE_COUNTRY_CODE, '', v_phone_country_code, '+' || hcp.PHONE_COUNTRY_CODE || '-' || '') || DECODE (hcp.PHONE_AREA_CODE, '', '', hcp.PHONE_AREA_CODE || '-' || '') || hcp.PHONE_NUMBER || DECODE (hcp.PHONE_EXTENSION, '', '', '#' || hcp.PHONE_EXTENSION) --added for globalisation v2
                                                                                                                                                                                                                                                                                               Work_phone --,hcp.*
                  INTO v_contact_info
                  FROM apps.HZ_CONTACT_POINTS hcp
                 WHERE     hcp.owner_table_id = p_rel_party_id
                       AND hcp.status = 'A'
                       AND contact_point_type = 'PHONE'
                       AND hcp.PRIMARY_FLAG = 'Y'
                       AND hcp.phone_line_type NOT IN ('FAX', 'MOBILE');
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    v_contact_info   := NULL;
                WHEN OTHERS
                THEN
                    v_contact_info   := NULL;
            END;

            IF v_contact_info IS NULL
            THEN
                BEGIN
                    SELECT --DECODE (hcp.PHONE_COUNTRY_CODE, '', '', hcp.PHONE_COUNTRY_CODE || '-' || '') commented on 20Dec2010
                           DECODE (hcp.PHONE_COUNTRY_CODE, '', v_phone_country_code, '+' || hcp.PHONE_COUNTRY_CODE || '-' || '') || DECODE (hcp.PHONE_AREA_CODE, '', '', hcp.PHONE_AREA_CODE || '-' || '') || hcp.PHONE_NUMBER || DECODE (hcp.PHONE_EXTENSION, '', '', '#' || hcp.PHONE_EXTENSION) --added for globalisation v2
                                                                                                                                                                                                                                                                                                   Work_phone
                      INTO v_contact_info
                      FROM apps.HZ_CONTACT_POINTS hcp
                     WHERE     hcp.owner_table_id = p_rel_party_id
                           AND hcp.status = 'A'
                           AND contact_point_type = 'PHONE'
                           AND hcp.phone_line_type IN ('GEN', 'STORE')
                           AND hcp.last_update_date =
                               (SELECT MAX (last_update_date)
                                  FROM apps.HZ_CONTACT_POINTS
                                 WHERE     owner_table_id =
                                           hcp.owner_table_id
                                       AND status(+) = 'A'
                                       AND contact_point_type(+) = 'PHONE'
                                       AND phone_line_type IN
                                               ('GEN', 'STORE'));
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        v_contact_info   := NULL;
                    WHEN OTHERS
                    THEN
                        v_contact_info   := NULL;
                END;
            END IF;
        ELSE
            BEGIN
                SELECT DECODE (hcp.phone_line_type, p_line_type, --DECODE (hcp.PHONE_COUNTRY_CODE, '', '', hcp.PHONE_COUNTRY_CODE || '-' || '') commented ON 20Dec2010
                                                                 DECODE (hcp.PHONE_COUNTRY_CODE, '', v_phone_country_code, '+' || hcp.PHONE_COUNTRY_CODE || '-' || '') || DECODE (hcp.PHONE_AREA_CODE, '', '', hcp.PHONE_AREA_CODE || '-' || '') || hcp.PHONE_NUMBER || DECODE (hcp.PHONE_EXTENSION, '', '', '#' || hcp.PHONE_EXTENSION) --added for globalisation v2
                                                                                                                                                                                                                                                                                                                                        ) Work_phone
                  INTO v_contact_info
                  FROM apps.HZ_CONTACT_POINTS hcp
                 WHERE     hcp.owner_table_id = p_rel_party_id
                       AND DECODE (hcp.phone_line_type,
                                   p_line_type, hcp.PHONE_NUMBER)
                               IS NOT NULL
                       AND hcp.status = 'A'
                       AND contact_point_type = 'PHONE'
                       AND hcp.PRIMARY_FLAG = 'Y';
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    v_contact_info   := NULL;
                WHEN OTHERS
                THEN
                    v_contact_info   := NULL;
            END;

            IF v_contact_info IS NULL
            THEN
                BEGIN
                    SELECT DECODE (hcp.phone_line_type, p_line_type, --DECODE (hcp.PHONE_COUNTRY_CODE, '', '', hcp.PHONE_COUNTRY_CODE || '-' || '') commented on 20Dec2010
                                                                     DECODE (hcp.PHONE_COUNTRY_CODE, '', v_phone_country_code, '+' || hcp.PHONE_COUNTRY_CODE || '-' || '') || DECODE (hcp.PHONE_AREA_CODE, '', '', hcp.PHONE_AREA_CODE || '-' || '') || hcp.PHONE_NUMBER || DECODE (hcp.PHONE_EXTENSION, '', '', '#' || hcp.PHONE_EXTENSION) --added for globalisation v2
                                                                                                                                                                                                                                                                                                                                            ) Work_phone
                      INTO v_contact_info
                      FROM apps.HZ_CONTACT_POINTS hcp
                     WHERE     hcp.owner_table_id = p_rel_party_id
                           AND DECODE (hcp.phone_line_type,
                                       p_line_type, hcp.PHONE_NUMBER)
                                   IS NOT NULL
                           AND hcp.status = 'A'
                           AND contact_point_type = 'PHONE'
                           --and hcp.last_update_date = (select max(last_update_date) from apps.HZ_CONTACT_POINTS where owner_table_id = hcp.owner_table_id)

                           AND hcp.last_update_date =
                               (SELECT MAX (last_update_date)
                                  FROM apps.HZ_CONTACT_POINTS
                                 WHERE     owner_table_id =
                                           hcp.owner_table_id
                                       AND status(+) = 'A'
                                       AND contact_point_type(+) = 'PHONE'
                                       AND phone_line_type = p_line_type) /*

                                                                          and hcp.contact_point_id = (

                                                                          select max(contact_point_id) from apps.HZ_CONTACT_POINTS hcp

                                                                          where hcp.owner_table_id = p_rel_party_id

                                                                          and decode(hcp.phone_line_type,p_line_type,hcp.PHONE_NUMBER) is not null

                                                                          and hcp.status = 'A'

                                                                          and hcp.last_update_date = (select max(last_update_date) from apps.HZ_CONTACT_POINTS where owner_table_id = hcp.owner_table_id)

                                                                          )*/
                                                                         ;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        v_contact_info   := NULL;
                    WHEN OTHERS
                    THEN
                        v_contact_info   := NULL;
                END;
            END IF;
        END IF;

        RETURN v_contact_info;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;



    FUNCTION get_account_contact (p_party_id IN NUMBER, p_line_type IN VARCHAR2, p_country_code IN VARCHAR2)
        RETURN VARCHAR2
    IS
        v_contact_info         VARCHAR2 (2000);
        v_phone_country_code   VARCHAR2 (15);
    BEGIN
        BEGIN
            SELECT phone_country_code
              INTO v_phone_country_code
              FROM xxdood_ebscrm_country_code
             WHERE 1 = 1 AND ebs_short_name = p_country_code AND ROWNUM < 2;

            IF v_phone_country_code IS NOT NULL
            THEN
                v_phone_country_code   := '+' || v_phone_country_code || '-';
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                v_phone_country_code   := NULL;
        END;

        IF p_line_type = 'GEN'
        THEN
            BEGIN
                SELECT --decode(hcp.contact_point_type,'EMAIL','',decode(hcp.phone_line_type,'FAX','','STOREF','',decode(hcp.PHONE_COUNTRY_CODE,'','',hcp.PHONE_COUNTRY_CODE||'-'||'')||decode(hcp.PHONE_AREA_CODE,'','',hcp.PHONE_AREA_CODE||'-'||'')||hcp.PHONE_NUMBER)) main_phone
                       --decode(hcp.contact_point_type,'EMAIL','',decode(hcp.PHONE_COUNTRY_CODE,'','',hcp.PHONE_COUNTRY_CODE||'-'||'')||decode(hcp.PHONE_AREA_CODE,'','',hcp.PHONE_AREA_CODE||'-'||'')||hcp.PHONE_NUMBER) main_phone

                       --DECODE (hcp.PHONE_COUNTRY_CODE, '', '', hcp.PHONE_COUNTRY_CODE || '-' || '') commented on 20Dec2010
                       DECODE (hcp.PHONE_COUNTRY_CODE, '', v_phone_country_code, '+' || hcp.PHONE_COUNTRY_CODE || '-' || '') || DECODE (hcp.PHONE_AREA_CODE, '', '', hcp.PHONE_AREA_CODE || '-' || '') || hcp.PHONE_NUMBER || DECODE (hcp.PHONE_EXTENSION, '', '', '#' || hcp.PHONE_EXTENSION) --added for globalisation v2
                                                                                                                                                                                                                                                                                               main_phone
                  INTO v_contact_info
                  FROM apps.hz_contact_points hcp
                 WHERE                             -- contact_point_id = 12219
                           hcp.owner_table_id = p_party_id
                       AND hcp.status(+) = 'A'
                       AND hcp.primary_flag(+) = 'Y'
                       AND hcp.phone_line_type NOT IN ('FAX', 'STOREF')
                       AND hcp.contact_point_type(+) = 'PHONE';
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    v_contact_info   := NULL;
                WHEN OTHERS
                THEN
                    v_contact_info   := NULL;
            END;

            IF v_contact_info IS NULL
            THEN
                BEGIN
                    SELECT --decode(hcp.contact_point_type,'EMAIL','',decode(hcp.phone_line_type,'FAX','','STOREF','',decode(hcp.PHONE_COUNTRY_CODE,'','',hcp.PHONE_COUNTRY_CODE||'-'||'')||decode(hcp.PHONE_AREA_CODE,'','',hcp.PHONE_AREA_CODE||'-'||'')||hcp.PHONE_NUMBER)) main_phone
                           --decode(hcp.contact_point_type,'EMAIL','',decode(hcp.PHONE_COUNTRY_CODE,'','',hcp.PHONE_COUNTRY_CODE||'-'||'')||decode(hcp.PHONE_AREA_CODE,'','',hcp.PHONE_AREA_CODE||'-'||'')||hcp.PHONE_NUMBER) main_phone

                           --DECODE (hcp.PHONE_COUNTRY_CODE, '', '', hcp.PHONE_COUNTRY_CODE || '-' || '') commented on 20Dec2010
                           DECODE (hcp.PHONE_COUNTRY_CODE, '', v_phone_country_code, '+' || hcp.PHONE_COUNTRY_CODE || '-' || '') || DECODE (hcp.PHONE_AREA_CODE, '', '', hcp.PHONE_AREA_CODE || '-' || '') || hcp.PHONE_NUMBER || DECODE (hcp.PHONE_EXTENSION, '', '', '#' || hcp.PHONE_EXTENSION) --added for globalisation v2
                                                                                                                                                                                                                                                                                                   main_phone
                      INTO v_contact_info
                      FROM apps.hz_contact_points hcp
                     WHERE                         -- contact_point_id = 12219
                               hcp.owner_table_id = p_party_id
                           AND hcp.status(+) = 'A'
                           AND hcp.contact_point_type(+) = 'PHONE'
                           AND hcp.phone_line_type NOT IN ('FAX', 'STOREF')
                           AND hcp.last_update_date =
                               (SELECT MAX (last_update_date)
                                  FROM apps.hz_contact_points
                                 WHERE     owner_table_id =
                                           hcp.owner_table_id
                                       AND status(+) = 'A'
                                       AND contact_point_type(+) = 'PHONE'
                                       AND phone_line_type NOT IN
                                               ('FAX', 'STOREF'));
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        v_contact_info   := NULL;
                    WHEN OTHERS
                    THEN
                        v_contact_info   := NULL;
                END;
            END IF;
        ELSE
            BEGIN
                SELECT --decode(hcp.contact_point_type,'EMAIL','',decode(hcp.phone_line_type,'FAX',decode(hcp.PHONE_COUNTRY_CODE,'','',hcp.PHONE_COUNTRY_CODE||'-'||'')||decode(hcp.PHONE_AREA_CODE,'','',hcp.PHONE_AREA_CODE||'-'||'')||hcp.PHONE_NUMBER,'')) Main_fax
                       --decode(hcp.contact_point_type,'EMAIL','',decode(hcp.PHONE_COUNTRY_CODE,'','',hcp.PHONE_COUNTRY_CODE||'-'||'')||decode(hcp.PHONE_AREA_CODE,'','',hcp.PHONE_AREA_CODE||'-'||'')||hcp.PHONE_NUMBER) Main_fax

                       --DECODE (hcp.PHONE_COUNTRY_CODE, '', '', hcp.PHONE_COUNTRY_CODE || '-' || '') commented on 20Dec2010
                       DECODE (hcp.PHONE_COUNTRY_CODE, '', v_phone_country_code, '+' || hcp.PHONE_COUNTRY_CODE || '-' || '') || DECODE (hcp.PHONE_AREA_CODE, '', '', hcp.PHONE_AREA_CODE || '-' || '') || hcp.PHONE_NUMBER || DECODE (hcp.PHONE_EXTENSION, '', '', '#' || hcp.PHONE_EXTENSION) --added for globalisation v2
                                                                                                                                                                                                                                                                                               Main_fax
                  INTO v_contact_info
                  FROM apps.hz_contact_points hcp
                 WHERE                             -- contact_point_id = 12219
                           hcp.owner_table_id = p_party_id
                       AND hcp.status(+) = 'A'
                       AND hcp.primary_flag(+) = 'Y'
                       AND hcp.contact_point_type(+) = 'PHONE'
                       --and hcp.phone_line_type = 'FAX'

                       AND hcp.phone_line_type IN ('FAX', 'STOREF');
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    v_contact_info   := NULL;
                WHEN OTHERS
                THEN
                    v_contact_info   := NULL;
            END;

            IF v_contact_info IS NULL
            THEN
                BEGIN
                    SELECT --decode(hcp.contact_point_type,'EMAIL','',decode(hcp.phone_line_type,'FAX',decode(hcp.PHONE_COUNTRY_CODE,'','',hcp.PHONE_COUNTRY_CODE||'-'||'')||decode(hcp.PHONE_AREA_CODE,'','',hcp.PHONE_AREA_CODE||'-'||'')||hcp.PHONE_NUMBER,'')) Main_fax
                           --decode(hcp.contact_point_type,'EMAIL','',decode(hcp.PHONE_COUNTRY_CODE,'','',hcp.PHONE_COUNTRY_CODE||'-'||'')||decode(hcp.PHONE_AREA_CODE,'','',hcp.PHONE_AREA_CODE||'-'||'')||hcp.PHONE_NUMBER) Main_fax

                           --DECODE (hcp.PHONE_COUNTRY_CODE, '', '', hcp.PHONE_COUNTRY_CODE || '-' || '') commented on 20Dec2010
                           DECODE (hcp.PHONE_COUNTRY_CODE, '', v_phone_country_code, '+' || hcp.PHONE_COUNTRY_CODE || '-' || '') || DECODE (hcp.PHONE_AREA_CODE, '', '', hcp.PHONE_AREA_CODE || '-' || '') || hcp.PHONE_NUMBER || DECODE (hcp.PHONE_EXTENSION, '', '', '#' || hcp.PHONE_EXTENSION) --added for globalisation v2
                                                                                                                                                                                                                                                                                                   Main_fax
                      INTO v_contact_info
                      FROM apps.hz_contact_points hcp
                     WHERE                         -- contact_point_id = 12219
                               hcp.owner_table_id = p_party_id
                           AND hcp.status(+) = 'A'
                           AND hcp.contact_point_type(+) = 'PHONE'
                           --and hcp.phone_line_type = 'FAX'

                           AND hcp.phone_line_type IN ('FAX', 'STOREF')
                           --and hcp.last_update_date = (select max(last_update_date) from apps.hz_contact_points  where owner_table_id = hcp.owner_table_id and status(+) = 'A' and contact_point_type(+) = 'PHONE'  and phone_line_type = 'FAX')

                           AND hcp.last_update_date =
                               (SELECT MAX (last_update_date)
                                  FROM apps.hz_contact_points
                                 WHERE     owner_table_id =
                                           hcp.owner_table_id
                                       AND status(+) = 'A'
                                       AND contact_point_type(+) = 'PHONE'
                                       AND phone_line_type IN
                                               ('FAX', 'STOREF'));
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        v_contact_info   := NULL;
                    WHEN OTHERS
                    THEN
                        v_contact_info   := NULL;
                END;
            END IF;
        END IF;

        RETURN v_contact_info;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;



    FUNCTION get_contact_wp (p_rel_party_id IN NUMBER)
        RETURN VARCHAR2
    IS
        v_contact_info   VARCHAR2 (2000);

        CURSOR c1 IS
            SELECT DECODE (hcp.phone_line_type, 'GEN', DECODE (hcp.PHONE_COUNTRY_CODE, '', '', hcp.PHONE_COUNTRY_CODE || '-' || '') || DECODE (hcp.PHONE_AREA_CODE, '', '', hcp.PHONE_AREA_CODE || '-' || '') || hcp.PHONE_NUMBER) Work_phone
              FROM apps.HZ_CONTACT_POINTS hcp
             WHERE     hcp.owner_table_id = p_rel_party_id
                   AND DECODE (hcp.phone_line_type, 'GEN', hcp.PHONE_NUMBER)
                           IS NOT NULL
                   --and rownum <= 1

                   AND hcp.PRIMARY_FLAG = 'Y';
    BEGIN
        FOR r1 IN c1
        LOOP
            IF v_contact_info IS NOT NULL
            THEN
                v_contact_info   :=
                    v_contact_info || ' ,   ' || r1.Work_phone;
            ELSE
                v_contact_info   := r1.Work_phone;
            END IF;
        END LOOP;

        RETURN v_contact_info;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    FUNCTION get_contact_fx (p_rel_party_id IN NUMBER)
        RETURN VARCHAR2
    IS
        v_contact_info   VARCHAR2 (2000);

        CURSOR c1 IS
            SELECT DECODE (hcp.phone_line_type, 'FAX', DECODE (hcp.PHONE_COUNTRY_CODE, '', '', hcp.PHONE_COUNTRY_CODE || '-' || '') || DECODE (hcp.PHONE_AREA_CODE, '', '', hcp.PHONE_AREA_CODE || '-' || '') || hcp.PHONE_NUMBER) fax
              FROM apps.HZ_CONTACT_POINTS hcp
             WHERE     hcp.owner_table_id = p_rel_party_id
                   AND DECODE (hcp.phone_line_type, 'FAX', hcp.PHONE_NUMBER)
                           IS NOT NULL
                   --and rownum <= 1

                   AND hcp.PRIMARY_FLAG = 'Y';
    BEGIN
        FOR r1 IN c1
        LOOP
            IF v_contact_info IS NOT NULL
            THEN
                v_contact_info   := v_contact_info || ' ,   ' || r1.fax;
            ELSE
                v_contact_info   := r1.fax;
            END IF;
        END LOOP;

        RETURN v_contact_info;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    FUNCTION get_contact_mb (p_rel_party_id IN NUMBER)
        RETURN VARCHAR2
    IS
        v_contact_info   VARCHAR2 (2000);

        CURSOR c1 IS
            SELECT DECODE (hcp.phone_line_type, 'MOBILE', DECODE (hcp.PHONE_COUNTRY_CODE, '', '', hcp.PHONE_COUNTRY_CODE || '-' || '') || DECODE (hcp.PHONE_AREA_CODE, '', '', hcp.PHONE_AREA_CODE || '-' || '') || hcp.PHONE_NUMBER) CELL
              FROM apps.HZ_CONTACT_POINTS hcp
             WHERE     hcp.owner_table_id = p_rel_party_id
                   AND DECODE (hcp.phone_line_type,
                               'MOBILE', hcp.PHONE_NUMBER)
                           IS NOT NULL
                   --and rownum <= 1

                   AND hcp.PRIMARY_FLAG = 'Y';
    BEGIN
        FOR r1 IN c1
        LOOP
            IF v_contact_info IS NOT NULL
            THEN
                v_contact_info   := v_contact_info || ' ,   ' || r1.CELL;
            ELSE
                v_contact_info   := r1.CELL;
            END IF;
        END LOOP;

        RETURN v_contact_info;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    FUNCTION get_contact_email (p_rel_party_id IN NUMBER)
        RETURN VARCHAR2
    IS
        v_contact_info   VARCHAR2 (2000);

        CURSOR c1 IS
            SELECT hcp.EMAIL_ADDRESS email
              FROM apps.HZ_CONTACT_POINTS hcp
             WHERE     hcp.owner_table_id = p_rel_party_id
                   AND hcp.PRIMARY_FLAG = 'Y';
    BEGIN
        FOR r1 IN c1
        LOOP
            IF v_contact_info IS NOT NULL
            THEN
                v_contact_info   := v_contact_info || ' ,   ' || r1.email;
            ELSE
                v_contact_info   := r1.email;
            END IF;
        END LOOP;

        RETURN v_contact_info;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    FUNCTION get_contact_type (p_rel_party_id IN NUMBER)
        RETURN VARCHAR2
    IS
        v_contact_info   VARCHAR2 (2000);

        CURSOR c1 IS
            SELECT hcp.CONTACT_POINT_TYPE CONTACT_TYPE
              FROM apps.HZ_CONTACT_POINTS hcp
             WHERE hcp.owner_table_id = p_rel_party_id;
    BEGIN
        /*

        select customer_name

        into v_loc

        from ra_customers

        where customer_id = p_customer_id;

        */

        FOR r1 IN c1
        LOOP
            IF v_contact_info IS NOT NULL
            THEN
                v_contact_info   :=
                    v_contact_info || ' ,   ' || r1.contact_type;
            ELSE
                v_contact_info   := r1.contact_type;
            END IF;
        END LOOP;

        RETURN v_contact_info;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;



    FUNCTION get_dc_desc (p_lookup_code IN VARCHAR)
        RETURN VARCHAR2
    IS
        v_dc_desc   VARCHAR2 (120);
    BEGIN
        SELECT description
          INTO v_dc_desc
          FROM apps.fnd_lookup_values
         WHERE     lookup_type = 'DO_DISTRIBUTION_CHANNEL'
               AND lookup_code = p_lookup_code           -- in('SG','OS','FS')
               AND NVL (start_date_active, SYSDATE) <= SYSDATE + 1
               AND NVL (end_date_active, SYSDATE) >= SYSDATE
               AND NVL (enabled_flag, 'N') = 'Y'
               AND LANGUAGE = USERENV ('LANG');

        RETURN v_dc_desc;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    FUNCTION get_ship_method (p_party_id IN NUMBER)
        RETURN VARCHAR2
    IS
        v_ship_method   VARCHAR2 (120);
    BEGIN
        /*

        select

        hcsu.ship_via

        into

        v_ship_method

        from

         apps.hz_parties hp

        ,apps.hz_party_sites hps

        ,apps.hz_cust_acct_sites_all hcas

        ,apps.hz_cust_site_uses_all hcsu

        where 1=1

        and hps.party_id = hp.party_id

        and hcas.party_site_id = hps.party_site_id

        and hcsu.cust_acct_site_id = hcas.cust_acct_site_id

        and hcsu.primary_flag = 'Y'

        and hcsu.site_use_code = 'BILL_TO'

        and hp.party_id = p_party_id

        */
        SELECT hca.ship_via
          INTO v_ship_method
          FROM apps.hz_cust_accounts hca
         WHERE 1 = 1 AND hca.party_id = p_party_id;

        RETURN v_ship_method;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;
END XXDO_CRM_EXPORT_PKG;
/
