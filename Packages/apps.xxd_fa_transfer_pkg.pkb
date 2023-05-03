--
-- XXD_FA_TRANSFER_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:30:28 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.xxd_fa_transfer_pkg
AS
    /****************************************************************************************
    * Package      : XXD_FA_TRANSFER_PKG
    * Author       : BT Technology Team
    * Created      : 09-SEP-2014
    * Program Name : Deckers Fixed Asset Transfer - Web ADI
    * Description  : Package used by custom Web ADIs
    *                     1) Mass Asset Adjustments (Transfers)
    *
    * Modification :
    *--------------------------------------------------------------------------------------
    * Date          Developer           Version    Description
    *--------------------------------------------------------------------------------------
    * 09-SEP-2014   BT Technology Team  1.00       Created package body script for FA Transfer
    * 29-SEP-2015   BT Technology Team  1.10       Modified for Defect# 3030
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

    PROCEDURE assets_transfer (p_created_by IN VARCHAR2, p_book_type_code IN VARCHAR2, p_book_type_code_h IN VARCHAR2, p_asset_number IN VARCHAR2, p_asset_number_h IN VARCHAR2 DEFAULT NULL, p_asset_description IN VARCHAR2 DEFAULT NULL, p_asset_category IN VARCHAR2 DEFAULT NULL, p_asset_tag_number IN VARCHAR2 DEFAULT NULL, p_asset_tag_number_h IN VARCHAR2 DEFAULT NULL, p_asset_serial_number IN VARCHAR2 DEFAULT NULL, p_asset_serial_number_h IN VARCHAR2 DEFAULT NULL, p_new_asset_tag_number IN VARCHAR2 DEFAULT NULL, p_new_asset_serial_number IN VARCHAR2 DEFAULT NULL, p_transfer_date IN DATE DEFAULT NULL, p_transfer_description IN VARCHAR2 DEFAULT NULL, p_distribution_id IN NUMBER DEFAULT NULL, p_transfer_units IN NUMBER DEFAULT NULL, p_current_location IN VARCHAR2 DEFAULT NULL, p_current_location_h IN VARCHAR2 DEFAULT NULL, p_new_location IN VARCHAR2 DEFAULT NULL, p_current_custodian IN VARCHAR2 DEFAULT NULL, p_current_custodian_h IN VARCHAR2 DEFAULT NULL, p_employee_number IN NUMBER DEFAULT NULL, p_new_custodian IN VARCHAR2 DEFAULT NULL
                               , p_units_assigned IN NUMBER DEFAULT NULL)
    IS
        /****************************************************************************************
        * Procedure : assets_transfer
        * Design    : Mass Asset Adjustments (Transfers)
        * Notes     :
        * Return Values: None
        * Modification :
        * Date          Developer     Version    Description
        *--------------------------------------------------------------------------------------
        * 07-JUL-2014   BT Technology Team         1.00       Created
        ****************************************************************************************/
        ln_transfer_units         NUMBER;
        l_curr_message            VARCHAR2 (4000) := NULL;
        l_ret_message             VARCHAR2 (4000) := NULL;

        ln_asset_id               fa_additions_b.asset_id%TYPE;
        l_asset_number            fa_additions_b.asset_number%TYPE;
        l_asset_type              fa_additions_b.asset_type%TYPE;
        l_book_type_code          fa_book_controls.book_type_code%TYPE;
        lc_tmp_booktypecode       fa_book_controls.book_type_code%TYPE;

        l_err_msg                 VARCHAR2 (4000);
        ln_api_version   CONSTANT NUMBER := 1.0;
        l_init_msg_list           VARCHAR2 (1) := fnd_api.g_false;
        l_commit                  VARCHAR2 (1) := fnd_api.g_false;
        ln_validation_level       NUMBER := fnd_api.g_valid_level_full;
        l_calling_function        VARCHAR2 (50)
            := 'XXD_FA_TRANSFER_PKG.ASSETS_TRANSFER';
        l_return_status           VARCHAR2 (1) := NULL;
        ln_msg_count              NUMBER := 0;
        l_msg_data                VARCHAR2 (2000) := NULL;
        l_trans_rec_type          fa_api_types.trans_rec_type;
        l_asset_hdr_rec_type      fa_api_types.asset_hdr_rec_type;
        l_asset_dist_tbl          fa_api_types.asset_dist_tbl_type;
        l_asset_desc_rec          fa_api_types.asset_desc_rec_type;
        l_asset_cat_rec           fa_api_types.asset_cat_rec_type;
        l_source_location         VARCHAR2 (100);
        lc_source_account         VARCHAR2 (100);
        ln_source_locationid      NUMBER;
        ln_dest_locationid        NUMBER;
        ln_expense_ccid           NUMBER;
        ln_units_assigned         NUMBER;
        ln_distribution_id        NUMBER;
        ln_distribution_id_new    NUMBER;
        ln_custodian_new          NUMBER;
        ln_location_id_new        NUMBER;
        lv_perform_transfer       VARCHAR2 (1);
        ln_person_id              NUMBER;
        le_webadi_exception       EXCEPTION;
    BEGIN
        lv_perform_transfer                          := 'Y';
        printmessage ('p_created_by: ' || p_created_by);
        printmessage ('p_book_type_code: ' || p_book_type_code_h);
        printmessage ('p_asset_number: ' || p_asset_number_h);
        printmessage ('p_asset_description: ' || p_asset_description);
        printmessage ('p_asset_category: ' || p_asset_category);
        printmessage ('p_asset_tag_number: ' || p_asset_tag_number_h);
        printmessage ('p_asset_serial_number: ' || p_asset_serial_number_h);
        printmessage ('p_new_asset_tag_number: ' || p_new_asset_tag_number);
        printmessage (
            'p_new_asset_serial_number: ' || p_new_asset_serial_number);
        printmessage ('p_transfer_date: ' || p_transfer_date);
        printmessage ('p_transfer_description: ' || p_transfer_description);
        printmessage ('p_distribution_id: ' || p_distribution_id);
        printmessage ('p_transfer_units: ' || p_transfer_units);
        printmessage ('p_current_location: ' || p_current_location_h);
        printmessage ('p_new_location: ' || p_new_location);
        printmessage ('p_current_custodian: ' || p_current_custodian_h);
        printmessage ('p_employee_number: ' || p_employee_number);
        printmessage ('p_new_custodian: ' || p_new_custodian);


        l_asset_number                               := p_asset_number_h;

        l_trans_rec_type.who_info.last_updated_by    := p_created_by;

        IF (l_trans_rec_type.who_info.last_updated_by IS NULL)
        THEN
            l_trans_rec_type.who_info.last_updated_by   := -1;
        END IF;

        IF (l_trans_rec_type.who_info.last_update_login IS NULL)
        THEN
            l_trans_rec_type.who_info.last_update_login   :=
                fnd_global.conc_login_id;
        END IF;

        l_trans_rec_type.who_info.last_update_date   := SYSDATE;
        l_trans_rec_type.who_info.creation_date      :=
            l_trans_rec_type.who_info.last_update_date;
        l_trans_rec_type.who_info.created_by         :=
            l_trans_rec_type.who_info.last_updated_by;
        l_trans_rec_type.transaction_type_code       := NULL;

        l_trans_rec_type.transaction_date_entered    :=
            NVL (p_transfer_date, SYSDATE);
        l_trans_rec_type.transaction_name            :=
            NVL (p_transfer_description, TO_CHAR (NULL));


        IF     p_new_location IS NULL
           AND p_new_custodian IS NULL
           AND p_new_asset_serial_number IS NULL
           AND p_new_asset_tag_number IS NULL
        THEN
            l_curr_message   :=
                'New Tag Number/ New Serial Number/ New Location/ New Custodian is required.';
            l_ret_message   := l_ret_message || l_curr_message;
        END IF;

        -- Validatiing Asset Number
        IF l_asset_number IS NULL
        THEN
            l_curr_message   := 'Asset # is required';
            l_ret_message    := l_ret_message || l_curr_message;
        ELSE
            BEGIN
                SELECT asset_id, asset_type
                  INTO ln_asset_id, l_asset_type
                  FROM fa_additions_b
                 WHERE asset_number = l_asset_number;

                l_asset_hdr_rec_type.asset_id   := ln_asset_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_curr_message   := 'Asset Number is not valid';
                    l_ret_message    := l_ret_message || l_curr_message;
            END;
        END IF;

        -- Validatiing Book
        IF p_book_type_code_h IS NULL
        THEN
            l_curr_message   := 'FA Book (in header) is required';
            l_ret_message    := l_ret_message || l_curr_message;
        ELSE
            BEGIN
                SELECT book_type_code
                  INTO l_book_type_code
                  FROM fa_book_controls
                 WHERE     TRUNC (NVL (date_ineffective, SYSDATE + 1)) >=
                           TRUNC (SYSDATE)
                       AND book_type_code = p_book_type_code_h;

                l_asset_hdr_rec_type.book_type_code   := l_book_type_code;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_curr_message   := 'FA Book is not valid';
                    l_ret_message    := l_ret_message || l_curr_message;
            END;
        END IF;

        --- Fetching Expense CCID
        BEGIN
            ln_distribution_id   := p_distribution_id;

            SELECT code_combination_id, units_assigned, distribution_id,
                   assigned_to, location_id
              INTO ln_expense_ccid, ln_units_assigned, ln_distribution_id_new, ln_custodian_new,
                                  ln_location_id_new
              FROM fa_distribution_history
             WHERE     1 = 1         --   distribution_id = ln_distribution_id
                   AND book_type_code = l_book_type_code
                   AND asset_id = ln_asset_id
                   AND transaction_header_id_out IS NULL;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;



        /*BEGIN
           SELECT distribution_id
             INTO ln_distribution_id_new
             FROM fa_distribution_history
            WHERE  book_type_code = l_book_type_code
                  AND asset_id = ln_asset_id
                  AND transaction_header_id_out IS NULL;
        EXCEPTION
           WHEN OTHERS
           THEN
              NULL;
        END; */

        printmessage ('ln_distribution_id_new ' || ln_distribution_id_new);
        printmessage ('ln_distribution_id ' || ln_distribution_id);

        IF p_transfer_units IS NULL
        THEN
            l_curr_message   := 'Transfer Units is required.';
            l_ret_message    := l_ret_message || l_curr_message;
        END IF;


        IF p_transfer_units IS NOT NULL
        THEN
            IF TRUNC (p_transfer_units) <> p_transfer_units
            THEN
                l_curr_message   := 'Transfer Units has to be in integers.';
                l_ret_message    := l_ret_message || l_curr_message;
            END IF;

            IF ln_units_assigned < p_transfer_units
            THEN
                l_curr_message   :=
                    'Transfer Units must not exceed units available.';
                l_ret_message   := l_ret_message || l_curr_message;
            ELSIF p_transfer_units < 0
            THEN
                l_curr_message   := 'Transfer Units should not be negative.';
                l_ret_message    := l_ret_message || l_curr_message;
            END IF;
        END IF;

        -- Validating Source and Destination  Locations
        IF l_source_location IS NOT NULL OR p_current_location_h IS NOT NULL
        THEN
            l_source_location   := p_current_location_h;

            IF l_source_location IS NULL
            THEN
                l_curr_message   := 'Source Location not Valid';
                l_ret_message    := l_ret_message || l_curr_message;
            ELSE
                BEGIN
                    SELECT location_id
                      INTO ln_source_locationid
                      FROM fa_locations_kfv
                     WHERE     NVL (enabled_flag, 'N') = 'Y'
                           AND TRUNC (SYSDATE) BETWEEN NVL (
                                                           start_date_active,
                                                           SYSDATE - 1)
                                                   AND NVL (end_date_active,
                                                            SYSDATE + 1)
                           AND concatenated_segments = l_source_location;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_curr_message   := 'Source Location is not Valid';
                        l_ret_message    := l_ret_message || l_curr_message;
                END;
            END IF;

            --- Validating New Location
            IF p_new_location IS NOT NULL
            THEN
                BEGIN
                    SELECT location_id
                      INTO ln_dest_locationid
                      FROM fa_locations_kfv
                     WHERE     NVL (enabled_flag, 'N') = 'Y'
                           AND TRUNC (SYSDATE) BETWEEN NVL (
                                                           start_date_active,
                                                           SYSDATE - 1)
                                                   AND NVL (end_date_active,
                                                            SYSDATE + 1)
                           AND location_id = p_new_location;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_curr_message   :=
                               'Destination Location is not Valid'
                            || p_new_location;
                        l_ret_message   := l_ret_message || l_curr_message;
                END;
            END IF;
        END IF;



        --- Fetching Assigned To
        BEGIN
            SELECT person_id
              INTO ln_person_id
              FROM xxd_fa_transfer_emp_v
             WHERE person_id = p_current_custodian;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_person_id   := NULL;
        END;

        --- FA Transfer
        l_asset_dist_tbl.delete;
        l_asset_dist_tbl (1).distribution_id         :=
            ln_distribution_id_new;
        l_asset_dist_tbl (1).transaction_units       :=
            (-1) * (p_transfer_units);
        l_asset_dist_tbl (1).expense_ccid            := ln_expense_ccid;
        l_asset_dist_tbl (1).location_ccid           := ln_source_locationid;
        l_asset_dist_tbl (2).transaction_units       := p_transfer_units;
        l_asset_dist_tbl (2).expense_ccid            := ln_expense_ccid;
        l_asset_dist_tbl (2).location_ccid           :=
            NVL (ln_dest_locationid, ln_source_locationid);
        l_asset_dist_tbl (2).assigned_to             :=
            NVL (p_new_custodian, ln_person_id);


        l_return_status                              := NULL;
        ln_msg_count                                 := 0;
        l_msg_data                                   := NULL;

        printmessage ('Asset(ln_asset_ID): ' || ln_asset_id);
        printmessage ('l_ret_message ' || l_ret_message);
        printmessage ('ln_location_id_new ' || ln_location_id_new);
        printmessage ('ln_custodian_new ' || ln_custodian_new);
        printmessage (
               'l_asset_dist_tbl (2).location_ccid '
            || l_asset_dist_tbl (2).location_ccid);
        printmessage (
               'l_asset_dist_tbl (2).assigned_to '
            || l_asset_dist_tbl (2).assigned_to);
        printmessage ('ln_distribution_id_new ' || ln_distribution_id_new);
        printmessage ('ln_distribution_id ' || ln_distribution_id);
        printmessage ('lv_perform_transfer  ' || lv_perform_transfer);

        IF l_ret_message IS NULL
        THEN
            printmessage ('In  ');

            IF ln_distribution_id_new <> ln_distribution_id
            THEN
                printmessage ('In check ');

                IF     (NVL (ln_location_id_new, l_asset_dist_tbl (2).location_ccid) = l_asset_dist_tbl (2).location_ccid)
                   AND (NVL (ln_custodian_new, l_asset_dist_tbl (2).assigned_to) = l_asset_dist_tbl (2).assigned_to)
                THEN
                    lv_perform_transfer   := 'N';
                END IF;

                printmessage (
                    'lv_perform_transfer 1: ' || lv_perform_transfer);
            END IF;

            IF     (p_new_custodian IS NOT NULL OR p_new_location IS NOT NULL)
               AND lv_perform_transfer = 'Y'
            THEN
                fa_transfer_pub.do_transfer (
                    p_api_version        => ln_api_version,
                    p_init_msg_list      => l_init_msg_list,
                    p_commit             => l_commit,
                    p_validation_level   => ln_validation_level,
                    p_calling_fn         => l_calling_function,
                    x_return_status      => l_return_status,
                    x_msg_count          => ln_msg_count,
                    x_msg_data           => l_msg_data,
                    px_trans_rec         => l_trans_rec_type,
                    px_asset_hdr_rec     => l_asset_hdr_rec_type,
                    px_asset_dist_tbl    => l_asset_dist_tbl);

                printmessage ('Asset Transfer(ln_asset_ID): ' || ln_asset_id);
                printmessage (
                    'Asset Transfer(l_return_status): ' || l_return_status);
                printmessage ('Asset Transfer(l_msg_data): ' || l_msg_data);
                printmessage (
                       'Asset Transfer(l_trans_rec_type.TRANSACTION_HEADER_ID): '
                    || l_trans_rec_type.transaction_header_id);


                IF NVL (l_return_status, 'E') = 'E'
                THEN
                    --l_curr_message :=  fnd_message.get();
                    l_curr_message   :=
                           'Asset Transfer failed - '
                        || 'RET STATUS'
                        || '-'
                        || l_return_status
                        || '-'
                        || l_msg_data;
                    l_ret_message   := l_ret_message || l_curr_message;
                    printmessage (l_ret_message);
                END IF;

                --Error Log
                IF (ln_msg_count > 0)
                THEN
                    l_ret_message   :=
                        SUBSTR (
                            fnd_msg_pub.get (fnd_msg_pub.g_first,
                                             fnd_api.g_false),
                            1,
                            512);

                    FOR i IN 1 .. (ln_msg_count - 1)
                    LOOP
                        l_ret_message   :=
                               l_ret_message
                            || SUBSTR (
                                   fnd_msg_pub.get (fnd_msg_pub.g_next,
                                                    fnd_api.g_false),
                                   1,
                                   512);
                    END LOOP;

                    --Start Modification by BT Tech Team for Defect# 3030 v1.10 on 29-Sep-2015
                    FND_MSG_PUB.Delete_Msg;
                    --End Modification by BT Tech Team for Defect# 3030 v1.10 on 29-Sep-2015
                    printmessage (l_ret_message);
                END IF;
            --End Error Log
            END IF;
        END IF;


        IF l_ret_message IS NULL
        THEN
            IF (p_new_asset_serial_number IS NOT NULL OR p_new_asset_tag_number IS NOT NULL)
            THEN
                --- Update Asset Serial/ Tag Number
                l_asset_desc_rec.serial_number   :=
                    NVL (p_new_asset_serial_number, p_asset_serial_number_h);
                l_asset_desc_rec.tag_number   :=
                    NVL (p_new_asset_tag_number, p_asset_tag_number_h);

                fa_asset_desc_pub.update_desc (
                    p_api_version           => ln_api_version,
                    p_init_msg_list         => l_init_msg_list,
                    p_commit                => l_commit,
                    p_validation_level      => ln_validation_level,
                    x_return_status         => l_return_status,
                    x_msg_count             => ln_msg_count,
                    x_msg_data              => l_msg_data,
                    p_calling_fn            => l_calling_function,
                    px_trans_rec            => l_trans_rec_type,
                    px_asset_hdr_rec        => l_asset_hdr_rec_type,
                    px_asset_desc_rec_new   => l_asset_desc_rec,
                    px_asset_cat_rec_new    => l_asset_cat_rec);

                IF NVL (l_return_status, 'E') = 'E'
                THEN
                    l_curr_message   :=
                           'Updating Asset Tag# and Serial# failed - '
                        || 'RET STATUS'
                        || '-'
                        || l_return_status
                        || '-'
                        || l_msg_data;
                    l_ret_message   := l_ret_message || l_curr_message;
                    printmessage (l_ret_message);
                END IF;

                --Error Log
                IF (ln_msg_count > 0)
                THEN
                    l_ret_message   :=
                        SUBSTR (
                            fnd_msg_pub.get (fnd_msg_pub.g_first,
                                             fnd_api.g_false),
                            1,
                            512);

                    FOR i IN 1 .. (ln_msg_count - 1)
                    LOOP
                        l_ret_message   :=
                               l_ret_message
                            || SUBSTR (
                                   fnd_msg_pub.get (fnd_msg_pub.g_next,
                                                    fnd_api.g_false),
                                   1,
                                   512);
                    END LOOP;

                    printmessage (l_ret_message);
                END IF;
            --End Error Log
            END IF;
        END IF;

        -- If there are errors, throw error as exception
        IF l_ret_message IS NOT NULL
        THEN
            RAISE le_webadi_exception;
        END IF;
    EXCEPTION
        WHEN le_webadi_exception
        THEN
            raise_application_error (-20000, l_ret_message);
        WHEN OTHERS
        THEN
            printmessage (l_err_msg || ' - SQLErrm: ' || SQLERRM);

            l_curr_message   := 'Unhandled Exception ' || SQLERRM;
            l_ret_message    := l_ret_message || l_curr_message;
    END;
END;
/
