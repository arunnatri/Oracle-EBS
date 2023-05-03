--
-- XXD_ONT_VAS_CUSTOMER_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:06 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_VAS_CUSTOMER_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_VAS_CUSTOMER_PKG
    * Design       : This package will be used for VAS Automation.
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 30-JUL-2020  1.0        Gaurav Joshi           Initial Version
 -- 06-Aug-2021  1.1       Gaurav Joshi            CCR0009419
 -- 15-jul-2022  1.2       Gaurav Joshi            CCR0010026
 -- 23-Sep-2022  1.3       Gaurav joshi            CCR0010204
    ******************************************************************************************/
    gn_org_id              NUMBER := fnd_global.org_id;
    gn_user_id             NUMBER := fnd_global.user_id;
    gn_login_id            NUMBER := fnd_global.login_id;
    gn_application_id      NUMBER := fnd_profile.VALUE ('RESP_APPL_ID');
    gn_responsibility_id   NUMBER := fnd_profile.VALUE ('RESP_ID');

    PROCEDURE init
    AS
    BEGIN
        mo_global.init ('AR');
        mo_global.set_policy_context ('S', gn_org_id);
        fnd_global.apps_initialize (user_id        => gn_user_id,
                                    resp_id        => gn_responsibility_id,
                                    resp_appl_id   => gn_application_id);
    EXCEPTION
        WHEN OTHERS
        THEN
            RAISE;
    END init;

    PROCEDURE save_customer_info (p_org_id IN NUMBER, p_resp_id IN NUMBER, p_resp_app_id IN NUMBER, p_user_id IN NUMBER, p_cust_hdr_info_record IN xxdo.xxd_ont_cust_head_info_tbl_typ, x_ret_status OUT NOCOPY VARCHAR2
                                  , x_err_msg OUT NOCOPY VARCHAR2)
    AS
        lc_status   VARCHAR2 (10);
    BEGIN
        MERGE INTO xxd_ont_customer_header_info_t a
             USING (SELECT *
                      FROM TABLE (p_cust_hdr_info_record) p_cust_hdr_info_row)
                   b
                ON (a.cust_account_id = b.cust_account_id)
        WHEN MATCHED
        THEN
            UPDATE SET a.ship_method = b.ship_method, a.freight_terms = b.freight_terms, a.freight_account = b.freight_account,
                       a.shipping_instructions = b.shipping_instructions, a.packing_instructions = b.packing_instructions, a.gs1_format = b.gs1_format,
                       a.gs1_mc_panel = b.gs1_mc_panel, a.gs1_justification = b.gs1_justification, a.gs1_side_offset = b.gs1_side_offset,
                       a.gs1_bottom_offset = b.gs1_bottom_offset, a.print_cc = b.print_cc, a.cc_mc_panel = b.cc_mc_panel,
                       a.cc_justification = b.cc_justification, a.cc_side_offset = b.cc_side_offset, a.cc_bottom_offset = b.cc_bottom_offset,
                       a.mc_max_length = b.mc_max_length, a.mc_max_width = b.mc_max_width, a.mc_max_height = b.mc_max_height,
                       a.mc_max_weight = b.mc_max_weight, a.mc_min_length = b.mc_min_length, a.mc_min_width = b.mc_min_width,
                       a.mc_min_height = b.mc_min_height, a.mc_min_weight = b.mc_min_weight, a.custom_dropship_packslip_flag = b.custom_dropship_packslip_flag,
                       a.print_pack_slip = b.print_pack_slip, a.dropship_packslip_display_name = b.dropship_packslip_display_name, a.dropship_packslip_message = b.dropship_packslip_message,
                       a.custom_dropship_phone_num = b.custom_dropship_phone_num, a.custom_dropship_email = b.custom_dropship_email, a.service_time_frame = b.service_time_frame,
                       a.call_in_sla = b.call_in_sla, a.tms_cutoff_time = b.tms_cutoff_time, a.routing_day1 = b.routing_day1,
                       a.scheduled_day1 = b.scheduled_day1, a.routing_day2 = b.routing_day2, a.scheduled_day2 = b.scheduled_day2,
                       a.back_to_back = b.back_to_back, a.tms_flag = b.tms_flag, a.tms_url = b.tms_url,
                       a.tms_username = b.tms_username, a.tms_password = b.tms_password, a.routing_notes = b.routing_notes,
                       a.routing_contact_name = b.routing_contact_name, a.routing_contact_phone = b.routing_contact_phone, a.routing_contact_fax = b.routing_contact_fax,
                       a.routing_contact_email = b.routing_contact_email, a.parcel_ship_method = b.parcel_ship_method, a.parcel_weight_limit = b.parcel_weight_limit,
                       a.parcel_dim_weight_flag = b.parcel_dim_weight_flag, a.parcel_carton_limit = b.parcel_carton_limit, a.ltl_ship_method = b.ltl_ship_method,
                       a.ltl_weight_limit = b.ltl_weight_limit, a.ltl_dim_weight_flag = b.ltl_dim_weight_flag, a.ltl_carton_limit = b.ltl_carton_limit,
                       a.ftl_ship_method = b.ftl_ship_method, a.ftl_weight_limit = b.ftl_weight_limit, a.ftl_dim_weight_flag = b.ftl_dim_weight_flag,
                       a.ftl_unit_limit = b.ftl_unit_limit, a.ftl_pallet_flag = b.ftl_pallet_flag, a.last_updated_by = p_user_id,
                       a.last_updated_date = SYSDATE, a.last_update_login = gn_login_id
        WHEN NOT MATCHED
        THEN
            INSERT     (account_name,
                        cust_account_id,
                        account_number,
                        brand,
                        customer_class,
                        ship_method,
                        freight_terms,
                        freight_account,
                        shipping_instructions,
                        packing_instructions,
                        gs1_format,
                        gs1_mc_panel,
                        gs1_justification,
                        gs1_side_offset,
                        gs1_bottom_offset,
                        print_cc,
                        cc_mc_panel,
                        cc_justification,
                        cc_side_offset,
                        cc_bottom_offset,
                        mc_max_length,
                        mc_max_width,
                        mc_max_height,
                        mc_max_weight,
                        mc_min_length,
                        mc_min_width,
                        mc_min_height,
                        mc_min_weight,
                        custom_dropship_packslip_flag,
                        print_pack_slip,
                        dropship_packslip_display_name,
                        dropship_packslip_message,
                        custom_dropship_phone_num,
                        custom_dropship_email,
                        service_time_frame,
                        call_in_sla,
                        tms_cutoff_time,
                        routing_day1,
                        scheduled_day1,
                        routing_day2,
                        scheduled_day2,
                        back_to_back,
                        tms_flag,
                        tms_url,
                        tms_username,
                        tms_password,
                        routing_notes,
                        routing_contact_name,
                        routing_contact_phone,
                        routing_contact_fax,
                        routing_contact_email,
                        parcel_ship_method,
                        parcel_weight_limit,
                        parcel_dim_weight_flag,
                        parcel_carton_limit,
                        ltl_ship_method,
                        ltl_weight_limit,
                        ltl_dim_weight_flag,
                        ltl_carton_limit,
                        ftl_ship_method,
                        ftl_weight_limit,
                        ftl_dim_weight_flag,
                        ftl_unit_limit,
                        ftl_pallet_flag,
                        created_by,
                        creation_date,
                        last_updated_by,
                        last_updated_date,
                        last_update_login)
                VALUES (b.account_name, b.cust_account_id, b.account_number,
                        b.brand, b.customer_class, b.ship_method,
                        b.freight_terms, b.freight_account, b.shipping_instructions, b.packing_instructions, b.gs1_format, b.gs1_mc_panel, b.gs1_justification, b.gs1_side_offset, b.gs1_bottom_offset, b.print_cc, b.cc_mc_panel, b.cc_justification, b.cc_side_offset, b.cc_bottom_offset, b.mc_max_length, b.mc_max_width, b.mc_max_height, b.mc_max_weight, b.mc_min_length, b.mc_min_width, b.mc_min_height, b.mc_min_weight, b.custom_dropship_packslip_flag, b.print_pack_slip, b.dropship_packslip_display_name, b.dropship_packslip_message, b.custom_dropship_phone_num, b.custom_dropship_email, b.service_time_frame, b.call_in_sla, b.tms_cutoff_time, b.routing_day1, b.scheduled_day1, b.routing_day2, b.scheduled_day2, b.back_to_back, b.tms_flag, b.tms_url, b.tms_username, b.tms_password, b.routing_notes, b.routing_contact_name, b.routing_contact_phone, b.routing_contact_fax, b.routing_contact_email, b.parcel_ship_method, b.parcel_weight_limit, b.parcel_dim_weight_flag, b.parcel_carton_limit, b.ltl_ship_method, b.ltl_weight_limit, b.ltl_dim_weight_flag, b.ltl_carton_limit, b.ftl_ship_method, b.ftl_weight_limit, b.ftl_dim_weight_flag, b.ftl_unit_limit, b.ftl_pallet_flag, p_user_id, SYSDATE
                        , p_user_id, SYSDATE, gn_login_id);

        COMMIT;
        x_ret_status   := 'S';
        x_err_msg      := NULL;
        -- custom table updated; now try syncing data into the std table
        update_customer_account (p_org_id,
                                 p_resp_id,
                                 p_resp_app_id,
                                 p_user_id,
                                 p_cust_hdr_info_record (1).cust_account_id,
                                 p_cust_hdr_info_record (1).ship_method,
                                 p_cust_hdr_info_record (1).freight_terms,
                                 p_cust_hdr_info_record (1).gs1_format,
                                 p_cust_hdr_info_record (1).freight_account,
                                 p_cust_hdr_info_record (1).print_cc,
                                 x_ret_status,
                                 x_err_msg);

        IF (x_ret_status <> 'S')
        THEN
            x_ret_status   := 'E';
            x_err_msg      :=
                   'Changes have been saved successfully into the staging table.However, could not able to sync ship-via/freight term/freight account/Print CC and GS1 128 Format.'
                || x_err_msg;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_status   := 'E';
            x_err_msg      := SUBSTR (SQLERRM, 1, 500);
    END save_customer_info;

    PROCEDURE save_customersite_info (p_org_id IN NUMBER, p_resp_id IN NUMBER, p_resp_app_id IN NUMBER, p_user_id IN NUMBER, p_custsite_hdr_info_record IN xxdo.xxd_ont_cust_ship_info_tbl_typ, x_ret_status OUT NOCOPY VARCHAR2
                                      , x_err_msg OUT NOCOPY VARCHAR2)
    AS
        lc_status   VARCHAR2 (10);
    BEGIN
        MERGE INTO xxd_ont_customer_shipto_info_t a
             USING (SELECT *
                      FROM TABLE (p_custsite_hdr_info_record) p_cust_hdr_info_row)
                   b
                ON (a.cust_account_id = b.cust_account_id AND a.cust_acct_site_id = b.cust_acct_site_id)
        WHEN MATCHED
        THEN
            UPDATE SET a.ship_method = b.ship_method, a.freight_terms = b.freight_terms, a.freight_account = b.freight_account,
                       a.shipping_instructions = b.shipping_instructions, a.packing_instructions = b.packing_instructions, a.gs1_format = b.gs1_format,
                       a.gs1_mc_panel = b.gs1_mc_panel, a.gs1_justification = b.gs1_justification, a.gs1_side_offset = b.gs1_side_offset,
                       a.gs1_bottom_offset = b.gs1_bottom_offset, a.print_cc = b.print_cc, a.cc_mc_panel = b.cc_mc_panel,
                       a.cc_justification = b.cc_justification, a.cc_side_offset = b.cc_side_offset, a.cc_bottom_offset = b.cc_bottom_offset,
                       a.service_time_frame = b.service_time_frame, a.call_in_sla = b.call_in_sla, a.tms_cutoff_time = b.tms_cutoff_time,
                       a.routing_day1 = b.routing_day1, a.scheduled_day1 = b.scheduled_day1, a.routing_day2 = b.routing_day2,
                       a.scheduled_day2 = b.scheduled_day2, a.back_to_back = b.back_to_back, a.tms_flag = b.tms_flag,
                       a.tms_url = b.tms_url, a.tms_username = b.tms_username, a.tms_password = b.tms_password,
                       a.routing_notes = b.routing_notes, a.routing_contact_name = b.routing_contact_name, a.routing_contact_phone = b.routing_contact_phone,
                       a.routing_contact_fax = b.routing_contact_fax, a.routing_contact_email = b.routing_contact_email, a.parcel_ship_method = b.parcel_ship_method,
                       a.parcel_weight_limit = b.parcel_weight_limit, a.parcel_dim_weight_flag = b.parcel_dim_weight_flag, a.parcel_carton_limit = b.parcel_carton_limit,
                       a.ltl_ship_method = b.ltl_ship_method, a.ltl_weight_limit = b.ltl_weight_limit, a.ltl_dim_weight_flag = b.ltl_dim_weight_flag,
                       a.ltl_carton_limit = b.ltl_carton_limit, a.ftl_ship_method = b.ftl_ship_method, a.ftl_weight_limit = b.ftl_weight_limit,
                       a.ftl_dim_weight_flag = b.ftl_dim_weight_flag, a.ftl_unit_limit = b.ftl_unit_limit, a.ftl_pallet_flag = b.ftl_pallet_flag,
                       a.last_updated_by = p_user_id, a.last_updated_date = SYSDATE, a.last_update_login = gn_login_id
        WHEN NOT MATCHED
        THEN
            INSERT     (account_name,
                        cust_account_id,
                        account_number,
                        brand,
                        ship_to_site_id,
                        cust_acct_site_id,
                        ship_to_location_name,
                        ship_method,
                        freight_terms,
                        freight_account,
                        shipping_instructions,
                        packing_instructions,
                        gs1_format,
                        gs1_mc_panel,
                        gs1_justification,
                        gs1_side_offset,
                        gs1_bottom_offset,
                        print_cc,
                        cc_mc_panel,
                        cc_justification,
                        cc_side_offset,
                        cc_bottom_offset,
                        service_time_frame,
                        call_in_sla,
                        tms_cutoff_time,
                        routing_day1,
                        scheduled_day1,
                        routing_day2,
                        scheduled_day2,
                        back_to_back,
                        tms_flag,
                        tms_url,
                        tms_username,
                        tms_password,
                        routing_notes,
                        routing_contact_name,
                        routing_contact_phone,
                        routing_contact_fax,
                        routing_contact_email,
                        parcel_ship_method,
                        parcel_weight_limit,
                        parcel_dim_weight_flag,
                        parcel_carton_limit,
                        ltl_ship_method,
                        ltl_weight_limit,
                        ltl_dim_weight_flag,
                        ltl_carton_limit,
                        ftl_ship_method,
                        ftl_weight_limit,
                        ftl_dim_weight_flag,
                        ftl_unit_limit,
                        ftl_pallet_flag,
                        created_by,
                        creation_date,
                        last_updated_by,
                        last_updated_date,
                        last_update_login)
                VALUES (b.account_name, b.cust_account_id, b.account_number,
                        b.brand, b.ship_to_site_id, b.cust_acct_site_id,
                        b.ship_to_location_name, b.ship_method, b.freight_terms, b.freight_account, b.shipping_instructions, b.packing_instructions, b.gs1_format, b.gs1_mc_panel, b.gs1_justification, b.gs1_side_offset, b.gs1_bottom_offset, b.print_cc, b.cc_mc_panel, b.cc_justification, b.cc_side_offset, b.cc_bottom_offset, b.service_time_frame, b.call_in_sla, b.tms_cutoff_time, b.routing_day1, b.scheduled_day1, b.routing_day2, b.scheduled_day2, b.back_to_back, b.tms_flag, b.tms_url, b.tms_username, b.tms_password, b.routing_notes, b.routing_contact_name, b.routing_contact_phone, b.routing_contact_fax, b.routing_contact_email, b.parcel_ship_method, b.parcel_weight_limit, b.parcel_dim_weight_flag, b.parcel_carton_limit, b.ltl_ship_method, b.ltl_weight_limit, b.ltl_dim_weight_flag, b.ltl_carton_limit, b.ftl_ship_method, b.ftl_weight_limit, b.ftl_dim_weight_flag, b.ftl_unit_limit, b.ftl_pallet_flag, p_user_id, SYSDATE
                        , p_user_id, SYSDATE, gn_login_id);

        COMMIT;
        x_ret_status   := 'S';
        x_err_msg      := NULL;
        -- custom table updated; now try syncing data into the std table
        update_cust_acct_site (p_org_id, p_resp_id, p_resp_app_id,
                               p_user_id, p_custsite_hdr_info_record (1).cust_acct_site_id, p_custsite_hdr_info_record (1).gs1_format, p_custsite_hdr_info_record (1).freight_account, p_custsite_hdr_info_record (1).print_cc, x_ret_status
                               , x_err_msg);
        update_cust_site_uses (p_org_id, p_resp_id, p_resp_app_id,
                               p_user_id, p_custsite_hdr_info_record (1).ship_to_site_id, p_custsite_hdr_info_record (1).cust_acct_site_id, p_custsite_hdr_info_record (1).ship_method, p_custsite_hdr_info_record (1).freight_terms, x_ret_status
                               , x_err_msg);

        IF (x_ret_status <> 'S')
        THEN
            x_ret_status   := 'E';
            x_err_msg      :=
                   'Changes have been saved successfully into the staging table.However, could not able to sync ship-via/freight term/freight account/Print CC and GS1 128 Format.'
                || x_err_msg;
        END IF;

        x_ret_status   := 'S';
        x_err_msg      := NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_status   := 'E';
            x_err_msg      := SUBSTR (SQLERRM, 1, 500);
    END save_customersite_info;

    PROCEDURE assign_vas_to_customer (
        p_org_id                   IN            NUMBER,
        p_resp_id                  IN            NUMBER,
        p_resp_app_id              IN            NUMBER,
        p_user_id                  IN            NUMBER,
        p_mode                     IN            VARCHAR2,
        p_cust_vas_assign_record   IN            xxdo.xxd_ont_vas_agnmt_dtls_tbl_typ,
        x_ret_status                  OUT NOCOPY VARCHAR2,
        x_err_msg                     OUT NOCOPY VARCHAR2)
    AS
        lc_status   VARCHAR2 (10);
    BEGIN
        IF p_mode = 'INSERT-UPDATE'
        THEN
            MERGE INTO xxd_ont_vas_assignment_dtls_t a
                 USING (SELECT *
                          FROM TABLE (p_cust_vas_assign_record) p_cust_hdr_info_row)
                       b
                    ON (a.cust_account_id = b.cust_account_id AND a.vas_code = b.vas_code AND a.attribute_level = b.attribute_level AND a.attribute_value = b.attribute_value)
            WHEN MATCHED
            THEN
                UPDATE SET a.vas_comments = b.vas_comments, a.last_updated_by = p_user_id, a.last_updated_date = SYSDATE,
                           a.last_update_login = gn_login_id
            WHEN NOT MATCHED
            THEN
                INSERT     (account_number, cust_account_id, attribute_level,
                            attribute_value, description, entity,
                            org_id, vas_code, vas_comments,
                            created_by, creation_date, last_updated_by,
                            last_updated_date, last_update_login)
                    VALUES (b.account_number, b.cust_account_id, b.attribute_level, b.attribute_value, b.description, b.entity, b.org_id, b.vas_code, b.vas_comments, p_user_id, SYSDATE, p_user_id
                            , SYSDATE, gn_login_id);
        ELSIF p_mode = 'DELETE'
        THEN
            DELETE FROM
                xxd_ont_vas_assignment_dtls_t a
                  WHERE EXISTS
                            (SELECT 1
                               FROM TABLE (p_cust_vas_assign_record) b
                              WHERE     a.cust_account_id = b.cust_account_id
                                    AND a.vas_code = b.vas_code
                                    AND a.attribute_level = b.attribute_level
                                    AND a.attribute_value = b.attribute_value);
        END IF;

        COMMIT;
        x_ret_status   := 'S';
        x_err_msg      := NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_status   := 'E';
            x_err_msg      := SUBSTR (SQLERRM, 1, 500);
    END assign_vas_to_customer;

    PROCEDURE update_customer_account (p_org_id IN NUMBER, p_resp_id IN NUMBER, p_resp_app_id IN NUMBER, p_user_id IN NUMBER, p_cust_account_id IN NUMBER, p_ship_via IN VARCHAR2, p_freight_term IN VARCHAR2, p_gs1_128format IN VARCHAR2, p_freight_account IN VARCHAR2
                                       , p_print_cc IN VARCHAR2, x_ret_status OUT NOCOPY VARCHAR2, x_err_msg OUT NOCOPY VARCHAR2)
    AS
        p_cust_account_rec         hz_cust_account_v2pub.cust_account_rec_type;
        lc_object_version_number   NUMBER;
        x_return_status            VARCHAR2 (2000);
        x_msg_count                NUMBER;
        x_msg_data                 VARCHAR2 (2000);
        ln_cust_account_id         hz_cust_accounts.cust_account_id%TYPE;
        lc_customer_type           hz_cust_accounts.customer_type%TYPE;
        lc_freight_term            hz_cust_accounts.freight_term%TYPE;
        lc_ship_via                hz_cust_accounts.ship_via%TYPE;
    BEGIN
        gn_org_id                            := p_org_id;
        gn_user_id                           := p_user_id;
        gn_application_id                    := p_resp_app_id;
        gn_responsibility_id                 := p_resp_id;
        -- Setting the Context --
        init;

        BEGIN
            SELECT object_version_number, customer_type
              INTO lc_object_version_number, lc_customer_type
              FROM hz_cust_accounts
             WHERE cust_account_id = p_cust_account_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                x_ret_status   := 'E';
                x_err_msg      := 'Unable to derive cust account details';
        END;

        -- get the code freight code
        BEGIN
            SELECT lookup_code
              INTO lc_freight_term
              FROM apps.oe_lookups
             WHERE     UPPER (lookup_type) = 'FREIGHT_TERMS'
                   AND enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (start_date_active,
                                                        SYSDATE))
                                           AND TRUNC (
                                                   NVL (end_date_active,
                                                        SYSDATE))
                   AND meaning = p_freight_term;
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_freight_term   := NULL;
        END;

        --  get ship code from meaning
        BEGIN
            SELECT lookup_code
              INTO lc_ship_via
              FROM fnd_lookup_values_vl
             WHERE     lookup_type = 'SHIP_METHOD'
                   AND enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (start_date_active,
                                                        SYSDATE))
                                           AND TRUNC (
                                                   NVL (end_date_active,
                                                        SYSDATE))
                   AND meaning = p_ship_via;
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_ship_via   := NULL;
        END;

        -- Initializing the Mandatory API parameters
        p_cust_account_rec.cust_account_id   := p_cust_account_id;
        p_cust_account_rec.customer_type     := lc_customer_type;
        /*  begin ver 1.1
                IF lc_freight_term IS NOT NULL
                THEN
                    p_cust_account_rec.freight_term := lc_freight_term;
                END IF;

                IF (lc_ship_via IS NOT NULL)
                THEN
                    p_cust_account_rec.ship_via := lc_ship_via;
                END IF;
        end ver 2.1 */
        p_cust_account_rec.freight_term      :=
            NVL (lc_freight_term, fnd_api.g_miss_char);             -- ver 1.1
        p_cust_account_rec.ship_via          :=
            NVL (lc_ship_via, fnd_api.g_miss_char);                 -- ver 1.1

        IF p_gs1_128format IS NOT NULL
        THEN
            p_cust_account_rec.attribute2   := p_gs1_128format;
        END IF;

        /*  begin ver 1.1
                IF p_freight_account IS NOT NULL
                THEN
                    p_cust_account_rec.attribute8 := p_freight_account;
                END IF;
        end ver 1.1 */
        p_cust_account_rec.attribute8        :=
            NVL (p_freight_account, fnd_api.g_miss_char);           -- ver 1.1

        IF p_print_cc IS NOT NULL
        THEN
            p_cust_account_rec.attribute12   := p_print_cc;
        END IF;

        hz_cust_account_v2pub.update_cust_account (
            p_init_msg_list           => fnd_api.g_true,
            p_cust_account_rec        => p_cust_account_rec,
            p_object_version_number   => lc_object_version_number,
            x_return_status           => x_return_status,
            x_msg_count               => x_msg_count,
            x_msg_data                => x_msg_data);

        IF x_return_status = fnd_api.g_ret_sts_success
        THEN
            COMMIT;
            x_ret_status   := 'S';
        ELSE
            ROLLBACK;

            FOR i IN 1 .. x_msg_count
            LOOP
                x_msg_data   :=
                    fnd_msg_pub.get (p_msg_index => i, p_encoded => 'F');
            END LOOP;

            x_ret_status   := 'E';
            x_err_msg      := SUBSTR (x_msg_data, 1, 500);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_status   := 'E';
            x_err_msg      := SUBSTR (SQLERRM, 1, 500);
    END update_customer_account;

    --  This procedure is used to update lable format/ print cc and freight account on
    -- hz_cust_acct_sites_all
    PROCEDURE update_cust_acct_site (p_org_id IN NUMBER, p_resp_id IN NUMBER, p_resp_app_id IN NUMBER, p_user_id IN NUMBER, p_cust_acct_site_Id IN NUMBER, p_gs1_128format IN VARCHAR2, p_freight_account IN VARCHAR2, p_print_cc IN VARCHAR2, x_ret_status OUT NOCOPY VARCHAR2
                                     , x_err_msg OUT NOCOPY VARCHAR2)
    AS
        p_init_msg_list           VARCHAR2 (250) := fnd_api.g_false;
        l_cust_acct_site_rec      HZ_CUST_ACCOUNT_SITE_V2PUB.cust_acct_site_rec_type;
        p_object_version_number   NUMBER (10);
        x_return_status           VARCHAR2 (1000);
        x_msg_count               NUMBER (10);
        x_msg_data                VARCHAR2 (1000);
        ln_site_use_id            NUMBER;
        ln_cust_acct_site_id      NUMBER;
        lc_customer_type          hz_cust_accounts.customer_type%TYPE;
    BEGIN
        gn_org_id                                := p_org_id;
        gn_user_id                               := p_user_id;
        gn_application_id                        := p_resp_app_id;
        gn_responsibility_id                     := p_resp_id;

        -- Setting the Context --
        init;

        BEGIN
            SELECT object_version_number
              INTO p_object_version_number
              FROM hz_cust_acct_sites_all
             WHERE cust_acct_site_id = p_cust_acct_site_Id;
        EXCEPTION
            WHEN OTHERS
            THEN
                x_ret_status   := 'E';
                x_err_msg      :=
                    'Unable to derive cust account site details';
        END;


        l_cust_acct_site_rec.cust_acct_site_id   := p_cust_acct_site_id;
        p_object_version_number                  := p_object_version_number;


        IF p_gs1_128format IS NOT NULL
        THEN
            l_cust_acct_site_rec.global_attribute16   :=
                NVL (p_gs1_128format, fnd_api.g_miss_char);
        END IF;

        /* begin  ver 1.1 CCR0009419
        IF p_freight_account IS NOT NULL
        THEN
            l_cust_acct_site_rec.attribute8 := p_freight_account;
        END IF; begin  ver 1.1 CCR0009419 */
        l_cust_acct_site_rec.attribute8          :=
            NVL (p_freight_account, fnd_api.g_miss_char);     -- ver 1.1 added

        IF p_print_cc IS NOT NULL
        THEN
            l_cust_acct_site_rec.global_attribute17   :=
                NVL (p_print_cc, fnd_api.g_miss_char);
        END IF;

        hz_cust_account_site_v2pub.update_cust_acct_site (
            p_init_msg_list           => 'T',
            p_cust_acct_site_rec      => l_cust_acct_site_rec,
            p_object_version_number   => p_object_version_number,
            x_return_status           => x_return_status,
            x_msg_count               => x_msg_count,
            x_msg_data                => x_msg_data);

        IF x_return_status = fnd_api.g_ret_sts_success
        THEN
            COMMIT;
            x_ret_status   := 'S';
            x_err_msg      := NULL;
        ELSE
            ROLLBACK;

            FOR i IN 1 .. x_msg_count
            LOOP
                x_msg_data   :=
                    fnd_msg_pub.get (p_msg_index => i, p_encoded => 'F');
            END LOOP;

            x_ret_status   := 'E';
            x_err_msg      := SUBSTR (x_msg_data, 1, 500);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_status   := 'E';
            x_err_msg      := SUBSTR (SQLERRM, 1, 500);
    END update_cust_acct_site;



    --  This procedure is used to update  site freight terms and ship method
    -- hz_cust_site_uses_all
    PROCEDURE update_cust_site_uses (p_org_id IN NUMBER, p_resp_id IN NUMBER, p_resp_app_id IN NUMBER, p_user_id IN NUMBER, p_site_use_id IN NUMBER, p_cust_acct_site_Id IN NUMBER, p_ship_via IN VARCHAR2, p_freight_term IN VARCHAR2, x_ret_status OUT NOCOPY VARCHAR2
                                     , x_err_msg OUT NOCOPY VARCHAR2)
    AS
        p_init_msg_list           VARCHAR2 (250) := fnd_api.g_false;
        p_cust_site_use_rec       hz_cust_account_site_v2pub.cust_site_use_rec_type;
        p_object_version_number   NUMBER (10);
        x_return_status           VARCHAR2 (1000);
        x_msg_count               NUMBER (10);
        x_msg_data                VARCHAR2 (1000);
        ln_site_use_id            NUMBER;
        ln_cust_acct_site_id      NUMBER;
        lc_customer_type          hz_cust_accounts.customer_type%TYPE;
        lc_freight_term           hz_cust_accounts.freight_term%TYPE;
        lc_ship_via               hz_cust_accounts.ship_via%TYPE;
    BEGIN
        gn_org_id                               := p_org_id;
        gn_user_id                              := p_user_id;
        gn_application_id                       := p_resp_app_id;
        gn_responsibility_id                    := p_resp_id;

        -- Setting the Context --
        init;

        BEGIN
            SELECT object_version_number
              INTO p_object_version_number
              FROM hz_cust_site_uses_all
             WHERE     cust_acct_site_id = p_cust_acct_site_Id
                   AND site_use_id = p_site_use_id
                   AND site_use_code IN ('SHIP_TO', 'BILL_TO');
        EXCEPTION
            WHEN OTHERS
            THEN
                x_ret_status   := 'E';
                x_err_msg      :=
                    'Unable to derive cust account site details';
        END;

        -- get the code freight code
        BEGIN
            SELECT lookup_code
              INTO lc_freight_term
              FROM oe_lookups
             WHERE     UPPER (lookup_type) = 'FREIGHT_TERMS'
                   AND enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (start_date_active,
                                                        SYSDATE))
                                           AND TRUNC (
                                                   NVL (end_date_active,
                                                        SYSDATE))
                   AND meaning = p_freight_term;
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_freight_term   := NULL;
        END;

        BEGIN
            SELECT lookup_code
              INTO lc_ship_via
              FROM fnd_lookup_values_vl
             WHERE     lookup_type = 'SHIP_METHOD'
                   AND enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (start_date_active,
                                                        SYSDATE))
                                           AND TRUNC (
                                                   NVL (end_date_active,
                                                        SYSDATE))
                   AND meaning = p_ship_via;
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_ship_via   := NULL;
        END;

        p_cust_site_use_rec.cust_acct_site_id   := p_cust_acct_site_Id;
        p_cust_site_use_rec.site_use_id         := p_site_use_id;
        p_object_version_number                 := p_object_version_number;
        /* begin ver 1.1
                IF lc_freight_term IS NOT NULL
                THEN
                    p_cust_site_use_rec.freight_term := lc_freight_term;
                END IF;

                IF lc_ship_via IS NOT NULL
                THEN
                    p_cust_site_use_rec.ship_via := lc_ship_via;
                END IF;
         end  ver 1.1  */
        p_cust_site_use_rec.freight_term        :=
            NVL (lc_freight_term, fnd_api.g_miss_char);             -- ver 1.1
        p_cust_site_use_rec.ship_via            :=
            NVL (lc_ship_via, fnd_api.g_miss_char);                 -- ver 1.1
        hz_cust_account_site_v2pub.update_cust_site_use (
            p_init_msg_list           => 'T',
            p_cust_site_use_rec       => p_cust_site_use_rec,
            p_object_version_number   => p_object_version_number,
            x_return_status           => x_return_status,
            x_msg_count               => x_msg_count,
            x_msg_data                => x_msg_data);

        IF x_return_status = fnd_api.g_ret_sts_success
        THEN
            COMMIT;
            x_ret_status   := 'S';
            x_err_msg      := NULL;
        ELSE
            ROLLBACK;

            FOR i IN 1 .. x_msg_count
            LOOP
                x_msg_data   :=
                    fnd_msg_pub.get (p_msg_index => i, p_encoded => 'F');
            END LOOP;

            x_ret_status   := 'E';
            x_err_msg      := SUBSTR (x_msg_data, 1, 500);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_status   := 'E';
            x_err_msg      := SUBSTR (SQLERRM, 1, 500);
    END update_cust_site_uses;


    PROCEDURE pre_pack_order (p_errbuf OUT VARCHAR2, p_retcode OUT VARCHAR2, p_order_number IN NUMBER, p_override_assortment IN VARCHAR2, p_assortment1 IN NUMBER, p_assortment1_line_id IN VARCHAR2, p_assortment2 IN NUMBER, p_assortment2_line_id IN VARCHAR2, p_assortment3 IN NUMBER, p_assortment3_line_id IN VARCHAR2, p_assortment4 IN NUMBER, p_assortment4_line_id IN VARCHAR2, p_assortment5 IN NUMBER, p_assortment5_line_id IN VARCHAR2, p_assortment6 IN NUMBER
                              , p_assortment6_line_id IN VARCHAR2)
    IS
        CURSOR c_assortment IS
            (SELECT assortment_id, line_ids
               FROM (SELECT p_assortment1 AS assortment_id, p_assortment1_line_id AS line_ids
                       FROM DUAL
                     UNION ALL
                     SELECT p_assortment2 AS assortment_id, p_assortment2_line_id AS line_ids
                       FROM DUAL
                     UNION ALL
                     SELECT p_assortment3 AS assortment_id, p_assortment3_line_id AS line_ids
                       FROM DUAL
                     UNION ALL
                     SELECT p_assortment4 AS assortment_id, p_assortment4_line_id AS line_ids
                       FROM DUAL
                     UNION ALL
                     SELECT p_assortment4 AS assortment_id, p_assortment5_line_id AS line_ids
                       FROM DUAL
                     UNION ALL
                     SELECT p_assortment6 AS assortment_id, p_assortment6_line_id AS line_ids
                       FROM DUAL)
              WHERE assortment_id IS NOT NULL);

        -- lineids of all the assortment to validate distinctness only when the assortmentids are given
        CURSOR c_assortmentlineids IS
            ((SELECT COUNT (DISTINCT line_id) distinct_line_count, COUNT (line_id) total_line_count
                FROM (    SELECT REGEXP_SUBSTR (p_assortment1_line_id, '[^,]+', 1
                                                , LEVEL) line_id
                            FROM DUAL
                           WHERE 1 = 1 AND p_assortment1 IS NOT NULL
                      CONNECT BY REGEXP_SUBSTR (p_assortment1_line_id, '[^,]+', 1
                                                , LEVEL)
                                     IS NOT NULL
                      UNION ALL
                          SELECT REGEXP_SUBSTR (p_assortment2_line_id, '[^,]+', 1
                                                , LEVEL) line_id
                            FROM DUAL
                           WHERE p_assortment2 IS NOT NULL
                      CONNECT BY REGEXP_SUBSTR (p_assortment2_line_id, '[^,]+', 1
                                                , LEVEL)
                                     IS NOT NULL
                      UNION ALL
                          SELECT REGEXP_SUBSTR (p_assortment3_line_id, '[^,]+', 1
                                                , LEVEL) line_id
                            FROM DUAL
                           WHERE p_assortment3 IS NOT NULL
                      CONNECT BY REGEXP_SUBSTR (p_assortment3_line_id, '[^,]+', 1
                                                , LEVEL)
                                     IS NOT NULL
                      UNION ALL
                          SELECT REGEXP_SUBSTR (p_assortment4_line_id, '[^,]+', 1
                                                , LEVEL) line_id
                            FROM DUAL
                           WHERE p_assortment4 IS NOT NULL
                      CONNECT BY REGEXP_SUBSTR (p_assortment4_line_id, '[^,]+', 1
                                                , LEVEL)
                                     IS NOT NULL
                      UNION ALL
                          SELECT REGEXP_SUBSTR (p_assortment5_line_id, '[^,]+', 1
                                                , LEVEL) line_id
                            FROM DUAL
                           WHERE p_assortment5 IS NOT NULL
                      CONNECT BY REGEXP_SUBSTR (p_assortment5_line_id, '[^,]+', 1
                                                , LEVEL)
                                     IS NOT NULL
                      UNION ALL
                          SELECT REGEXP_SUBSTR (p_assortment6_line_id, '[^,]+', 1
                                                , LEVEL) line_id
                            FROM DUAL
                           WHERE p_assortment6 IS NOT NULL
                      CONNECT BY REGEXP_SUBSTR (p_assortment6_line_id, '[^,]+', 1
                                                , LEVEL)
                                     IS NOT NULL) a
               WHERE line_id IS NOT NULL));


        CURSOR c_getlines (lineids VARCHAR2)
        IS
            (SELECT line_id
               FROM (    SELECT REGEXP_SUBSTR (lineids, '[^,]+', 1,
                                               LEVEL) line_id
                           FROM DUAL
                     CONNECT BY REGEXP_SUBSTR (lineids, '[^,]+', 1,
                                               LEVEL)
                                    IS NOT NULL) a);


        CURSOR c_lines (p_lineids           VARCHAR2,
                        p_cust_account_id   NUMBER,
                        p_header_id         NUMBER)
        IS
            (SELECT inventory_item_id, ordered_quantity, line_id,
                    a.line_number, ordered_item
               FROM oe_order_lines_all a,
                    (SELECT line_number
                       FROM (    SELECT REGEXP_SUBSTR (p_lineids, '[^,]+', 1,
                                                       LEVEL) line_number
                                   FROM DUAL
                             CONNECT BY REGEXP_SUBSTR (p_lineids, '[^,]+', 1,
                                                       LEVEL)
                                            IS NOT NULL)) lineids
              WHERE     1 = 1
                    AND a.sold_to_org_id = p_cust_account_id
                    AND header_id = p_header_id
                    AND a.line_number = lineids.line_number);

        l_invalidlineid            NUMBER := 0;
        l_cust_account_id          NUMBER;
        l_flag                     VARCHAR2 (1) := 'N';
        l_flag1                    VARCHAR2 (1) := 'N';
        l_cancelled_flag           VARCHAR2 (1);
        L_SPLIT_COUNT              NUMBER;
        l_ola_distinct_sku_count   NUMBER;
        l_custom_sku_count         NUMBER;
        l_total_line_count         NUMBER;
        l_ship_to_count            NUMBER;
        l_count                    NUMBER;
        l_count1                   NUMBER;
        l_count3                   NUMBER;
        l_pack_qty                 NUMBER;
        l_attribute3               VARCHAR2 (240);
        l_header_id                NUMBER;
        l_distinctlines            VARCHAR2 (1) := 'N';
        l_headerinvalid            VARCHAR2 (1) := 'N';
        l_validcontainer           NUMBER;
        l_total_container          NUMBER;
        l_updatecount              NUMBER;
        l_message                  VARCHAR2 (240);
        l_released_status          VARCHAR2 (1);
        l_flow_status_code         VARCHAR2 (2000);
        l_ret_code                 NUMBER;
    BEGIN
        BEGIN
            SELECT sold_to_org_id, header_id
              INTO l_cust_account_id, l_header_id
              FROM oe_order_headers_all
             WHERE order_number = p_order_number;
        --  need to add more condition here
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error while Fetching Order header information'
                    || SQLERRM);
                l_headerinvalid   := 'Y';
                l_ret_code        := 1;
        END;

        IF l_headerinvalid = 'N'
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Processing for Order: ' || p_order_number);
            fnd_file.put_line (
                fnd_file.output,
                'assortment_id~ordered_quantity~line_number~casesize~status');

            -- all the lineids accross all Assortment shuld be dstinct BUT THIS INCLUDES VARCHAR ALSO

            FOR i IN c_assortmentlineids
            LOOP
                IF i.distinct_line_count <> i.total_line_count
                THEN
                    -- write into the log file and exit
                    -- hedaer level validation failed
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'There are duplicate line numbers accross the assortments');
                    l_distinctlines   := 'Y';
                    l_ret_code        := 1;
                END IF;
            END LOOP;

            IF l_distinctlines = 'N'
            THEN
                -- code from here onward will execute only when abvove validation holds true

                FOR i IN c_assortment
                LOOP
                    -- individual assortment line id varchar validation; if any of the lineid is invalid, skip the complete assortment batch
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Processing for assortment: '
                        || i.assortment_id
                        || ', lines Numbers: '
                        || i.line_ids);

                    SELECT COUNT (DISTINCT line_id)
                      INTO l_invalidlineid
                      FROM (    SELECT REGEXP_SUBSTR (i.line_ids, '[^,]+', 1,
                                                      LEVEL) line_id
                                  FROM DUAL
                            CONNECT BY REGEXP_SUBSTR (i.line_ids, '[^,]+', 1,
                                                      LEVEL)
                                           IS NOT NULL) a
                     WHERE REGEXP_LIKE (line_id, '[[:alpha:]]+$');

                    IF l_invalidlineid > 0
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'AlphaNumberic Line Id found for AssortmentId:'
                            || i.assortment_id);
                        l_ret_code   := 1;
                        -- write into the log file and contiuue to process next assortmentid
                        CONTINUE;
                    END IF;


                    l_flag   := 'N';               -- init at assrotment level

                    -- loop thru all the lines for an assortment id
                    FOR j IN c_getlines (i.line_ids)
                    LOOP
                        -- split line validation for the given lines

                        BEGIN
                            SELECT COUNT (line_id), MIN (cancelled_flag)
                              INTO l_split_count, l_cancelled_flag
                              FROM oe_order_lines_all
                             WHERE     header_id = l_header_id
                                   AND line_number = j.line_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'AssortmentId:'
                                    || i.assortment_id
                                    || ' Line Number:'
                                    || j.line_id
                                    || ': Unexpected error'
                                    || SQLERRM);
                                l_flag       := 'Y';
                                l_ret_code   := 1;
                                CONTINUE;             -- move to the next line
                        --unexpected  error while checkign split status for the given line id; write into log and proceed further
                        END;

                        IF l_cancelled_flag = 'Y'
                        THEN
                            l_flag       := 'Y';
                            l_ret_code   := 1;
                            -- its a CANCELLED LINE ; log the information in the log file and move to the next line
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'AssortmentId:'
                                || i.assortment_id
                                || ' Line Number:'
                                || j.line_id
                                || ': is a cancelled line');
                            CONTINUE;
                        END IF;

                        IF l_split_count > 1
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'AssortmentId:'
                                || i.assortment_id
                                || ' Line Number:'
                                || j.line_id
                                || ': is a split line');
                            l_flag       := 'Y';
                            l_ret_code   := 1;
                            -- its a split case ; log the information in the log file and move to the next line
                            CONTINUE;
                        ELSIF l_split_count = 0
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'AssortmentId:'
                                || i.assortment_id
                                || ' Line Number:'
                                || j.line_id
                                || ': unable to derive line Number information from orders line');
                            l_flag       := 'Y';
                            l_ret_code   := 1;
                            -- unable to drive lineid information for the given order ; log the information in the log file and move to the next line
                            CONTINUE;
                        END IF;

                        l_released_status   := NULL;

                        --- applicable unrelased or backordered line;
                        BEGIN
                            SELECT released_status
                              INTO l_released_status
                              FROM wsh_delivery_details a, oe_order_lines_all b
                             WHERE     a.source_line_id = b.line_id
                                   AND b.header_id = a.source_header_id
                                   AND b.line_number = j.line_id
                                   AND b.header_id = l_header_id
                                   AND source_code = 'OE';
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                BEGIN
                                    SELECT flow_status_code
                                      INTO l_flow_status_code
                                      FROM oe_order_lines_all
                                     WHERE     header_id = l_header_id
                                           AND line_number = j.line_id;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        l_released_status   := 'N';
                                END;

                                IF l_flow_status_code IN
                                       ('BOOKED', 'ENTERED')
                                THEN
                                    l_released_status   := 'R';
                                ELSE
                                    l_released_status   := 'N';
                                END IF;
                            -- this is a valid case as devliery will get created later after the pick release program
                            WHEN OTHERS
                            THEN
                                l_released_status   := NULL;
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'AssortmentId:'
                                    || i.assortment_id
                                    || ' Line Number:'
                                    || j.line_id
                                    || ': error while checking the line delivery status'
                                    || SQLERRM);
                                l_flag              := 'Y';
                                l_ret_code          := 1;
                                -- unable to drive lineid information for the given order ; log the information in the log file and move to the next line
                                CONTINUE;
                        END;

                        IF l_released_status NOT IN ('R', 'B')
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'AssortmentId:'
                                || i.assortment_id
                                || ' Line Number:'
                                || j.line_id
                                || ': is not a unreleased /back order line.');
                            l_flag       := 'Y';
                            l_ret_code   := 1;
                            -- unable to drive lineid information for the given order ; log the information in the log file and move to the next line
                            CONTINUE;
                        END IF;
                    END LOOP;

                    IF l_flag = 'Y'
                    THEN
                        l_ret_code   := 1;
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'AssortmentId:'
                            || i.assortment_id
                            || ' Line Number:'
                            || i.line_ids
                            || ': failed validation');
                    END IF;

                    IF l_flag = 'N'
                    THEN -- all lines for the given assrotment are ok; none of the line is a split case/ or cancelled
                        -- VALIDATE DISTINCT SKU FOR lineid supplied against current ASSORTMENT ID IN OLA

                        SELECT COUNT (DISTINCT ordered_item), COUNT (*), COUNT (DISTINCT ship_to_org_id)
                          INTO l_ola_distinct_sku_count, l_total_line_count, l_ship_to_count
                          FROM oe_order_lines_all
                         WHERE     header_id = l_header_id
                               AND line_number IN
                                       ((SELECT line_number
                                           FROM (    SELECT REGEXP_SUBSTR (
                                                                i.line_ids,
                                                                '[^,]+',
                                                                1,
                                                                LEVEL) line_number
                                                       FROM DUAL
                                                 CONNECT BY REGEXP_SUBSTR (
                                                                i.line_ids,
                                                                '[^,]+',
                                                                1,
                                                                LEVEL)
                                                                IS NOT NULL)
                                                a));

                        IF l_ola_distinct_sku_count <> l_total_line_count
                        THEN
                            l_ret_code   := 1;
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'AssortmentId:'
                                || i.assortment_id
                                || ' Line Number:'
                                || i.line_ids
                                || ': has duplicate SKUs.Failed validation');
                            --  DUPLICTA SKU found for the given assortmentid; move the the next assortment
                            -- LOG ERROR IN THE LOG FLE
                            CONTINUE;
                        END IF;

                        IF l_ship_to_count > 1
                        THEN
                            l_ret_code   := 1;
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'AssortmentId:'
                                || i.assortment_id
                                || ' Line Number:'
                                || i.line_ids
                                || ': has duplicate ship to location.Failed validation');
                            --  MULTIPLE SHIPT TO ERROR; SKIP THE ENTIRE ASSORTMENTID
                            -- LOG ERROR IN THE LOG FLE
                            CONTINUE;
                        END IF;

                        -- total number of SKU count shuld be same in the cusom table
                        -- for instance, assortment id 123456, lineids 4,5,6
                        -- then in the custom table also we shuld be having only theese 3 SKU(for given customer and assortmentid)
                        -- however count could match, but SKU could be  all together different subset of same size
                        -- that validation is in the for loop given below to validate one2one mapping of the ola SKU in custom table configuration
                        SELECT COUNT (b.inventory_item_id)
                          INTO l_custom_sku_count
                          FROM xxd_ont_cust_assortmnt_dtls_t b
                         WHERE     1 = 1
                               AND b.assortment_id = i.assortment_id
                               AND b.cust_account_id = l_cust_account_id;

                        IF l_total_line_count <> l_custom_sku_count
                        THEN
                            l_ret_code   := 1;
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'AssortmentId:'
                                || i.assortment_id
                                || ' Line Number:'
                                || i.line_ids
                                || ': SKU information is missing/not matching with assortment table.Failed validation');
                            --not all the given SKU have been steup in the custom tabl
                            -- print both the count in the log
                            CONTINUE;
                        END IF;

                        -- Total No.of Containers (order line qty / Pack Qty Combination) should be whole number and should be equal for all SKU’s
                        BEGIN
                            SELECT COUNT (DISTINCT (ordered_quantity / pack_qty)), MIN (ordered_quantity / pack_qty)
                              INTO l_count3, l_total_container
                              FROM oe_order_lines_all a, xxd_ont_cust_assortmnt_dtls_t b
                             WHERE     a.inventory_item_id =
                                       b.inventory_item_id
                                   AND b.assortment_id = i.assortment_id
                                   AND a.sold_to_org_id = l_cust_account_id
                                   AND header_id = l_header_id
                                   AND line_number IN
                                           (((SELECT line_number
                                                FROM (    SELECT REGEXP_SUBSTR (
                                                                     i.line_ids,
                                                                     '[^,]+',
                                                                     1,
                                                                     LEVEL) line_number
                                                            FROM DUAL
                                                      CONNECT BY REGEXP_SUBSTR (
                                                                     i.line_ids,
                                                                     '[^,]+',
                                                                     1,
                                                                     LEVEL)
                                                                     IS NOT NULL)
                                                     a)));
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'AssortmentId:'
                                    || i.assortment_id
                                    || ' Line Number:'
                                    || i.line_ids
                                    || ': unexpected error in whole Number validation:'
                                    || SQLERRM);
                                l_ret_code   := 1;
                                -- log the error and continue with next assortment batch
                                CONTINUE;
                        END;

                        IF l_count3 <> 1
                        THEN
                            l_ret_code   := 1;
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'AssortmentId:'
                                || i.assortment_id
                                || ' Line Number:'
                                || i.line_ids
                                || ': Unable to assign pre-package details. Line Qty''s not matched as per assortment details');
                            -- wirte into log file and move to the next assortmentid
                            CONTINUE;
                        ELSIF l_count3 = 1
                        THEN        --  FRACTION CHECK ONLY THEN COUNT IS ONE.
                            SELECT COUNT (1)
                              INTO l_validcontainer
                              FROM DUAL
                             WHERE     1 = 1
                                   AND REGEXP_LIKE (l_total_container,
                                                    '^[0-9]+$');

                            IF l_validcontainer = 0
                            THEN
                                l_ret_code   := 1;
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'AssortmentId:'
                                    || i.assortment_id
                                    || ' Line Number:'
                                    || i.line_ids
                                    || ': Containers size should be whole number for all SKU’s.Failed validation');
                            END IF;
                        END IF;

                        FOR idx
                            IN c_lines (i.line_ids,
                                        l_cust_account_id,
                                        l_header_id)
                        LOOP
                            l_attribute3    := NULL;

                            SELECT COUNT (inventory_item_id), MIN (pack_qty)
                              INTO l_count1, l_pack_qty
                              FROM xxd_ont_cust_assortmnt_dtls_t a
                             WHERE     a.cust_account_id = l_cust_account_id
                                   AND a.assortment_id = i.assortment_id
                                   AND a.inventory_item_id =
                                       idx.inventory_item_id;

                            IF l_count1 = 0
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'AssortmentId:'
                                    || i.assortment_id
                                    || ' Line Number:'
                                    || idx.line_number
                                    || ' SKU:'
                                    || idx.ordered_item
                                    || ': setup missing in assortment table.Failed validation');
                                --  setup missing for given given sku/customerNumber/assortmentid in custom table
                                l_ret_code   := 1;
                                ROLLBACK;
                                EXIT;
                            ELSIF l_count1 > 1
                            THEN
                                l_ret_code   := 1;
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'AssortmentId:'
                                    || i.assortment_id
                                    || ' Line Number:'
                                    || idx.line_number
                                    || ' SKU:'
                                    || idx.ordered_item
                                    || ': Multiple Entries in assortment table.Failed validation');
                                ROLLBACK;
                                -- multiple entires found for given sku/customerNumber/assortmentid in custom table
                                EXIT;
                            END IF;

                            l_attribute3    :=
                                   'vendor_sku:'
                                || i.assortment_id
                                || ',casepack_qty:'
                                || l_pack_qty;

                            UPDATE oe_order_lines_all
                               SET attribute3 = NVL2 (attribute3, DECODE (p_override_assortment, 'Y', l_attribute3, attribute3), l_attribute3)
                             WHERE line_id = idx.line_id;

                            l_updatecount   := SQL%ROWCOUNT;

                            IF l_updatecount = 1
                            THEN
                                l_message   := 'SUCESS';
                            ELSE
                                l_message   := 'UNSUCESSFUL';
                            END IF;

                            fnd_file.put_line (
                                fnd_file.output,
                                   i.assortment_id
                                || '~'
                                || idx.ordered_quantity
                                || '~'
                                || idx.line_number
                                || '~'
                                || l_attribute3
                                || '~'
                                || l_message);
                        END LOOP;
                    END IF;
                END LOOP; -- first check collectively if all the line ids are unique accross all assortment i.e 1 to 6
            END IF;

            COMMIT;
        END IF;

        fnd_file.put_line (fnd_file.LOG, 'Ret Code: ' || l_ret_code);

        IF l_ret_code = 1
        THEN
            p_retcode   := 1;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'pre_pack_order = ' || SQLERRM);
    END pre_pack_order;

    -- begin ver 1.2

    PROCEDURE assign_vas_at_site_style_mc_sc_lvl (
        p_org_id                   IN            NUMBER,
        p_resp_id                  IN            NUMBER,
        p_resp_app_id              IN            NUMBER,
        p_user_id                  IN            NUMBER,
        p_cust_account_id          IN            NUMBER,
        p_site_use_ids_record      IN            xxdo.xxd_ont_vas_site_use_tbl_typ,
        p_cust_vas_assign_record   IN            xxdo.xxd_ont_vas_agnmt_dtls_tbl_typ,
        p_mode                     IN            VARCHAR2,
        x_ret_status                  OUT NOCOPY VARCHAR2,
        x_err_msg                     OUT NOCOPY VARCHAR2)
    AS
        lc_status          VARCHAR2 (10);
        l_account_number   VARCHAR2 (100);

        CURSOR c_sites IS
            (SELECT a.site_use_id, b.vas_code, b.attribute1,
                    b.attribute2, b.attribute3, b.attribute4        -- ver 1.3
               FROM TABLE (p_site_use_ids_record) a, TABLE (p_cust_vas_assign_record) b);
    BEGIN
        SELECT account_number
          INTO l_account_number
          FROM hz_cust_accounts
         WHERE cust_account_id = p_cust_account_id;

        IF p_mode = 'MASSINSERT'
        THEN
            MERGE INTO xxd_ont_vas_assignment_dtls_t a
                 USING (SELECT site_use_id, c.vas_code, c.attribute1,
                               c.attribute2, c.attribute3, c.attribute4,
                               c.description, c.entity, c.vas_comments -- ver 1.3 added att4 for dept
                          FROM TABLE (p_site_use_ids_record) b, TABLE (p_cust_vas_assign_record) c)
                       bb
                    ON (a.cust_account_id = p_cust_account_id AND a.attribute_level = 'SITE-MASTERCLASS-SUBCLASS' AND a.attribute_value = bb.site_use_id AND a.vas_code = bb.vas_code AND NVL (a.attribute1, 'X') = NVL (bb.attribute1, 'X') AND NVL (a.attribute2, 'X') = NVL (bb.attribute2, 'X') AND NVL (a.attribute3, 'X') = NVL (bb.attribute3, 'X') AND NVL (a.attribute4, 'X') = NVL (bb.attribute4, 'X') -- ver 1.3
                                                                                                                                                                                                                                                                                                                                                                                                                 )
            WHEN MATCHED
            THEN
                UPDATE SET a.vas_comments = bb.vas_comments, a.last_updated_by = p_user_id, a.last_updated_date = SYSDATE,
                           a.last_update_login = gn_login_id
            WHEN NOT MATCHED
            THEN
                INSERT     (account_number, cust_account_id, attribute_level,
                            attribute_value, description, entity,
                            org_id, vas_code, vas_comments,
                            created_by, creation_date, last_updated_by,
                            last_updated_date, last_update_login, attribute1,
                            attribute2, attribute3, attribute4      -- ver 1.3
                                                              )
                    VALUES (l_account_number, p_cust_account_id, 'SITE-MASTERCLASS-SUBCLASS', bb.site_use_id, bb.description, 'Line Level', p_org_id, bb.vas_code, bb.vas_comments, p_user_id, SYSDATE, p_user_id, SYSDATE, gn_login_id, bb.attribute1
                            , bb.attribute2, bb.attribute3, bb.attribute4 -- ver 1.3
                                                                         );

            /*    FOR i IN c_sites
                    LOOP
                        INSERT INTO xxd_ont_vas_assignment_dtls_t (account_number,
                                                                   cust_account_id,
                                                                   attribute_level,
                                                                   attribute_value,
                                                                   description,
                                                                   entity,
                                                                   org_id,
                                                                   vas_code,
                                                                   vas_comments,
                                                                   created_by,
                                                                   creation_date,
                                                                   last_updated_by,
                                                                   last_updated_date,
                                                                   last_update_login,
                                                                   attribute1,
                                                                   attribute2,
                                                                   attribute3)
                             VALUES (l_account_number,
                                     p_cust_account_id,
                                     'SITE-MASTERCLASS-SUBCLASS',
                                     to_char(i.site_use_id),
                                     'description',
                                     'Line Level',
                                     p_org_id,
                                     i.vas_code,
                                     'vas_comments',
                                     p_user_id,
                                     SYSDATE,
                                     p_user_id,
                                     SYSDATE,
                                     gn_login_id,
                                     i.attribute1,
                                     i.attribute2,
                                     i.attribute3);
                    END LOOP;
              */

            COMMIT;

            x_ret_status   := 'S';
            x_err_msg      := NULL;
        END IF;

        IF P_MODE = 'SINGLEDELETE'
        THEN
            DELETE FROM
                xxd_ont_vas_assignment_dtls_t a
                  WHERE EXISTS
                            (SELECT 1
                               FROM TABLE (p_cust_vas_assign_record) b
                              WHERE     a.cust_account_id = b.cust_account_id
                                    AND a.vas_code = b.vas_code
                                    AND a.attribute_level = b.attribute_level
                                    AND a.attribute_value = b.attribute_value
                                    AND NVL (a.attribute1, 'X') =
                                        NVL (b.attribute1, 'X')       -- style
                                    AND NVL (a.attribute2, 'X') =
                                        NVL (b.attribute2, 'X')          -- mc
                                    AND NVL (a.attribute3, 'X') =
                                        NVL (b.attribute3, 'X')          -- sc
                                    AND NVL (a.attribute4, 'X') =
                                        NVL (b.attribute4, 'X')        -- dept
                                                               );

            COMMIT;
            x_ret_status   := 'S';
            x_err_msg      := NULL;
        END IF;

        IF P_MODE = 'SINGLEINSERT'
        THEN
            MERGE INTO xxd_ont_vas_assignment_dtls_t a
                 USING (SELECT *
                          FROM TABLE (p_cust_vas_assign_record) p_cust_hdr_info_row)
                       b
                    ON (a.cust_account_id = b.cust_account_id AND a.vas_code = b.vas_code AND a.attribute_level = b.attribute_level AND a.attribute_value = b.attribute_value AND NVL (a.attribute1, 'X') = NVL (b.attribute1, 'X') AND NVL (a.attribute2, 'X') = NVL (b.attribute2, 'X') AND NVL (a.attribute3, 'X') = NVL (b.attribute3, 'X') AND NVL (a.attribute4, 'X') = NVL (b.attribute4, 'X') -- ver 1.3
                                                                                                                                                                                                                                                                                                                                                                                                     )
            WHEN MATCHED
            THEN
                UPDATE SET a.vas_comments = b.vas_comments, a.last_updated_by = p_user_id, a.last_updated_date = SYSDATE,
                           a.last_update_login = gn_login_id
            WHEN NOT MATCHED
            THEN
                INSERT     (account_number, cust_account_id, attribute_level,
                            attribute_value, description, entity,
                            org_id, vas_code, vas_comments,
                            created_by, creation_date, last_updated_by,
                            last_updated_date, last_update_login, attribute1,
                            attribute2, attribute3, attribute4      -- ver 1.3
                                                              )
                    VALUES (b.account_number, b.cust_account_id, b.attribute_level, b.attribute_value, b.description, b.entity, b.org_id, b.vas_code, b.vas_comments, p_user_id, SYSDATE, p_user_id, SYSDATE, gn_login_id, b.attribute1
                            , b.attribute2, b.attribute3, b.attribute4 -- ver 1.4
                                                                      );

            COMMIT;
            x_ret_status   := 'S';
            x_err_msg      := NULL;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_status   := 'E';
            x_err_msg      := SUBSTR (SQLERRM, 1, 500);
    END assign_vas_at_site_style_mc_sc_lvl;
-- end ver 1.2

END xxd_ont_vas_customer_pkg;
/
