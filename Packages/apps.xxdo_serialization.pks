--
-- XXDO_SERIALIZATION  (Package) 
--
--  Dependencies: 
--   FND_API (Package)
--   SN (Type)
--   STANDARD (Package)
--   XXDO_SERIAL_TEMP (Table)
--
/* Formatted on 4/26/2023 4:17:43 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_SERIALIZATION"
    AUTHID DEFINER
AS
    g_debug_pick                 NUMBER := 0;
    -- RETURN STATUSES
    G_RET_SUCCESS       CONSTANT VARCHAR2 (1) := APPS.FND_API.G_RET_STS_SUCCESS;
    G_RET_ERROR         CONSTANT VARCHAR2 (1) := APPS.FND_API.G_RET_STS_ERROR;
    G_RET_UNEXP_ERROR   CONSTANT VARCHAR2 (1)
                                     := APPS.FND_API.G_RET_STS_UNEXP_ERROR ;
    G_RET_WARNING       CONSTANT VARCHAR2 (1) := 'W';

    TYPE sn_rec
        IS RECORD
    (
        serial_number            xxdo.xxdo_serial_temp.serial_number%TYPE,
        lpn_id                   xxdo.xxdo_serial_temp.lpn_id%TYPE,
        license_plate_number     xxdo.xxdo_serial_temp.license_plate_number%TYPE,
        inventory_item_id        xxdo.xxdo_serial_temp.inventory_item_id%TYPE,
        organization_id          xxdo.xxdo_serial_temp.organization_id%TYPE,
        status_id                xxdo.xxdo_serial_temp.status_id%TYPE,
        last_updated_by          xxdo.xxdo_serial_temp.last_updated_by%TYPE,
        source_code              xxdo.xxdo_serial_temp.source_code%TYPE,
        source_code_reference    xxdo.xxdo_serial_temp.source_code_reference%TYPE,
        soa_event                xxdo.xxdo_serial_temp.soa_event%TYPE,
        soa_status               xxdo.xxdo_serial_temp.soa_status%TYPE,
        soa_message_text         xxdo.xxdo_serial_temp.soa_message_text%TYPE,
        soa_update_date          xxdo.xxdo_serial_temp.soa_update_date%TYPE,
        product_qr_code          xxdo.xxdo_serial_temp.product_qr_code%TYPE
    );



    PROCEDURE qr_verify (p_qrcode               VARCHAR2,
                         x_ret_stat         OUT VARCHAR2,
                         x_message          OUT VARCHAR2,
                         x_sn               OUT VARCHAR2,
                         x_item_id          OUT NUMBER,
                         x_current_status   OUT VARCHAR2);

    PROCEDURE SET_SN_TO_LPN (p_sn                IN     SN,
                             p_lpn               IN     VARCHAR2,
                             p_organization_id          NUMBER,
                             x_ret_stat             OUT VARCHAR2,
                             x_message              OUT VARCHAR2);

    PROCEDURE UPDATE_SERIAL_TEMP (p_sn_rec IN sn_rec, p_debug_level IN NUMBER:= 0, x_return_status OUT NOCOPY VARCHAR2
                                  , x_error_message OUT NOCOPY VARCHAR2);
END XXDO_SERIALIZATION;
/
