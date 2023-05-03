--
-- XXDO_ONT_WMS_INTF_UTIL_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:15 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_ONT_WMS_INTF_UTIL_PKG"
AS
    /*
    **********************************************************************************************
    $Header:  xxdo_ont_wms_intf_util_pkg.sql   1.0    2014/07/15    10:00:00   Infosys $
    **********************************************************************************************
    */
    -- ***************************************************************************
    --                (c) Copyright Deckers Outdoor Corp.
    --                    All rights reserved
    -- ***************************************************************************
    --
    -- Package Name :  xxdo_ont_wms_intf_util_pkg
    --
    -- Description  :  This package has the utilities required the Interfaces between EBS and WMS
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- Date          Author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 15-Jul-14    Infosys            1.0       Created
    -- ***************************************************************************

    FUNCTION get_sku (p_in_num_inventory_item_id IN NUMBER)
        RETURN VARCHAR2
    IS
        l_chr_sku   VARCHAR2 (50);
    BEGIN
        SELECT segment1 || '-' || segment2 || '-' || segment3
          INTO l_chr_sku
          FROM mtl_system_items_b
         WHERE     organization_id = 7
               AND inventory_item_id = p_in_num_inventory_item_id;

        RETURN l_chr_sku;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_sku;

    PROCEDURE release_holds (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_io_hold_source_tbl IN OUT g_hold_source_tbl_type
                             , p_in_num_header_id IN NUMBER)
    IS
        l_num_msg_count       NUMBER;
        l_chr_msg_data        VARCHAR2 (300);
        l_chr_return_status   VARCHAR2 (1);
        l_chr_message         VARCHAR2 (2000);
        l_chr_message1        VARCHAR2 (2000);
        l_num_msg_index_out   NUMBER;

        l_hold_release_rec    OE_Holds_PVT.Hold_Release_REC_type;
        l_hold_source_rec     OE_Holds_PVT.Hold_Source_REC_type;


        CURSOR cur_holds (p_num_header_id IN NUMBER)
        IS
            SELECT DECODE (hold_srcs.hold_entity_code,  'S', 'Ship-To',  'B', 'Bill-To',  'I', 'Item',  'W', 'Warehouse',  'O', 'Order',  'C', 'Customer',  hold_srcs.hold_entity_code) AS hold_type, hold_defs.name AS hold_name, hold_defs.type_code,
                   holds.header_id, holds.line_id, hold_srcs.*
              FROM oe_hold_definitions hold_defs, oe_hold_sources hold_srcs, oe_order_holds holds
             WHERE     hold_srcs.hold_source_id = holds.hold_source_id
                   AND hold_defs.hold_id = hold_srcs.hold_id
                   AND holds.header_id = p_num_header_id
                   AND holds.released_flag = 'N';
    BEGIN
        p_out_chr_errbuf    := NULL;
        p_out_chr_retcode   := '0';

        FOR holds_rec IN cur_holds (p_in_num_header_id)
        LOOP
            p_io_hold_source_tbl (p_io_hold_source_tbl.COUNT + 1).hold_id   :=
                holds_rec.hold_id;
            p_io_hold_source_tbl (p_io_hold_source_tbl.COUNT).hold_entity_code   :=
                holds_rec.hold_entity_code;
            p_io_hold_source_tbl (p_io_hold_source_tbl.COUNT).hold_entity_id   :=
                holds_rec.hold_entity_id;
            p_io_hold_source_tbl (p_io_hold_source_tbl.COUNT).header_id   :=
                holds_rec.header_id;
            p_io_hold_source_tbl (p_io_hold_source_tbl.COUNT).line_id   :=
                holds_rec.line_id;
            p_io_hold_source_tbl (p_io_hold_source_tbl.COUNT).hold_type   :=
                holds_rec.hold_type;
            p_io_hold_source_tbl (p_io_hold_source_tbl.COUNT).hold_name   :=
                holds_rec.hold_name;
            l_hold_source_rec.hold_id            := holds_rec.hold_id;
            l_hold_source_rec.hold_entity_code   :=
                holds_rec.hold_entity_code;
            l_hold_source_rec.hold_entity_id     := holds_rec.hold_entity_id;
            l_hold_release_rec.hold_source_id    := holds_rec.hold_source_id;

            IF holds_rec.type_code = 'CREDIT'
            THEN
                l_hold_release_rec.release_reason_code   :=
                    g_chr_ar_release_reason;
            ELSE
                l_hold_release_rec.release_reason_code   :=
                    g_chr_om_release_reason;
            END IF;

            l_hold_release_rec.release_comment   :=
                'Auto-release for ship-confirm.';
            l_hold_release_rec.request_id        :=
                NVL (fnd_global.CONC_REQUEST_ID, -100);

            OE_Holds_PUB.Release_Holds (
                p_api_version        => 1.0,
                p_validation_level   => FND_API.G_VALID_LEVEL_NONE,
                p_hold_source_rec    => l_hold_source_rec,
                p_hold_release_rec   => l_hold_release_rec,
                x_msg_count          => l_num_msg_count,
                x_msg_data           => l_chr_msg_data,
                x_return_status      => l_chr_return_status);

            IF l_chr_return_status <> FND_API.G_RET_STS_SUCCESS
            THEN
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                       holds_rec.hold_name
                    || ' is released from the order - header Id: '
                    || holds_rec.header_id);

                FOR l_num_msg_cntr IN 1 .. l_num_msg_count
                LOOP
                    FND_MSG_PUB.GET (p_msg_index => l_num_msg_cntr, p_encoded => 'F', p_data => l_chr_msg_data
                                     , p_msg_index_out => l_num_msg_index_out);
                    FND_FILE.PUT_LINE (FND_FILE.LOG,
                                       'Error Message: ' || l_chr_msg_data);
                END LOOP;

                p_out_chr_retcode   := '2';
            ELSE
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                       holds_rec.hold_name
                    || ' is released successfully from the order - header Id: '
                    || holds_rec.header_id);
            END IF;

            fnd_msg_pub.delete_msg ();
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_chr_errbuf    := SQLERRM;
            p_out_chr_retcode   := '2';
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                   'Unexpected error at release hold procedure : '
                || p_out_chr_errbuf);
    END release_holds;

    PROCEDURE reapply_holds (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_hold_source_tbl IN g_hold_source_tbl_type)
    IS
        l_num_rec_cnt         NUMBER;
        l_num_msg_count       NUMBER;
        l_chr_msg_data        VARCHAR2 (2000);
        l_chr_return_status   VARCHAR2 (1);
        l_num_msg_index_out   NUMBER;

        l_hold_source_rec     OE_Holds_PVT.Hold_Source_REC_type;
    BEGIN
        p_out_chr_errbuf    := NULL;
        p_out_chr_retcode   := '0';

        FOR l_num_index IN 1 .. p_in_hold_source_tbl.COUNT
        LOOP
            SELECT COUNT (1)
              INTO l_num_rec_cnt
              FROM oe_order_lines
             WHERE     header_id =
                       p_in_hold_source_tbl (l_num_index).header_id
                   AND open_flag = 'Y';

            IF l_num_rec_cnt > 0
            THEN
                l_hold_source_rec   := OE_HOLDS_PVT.G_MISS_HOLD_SOURCE_REC;
                l_hold_source_rec.hold_id   :=
                    p_in_hold_source_tbl (l_num_index).hold_id;
                l_hold_source_rec.hold_entity_code   :=
                    p_in_hold_source_tbl (l_num_index).hold_entity_code;
                l_hold_source_rec.hold_entity_id   :=
                    p_in_hold_source_tbl (l_num_index).hold_entity_id;
                l_hold_source_rec.header_id   :=
                    p_in_hold_source_tbl (l_num_index).header_id;
                l_hold_source_rec.line_id   :=
                    p_in_hold_source_tbl (l_num_index).line_id;

                OE_Holds_PUB.Apply_Holds (
                    p_api_version        => 1.0,
                    p_validation_level   => FND_API.G_VALID_LEVEL_NONE,
                    p_hold_source_rec    => l_hold_source_rec,
                    x_msg_count          => l_num_msg_count,
                    x_msg_data           => l_chr_msg_data,
                    x_return_status      => l_chr_return_status);

                IF l_chr_return_status <> FND_API.G_RET_STS_SUCCESS
                THEN
                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                           p_in_hold_source_tbl (l_num_index).hold_name
                        || ' is not reapplied on the order - header Id: '
                        || p_in_hold_source_tbl (l_num_index).header_id);

                    FOR l_num_msg_cntr IN 1 .. l_num_msg_count
                    LOOP
                        FND_MSG_PUB.GET (
                            p_msg_index       => l_num_msg_cntr,
                            p_encoded         => 'F',
                            p_data            => l_chr_msg_data,
                            p_msg_index_out   => l_num_msg_index_out);
                        FND_FILE.PUT_LINE (
                            FND_FILE.LOG,
                            'Error Message: ' || l_chr_msg_data);
                    END LOOP;

                    p_out_chr_retcode   := '2';
                ELSE
                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                           p_in_hold_source_tbl (l_num_index).hold_name
                        || ' is reapplied successfully on the order - header Id: '
                        || p_in_hold_source_tbl (l_num_index).header_id);
                END IF;
            ELSE
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                       p_in_hold_source_tbl (l_num_index).hold_name
                    || ' is not reapplied since no open lines in the order - header Id: '
                    || p_in_hold_source_tbl (l_num_index).header_id);
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_chr_errbuf    := SQLERRM;
            p_out_chr_retcode   := '2';
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                   'Unexpected error at reapply hold procedure : '
                || p_out_chr_errbuf);
    END reapply_holds;

    FUNCTION get_last_run_time (p_in_chr_interface_prgm_name IN VARCHAR2)
        RETURN DATE
    IS
        l_interface_setup_rec   fnd_lookup_values%ROWTYPE;
    BEGIN
        -- Get the interface setup
        BEGIN
            IF p_in_chr_interface_prgm_name IS NULL
            THEN
                SELECT flv.*
                  INTO l_interface_setup_rec
                  FROM fnd_concurrent_programs fcp, fnd_lookup_values flv
                 WHERE     fcp.concurrent_program_id = g_num_program_id
                       AND fcp.application_id = g_num_program_appl_id
                       AND flv.language = 'US'
                       AND flv.lookup_type = 'XXDO_WMS_INTERFACES_SETUP'
                       AND flv.lookup_code = fcp.concurrent_program_name;
            ELSE
                SELECT flv.*
                  INTO l_interface_setup_rec
                  FROM fnd_lookup_values flv
                 WHERE     flv.language = 'US'
                       AND flv.lookup_type = 'XXDO_WMS_INTERFACES_SETUP'
                       AND flv.lookup_code = p_in_chr_interface_prgm_name;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                    'Unable to get the inteface setup due to ' || SQLERRM);
                RETURN NULL;
        END;

        RETURN TO_DATE (l_interface_setup_rec.attribute12,
                        'DD-Mon-RRRR HH24:MI:SS');
    EXCEPTION
        WHEN OTHERS
        THEN
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                   'Unexpected error at get interface last run time procedure : '
                || SQLERRM);
            RETURN NULL;
    END get_last_run_time;

    PROCEDURE set_last_run_time (p_in_chr_interface_prgm_name   IN VARCHAR2,
                                 p_in_dte_run_time              IN DATE)
    IS
    BEGIN
        BEGIN
            IF p_in_chr_interface_prgm_name IS NULL
            THEN
                UPDATE fnd_lookup_values flv
                   SET attribute12 = TO_CHAR (p_in_dte_run_time, 'DD-Mon-RRRR HH24:MI:SS')
                 WHERE     flv.language = 'US'
                       AND flv.lookup_type = 'XXDO_WMS_INTERFACES_SETUP'
                       AND flv.lookup_code =
                           (SELECT fcp.concurrent_program_name
                              FROM fnd_concurrent_programs fcp
                             WHERE     fcp.concurrent_program_id =
                                       g_num_program_id
                                   AND fcp.application_id =
                                       g_num_program_appl_id);
            ELSE
                UPDATE fnd_lookup_values flv
                   SET attribute12 = TO_CHAR (p_in_dte_run_time, 'DD-Mon-RRRR HH24:MI:SS')
                 WHERE     flv.language = 'US'
                       AND flv.lookup_type = 'XXDO_WMS_INTERFACES_SETUP'
                       AND flv.lookup_code = p_in_chr_interface_prgm_name;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                       'Unexpected error while updating the next run time : '
                    || SQLERRM);
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                   'Unexpected error at set interface last run time procedure : '
                || SQLERRM);
    END set_last_run_time;

    FUNCTION highjump_enabled_whse (p_org_code IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_highjump_whse   VARCHAR2 (1) := 'N';
        lv_whse_count      NUMBER := 0;
    BEGIN
        SELECT COUNT (*)
          INTO lv_whse_count
          FROM fnd_lookup_values fvl
         WHERE     fvl.lookup_type = 'XXONT_WMS_WHSE'
               AND NVL (LANGUAGE, USERENV ('LANG')) = USERENV ('LANG')
               AND fvl.enabled_flag = 'Y'
               AND end_date_active IS NULL
               AND fvl.lookup_code = p_org_code;

        IF lv_whse_count > 0
        THEN
            lv_highjump_whse   := 'Y';
        ELSE
            lv_highjump_whse   := 'N';
        END IF;

        RETURN lv_highjump_whse;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN 'N';
        WHEN OTHERS
        THEN
            RETURN 'N';
    END highjump_enabled_whse;

    FUNCTION HIGHJUMP_ENABLED_Delivery (p_delivery_id IN NUMBER)
        RETURN VARCHAR2
    IS
        lv_highjump_whse   VARCHAR2 (1) := 'N';
        lv_whse_count      NUMBER := 0;
    BEGIN
        SELECT COUNT (1)
          INTO lv_whse_count
          FROM WSH_NEW_DELIVERIES WND
         WHERE     wnd.delivery_id = p_delivery_id
               AND wnd.organization_id IN
                       (SELECT mp.organization_id
                          FROM fnd_lookup_values fvl, mtl_parameters mp
                         WHERE     fvl.lookup_type = 'XXONT_WMS_WHSE'
                               AND NVL (LANGUAGE, USERENV ('LANG')) =
                                   USERENV ('LANG')
                               AND fvl.enabled_flag = 'Y'
                               AND fvl.lookup_code = mp.organization_code);

        IF lv_whse_count > 0
        THEN
            lv_highjump_whse   := 'Y';
        ELSE
            lv_highjump_whse   := 'N';
        END IF;

        RETURN lv_highjump_whse;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN 'N';
        WHEN OTHERS
        THEN
            RETURN 'N';
    END highjump_enabled_delivery;
END xxdo_ont_wms_intf_util_pkg;
/
