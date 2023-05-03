--
-- XXDO_SERIALIZATION  (Package Body) 
--
/* Formatted on 4/26/2023 4:32:17 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_SERIALIZATION"
AS
    lg_package_name   CONSTANT VARCHAR2 (200) := 'XXDO.XXDO_SERIALIZATION';
    lg_enable_debug            NUMBER
        := NVL (
               apps.do_get_profile_value (
                   'DO_DEBUG_XXDO_SERIALIZATION_INTERFACE'),
               1);

    --------------------------------------------------------------------------
    /* PRIVATE PROCEDURES */
    /* added by venkat on 10-MAR-2014 */
    PROCEDURE insert_into_table (p_sn_rec IN sn_rec, x_ret_status OUT NOCOPY VARCHAR2, x_err_msg OUT NOCOPY VARCHAR2);

    PROCEDURE update_table (p_sn_rec IN sn_rec, x_ret_status OUT NOCOPY VARCHAR2, x_err_msg OUT NOCOPY VARCHAR2);

    PROCEDURE validate_asn (p_sn_rec IN sn_rec, x_operation OUT NOCOPY VARCHAR2, x_val_status OUT NOCOPY VARCHAR2
                            , x_err_msg OUT NOCOPY VARCHAR2);

    PROCEDURE validate_initial_entry (p_sn_rec IN sn_rec, x_operation OUT NOCOPY VARCHAR2, x_val_status OUT NOCOPY VARCHAR2
                                      , x_err_msg OUT NOCOPY VARCHAR2);

    PROCEDURE validate_mobile_update (p_sn_rec IN sn_rec, x_operation OUT NOCOPY VARCHAR2, x_val_status OUT NOCOPY VARCHAR2
                                      , x_err_msg OUT NOCOPY VARCHAR2);

    PROCEDURE validate_pick_load (p_sn_rec IN OUT NOCOPY sn_rec, x_operation OUT NOCOPY VARCHAR2, x_val_status OUT NOCOPY VARCHAR2
                                  , x_err_msg OUT NOCOPY VARCHAR2);

    PROCEDURE validate_rma_return (p_sn_rec IN sn_rec, x_operation OUT NOCOPY VARCHAR2, x_val_status OUT NOCOPY VARCHAR2
                                   , x_err_msg OUT NOCOPY VARCHAR2);


    PROCEDURE validate_unpack_lpn (p_sn_rec IN sn_rec, x_operation OUT NOCOPY VARCHAR2, x_val_status OUT NOCOPY VARCHAR2
                                   , x_err_msg OUT NOCOPY VARCHAR2);

    /* PRIVATE FUNCTIONS */
    FUNCTION soa_update_req_check (p_serial_number IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION validate_status_id (p_status_id IN NUMBER)
        RETURN NUMBER;

    /* end of changes */
    --------------------------------------------------------------------------

    PROCEDURE msg (p_msg VARCHAR2, p_level NUMBER:= 1)
    IS
        l_pn   CONSTANT VARCHAR2 (200) := lg_package_name || '.msg';
    BEGIN
        IF lg_enable_debug = 1 OR g_debug_pick = 1 OR p_level < 1
        THEN
            apps.do_debug_tools.msg (p_msg, p_level);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            BEGIN
                apps.do_debug_tools.msg (
                    SUBSTR ('Debug Error: ' || SQLERRM, 1, 200),
                    0);
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
    END;

    PROCEDURE debug_on
    IS
        l_pn   CONSTANT VARCHAR2 (200) := lg_package_name || '.debug_on';
    BEGIN
        msg ('+' || l_pn);
        --  do_debug_tools.enable_dbms(1000000);
        apps.do_debug_tools.enable_conc_log (1000000);
        apps.do_debug_tools.enable_table (10000000);
        msg ('-' || l_pn);
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('-' || l_pn);
    END;

    PROCEDURE output_msg (MESSAGE VARCHAR2, p_email_results NUMBER)
    IS
        l_pn   CONSTANT VARCHAR2 (200) := lg_package_name || '.output_msg';
        x               NUMBER;
    BEGIN
        msg (MESSAGE, -1);
        apps.FND_FILE.PUT_LINE (apps.FND_FILE.output, MESSAGE);

        IF p_email_results = 1
        THEN
            apps.do_mail_utils.send_mail_line (MESSAGE, x);
        END IF;
    END;

    PROCEDURE insert_into_table (p_sn_rec IN sn_rec, x_ret_status OUT NOCOPY VARCHAR2, x_err_msg OUT NOCOPY VARCHAR2)
    IS
        p_sn_rec1   sn_rec;
    BEGIN
        p_sn_rec1      := p_sn_rec;
        x_ret_status   := G_RET_SUCCESS;

        BEGIN
            IF p_sn_rec1.source_code = 'INITIAL_ENTRY'
            THEN
                IF p_sn_rec1.lpn_id IS NULL
                THEN
                    p_sn_rec1.lpn_id   :=
                        apps.LPN_TO_LPNID (p_sn_rec1.license_plate_number);
                ELSIF p_sn_rec1.license_plate_number IS NULL
                THEN
                    p_sn_rec1.license_plate_number   :=
                        apps.LPNID_TO_LPN (p_sn_rec1.lpn_id);
                END IF;
            -- p_sn_rec1.source_code_reference:=NULL;
            ELSIF p_sn_rec1.source_code IN ('FACTORY_ASN', 'RMA_RETURN')
            THEN
                p_sn_rec1.soa_event         := NULL;
                p_sn_rec1.soa_status        := NULL;
                p_sn_rec1.soa_update_date   := NULL;
            END IF;
        END;

        INSERT INTO XXDO.XXDO_SERIAL_TEMP (SERIAL_NUMBER, LPN_ID, LICENSE_PLATE_NUMBER, INVENTORY_ITEM_ID, ORGANIZATION_ID, LAST_UPDATE_DATE, LAST_UPDATED_BY, CREATION_DATE, CREATED_BY, STATUS_ID, SOURCE_CODE, SOURCE_CODE_REFERENCE
                                           , PRODUCT_QR_CODE)
             VALUES (p_sn_rec1.serial_number, p_sn_rec1.lpn_id, p_sn_rec1.license_plate_number, p_sn_rec1.inventory_item_id, p_sn_rec1.organization_id, SYSDATE, NVL (p_sn_rec1.LAST_UPDATED_BY, apps.fnd_global.user_id), --get from fnd_users
                                                                                                                                                                                                                           SYSDATE, apps.fnd_global.user_id, p_sn_rec1.status_id, p_sn_rec1.source_code, p_sn_rec1.source_code_reference
                     , p_sn_rec1.product_qr_code);
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_status   := G_RET_ERROR;
            x_err_msg      := 'Error in Insert Serial Temp -' || SQLERRM;
            msg (x_err_msg);
    END;

    -- PROCEDURE TO VERIFY WHETHER THE PASSED QR CODE IS VALID,
    -- IS ASSOCIATED WITH AN A-GRADE PRODUCT AND EXISTS IN THE
    -- SERIAL TEMP TABLE
    PROCEDURE qr_verify (p_qrcode               VARCHAR2,
                         x_ret_stat         OUT VARCHAR2,
                         x_message          OUT VARCHAR2,
                         x_sn               OUT VARCHAR2,
                         x_item_id          OUT NUMBER,
                         x_current_status   OUT VARCHAR2)
    IS
        -- TEMP VARIABLES
        l_qrcode     xxdo.xxdo_serial_temp.serial_number%TYPE := NULL;
        l_location   VARCHAR2 (30);
        l_item_id    VARCHAR2 (30);
        l_status     xxdo.xxdo_serial_temp.status_id%TYPE;
    BEGIN
        -- Check whether the passed QR code is null.
        -- If yes, exit
        -- Otherwise, strip extra leading characters
        IF p_qrcode IS NOT NULL
        THEN
            -- A QR code may contain the URL characters "http://" or "WWW." before the number itself
            -- This API strips the forward slashes and returns only the QR Code
            l_qrcode   :=
                XXDO_WMS_QR_PROCESSING_API.qr_http_strip_fnc (p_qrcode);
        ELSE
            x_sn               := NULL;
            x_item_id          := NULL;
            x_current_status   := NULL;
            x_message          := 'No QR code passed: ' || SQLERRM;
            msg (x_message);
            x_ret_Stat         := g_ret_unexp_error;
            msg (' - No QR code passed. - ');
            RETURN;
        END IF;

        IF l_qrcode IS NOT NULL
        THEN                 -- if the strip function returned a serial number
            -- OLD QUERY
            --      select serial_number, apps.lid_to_loc(msn.current_locator_id
            --      , msn.owning_organization_id) location, apps.iid_to_sku(msn.inventory_item_id) sku
            --      , current_status  into l_qrcode, l_location, l_sku, l_status  from apps.mtl_serial_numbers msn where serial_number =  nvl(l_qrcode,p_qrcode)  ;

            SELECT serial_number, NULL location, xts.inventory_item_id item_id,
                   status_id current_status
              INTO l_qrcode, l_location, l_item_id, l_status
              FROM xxdo.xxdo_serial_temp xts
             WHERE serial_number = l_qrcode; -- Sample QR Code/Serial Number '990000000000241303'

            --and status_id = 1; -- Status = 1 means we are looking for Grade A product only

            -- Status = 1 means we are looking for Grade A product only
            IF l_status = 1
            THEN
                x_sn               := l_qrcode;
                x_item_id          := l_item_id;
                x_current_status   := l_status;
                x_ret_Stat         := G_RET_SUCCESS;
                x_message          := ('Success');
            ELSE -- For any other type of status (either B-Grade product (ID 3) or C Grade (ID 9)), we return that the SN is invalid even if it exists in our temp table
                x_sn               := NULL;
                x_item_id          := NULL;
                x_current_status   := NULL;
                x_message          := 'Invalid SN. Status ' || l_status;
                msg (x_message);
                x_ret_Stat         := G_RET_WARNING;
                msg ('- Invalid Serial Number - ' || p_qrcode);
            END IF;
        ELSE       -- if the strip function could not return any serial number
            x_sn               := NULL;
            x_item_id          := NULL;
            x_current_status   := NULL;
            x_message          := 'Serial Number not found. ' || SQLERRM;
            msg (x_message);
            x_ret_Stat         := G_RET_ERROR;
            msg (
                   '- XXDO_WMS_QR_PROCESSING_API.qr_http_strip_fnc did not return any QR code - '
                || p_qrcode);
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_sn               := NULL;
            x_item_id          := NULL;
            x_current_status   := NULL;
            x_message          := 'SN not found.';
            msg (x_message);
            x_ret_Stat         := G_RET_ERROR;
            msg (
                   ' - Did not pull QR information back  - '
                || p_qrcode
                || ' - '
                || SQLERRM);
            RETURN;
        WHEN OTHERS
        THEN
            x_sn               := NULL;
            x_item_id          := NULL;
            x_current_status   := NULL;
            x_message          :=
                'EXCEPTION: Unexpected exception - ' || SQLERRM;
            msg (x_message);
            x_ret_Stat         := g_ret_unexp_error;
            msg (' - Did not pull QR information back  - ' || p_qrcode);
            RAISE;
    END qr_verify;


    PROCEDURE SET_SN_TO_LPN (p_sn                IN     SN,
                             p_lpn               IN     VARCHAR2,
                             p_organization_id          NUMBER,
                             x_ret_stat             OUT VARCHAR2,
                             x_message              OUT VARCHAR2)
    IS
        l_proc_name     VARCHAR2 (80)
                            := lg_package_name || '.SET_SN_TO_LPN (p_sn)';
        sn_rec          apps.xxdo_serialization.sn_rec;
        l_debug_level   NUMBER := 0;
    BEGIN
        -- YK@DECKERS
        -- CCR0002662 to remove the previous association of an LPN with the serial numbers
        UPDATE XXDO.XXDO_SERIAL_TEMP XST
           SET XST.LPN_ID = NULL, XST.LICENSE_PLATE_NUMBER = NULL, XST.SOURCE_CODE = 'MOBILE_UPDATE',
               XST.SOURCE_CODE_REFERENCE = NULL, XST.LAST_UPDATE_DATE = SYSDATE, XST.LAST_UPDATED_BY = APPS.FND_GLOBAL.USER_ID
         WHERE XST.LPN_ID = LPN_TO_LPNID (P_LPN);

        FOR i IN 1 .. p_sn.COUNT
        LOOP
            msg ('Setting SN ' || p_sn (i) || ' to lpn' || p_lpn);


            sn_rec.serial_number          := p_sn (i);
            sn_rec.lpn_id                 := lpn_to_lpnid (p_lpn);
            sn_rec.license_plate_number   := p_lpn;
            sn_rec.organization_id        := p_organization_id;
            sn_rec.source_code            := 'MOBILE_UPDATE';

            -- Call the update_serial_temp API to insert/update the xxdo_serial_temp table
            apps.xxdo_serialization.update_serial_temp (sn_rec, l_debug_level, x_ret_stat
                                                        , x_message);
        END LOOP;

        msg ('Updated SN succefully');
        x_ret_Stat   := g_ret_success;
        x_message    := ('Success');
        COMMIT;
        RETURN;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_message    := 'Unhandled exception: ' || SQLERRM;
            msg (x_message);
            x_ret_Stat   := g_ret_unexp_error;
            msg ('- Did not update  - ' || p_lpn);
            ROLLBACK;
            RETURN;
    END;

    /* added by venkat on 10-Mar-2014*/
    PROCEDURE update_serial_temp (p_sn_rec IN sn_rec, p_debug_level IN NUMBER:= 0, x_return_status OUT VARCHAR2
                                  , x_error_message OUT VARCHAR2)
    IS
        l_val_status   VARCHAR2 (1);                        --:=G_RET_SUCCESS;
        lv_operation   VARCHAR2 (10);
        l_err_msg      VARCHAR2 (2000);
        lv_src_code    xxdo.xxdo_serial_temp.source_code%TYPE;
        lv_null        VARCHAR2 (10);
        p_sn_rec1      sn_rec;
    BEGIN
        p_sn_rec1         := p_sn_rec;
        x_return_status   := G_RET_SUCCESS;

        --Source code Validation
        BEGIN
            SELECT NULL
              INTO lv_null
              FROM apps.fnd_lookup_values flv
             WHERE     flv.lookup_type = 'XXDO_SERIAL_TEMP_SOURCE_CODE'
                   AND flv.LANGUAGE = USERENV ('LANG')
                   AND NVL (flv.enabled_flag, 'N') = 'Y'
                   AND flv.lookup_code = p_sn_rec1.source_code;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                x_return_status   := G_RET_ERROR;
                x_error_message   := 'Invalid Source Code';
            WHEN OTHERS
            THEN
                x_return_status   := G_RET_ERROR;
                x_error_message   :=
                    'Error in Source Code Validation -' || SQLERRM;
                msg (x_error_message);
        END;

        -- Serial Number Length Validation
        IF     p_sn_rec1.serial_number IS NOT NULL
           AND LENGTH (NVL (p_sn_rec1.serial_number, 1)) NOT IN (16, 18)
        THEN
            x_return_status   := G_RET_ERROR;
            x_error_message   := x_error_message || 'Invalid serial number';
            msg (x_error_message);
        END IF;

        --validating last_update_by
        IF p_sn_rec1.last_updated_by IS NOT NULL
        THEN
            BEGIN
                SELECT NULL
                  INTO lv_null
                  FROM apps.fnd_user fu
                 WHERE fu.user_id = p_sn_rec1.last_updated_by;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    x_return_status   := G_RET_ERROR;
                    x_error_message   := x_error_message || 'Invalid user_id';
                    msg (x_error_message);
                WHEN OTHERS
                THEN
                    x_return_status   := G_RET_ERROR;
                    x_error_message   :=
                           x_error_message
                        || 'Error in validating user_id -'
                        || SQLERRM;
                    msg (x_error_message);
            END;
        END IF;

        IF x_return_status <> G_RET_ERROR
        THEN
            IF p_sn_rec1.source_code = 'RMA_RETURN'
            THEN
                validate_rma_return (p_sn_rec => p_sn_rec1, x_operation => lv_operation, x_val_status => l_val_status
                                     , x_err_msg => l_err_msg);
            ELSIF p_sn_rec1.source_code = 'FACTORY_ASN'
            THEN
                validate_asn (p_sn_rec => p_sn_rec1, x_operation => lv_operation, x_val_status => l_val_status
                              , x_err_msg => l_err_msg);
            ELSIF p_sn_rec1.source_code = 'PICK_LOAD'
            THEN
                validate_pick_load (p_sn_rec => p_sn_rec1, x_operation => lv_operation, x_val_status => l_val_status
                                    , x_err_msg => l_err_msg);
            ELSIF p_sn_rec1.source_code = 'UNPACK_LPN'
            THEN
                validate_unpack_lpn (p_sn_rec => p_sn_rec1, x_operation => lv_operation, x_val_status => l_val_status
                                     , x_err_msg => l_err_msg);
            ELSIF p_sn_rec1.source_code = 'INITIAL_ENTRY'
            THEN
                validate_initial_entry (p_sn_rec => p_sn_rec1, x_operation => lv_operation, x_val_status => l_val_status
                                        , x_err_msg => l_err_msg);
            ELSIF p_sn_rec1.source_code = 'MOBILE_UPDATE'
            THEN
                validate_mobile_update (p_sn_rec => p_sn_rec1, x_operation => lv_operation, x_val_status => l_val_status
                                        , x_err_msg => l_err_msg);
            END IF;

            IF lv_operation = 'UPDATE' AND l_val_status <> G_RET_ERROR
            THEN
                update_table (p_sn_rec       => p_sn_rec1,
                              x_ret_status   => l_val_status,
                              x_err_msg      => l_err_msg);
            ELSIF lv_operation = 'INSERT' AND l_val_status <> G_RET_ERROR
            THEN
                insert_into_table (p_sn_rec       => p_sn_rec1,
                                   x_ret_status   => l_val_status,
                                   x_err_msg      => l_err_msg);
            END IF;

            IF l_val_status = G_RET_SUCCESS
            THEN
                x_return_status   := G_RET_SUCCESS;
            ELSE
                x_return_status   := G_RET_ERROR;
                x_error_message   := x_error_message || ' ' || l_err_msg;
                msg (x_error_message);
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_return_status   := G_RET_ERROR;
            x_error_message   :=
                'Error occured in Update Temp table Procedure';
            msg (x_error_message);
    END;

    PROCEDURE update_table (p_sn_rec IN sn_rec, x_ret_status OUT NOCOPY VARCHAR2, x_err_msg OUT NOCOPY VARCHAR2)
    IS
        TYPE cur_type IS REF CURSOR;

        s_rec          cur_type;
        query_str      VARCHAR2 (2000) := 'SELECT * FROM xxdo.xxdo_serial_temp';
        sn_rec_out     xxdo.xxdo_serial_temp%ROWTYPE;
        ln_rows_updt   NUMBER := 0;
        p_sn_record    sn_rec;
    BEGIN
        x_ret_status   := G_RET_SUCCESS;

        IF p_sn_rec.source_code = 'UNPACK_LPN'
        THEN
            IF     p_sn_rec.lpn_id IS NULL
               AND p_sn_rec.license_plate_number IS NOT NULL
            THEN
                query_str   :=
                       query_str
                    || ' '
                    || 'WHERE NVL(lpn_id,1)  =DECODE(:lpn_id ,NULL, NVL(lpn_id,1),NVL(lpn_id,1)) AND license_plate_number = :license_plate_number';
            ELSIF     p_sn_rec.license_plate_number IS NULL
                  AND p_sn_rec.lpn_id IS NOT NULL
            THEN
                query_str   :=
                       query_str
                    || ' '
                    || 'WHERE lpn_id =:lpn_id AND DECODE(:license_plate_number,NULL,NVL(license_plate_number,1),NVL(license_plate_number,1)) = NVL(:license_plate_number,1)';
            ELSIF     p_sn_rec.lpn_id IS NOT NULL
                  AND p_sn_rec.license_plate_number IS NOT NULL
            THEN
                query_str   :=
                       query_str
                    || ' '
                    || 'WHERE lpn_id =:lpn_id AND license_plate_number =:license_plate_number';
            END IF;

            OPEN s_rec FOR query_str USING p_sn_rec.lpn_id, p_sn_rec.license_plate_number;

            LOOP
                FETCH s_rec INTO sn_rec_out;

                IF soa_update_req_check (sn_rec_out.serial_number) = 'Y'
                THEN
                    sn_rec_out.soa_event         := p_sn_rec.soa_event;
                    sn_rec_out.soa_status        := 'P';
                    sn_rec_out.SOA_UPDATE_DATE   := SYSDATE;
                ELSE
                    sn_rec_out.soa_event         := NULL;
                    sn_rec_out.soa_status        := NULL;
                    sn_rec_out.SOA_UPDATE_DATE   := NULL;
                END IF;

                UPDATE xxdo.xxdo_serial_temp xst
                   SET xst.lpn_id = NULL, xst.license_plate_number = NULL, xst.source_code = p_sn_rec.source_code,
                       xst.SOURCE_CODE_REFERENCE = NULL, xst.SOA_EVENT = sn_rec_out.soa_event, xst.SOA_STATUS = sn_rec_out.soa_status,
                       xst.SOA_UPDATE_DATE = sn_rec_out.soa_update_date
                 WHERE xst.SERIAL_NUMBER = sn_rec_out.serial_number;

                EXIT WHEN s_rec%NOTFOUND;
            END LOOP;

            ln_rows_updt   := SQL%ROWCOUNT;

            CLOSE s_rec;

            x_err_msg      := ln_rows_updt || '- Rows Updated';
            msg (x_err_msg);
        ELSIF p_sn_rec.source_code = 'MOBILE_UPDATE'
        THEN
            IF p_sn_rec.serial_number IS NOT NULL
            THEN
                query_str   :=
                       query_str
                    || ' '
                    || 'WHERE serial_number  =:serial_number';
            END IF;

            OPEN s_rec FOR query_str USING p_sn_rec.serial_number;

            LOOP
                FETCH s_rec INTO sn_rec_out;

                IF soa_update_req_check (sn_rec_out.serial_number) = 'Y'
                THEN
                    sn_rec_out.soa_event         := 'ContainerPack';
                    sn_rec_out.soa_status        := 'P';
                    sn_rec_out.SOA_UPDATE_DATE   := SYSDATE;
                ELSE
                    sn_rec_out.soa_event         := NULL;
                    sn_rec_out.soa_status        := NULL;
                    sn_rec_out.SOA_UPDATE_DATE   := NULL;
                END IF;

                UPDATE xxdo.xxdo_serial_temp xst
                   SET xst.lpn_id = NVL (p_sn_rec.lpn_id, apps.lpn_to_lpnid (p_sn_rec.license_plate_number)), xst.license_plate_number = NVL (p_sn_rec.license_plate_number, apps.lpnid_to_lpn (p_sn_rec.lpn_id)), xst.source_code = p_sn_rec.source_code,
                       xst.SOURCE_CODE_REFERENCE = NULL, xst.SOA_EVENT = sn_rec_out.soa_event, xst.SOA_STATUS = sn_rec_out.soa_status,
                       xst.SOA_UPDATE_DATE = sn_rec_out.soa_update_date, xst.LAST_UPDATE_DATE = SYSDATE, xst.LAST_UPDATED_BY = NVL (p_sn_rec.last_updated_by, apps.fnd_global.user_id)
                 WHERE xst.SERIAL_NUMBER = p_sn_rec.serial_number;

                EXIT WHEN s_rec%NOTFOUND;
            END LOOP;

            ln_rows_updt   := SQL%ROWCOUNT;

            CLOSE s_rec;

            x_err_msg      := ln_rows_updt || '- Rows Updated';
            msg (x_err_msg);
        ELSIF p_sn_rec.source_code = 'RMA_RETURN'
        THEN
            UPDATE xxdo.xxdo_serial_temp xst
               SET xst.source_code = p_sn_rec.source_code, xst.source_code_reference = p_sn_rec.source_code_reference, xst.soa_event = NULL,
                   xst.soa_status = NULL, xst.status_id = 1, xst.soa_message_text = NULL,
                   xst.soa_update_date = NULL, xst.last_update_date = SYSDATE, xst.last_updated_by = NVL (p_sn_rec.last_updated_by, apps.fnd_global.user_id),
                   xst.product_qr_code = NULL
             WHERE xst.serial_number = p_sn_rec.serial_number;

            ln_rows_updt   := SQL%ROWCOUNT;
            x_err_msg      := ln_rows_updt || '- Rows Updated';
            msg (x_err_msg);
        ELSIF p_sn_rec.source_code = 'PICK_LOAD'
        THEN
            p_sn_record    := p_sn_rec;

            IF soa_update_req_check (p_sn_rec.serial_number) = 'Y'
            THEN
                p_sn_record.soa_event         := 'ContainerPack';
                p_sn_record.soa_status        := 'P';
                p_sn_record.soa_update_date   := SYSDATE;
            ELSE
                p_sn_record.soa_event         := NULL;
                p_sn_record.soa_status        := NULL;
                p_sn_record.soa_update_date   := NULL;
            END IF;

            UPDATE xxdo.xxdo_serial_temp xst
               SET xst.last_updated_by = NVL (p_sn_rec.last_updated_by, apps.fnd_global.user_id), xst.last_update_date = SYSDATE, xst.lpn_id = p_sn_rec.lpn_id,
                   xst.license_plate_number = p_sn_rec.license_plate_number, xst.source_code = p_sn_rec.source_code, xst.source_code_reference = p_sn_rec.source_code_reference,
                   xst.soa_event = p_sn_record.soa_event, xst.soa_status = p_sn_record.soa_status, xst.soa_update_date = p_sn_record.soa_update_date
             WHERE xst.serial_number = p_sn_rec.serial_number;

            ln_rows_updt   := SQL%ROWCOUNT;
            x_err_msg      := ln_rows_updt || '- Rows Updated';
            msg (x_err_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_status   := G_RET_ERROR;
            x_err_msg      := 'Error to update Record-' || SQLERRM;
            msg (x_err_msg);
    END;

    PROCEDURE validate_asn (p_sn_rec IN sn_rec, x_operation OUT NOCOPY VARCHAR2, x_val_status OUT NOCOPY VARCHAR2
                            , x_err_msg OUT NOCOPY VARCHAR2)
    IS
        --ln_line_loc_id  apps.po_line_locations_all.line_location_id%TYPE;
        ln_item_id      apps.mtl_system_items_b.inventory_item_id%TYPE;
        lv_carton_num   custom.do_cartons.carton_number%TYPE;
        lv_null         VARCHAR2 (10);
        ln_sn_cnt       NUMBER := 0;
    BEGIN
        x_val_status   := G_RET_SUCCESS;

        --Serial Number Validation at serial temp table (Serial Number should not exist)
        BEGIN
            SELECT COUNT (1)
              INTO ln_sn_cnt
              FROM xxdo.xxdo_serial_temp stp
             WHERE stp.serial_number = p_sn_rec.serial_number;
        EXCEPTION
            WHEN OTHERS
            THEN
                x_val_status   := G_RET_ERROR;
                x_err_msg      :=
                    'Error at  serial number Validation for FACTORY_ASN';
                msg (x_err_msg);
        END;

        IF ln_sn_cnt = 0
        THEN
            x_val_status   := G_RET_SUCCESS;
        ELSE
            x_val_status   := G_RET_ERROR;
            x_err_msg      :=
                'serial number Already Exist in serial temp table';
        END IF;

        IF x_val_status <> G_RET_ERROR
        THEN
            -- Source Code Reference Validation
            BEGIN
                SELECT NULL
                  INTO lv_null
                  FROM apps.po_line_locations_all pll
                 WHERE pll.line_location_id =
                       TO_NUMBER (p_sn_rec.source_code_reference);
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    x_val_status   := G_RET_ERROR;
                    x_err_msg      := 'Invalid source code reference';
                    msg (x_err_msg);
                WHEN OTHERS
                THEN
                    x_val_status   := G_RET_ERROR;
                    x_err_msg      :=
                        'Invalid source code reference-' || SQLERRM;
                    msg (x_err_msg);
            END;
        END IF;

        IF x_val_status <> G_RET_ERROR
        THEN
            --Inventory_item_id and organization_id validation
            BEGIN
                SELECT DISTINCT pl.ITEM_ID
                  INTO ln_item_id
                  FROM apps.po_line_locations_all pll, apps.po_lines_all pl
                 WHERE     pll.PO_LINE_ID = pl.PO_LINE_ID
                       AND pl.ITEM_ID = p_sn_rec.inventory_item_id
                       AND pll.SHIP_TO_ORGANIZATION_ID =
                           p_sn_rec.organization_id
                       AND pll.line_location_id =
                           TO_NUMBER (p_sn_rec.source_code_reference);
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    x_val_status   := G_RET_ERROR;
                    x_err_msg      :=
                        'Invalid inventory_item_id or organization_id';
                    msg (x_err_msg);
                WHEN TOO_MANY_ROWS
                THEN
                    NULL;
                WHEN OTHERS
                THEN
                    x_val_status   := G_RET_ERROR;
                    x_err_msg      :=
                        'Error in inventory_item_id or organization_id validation';
                    msg (x_err_msg);
            END;
        END IF;

        IF x_val_status <> G_RET_ERROR
        THEN
            IF p_sn_rec.license_plate_number IS NOT NULL
            THEN
                --Carton Number Validation
                BEGIN
                    SELECT DISTINCT dc.carton_number
                      INTO lv_carton_num
                      FROM custom.do_cartons dc
                     WHERE     dc.carton_number =
                               p_sn_rec.license_plate_number
                           AND dc.item_id = p_sn_rec.inventory_item_id
                           AND dc.organization_id = p_sn_rec.organization_id
                           AND dc.line_location_id =
                               TO_NUMBER (p_sn_rec.source_code_reference);
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        x_val_status   := G_RET_ERROR;
                        x_err_msg      := 'Invalid Carton Number';
                        msg (x_err_msg);
                    WHEN TOO_MANY_ROWS
                    THEN
                        NULL;
                    WHEN OTHERS
                    THEN
                        x_val_status   := G_RET_ERROR;
                        x_err_msg      :=
                               'Error in Carton Number Validation msg-'
                            || SQLERRM;
                        msg (x_err_msg);
                END;
            ELSE
                x_val_status   := G_RET_ERROR;
                x_err_msg      := 'Carton Number can not be null';
                msg (x_err_msg);
            END IF;
        END IF;

        IF x_val_status <> G_RET_ERROR
        THEN
            x_operation   := 'INSERT';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_val_status   := G_RET_ERROR;
            x_err_msg      := 'Error at FACTORY_ASN Validation' || SQLERRM;
            msg (x_err_msg);
    END;                                                        --Validate_asn

    PROCEDURE validate_pick_load (p_sn_rec IN OUT NOCOPY sn_rec, x_operation OUT NOCOPY VARCHAR2, x_val_status OUT NOCOPY VARCHAR2
                                  , x_err_msg OUT NOCOPY VARCHAR2)
    IS
        lv_null   VARCHAR2 (10);
    BEGIN
        x_val_status   := G_RET_SUCCESS;

        --Serial Number Validation at serial temp table(Must Exist)
        BEGIN
            SELECT NULL
              INTO lv_null
              FROM xxdo.xxdo_serial_temp stp
             WHERE stp.serial_number = p_sn_rec.serial_number;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                x_val_status   := G_RET_ERROR;
                x_err_msg      := 'Invalid Serial Number';
                msg (x_err_msg);
            WHEN OTHERS
            THEN
                x_val_status   := G_RET_ERROR;
                x_err_msg      :=
                    'Error at  serial number Validation for PICK_LOAD';
                msg (x_err_msg);
        END;

        --Validate Inventory_item_id
        IF x_val_status <> G_RET_ERROR
        THEN
            IF p_sn_rec.inventory_item_id IS NOT NULL
            THEN
                BEGIN
                    SELECT NULL
                      INTO lv_null
                      FROM xxdo.xxdo_serial_temp stp
                     WHERE     stp.inventory_item_id =
                               p_sn_rec.inventory_item_id
                           AND stp.serial_number = p_sn_rec.serial_number;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        x_val_status   := G_RET_ERROR;
                        x_err_msg      := 'Invalid Inventory_item_id';
                        msg (x_err_msg);
                    WHEN OTHERS
                    THEN
                        x_val_status   := G_RET_ERROR;
                        x_err_msg      :=
                               'Error at inventory_item_id Validation err msg-'
                            || SQLERRM;
                        msg (x_err_msg);
                END;
            END IF;
        END IF;

        --Validate source Code Reference
        IF x_val_status <> G_RET_ERROR
        THEN
            BEGIN
                SELECT NULL
                  INTO lv_null
                  FROM apps.mtl_material_transactions_temp mmtt
                 WHERE     mmtt.organization_id =
                           NVL (p_sn_rec.organization_id, 7)
                       AND mmtt.inventory_item_id =
                           p_sn_rec.inventory_item_id
                       AND mmtt.transaction_temp_id =
                           TO_NUMBER (p_sn_rec.source_code_reference);
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    x_val_status   := G_RET_ERROR;
                    x_err_msg      := 'Invalid source code reference ';
                    msg (x_err_msg);
                WHEN TOO_MANY_ROWS
                THEN
                    NULL;
                WHEN OTHERS
                THEN
                    x_val_status   := G_RET_ERROR;
                    x_err_msg      :=
                        'Invalid source code reference-' || SQLERRM;
                    msg (x_err_msg);
            END;
        END IF;

        --Validate Status Id
        IF x_val_status <> G_RET_ERROR
        THEN
            BEGIN
                SELECT NULL
                  INTO lv_null
                  FROM xxdo.xxdo_serial_temp xst
                 WHERE     xst.serial_number = p_sn_rec.serial_number
                       AND xst.inventory_item_id = p_sn_rec.inventory_item_id
                       AND xst.status_id = 1;
            --IF validate_status_id(p_sn_rec.status_id)=0
            --THEN
            --  x_val_status :=G_RET_ERROR;
            --  x_err_msg    :='Invalid status_id';
            --END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    x_val_status   := G_RET_ERROR;
                    x_err_msg      := 'Invalid status_id';
                    msg (x_err_msg);
                WHEN OTHERS
                THEN
                    x_val_status   := G_RET_ERROR;
                    x_err_msg      := 'Invalid status_id';
                    msg (x_err_msg);
            END;
        END IF;

        IF x_val_status <> G_RET_ERROR
        THEN
            x_operation   := 'UPDATE';
        END IF;

        --Validate LPN or LPN_ID
        IF p_sn_rec.license_plate_number IS NULL AND p_sn_rec.lpn_id IS NULL
        THEN
            x_val_status   := G_RET_ERROR;
            x_err_msg      := 'LPN_ID or License_plate_number Required';
            msg (x_err_msg);
        ELSIF p_sn_rec.license_plate_number IS NULL
        THEN
            BEGIN
                SELECT wlp.license_plate_number
                  INTO p_sn_rec.license_plate_number
                  FROM apps.wms_license_plate_numbers wlp
                 WHERE wlp.lpn_id = p_sn_rec.lpn_id;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    x_val_status   := G_RET_ERROR;
                    x_err_msg      := 'Invalid LPN_ID';
                    msg (x_err_msg);
                WHEN OTHERS
                THEN
                    x_val_status   := G_RET_ERROR;
                    x_err_msg      := 'Error validating LPN_ID -' || SQLERRM;
                    msg (x_err_msg);
            END;
        ELSIF p_sn_rec.lpn_id IS NULL
        THEN
            BEGIN
                SELECT wlp.lpn_id
                  INTO p_sn_rec.lpn_id
                  FROM apps.wms_license_plate_numbers wlp
                 WHERE wlp.license_plate_number =
                       p_sn_rec.license_plate_number;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    x_val_status   := G_RET_ERROR;
                    x_err_msg      := 'Invalid LICENSE_PLATE_NUMBER';
                    msg (x_err_msg);
                WHEN OTHERS
                THEN
                    x_val_status   := G_RET_ERROR;
                    x_err_msg      :=
                           'Error while validating LICENSE_PLATE_NUMBER -'
                        || SQLERRM;
                    msg (x_err_msg);
            END;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_val_status   := G_RET_ERROR;
            x_err_msg      := 'Error at pick load validation-' || SQLERRM;
            msg (x_err_msg);
    END;

    PROCEDURE validate_rma_return (p_sn_rec IN sn_rec, x_operation OUT NOCOPY VARCHAR2, x_val_status OUT NOCOPY VARCHAR2
                                   , x_err_msg OUT NOCOPY VARCHAR2)
    IS
        -- lv_src_ref  apps.oe_order_lines.line_id%TYPE;
        -- ln_item_id  apps.oe_order_lines.INVENTORY_ITEM_ID%TYPE;
        lv_null   VARCHAR2 (10);
    BEGIN
        x_val_status   := G_RET_SUCCESS;

        --RMA Line Id Validation
        BEGIN
            SELECT NULL
              INTO lv_null
              FROM apps.oe_order_lines_all ool
             WHERE ool.line_id = TO_NUMBER (p_sn_rec.source_code_reference);
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                x_val_status   := G_RET_ERROR;
                x_err_msg      := 'Invalid source code reference';
                msg (x_err_msg);
            WHEN OTHERS
            THEN
                x_val_status   := G_RET_ERROR;
                x_err_msg      :=
                    'Error to validate source code reference - ' || SQLERRM;
                msg (x_err_msg);
        END;

        IF x_val_status <> G_RET_ERROR
        THEN
            --Validate inventory_item_id and Organization_id
            BEGIN
                SELECT NULL
                  INTO lv_null
                  FROM apps.oe_order_lines_all ool
                 WHERE     ool.line_id =
                           TO_NUMBER (p_sn_rec.source_code_reference)
                       AND ool.inventory_item_id = p_sn_rec.inventory_item_id
                       AND ool.ship_from_org_id = p_sn_rec.organization_id;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    x_val_status   := G_RET_ERROR;
                    x_err_msg      :=
                        'Invalid inventory_item_id or organization_id';
                    msg (x_err_msg);
                WHEN OTHERS
                THEN
                    x_val_status   := G_RET_ERROR;
                    x_err_msg      :=
                           'Error to inventory_item_id or organization_id - '
                        || SQLERRM;
                    msg (x_err_msg);
            END;
        END IF;

        IF x_val_status <> G_RET_ERROR
        THEN
            --validating serial number in serial temp table
            BEGIN
                SELECT DECODE (COUNT (1),  1, 'UPDATE',  0, 'INSERT',  'ERROR')
                  INTO x_operation
                  FROM xxdo.xxdo_serial_temp st
                 WHERE st.serial_number = p_sn_rec.serial_number;
            END;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_val_status   := G_RET_ERROR;
            x_err_msg      := 'Error at RMA_RETUN Validation-' || SQLERRM;
            msg (x_err_msg);
    END;                                                 --validate_rma_return

    PROCEDURE validate_initial_entry (p_sn_rec IN sn_rec, x_operation OUT NOCOPY VARCHAR2, x_val_status OUT NOCOPY VARCHAR2
                                      , x_err_msg OUT NOCOPY VARCHAR2)
    IS
        --ln_lpn_id  apps.wms_license_plate_numbers.lpn_id%TYPE;
        --ln_item_id apps.mtl_system_items_b.inventory_item_id%TYPE;
        lv_null   VARCHAR2 (10);
    BEGIN
        x_val_status   := G_RET_SUCCESS;

        --Validate LPN or LPN_ID
        IF p_sn_rec.license_plate_number IS NULL AND p_sn_rec.lpn_id IS NULL
        THEN
            x_val_status   := G_RET_ERROR;
            x_err_msg      := 'LPN_ID or License_plate_number Required';
            msg (x_err_msg);
        ELSIF p_sn_rec.license_plate_number IS NULL
        THEN
            BEGIN
                SELECT NULL
                  INTO lv_null
                  FROM apps.wms_license_plate_numbers wlp
                 WHERE wlp.lpn_id = p_sn_rec.lpn_id;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    x_val_status   := G_RET_ERROR;
                    x_err_msg      := 'Invalid LPN_ID';
                    msg (x_err_msg);
                WHEN OTHERS
                THEN
                    x_val_status   := G_RET_ERROR;
                    x_err_msg      := 'Error validating LPN_ID -' || SQLERRM;
                    msg (x_err_msg);
            END;
        ELSIF p_sn_rec.lpn_id IS NULL
        THEN
            BEGIN
                SELECT NULL
                  INTO lv_null
                  FROM apps.wms_license_plate_numbers wlp
                 WHERE wlp.license_plate_number =
                       p_sn_rec.license_plate_number;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    x_val_status   := G_RET_ERROR;
                    x_err_msg      := 'Invalid LICENSE_PLATE_NUMBER';
                    msg (x_err_msg);
                WHEN OTHERS
                THEN
                    x_val_status   := G_RET_ERROR;
                    x_err_msg      :=
                           'Error while validating LICENSE_PLATE_NUMBER -'
                        || SQLERRM;
                    msg (x_err_msg);
            END;
        END IF;

        --Validate inventory item id
        IF p_sn_rec.inventory_item_id IS NULL
        THEN
            x_val_status   := G_RET_ERROR;
            x_err_msg      := 'inventory_item_id is Required';
            msg (x_err_msg);
        ELSE
            BEGIN
                SELECT NULL
                  INTO lv_null
                  FROM apps.mtl_system_items_b msib
                 WHERE     msib.inventory_item_id =
                           p_sn_rec.inventory_item_id
                       AND msib.organization_id =
                           NVL (p_sn_rec.organization_id, 7);
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    x_val_status   := G_RET_ERROR;
                    x_err_msg      := 'Invalid inventory_item_id';
                    msg (x_err_msg);
                WHEN OTHERS
                THEN
                    x_val_status   := G_RET_ERROR;
                    x_err_msg      :=
                        'Error in validating inventory_item_id -' || SQLERRM;
                    msg (x_err_msg);
            END;
        END IF;

        --Product QR Code Validation
        IF p_sn_rec.product_qr_code IS NULL
        THEN
            x_val_status   := G_RET_ERROR;
            x_err_msg      := 'Product QR Code is Required -' || SQLERRM;
            msg (x_err_msg);
        END IF;

        --Status id Validation
        BEGIN
            IF validate_status_id (p_sn_rec.status_id) = 0
            THEN
                x_val_status   := G_RET_ERROR;
                x_err_msg      := 'Invalid Status_id ' || p_sn_rec.status_id;
                msg (x_err_msg);
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                x_val_status   := G_RET_ERROR;
                x_err_msg      :=
                    'Error in validating Status_id -' || SQLERRM;
                msg (x_err_msg);
        END;

        IF x_val_status <> G_RET_ERROR
        THEN
            x_operation   := 'INSERT';
        ELSE
            x_operation   := 'ERROR';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_val_status   := G_RET_ERROR;
            x_err_msg      := 'Error in Insert Serial Temp -' || SQLERRM;
            msg (x_err_msg);
    END;

    PROCEDURE validate_mobile_update (p_sn_rec IN sn_rec, x_operation OUT NOCOPY VARCHAR2, x_val_status OUT NOCOPY VARCHAR2
                                      , x_err_msg OUT NOCOPY VARCHAR2)
    IS
        --ln_serial_num   xxdo.xxdo_serial_temp.serial_number%TYPE;
        --ln_lpn_id       apps.wms_license_plate_numbers.lpn_id%TYPE;
        --lv_lpn_num      apps.wms_license_plate_numbers.license_plate_number%TYPE;
        ln_case_qty   NUMBER;
        lv_null       VARCHAR2 (10);
    BEGIN
        x_val_status   := G_RET_SUCCESS;

        --Serial number must exist in serial tmep table
        BEGIN
            SELECT NULL
              INTO lv_null
              FROM xxdo.xxdo_serial_temp stp
             WHERE stp.serial_number = p_sn_rec.serial_number;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                x_val_status   := G_RET_ERROR;
                x_err_msg      := 'invalid serial number -' || SQLERRM;
                msg (x_err_msg);
            WHEN OTHERS
            THEN
                x_val_status   := G_RET_ERROR;
                x_err_msg      :=
                    'Error in Validating Serial Number' || SQLERRM;
                msg (x_err_msg);
        END;

        -- License Plate Number Validation
        IF p_sn_rec.license_plate_number IS NULL AND p_sn_rec.lpn_id IS NULL
        THEN
            x_val_status   := G_RET_ERROR;
            x_err_msg      := 'LPN_ID or License_plate_number is Required';
            msg (x_err_msg);
        ELSIF p_sn_rec.license_plate_number IS NULL
        THEN
            BEGIN
                SELECT NULL
                  INTO lv_null
                  FROM apps.wms_license_plate_numbers lpn
                 WHERE lpn.lpn_id = p_sn_rec.lpn_id;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    x_val_status   := G_RET_ERROR;
                    x_err_msg      := 'Invalid LPN_ID';
                    msg (x_err_msg);
                WHEN OTHERS
                THEN
                    x_val_status   := G_RET_ERROR;
                    x_err_msg      := 'Error validating LPN_ID -' || SQLERRM;
                    msg (x_err_msg);
            END;
        ELSIF p_sn_rec.lpn_id IS NULL
        THEN
            BEGIN
                SELECT NULL                             --license_plate_number
                  INTO lv_null
                  FROM apps.wms_license_plate_numbers lpn
                 WHERE lpn.license_plate_number =
                       p_sn_rec.license_plate_number;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    x_val_status   := G_RET_ERROR;
                    x_err_msg      := 'Invalid LICENSE_PLATE_NUMBER';
                    msg (x_err_msg);
                WHEN OTHERS
                THEN
                    x_val_status   := G_RET_ERROR;
                    x_err_msg      :=
                           'Error while validating LICENSE_PLATE_NUMBER -'
                        || SQLERRM;
                    msg (x_err_msg);
            END;
        END IF;

        --LPN OR LPN_ID Should Have On-Hand
        /************
        --COMMENTING THIS PORTION, AS  THIS CONDITION IS ALREADY VALIDATED IN THE MOBILE
          SELECT COUNT(1)
                 --NVL (muc.CONVERSION_RATE, 0) AS case_pack_qty
                 --    ,apps.iid_to_sku (moqd.inventory_item_id) sku
           INTO  lv_null
            FROM  apps.mtl_uom_conversions muc,
                  apps.mtl_onhand_quantities_detail moqd,
                  apps.wms_license_plate_numbers wlpn
           WHERE     moqd.organization_id =p_sn_rec.organization_id
           AND muc.INVENTORY_ITEM_ID(+) = moqd.inventory_item_id
           AND muc.uom_code(+) = 'CSE'
           AND wlpn.license_plate_number = p_sn_rec.license_plate_number
           AND moqd.lpn_id = wlpn.lpn_id AND wlpn.lpn_context NOT IN (4, 5);
         EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            x_val_status:=G_RET_ERROR;
            x_err_msg   :='No Case Pick QTY';
            msg(x_err_msg);
         WHEN OTHERS
         THEN
            x_val_status:=G_RET_ERROR;
            x_err_msg   :='Error in  Case Pick QTY Validation-'||SQLERRM;
            msg(x_err_msg);
         END;

       ***********************/

        IF x_val_status <> G_RET_ERROR
        THEN
            x_operation   := 'UPDATE';
        ELSE
            x_operation   := 'ERROR';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_val_status   := G_RET_ERROR;
            x_err_msg      :=
                'Error in mobile update validation -' || SQLERRM;
            msg (x_err_msg);
    END;

    PROCEDURE validate_unpack_lpn (p_sn_rec IN sn_rec, x_operation OUT NOCOPY VARCHAR2, x_val_status OUT NOCOPY VARCHAR2
                                   , x_err_msg OUT NOCOPY VARCHAR2)
    IS
        ln_lpn_id       xxdo.xxdo_serial_temp.lpn_id%TYPE;
        lv_lpn_number   xxdo.xxdo_serial_temp.license_plate_number%TYPE;
    --lv_null     VARCHAR2(10);
    BEGIN
        x_val_status   := G_RET_SUCCESS;

        -- License Plate Number Validation
        IF p_sn_rec.license_plate_number IS NULL AND p_sn_rec.lpn_id IS NULL
        THEN
            x_val_status   := G_RET_ERROR;
            x_err_msg      := 'LPN_ID or License_plate_number Required';
            msg (x_err_msg);
        ELSIF p_sn_rec.license_plate_number IS NULL
        THEN
            BEGIN
                SELECT DISTINCT lpn_id
                  INTO ln_lpn_id
                  FROM xxdo.xxdo_serial_temp stp
                 WHERE stp.lpn_id = p_sn_rec.lpn_id;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    x_val_status   := G_RET_ERROR;
                    x_err_msg      := 'Invalid LPN_ID';
                    msg (x_err_msg);
                WHEN TOO_MANY_ROWS
                THEN
                    x_val_status   := G_RET_SUCCESS;
                    x_err_msg      := NULL;
                    msg (x_err_msg);
                WHEN OTHERS
                THEN
                    x_val_status   := G_RET_ERROR;
                    x_err_msg      := 'Error validating LPN_ID -' || SQLERRM;
                    msg (x_err_msg);
            END;
        ELSIF p_sn_rec.lpn_id IS NULL
        THEN
            BEGIN
                SELECT DISTINCT license_plate_number
                  INTO lv_lpn_number
                  FROM xxdo.xxdo_serial_temp stp
                 WHERE stp.license_plate_number =
                       p_sn_rec.license_plate_number;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    x_val_status   := G_RET_ERROR;
                    x_err_msg      := 'Invalid LICENSE_PLATE_NUMBER';
                    msg (x_err_msg);
                WHEN TOO_MANY_ROWS
                THEN
                    x_val_status   := G_RET_SUCCESS;
                    x_err_msg      := NULL;
                WHEN OTHERS
                THEN
                    x_val_status   := G_RET_ERROR;
                    x_err_msg      :=
                           'Error while validating LICENSE_PLATE_NUMBER -'
                        || SQLERRM;
                    msg (x_err_msg);
            END;
        END IF;

        IF x_val_status <> G_RET_ERROR
        THEN
            x_operation   := 'UPDATE';
        ELSE
            x_operation   := 'ERROR';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_val_status   := G_RET_ERROR;
            x_err_msg      :=
                   'LPN_ID or LICENSE_PLATE_NUMBER validation error -'
                || SQLERRM;
            msg (x_err_msg);
    END;

    ------------------------------------------------------------
    --FUNCTIONS
    ------------------------------------------------------------
    FUNCTION soa_update_req_check (p_serial_number IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_string   VARCHAR2 (2);
        lv_flag     VARCHAR2 (1) := 'N';
    BEGIN
        BEGIN
            SELECT SUBSTR (st.serial_number, 1, 2)
              INTO lv_string
              FROM xxdo.xxdo_serial_temp st
             WHERE st.serial_number = p_serial_number;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_string   := NULL;
        END;

        IF NVL (lv_string, '1') = '99'
        THEN
            lv_flag   := 'N';
        ELSE
            lv_flag   := 'Y';
        END IF;

        RETURN lv_flag;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_flag   := 'N';
            RETURN lv_flag;
    END;

    FUNCTION validate_status_id (p_status_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_status_cnt   NUMBER;
    BEGIN
        SELECT COUNT (1)
          INTO ln_status_cnt
          FROM fnd_lookup_values flv
         WHERE     flv.lookup_type = 'XXDO_SERIAL_TEMP_STATUS_ID'
               AND language = USERENV ('LANG')
               AND lookup_code = p_status_id;

        RETURN ln_status_cnt;
    END;
/* end of changes */
END XXDO_SERIALIZATION;
/
