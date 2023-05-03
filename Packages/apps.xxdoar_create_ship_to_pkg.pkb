--
-- XXDOAR_CREATE_SHIP_TO_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:22 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOAR_CREATE_SHIP_TO_PKG"
AS
    /*******************************************************************************
       * Program Name : XXDOAR_CREATE_SHIP_TO_PKG
       * Language     : PL/SQL
       * Description  : This package will Loading Shipto Data from Staging - Deckers
       *
       * History      :
       *
       * WHO               WHAT              Desc                             WHEN
       * -------------- ---------------------------------------------- ---------------
       * BT Technology Team                                                NOV/18/2014
       * --------------------------------------------------------------------------- */
    PROCEDURE xxdo_update_stg
    IS
        CURSOR upd_county IS
            SELECT DISTINCT city, zip
              FROM xxdoar_load_ship_to_stg
             WHERE     1 = 1
                   AND NVL (processed_flag, 'N') = 'N'
                   AND city IS NOT NULL
                   AND zip IS NOT NULL
                   AND county IS NULL;

        v_county   VARCHAR2 (100) := NULL;
    BEGIN
        FOR i IN upd_county
        LOOP
            v_county   := NULL;

            BEGIN
                SELECT do_edi_utils_pub.get_county_name (i.city, i.zip)
                  INTO v_county
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Reason for Invalid Addresses for creating Site use Code');
            END;

            UPDATE xxdoar_load_ship_to_stg
               SET county   = v_county
             WHERE     1 = 1
                   AND NVL (processed_flag, 'N') = 'N'
                   AND city = i.city
                   AND zip = i.zip
                   AND county IS NULL;

            COMMIT;
        END LOOP;
    END xxdo_update_stg;

    PROCEDURE xxdo_create_ship_to (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, pv_file_loc IN VARCHAR2
                                   , pv_file_name IN VARCHAR2, pn_account IN NUMBER, pn_org IN NUMBER)
    IS
        CURSOR create_ship_to_cur IS
            SELECT DISTINCT dc_number, store_number, address_line1,
                            address_line2, loc_name, city,
                            state, county, zip,
                            location_id, customer_name, loc_info
              FROM xxdoar_load_ship_to_stg
             WHERE     1 = 1
                   AND NVL (processed_flag, 'N') = 'N'
                   AND status_code IS NULL
                   AND remark_loc IS NULL
                   AND remark_party_site IS NULL
                   AND remark_ship_to IS NULL
                   AND remarks_acct_site IS NULL;

        p_location_rec           hz_location_v2pub.location_rec_type;
        x_geometry               MDSYS.SDO_GEOMETRY; -- := hz_gaeometry_default;
        xa_location_id           NUMBER := 0;
        xa_return_status         VARCHAR2 (2000) := NULL;
        xa_msg_count             NUMBER := 0;
        xa_msg_data              VARCHAR2 (4000) := NULL;
        la_location_id           NUMBER := 0;
        p_party_site_rec         hz_party_site_v2pub.party_site_rec_type;
        lparty_id                NUMBER := 0;
        p_cust_acct_site_rec     hz_cust_account_site_v2pub.cust_acct_site_rec_type;
        lcust_id                 NUMBER := 0;
        xc_party_site_id         NUMBER := 0;
        xc_party_site_number     NUMBER := 0;
        xc_msg_count             NUMBER := 0;
        xc_msg_data              VARCHAR2 (4000) := NULL;
        xp_cust_acct_site_id     NUMBER := 0;
        xp_return_status         VARCHAR2 (2000) := NULL;
        xp_msg_count             NUMBER := 0;
        xp_msg_data              VARCHAR2 (4000) := NULL;
        p_cust_site_use_rec      hz_cust_account_site_v2pub.cust_site_use_rec_type;
        p_customer_profile_rec   hz_customer_profile_v2pub.customer_profile_rec_type;
        xsh_site_use_id          NUMBER := 0;
        xsh_return_status        VARCHAR2 (2000) := NULL;
        xsh_msg_count            NUMBER := 0;
        xsh_msg_data             VARCHAR2 (4000) := NULL;
        xc_return_status         VARCHAR2 (2000) := NULL;
        primary_flag             VARCHAR2 (2000) := NULL;
        l_addrcount              NUMBER := 0;
        l_partycount             NUMBER := 0;
        l_site_id                NUMBER := 0;
        l_site_use_id            NUMBER := 0;
        l_error_loc              VARCHAR2 (4000) := NULL;
        l_error_party            VARCHAR2 (4000) := NULL;
        l_error_account_site     VARCHAR2 (4000) := NULL;
        l_error_remarks          VARCHAR2 (4000) := NULL;
        l_error_remarks_ship     VARCHAR2 (4000) := NULL;
        l_wait                   BOOLEAN;
        l_phase                  VARCHAR2 (50);
        l_del_phase              VARCHAR2 (50);
        l_interval               NUMBER := 30;
        l_mal_wait               NUMBER := 1800;
        l_status                 VARCHAR2 (2000) := '';
        l_del_status             VARCHAR2 (2000) := '';
        l_message                VARCHAR2 (2000) := '';
        l_req_id1                NUMBER;
        v_counter                NUMBER := 0;
        v_loc_info               VARCHAR2 (100) := NULL;
        lv_party_name            VARCHAR2 (240) := NULL;
        lv_country               VARCHAR2 (10) := NULL;
    BEGIN
        BEGIN
            DELETE FROM xxdoar_load_ship_to_stg;

            COMMIT;
            --         IF (NVL (pv_validation, 'N') = 'Y')
            --         THEN
            l_req_id1     :=
                fnd_request.submit_request (
                    application   => 'XXDO',
                    program       => 'xxdoar_load_ship_to_stg',
                    description   => NULL,
                    start_time    => NULL,
                    sub_request   => FALSE,
                    argument1     =>
                           '/appdata/app/fs2/EBSapps/appl/xxdo/12.0.0/bin/'
                        --  '/home/oracle/'
                        -- || pv_file_loc
                        -- || '/apps/apps_st/appl/xxdo/12.0.0/bin/'
                        || pv_file_name
                        || '.csv',                        --i.organization_id,
                    argument2     => NULL,
                    argument3     => NULL);
            COMMIT;
            l_phase       := 'START';
            l_del_phase   := 'START';

            WHILE l_del_phase <> 'COMPLETE'
            LOOP
                l_wait   :=
                    fnd_concurrent.wait_for_request (l_req_id1,
                                                     l_interval,
                                                     l_mal_wait,
                                                     l_phase,
                                                     l_status,
                                                     l_del_phase,
                                                     l_del_status,
                                                     l_message);
            END LOOP;
        --END IF;
        END;

        fnd_file.put_line (fnd_file.LOG, 'Start of Updating Staging');
        xxdo_update_stg;

        BEGIN
            SELECT DISTINCT hrl.country
              INTO lv_country
              FROM xle_entity_profiles lep, xle_registrations reg, hr_locations_all hrl,
                   fnd_territories_vl ter, hr_operating_units hro, hr_all_organization_units_tl hroutl_bg,
                   hr_all_organization_units_tl hroutl_ou, hr_organization_units gloperatingunitseo
             WHERE     lep.transacting_entity_flag = 'Y'
                   AND lep.legal_entity_id = reg.source_id
                   AND reg.source_table = 'XLE_ENTITY_PROFILES'
                   AND hrl.location_id = reg.location_id
                   AND reg.identifying_flag = 'Y'
                   AND ter.territory_code = hrl.country
                   AND lep.legal_entity_id = hro.default_legal_context_id
                   AND gloperatingunitseo.organization_id =
                       hro.organization_id
                   AND hroutl_bg.organization_id = hro.business_group_id
                   AND hroutl_ou.organization_id = hro.organization_id
                   AND hro.organization_id = pn_org;

            fnd_file.put_line (
                fnd_file.LOG,
                'Country Name for the given OU: ' || lv_country);
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Country Name is not Found for the given OU: ' || pn_org);
                lv_country   := 'US';
        END;

        BEGIN
            SELECT hzp.party_name
              INTO lv_party_name
              FROM hz_cust_accounts hca, hz_parties hzp
             WHERE     hzp.party_id = hca.party_id
                   AND hca.cust_account_id = pn_account;

            fnd_file.put_line (fnd_file.LOG,
                               'Account Name: ' || lv_party_name);

            --AND    ROWNUM = 1;
            IF lv_party_name IS NOT NULL
            THEN
                UPDATE xxdoar_load_ship_to_stg
                   SET loc_info = loc_name || '-' || store_number, --dc_number || '-' || store_number || '-' || loc_name,
                                                                   customer_name = lv_party_name
                 WHERE loc_info IS NULL;

                COMMIT;
            END IF;

            FOR j IN create_ship_to_cur
            LOOP
                l_error_remarks        := NULL;
                l_error_party          := NULL;
                la_location_id         := 0;
                lparty_id              := 0;
                lcust_id               := 0;
                xa_return_status       := NULL;
                xp_return_status       := NULL;
                xc_return_status       := NULL;
                xsh_return_status      := NULL;
                l_addrcount            := 0;
                l_partycount           := 0;
                l_site_id              := 0;
                l_site_use_id          := 0;
                l_error_loc            := NULL;
                l_error_party          := NULL;
                l_error_account_site   := NULL;
                l_error_remarks        := NULL;
                l_error_remarks_ship   := NULL;
                v_loc_info             := NULL;

                IF LENGTH (j.loc_info) > 39
                THEN
                    v_loc_info   := REPLACE (j.loc_info, ' ', '');
                ELSE
                    v_loc_info   := j.loc_info;
                END IF;

                BEGIN
                    p_location_rec.address_effective_date   := SYSDATE;
                    p_location_rec.address1                 :=
                        j.address_line1;
                    p_location_rec.address2                 :=
                        j.address_line2;
                    --p_location_rec.address3 := j.loc_info;
                    p_location_rec.address_style            :=
                        'POSTAL_ADDR_US';
                    p_location_rec.city                     := j.city;
                    p_location_rec.state                    := j.state;
                    p_location_rec.county                   := j.county;
                    p_location_rec.country                  := lv_country; --'US';
                    p_location_rec.LANGUAGE                 := 'US';
                    p_location_rec.postal_code              := j.zip;
                    p_location_rec.created_by_module        := 'HZ_CPUI';

                    BEGIN
                        SELECT party_id
                          INTO lparty_id
                          FROM hz_parties
                         WHERE UPPER (party_name) = UPPER (j.customer_name);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Customer Doesnot exists: ' || j.customer_name);
                    END;

                    BEGIN
                        SELECT cust_account_id
                          INTO lcust_id
                          FROM hz_cust_accounts
                         WHERE party_id = lparty_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Customer Account Doesnot exists for : ' || j.customer_name);
                    END;

                    BEGIN
                        SELECT COUNT (1)
                          INTO l_addrcount
                          FROM hz_parties hzp, hz_party_sites party_site, hz_locations loc
                         WHERE     hzp.party_id = party_site.party_id
                               AND hzp.party_type = 'ORGANIZATION'
                               AND loc.location_id = party_site.location_id
                               AND hzp.party_name = UPPER (j.customer_name)
                               AND UPPER (loc.address1) =
                                   UPPER (j.address_line1)
                               AND UPPER (NVL (loc.address2, '@')) =
                                   UPPER (NVL (j.address_line2, '@'))
                               AND UPPER (NVL (loc.address3, '@')) =
                                   UPPER (NVL (j.loc_info, '@'))
                               AND UPPER (loc.city) = UPPER (j.city)
                               AND UPPER (loc.state) = UPPER (j.state)
                               AND UPPER (loc.postal_code) = UPPER (j.zip);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_addrcount   := 0;
                    END;

                    IF     l_addrcount = 0
                       AND lparty_id IS NOT NULL
                       AND lcust_id IS NOT NULL
                    THEN
                        SAVEPOINT a;
                        fnd_file.put_line (
                            fnd_file.LOG,
                            '1. Address doesnot exists, Hence Creating Location');
                        hz_location_v2pub.create_location ('T',
                                                           p_location_rec,
                                                           xa_location_id,
                                                           xa_return_status,
                                                           xa_msg_count,
                                                           xa_msg_data);
                        la_location_id   := xa_location_id;
                        --lparty_id := 142519598;
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Msg Data for Location creation: '
                            || SUBSTR (xa_msg_data, 1, 255));
                    -- fnd_file.put_line(fnd_file.log,'2. Address doesnot exists, created now and value of location_id is :'||la_location_id);
                    ELSIF     l_addrcount > 0
                          AND lparty_id IS NOT NULL
                          AND lcust_id IS NOT NULL
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            '2. Address Already Exists for the provided Details.. so no need');
                    END IF;

                    IF xa_msg_count > 0
                    THEN
                        FOR i IN 1 .. xa_msg_count
                        LOOP
                            --                  l_error_loc := l_error_loc|| ', '|| SUBSTR (fnd_msg_pub.get (p_encoded      => fnd_api.g_false),1,255);
                            l_error_loc   :=
                                   l_error_loc
                                || ', '
                                || SUBSTR (xa_msg_data, 1, 255);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error Infomration on Location1: '
                                || l_error_loc);
                        END LOOP;
                    END IF;

                    IF xa_return_status = 'S'
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               '3. Address - Location Created And Location Id is: '
                            || la_location_id);

                        UPDATE xxdoar_load_ship_to_stg
                           SET remark_loc   = 'SUCCESS'
                         WHERE     UPPER (customer_name) =
                                   UPPER (j.customer_name)
                               AND UPPER (address_line1) =
                                   UPPER (j.address_line1)
                               AND UPPER (NVL (address_line2, '@')) =
                                   UPPER (NVL (j.address_line2, '@'))
                               AND UPPER (NVL (loc_info, '@')) =
                                   UPPER (NVL (j.loc_info, '@'))
                               AND UPPER (NVL (city, '~~')) =
                                   UPPER (NVL (j.city, '~~'))
                               AND UPPER (NVL (state, '~~')) =
                                   UPPER (NVL (j.state, '~~'))
                               AND UPPER (NVL (zip, '~~')) =
                                   UPPER (NVL (j.zip, '~~'));
                    ELSIF xa_return_status IN ('E', 'U')
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            '4. Address - Location API Retuned Error');

                        UPDATE xxdoar_load_ship_to_stg
                           SET remark_loc   = SUBSTR (xa_msg_data, 1, 255)
                         --TRANSLATE (l_error_loc, CHR (10), ' ')
                         WHERE     UPPER (customer_name) =
                                   UPPER (j.customer_name)
                               AND UPPER (address_line1) =
                                   UPPER (j.address_line1)
                               AND UPPER (NVL (address_line2, '@')) =
                                   UPPER (NVL (j.address_line2, '@'))
                               AND UPPER (NVL (loc_info, '@')) =
                                   UPPER (NVL (j.loc_info, '@'))
                               AND UPPER (NVL (city, '~~')) =
                                   UPPER (NVL (j.city, '~~'))
                               AND UPPER (NVL (state, '~~')) =
                                   UPPER (NVL (j.state, '~~'))
                               AND UPPER (NVL (zip, '~~')) =
                                   UPPER (NVL (j.zip, '~~'));

                        ROLLBACK TO a;
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Exception Error exists in Customer Location creation :'
                            || SQLERRM);
                --l_error_remarks := l_error_remarks || ' ,' || SQLERRM;
                END;

                --Create a party site using party_id and Location_id
                BEGIN
                    IF xa_return_status = 'S'
                    THEN
                        BEGIN
                            SELECT COUNT (1)
                              INTO l_partycount
                              FROM hz_party_sites
                             WHERE     location_id = la_location_id
                                   AND party_id = lparty_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_partycount   := 0;
                        END;

                        IF l_partycount = 0
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                '5. Party Site doesnot exists, Hence Creating..');
                            p_party_site_rec.party_id            := lparty_id;
                            p_party_site_rec.location_id         := la_location_id;
                            --  p_party_site_rec.identifying_address_flag := primary_flag;
                            p_party_site_rec.created_by_module   := 'HZ_CPUI';
                            hz_party_site_v2pub.create_party_site (
                                'T',
                                p_party_site_rec,
                                xc_party_site_id,
                                xc_party_site_number,
                                xc_return_status,
                                xc_msg_count,
                                xc_msg_data);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Msg Data for Location creation: '
                                || SUBSTR (xc_msg_data, 1, 255));
                        ELSIF l_partycount > 0
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                '6. Party Site Already Exists for that Location');
                        END IF;

                        IF xc_msg_count > 0
                        THEN
                            FOR i IN 1 .. xc_msg_count
                            LOOP
                                --                     l_error_party := l_error_party|| ', '|| SUBSTR(fnd_msg_pub.get (p_encoded      => fnd_api.g_false),1,255);
                                l_error_party   :=
                                       l_error_party
                                    || ', '
                                    || SUBSTR (xc_msg_data, 1, 255);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Error Infomration on Party Site 1: '
                                    || l_error_party);
                            END LOOP;
                        END IF;

                        IF xc_return_status = 'S'
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   '7. Party Site Created is: '
                                || xc_party_site_id);

                            UPDATE xxdoar_load_ship_to_stg
                               SET remark_party_site   = 'SUCCESS'
                             WHERE     UPPER (customer_name) =
                                       UPPER (j.customer_name)
                                   AND UPPER (address_line1) =
                                       UPPER (j.address_line1)
                                   AND UPPER (NVL (address_line2, '@')) =
                                       UPPER (NVL (j.address_line2, '@'))
                                   AND UPPER (NVL (loc_info, '@')) =
                                       UPPER (NVL (j.loc_info, '@'))
                                   AND UPPER (NVL (city, '~~')) =
                                       UPPER (NVL (j.city, '~~'))
                                   AND UPPER (NVL (state, '~~')) =
                                       UPPER (NVL (j.state, '~~'))
                                   AND UPPER (NVL (zip, '~~')) =
                                       UPPER (NVL (j.zip, '~~'));
                        ELSIF xc_return_status IN ('E', 'U')
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                '8. Party Site API Returned Error');

                            UPDATE xxdoar_load_ship_to_stg
                               SET remark_party_site = SUBSTR (xc_msg_data, 1, 255)
                             --                                      TRANSLATE (l_error_party, CHR (10), ' ')
                             WHERE     UPPER (customer_name) =
                                       UPPER (j.customer_name)
                                   AND UPPER (address_line1) =
                                       UPPER (j.address_line1)
                                   AND UPPER (NVL (address_line2, '@')) =
                                       UPPER (NVL (j.address_line2, '@'))
                                   AND UPPER (NVL (loc_info, '@')) =
                                       UPPER (NVL (j.loc_info, '@'))
                                   AND UPPER (NVL (city, '~~')) =
                                       UPPER (NVL (j.city, '~~'))
                                   AND UPPER (NVL (state, '~~')) =
                                       UPPER (NVL (j.state, '~~'))
                                   AND UPPER (NVL (zip, '~~')) =
                                       UPPER (NVL (j.zip, '~~'));

                            ROLLBACK TO a;
                        END IF;
                    ELSE
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Location is not created, so no Party Site Info');
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Exception Error exists in Party Site creation :'
                            || SQLERRM);
                --               l_error_remarks := l_error_remarks || ' ,' || SQLERRM;
                END;

                --CREATE AN ACCOUNT SITE USING CUST_ACCOUNT_ID AND PARTY_SITE_ID
                BEGIN
                    IF xc_return_status = 'S'
                    THEN
                        BEGIN
                            -- lcust_id := 135065744;
                            SELECT COUNT (*)
                              INTO l_site_id
                              FROM hz_cust_acct_sites_all
                             WHERE     cust_account_id = lcust_id
                                   AND party_site_id = xc_party_site_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_site_id   := 0;
                        END;

                        IF l_site_id = 0
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                '9. ACCOUNT SITE Information doesnot exists, Hence Creating..');
                            p_cust_acct_site_rec.cust_account_id   :=
                                lcust_id;
                            p_cust_acct_site_rec.party_site_id   :=
                                xc_party_site_id;
                            p_cust_acct_site_rec.created_by_module   :=
                                'HZ_CPUI';
                            p_cust_acct_site_rec.status       := 'A';
                            p_cust_acct_site_rec.org_id       := pn_org;
                            p_cust_acct_site_rec.attribute2   :=
                                j.store_number;
                            p_cust_acct_site_rec.attribute5   := j.dc_number;
                            hz_cust_account_site_v2pub.create_cust_acct_site (
                                p_init_msg_list        => fnd_api.g_true,
                                p_cust_acct_site_rec   => p_cust_acct_site_rec,
                                x_cust_acct_site_id    => xp_cust_acct_site_id,
                                x_return_status        => xp_return_status,
                                x_msg_count            => xp_msg_count,
                                x_msg_data             => xp_msg_data);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Msg Data for Location creation: '
                                || SUBSTR (xp_msg_data, 1, 255));
                        ELSIF l_site_id > 0
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                '10. Account Site Already Exists for that Location');
                        END IF;

                        IF xp_msg_count > 0
                        THEN
                            FOR i IN 1 .. xp_msg_count
                            LOOP
                                --                     l_error_account_site :=l_error_account_site|| ', '|| SUBSTR(fnd_msg_pub.get (p_encoded      => fnd_api.g_false), 1,255);
                                l_error_account_site   :=
                                       l_error_account_site
                                    || ', '
                                    || SUBSTR (xp_msg_data, 1, 255);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Error Infomration on Account Site 1: '
                                    || l_error_account_site);
                            END LOOP;
                        END IF;

                        IF xp_return_status = 'S'
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   '11. Cust Site Created is: '
                                || xp_cust_acct_site_id);

                            UPDATE xxdoar_load_ship_to_stg
                               SET remarks_acct_site   = 'SUCCESS'
                             WHERE     UPPER (customer_name) =
                                       UPPER (j.customer_name)
                                   AND UPPER (address_line1) =
                                       UPPER (j.address_line1)
                                   AND UPPER (NVL (address_line2, '@')) =
                                       UPPER (NVL (j.address_line2, '@'))
                                   AND UPPER (NVL (loc_info, '@')) =
                                       UPPER (NVL (j.loc_info, '@'))
                                   AND UPPER (NVL (city, '~~')) =
                                       UPPER (NVL (j.city, '~~'))
                                   AND UPPER (NVL (state, '~~')) =
                                       UPPER (NVL (j.state, '~~'))
                                   AND UPPER (NVL (zip, '~~')) =
                                       UPPER (NVL (j.zip, '~~'));
                        ELSIF xp_return_status IN ('E', 'U')
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                '12. Cust Site API Returned Error');

                            UPDATE xxdoar_load_ship_to_stg
                               SET remarks_acct_site = SUBSTR (xp_msg_data, 1, 255)
                             --TRANSLATE (l_error_account_site, CHR (10), ' ')
                             WHERE     UPPER (customer_name) =
                                       UPPER (j.customer_name)
                                   AND UPPER (address_line1) =
                                       UPPER (j.address_line1)
                                   AND UPPER (NVL (address_line2, '@')) =
                                       UPPER (NVL (j.address_line2, '@'))
                                   AND UPPER (NVL (loc_info, '@')) =
                                       UPPER (NVL (j.loc_info, '@'))
                                   AND UPPER (NVL (city, '~~')) =
                                       UPPER (NVL (j.city, '~~'))
                                   AND UPPER (NVL (state, '~~')) =
                                       UPPER (NVL (j.state, '~~'))
                                   AND UPPER (NVL (zip, '~~')) =
                                       UPPER (NVL (j.zip, '~~'));

                            ROLLBACK TO a;
                        END IF;
                    ELSE
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'party_site_id is not created, so no Accounting Site Info');
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Exception Error exists in Cust Site creation :'
                            || SQLERRM);
                --               l_error_remarks := l_error_remarks || ' ,' || SQLERRM;
                END;

                -- CREATE AN ACCOUNT SITE USE 'SHIP_TO' using CUST_ACCT_SITE_ID
                BEGIN
                    IF xp_return_status = 'S'
                    THEN
                        BEGIN
                            SELECT COUNT (*)
                              INTO l_site_use_id
                              FROM hz_cust_site_uses_all
                             WHERE     cust_acct_site_id =
                                       xp_cust_acct_site_id
                                   AND site_use_code = 'SHIP_TO';
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_site_use_id   := 0;
                        END;

                        IF l_site_use_id = 0
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Assigning Site use code to Accounting Info');
                            p_cust_site_use_rec.cust_acct_site_id   :=
                                xp_cust_acct_site_id;
                            p_cust_site_use_rec.site_use_code   := 'SHIP_TO';
                            p_cust_site_use_rec.LOCATION        :=
                                SUBSTR (v_loc_info, 1, 40);
                            --SUBSTR (j.loc_info, 1, 40);  --la_location_id;
                            p_cust_site_use_rec.gl_id_rec       := NULL;
                            p_cust_site_use_rec.gl_id_rev       := NULL;
                            p_cust_site_use_rec.gl_id_freight   := NULL;
                            --p_cust_site_use_rec.primary_flag := 'Y';
                            p_cust_site_use_rec.created_by_module   :=
                                'HZ_CPUI';
                            hz_cust_account_site_v2pub.create_cust_site_use (
                                'T',
                                p_cust_site_use_rec,
                                p_customer_profile_rec,
                                fnd_api.g_true,
                                '',
                                xsh_site_use_id,
                                xsh_return_status,
                                xsh_msg_count,
                                xsh_msg_data);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Msg Data for Location creation: '
                                || SUBSTR (xsh_msg_data, 1, 255));
                        ELSIF l_site_use_id > 0
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                '10. Account Site Already Exists for that Location');
                        END IF;

                        IF xsh_msg_count > 0
                        THEN
                            FOR i IN 1 .. xsh_msg_count
                            LOOP
                                --                     l_error_remarks_ship :=l_error_remarks_ship|| ', '|| SUBSTR (fnd_msg_pub.get (p_encoded      => fnd_api.g_false),1,255);
                                l_error_remarks_ship   :=
                                       l_error_remarks_ship
                                    || ', '
                                    || SUBSTR (xsh_msg_data, 1, 255);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Error Infomration on Site Use Code 1: '
                                    || l_error_remarks_ship);
                            END LOOP;
                        END IF;

                        IF xsh_return_status = 'S'
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                '13. Site Use code is Assigned');

                            UPDATE xxdoar_load_ship_to_stg
                               SET remark_ship_to = 'SUCCESS', processed_flag = 'Y', status_code = 'SUCCESS'
                             WHERE     UPPER (customer_name) =
                                       UPPER (j.customer_name)
                                   AND UPPER (address_line1) =
                                       UPPER (j.address_line1)
                                   AND UPPER (NVL (address_line2, '@')) =
                                       UPPER (NVL (j.address_line2, '@'))
                                   AND UPPER (NVL (loc_info, '@')) =
                                       UPPER (NVL (j.loc_info, '@'))
                                   AND UPPER (NVL (city, '~~')) =
                                       UPPER (NVL (j.city, '~~'))
                                   AND UPPER (NVL (state, '~~')) =
                                       UPPER (NVL (j.state, '~~'))
                                   AND UPPER (NVL (zip, '~~')) =
                                       UPPER (NVL (j.zip, '~~'));

                            COMMIT;
                        ELSIF xsh_return_status IN ('E', 'U')
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                '14. Site Use code API Returned Error');

                            UPDATE xxdoar_load_ship_to_stg
                               SET remark_ship_to = SUBSTR (xsh_msg_data, 1, 255), --TRANSLATE (l_error_remarks_ship, CHR (10), ' '),
                                                                                   processed_flag = 'Y', status_code = 'ERROR'
                             WHERE     UPPER (customer_name) =
                                       UPPER (j.customer_name)
                                   AND UPPER (address_line1) =
                                       UPPER (j.address_line1)
                                   AND UPPER (NVL (address_line2, '@')) =
                                       UPPER (NVL (j.address_line2, '@'))
                                   AND UPPER (NVL (loc_info, '@')) =
                                       UPPER (NVL (j.loc_info, '@'))
                                   AND UPPER (NVL (city, '~~')) =
                                       UPPER (NVL (j.city, '~~'))
                                   AND UPPER (NVL (state, '~~')) =
                                       UPPER (NVL (j.state, '~~'))
                                   AND UPPER (NVL (zip, '~~')) =
                                       UPPER (NVL (j.zip, '~~'));

                            --row_id = j.row_id;
                            ROLLBACK TO a;
                        END IF;
                    ELSE
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Account Site is not created, so no Site Use Code');
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Exception Error exists in SITE USE CODE creation :'
                            || SQLERRM);
                --               l_error_remarks := l_error_remarks || ' ,' || SQLERRM;
                END;

                v_counter              := v_counter + 1;
            END LOOP;

            fnd_file.put_line (fnd_file.LOG,
                               'Processed no.of records are :' || v_counter);
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'The Customer Doesnot exists for the given Account: '
                    || pn_account);
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, '2 Final' || SQLERRM);
    END xxdo_create_ship_to;
END xxdoar_create_ship_to_pkg;
/
