--
-- XXDOEC_AR_CUSTOMER_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:08 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOEC_AR_CUSTOMER_PKG"
AS
    -- =======================================================
    -- Author:      Vijay Reddy
    -- Create date: 10/18/2010
    -- Description: This package is used to interface customers
    --              and their addresses from DW to Oracle
    -- =======================================================
    -- Modification History
    -- Modified Date/By/Description:
    -- <MODIFYING DATE, VERSION    MODIFYING AUTHOR, Change Description>
    -----------------------------------------------------------------------------------------------------------------------------------------
    -- 11/10/2011,              Vijay Reddy,     Added code to derive province name to compare with
    --                                      existing addresses in EBS
    -- 10/29/2011,              Vijay Reddy,     Modified to add NVL check for city, state, zip code
    --                                      of Bill to, Ship to addresses in validate_cust_addresses
    -- 07/18/2011,              Vijay Reddy,     Added Province, email address to address rec
    --
    -- 05-DEC-2014       1.0    Infosys        Modified for BT.
    --
    -- 21-MAY-2015       1.1    Infosys        Modified for a CR in BTUAT to populate DISTRIBUTION CHANNEL for Ecommerce customers.
    -----------------------------------------------------------------------------------------------------------------------------------------

    -- =======================================================
    -- Sample Execution
    -- =======================================================
    -- G_PACKAGE_TITLE     CONSTANT VARCHAR2(30) := 'doec_ar_customer_pkg';
    G_PACKAGE_TITLE       CONSTANT VARCHAR2 (30) := 'DOEC_AR_CUSTOMER_PKG'; -- 1.0 : Modified for BT.

    G_CREATED_BY_MODULE   CONSTANT VARCHAR2 (30) := 'HZ_WS';

    PROCEDURE msg (MESSAGE VARCHAR2, debug_level NUMBER:= 100)
    IS
    BEGIN
        do_debug_tools.msg (MESSAGE, debug_level);
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END msg;

    PROCEDURE validate_cust_addresses (p_customer_number IN VARCHAR2, p_bill_to_address_rec IN address_rec_type, p_ship_to_address_rec IN address_rec_type, x_customer_id OUT NUMBER, x_bill_to_site_use_id OUT NUMBER, x_ship_to_site_use_id OUT NUMBER
                                       , x_addresses_match OUT BOOLEAN, x_return_status OUT VARCHAR2, x_error_text OUT VARCHAR2)
    IS
        l_province_name   VARCHAR2 (120);

        CURSOR c_province_name (c_province_code IN VARCHAR2)
        IS
            SELECT geography_name
              FROM hz_geographies geo
             WHERE     geo.geography_type = 'PROVINCE'
                   AND geo.country_code = 'CA'
                   AND geography_code = c_province_code;

        CURSOR c_cust_exists IS
            SELECT cust_account_id
              FROM hz_cust_accounts hca
             WHERE     hca.account_number = p_customer_number
                   AND NVL (status, 'A') = 'A';

        CURSOR c_bill_to_exists (c_customer_id IN NUMBER)
        IS
            SELECT hcsu.site_use_id
              FROM hz_cust_accounts hca, hz_locations hl, hz_party_sites hps,
                   hz_cust_acct_sites_all hcas, hz_cust_site_uses_all hcsu
             WHERE     hca.cust_account_id = c_customer_id
                   AND NVL (hca.status, 'A') = 'A'
                   AND UPPER (REPLACE (hl.address1, ' ', NULL)) =
                       UPPER (
                           REPLACE (p_bill_to_address_rec.address1,
                                    ' ',
                                    NULL))
                   AND NVL (UPPER (REPLACE (hl.address2, ' ', NULL)), '~') =
                       NVL (
                           UPPER (
                               REPLACE (p_bill_to_address_rec.address2,
                                        ' ',
                                        NULL)),
                           '~')
                   AND NVL (UPPER (REPLACE (hl.address3, ' ', NULL)), '~') =
                       NVL (
                           UPPER (
                               REPLACE (p_bill_to_address_rec.address3,
                                        ' ',
                                        NULL)),
                           '~')
                   AND NVL (UPPER (REPLACE (hl.city, ' ', NULL)), '~') =
                       NVL (
                           UPPER (
                               REPLACE (p_bill_to_address_rec.city,
                                        ' ',
                                        NULL)),
                           '~')
                   AND NVL (UPPER (REPLACE (hl.state, ' ', NULL)), '~') =
                       NVL (
                           UPPER (
                               REPLACE (p_bill_to_address_rec.state,
                                        ' ',
                                        NULL)),
                           '~')
                   AND NVL (UPPER (REPLACE (hl.province, ' ', NULL)), '~') =
                       NVL (UPPER (REPLACE (l_province_name, ' ', NULL)),
                            '~')
                   AND NVL (UPPER (REPLACE (hl.postal_code, ' ', NULL)), '~') =
                       NVL (
                           UPPER (
                               REPLACE (p_bill_to_address_rec.postal_code,
                                        ' ',
                                        NULL)),
                           '~')
                   AND UPPER (REPLACE (hl.country, ' ', NULL)) =
                       UPPER (
                           REPLACE (p_bill_to_address_rec.country, ' ', NULL))
                   AND hps.party_id = hca.party_id
                   AND hps.location_id = hl.location_id
                   AND NVL (hps.status, 'A') = 'A'
                   AND hcas.cust_account_id = hca.cust_account_id
                   AND hcas.party_site_id = hps.party_site_id
                   AND NVL (hcas.status, 'A') = 'A'
                   AND hcsu.cust_acct_site_id = hcas.cust_acct_site_id
                   AND hcsu.site_use_code = 'BILL_TO'
                   AND NVL (hcsu.status, 'A') = 'A';

        CURSOR c_ship_to_exists (c_customer_id IN NUMBER)
        IS
            SELECT hcsu.site_use_id
              FROM hz_cust_accounts hca, hz_locations hl, hz_party_sites hps,
                   hz_cust_acct_sites_all hcas, hz_cust_site_uses_all hcsu
             WHERE     hca.cust_account_id = c_customer_id
                   AND NVL (hca.status, 'A') = 'A'
                   AND UPPER (REPLACE (hl.address1, ' ', NULL)) =
                       UPPER (
                           REPLACE (p_ship_to_address_rec.address1,
                                    ' ',
                                    NULL))
                   AND NVL (UPPER (REPLACE (hl.address2, ' ', NULL)), '~') =
                       NVL (
                           UPPER (
                               REPLACE (p_ship_to_address_rec.address2,
                                        ' ',
                                        NULL)),
                           '~')
                   AND NVL (UPPER (REPLACE (hl.address3, ' ', NULL)), '~') =
                       NVL (
                           UPPER (
                               REPLACE (p_ship_to_address_rec.address3,
                                        ' ',
                                        NULL)),
                           '~')
                   AND NVL (UPPER (REPLACE (hl.city, ' ', NULL)), '~') =
                       NVL (
                           UPPER (
                               REPLACE (p_ship_to_address_rec.city,
                                        ' ',
                                        NULL)),
                           '~')
                   AND NVL (UPPER (REPLACE (hl.state, ' ', NULL)), '~') =
                       NVL (
                           UPPER (
                               REPLACE (p_ship_to_address_rec.state,
                                        ' ',
                                        NULL)),
                           '~')
                   AND NVL (UPPER (REPLACE (hl.province, ' ', NULL)), '~') =
                       NVL (UPPER (REPLACE (l_province_name, ' ', NULL)),
                            '~')
                   AND NVL (UPPER (REPLACE (hl.postal_code, ' ', NULL)), '~') =
                       NVL (
                           UPPER (
                               REPLACE (p_ship_to_address_rec.postal_code,
                                        ' ',
                                        NULL)),
                           '~')
                   AND UPPER (REPLACE (hl.country, ' ', NULL)) =
                       UPPER (
                           REPLACE (p_ship_to_address_rec.country, ' ', NULL))
                   AND hps.party_id = hca.party_id
                   AND hps.location_id = hl.location_id
                   AND NVL (hps.status, 'A') = 'A'
                   AND hcas.cust_account_id = hca.cust_account_id
                   AND hcas.party_site_id = hps.party_site_id
                   AND NVL (hcas.status, 'A') = 'A'
                   AND hcsu.cust_acct_site_id = hcas.cust_acct_site_id
                   AND hcsu.site_use_code = 'SHIP_TO'
                   AND NVL (hcsu.status, 'A') = 'A';
    BEGIN
        -- Check if customer exists.
        OPEN c_cust_exists;

        FETCH c_cust_exists INTO x_customer_id;

        CLOSE c_cust_exists;

        -- Derive BILL-TO province name.
        IF p_bill_to_address_rec.province IS NOT NULL
        THEN
            OPEN c_province_name (p_bill_to_address_rec.province);

            FETCH c_province_name INTO l_province_name;

            IF c_province_name%NOTFOUND
            THEN
                CLOSE c_province_name;

                l_province_name   := p_bill_to_address_rec.province;
            ELSE
                CLOSE c_province_name;
            END IF;
        ELSE
            l_province_name   := NULL;
        END IF;

        -- Check if BILL-TO exists.
        OPEN c_bill_to_exists (x_customer_id);

        FETCH c_bill_to_exists INTO x_bill_to_site_use_id;

        CLOSE c_bill_to_exists;

        -- Derive SHIP-TO province name.
        IF p_ship_to_address_rec.province IS NOT NULL
        THEN
            OPEN c_province_name (p_ship_to_address_rec.province);

            FETCH c_province_name INTO l_province_name;

            IF c_province_name%NOTFOUND
            THEN
                CLOSE c_province_name;

                l_province_name   := p_ship_to_address_rec.province;
            ELSE
                CLOSE c_province_name;
            END IF;
        ELSE
            l_province_name   := NULL;
        END IF;

        -- Check if SHIP_TO exists.
        OPEN c_ship_to_exists (x_customer_id);

        FETCH c_ship_to_exists INTO x_ship_to_site_use_id;

        CLOSE c_ship_to_exists;

        --Check if  BILL-TO , SHIP-TO addresses match.
        IF     UPPER (REPLACE (p_bill_to_address_rec.address1, ' ', NULL)) =
               UPPER (REPLACE (p_ship_to_address_rec.address1, ' ', NULL))
           AND NVL (
                   UPPER (
                       REPLACE (p_bill_to_address_rec.address2, ' ', NULL)),
                   '~') =
               NVL (
                   UPPER (
                       REPLACE (p_ship_to_address_rec.address2, ' ', NULL)),
                   '~')
           AND NVL (
                   UPPER (
                       REPLACE (p_bill_to_address_rec.address3, ' ', NULL)),
                   '~') =
               NVL (
                   UPPER (
                       REPLACE (p_ship_to_address_rec.address3, ' ', NULL)),
                   '~')
           AND NVL (UPPER (REPLACE (p_bill_to_address_rec.city, ' ', NULL)),
                    '~') =
               NVL (UPPER (REPLACE (p_ship_to_address_rec.city, ' ', NULL)),
                    '~')
           AND NVL (UPPER (REPLACE (p_bill_to_address_rec.state, ' ', NULL)),
                    '~') =
               NVL (UPPER (REPLACE (p_ship_to_address_rec.state, ' ', NULL)),
                    '~')
           AND NVL (
                   UPPER (
                       REPLACE (p_bill_to_address_rec.province, ' ', NULL)),
                   '~') =
               NVL (
                   UPPER (
                       REPLACE (p_ship_to_address_rec.province, ' ', NULL)),
                   '~')
           AND NVL (
                   UPPER (
                       REPLACE (p_bill_to_address_rec.postal_code, ' ', NULL)),
                   '~') =
               NVL (
                   UPPER (
                       REPLACE (p_ship_to_address_rec.postal_code, ' ', NULL)),
                   '~')
           AND UPPER (REPLACE (p_bill_to_address_rec.country, ' ', NULL)) =
               UPPER (REPLACE (p_ship_to_address_rec.country, ' ', NULL))
        THEN
            x_addresses_match   := TRUE;
        ELSE
            x_addresses_match   := FALSE;
        END IF;

        x_return_status   := FND_API.G_RET_STS_SUCCESS;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_return_status   := FND_API.G_RET_STS_UNEXP_ERROR;
            x_error_text      :=
                'Validate Cust Addresses failed with Error: ' || SQLERRM;
    END validate_cust_addresses;

    PROCEDURE create_cust_account (p_customer_rec IN customer_rec_type, p_created_by_module IN VARCHAR2, x_ret_status OUT VARCHAR2, x_ret_msg_data OUT VARCHAR2, x_cust_account_id OUT NUMBER, x_account_number OUT VARCHAR2
                                   , x_party_id OUT NUMBER, x_party_number OUT VARCHAR2, x_profile_id OUT NUMBER)
    IS
        l_cust_account_rec       HZ_CUST_ACCOUNT_V2PUB.CUST_ACCOUNT_REC_TYPE;
        l_person_rec             HZ_PARTY_V2PUB.PERSON_REC_TYPE;
        l_customer_profile_rec   HZ_CUSTOMER_PROFILE_V2PUB.CUSTOMER_PROFILE_REC_TYPE;

        p_contact_point_rec      HZ_CONTACT_POINT_V2PUB.contact_point_rec_type
            := NULL;
        p_phone_rec              HZ_CONTACT_POINT_V2PUB.phone_rec_type
            := HZ_CONTACT_POINT_V2PUB.g_miss_phone_rec;
        p_edi_rec                HZ_CONTACT_POINT_V2PUB.edi_rec_type;
        p_email_rec              HZ_CONTACT_POINT_V2PUB.email_rec_type
            := HZ_CONTACT_POINT_V2PUB.g_miss_email_rec;
        p_telex_rec              HZ_CONTACT_POINT_V2PUB.telex_rec_type;
        p_web_rec                HZ_CONTACT_POINT_V2PUB.web_rec_type;

        l_phone_contact_id       NUMBER;
        l_email_contact_id       NUMBER;
        l_msg_count              NUMBER;
        l_msg_data               VARCHAR2 (2000);
        l_msg_index_out          NUMBER;
        -- 1.0 : Start : Added for BT.
        lv_brand                 VARCHAR2 (150);
        lv_demand_class          VARCHAR2 (150);
    -- 1.0 : End : Added for BT.
    BEGIN
        x_ret_status                             := FND_API.G_RET_STS_SUCCESS;

        l_cust_account_rec.account_name          :=
            p_customer_rec.first_name || ' ' || p_customer_rec.last_name;
        l_cust_account_rec.account_number        := p_customer_rec.customer_number;
        --  l_cust_account_rec.attribute1         := '0.00'; -- Commission: Teva    -- 1.0 : Commented for BT.
        --  l_cust_account_rec.attribute3         := '0.00'; -- Commission: Simple    -- 1.0 : Commented for BT.
        l_cust_account_rec.attribute3            := 'Internet / Catalog'; -- Distribution Channel for Ecommerce customers.    -- 1.1 : Added for BT in UAT.
        --  l_cust_account_rec.attribute4         := '0.00'; -- Commission: UGG        -- 1.0 : Commented for BT.
        l_cust_account_rec.attribute5            := 'N'; -- Put on - Past Cancel Hold
        l_cust_account_rec.attribute6            := 'Y'; -- Zero Freight Customer
        l_cust_account_rec.attribute9            := '00'; -- EDI Print Flag (ASN/EDI Inv)
        --  l_cust_account_rec.attribute10        := 'N'; -- Print SO Acknowledgement        -- 1.0 : Commented for BT.
        l_cust_account_rec.attribute14           := 'N'; -- Auto Generate ASN            -- 1.0 : Added for BT.
        l_cust_account_rec.attribute7            := '0'; -- Sales Order Ack Trans Method    -- 1.0 : Added for BT.
        l_cust_account_rec.attribute_category    := 'Person';
        l_cust_account_rec.attribute17           := p_customer_rec.language;
        l_cust_account_rec.attribute18           := p_customer_rec.web_site_id;
        l_cust_account_rec.created_by_module     :=
            NVL (p_created_by_module, G_CREATED_BY_MODULE);

        l_person_rec.person_first_name           := p_customer_rec.first_name;
        l_person_rec.person_last_name            := p_customer_rec.last_name;
        l_person_rec.person_middle_name          := p_customer_rec.middle_name;
        l_person_rec.person_pre_name_adjunct     := p_customer_rec.title;
        l_person_rec.created_by_module           :=
            NVL (p_created_by_module, G_CREATED_BY_MODULE);
        -- 1.0 : Start : Modified for BT.

        lv_brand                                 := NULL;
        lv_demand_class                          := NULL;

        BEGIN
            SELECT ffv.ATTRIBUTE1, ffv.ATTRIBUTE2
              INTO lv_brand, lv_demand_class
              FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv
             WHERE     ffvs.flex_value_set_id = ffv.flex_value_set_id
                   AND flex_value_set_name = 'XXDO_ECOMM_WEB_SITES'
                   AND flex_Value = p_customer_rec.web_site_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_brand          := NULL;
                lv_demand_class   := NULL;
                x_ret_status      := FND_API.G_RET_STS_ERROR;
                x_ret_msg_data    :=
                       'Value-Set XXDO_ECOMM_WEB_SITES does not have an entry for website : '
                    || p_customer_rec.web_site_id
                    || '. Error : '
                    || SQLERRM;
        END;

        l_cust_account_rec.attribute13           := lv_demand_class;
        l_cust_account_rec.sales_channel_code    := 'E-COMMERCE';
        l_cust_account_rec.customer_class_code   := 'ECOMMERCE'; -- 'E-COMMERCE';
        l_cust_account_rec.attribute1            := lv_brand;

        -- 1.0 : End : Modified for BT.

        hz_cust_account_v2pub.create_cust_account (p_init_msg_list => 'T', p_cust_account_rec => l_cust_account_rec, p_person_rec => l_person_rec, p_customer_profile_rec => l_customer_profile_rec, p_create_profile_amt => 'F', x_cust_account_id => x_cust_account_id, x_account_number => x_account_number, x_party_id => x_party_id, x_party_number => x_party_number, x_profile_id => x_profile_id, x_return_status => x_ret_status, x_msg_count => l_msg_count
                                                   , x_msg_data => l_msg_data);


        IF x_ret_status <> FND_API.G_RET_STS_SUCCESS AND l_msg_count > 0
        THEN
            FOR i IN 1 .. l_msg_count
            LOOP
                fnd_msg_pub.get (p_msg_index => i, p_encoded => Fnd_Api.G_FALSE, p_data => l_msg_data
                                 , p_msg_index_out => l_msg_index_out);
                x_ret_msg_data   :=
                    SUBSTR (x_ret_msg_data || l_msg_data || CHR (13),
                            1,
                            2000);
                DBMS_OUTPUT.put_line (
                       'HZ_CUST_ACCOUNT_V2PUB. CREATE_CUST_ACCOUNT : '
                    || x_ret_msg_data);
            END LOOP;
        END IF;

        IF p_customer_rec.phone_number IS NOT NULL
        THEN
            -- Create phone contact point.
            p_contact_point_rec.contact_point_type   := 'PHONE';
            p_contact_point_rec.owner_table_name     := 'HZ_PARTIES';
            p_contact_point_rec.owner_table_id       := x_party_id;
            p_contact_point_rec.created_by_module    :=
                NVL (p_created_by_module, G_CREATED_BY_MODULE);
            p_phone_rec.Phone_number                 :=
                p_customer_rec.phone_number;
            p_phone_rec.phone_line_type              := 'GEN';

            HZ_CONTACT_POINT_V2PUB.create_contact_point (
                p_init_msg_list       => 'T',
                p_contact_point_rec   => p_contact_point_rec,
                p_edi_rec             => p_edi_rec,
                p_email_rec           => p_email_rec,
                p_phone_rec           => p_phone_rec,
                p_telex_rec           => p_telex_rec,
                p_web_rec             => p_web_rec,
                x_contact_point_id    => l_phone_contact_id,
                x_return_status       => x_ret_status,
                x_msg_count           => l_msg_count,
                x_msg_data            => l_msg_data);

            IF x_ret_status <> FND_API.G_RET_STS_SUCCESS AND l_msg_count > 0
            THEN
                FOR i IN 1 .. l_msg_count
                LOOP
                    fnd_msg_pub.get (p_msg_index => i, p_encoded => Fnd_Api.G_FALSE, p_data => l_msg_data
                                     , p_msg_index_out => l_msg_index_out);
                    x_ret_msg_data   :=
                        SUBSTR (x_ret_msg_data || l_msg_data || CHR (13),
                                1,
                                2000);
                END LOOP;
            END IF;
        END IF;

        IF p_customer_rec.email_address IS NOT NULL
        THEN
            -- create email contact point
            p_contact_point_rec                      := NULL;
            p_phone_rec                              := HZ_CONTACT_POINT_V2PUB.g_miss_phone_rec;
            p_contact_point_rec.contact_point_type   := 'EMAIL';
            p_contact_point_rec.owner_table_name     := 'HZ_PARTIES';
            p_contact_point_rec.owner_table_id       := x_party_id;
            p_contact_point_rec.created_by_module    :=
                NVL (p_created_by_module, G_CREATED_BY_MODULE);
            p_email_rec.email_address                :=
                p_customer_rec.email_address;

            HZ_CONTACT_POINT_V2PUB.create_contact_point (
                p_init_msg_list       => 'T',
                p_contact_point_rec   => p_contact_point_rec,
                p_edi_rec             => p_edi_rec,
                p_email_rec           => p_email_rec,
                p_phone_rec           => p_phone_rec,
                p_telex_rec           => p_telex_rec,
                p_web_rec             => p_web_rec,
                x_contact_point_id    => l_email_contact_id,
                x_return_status       => x_ret_status,
                x_msg_count           => l_msg_count,
                x_msg_data            => l_msg_data);

            IF x_ret_status <> FND_API.G_RET_STS_SUCCESS AND l_msg_count > 0
            THEN
                FOR i IN 1 .. l_msg_count
                LOOP
                    fnd_msg_pub.get (p_msg_index => i, p_encoded => Fnd_Api.G_FALSE, p_data => l_msg_data
                                     , p_msg_index_out => l_msg_index_out);
                    x_ret_msg_data   :=
                        SUBSTR (x_ret_msg_data || l_msg_data || CHR (13),
                                1,
                                2000);
                END LOOP;
            END IF;
        END IF;
    END create_cust_account;

    PROCEDURE create_site_use (
        p_cust_acct_site_id     IN     NUMBER,
        p_location_name         IN     VARCHAR2,
        p_site_use_code         IN     VARCHAR2,
        p_bill_to_site_use_id   IN     NUMBER DEFAULT NULL,
        p_created_by_module     IN     VARCHAR2,
        x_ret_status               OUT VARCHAR2,
        x_msg_data                 OUT VARCHAR2,
        x_site_use_id              OUT NUMBER)
    IS
        l_cust_site_use_rec      HZ_CUST_ACCOUNT_SITE_V2PUB.CUST_SITE_USE_REC_TYPE;
        l_customer_profile_rec   HZ_CUSTOMER_PROFILE_V2PUB.CUSTOMER_PROFILE_REC_TYPE;

        l_msg_count              NUMBER;
        l_msg_data               VARCHAR2 (2000);
        l_msg_index_out          NUMBER;
    BEGIN
        x_ret_status                              := FND_API.G_RET_STS_SUCCESS;

        l_cust_site_use_rec.cust_acct_site_id     := p_cust_acct_site_id;
        l_cust_site_use_rec.site_use_code         := p_site_use_code;
        l_cust_site_use_rec.location              := p_location_name;
        l_cust_site_use_rec.bill_to_site_use_id   := p_bill_to_site_use_id;
        l_cust_site_use_rec.created_by_module     :=
            NVL (p_created_by_module, G_CREATED_BY_MODULE);

        hz_cust_account_site_v2pub.create_cust_site_use (
            p_init_msg_list          => 'T',
            p_cust_site_use_rec      => l_cust_site_use_rec,
            p_customer_profile_rec   => l_customer_profile_rec,
            p_create_profile         => FND_API.G_FALSE,
            p_create_profile_amt     => FND_API.G_FALSE,
            x_site_use_id            => x_site_use_id,
            x_return_status          => x_ret_status,
            x_msg_count              => l_msg_count,
            x_msg_data               => l_msg_data);

        IF x_ret_status <> FND_API.G_RET_STS_SUCCESS AND l_msg_count > 0
        THEN
            FOR i IN 1 .. l_msg_count
            LOOP
                fnd_msg_pub.get (p_msg_index => i, p_encoded => Fnd_Api.G_FALSE, p_data => l_msg_data
                                 , p_msg_index_out => l_msg_index_out);
                x_msg_data   :=
                    SUBSTR (x_msg_data || l_msg_data || CHR (13), 1, 2000);
            END LOOP;
        END IF;
    END create_site_use;

    PROCEDURE create_cust_site_contact (p_party_site_id IN NUMBER, p_phone_number IN VARCHAR2, p_email_address IN VARCHAR2, p_created_by_module IN VARCHAR2, x_ret_status OUT VARCHAR2, x_msg_data OUT VARCHAR2
                                        , x_contact_point_id OUT NUMBER)
    IS
        p_contact_point_rec   HZ_CONTACT_POINT_V2PUB.contact_point_rec_type
                                  := NULL;
        p_phone_rec           HZ_CONTACT_POINT_V2PUB.phone_rec_type
                                  := HZ_CONTACT_POINT_V2PUB.g_miss_phone_rec;
        p_edi_rec             HZ_CONTACT_POINT_V2PUB.edi_rec_type;
        p_email_rec           HZ_CONTACT_POINT_V2PUB.email_rec_type;
        p_telex_rec           HZ_CONTACT_POINT_V2PUB.telex_rec_type;
        p_web_rec             HZ_CONTACT_POINT_V2PUB.web_rec_type;

        l_contact_point_id    NUMBER := NULL;
        l_msg_count           NUMBER;
        l_msg_data            VARCHAR2 (2000);
        l_msg_index_out       NUMBER;
    BEGIN
        x_ret_status   := FND_API.G_RET_STS_SUCCESS;

        IF p_phone_number IS NOT NULL
        THEN
            -- create phone contact point
            p_contact_point_rec.contact_point_type   := 'PHONE';
            p_contact_point_rec.owner_table_name     := 'HZ_PARTY_SITES';
            p_contact_point_rec.owner_table_id       := p_party_site_id;
            p_contact_point_rec.created_by_module    :=
                NVL (p_created_by_module, G_CREATED_BY_MODULE);
            p_phone_rec.Phone_number                 := p_phone_number;
            p_phone_rec.phone_line_type              := 'GEN';
            --
            HZ_CONTACT_POINT_V2PUB.create_contact_point (
                p_init_msg_list       => 'T',
                p_contact_point_rec   => p_contact_point_rec,
                p_edi_rec             => p_edi_rec,
                p_email_rec           => p_email_rec,
                p_phone_rec           => p_phone_rec,
                p_telex_rec           => p_telex_rec,
                p_web_rec             => p_web_rec,
                x_contact_point_id    => l_contact_point_id,
                x_return_status       => x_ret_status,
                x_msg_count           => l_msg_count,
                x_msg_data            => l_msg_data);

            IF x_ret_status <> FND_API.G_RET_STS_SUCCESS AND l_msg_count > 0
            THEN
                FOR i IN 1 .. l_msg_count
                LOOP
                    fnd_msg_pub.get (p_msg_index => i, p_encoded => Fnd_Api.G_FALSE, p_data => l_msg_data
                                     , p_msg_index_out => l_msg_index_out);
                    x_msg_data   :=
                        SUBSTR (x_msg_data || l_msg_data || CHR (13),
                                1,
                                2000);
                END LOOP;
            ELSE
                x_contact_point_id   := l_contact_point_id;
            END IF;
        END IF;

        IF p_email_address IS NOT NULL
        THEN
            -- create email contact point
            p_contact_point_rec                      := NULL;
            p_phone_rec                              := HZ_CONTACT_POINT_V2PUB.g_miss_phone_rec;
            p_contact_point_rec.contact_point_type   := 'EMAIL';
            p_contact_point_rec.owner_table_name     := 'HZ_PARTY_SITES';
            p_contact_point_rec.owner_table_id       := p_party_site_id;
            p_contact_point_rec.created_by_module    :=
                NVL (p_created_by_module, G_CREATED_BY_MODULE);
            p_email_rec.email_address                := p_email_address;

            HZ_CONTACT_POINT_V2PUB.create_contact_point (
                p_init_msg_list       => 'T',
                p_contact_point_rec   => p_contact_point_rec,
                p_edi_rec             => p_edi_rec,
                p_email_rec           => p_email_rec,
                p_phone_rec           => p_phone_rec,
                p_telex_rec           => p_telex_rec,
                p_web_rec             => p_web_rec,
                x_contact_point_id    => l_contact_point_id,
                x_return_status       => x_ret_status,
                x_msg_count           => l_msg_count,
                x_msg_data            => l_msg_data);

            IF x_ret_status <> FND_API.G_RET_STS_SUCCESS AND l_msg_count > 0
            THEN
                FOR i IN 1 .. l_msg_count
                LOOP
                    fnd_msg_pub.get (p_msg_index => i, p_encoded => Fnd_Api.G_FALSE, p_data => l_msg_data
                                     , p_msg_index_out => l_msg_index_out);
                    x_msg_data   :=
                        SUBSTR (x_msg_data || l_msg_data || CHR (13),
                                1,
                                2000);
                END LOOP;
            END IF;
        END IF;
    END create_cust_site_contact;

    PROCEDURE update_customer_email (p_customer_number IN VARCHAR2, p_new_email_address IN VARCHAR2, x_return_status OUT VARCHAR2
                                     , x_return_msg OUT VARCHAR2)
    AS
        l_cp_rec              hz_contact_point_v2pub.contact_point_rec_type;
        l_email_rec           hz_contact_point_v2pub.email_rec_type;
        l_cp_object_ver_num   hz_contact_points.object_version_number%TYPE;
        l_msg_count           NUMBER;
        l_msg_data            VARCHAR2 (2000);

        CURSOR c_email_contact IS
            SELECT hcp.contact_point_id, hcp.object_version_number
              FROM apps.hz_cust_accounts hca, hz_contact_points hcp
             WHERE     hca.account_number = p_customer_number
                   AND hcp.owner_table_name = 'HZ_PARTIES'
                   AND hcp.owner_table_id = hca.party_id
                   AND hcp.contact_point_type = 'EMAIL'
                   AND hcp.status = 'A'
                   AND hcp.primary_flag = 'Y';
    BEGIN
        l_cp_rec              := NULL;
        l_email_rec           := hz_contact_point_v2pub.g_miss_email_rec;
        l_cp_object_ver_num   := NULL;

        OPEN c_email_contact;

        FETCH c_email_contact INTO l_cp_rec.contact_point_id, l_cp_object_ver_num;

        IF c_email_contact%NOTFOUND
        THEN
            CLOSE c_email_contact;

            x_return_status   := fnd_api.G_RET_STS_ERROR;
            x_return_msg      :=
                'Invalid Customer Number: ' || p_customer_number;
        ELSE
            CLOSE c_email_contact;

            l_email_rec.email_address   := p_new_email_address;
            hz_contact_point_v2pub.update_email_contact_point (
                p_init_msg_list           => 'T',
                p_contact_point_rec       => l_cp_rec,
                p_email_rec               => l_email_rec,
                p_object_version_number   => l_cp_object_ver_num,
                x_return_status           => x_return_status,
                x_msg_count               => l_msg_count,
                x_msg_data                => x_return_msg);

            IF     x_return_status <> fnd_api.G_RET_STS_SUCCESS
               AND l_msg_count > 1
            THEN
                FOR i IN 1 .. l_msg_count
                LOOP
                    l_msg_data     := i || '. ' || fnd_msg_pub.get (i, 'F');
                    x_return_msg   := x_return_msg || l_msg_data;
                END LOOP;
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_return_status   := fnd_api.G_RET_STS_UNEXP_ERROR;
            x_return_msg      := SQLERRM;
    END update_customer_email;

    PROCEDURE create_cust_site_use (p_customer_rec IN customer_rec_type, p_bill_to_address_rec IN address_rec_type, p_ship_to_address_rec IN address_rec_type, p_tax_code IN VARCHAR2, p_gl_id_rev IN NUMBER, p_created_by_module IN VARCHAR2 DEFAULT NULL, --BEGIN Flexfields
                                                                                                                                                                                                                                                            p_store_number IN VARCHAR2 DEFAULT NULL, p_dc_number IN VARCHAR2 DEFAULT NULL, p_distro_customer_name IN VARCHAR2 DEFAULT NULL, p_ec_non_ec_country IN VARCHAR2 DEFAULT NULL, p_dealer_locator_eligible IN VARCHAR2 DEFAULT NULL, p_sales_region IN VARCHAR2 DEFAULT NULL, p_edi_enabled_flag IN VARCHAR2 DEFAULT NULL, --END Flexfields
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    x_customer_id OUT NUMBER, x_bill_to_site_use_id OUT NUMBER
                                    , x_ship_to_site_use_id OUT NUMBER, x_return_status OUT VARCHAR2, x_error_text OUT VARCHAR2)
    IS
        l_customer_id             NUMBER;
        l_party_site_id           NUMBER;
        l_cust_acct_site_id       NUMBER;
        l_bill_to_site_use_id     NUMBER;
        l_ship_to_site_use_id     NUMBER;
        l_account_number          VARCHAR2 (120);
        l_party_id                NUMBER;
        l_party_number            VARCHAR2 (120);
        l_profile_id              NUMBER;
        l_addresses_match         BOOLEAN;
        l_bill_to_contact_id      NUMBER;
        l_ship_to_contact_id      NUMBER;
        l_use_created_by_module   VARCHAR2 (240);
        ex_cust_info_missing      EXCEPTION;

        CURSOR c_cust_acct_site_id (c_site_use_id IN NUMBER)
        IS
            SELECT hcsu.cust_acct_site_id, hcas.party_site_id
              FROM hz_cust_site_uses_all hcsu, hz_cust_acct_sites_all hcas
             WHERE     hcas.cust_acct_site_id = hcsu.cust_acct_site_id
                   AND hcsu.site_use_id = c_site_use_id;
    BEGIN
        msg (MESSAGE       => '+' || G_PACKAGE_TITLE || '.create_cust_site_use',
             debug_level   => 100);
        msg (
            MESSAGE       =>
                   '  Cust First Name: '
                || NVL (p_customer_rec.first_name, '--none--'),
            debug_level   => 100);
        msg (
            MESSAGE       =>
                   '  Cust Last Name: '
                || NVL (p_customer_rec.last_name, '--none--'),
            debug_level   => 100);
        msg (
            MESSAGE       =>
                   '  Custmer Number: '
                || NVL (p_customer_rec.customer_number, '--none--'),
            debug_level   => 100);

        fnd_msg_pub.initialize;
        l_use_created_by_module   :=
            NVL (p_created_by_module, G_CREATED_BY_MODULE);

        l_customer_id           := NULL;
        l_party_site_id         := NULL;
        l_cust_acct_site_id     := NULL;
        l_bill_to_site_use_id   := NULL;
        l_ship_to_site_use_id   := NULL;
        l_addresses_match       := FALSE;
        l_bill_to_contact_id    := NULL;
        l_ship_to_contact_id    := NULL;
        x_return_status         := FND_API.G_RET_STS_SUCCESS;

        validate_cust_addresses (
            p_customer_number       => p_customer_rec.customer_number,
            p_bill_to_address_rec   => p_bill_to_address_rec,
            p_ship_to_address_rec   => p_ship_to_address_rec,
            x_customer_id           => l_customer_id,
            x_bill_to_site_use_id   => l_bill_to_site_use_id,
            x_ship_to_site_use_id   => l_ship_to_site_use_id,
            x_addresses_match       => l_addresses_match,
            x_return_status         => x_return_status,
            x_error_text            => x_error_text);

        IF l_customer_id IS NULL
        THEN
            -- Customer doesn't exists, new customer account needs to be created
            IF    p_customer_rec.first_name IS NULL
               OR p_customer_rec.last_name IS NULL
               OR p_customer_rec.customer_number IS NULL
            THEN
                msg (
                    MESSAGE       =>
                        'Customer First/Last name or Number is missing',
                    debug_level   => 100);
                RAISE ex_cust_info_missing;
            ELSE
                create_cust_account (
                    p_customer_rec        => p_customer_rec,
                    p_created_by_module   => l_use_created_by_module,
                    x_ret_status          => x_return_status,
                    x_ret_msg_data        => x_error_text,
                    x_cust_account_id     => l_customer_id,
                    x_account_number      => l_account_number,
                    x_party_id            => l_party_id,
                    x_party_number        => l_party_number,
                    x_profile_id          => l_profile_id);
                DBMS_OUTPUT.put_line (
                    'After CREATE_CUST_ACCOUNT : ' || x_return_status);

                IF x_return_status <> FND_API.G_RET_STS_SUCCESS
                THEN
                    l_customer_id   := NULL;
                    msg (
                        MESSAGE       =>
                               'Customer Account creation failed with Error: '
                            || x_error_text,
                        debug_level   => 100);
                ELSE
                    x_customer_id   := l_customer_id;
                    msg (
                        MESSAGE       =>
                            'Customer Account creation completed Successfully ',
                        debug_level   => 100);
                END IF;
            END IF;                             -- Customer info missing check
        ELSE
            -- Customer already exists
            x_customer_id   := l_customer_id;
            msg (MESSAGE       => 'Customer Account already exists ',
                 debug_level   => 100);
        END IF;

        -- Create Bill To address and site Use
        IF     l_customer_id IS NOT NULL
           AND p_bill_to_address_rec.address1 IS NOT NULL
        THEN
            IF l_bill_to_site_use_id IS NULL
            THEN
                DO_AR_CUSTOMER_UTILS.CREATE_SITE_USE_GL (
                    p_customer_id               => l_customer_id,
                    p_location_name             => p_bill_to_address_rec.location_name,
                    p_address1                  => p_bill_to_address_rec.address1,
                    p_address2                  => p_bill_to_address_rec.address2,
                    p_address3                  => p_bill_to_address_rec.address3,
                    p_city                      => p_bill_to_address_rec.city,
                    p_state                     => p_bill_to_address_rec.state,
                    p_province                  => p_bill_to_address_rec.province,
                    p_postal_code               => p_bill_to_address_rec.postal_code,
                    p_country                   => p_bill_to_address_rec.country,
                    p_tax_code                  => p_tax_code,
                    p_site_use_code             => 'BILL_TO',
                    p_bill_to_site_use_id       => NULL,
                    p_created_by_module         => l_use_created_by_module,
                    p_gl_id_rev                 => p_gl_id_rev,
                    --BEGIN Flexfields
                    p_store_number              => p_store_number,
                    p_dc_number                 => p_dc_number,
                    p_distro_customer_name      => p_distro_customer_name,
                    p_ec_non_ec_country         => p_ec_non_ec_country,
                    p_dealer_locator_eligible   => p_dealer_locator_eligible,
                    p_sales_region              => p_sales_region,
                    p_edi_enabled_flag          => p_edi_enabled_flag,
                    --END Flexfields
                    x_site_use_id               => l_bill_to_site_use_id,
                    x_return_status             => x_return_status,
                    x_error_text                => x_error_text);

                IF x_return_status <> FND_API.G_RET_STS_SUCCESS
                THEN
                    msg (
                        MESSAGE       =>
                               'Customer Bill To Address, Site Use creation failed with Error: '
                            || x_error_text,
                        debug_level   => 100);
                    x_bill_to_site_use_id   := NULL;
                ELSE
                    msg (
                        MESSAGE       =>
                            'Customer Bill To Address, Site Use creation completed Successfully.',
                        debug_level   => 100);
                    x_bill_to_site_use_id   := l_bill_to_site_use_id;

                    IF    p_bill_to_address_rec.phone_number IS NOT NULL
                       OR p_bill_to_address_rec.email_address IS NOT NULL
                    THEN
                        -- create bill to contact phone and/or email
                        OPEN c_cust_acct_site_id (l_bill_to_site_use_id);

                        FETCH c_cust_acct_site_id INTO l_cust_acct_site_id, l_party_site_id;

                        CLOSE c_cust_acct_site_id;

                        create_cust_site_contact (
                            p_party_site_id       => l_party_site_id,
                            p_phone_number        =>
                                p_bill_to_address_rec.phone_number,
                            p_email_address       =>
                                p_bill_to_address_rec.email_address,
                            p_created_by_module   => l_use_created_by_module,
                            x_ret_status          => x_return_status,
                            x_msg_data            => x_error_text,
                            x_contact_point_id    => l_bill_to_contact_id);

                        IF x_return_status <> FND_API.G_RET_STS_SUCCESS
                        THEN
                            l_bill_to_contact_id   := NULL;
                            msg (
                                MESSAGE       =>
                                       'Bill To Contact Phone creation failed with Error: '
                                    || x_error_text,
                                debug_level   => 100);
                        ELSE
                            msg (
                                MESSAGE       =>
                                    'Bill To Contact Phone creation completed Successfully',
                                debug_level   => 100);
                        END IF;
                    END IF;                    -- BILL TO Phone not null check
                END IF;                    -- BILL TO site return status check
            ELSE
                -- BILL TO already exists
                msg (MESSAGE       => 'Customer Bill To Site Use already exists',
                     debug_level   => 100);
                x_bill_to_site_use_id   := l_bill_to_site_use_id;
            END IF;
        END IF;

        IF     l_bill_to_site_use_id IS NOT NULL
           AND p_ship_to_address_rec.address1 IS NOT NULL
        THEN
            -- Create SHIP TO address and site Use.
            IF l_ship_to_site_use_id IS NULL
            THEN
                IF NOT l_addresses_match
                THEN
                    DO_AR_CUSTOMER_UTILS.CREATE_SITE_USE_GL (
                        p_customer_id               => l_customer_id,
                        p_location_name             =>
                            p_ship_to_address_rec.location_name,
                        p_address1                  => p_ship_to_address_rec.address1,
                        p_address2                  => p_ship_to_address_rec.address2,
                        p_address3                  => p_ship_to_address_rec.address3,
                        p_city                      => p_ship_to_address_rec.city,
                        p_state                     => p_ship_to_address_rec.state,
                        p_province                  => p_ship_to_address_rec.province,
                        p_postal_code               => p_ship_to_address_rec.postal_code,
                        p_country                   => p_ship_to_address_rec.country,
                        p_tax_code                  => p_tax_code,
                        p_site_use_code             => 'SHIP_TO',
                        p_bill_to_site_use_id       => l_bill_to_site_use_id,
                        p_created_by_module         => l_use_created_by_module,
                        p_gl_id_rev                 => NULL,
                        --BEGIN Flexfields
                        p_store_number              => p_store_number,
                        p_dc_number                 => p_dc_number,
                        p_distro_customer_name      => p_distro_customer_name,
                        p_ec_non_ec_country         => p_ec_non_ec_country,
                        p_dealer_locator_eligible   =>
                            p_dealer_locator_eligible,
                        p_sales_region              => p_sales_region,
                        p_edi_enabled_flag          => p_edi_enabled_flag,
                        --END Flexfields
                        x_site_use_id               => l_ship_to_site_use_id,
                        x_return_status             => x_return_status,
                        x_error_text                => x_error_text);

                    IF x_return_status <> FND_API.G_RET_STS_SUCCESS
                    THEN
                        msg (
                            MESSAGE       =>
                                   'Customer Ship To Address, Site Use creation failed with Error: '
                                || x_error_text,
                            debug_level   => 100);
                        x_ship_to_site_use_id   := NULL;
                    ELSE
                        msg (
                            MESSAGE       =>
                                'Customer Ship To Address, Site Use creation completed Sccessfully',
                            debug_level   => 100);
                        x_ship_to_site_use_id   := l_ship_to_site_use_id;

                        IF    p_ship_to_address_rec.phone_number IS NOT NULL
                           OR p_ship_to_address_rec.email_address IS NOT NULL
                        THEN
                            -- create ship to contact phone and/or email
                            OPEN c_cust_acct_site_id (l_ship_to_site_use_id);

                            FETCH c_cust_acct_site_id
                                INTO l_cust_acct_site_id, l_party_site_id;

                            CLOSE c_cust_acct_site_id;

                            create_cust_site_contact (
                                p_party_site_id       => l_party_site_id,
                                p_phone_number        =>
                                    p_ship_to_address_rec.phone_number,
                                p_email_address       =>
                                    p_ship_to_address_rec.email_address,
                                p_created_by_module   =>
                                    l_use_created_by_module,
                                x_ret_status          => x_return_status,
                                x_msg_data            => x_error_text,
                                x_contact_point_id    => l_ship_to_contact_id);

                            IF x_return_status <> FND_API.G_RET_STS_SUCCESS
                            THEN
                                l_ship_to_contact_id   := NULL;
                                msg (
                                    MESSAGE       =>
                                           'Ship To Contact Phone creation failed with Error: '
                                        || x_error_text,
                                    debug_level   => 100);
                            ELSE
                                msg (
                                    MESSAGE       =>
                                        'Ship To Contact Phone creation completed Successfully',
                                    debug_level   => 100);
                            END IF;
                        END IF;                -- ship to phone not null check
                    END IF;                -- ship to site Return status check
                ELSE
                    -- ship to, bill to addresses match
                    -- just create ship to site use, no need to create actual address
                    OPEN c_cust_acct_site_id (l_bill_to_site_use_id);

                    FETCH c_cust_acct_site_id INTO l_cust_acct_site_id, l_party_site_id;

                    CLOSE c_cust_acct_site_id;

                    create_site_use (
                        p_cust_acct_site_id     => l_cust_acct_site_id,
                        p_location_name         =>
                            p_ship_to_address_rec.location_name,
                        p_site_use_code         => 'SHIP_TO',
                        p_bill_to_site_use_id   => l_bill_to_site_use_id,
                        p_created_by_module     => l_use_created_by_module,
                        x_site_use_id           => l_ship_to_site_use_id,
                        x_ret_status            => x_return_status,
                        x_msg_data              => x_error_text);

                    IF x_return_status <> FND_API.G_RET_STS_SUCCESS
                    THEN
                        msg (
                            MESSAGE       =>
                                   'Customer Ship To Site Use creation failed with Error: '
                                || x_error_text,
                            debug_level   => 100);
                        x_ship_to_site_use_id   := NULL;
                    ELSE
                        msg (
                            MESSAGE       =>
                                'Customer Ship To Site Use creation completed Sccessfully',
                            debug_level   => 100);
                        x_ship_to_site_use_id   := l_ship_to_site_use_id;

                        IF    (p_ship_to_address_rec.phone_number IS NOT NULL AND p_ship_to_address_rec.phone_number <> NVL (p_bill_to_address_rec.phone_number, '~'))
                           OR (p_ship_to_address_rec.email_address IS NOT NULL AND p_ship_to_address_rec.email_address <> NVL (p_bill_to_address_rec.email_address, '~'))
                        THEN
                            -- Create SHIP TO contact phone and/or email.
                            OPEN c_cust_acct_site_id (l_ship_to_site_use_id);

                            FETCH c_cust_acct_site_id
                                INTO l_cust_acct_site_id, l_party_site_id;

                            CLOSE c_cust_acct_site_id;

                            create_cust_site_contact (
                                p_party_site_id       => l_party_site_id,
                                p_phone_number        =>
                                    p_ship_to_address_rec.phone_number,
                                p_email_address       =>
                                    p_ship_to_address_rec.email_address,
                                p_created_by_module   =>
                                    l_use_created_by_module,
                                x_ret_status          => x_return_status,
                                x_msg_data            => x_error_text,
                                x_contact_point_id    => l_ship_to_contact_id);

                            IF x_return_status <> FND_API.G_RET_STS_SUCCESS
                            THEN
                                l_ship_to_contact_id   := NULL;
                                msg (
                                    MESSAGE       =>
                                           'SHIP TO Contact Phone creation2 failed with Error: '
                                        || x_error_text,
                                    debug_level   => 100);
                            ELSE
                                msg (
                                    MESSAGE       =>
                                        'Ship To Contact Phone creation2 completed Successfully',
                                    debug_level   => 100);
                            END IF;
                        END IF;                -- Ship to Phone not null check
                    END IF;                -- ship to Site Return status check
                END IF;                               -- addresses match check
            ELSE
                msg (MESSAGE       => 'Customer Ship To Site Use already exists',
                     debug_level   => 100);
                x_ship_to_site_use_id   := l_ship_to_site_use_id;
            END IF;                            -- Ship to already exists check
        END IF;
    EXCEPTION
        WHEN ex_cust_info_missing
        THEN
            x_return_status   := FND_API.G_RET_STS_ERROR;
            x_error_text      :=
                'The Customer Last/First name or Number is missing.';
        WHEN OTHERS
        THEN
            x_return_status   := FND_API.G_RET_STS_UNEXP_ERROR;
            x_error_text      :=
                   'The Cust Site Use creation process failed with Error: '
                || SQLERRM;
    END create_cust_site_use;

    PROCEDURE create_customer_addresses (p_customer_number IN VARCHAR2, p_first_name IN VARCHAR2, p_middle_name IN VARCHAR2, p_last_name IN VARCHAR2, p_title IN VARCHAR2, p_phone_number IN VARCHAR2, p_email_address IN VARCHAR2, p_web_site_id IN VARCHAR2, p_language IN VARCHAR2, -- bill to Address
                                                                                                                                                                                                                                                                                       p_bill_to_loc_name IN VARCHAR2, p_bill_to_address1 IN VARCHAR2, p_bill_to_address2 IN VARCHAR2, p_bill_to_address3 IN VARCHAR2, p_bill_to_city IN VARCHAR2, p_bill_to_state IN VARCHAR2, p_bill_to_province IN VARCHAR2:= NULL, p_bill_to_postal_code IN VARCHAR2, p_bill_to_country IN VARCHAR2, p_bill_to_phone IN VARCHAR2, p_bill_to_email IN VARCHAR2:= NULL, -- ship to Address
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          p_ship_to_loc_name IN VARCHAR2, p_ship_to_address1 IN VARCHAR2, p_ship_to_address2 IN VARCHAR2, p_ship_to_address3 IN VARCHAR2, p_ship_to_city IN VARCHAR2, p_ship_to_state IN VARCHAR2, p_ship_to_province IN VARCHAR2:= NULL, p_ship_to_postal_code IN VARCHAR2, p_ship_to_country IN VARCHAR2, p_ship_to_phone IN VARCHAR2, p_ship_to_email IN VARCHAR2:= NULL, p_tax_code IN VARCHAR2, p_gl_id_rev IN NUMBER, p_created_by_module IN VARCHAR2 DEFAULT NULL, --BEGIN Flexfields
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          p_store_number IN VARCHAR2 DEFAULT NULL, p_dc_number IN VARCHAR2 DEFAULT NULL, p_distro_customer_name IN VARCHAR2 DEFAULT NULL, p_ec_non_ec_country IN VARCHAR2 DEFAULT NULL, p_dealer_locator_eligible IN VARCHAR2 DEFAULT NULL, p_sales_region IN VARCHAR2 DEFAULT NULL, p_edi_enabled_flag IN VARCHAR2 DEFAULT NULL, --END Flexfields
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  x_customer_id OUT NUMBER, x_bill_to_site_use_id OUT NUMBER, x_ship_to_site_use_id OUT NUMBER, x_return_status OUT VARCHAR2
                                         , x_error_text OUT VARCHAR2)
    IS
        l_customer_rec          customer_rec_type := NULL;
        l_bill_to_address_rec   address_rec_type := NULL;
        l_ship_to_address_rec   address_rec_type := NULL;
        ex_mis_wbsite_info      EXCEPTION;
    BEGIN
        -- 1.0 : START : Added for BT.
        mo_global.init ('ONT');
        mo_global.set_policy_context ('M', NULL);

        -- 1.0 : END : Added for BT.

        IF p_web_site_id IS NULL OR p_language IS NULL
        THEN
            msg (MESSAGE       => 'p_Web_site_id and/or p_language are missing',
                 debug_level   => 100);
            RAISE ex_mis_wbsite_info;
        END IF;

        l_customer_rec.customer_number        := p_customer_number;
        l_customer_rec.first_name             := p_first_name;
        l_customer_rec.middle_name            := p_middle_name;
        l_customer_rec.last_name              := p_last_name;
        l_customer_rec.title                  := p_title;
        l_customer_rec.phone_number           := p_phone_number;
        l_customer_rec.email_address          := p_email_address;
        l_customer_rec.web_site_id            := p_web_site_id;
        l_customer_rec.language               := p_language;
        --
        l_bill_to_address_rec.location_name   := p_bill_to_loc_name;
        l_bill_to_address_rec.address1        := p_bill_to_address1;
        l_bill_to_address_rec.address2        := p_bill_to_address2;
        l_bill_to_address_rec.address3        := p_bill_to_address3;
        l_bill_to_address_rec.city            := p_bill_to_city;
        l_bill_to_address_rec.state           := p_bill_to_state;
        l_bill_to_address_rec.province        := p_bill_to_province;
        l_bill_to_address_rec.postal_code     := p_bill_to_postal_code;
        l_bill_to_address_rec.country         := p_bill_to_country;
        l_bill_to_address_rec.phone_number    := p_bill_to_phone;
        l_bill_to_address_rec.email_address   := p_bill_to_email;
        --
        l_ship_to_address_rec.location_name   := p_ship_to_loc_name;
        l_ship_to_address_rec.address1        := p_ship_to_address1;
        l_ship_to_address_rec.address2        := p_ship_to_address2;
        l_ship_to_address_rec.address3        := p_ship_to_address3;
        l_ship_to_address_rec.city            := p_ship_to_city;
        l_ship_to_address_rec.state           := p_ship_to_state;
        l_ship_to_address_rec.province        := p_ship_to_province;
        l_ship_to_address_rec.postal_code     := p_ship_to_postal_code;
        l_ship_to_address_rec.country         := p_ship_to_country;
        l_ship_to_address_rec.phone_number    := p_ship_to_phone;
        l_ship_to_address_rec.email_address   := p_ship_to_email;
        --
        create_cust_site_use (
            p_customer_rec              => l_customer_rec,
            p_bill_to_address_rec       => l_bill_to_address_rec,
            p_ship_to_address_rec       => l_ship_to_address_rec,
            p_tax_code                  => p_tax_code,
            p_gl_id_rev                 => p_gl_id_rev,
            p_created_by_module         => p_created_by_module,
            --BEGIN Flexfields
            p_store_number              => p_store_number,
            p_dc_number                 => p_dc_number,
            p_distro_customer_name      => p_distro_customer_name,
            p_ec_non_ec_country         => p_ec_non_ec_country,
            p_dealer_locator_eligible   => p_dealer_locator_eligible,
            p_sales_region              => p_sales_region,
            p_edi_enabled_flag          => p_edi_enabled_flag,
            --END Flexfields
            x_customer_id               => x_customer_id,
            x_bill_to_site_use_id       => x_bill_to_site_use_id,
            x_ship_to_site_use_id       => x_ship_to_site_use_id,
            x_return_status             => x_return_status,
            x_error_text                => x_error_text);
    EXCEPTION
        WHEN ex_mis_wbsite_info
        THEN
            x_return_status   := FND_API.G_RET_STS_ERROR;
            x_error_text      :=
                'The Web Site ID and/or Language info is Missing';
        WHEN OTHERS
        THEN
            x_return_status   := FND_API.G_RET_STS_UNEXP_ERROR;
            x_error_text      :=
                   'The Customer Addresses creation process failed with Error: '
                || SQLERRM;
    END create_customer_addresses;
END xxdoec_ar_customer_pkg;
/
