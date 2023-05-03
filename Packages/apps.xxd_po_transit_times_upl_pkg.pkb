--
-- XXD_PO_TRANSIT_TIMES_UPL_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:28 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_PO_TRANSIT_TIMES_UPL_PKG"
AS
    /******************************************************************************************************
    * Package Name  : XXD_PO_TRANSIT_TIMES_UPL_PKG
    * Description   : This Package will be used to insert/update lookup - XXDO_SUPPLIER_INTRANSIT
    *
    * Modification History
    * -------------------
    * Date          Author            Version          Change Description
    * -----------   ------            -------          ---------------------------
    * 17-Nov-2022   Ramesh BR         1.0              Initial Version
    ********************************************************************************************************/

    PROCEDURE lookup_upload_prc (p_ultimate_dest_code   IN VARCHAR2,
                                 p_vendor_name          IN VARCHAR2,
                                 p_vendor_site_code     IN VARCHAR2,
                                 p_tran_days_ocean      IN NUMBER,
                                 p_tran_days_air        IN NUMBER,
                                 p_tran_days_truck      IN NUMBER,
                                 p_pref_ship_method     IN VARCHAR2,
                                 p_batch_id             IN NUMBER,
                                 p_lookup_code          IN NUMBER,
                                 p_sup_site_status      IN VARCHAR2,
                                 p_enabled_flag         IN VARCHAR2)
    AS
        l_sup_count          NUMBER := 0;
        l_ulti_meaning       VARCHAR2 (80) := NULL;
        l_count              NUMBER := 0;
        l_ship_count         NUMBER := 0;
        l_lookup_code        VARCHAR2 (30) := NULL;
        l_meaning            VARCHAR2 (80) := NULL;
        l_tda                VARCHAR2 (150) := NULL;
        l_tdo                VARCHAR2 (150) := NULL;
        l_tdt                VARCHAR2 (150) := NULL;
        l_psm                VARCHAR2 (150) := NULL;
        l_enabled_flag       VARCHAR2 (1) := NULL;
        l_attribute1         VARCHAR2 (150) := NULL;
        l_attribute4         VARCHAR2 (150) := NULL;
        l_vendor_id          NUMBER := NULL;
        l_vendor_site_id     NUMBER := NULL;
        xrow                 ROWID;
        l_status             VARCHAR2 (1) := NULL;
        l_message            VARCHAR2 (4000) := NULL;
        l_ret_message        VARCHAR2 (4000) := NULL;
        l_webadi_exception   EXCEPTION;


        CURSOR cur_get_tran_time IS
            SELECT stg.ROWID, stg.*
              FROM xxd_po_transit_times_upl_t stg
             WHERE stg.status IN ('N');
    BEGIN
        l_status    := NULL;
        l_message   := NULL;

        IF p_vendor_name IS NULL
        THEN
            l_status    := 'E';
            l_message   := 'Supplier Name is Mandatory';
        END IF;

        IF p_vendor_site_code IS NULL
        THEN
            l_status    := 'E';
            l_message   := 'Supplier Site is Mandatory';
        END IF;

        IF p_ultimate_dest_code IS NULL
        THEN
            l_status   := 'E';
            l_message   :=
                l_message || '-' || 'Ultimate Destination Code is Mandatory';
        END IF;

        IF p_enabled_flag IS NULL
        THEN
            l_status    := 'E';
            l_message   := l_message || '-' || 'Enabled Flag is Mandatory';
        ELSIF p_enabled_flag IS NOT NULL
        THEN
            IF p_enabled_flag NOT IN ('Y', 'N')
            THEN
                l_status   := 'E';
                l_message   :=
                    l_message || '-' || 'Enabled Flag should be either Y/N';
            END IF;
        END IF;

        BEGIN
            IF p_tran_days_ocean IS NULL
            THEN
                l_status   := 'E';
                l_message   :=
                    l_message || '-' || 'Transit Days Ocean is Mandatory';
            ELSIF p_tran_days_ocean IS NOT NULL
            THEN
                IF TRIM (TRANSLATE (p_tran_days_ocean, '0123456789-,.', ' '))
                       IS NULL
                THEN
                    IF p_tran_days_ocean < 0
                    THEN
                        l_status   := 'E';
                        l_message   :=
                               l_message
                            || '-'
                            || 'Transit Days Ocean should be greater than zero';
                    END IF;
                ELSE
                    l_status   := 'E';
                    l_message   :=
                           l_message
                        || '-'
                        || 'Transit Days Ocean should be Numeric';
                END IF;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_status   := 'E';
                l_message   :=
                       l_message
                    || '-'
                    || 'In exception of Transit Days Ocean validation - '
                    || SQLERRM;
        END;

        BEGIN
            IF p_tran_days_air IS NULL
            THEN
                l_status   := 'E';
                l_message   :=
                    l_message || '-' || 'Transit Days Air is Mandatory';
            ELSIF p_tran_days_air IS NOT NULL
            THEN
                IF TRIM (TRANSLATE (p_tran_days_air, '0123456789-,.', ' '))
                       IS NULL
                THEN
                    IF p_tran_days_air < 0
                    THEN
                        l_status   := 'E';
                        l_message   :=
                               l_message
                            || '-'
                            || 'Transit Days Air should be greater than zero';
                    END IF;
                ELSE
                    l_status   := 'E';
                    l_message   :=
                           l_message
                        || '-'
                        || 'Transit Days Air should be Numeric';
                END IF;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_status   := 'E';
                l_message   :=
                       l_message
                    || '-'
                    || 'In exception of Transit Days Air validation';
        END;

        BEGIN
            IF p_tran_days_truck IS NOT NULL
            THEN
                IF TRIM (TRANSLATE (p_tran_days_truck, '0123456789-,.', ' '))
                       IS NULL
                THEN
                    NULL;
                ELSE
                    l_status   := 'E';
                    l_message   :=
                           l_message
                        || '-'
                        || 'Transit Days Truck should be Numeric';
                END IF;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_status   := 'E';
                l_message   :=
                       l_message
                    || '-'
                    || 'In exception of Transit Days Truck validation - '
                    || SQLERRM;
        END;

        BEGIN
            SELECT COUNT (*)
              INTO l_ship_count
              FROM fnd_flex_values_vl ffvl, fnd_flex_value_sets ffvs
             WHERE     ffvl.flex_value_set_id = ffvs.flex_value_set_id
                   AND ffvs.flex_value_set_name = 'XXDO_SHIP_METHOD'
                   AND ffvl.flex_value =
                       NVL (p_pref_ship_method, ffvl.flex_value)
                   AND ffvl.enabled_flag = 'Y';


            IF l_ship_count = 0
            THEN
                l_status   := 'E';
                l_message   :=
                       l_message
                    || '-'
                    || 'Preferred Ship Method does not exist in the valueset XXDO_SHIP_METHOD';
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_status   := 'E';
                l_message   :=
                       l_message
                    || '-'
                    || 'In exception of Preferred Ship Method validation - '
                    || SQLERRM;
        END;

        BEGIN
            l_vendor_id   := NULL;

            SELECT vendor_id
              INTO l_vendor_id
              FROM ap_suppliers
             WHERE vendor_name = p_vendor_name;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_status   := 'E';
                l_message   :=
                    l_message || '-' || 'Supplier Name is not valid';
        END;

        BEGIN
            l_vendor_site_id   := NULL;

              SELECT vendor_id
                INTO l_vendor_site_id
                FROM ap_supplier_sites_all
               WHERE     vendor_id = l_vendor_id
                     AND vendor_site_code = p_vendor_site_code
            GROUP BY vendor_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_status   := 'E';
                l_message   :=
                       l_message
                    || '-'
                    || 'Supplier Site is not valid for this Supplier';
        END;

        BEGIN
            l_ulti_meaning   := NULL;

              SELECT meaning
                INTO l_ulti_meaning
                FROM fnd_lookup_values
               WHERE     lookup_type = 'XXDO_ULTIMATE_DESTINATION_CODE'
                     AND language = 'US'
                     AND lookup_code = p_ultimate_dest_code
                     AND enabled_flag = 'Y'
                     AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                     NVL (start_date_active,
                                                          SYSDATE))
                                             AND TRUNC (
                                                       NVL (end_date_active,
                                                            SYSDATE)
                                                     + 1)
            GROUP BY meaning;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_status   := 'E';
                l_message   :=
                       l_message
                    || '-'
                    || 'Ultimate Destination Name does not exist';
        END;

        BEGIN
            IF l_status IS NULL
            THEN
                INSERT INTO xxd_po_transit_times_upl_t (lookup_code, vendor_name, vendor_site_code, vendor_id, ultimate_dest_code, ultimate_dest_name, transit_days_ocean, transit_days_air, transit_days_truck, preferred_ship_method, enabled_flag, creation_date, created_by, last_update_date, last_updated_by, last_update_login, batch_id, status
                                                        , MESSAGE)
                     VALUES (p_lookup_code, p_vendor_name, p_vendor_site_code, l_vendor_id, p_ultimate_dest_code, l_ulti_meaning, p_tran_days_ocean, p_tran_days_air, p_tran_days_truck, p_pref_ship_method, p_enabled_flag, SYSDATE, FND_GLOBAL.USER_ID, SYSDATE, FND_GLOBAL.USER_ID, FND_GLOBAL.USER_ID, p_batch_id, 'N'
                             , NULL);

                COMMIT;
            ELSE
                RAISE l_webadi_exception;
            END IF;
        EXCEPTION
            WHEN l_webadi_exception
            THEN
                fnd_message.set_name ('XXDO', 'XXD_PO_TRANSIT_TIMES_MSG');
                fnd_message.set_token ('ERROR_MESSAGE', l_message);
            WHEN OTHERS
            THEN
                l_ret_message   := SQLERRM;
                raise_application_error (-20000, l_ret_message);
        END;

        FOR rec_get_tran_time IN cur_get_tran_time
        LOOP
            SELECT COUNT (*)
              INTO l_count
              FROM fnd_lookup_values
             WHERE     lookup_type = 'XXDO_SUPPLIER_INTRANSIT'
                   AND language = 'US'
                   AND attribute1 = rec_get_tran_time.vendor_id
                   AND attribute2 = rec_get_tran_time.vendor_site_code
                   AND attribute3 = rec_get_tran_time.ultimate_dest_code;

            SELECT NVL (MAX (TO_NUMBER (lookup_code)), 1)
              INTO l_lookup_code
              FROM fnd_lookup_values
             WHERE     lookup_type = 'XXDO_SUPPLIER_INTRANSIT'
                   AND language = 'US';

            IF l_count = 0
            THEN
                fnd_lookup_values_pkg.insert_row (
                    x_rowid                 => xrow,
                    x_lookup_type           => 'XXDO_SUPPLIER_INTRANSIT',
                    x_security_group_id     => 0,
                    x_view_application_id   => 201,
                    x_lookup_code           => TO_NUMBER (l_lookup_code) + 1,
                    x_tag                   => NULL,
                    x_attribute_category    => 'XXDO_SUPPLIER_INTRANSIT',
                    x_attribute1            => rec_get_tran_time.vendor_id,
                    x_attribute2            =>
                        rec_get_tran_time.vendor_site_code,
                    x_attribute3            =>
                        rec_get_tran_time.ultimate_dest_code,
                    x_attribute4            =>
                        rec_get_tran_time.ultimate_dest_name,
                    x_enabled_flag          => rec_get_tran_time.enabled_flag,
                    x_start_date_active     => SYSDATE,
                    x_end_date_active       => NULL,
                    x_territory_code        => NULL,
                    x_attribute5            =>
                        rec_get_tran_time.transit_days_air,
                    x_attribute6            =>
                        rec_get_tran_time.transit_days_ocean,
                    x_attribute7            =>
                        rec_get_tran_time.transit_days_truck,
                    x_attribute8            =>
                        rec_get_tran_time.preferred_ship_method,
                    x_attribute9            => NULL,
                    x_attribute10           => NULL,
                    x_attribute11           => NULL,
                    x_attribute12           => NULL,
                    x_attribute13           => NULL,
                    x_attribute14           => NULL,
                    x_attribute15           => NULL,
                    x_meaning               => TO_NUMBER (l_lookup_code) + 1,
                    x_description           => NULL,
                    x_creation_date         => SYSDATE,
                    x_created_by            => FND_GLOBAL.USER_ID,
                    x_last_update_date      => SYSDATE,
                    x_last_updated_by       => FND_GLOBAL.USER_ID,
                    x_last_update_login     => FND_GLOBAL.USER_ID);

                UPDATE xxd_po_transit_times_upl_t
                   SET status = 'S', MESSAGE = 'Success'
                 WHERE     vendor_name = rec_get_tran_time.vendor_name
                       AND vendor_site_code =
                           rec_get_tran_time.vendor_site_code
                       AND ultimate_dest_code =
                           rec_get_tran_time.ultimate_dest_code
                       AND status = 'N'
                       AND ROWID = rec_get_tran_time.ROWID;
            ELSIF l_count > 0
            THEN
                l_lookup_code   := NULL;
                l_meaning       := NULL;
                l_tda           := NULL;
                l_tdo           := NULL;
                l_tdt           := NULL;
                l_psm           := NULL;

                BEGIN
                    SELECT lookup_code, meaning, attribute1,
                           attribute4, attribute5, attribute6,
                           attribute7, attribute8, enabled_flag
                      INTO l_lookup_code, l_meaning, l_attribute1, l_attribute4,
                                        l_tda, l_tdo, l_tdt,
                                        l_psm, l_enabled_flag
                      FROM fnd_lookup_values
                     WHERE     lookup_type = 'XXDO_SUPPLIER_INTRANSIT'
                           AND language = 'US'
                           AND attribute1 = rec_get_tran_time.vendor_id
                           AND attribute2 =
                               rec_get_tran_time.vendor_site_code
                           AND attribute3 =
                               rec_get_tran_time.ultimate_dest_code;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_ret_message   := SQLERRM;

                        UPDATE xxd_po_transit_times_upl_t
                           SET status = 'E', MESSAGE = l_ret_message
                         WHERE     vendor_name =
                                   rec_get_tran_time.vendor_name
                               AND vendor_site_code =
                                   rec_get_tran_time.vendor_site_code
                               AND ultimate_dest_code =
                                   rec_get_tran_time.ultimate_dest_code
                               AND status = 'N'
                               AND ROWID = rec_get_tran_time.ROWID;
                END;

                fnd_lookup_values_pkg.update_row (
                    x_lookup_type           => 'XXDO_SUPPLIER_INTRANSIT',
                    x_security_group_id     => 0,
                    x_view_application_id   => 201,
                    x_lookup_code           => l_lookup_code,
                    x_tag                   => NULL,
                    x_attribute_category    => 'XXDO_SUPPLIER_INTRANSIT',
                    x_attribute1            => rec_get_tran_time.vendor_id,
                    x_attribute2            =>
                        rec_get_tran_time.vendor_site_code,
                    x_attribute3            =>
                        rec_get_tran_time.ultimate_dest_code,
                    x_attribute4            => l_attribute4,
                    x_enabled_flag          => rec_get_tran_time.enabled_flag,
                    x_start_date_active     => SYSDATE,
                    x_end_date_active       => NULL,
                    x_territory_code        => NULL,
                    x_attribute5            =>
                        rec_get_tran_time.transit_days_air,
                    x_attribute6            =>
                        rec_get_tran_time.transit_days_ocean,
                    x_attribute7            =>
                        rec_get_tran_time.transit_days_truck,
                    x_attribute8            =>
                        rec_get_tran_time.preferred_ship_method,
                    x_attribute9            => NULL,
                    x_attribute10           => NULL,
                    x_attribute11           => NULL,
                    x_attribute12           => NULL,
                    x_attribute13           => NULL,
                    x_attribute14           => NULL,
                    x_attribute15           => NULL,
                    x_meaning               => l_meaning,
                    x_description           => NULL,
                    x_last_update_date      => SYSDATE,
                    x_last_updated_by       => FND_GLOBAL.USER_ID,
                    x_last_update_login     => FND_GLOBAL.USER_ID);

                UPDATE xxd_po_transit_times_upl_t
                   SET old_transit_days_air = l_tda, old_transit_days_ocean = l_tdo, old_transit_days_truck = l_tdt,
                       old_preferred_ship_method = l_psm, old_enabled_flag = l_enabled_flag, status = 'S',
                       MESSAGE = 'Success'
                 WHERE     vendor_name = rec_get_tran_time.vendor_name
                       AND vendor_site_code =
                           rec_get_tran_time.vendor_site_code
                       AND ultimate_dest_code =
                           rec_get_tran_time.ultimate_dest_code
                       AND status = 'N'
                       AND ROWID = rec_get_tran_time.ROWID;
            END IF;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_ret_message   := SQLERRM;

            raise_application_error (-20000, l_ret_message);
    END lookup_upload_prc;
END XXD_PO_TRANSIT_TIMES_UPL_PKG;
/
