--
-- XXD_ONT_EDI_INTERFACE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:43 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_EDI_INTERFACE_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_EDI_INTERFACE_PKG
    * Description  : This is package for WMS(Highjump) to edi Interface
    * Notes        :
    * Modification :
    -- ===========  ========    ======================= =====================================
    -- Date         Version#    Name                    Comments
    -- ===========  ========    ======================= =======================================
    -- 11-Mar-2020  1.1         Tejaswi Gangumalla      Intial version
    -- 03-Sep-2020  1.2         Viswanathan Pandian     Updated for CCR0008881
    -- 03-Jul-2020  1.3         Showkath Ali            CCR0008848 -- SPS Enable for EDI Customers
    -- 18-May-2022  1.4         Elaine Yang             Updated for CCR0009997
    ******************************************************************************************/
    gn_user_id   NUMBER := fnd_global.user_id;


    ---added by CCR0009997
    /**************************************************
       Function: get_root_line_buyer_part_num
       Parameters:
        p_child_line_id: current line id
       Purpose:
        retrieve the root line in order to get buyer
        part number of root line
    ***************************************************/
    FUNCTION get_root_line_buyer_part_num (p_child_line_id NUMBER)
        RETURN VARCHAR2
    IS
        x_buyer_part_number   VARCHAR2 (500) := NULL;
        ln_parent_line_id     NUMBER;
        ln_child_line_id      NUMBER;
    BEGIN
        SELECT line_id, split_From_line_id
          INTO ln_child_line_id, ln_parent_line_id
          FROM oe_order_lines_all
         WHERE line_id = p_child_line_id;

        WHILE ln_parent_line_id IS NOT NULL
        LOOP
            SELECT line_id, split_From_line_id
              INTO ln_child_line_id, ln_parent_line_id
              FROM oe_order_lines_all
             WHERE line_id = ln_parent_line_id;
        END LOOP;

        BEGIN
            SELECT attribute7
              INTO x_buyer_part_number
              FROM apps.oe_order_lines_all
             WHERE line_id = ln_child_line_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                x_buyer_part_number   := NULL;
            WHEN OTHERS
            THEN
                x_buyer_part_number   := NULL;
        END;

        RETURN x_buyer_part_number;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN x_buyer_part_number;
        WHEN OTHERS
        THEN
            RETURN x_buyer_part_number;
    END get_root_line_buyer_part_num;

    --end of added by CCR0009997

    -- 1.3 changes start
    /***********************************************************************************************
    **************** Function to get SPS or NOT for a given customer *******************************
    ************************************************************************************************/
    FUNCTION get_customer_type (p_customer_number IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_sps_customer   VARCHAR2 (10) := NULL;
    BEGIN
        BEGIN
            -- check whether the customer is SFS customer or not
            SELECT attribute1
              INTO lv_sps_customer
              FROM fnd_lookup_values flv
             WHERE     1 = 1
                   AND flv.lookup_type = 'XXDO_EDI_CUSTOMERS'
                   AND flv.language = 'US'
                   AND NVL (flv.enabled_flag, 'N') = 'Y'
                   AND NVL (TRUNC (flv.start_date_active), TRUNC (SYSDATE)) <=
                       TRUNC (SYSDATE)
                   AND NVL (TRUNC (flv.end_date_active), TRUNC (SYSDATE)) >=
                       TRUNC (SYSDATE)
                   AND lookup_code = p_customer_number;

            fnd_file.put_line (
                fnd_file.LOG,
                   'The customer service is:'
                || lv_sps_customer
                || '-'
                || 'for customer:'
                || p_customer_number);
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_sps_customer   := NULL;
        END;

        RETURN lv_sps_customer;
    END get_customer_type;

    --1.3 changes end


    PROCEDURE edi_outbound (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2)
    IS
        CURSOR parcel_dropship_shipments IS
              SELECT ooh.sold_to_org_id, ooh.attribute5 brand, hca.account_number,
                     head.shipment_number, NVL (ool.deliver_to_org_id, 1) deliver_to_org_id
                FROM xxdo_ont_ship_conf_order_stg ord, oe_order_headers_all ooh, hz_cust_accounts_all hca,
                     oe_order_lines_all ool, xxdo_ont_ship_conf_carton_stg carton, xxdo_ont_ship_conf_head_stg head
               WHERE     1 = 1
                     AND ord.order_header_id = ooh.header_id
                     AND ooh.sold_to_org_id = hca.cust_account_id
                     AND ooh.header_id = ool.header_id
                     AND ord.edi_eligible = 'Y'
                     AND ord.edi_creation_status = 'INPROCESS'
                     AND carton.process_status = 'PROCESSED'
                     AND ord.process_status = 'PROCESSED'
                     AND head.process_status = 'PROCESSED'
                     AND carton.shipment_number = ord.shipment_number
                     AND carton.order_number = ord.order_number
                     AND head.shipment_number = ord.shipment_number
                     AND UPPER (head.shipment_type) = 'PARCEL'
                     AND UPPER (head.sales_channel) = 'DROPSHIP'
            GROUP BY ooh.sold_to_org_id, ooh.attribute5, hca.account_number,
                     head.shipment_number, NVL (ool.deliver_to_org_id, 1);

        CURSOR parcel_dropship_delivery (cn_sold_to_org_id      IN NUMBER,
                                         cv_brand               IN VARCHAR2,
                                         cn_deliver_to_org_id   IN NUMBER,
                                         cn_account_number      IN VARCHAR2,
                                         cn_shipment_number     IN VARCHAR2)
        IS
            SELECT DISTINCT ord.*
              FROM xxdo_ont_ship_conf_order_stg ord, oe_order_headers_all ooh, oe_order_lines_all ool,
                   wsh_delivery_assignments wda, wsh_delivery_details wdd, hz_cust_accounts_all hca
             WHERE     1 = 1
                   AND ord.shipment_number = cn_shipment_number
                   AND ord.order_header_id = ooh.header_id
                   AND ooh.sold_to_org_id = cn_sold_to_org_id
                   AND ooh.attribute5 = cv_brand
                   AND ooh.header_id = ool.header_id
                   AND ord.process_status = 'PROCESSED'
                   AND NVL (ool.deliver_to_org_id, 1) =
                       NVL (cn_deliver_to_org_id, 1)
                   AND NVL (ord.delivery_id, ord.order_number) =
                       wda.delivery_id
                   AND wda.delivery_detail_id = wdd.delivery_detail_id
                   AND wdd.source_code = 'OE'
                   AND wdd.source_line_id = ool.line_id
                   AND wdd.source_header_id = ool.header_id
                   AND ooh.sold_to_org_id = hca.cust_account_id
                   AND hca.account_number = cn_account_number;

        CURSOR parcel_nondropship_shipments IS
            SELECT DISTINCT ooh.sold_to_org_id,
                            ooh.attribute5 brand,
                            hca.account_number,
                            head.shipment_number,
                            (SELECT ool.ship_to_org_id
                               FROM apps.oe_order_lines_all ool, apps.wsh_delivery_details wdd, apps.wsh_delivery_assignments wda
                              WHERE     ooh.header_id = ool.header_id
                                    AND ool.line_id = wdd.source_line_id
                                    AND wdd.source_code = 'OE'
                                    AND wdd.delivery_detail_id =
                                        wda.delivery_detail_id
                                    AND wda.delivery_id = ord.order_number
                                    AND ROWNUM = 1) ship_to_org_id
              FROM xxdo_ont_ship_conf_order_stg ord, oe_order_headers_all ooh, hz_cust_accounts_all hca,
                   oe_order_lines_all ool, xxdo_ont_ship_conf_carton_stg carton, xxdo_ont_ship_conf_head_stg head
             WHERE     1 = 1
                   AND ord.order_header_id = ooh.header_id
                   AND ooh.sold_to_org_id = hca.cust_account_id
                   AND ooh.header_id = ool.header_id
                   AND ord.edi_eligible = 'Y'
                   AND ord.edi_creation_status = 'INPROCESS'
                   AND carton.process_status = 'PROCESSED'
                   AND ord.process_status = 'PROCESSED'
                   AND head.process_status = 'PROCESSED'
                   AND carton.shipment_number = ord.shipment_number
                   AND carton.order_number = ord.order_number
                   AND head.shipment_number = ord.shipment_number
                   AND UPPER (head.shipment_type) = 'PARCEL'
                   AND UPPER (head.sales_channel) NOT IN ('DROPSHIP', 'ECOM');

        CURSOR parcel_nondropship_delivery (cn_sold_to_org_id    IN NUMBER,
                                            cv_brand             IN VARCHAR2,
                                            cn_ship_to_org_id    IN NUMBER,
                                            cn_account_number    IN VARCHAR2,
                                            cn_shipment_number   IN VARCHAR2)
        IS
            SELECT DISTINCT ord.*
              FROM xxdo_ont_ship_conf_order_stg ord, oe_order_headers_all ooh, oe_order_lines_all ool,
                   wsh_delivery_assignments wda, wsh_delivery_details wdd, hz_cust_accounts_all hca
             WHERE     1 = 1
                   AND ord.shipment_number = cn_shipment_number
                   AND ord.order_header_id = ooh.header_id
                   AND ooh.sold_to_org_id = cn_sold_to_org_id
                   AND ooh.attribute5 = cv_brand
                   AND ooh.header_id = ool.header_id
                   AND ool.ship_to_org_id = cn_ship_to_org_id
                   AND NVL (ord.delivery_id, ord.order_number) =
                       wda.delivery_id
                   AND wda.delivery_detail_id = wdd.delivery_detail_id
                   AND wdd.source_code = 'OE'
                   AND ord.process_status = 'PROCESSED'
                   AND wdd.source_line_id = ool.line_id
                   AND wdd.source_header_id = ool.header_id
                   AND ooh.sold_to_org_id = hca.cust_account_id
                   AND hca.account_number = cn_account_number;

        CURSOR nonparcel_shipments IS
              SELECT DISTINCT ooh.sold_to_org_id, ooh.attribute5 brand, hca.account_number,
                              head.bol_number
                FROM xxdo_ont_ship_conf_order_stg ord, oe_order_headers_all ooh, hz_cust_accounts_all hca,
                     oe_order_lines_all ool, xxdo_ont_ship_conf_carton_stg carton, xxdo_ont_ship_conf_head_stg head
               WHERE     1 = 1
                     AND ord.order_header_id = ooh.header_id
                     AND ooh.sold_to_org_id = hca.cust_account_id
                     AND ooh.header_id = ool.header_id
                     AND ord.edi_eligible = 'Y'
                     AND ord.edi_creation_status = 'INPROCESS'
                     AND carton.shipment_number = ord.shipment_number
                     AND carton.order_number = ord.order_number
                     AND head.shipment_number = ord.shipment_number
                     AND carton.process_status = 'PROCESSED'
                     AND ord.process_status = 'PROCESSED'
                     AND head.process_status = 'PROCESSED'
                     AND UPPER (head.shipment_type) = 'NON-PARCEL'
                     AND head.bol_number IS NOT NULL
            GROUP BY ooh.sold_to_org_id, ooh.attribute5, hca.account_number,
                     head.bol_number;

        CURSOR nonparcel_shipments_dc (cn_sold_to_org_id IN NUMBER, cv_brand IN VARCHAR2, cn_account_number IN VARCHAR2
                                       , cn_bol_number IN VARCHAR2)
        IS
            SELECT DISTINCT addr.attribute5 ship_to_dc
              FROM xxdo_ont_ship_conf_order_stg ord, oe_order_headers_all ooh, hz_cust_accounts_all hca,
                   oe_order_lines_all ool, xxdo_ont_ship_conf_head_stg head, apps.xxd_ra_site_uses_morg_v su,
                   apps.xxd_ra_addresses_morg_v addr, apps.wsh_delivery_assignments wda, apps.wsh_delivery_details wdd
             WHERE     1 = 1
                   AND ord.order_header_id = ooh.header_id
                   AND ooh.sold_to_org_id = hca.cust_account_id
                   AND ooh.header_id = ool.header_id
                   AND ord.edi_eligible = 'Y'
                   AND ord.edi_creation_status = 'INPROCESS'
                   AND ord.process_status = 'PROCESSED'
                   AND head.process_status = 'PROCESSED'
                   AND head.shipment_number = ord.shipment_number
                   AND UPPER (head.shipment_type) = 'NON-PARCEL'
                   AND ooh.sold_to_org_id = cn_sold_to_org_id
                   AND ooh.attribute5 = cv_brand
                   AND hca.account_number = cn_account_number
                   AND head.bol_number = cn_bol_number
                   AND su.site_use_id = ool.ship_to_org_id
                   AND addr.address_id = su.address_id
                   AND addr.attribute5 IS NOT NULL
                   AND addr.attribute2 IS NOT NULL
                   AND ord.order_number = wda.delivery_id
                   AND wda.delivery_detail_id = wdd.delivery_detail_id
                   AND wdd.source_code = 'OE'
                   AND wdd.source_line_id = ool.line_id;

        CURSOR nonparcel_dc_delivery (cn_sold_to_org_id   IN NUMBER,
                                      cv_brand            IN VARCHAR2,
                                      cn_account_number   IN VARCHAR2,
                                      cn_bol_number       IN VARCHAR2,
                                      cn_ship_to_dc       IN VARCHAR2)
        IS
            SELECT DISTINCT ord.*
              FROM xxdo_ont_ship_conf_order_stg ord, xxdo_ont_ship_conf_head_stg head, oe_order_headers_all ooh,
                   oe_order_lines_all ool, wsh_delivery_assignments wda, wsh_delivery_details wdd,
                   hz_cust_accounts_all hca, apps.xxd_ra_site_uses_morg_v su, apps.xxd_ra_addresses_morg_v addr
             WHERE     1 = 1
                   AND head.bol_number = cn_bol_number
                   AND ord.shipment_number = head.shipment_number
                   AND ord.order_header_id = ooh.header_id
                   AND ooh.sold_to_org_id = cn_sold_to_org_id
                   AND ooh.attribute5 = cv_brand
                   AND ooh.header_id = ool.header_id
                   AND NVL (ord.delivery_id, ord.order_number) =
                       wda.delivery_id
                   AND wda.delivery_detail_id = wdd.delivery_detail_id
                   AND wdd.source_code = 'OE'
                   AND wdd.source_line_id = ool.line_id
                   AND ord.process_status = 'PROCESSED'
                   AND head.process_status = 'PROCESSED'
                   AND wdd.source_header_id = ool.header_id
                   AND ooh.sold_to_org_id = hca.cust_account_id
                   AND hca.account_number = cn_account_number
                   AND su.site_use_id = ool.ship_to_org_id
                   AND addr.address_id = su.address_id
                   AND addr.attribute5 = cn_ship_to_dc;

        CURSOR nonparcel_shipments_loc_id (cn_sold_to_org_id IN NUMBER, cv_brand IN VARCHAR2, cn_account_number IN VARCHAR2
                                           , cn_bol_number IN VARCHAR2)
        IS
            SELECT DISTINCT ord.ship_to_location_id
              FROM xxdo_ont_ship_conf_order_stg ord, oe_order_headers_all ooh, hz_cust_accounts_all hca,
                   oe_order_lines_all ool, xxdo_ont_ship_conf_head_stg head, apps.xxd_ra_site_uses_morg_v su,
                   apps.xxd_ra_addresses_morg_v addr, apps.wsh_delivery_assignments wda, apps.wsh_delivery_details wdd
             WHERE     1 = 1
                   AND ord.order_header_id = ooh.header_id
                   AND ooh.sold_to_org_id = hca.cust_account_id
                   AND ooh.header_id = ool.header_id
                   AND ord.edi_eligible = 'Y'
                   AND ord.edi_creation_status = 'INPROCESS'
                   AND head.shipment_number = ord.shipment_number
                   AND UPPER (head.shipment_type) = 'NON-PARCEL'
                   AND ord.process_status = 'PROCESSED'
                   AND head.process_status = 'PROCESSED'
                   AND ooh.sold_to_org_id = cn_sold_to_org_id
                   AND ooh.attribute5 = cv_brand
                   AND hca.account_number = cn_account_number
                   AND head.bol_number = cn_bol_number
                   AND su.site_use_id = ool.ship_to_org_id
                   AND addr.address_id = su.address_id
                   AND (addr.attribute5 IS NULL OR addr.attribute2 IS NULL)
                   AND ord.order_number = wda.delivery_id
                   AND wda.delivery_detail_id = wdd.delivery_detail_id
                   AND wdd.source_code = 'OE'
                   AND wdd.source_line_id = ool.line_id;

        CURSOR nonparcel_delivery (cn_sold_to_org_id       IN NUMBER,
                                   cv_brand                IN VARCHAR2,
                                   cn_account_number       IN VARCHAR2,
                                   cn_bol_number           IN VARCHAR2,
                                   cn_shipment_to_loc_id   IN NUMBER)
        IS
            SELECT DISTINCT ord.*
              FROM xxdo_ont_ship_conf_order_stg ord, xxdo_ont_ship_conf_head_stg head, oe_order_headers_all ooh,
                   oe_order_lines_all ool, wsh_delivery_assignments wda, wsh_delivery_details wdd,
                   hz_cust_accounts_all hca
             WHERE     1 = 1
                   AND head.bol_number = cn_bol_number
                   AND ord.shipment_number = head.shipment_number
                   AND ord.order_header_id = ooh.header_id
                   AND ooh.sold_to_org_id = cn_sold_to_org_id
                   AND ooh.attribute5 = cv_brand
                   AND ooh.header_id = ool.header_id
                   AND ord.process_status = 'PROCESSED'
                   AND head.process_status = 'PROCESSED'
                   AND NVL (ord.delivery_id, ord.order_number) =
                       wda.delivery_id
                   AND wda.delivery_detail_id = wdd.delivery_detail_id
                   AND wdd.source_code = 'OE'
                   AND wdd.source_line_id = ool.line_id
                   AND wdd.source_header_id = ool.header_id
                   AND ooh.sold_to_org_id = hca.cust_account_id
                   AND hca.account_number = cn_account_number
                   AND ord.ship_to_location_id = cn_shipment_to_loc_id;

        ln_shipment_id        NUMBER;
        ln_derived_del_id     NUMBER;
        lv_record_exists      VARCHAR2 (2);
        ln_min_tracking_num   VARCHAR2 (100);
        ln_char_incrment      VARCHAR2 (1) := NULL;
        ln_loop_count         NUMBER := 1;
        lv_sps_customer       VARCHAR2 (1) := NULL;                     -- 1.3
    BEGIN
        /* Update EDI eligible records to "INPROCESS"*/
        BEGIN
            UPDATE xxdo_ont_ship_conf_order_stg
               SET edi_creation_status   = 'INPROCESS'
             WHERE edi_eligible = 'Y' AND edi_creation_status = 'NEW';

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_retcode   := '1';
                pv_errbuf    :=
                       'Error occurred while updating records to Inprocess: '
                    || SQLERRM;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error occurred while updating records to Inprocess: '
                    || SQLERRM);
        END;

        FOR parcel_dropship_rec IN parcel_dropship_shipments
        LOOP
            ln_shipment_id        := NULL;
            ln_min_tracking_num   := NULL;

            BEGIN
                SELECT MIN (carton.tracking_number)
                  INTO ln_min_tracking_num
                  FROM xxdo_ont_ship_conf_carton_stg carton, xxdo_ont_ship_conf_order_stg ord, oe_order_headers_all ooh,
                       oe_order_lines_all ool, hz_cust_accounts_all hca, -- Start changes for CCR0008881
                                                                         wsh_delivery_assignments wda,
                       wsh_delivery_details wdd
                 -- End changes for CCR0008881
                 WHERE     ord.shipment_number =
                           parcel_dropship_rec.shipment_number
                       AND carton.shipment_number =
                           parcel_dropship_rec.shipment_number
                       AND carton.order_number = ord.order_number
                       AND ord.order_header_id = ooh.header_id
                       AND ooh.attribute5 = parcel_dropship_rec.brand
                       AND ooh.sold_to_org_id =
                           parcel_dropship_rec.sold_to_org_id
                       AND ooh.sold_to_org_id = hca.cust_account_id
                       AND carton.process_status = 'PROCESSED'
                       AND ord.process_status = 'PROCESSED'
                       AND hca.account_number =
                           parcel_dropship_rec.account_number
                       AND carton.tracking_number IS NOT NULL
                       AND ooh.header_id = ool.header_id
                       AND NVL (ool.deliver_to_org_id, 1) =
                           NVL (parcel_dropship_rec.deliver_to_org_id, 1)
                       -- Start changes for CCR0008881
                       AND ord.order_number = wda.delivery_id
                       AND wda.delivery_detail_id = wdd.delivery_detail_id
                       AND wdd.source_code = 'OE'
                       AND wdd.source_header_id = ool.header_id
                       AND wdd.source_line_id = ool.line_id;
            -- End changes for CCR0008881
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_min_tracking_num   := NULL;
            END;

            do_edi.get_next_values ('DO_EDI856_SHIPMENTS', 1, ln_shipment_id);
            --1.3 changes start
            lv_sps_customer       := NULL;
            lv_sps_customer       :=
                get_customer_type (parcel_dropship_rec.account_number);

            --1.3 changes end

            BEGIN
                INSERT INTO do_edi.do_edi856_shipments (shipment_id, asn_status, asn_date, invoice_date, customer_id, ship_to_org_id, waybill, seal_code, trailer_number, tracking_number, pro_number, est_delivery_date, creation_date, created_by, last_update_date, last_updated_by, archive_flag, organization_id, location_id, request_sent_date, reply_rcv_date, scheduled_pu_date, bill_of_lading, carrier, carrier_scac, comments, confirm_sent_date, contact_name, cust_shipment_id, earliest_pu_date, latest_pu_date, load_id, routing_status, ship_confirm_date, shipment_weight, shipment_weight_uom
                                                        , sps_event     -- 1.3
                                                                   )
                    SELECT ln_shipment_id,
                           'R',
                           NULL,
                           NULL,
                           parcel_dropship_rec.sold_to_org_id,
                           -1 /* ship to org id is inserted -1 first and updated later */
                             ,
                           head.bol_number,
                           head.seal_number,
                           head.trailer_number,
                           ln_min_tracking_num
                               tracking_number,
                           head.pro_number,
                           head.ship_date + 3
                               est_delivery_date,
                           SYSDATE
                               creation_date,
                           gn_user_id
                               created_by,
                           SYSDATE
                               last_update_date,
                           gn_user_id
                               last_updated_by,
                           'N'
                               archive_flag,
                           (SELECT organization_id
                              FROM mtl_parameters mp
                             WHERE mp.organization_code = head.wh_id)
                               ship_from_org_id,
                           -1
                               location_id,
                           NULL
                               request_sent_date,
                           NULL
                               reply_rcv_date,
                           NULL
                               scheduled_pu_date,
                           NULL
                               bill_of_lading,
                           head.carrier,
                           (SELECT scac_code
                              FROM wsh_carriers_v
                             WHERE freight_code = head.carrier)
                               carrier_scac,
                           head.comments,
                           NULL
                               confirm_sent_date,
                           NULL
                               contact_name,
                           NULL
                               cust_shipment_id,
                           NULL
                               earliest_pu_date,
                           NULL
                               latest_pu_date,
                           SUBSTR (head.customer_load_id, 1, 30) -- Updated from 10 to 30 for CCR0008881
                               load_id,
                           NULL
                               routing_status,
                           head.ship_date
                               ship_confirm_date,
                           NULL
                               shipment_weight,
                           'LB'
                               shipment_weight_uom,
                           lv_sps_customer                              -- 1.3
                      FROM xxdo_ont_ship_conf_head_stg head
                     WHERE     head.shipment_number =
                               parcel_dropship_rec.shipment_number
                           AND head.process_status = 'PROCESSED';
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_retcode   := '1';
                    pv_errbuf    :=
                           'Error occurred while inserting into table do_edi856_shipments: '
                        || SQLERRM;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error occurred while inserting into table do_edi856_shipments: '
                        || SQLERRM);
            END;


            FOR parcel_dropship_del_rec
                IN parcel_dropship_delivery (
                       parcel_dropship_rec.sold_to_org_id,
                       parcel_dropship_rec.brand,
                       parcel_dropship_rec.deliver_to_org_id,
                       parcel_dropship_rec.account_number,
                       parcel_dropship_rec.shipment_number)
            LOOP
                /* update ship to org ID on ASN header only once. Any ship-to in this shipment is fine*/

                BEGIN
                    UPDATE do_edi.do_edi856_shipments
                       SET ship_to_org_id = parcel_dropship_del_rec.ship_to_org_id
                     WHERE     shipment_id = ln_shipment_id
                           AND ship_to_org_id = -1;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pv_retcode   := '1';
                        pv_errbuf    :=
                               'Error occurred while updating ship_to_org_id in table do_edi856_shipments: '
                            || SQLERRM;
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error occurred while updating ship_to_org_id in table do_edi856_shipments: '
                            || SQLERRM);
                END;

                ln_derived_del_id   :=
                    NVL (parcel_dropship_del_rec.delivery_id,
                         parcel_dropship_del_rec.order_number);
                lv_record_exists   := 'N';

                --- To check whether the delivery is already interfaced

                BEGIN
                    SELECT 'Y'
                      INTO lv_record_exists
                      FROM do_edi.do_edi856_pick_tickets
                     WHERE delivery_id = ln_derived_del_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_record_exists   := 'N';
                END;

                IF lv_record_exists = 'N'
                THEN
                    BEGIN
                        INSERT INTO do_edi.do_edi856_pick_tickets (
                                        shipment_id,
                                        delivery_id,
                                        weight,
                                        weight_uom,
                                        number_cartons,
                                        cartons_uom,
                                        volume,
                                        volume_uom,
                                        ordered_qty,
                                        shipped_qty,
                                        shipped_qty_uom,
                                        source_header_id,
                                        intmed_ship_to_org_id,
                                        creation_date,
                                        created_by,
                                        last_update_date,
                                        last_updated_by,
                                        archive_flag,
                                        shipment_key)
                              SELECT ln_shipment_id,
                                     ln_derived_del_id,
                                     (SELECT SUM (NVL (cartoni.weight, 0))
                                        FROM xxdo_ont_ship_conf_order_stg ordi, xxdo_ont_ship_conf_carton_stg cartoni
                                       WHERE     1 = 1
                                             AND ordi.order_number =
                                                 ord.order_number
                                             AND ordi.order_header_id =
                                                 ord.order_header_id
                                             AND ordi.shipment_number =
                                                 ord.shipment_number
                                             AND ordi.process_status =
                                                 'PROCESSED'
                                             AND ordi.shipment_number =
                                                 cartoni.shipment_number
                                             AND ordi.order_number =
                                                 cartoni.order_number
                                             AND cartoni.process_status =
                                                 'PROCESSED')
                                         weight,
                                     'LB'
                                         weight_uom,
                                     COUNT (DISTINCT carton.carton_number)
                                         number_cartons,
                                     'EA'
                                         cartons_uom,
                                     (SELECT SUM (NVL (cartoni.LENGTH, 1) * NVL (cartoni.width, 1) * NVL (cartoni.height, 1))
                                        FROM xxdo_ont_ship_conf_order_stg ordi, xxdo_ont_ship_conf_carton_stg cartoni
                                       WHERE     1 = 1
                                             AND ordi.order_number =
                                                 ord.order_number
                                             AND ordi.order_header_id =
                                                 ord.order_header_id
                                             AND ordi.shipment_number =
                                                 ord.shipment_number
                                             AND ordi.process_status =
                                                 'PROCESSED'
                                             AND ordi.shipment_number =
                                                 cartoni.shipment_number
                                             AND ordi.order_number =
                                                 cartoni.order_number
                                             AND cartoni.process_status =
                                                 'PROCESSED')
                                         volume,
                                     'CI'
                                         volume_uom,
                                     SUM (qty)
                                         ordered_qty,
                                     SUM (qty)
                                         shipped_qty,
                                     'EA'
                                         shipped_qty_uom,
                                     ord.order_header_id
                                         source_header_id,
                                     NULL
                                         intmed_ship_to_org_id,
                                     SYSDATE
                                         creation_date,
                                     gn_user_id
                                         created_by,
                                     SYSDATE
                                         last_update_date,
                                     gn_user_id
                                         last_updated_by,
                                     'N'
                                         archive_flag,
                                     (SELECT ln_shipment_id || brand_code
                                        FROM do_custom.do_brands db, mtl_parameters mp, mtl_system_items_kfv msi,
                                             mtl_item_categories mic, mtl_categories_b mc, mtl_category_sets mcs,
                                             xxdo_ont_ship_conf_order_stg ordi, xxdo_ont_ship_conf_carton_stg cartoni, xxdo_ont_ship_conf_cardtl_stg cardtli
                                       WHERE     msi.concatenated_segments =
                                                 cardtli.item_number
                                             AND msi.organization_id =
                                                 mic.organization_id
                                             AND msi.inventory_item_id =
                                                 mic.inventory_item_id
                                             AND mcs.category_set_id =
                                                 mic.category_set_id
                                             AND mcs.category_set_id = 1
                                             AND mc.category_id =
                                                 mic.category_id
                                             AND UPPER (mc.segment1) =
                                                 db.brand_name
                                             AND mp.organization_code =
                                                 ord.wh_id
                                             AND mp.organization_id =
                                                 msi.organization_id
                                             AND ordi.process_status =
                                                 'PROCESSED'
                                             AND ordi.shipment_number =
                                                 ord.shipment_number
                                             AND cartoni.process_status =
                                                 'PROCESSED'
                                             AND ordi.shipment_number =
                                                 cartoni.shipment_number
                                             AND ordi.order_number =
                                                 cartoni.order_number
                                             AND cardtli.process_status =
                                                 'PROCESSED'
                                             AND cardtli.shipment_number =
                                                 ordi.shipment_number
                                             AND cardtli.order_number =
                                                 ordi.order_number
                                             AND cardtli.carton_number =
                                                 cartoni.carton_number
                                             AND ordi.order_number =
                                                 ord.order_number
                                             AND ordi.order_header_id =
                                                 ord.order_header_id
                                             AND ROWNUM < 2)
                                         shipment_key
                                FROM xxdo_ont_ship_conf_order_stg ord, xxdo_ont_ship_conf_carton_stg carton, xxdo_ont_ship_conf_cardtl_stg cardtl
                               WHERE     ord.shipment_number =
                                         parcel_dropship_del_rec.shipment_number
                                     AND ord.process_status = 'PROCESSED'
                                     AND ord.shipment_number =
                                         carton.shipment_number
                                     AND ord.order_number = carton.order_number
                                     AND carton.process_status = 'PROCESSED'
                                     AND cardtl.shipment_number =
                                         ord.shipment_number
                                     AND cardtl.order_number = ord.order_number
                                     AND cardtl.carton_number =
                                         carton.carton_number
                                     AND cardtl.process_status = 'PROCESSED'
                                     AND ord.order_number =
                                         parcel_dropship_del_rec.order_number
                            GROUP BY ord.order_number, ord.order_header_id, ord.wh_id,
                                     ord.shipment_number;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            pv_retcode   := '1';
                            pv_errbuf    :=
                                   'Error occurred while inserting into table do_edi856_pick_tickets: '
                                || SQLERRM;
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error occurred while inserting into table do_edi856_pick_tickets: '
                                || SQLERRM);
                    END;

                    BEGIN
                        UPDATE xxdo_ont_ship_conf_order_stg
                           SET attribute1 = ln_shipment_id, edi_creation_status = 'PROCESSED'
                         WHERE     order_number =
                                   parcel_dropship_del_rec.order_number
                               AND shipment_number =
                                   parcel_dropship_del_rec.shipment_number;

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            pv_retcode   := '1';
                            pv_errbuf    :=
                                   'Error occurred while updating attribute1 in table xxdo_ont_ship_conf_order_stg: '
                                || SQLERRM;
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error occurred while updating attribute1 in table xxdo_ont_ship_conf_order_stg: '
                                || SQLERRM);
                    END;
                END IF;
            END LOOP;
        END LOOP;

        FOR parcel_nondropship_rec IN parcel_nondropship_shipments
        LOOP
            ln_shipment_id        := NULL;
            ln_min_tracking_num   := NULL;
            lv_sps_customer       := NULL;                              -- 1.3

            BEGIN
                SELECT MIN (carton.tracking_number)
                  INTO ln_min_tracking_num
                  FROM xxdo_ont_ship_conf_carton_stg carton, xxdo_ont_ship_conf_order_stg ord, oe_order_headers_all ooh,
                       oe_order_lines_all ool, hz_cust_accounts_all hca, -- Start changes for CCR0008881
                                                                         wsh_delivery_assignments wda,
                       wsh_delivery_details wdd
                 -- End changes for CCR0008881
                 WHERE     ord.shipment_number =
                           parcel_nondropship_rec.shipment_number
                       AND carton.shipment_number =
                           parcel_nondropship_rec.shipment_number
                       AND carton.order_number = ord.order_number
                       AND ord.order_header_id = ooh.header_id
                       AND ooh.attribute5 = parcel_nondropship_rec.brand
                       AND carton.process_status = 'PROCESSED'
                       AND ord.process_status = 'PROCESSED'
                       AND ooh.sold_to_org_id = hca.cust_account_id
                       AND hca.account_number =
                           parcel_nondropship_rec.account_number
                       AND ooh.sold_to_org_id =
                           parcel_nondropship_rec.sold_to_org_id
                       AND ool.ship_to_org_id =
                           parcel_nondropship_rec.ship_to_org_id
                       AND carton.tracking_number IS NOT NULL
                       AND ooh.header_id = ool.header_id
                       -- Start changes for CCR0008881
                       AND ord.order_number = wda.delivery_id
                       AND wda.delivery_detail_id = wdd.delivery_detail_id
                       AND wdd.source_code = 'OE'
                       AND wdd.source_header_id = ool.header_id
                       AND wdd.source_line_id = ool.line_id;
            -- End changes for CCR0008881
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_min_tracking_num   := NULL;
            END;

            do_edi.get_next_values ('DO_EDI856_SHIPMENTS', 1, ln_shipment_id);
            fnd_file.put_line (fnd_file.LOG, 'Shipment ID' || ln_shipment_id);
            --1.3 changes start
            lv_sps_customer       := NULL;
            lv_sps_customer       :=
                get_customer_type (parcel_nondropship_rec.account_number);

            --1.3 changes end

            BEGIN
                INSERT INTO do_edi.do_edi856_shipments (shipment_id, asn_status, asn_date, invoice_date, customer_id, ship_to_org_id, waybill, seal_code, trailer_number, tracking_number, pro_number, est_delivery_date, creation_date, created_by, last_update_date, last_updated_by, archive_flag, organization_id, location_id, request_sent_date, reply_rcv_date, scheduled_pu_date, bill_of_lading, carrier, carrier_scac, comments, confirm_sent_date, contact_name, cust_shipment_id, earliest_pu_date, latest_pu_date, load_id, routing_status, ship_confirm_date, shipment_weight, shipment_weight_uom
                                                        , sps_event     -- 1.3
                                                                   )
                    SELECT ln_shipment_id,
                           'R',
                           NULL,
                           NULL,
                           parcel_nondropship_rec.sold_to_org_id,
                           parcel_nondropship_rec.ship_to_org_id,
                           head.bol_number,
                           head.seal_number,
                           head.trailer_number,
                           ln_min_tracking_num
                               tracking_number,
                           head.pro_number,
                           head.ship_date + 3
                               est_delivery_date,
                           SYSDATE
                               creation_date,
                           gn_user_id
                               created_by,
                           SYSDATE
                               last_update_date,
                           gn_user_id
                               last_updated_by,
                           'N'
                               archive_flag,
                           (SELECT organization_id
                              FROM mtl_parameters mp
                             WHERE mp.organization_code = head.wh_id)
                               ship_from_org_id,
                           -1
                               location_id,
                           NULL
                               request_sent_date,
                           NULL
                               reply_rcv_date,
                           NULL
                               scheduled_pu_date,
                           NULL
                               bill_of_lading,
                           head.carrier,
                           (SELECT scac_code
                              FROM wsh_carriers_v
                             WHERE freight_code = head.carrier)
                               carrier_scac,
                           head.comments,
                           NULL
                               confirm_sent_date,
                           NULL
                               contact_name,
                           NULL
                               cust_shipment_id,
                           NULL
                               earliest_pu_date,
                           NULL
                               latest_pu_date,
                           SUBSTR (head.customer_load_id, 1, 30) -- Updated from 10 to 30 for CCR0008881
                               load_id,
                           NULL
                               routing_status,
                           head.ship_date
                               ship_confirm_date,
                           NULL
                               shipment_weight,
                           'LB'
                               shipment_weight_uom,
                           lv_sps_customer                               --1.3
                      FROM xxdo_ont_ship_conf_head_stg head
                     WHERE     head.shipment_number =
                               parcel_nondropship_rec.shipment_number
                           AND head.process_status = 'PROCESSED';
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_retcode   := '1';
                    pv_errbuf    :=
                           'Error occurred while inserting into table do_edi856_shipments: '
                        || SQLERRM;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error occurred while inserting into table do_edi856_shipments: '
                        || SQLERRM);
            END;

            FOR parcel_nondropship_del_rec
                IN parcel_nondropship_delivery (
                       parcel_nondropship_rec.sold_to_org_id,
                       parcel_nondropship_rec.brand,
                       parcel_nondropship_rec.ship_to_org_id,
                       parcel_nondropship_rec.account_number,
                       parcel_nondropship_rec.shipment_number)
            LOOP
                ln_derived_del_id   :=
                    NVL (parcel_nondropship_del_rec.delivery_id,
                         parcel_nondropship_del_rec.order_number);
                lv_record_exists   := 'N';

                --- To check whether the delivery is already interfaced
                BEGIN
                    SELECT 'Y'
                      INTO lv_record_exists
                      FROM do_edi.do_edi856_pick_tickets
                     WHERE delivery_id = ln_derived_del_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_record_exists   := 'N';
                END;

                IF lv_record_exists = 'N'
                THEN
                    BEGIN
                        INSERT INTO do_edi.do_edi856_pick_tickets (
                                        shipment_id,
                                        delivery_id,
                                        weight,
                                        weight_uom,
                                        number_cartons,
                                        cartons_uom,
                                        volume,
                                        volume_uom,
                                        ordered_qty,
                                        shipped_qty,
                                        shipped_qty_uom,
                                        source_header_id,
                                        intmed_ship_to_org_id,
                                        creation_date,
                                        created_by,
                                        last_update_date,
                                        last_updated_by,
                                        archive_flag,
                                        shipment_key)
                              SELECT ln_shipment_id,
                                     ln_derived_del_id,
                                     (SELECT SUM (NVL (cartoni.weight, 0))
                                        FROM xxdo_ont_ship_conf_order_stg ordi, xxdo_ont_ship_conf_carton_stg cartoni
                                       WHERE     1 = 1
                                             AND ordi.order_number =
                                                 ord.order_number
                                             AND ordi.order_header_id =
                                                 ord.order_header_id
                                             AND ordi.shipment_number =
                                                 ord.shipment_number
                                             AND ordi.process_status =
                                                 'PROCESSED'
                                             AND ordi.shipment_number =
                                                 cartoni.shipment_number
                                             AND ordi.order_number =
                                                 cartoni.order_number
                                             AND cartoni.process_status =
                                                 'PROCESSED')
                                         weight,
                                     'LB'
                                         weight_uom,
                                     COUNT (DISTINCT carton.carton_number)
                                         number_cartons,
                                     'EA'
                                         cartons_uom,
                                     (SELECT SUM (NVL (cartoni.LENGTH, 1) * NVL (cartoni.width, 1) * NVL (cartoni.height, 1))
                                        FROM xxdo_ont_ship_conf_order_stg ordi, xxdo_ont_ship_conf_carton_stg cartoni
                                       WHERE     1 = 1
                                             AND ordi.order_number =
                                                 ord.order_number
                                             AND ordi.order_header_id =
                                                 ord.order_header_id
                                             AND ordi.shipment_number =
                                                 ord.shipment_number
                                             AND ordi.process_status =
                                                 'PROCESSED'
                                             AND ordi.shipment_number =
                                                 cartoni.shipment_number
                                             AND ordi.order_number =
                                                 cartoni.order_number
                                             AND cartoni.process_status =
                                                 'PROCESSED')
                                         volume,
                                     'CI'
                                         volume_uom,
                                     SUM (qty)
                                         ordered_qty,
                                     SUM (qty)
                                         shipped_qty,
                                     'EA'
                                         shipped_qty_uom,
                                     ord.order_header_id
                                         source_header_id,
                                     NULL
                                         intmed_ship_to_org_id,
                                     SYSDATE
                                         creation_date,
                                     gn_user_id
                                         created_by,
                                     SYSDATE
                                         last_update_date,
                                     gn_user_id
                                         last_updated_by,
                                     'N'
                                         archive_flag,
                                     (SELECT ln_shipment_id || brand_code
                                        FROM do_custom.do_brands db, mtl_parameters mp, mtl_system_items_kfv msi,
                                             mtl_item_categories mic, mtl_categories_b mc, mtl_category_sets mcs,
                                             xxdo_ont_ship_conf_order_stg ordi, xxdo_ont_ship_conf_carton_stg cartoni, xxdo_ont_ship_conf_cardtl_stg cardtli
                                       WHERE     msi.concatenated_segments =
                                                 cardtli.item_number
                                             AND msi.organization_id =
                                                 mic.organization_id
                                             AND msi.inventory_item_id =
                                                 mic.inventory_item_id
                                             AND mcs.category_set_id =
                                                 mic.category_set_id
                                             AND mcs.category_set_id = 1
                                             AND mc.category_id =
                                                 mic.category_id
                                             AND UPPER (mc.segment1) =
                                                 db.brand_name
                                             AND mp.organization_code =
                                                 ord.wh_id
                                             AND mp.organization_id =
                                                 msi.organization_id
                                             AND ordi.process_status =
                                                 'PROCESSED'
                                             AND ordi.shipment_number =
                                                 ord.shipment_number
                                             AND cartoni.process_status =
                                                 'PROCESSED'
                                             AND ordi.shipment_number =
                                                 cartoni.shipment_number
                                             AND ordi.order_number =
                                                 cartoni.order_number
                                             AND cardtli.process_status =
                                                 'PROCESSED'
                                             AND cardtli.shipment_number =
                                                 ordi.shipment_number
                                             AND cardtli.order_number =
                                                 ordi.order_number
                                             AND cardtli.carton_number =
                                                 cartoni.carton_number
                                             AND ordi.order_number =
                                                 ord.order_number
                                             AND ordi.order_header_id =
                                                 ord.order_header_id
                                             AND ROWNUM < 2)
                                         shipment_key
                                FROM xxdo_ont_ship_conf_order_stg ord, xxdo_ont_ship_conf_carton_stg carton, xxdo_ont_ship_conf_cardtl_stg cardtl
                               WHERE     ord.shipment_number =
                                         parcel_nondropship_del_rec.shipment_number
                                     AND ord.process_status = 'PROCESSED'
                                     AND ord.shipment_number =
                                         carton.shipment_number
                                     AND ord.order_number = carton.order_number
                                     AND carton.process_status = 'PROCESSED'
                                     AND cardtl.shipment_number =
                                         ord.shipment_number
                                     AND cardtl.order_number = ord.order_number
                                     AND cardtl.carton_number =
                                         carton.carton_number
                                     AND cardtl.process_status = 'PROCESSED'
                                     AND ord.order_number =
                                         parcel_nondropship_del_rec.order_number
                            GROUP BY ord.order_number, ord.order_header_id, ord.wh_id,
                                     ord.shipment_number;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            pv_retcode   := '1';
                            pv_errbuf    :=
                                   'Error occurred while inserting into table do_edi856_pick_tickets: '
                                || SQLERRM;
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error occurred while inserting into table do_edi856_pick_tickets: '
                                || SQLERRM);
                    END;

                    BEGIN
                        UPDATE xxdo_ont_ship_conf_order_stg
                           SET attribute1 = ln_shipment_id, edi_creation_status = 'PROCESSED'
                         WHERE     order_number =
                                   parcel_nondropship_del_rec.order_number
                               AND shipment_number =
                                   parcel_nondropship_del_rec.shipment_number;

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            pv_retcode   := '1';
                            pv_errbuf    :=
                                   'Error occurred while updating attribute1 in table xxdo_ont_ship_conf_order_stg: '
                                || SQLERRM;
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error occurred while updating attribute1 in table xxdo_ont_ship_conf_order_stg: '
                                || SQLERRM);
                    END;
                END IF;
            END LOOP;
        END LOOP;

        FOR nonparcel_shipments_rec IN nonparcel_shipments
        LOOP
            ln_char_incrment   := NULL;
            ln_loop_count      := 0;

            FOR nonparcel_shipments_dc_rec
                IN nonparcel_shipments_dc (
                       nonparcel_shipments_rec.sold_to_org_id,
                       nonparcel_shipments_rec.brand,
                       nonparcel_shipments_rec.account_number,
                       nonparcel_shipments_rec.bol_number)
            LOOP
                ln_shipment_id    := NULL;
                ln_loop_count     := ln_loop_count + 1;

                IF ln_loop_count = 2
                THEN
                    ln_char_incrment   := 'A';
                ELSIF ln_loop_count > 2
                THEN
                    SELECT CHR (ASCII (ln_char_incrment) + 1)
                      INTO ln_char_incrment
                      FROM DUAL;
                END IF;

                --1.3 changes start
                lv_sps_customer   := NULL;
                lv_sps_customer   :=
                    get_customer_type (
                        nonparcel_shipments_rec.account_number);

                --1.3 changes end

                BEGIN
                    do_edi.get_next_values ('DO_EDI856_SHIPMENTS',
                                            1,
                                            ln_shipment_id);

                    INSERT INTO do_edi.do_edi856_shipments (shipment_id, asn_status, asn_date, invoice_date, customer_id, ship_to_org_id, waybill, seal_code, trailer_number, tracking_number, pro_number, est_delivery_date, creation_date, created_by, last_update_date, last_updated_by, archive_flag, organization_id, location_id, request_sent_date, reply_rcv_date, scheduled_pu_date, bill_of_lading, carrier, carrier_scac, comments, confirm_sent_date, contact_name, cust_shipment_id, earliest_pu_date, latest_pu_date, load_id, routing_status, ship_confirm_date, shipment_weight, shipment_weight_uom
                                                            , sps_event  --1.3
                                                                       )
                        SELECT ln_shipment_id,
                               'R',
                               NULL,
                               NULL,
                               nonparcel_shipments_rec.sold_to_org_id,
                               -1, /* ship to org id is inserted -1 first and updated later */
                               head.bol_number || ln_char_incrment,
                               head.seal_number,
                               head.trailer_number,
                               NULL
                                   tracking_number,
                               head.pro_number,
                               head.ship_date + 3
                                   est_delivery_date,
                               SYSDATE
                                   creation_date,
                               gn_user_id
                                   created_by,
                               SYSDATE
                                   last_update_date,
                               gn_user_id
                                   last_updated_by,
                               'N'
                                   archive_flag,
                               (SELECT organization_id
                                  FROM mtl_parameters mp
                                 WHERE mp.organization_code = head.wh_id)
                                   ship_from_org_id,
                               -1
                                   location_id,
                               NULL
                                   request_sent_date,
                               NULL
                                   reply_rcv_date,
                               NULL
                                   scheduled_pu_date,
                               NULL
                                   bill_of_lading,
                               head.carrier,
                               (SELECT scac_code
                                  FROM wsh_carriers_v
                                 WHERE freight_code = head.carrier)
                                   carrier_scac,
                               head.comments,
                               NULL
                                   confirm_sent_date,
                               NULL
                                   contact_name,
                               NULL
                                   cust_shipment_id,
                               NULL
                                   earliest_pu_date,
                               NULL
                                   latest_pu_date,
                               SUBSTR (head.customer_load_id, 1, 30) -- Updated from 10 to 30 for CCR0008881
                                   load_id,
                               NULL
                                   routing_status,
                               head.ship_date
                                   ship_confirm_date,
                               NULL
                                   shipment_weight,
                               'LB'
                                   shipment_weight_uom,
                               lv_sps_customer                           --1.3
                          FROM xxdo_ont_ship_conf_head_stg head
                         WHERE     head.bol_number =
                                   nonparcel_shipments_rec.bol_number
                               AND head.process_status = 'PROCESSED'
                               AND ROWNUM = 1;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pv_retcode   := '1';
                        pv_errbuf    :=
                               'Error occurred while inserting into table do_edi856_shipments: '
                            || SQLERRM;
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error occurred while inserting into table do_edi856_shipments: '
                            || SQLERRM);
                END;

                FOR nonparcel_dc_delivery_rec
                    IN nonparcel_dc_delivery (
                           nonparcel_shipments_rec.sold_to_org_id,
                           nonparcel_shipments_rec.brand,
                           nonparcel_shipments_rec.account_number,
                           nonparcel_shipments_rec.bol_number,
                           nonparcel_shipments_dc_rec.ship_to_dc)
                LOOP
                    /* update ship to org ID on ASN header only once. Any ship-to in this shipment is fine*/

                    BEGIN
                        UPDATE do_edi.do_edi856_shipments
                           SET ship_to_org_id = nonparcel_dc_delivery_rec.ship_to_org_id
                         WHERE     shipment_id = ln_shipment_id
                               AND ship_to_org_id = -1;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            pv_retcode   := '1';
                            pv_errbuf    :=
                                   'Error occurred while updating ship_to_org_id in table do_edi856_shipments: '
                                || SQLERRM;
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error occurred while updating ship_to_org_id in table do_edi856_shipments: '
                                || SQLERRM);
                    END;

                    ln_derived_del_id   :=
                        NVL (nonparcel_dc_delivery_rec.delivery_id,
                             nonparcel_dc_delivery_rec.order_number);
                    lv_record_exists   := 'N';

                    --- To check whether the delivery is already interfaced
                    BEGIN
                        SELECT 'Y'
                          INTO lv_record_exists
                          FROM do_edi.do_edi856_pick_tickets
                         WHERE delivery_id = ln_derived_del_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_record_exists   := 'N';
                    END;

                    IF lv_record_exists = 'N'
                    THEN
                        BEGIN
                            INSERT INTO do_edi.do_edi856_pick_tickets (
                                            shipment_id,
                                            delivery_id,
                                            weight,
                                            weight_uom,
                                            number_cartons,
                                            cartons_uom,
                                            volume,
                                            volume_uom,
                                            ordered_qty,
                                            shipped_qty,
                                            shipped_qty_uom,
                                            source_header_id,
                                            intmed_ship_to_org_id,
                                            creation_date,
                                            created_by,
                                            last_update_date,
                                            last_updated_by,
                                            archive_flag,
                                            shipment_key)
                                  SELECT ln_shipment_id,
                                         ln_derived_del_id,
                                         (SELECT SUM (NVL (cartoni.weight, 0))
                                            FROM xxdo_ont_ship_conf_order_stg ordi, xxdo_ont_ship_conf_carton_stg cartoni
                                           WHERE     1 = 1
                                                 AND ordi.order_number =
                                                     ord.order_number
                                                 AND ordi.order_header_id =
                                                     ord.order_header_id
                                                 AND ordi.shipment_number =
                                                     ord.shipment_number
                                                 AND ordi.process_status =
                                                     'PROCESSED'
                                                 AND ordi.shipment_number =
                                                     cartoni.shipment_number
                                                 AND ordi.order_number =
                                                     cartoni.order_number
                                                 AND cartoni.process_status =
                                                     'PROCESSED')
                                             weight,
                                         'LB'
                                             weight_uom,
                                         COUNT (DISTINCT carton.carton_number)
                                             number_cartons,
                                         'EA'
                                             cartons_uom,
                                         (SELECT SUM (NVL (cartoni.LENGTH, 1) * NVL (cartoni.width, 1) * NVL (cartoni.height, 1))
                                            FROM xxdo_ont_ship_conf_order_stg ordi, xxdo_ont_ship_conf_carton_stg cartoni
                                           WHERE     1 = 1
                                                 AND ordi.order_number =
                                                     ord.order_number
                                                 AND ordi.order_header_id =
                                                     ord.order_header_id
                                                 AND ordi.shipment_number =
                                                     ord.shipment_number
                                                 AND ordi.process_status =
                                                     'PROCESSED'
                                                 AND ordi.shipment_number =
                                                     cartoni.shipment_number
                                                 AND ordi.order_number =
                                                     cartoni.order_number
                                                 AND cartoni.process_status =
                                                     'PROCESSED')
                                             volume,
                                         'CI'
                                             volume_uom,
                                         SUM (qty)
                                             ordered_qty,
                                         SUM (qty)
                                             shipped_qty,
                                         'EA'
                                             shipped_qty_uom,
                                         ord.order_header_id
                                             source_header_id,
                                         NULL
                                             intmed_ship_to_org_id,
                                         SYSDATE
                                             creation_date,
                                         gn_user_id
                                             created_by,
                                         SYSDATE
                                             last_update_date,
                                         gn_user_id
                                             last_updated_by,
                                         'N'
                                             archive_flag,
                                         (SELECT ln_shipment_id || brand_code
                                            FROM do_custom.do_brands db, mtl_parameters mp, mtl_system_items_kfv msi,
                                                 mtl_item_categories mic, mtl_categories_b mc, mtl_category_sets mcs,
                                                 xxdo_ont_ship_conf_order_stg ordi, xxdo_ont_ship_conf_carton_stg cartoni, xxdo_ont_ship_conf_cardtl_stg cardtli
                                           WHERE     msi.concatenated_segments =
                                                     cardtli.item_number
                                                 AND msi.organization_id =
                                                     mic.organization_id
                                                 AND msi.inventory_item_id =
                                                     mic.inventory_item_id
                                                 AND mcs.category_set_id =
                                                     mic.category_set_id
                                                 AND mcs.category_set_id = 1
                                                 AND mc.category_id =
                                                     mic.category_id
                                                 AND UPPER (mc.segment1) =
                                                     db.brand_name
                                                 AND mp.organization_code =
                                                     ord.wh_id
                                                 AND mp.organization_id =
                                                     msi.organization_id
                                                 AND ordi.process_status =
                                                     'PROCESSED'
                                                 AND ordi.shipment_number =
                                                     ord.shipment_number
                                                 AND cartoni.process_status =
                                                     'PROCESSED'
                                                 AND ordi.shipment_number =
                                                     cartoni.shipment_number
                                                 AND ordi.order_number =
                                                     cartoni.order_number
                                                 AND cardtli.process_status =
                                                     'PROCESSED'
                                                 AND cardtli.shipment_number =
                                                     ordi.shipment_number
                                                 AND cardtli.order_number =
                                                     ordi.order_number
                                                 AND cardtli.carton_number =
                                                     cartoni.carton_number
                                                 AND ordi.order_number =
                                                     ord.order_number
                                                 AND ordi.order_header_id =
                                                     ord.order_header_id
                                                 AND ROWNUM < 2)
                                             shipment_key
                                    FROM xxdo_ont_ship_conf_order_stg ord, xxdo_ont_ship_conf_carton_stg carton, xxdo_ont_ship_conf_cardtl_stg cardtl
                                   WHERE     ord.shipment_number =
                                             nonparcel_dc_delivery_rec.shipment_number
                                         AND ord.process_status = 'PROCESSED'
                                         AND ord.shipment_number =
                                             carton.shipment_number
                                         AND ord.order_number =
                                             carton.order_number
                                         AND carton.process_status =
                                             'PROCESSED'
                                         AND cardtl.shipment_number =
                                             ord.shipment_number
                                         AND cardtl.order_number =
                                             ord.order_number
                                         AND cardtl.carton_number =
                                             carton.carton_number
                                         AND cardtl.process_status =
                                             'PROCESSED'
                                         AND ord.order_number =
                                             nonparcel_dc_delivery_rec.order_number
                                GROUP BY ord.order_number, ord.order_header_id, ord.wh_id,
                                         ord.shipment_number;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                pv_retcode   := '1';
                                pv_errbuf    :=
                                       'Error occurred while inserting into table do_edi856_pick_tickets: '
                                    || SQLERRM;
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Error occurred while inserting into table do_edi856_pick_tickets: '
                                    || SQLERRM);
                        END;

                        BEGIN
                            UPDATE xxdo_ont_ship_conf_order_stg
                               SET attribute1 = ln_shipment_id, edi_creation_status = 'PROCESSED'
                             WHERE     order_number =
                                       nonparcel_dc_delivery_rec.order_number
                                   AND shipment_number =
                                       nonparcel_dc_delivery_rec.shipment_number;

                            COMMIT;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                pv_retcode   := '1';
                                pv_errbuf    :=
                                       'Error occurred while updating attribute1 in table xxdo_ont_ship_conf_order_stg: '
                                    || SQLERRM;
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Error occurred while updating attribute1 in table xxdo_ont_ship_conf_order_stg: '
                                    || SQLERRM);
                        END;
                    END IF;
                END LOOP;
            END LOOP;

            FOR nonparcel_shipments_loc_rec
                IN nonparcel_shipments_loc_id (
                       nonparcel_shipments_rec.sold_to_org_id,
                       nonparcel_shipments_rec.brand,
                       nonparcel_shipments_rec.account_number,
                       nonparcel_shipments_rec.bol_number)
            LOOP
                ln_shipment_id    := NULL;
                ln_loop_count     := ln_loop_count + 1;

                IF ln_loop_count = 2
                THEN
                    ln_char_incrment   := 'A';
                ELSIF ln_loop_count > 2
                THEN
                    SELECT CHR (ASCII (ln_char_incrment) + 1)
                      INTO ln_char_incrment
                      FROM DUAL;
                END IF;

                --1.3 changes start
                lv_sps_customer   := NULL;
                lv_sps_customer   :=
                    get_customer_type (
                        nonparcel_shipments_rec.account_number);

                --1.3 changes end

                BEGIN
                    do_edi.get_next_values ('DO_EDI856_SHIPMENTS',
                                            1,
                                            ln_shipment_id);

                    INSERT INTO do_edi.do_edi856_shipments (shipment_id, asn_status, asn_date, invoice_date, customer_id, ship_to_org_id, waybill, seal_code, trailer_number, tracking_number, pro_number, est_delivery_date, creation_date, created_by, last_update_date, last_updated_by, archive_flag, organization_id, location_id, request_sent_date, reply_rcv_date, scheduled_pu_date, bill_of_lading, carrier, carrier_scac, comments, confirm_sent_date, contact_name, cust_shipment_id, earliest_pu_date, latest_pu_date, load_id, routing_status, ship_confirm_date, shipment_weight, shipment_weight_uom
                                                            , sps_event  --1.3
                                                                       )
                        SELECT ln_shipment_id,
                               'R',
                               NULL,
                               NULL,
                               nonparcel_shipments_rec.sold_to_org_id,
                               -1,
                               head.bol_number || ln_char_incrment,
                               head.seal_number,
                               head.trailer_number,
                               NULL
                                   tracking_number,
                               head.pro_number,
                               head.ship_date + 3
                                   est_delivery_date,
                               SYSDATE
                                   creation_date,
                               gn_user_id
                                   created_by,
                               SYSDATE
                                   last_update_date,
                               gn_user_id
                                   last_updated_by,
                               'N'
                                   archive_flag,
                               (SELECT organization_id
                                  FROM mtl_parameters mp
                                 WHERE mp.organization_code = head.wh_id)
                                   ship_from_org_id,
                               -1
                                   location_id,
                               NULL
                                   request_sent_date,
                               NULL
                                   reply_rcv_date,
                               NULL
                                   scheduled_pu_date,
                               NULL
                                   bill_of_lading,
                               head.carrier,
                               (SELECT scac_code
                                  FROM wsh_carriers_v
                                 WHERE freight_code = head.carrier)
                                   carrier_scac,
                               head.comments,
                               NULL
                                   confirm_sent_date,
                               NULL
                                   contact_name,
                               NULL
                                   cust_shipment_id,
                               NULL
                                   earliest_pu_date,
                               NULL
                                   latest_pu_date,
                               SUBSTR (head.customer_load_id, 1, 30) -- Updated from 10 to 30 for CCR0008881
                                   load_id,
                               NULL
                                   routing_status,
                               head.ship_date
                                   ship_confirm_date,
                               NULL
                                   shipment_weight,
                               'LB'
                                   shipment_weight_uom,
                               lv_sps_customer                           --1.3
                          FROM xxdo_ont_ship_conf_head_stg head
                         WHERE     head.bol_number =
                                   nonparcel_shipments_rec.bol_number
                               AND ROWNUM = 1
                               AND head.process_status = 'PROCESSED';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pv_retcode   := '1';
                        pv_errbuf    :=
                               'Error occurred while inserting into table do_edi856_shipments: '
                            || SQLERRM;
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error occurred while inserting into table do_edi856_shipments: '
                            || SQLERRM);
                END;

                FOR nonparcel_del_rec
                    IN nonparcel_delivery (
                           nonparcel_shipments_rec.sold_to_org_id,
                           nonparcel_shipments_rec.brand,
                           nonparcel_shipments_rec.account_number,
                           nonparcel_shipments_rec.bol_number,
                           nonparcel_shipments_loc_rec.ship_to_location_id)
                LOOP
                    /* update ship to org ID on ASN header only once. Any ship-to in this shipment is fine*/

                    BEGIN
                        UPDATE do_edi.do_edi856_shipments
                           SET ship_to_org_id = nonparcel_del_rec.ship_to_org_id
                         WHERE     shipment_id = ln_shipment_id
                               AND ship_to_org_id = -1;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            pv_retcode   := '1';
                            pv_errbuf    :=
                                   'Error occurred while updating ship_to_org_id in table do_edi856_shipments: '
                                || SQLERRM;
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error occurred while updating ship_to_org_id in table do_edi856_shipments: '
                                || SQLERRM);
                    END;

                    ln_derived_del_id   :=
                        NVL (nonparcel_del_rec.delivery_id,
                             nonparcel_del_rec.order_number);
                    lv_record_exists   := 'N';

                    --- To check whether the delivery is already interfaced
                    BEGIN
                        SELECT 'Y'
                          INTO lv_record_exists
                          FROM do_edi.do_edi856_pick_tickets
                         WHERE delivery_id = ln_derived_del_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_record_exists   := 'N';
                    END;

                    IF lv_record_exists = 'N'
                    THEN
                        BEGIN
                            INSERT INTO do_edi.do_edi856_pick_tickets (
                                            shipment_id,
                                            delivery_id,
                                            weight,
                                            weight_uom,
                                            number_cartons,
                                            cartons_uom,
                                            volume,
                                            volume_uom,
                                            ordered_qty,
                                            shipped_qty,
                                            shipped_qty_uom,
                                            source_header_id,
                                            intmed_ship_to_org_id,
                                            creation_date,
                                            created_by,
                                            last_update_date,
                                            last_updated_by,
                                            archive_flag,
                                            shipment_key)
                                  SELECT ln_shipment_id,
                                         ln_derived_del_id,
                                         (SELECT SUM (NVL (cartoni.weight, 0))
                                            FROM xxdo_ont_ship_conf_order_stg ordi, xxdo_ont_ship_conf_carton_stg cartoni
                                           WHERE     1 = 1
                                                 AND ordi.order_number =
                                                     ord.order_number
                                                 AND ordi.order_header_id =
                                                     ord.order_header_id
                                                 AND ordi.shipment_number =
                                                     ord.shipment_number
                                                 AND ordi.process_status =
                                                     'PROCESSED'
                                                 AND ordi.shipment_number =
                                                     cartoni.shipment_number
                                                 AND ordi.order_number =
                                                     cartoni.order_number
                                                 AND cartoni.process_status =
                                                     'PROCESSED')
                                             weight,
                                         'LB'
                                             weight_uom,
                                         COUNT (DISTINCT carton.carton_number)
                                             number_cartons,
                                         'EA'
                                             cartons_uom,
                                         (SELECT SUM (NVL (cartoni.LENGTH, 1) * NVL (cartoni.width, 1) * NVL (cartoni.height, 1))
                                            FROM xxdo_ont_ship_conf_order_stg ordi, xxdo_ont_ship_conf_carton_stg cartoni
                                           WHERE     1 = 1
                                                 AND ordi.order_number =
                                                     ord.order_number
                                                 AND ordi.order_header_id =
                                                     ord.order_header_id
                                                 AND ordi.shipment_number =
                                                     ord.shipment_number
                                                 AND ordi.process_status =
                                                     'PROCESSED'
                                                 AND ordi.shipment_number =
                                                     cartoni.shipment_number
                                                 AND ordi.order_number =
                                                     cartoni.order_number
                                                 AND cartoni.process_status =
                                                     'PROCESSED')
                                             volume,
                                         'CI'
                                             volume_uom,
                                         SUM (qty)
                                             ordered_qty,
                                         SUM (qty)
                                             shipped_qty,
                                         'EA'
                                             shipped_qty_uom,
                                         ord.order_header_id
                                             source_header_id,
                                         NULL
                                             intmed_ship_to_org_id,
                                         SYSDATE
                                             creation_date,
                                         gn_user_id
                                             created_by,
                                         SYSDATE
                                             last_update_date,
                                         gn_user_id
                                             last_updated_by,
                                         'N'
                                             archive_flag,
                                         (SELECT ln_shipment_id || brand_code
                                            FROM do_custom.do_brands db, mtl_parameters mp, mtl_system_items_kfv msi,
                                                 mtl_item_categories mic, mtl_categories_b mc, mtl_category_sets mcs,
                                                 xxdo_ont_ship_conf_order_stg ordi, xxdo_ont_ship_conf_carton_stg cartoni, xxdo_ont_ship_conf_cardtl_stg cardtli
                                           WHERE     msi.concatenated_segments =
                                                     cardtli.item_number
                                                 AND msi.organization_id =
                                                     mic.organization_id
                                                 AND msi.inventory_item_id =
                                                     mic.inventory_item_id
                                                 AND mcs.category_set_id =
                                                     mic.category_set_id
                                                 AND mcs.category_set_id = 1
                                                 AND mc.category_id =
                                                     mic.category_id
                                                 AND UPPER (mc.segment1) =
                                                     db.brand_name
                                                 AND mp.organization_code =
                                                     ord.wh_id
                                                 AND mp.organization_id =
                                                     msi.organization_id
                                                 AND ordi.process_status =
                                                     'PROCESSED'
                                                 AND ordi.shipment_number =
                                                     ord.shipment_number
                                                 AND cartoni.process_status =
                                                     'PROCESSED'
                                                 AND ordi.shipment_number =
                                                     cartoni.shipment_number
                                                 AND ordi.order_number =
                                                     cartoni.order_number
                                                 AND cardtli.process_status =
                                                     'PROCESSED'
                                                 AND cardtli.shipment_number =
                                                     ordi.shipment_number
                                                 AND cardtli.order_number =
                                                     ordi.order_number
                                                 AND cardtli.carton_number =
                                                     cartoni.carton_number
                                                 AND ordi.order_number =
                                                     ord.order_number
                                                 AND ordi.order_header_id =
                                                     ord.order_header_id
                                                 AND ROWNUM < 2)
                                             shipment_key
                                    FROM xxdo_ont_ship_conf_order_stg ord, xxdo_ont_ship_conf_carton_stg carton, xxdo_ont_ship_conf_cardtl_stg cardtl
                                   WHERE     ord.shipment_number =
                                             nonparcel_del_rec.shipment_number
                                         AND ord.process_status = 'PROCESSED'
                                         AND ord.shipment_number =
                                             carton.shipment_number
                                         AND ord.order_number =
                                             carton.order_number
                                         AND carton.process_status =
                                             'PROCESSED'
                                         AND cardtl.shipment_number =
                                             ord.shipment_number
                                         AND cardtl.order_number =
                                             ord.order_number
                                         AND cardtl.carton_number =
                                             carton.carton_number
                                         AND cardtl.process_status =
                                             'PROCESSED'
                                         AND ord.order_number =
                                             nonparcel_del_rec.order_number
                                GROUP BY ord.order_number, ord.order_header_id, ord.wh_id,
                                         ord.shipment_number;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                pv_retcode   := '1';
                                pv_errbuf    :=
                                       'Error occurred while inserting into table do_edi856_pick_tickets: '
                                    || SQLERRM;
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Error occurred while inserting into table do_edi856_pick_tickets: '
                                    || SQLERRM);
                        END;

                        BEGIN
                            UPDATE xxdo_ont_ship_conf_order_stg
                               SET attribute1 = ln_shipment_id, edi_creation_status = 'PROCESSED'
                             WHERE     order_number =
                                       nonparcel_del_rec.order_number
                                   AND shipment_number =
                                       nonparcel_del_rec.shipment_number;

                            COMMIT;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                pv_retcode   := '1';
                                pv_errbuf    :=
                                       'Error occurred while updating attribute1 in table xxdo_ont_ship_conf_order_stg: '
                                    || SQLERRM;
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Error occurred while updating attribute1 in table xxdo_ont_ship_conf_order_stg: '
                                    || SQLERRM);
                        END;
                    END IF;
                END LOOP;
            END LOOP;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_retcode   := '1';
            pv_errbuf    :=
                   'Error occurred in XXD_ONT_EDI_INTERFACE_PKG.edi_outbound: '
                || SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error occurred in XXD_ONT_EDI_INTERFACE_PKG.edi_outbound: '
                || SQLERRM);
    END edi_outbound;

    PROCEDURE PURGE (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pn_archival_days IN NUMBER
                     , pn_purge_days IN NUMBER)
    IS
        ld_sysdate   DATE := SYSDATE;

        CURSOR archival_data IS
            SELECT shipment_id
              FROM do_edi.do_edi856_shipments
             WHERE     creation_date < ld_sysdate - pn_archival_days
                   AND organization_id IN
                           (SELECT meaning
                              FROM fnd_lookup_values
                             WHERE     lookup_type = 'XXD_EDI_PURGE_ORG'
                                   AND LANGUAGE = 'US');
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           'Purging Started: ' || pn_archival_days);
        fnd_file.put_line (fnd_file.LOG,
                           'Log tables Purge Days: ' || pn_purge_days);

        --Archiving table do_edi856_shipments
        FOR archival_data_rec IN archival_data
        LOOP
            BEGIN
                INSERT INTO xxdo.do_edi856_shipments_log (
                                shipment_id,
                                asn_status,
                                asn_date,
                                invoice_date,
                                customer_id,
                                ship_to_org_id,
                                waybill,
                                tracking_number,
                                pro_number,
                                est_delivery_date,
                                creation_date,
                                created_by,
                                last_update_date,
                                last_updated_by,
                                archive_flag,
                                organization_id,
                                location_id,
                                request_sent_date,
                                reply_rcv_date,
                                scheduled_pu_date,
                                bill_of_lading,
                                carrier,
                                carrier_scac,
                                comments,
                                confirm_sent_date,
                                contact_name,
                                cust_shipment_id,
                                earliest_pu_date,
                                latest_pu_date,
                                load_id,
                                routing_status,
                                ship_confirm_date,
                                shipment_weight,
                                shipment_weight_uom,
                                seal_code,
                                trailer_number,
                                dock_door_event,
                                voyage_num,
                                vessel_name,
                                vessel_dept_date,
                                sps_event                                --1.3
                                         )
                    SELECT shipment_id, asn_status, asn_date,
                           invoice_date, customer_id, ship_to_org_id,
                           waybill, tracking_number, pro_number,
                           est_delivery_date, creation_date, created_by,
                           last_update_date, last_updated_by, archive_flag,
                           organization_id, location_id, request_sent_date,
                           reply_rcv_date, scheduled_pu_date, bill_of_lading,
                           carrier, carrier_scac, comments,
                           confirm_sent_date, contact_name, cust_shipment_id,
                           earliest_pu_date, latest_pu_date, load_id,
                           routing_status, ship_confirm_date, shipment_weight,
                           shipment_weight_uom, seal_code, trailer_number,
                           dock_door_event, voyage_num, vessel_name,
                           vessel_dept_date, sps_event                   --1.3
                      FROM do_edi.do_edi856_shipments
                     WHERE shipment_id = archival_data_rec.shipment_id;

                --Purging table do_edi856_shipments
                DELETE FROM do_edi.do_edi856_shipments
                      WHERE shipment_id = archival_data_rec.shipment_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_retcode   := '1';
                    pv_errbuf    :=
                           'Error happened while archiving do_edi856_shipments data: '
                        || SQLERRM;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error happened while archiving do_edi856_shipments data: '
                        || SQLERRM);
            END;

            BEGIN
                INSERT INTO xxdo.do_edi856_pick_tickets_log (shipment_id, delivery_id, weight, weight_uom, number_cartons, cartons_uom, volume, volume_uom, ordered_qty, shipped_qty, shipped_qty_uom, source_header_id, intmed_ship_to_org_id, creation_date, created_by, last_update_date, last_updated_by, archive_flag
                                                             , shipment_key)
                    SELECT shipment_id, delivery_id, weight,
                           weight_uom, number_cartons, cartons_uom,
                           volume, volume_uom, ordered_qty,
                           shipped_qty, shipped_qty_uom, source_header_id,
                           intmed_ship_to_org_id, creation_date, created_by,
                           last_update_date, last_updated_by, archive_flag,
                           shipment_key
                      FROM do_edi.do_edi856_pick_tickets
                     WHERE shipment_id = archival_data_rec.shipment_id;

                --Purging table do_edi856_pick_tickets
                DELETE FROM do_edi.do_edi856_pick_tickets
                      WHERE shipment_id = archival_data_rec.shipment_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_retcode   := '1';
                    pv_errbuf    :=
                           'Error happened while archiving do_edi856_pick_tickets data: '
                        || SQLERRM;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error happened while archiving do_edi856_pick_tickets data: '
                        || SQLERRM);
            END;
        END LOOP;

        --Purging log tables
        BEGIN
            DELETE FROM xxdo.do_edi856_shipments_log
                  WHERE creation_date < ld_sysdate - pn_purge_days;

            DELETE FROM xxdo.do_edi856_pick_tickets_log
                  WHERE creation_date < ld_sysdate - pn_purge_days;
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_retcode   := '1';
                pv_errbuf    :=
                       'Error happened while archiving do_edi856_pick_tickets data: '
                    || SQLERRM;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error happened while archiving do_edi856_pick_tickets data: '
                    || SQLERRM);
        END;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_retcode   := '1';
            pv_errbuf    :=
                   'Error occurred in XXD_ONT_EDI_INTERFACE_PKG.PURGE: '
                || SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error occurred in XXD_ONT_EDI_INTERFACE_PKG.PURGE: '
                || SQLERRM);
    END PURGE;
END xxd_ont_edi_interface_pkg;
/


GRANT EXECUTE ON APPS.XXD_ONT_EDI_INTERFACE_PKG TO SOA_INT
/
