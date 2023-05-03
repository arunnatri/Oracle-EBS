--
-- XXDO_GTN_PO_CONSTRAINT  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:56 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_GTN_PO_CONSTRAINT"
AS
    PROCEDURE check_po_approved (p_application_id IN NUMBER, p_entity_short_name IN VARCHAR2, p_validation_entity_short_name IN VARCHAR2, p_validation_tmplt_short_name IN VARCHAR2, p_record_set_tmplt_short_name IN VARCHAR2, p_scope IN VARCHAR2
                                 , p_result OUT NOCOPY /* file.sql.39 change */
                                                      NUMBER)
    IS
        l_line_id                NUMBER := apps.oe_line_security.g_record.line_id;
        l_header_id              NUMBER := apps.oe_line_security.g_record.header_id;
        l_ato_line_id            NUMBER := apps.oe_line_security.g_record.ato_line_id;
        l_item_type_code         VARCHAR2 (30)
            := apps.oe_line_security.g_record.item_type_code;
        l_source_type_code       VARCHAR2 (30)
            := apps.oe_line_security.g_record.source_type_code;
        l_operation              VARCHAR2 (30)
                                     := apps.oe_line_security.g_record.operation;
        l_debug_level   CONSTANT NUMBER := apps.oe_debug_pub.g_debug_level;
        l_po_header_id           NUMBER;
        lv_gtn_flag              VARCHAR2 (1);
        --bug 4411054
        --l_po_status             VARCHAR2(4100);
        --l_po_status_rec          po_status_rec_type;
        l_return_status          VARCHAR2 (1);
        l_autorization_status    VARCHAR2 (30);
        l_po_release_id          NUMBER;                        -- bug 5328526
    BEGIN
        p_result   := 0;

        IF NVL (l_line_id, apps.fnd_api.g_miss_num) = apps.fnd_api.g_miss_num
        THEN
            RETURN;
        END IF;

        IF    l_source_type_code <> 'EXTERNAL'
           OR NVL (l_source_type_code, apps.fnd_api.g_miss_char) =
              apps.fnd_api.g_miss_char
        THEN
            RETURN;
        END IF;

        IF     (l_ato_line_id IS NOT NULL AND l_ato_line_id <> apps.fnd_api.g_miss_num)
           AND NOT (l_item_type_code IN ('OPTION', 'STANDARD') AND l_ato_line_id = l_line_id)
        THEN
            IF l_debug_level > 0
            THEN
                apps.oe_debug_pub.ADD (
                    'Line part of a ATO Model: ' || l_ato_line_id,
                    2);
            END IF;

            SELECT po_header_id, po_release_id
              INTO l_po_header_id, l_po_release_id               --bug 5328526
              FROM apps.oe_drop_ship_sources ds, apps.oe_order_lines l
             WHERE     ds.header_id = l_header_id
                   AND l.item_type_code = 'CONFIG'
                   AND l.line_id = ds.line_id
                   AND l.ato_line_id = l_ato_line_id;
        ELSE
            IF     (l_operation IS NOT NULL AND l_operation <> apps.fnd_api.g_miss_char)
               AND l_operation <> apps.oe_globals.g_opr_create
            THEN
                SELECT po_header_id, po_release_id
                  INTO l_po_header_id, l_po_release_id           --bug 5328526
                  FROM apps.oe_drop_ship_sources
                 WHERE line_id = l_line_id AND header_id = l_header_id;
            END IF;
        END IF;

        IF l_po_header_id IS NOT NULL
        THEN
            -- comment out for bug 4411054
            /*l_po_status := UPPER(PO_HEADERS_SV3.Get_PO_Status
                                            (x_po_header_id => l_po_header_id
                                            ));

            IF l_debug_level > 0 THEN
               OE_DEBUG_PUB.Add('Check PO Status : '|| l_po_status, 2);
            END IF;
            */
            BEGIN
                SELECT attribute11
                  INTO lv_gtn_flag
                  FROM apps.po_headers_all
                 WHERE po_header_id = l_po_header_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_result   := 1;
            END;
        END IF;

        --IF (INSTR(nvl(l_po_status,'z'), 'APPROVED') <> 0 ) THEN
        IF (NVL (lv_gtn_flag, 'N') <> 'Y')
        THEN
            p_result   := 1;
        ELSE
            p_result   := 0;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_result   := 1;
    END check_po_approved;
END;
/
