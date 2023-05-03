--
-- XXDO_INT_007_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:48 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_INT_007_PKG"
IS
    /**********************************************************************************************************
    File Name : APPS.xxdo_int_007_pkg
       Created On   : 01-MARCH-2012  --RMS ASN Out Integration Deckers
       Created By   : Abdul and Sivakumar Boothathan
       Purpose      : Package used to find the shipments made for a order with an order source as "Retail"
                      The columns which were picked up are to_location_id, from_location_id and other columns
                      We make use of a custom lookup : XXDO_RETAIL_STORE_CUST_MAPPING which will be used to
                      map the store number in RMS with the customer number in EBS
                      If the net quantity is greater than zero which means we need to call on INT-009 which is
                      a message for cancel or backorder, for every backorder or for every cancellation we need
                      to send INT-009
     ***********************************************************************************************************
      Modification History:
     Version   SCN#   By                       Date              Comments
      1.0             Abdul and Siva           15-Feb-2012       NA
      1.1      100    C.M.Barath Kumar         10/25/2012        Added  code to handle distro doc type issue
      1.2             K.Kishore Kumar Reddy    31-Jan-2013       Modified the cursor cur_main_shipment to sum up
                                                                 the order line item quantity by line,container_id
      2.0             BT Technology Team       22-Jul-2014       BT Retrofit
      2.1             BT Technology Team       03-Jun-2015       BT Retrofit
      3.0             BT Technology Team       17-Feb-2016       Replaced PROD instance name with EBSPROD, wherever applicable.
      3.1             Infosys Team             31-Jan-2017       CCR0005907 - EBS-O2F: Retail ASN Publish Interface
      4.0             Dayanand Barage          03-May-2108       Added New function to match seq no CCR0007197
      5.0             Shivanshu Talwar         16-May-2021       Modified for Oracle 19C Upgrade - Integration will be happen through Business Event
     *************************************************************************************************************
      Parameters: 1.Reprocess
                  2.Reprocess dates
     *********************************************************************/

    --Start modification by BT Technogy Team on 22-Jul-2014,  v2.0

    gn_asn_publish_days   CONSTANT NUMBER
        := NVL (fnd_profile.VALUE ('XXD_RMS_ASN_PUBLISH_DAYS'), 180) ; --Added for change 4.0(Performance Fix)

    CURSOR get_order_source_id_c IS
        SELECT order_source_id
          FROM OE_ORDER_SOURCES
         WHERE NAME = 'Retail' AND enabled_flag = 'Y';

    gn_order_source_id             oe_order_sources.order_source_id%TYPE;

    --End modification by BT Technogy Team on 22-Jul-2014,  v2.0


    PROCEDURE xxdo_int_007_main_prc (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_deliver_number IN VARCHAR2
                                     , p_reprocess_flag IN VARCHAR2, p_reprocess_from IN VARCHAR2, p_reprocess_to IN VARCHAR2)
    IS
        --------------------------------------------------------
        -- Cursor cur_main_shipment which is used to pull out
        -- the values and fetch the location ID, BOL_NBR,
        -- and all other sales order and shipment information
        -- for which we need to work on
        -- modified the cursor cur_main_shipment to sum up the order line item quantity by line,container_id  (CCR0002708)
        --------------------------------------------------------

        CURSOR cur_main_shipment (p_delivery_number IN VARCHAR2)
        IS
              SELECT to_location_id, from_location_id, bol_nbr,
                     shipment_date, container_qty, ship_to_address1,
                     ship_to_address2, ship_to_address3, ship_to_address4,
                     ship_to_city, ship_to_state, ship_to_zip,
                     ship_to_country, distro_number, distro_doc_type,
                     trailer_nbr, carrier_node, SUM (net_weight) Net_Weight,
                     weight_uom_code, customer_order_nbr, container_name,
                     container_id, item_id, SUM (shipped_quantity) Shipped_Quantity,
                     SUM (ordered_quantity) Ordered_Quantity, SUM (net_quantity) Net_Quantity, line_number,
                     split_from_line_id, order_source, delivery_id,
                     delivery_name, virtual_warehouse, header_id,
                     wms_enabled_flag             -- Added by Naga DFCT0010535
                FROM (SELECT DISTINCT
                             --Start modification by BT Technogy Team on 22-Jul-2014,  v2.0
                             --  drs.rms_store_id To_Location_ID,
                             flv.attribute8
                                 To_Location_ID,
                             --End modification by BT Technogy Team on 22-Jul-2014,  v2.0
                             oola.ship_from_org_id
                                 From_Location_ID,
                             SUBSTR (
                                 NVL (
                                     wnd.waybill,
                                     NVL (
                                         DECODE (dess.pro_number,
                                                 NULL, dess.tracking_number,
                                                 dess.pro_number),
                                         wdd.tracking_number)),
                                 1,
                                 17)
                                 BOL_NBR,
                                TO_CHAR (TRUNC (oola.actual_shipment_date),
                                         'YYYY-MM-DD')
                             || 'T'
                             || TO_CHAR (oola.actual_shipment_date, 'HH:MI:SS')
                                 Shipment_Date,
                             NVL (wnd.number_of_lpn, 0)
                                 Container_Qty,
                             hzl.address1
                                 Ship_To_Address1,
                             hzl.address2
                                 Ship_To_Address2,
                             hzl.address3
                                 Ship_To_Address3,
                             hzl.address4
                                 Ship_To_Address4,
                             hzl.city
                                 Ship_To_City,
                             hzl.state
                                 Ship_To_State,
                             hzl.postal_code
                                 Ship_To_Zip,
                             fnt.territory_code
                                 Ship_To_Country,
                             (SUBSTR (oola.orig_sys_line_ref, 1, INSTR (oola.orig_sys_line_ref, '-') - 1))
                                 Distro_Number,
                             (SUBSTR (oola.orig_sys_line_ref, INSTR (oola.orig_sys_line_ref, '-') + 1, 1))
                                 Distro_Doc_Type,
                             DECODE (dess.pro_number,
                                     NULL, dess.tracking_number,
                                     dess.pro_number)
                                 Trailer_NBR,
                             wnd.ship_method_code
                                 Carrier_Node,
                             wdd.net_weight
                                 Net_Weight,
                             wdd.weight_uom_code
                                 Weight_UOM_Code,
                             ooh.cust_po_number
                                 Customer_Order_Nbr,
                             NVL (apps.lpnid_to_lpn (
                                      (SELECT wdd1.lpn_id
                                         FROM apps.wsh_delivery_details wdd1, apps.wsh_delivery_assignments wda
                                        WHERE     wda.delivery_detail_id =
                                                  wdd.delivery_detail_id
                                              AND wda.parent_delivery_detail_id =
                                                  wdd1.delivery_detail_id)),
                                  0)
                                 Container_name,
                             (SELECT wdd1.lpn_id
                                FROM apps.wsh_delivery_details wdd1, apps.wsh_delivery_assignments wda
                               WHERE     wda.delivery_detail_id =
                                         wdd.delivery_detail_id
                                     AND wda.parent_delivery_detail_id =
                                         wdd1.delivery_detail_id)
                                 container_id,
                             oola.inventory_item_id
                                 Item_ID,
                             wdd.shipped_quantity
                                 Shipped_Quantity,
                             wdd.requested_quantity
                                 Ordered_Quantity,
                             wdd.requested_quantity - wdd.shipped_quantity
                                 Net_Quantity,
                             oola.line_number
                                 Line_Number,
                             oola.SPLIT_FROM_LINE_ID,
                             oos.name
                                 Order_Source,
                             wnd.delivery_id
                                 delivery_id,
                             wnd.name
                                 delivery_name,
                             xst2.DC_VW_ID
                                 Virtual_Warehouse,
                             -- xerm.virtual_warehouse Virtual_Warehouse,
                             oola.header_id,
                             mp.wms_enabled_flag,
                             oola.line_id
                        FROM (SELECT NVL (MAX (last_run_date_time - 1 / 1440), SYSDATE - 1000) dte
                                FROM xxdo_inv_itm_mvmt_table
                               WHERE integration_code = 'INT_007') dte -- added -1 to insure data comes back
                                                                      ,
                             apps.mtl_material_transactions mmt,
                             --Start modification by BT Technogy Team on 22-Jul-2014,  v2.0
                             --  apps.oe_order_lines_all oola,
                             apps.oe_order_lines oola,
                             --End modification by BT Technogy Team on 22-Jul-2014,  v2.0
                             apps.wsh_delivery_details wdd,
                             apps.wsh_delivery_assignments wda,
                             xxdo_inv_int_026_stg2 xst2,
                             apps.wsh_new_deliveries wnd,
                             xxdo_ebs_rms_vw_map xerm,
                             --Start modification by BT Technogy Team on 22-Jul-2014,  v2.0
                             -- apps.oe_order_headers_all ooh,
                             apps.oe_order_headers ooh,
                             --End modification by BT Technogy Team on 22-Jul-2014,  v2.0
                             apps.oe_order_sources oos,
                             apps.mtl_parameters mp,
                             do_edi856_shipments dess,
                             apps.wsh_lookups wsl,
                             --Start modification by BT Technogy Team on 22-Jul-2014,  v2.0
                             -- apps.hz_cust_site_uses_all hcsu,
                             -- apps.hz_cust_acct_sites_all hcasa,
                             apps.hz_cust_site_uses hcsu,
                             apps.hz_cust_acct_sites hcasa,
                             --End modification by BT Technogy Team on 22-Jul-2014,  v2.0
                             apps.hz_party_sites hzps,
                             apps.hz_locations hzl,
                             apps.fnd_territories_tl fnt,
                             --Start modification by BT Technogy Team on 22-Jul-2014,  v2.0
                             fnd_lookup_values flv
                       --               do_retail.stores@datamart.deckers.com     drs
                       --End modification by BT Technogy Team on 22-Jul-2014,  v2.0
                       WHERE --Start modification by BT Technogy Team on 22-Jul-2014,  v2.0
                         -- mmt.transaction_type_id = 33 -- Sales order Issues
                                 mmt.transaction_type_id =
                                 (SELECT TRANSACTION_TYPE_ID
                                    FROM MTL_TRANSACTION_TYPES
                                   WHERE TRANSACTION_TYPE_NAME =
                                         'Sales order issue')
                             --End modification by BT Technogy Team on 22-Jul-2014,  v2.0
                             AND oola.line_id = mmt.trx_source_line_id
                             -- order lines that match shipments
                             AND UPPER (oola.flow_status_code) <> 'CANCELLED'
                             AND xst2.status = 1
                             AND xst2.distro_number =
                                 SUBSTR (
                                     oola.orig_sys_line_ref,
                                     1,
                                     INSTR (oola.orig_sys_line_ref, '-') - 1) -- match distro number
                             AND xst2.xml_id =
                                 SUBSTR (
                                     oola.orig_sys_line_ref,
                                       INSTR (oola.orig_sys_line_ref, '-', -1)
                                     + 1)                      -- match xml_id
                             AND xst2.seq_no = xxdo_get_seq_no (oola.line_id) --CCR0007197 Changes
                             AND oola.orig_sys_document_ref LIKE
                                        'RMS'
                                     || '-'
                                     || xst2.dest_id
                                     || '-'
                                     || xst2.dc_dest_id
                                     || '-%'   -- match dest_id and dc_dest_id
                             AND wdd.source_code = 'OE'
                             AND wdd.source_line_id = oola.line_id
                             AND wda.delivery_detail_id =
                                 wdd.delivery_detail_id
                             AND ((p_deliver_number IS NULL AND mmt.transaction_date >= dte.dte) OR (p_deliver_number IS NOT NULL AND wda.delivery_id = TO_NUMBER (p_deliver_number)))
                             AND wda.delivery_id = wnd.delivery_id
                             AND xerm.channel = 'OUTLET'
                             AND xerm.organization = oola.ship_from_org_id
                             AND ooh.header_id = oola.header_id
                             AND ooh.order_source_id = oos.order_source_id
                             AND ooh.org_id = xerm.org_id
                             AND mp.organization_id = oola.ship_from_org_id
                             AND oos.name = 'Retail'
                             AND wdd.source_header_id = ooh.header_id
                             AND wdd.source_line_id = oola.line_id
                             AND wnd.delivery_id = dess.shipment_id(+)
                             AND wsl.lookup_code = wdd.released_status
                             AND wsl.lookup_type = 'PICK_STATUS'
                             AND wsl.meaning = 'Shipped'
                             AND hcsu.site_use_id(+) = oola.ship_to_org_id
                             AND hcasa.cust_acct_site_id(+) =
                                 hcsu.cust_acct_site_id
                             AND hzps.party_site_id(+) = hcasa.party_site_id
                             AND hzl.location_id(+) = hzps.location_id
                             AND fnt.territory_code = hzl.country
                             AND fnt.language = 'US'
                             --Start modification by BT Technogy Team on 22-Jul-2014,  v2.0
                             --   AND drs.ra_customer_id * 1 = ooh.sold_to_org_id)
                             AND flv.lookup_type = 'XXD_RETAIL_STORES'
                             AND flv.enabled_flag = 'Y'
                             AND TRUNC (NVL (flv.start_date_active, SYSDATE)) >=
                                 SYSDATE
                             AND TRUNC (NVL (flv.end_date_active, SYSDATE)) <=
                                 SYSDATE
                             AND flv.attribute1 * 1 = ooh.sold_to_org_id)
            --End modification by BT Technogy Team on 22-Jul-2014,  v2.0
            GROUP BY to_location_id, from_location_id, bol_nbr,
                     shipment_date, container_qty, ship_to_address1,
                     ship_to_address2, ship_to_address3, ship_to_address4,
                     ship_to_city, ship_to_state, ship_to_zip,
                     ship_to_country, distro_number, distro_doc_type,
                     trailer_nbr, carrier_node, weight_uom_code,
                     customer_order_nbr, container_name, container_id,
                     item_id, line_number, split_from_line_id,
                     order_source, delivery_id, delivery_name,
                     virtual_warehouse, header_id, wms_enabled_flag -- Adde by Naga DFCT0010535
                                                                   ;

        ----------------------

        -- Declaring Variables

        ----------------------

        v_reprocess_flag        VARCHAR2 (10) := p_reprocess_flag;
        v_reprocess_from_date   VARCHAR2 (100) := p_reprocess_from;
        v_reprocess_to_date     VARCHAR2 (100) := p_reprocess_to;
        v_location_id           NUMBER := 0;
        v_from_location_id      NUMBER := 0;
        v_bol_nbr               VARCHAR2 (100) := NULL;
        v_shipment_date         VARCHAR2 (100) := NULL;
        v_container_qty         NUMBER := 0;
        v_ship_to_address1      VARCHAR2 (100) := NULL;
        v_ship_to_address2      VARCHAR2 (100) := NULL;
        v_ship_to_address3      VARCHAR2 (100) := NULL;
        v_ship_to_address4      VARCHAR2 (100) := NULL;
        v_city                  VARCHAR2 (100) := NULL;
        v_state                 VARCHAR2 (100) := NULL;
        v_zip_code              NUMBER := 0;
        v_country               VARCHAR2 (100) := NULL;
        v_distro_number         VARCHAR2 (100) := NULL;
        v_disto_doc_type        VARCHAR2 (100) := NULL;
        v_trailer_nbr           VARCHAR2 (100) := NULL;
        v_carrier_node          VARCHAR2 (4) := NULL;
        v_net_weight            NUMBER := 0;
        v_weight_uom_code       VARCHAR2 (100) := NULL;
        v_cust_order_nbr        VARCHAR2 (100) := NULL;
        v_container_ID          VARCHAR2 (100) := NULL;
        v_item_id               NUMBER := 0;
        v_shipped_qty           NUMBER := 0;
        v_ordered_qty           NUMBER := 0;
        v_net_qty               NUMBER := 0;
        v_line_nbr              NUMBER := 0;
        v_order_source          VARCHAR2 (100) := NULL;
        v_delivery_id           NUMBER := 0;
        v_delivery_name         VARCHAR2 (100) := NULL;
        v_vw_id                 NUMBER := 0;
        v_seq_num               NUMBER := 0;
        v_user_id               NUMBER := 0;
        v_processed_flag        VARCHAR2 (200) := NULL;
        v_transmission_date     DATE := NULL;
        v_error_code            VARCHAR2 (240) := NULL;
        v_xmldata               CLOB := NULL;
        v_retval                CLOB := NULL;
        v_seq_no                NUMBER := 0;
        lc_return               CLOB;
        l_Distro_Doc_Type       VARCHAR2 (10);
        l_Distro_Number         VARCHAR2 (100) := NULL;
        buffer                  VARCHAR2 (32767);
        v_sysdate               DATE;
        lv_errbuf               VARCHAR2 (2000);
        lv_retcode              VARCHAR2 (2000);
        v_container_name        VARCHAR2 (200);
        v_delivery_name1        VARCHAR2 (200) := p_deliver_number;
        lv_count                NUMBER;
    ------------------------------

    -- Beginning of the procedure

    ------------------------------

    BEGIN
        BEGIN
            SELECT SYSDATE INTO v_sysdate FROM DUAL;

            fnd_file.put_line (fnd_file.LOG, 'System Date Is :' || v_sysdate);
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_File.put_line (
                    fnd_file.LOG,
                    'Others error Found While getting the sysdate');
                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Code :' || SQLCODE);
                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Message:' || SQLERRM);
        END;

        ------------------------------------

        -- Select query to get the user ID

        ------------------------------------

        BEGIN
            ---------------------

            -- User name = BATCH

            ---------------------

            SELECT user_id
              INTO v_user_id
              FROM apps.fnd_user
             WHERE UPPER (user_name) = 'BATCH';
        EXCEPTION
            ----------------------

            -- Exception Handler

            ----------------------

            WHEN NO_DATA_FOUND
            THEN
                v_user_id   := 0;

                fnd_file.put_line (fnd_file.LOG,
                                   'No Data Found While Getting The User ID');

                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Code :' || SQLCODE);

                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Message :' || SQLERRM);
            WHEN OTHERS
            THEN
                v_user_id   := 0;

                fnd_file.put_line (
                    fnd_file.LOG,
                    'Others Error Found While Getting The User ID');

                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Code :' || SQLCODE);

                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Message :' || SQLERRM);
        --------------------------------------------

        -- End of the block to retrive the USER ID

        --------------------------------------------

        END;

        ----------------------------------------------------------

        -- check to see if the reprocess flag is ON and if requested

        -- if requested then we shouldn't run the cursor instead

        -- update the staging table with the flag as N so that

        -- it will be picked up for processing

        ----------------------------------------------------------

        IF (UPPER (v_reprocess_flag) = 'NO' OR UPPER (v_reprocess_flag) = 'N')
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Delivery Number :' || v_delivery_name1);

            ------------------------------------------------

            -- If the reprocess flag = N which means

            -- We need to take in the correct shipments

            -- and then send the XML data

            ------------------------------------------------

            FOR c_cur_main_shipment IN cur_main_shipment (v_delivery_name1)
            LOOP
                fnd_file.put_line (fnd_file.LOG, 'INside the loop');

                ----------------------------------------------

                -- Sequence which is used to take in the

                -- next val and store in the table

                ----------------------------------------------

                BEGIN
                    ------------------------------------------

                    -- We need to get the nextval from dual

                    ------------------------------------------

                    SELECT xxdo_ship_int_seq.NEXTVAL INTO v_seq_num FROM DUAL;
                ----------------------

                -- Exception Handler

                ----------------------

                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        v_user_id   := 0;

                        fnd_file.put_line (
                            fnd_file.LOG,
                            'No Data Found While Getting The Sequence Number');

                        fnd_file.put_line (fnd_file.LOG,
                                           'SQL Error Code :' || SQLCODE);

                        fnd_file.put_line (fnd_file.LOG,
                                           'SQL Error Message :' || SQLERRM);
                    WHEN OTHERS
                    THEN
                        v_user_id   := 0;

                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Others Error While Getting The Sequence Number');

                        fnd_file.put_line (fnd_file.LOG,
                                           'SQL Error Code :' || SQLCODE);

                        fnd_file.put_line (fnd_file.LOG,
                                           'SQL Error Message :' || SQLERRM);
                --------------------------------------------

                -- End of the block to retrive the USER ID

                --------------------------------------------

                END;

                ----------------------------------------------------
                ---  100 Distro Doctype fetch
                ----------------------------------------------------

                IF c_cur_main_shipment.Distro_Doc_Type = 'O'
                THEN
                    l_Distro_Doc_Type   := NULL;
                    l_Distro_Number     := NULL;

                    BEGIN
                        SELECT (SUBSTR (ool.orig_sys_line_ref, INSTR (ool.orig_sys_line_ref, '-') + 1, 1)), (SUBSTR (ool.orig_sys_line_ref, 1, INSTR (ool.orig_sys_line_ref, '-') - 1))
                          INTO l_Distro_Doc_Type, l_Distro_Number
                          --Start modification by BT Technogy Team on 22-Jul-2014,  v2.0
                          --FROM oe_order_lines_all ool
                          FROM oe_order_lines ool
                         --End modification by BT Technogy Team on 22-Jul-2014,  v2.0
                         WHERE line_id =
                               (SELECT MIN (line_id)
                                  --Start modification by BT Technogy Team on 22-Jul-2014,  v2.0
                                  -- FROM apps.oe_order_lines_all
                                  FROM apps.oe_order_lines
                                 --End modification by BT Technogy Team on 22-Jul-2014,  v2.0
                                 WHERE     header_id =
                                           c_cur_main_shipment.header_id
                                       AND LINE_NUMBER =
                                           c_cur_main_shipment.LINE_NUMBER); --added sub query  by naga

                        -- c_cur_main_shipment.SPLIT_FROM_LINE_ID ;


                        fnd_file.put_line (
                            fnd_file.LOG,
                            'l_Distro_Number  ' || l_Distro_Number);
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'c_cur_main_shipment.SPLIT_FROM_LINE_ID  '
                            || c_cur_main_shipment.SPLIT_FROM_LINE_ID);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_Distro_Doc_Type   := 'E';

                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Others Error While Getting The Distro_Doc_Type for  split line id '
                                || c_cur_main_shipment.SPLIT_FROM_LINE_ID);

                            fnd_file.put_line (fnd_file.LOG,
                                               'SQL Error Code :' || SQLCODE);

                            fnd_file.put_line (
                                fnd_file.LOG,
                                'SQL Error Message :' || SQLERRM);
                    END;
                ELSE
                    l_Distro_Doc_Type   := NULL;
                    l_Distro_Number     := NULL;
                    l_Distro_Doc_Type   :=
                        c_cur_main_shipment.Distro_Doc_Type;
                    l_Distro_Number     := c_cur_main_shipment.Distro_Number;
                END IF;

                ---------------------------------------------------
                ----- End Distro type fetch  ---
                -----------------------------------------------------

                -- added by naga
                IF v_delivery_name1 IS NOT NULL
                THEN
                    lv_count   := 0;
                ELSE
                    BEGIN
                        lv_count   := NULL;

                        SELECT COUNT (*)
                          INTO lv_count
                          FROM apps.xxdo_007_ship_int_stg
                         WHERE     delivery_id =
                                   c_cur_main_shipment.delivery_id -- 148737242
                               AND ITEM_ID = c_cur_main_shipment.item_id --3282817;
                               AND LPN_ID = c_cur_main_shipment.Container_ID
                               AND order_number =
                                   c_cur_main_shipment.Distro_Number;
                    --    and status ='N'

                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_count   := 2;
                    END;
                END IF;

                -------------------------------------------

                -- Insert into xxdo_007_ship_int_stg

                -------------------------------------------

                IF lv_count = 0
                THEN                             -- if condition added by naga
                    BEGIN
                        INSERT INTO xxdo_007_ship_int_stg (
                                        seq_number,
                                        to_location_id,
                                        from_location_id,
                                        bol_nbr,
                                        shipment_date,
                                        container_qty,
                                        ship_to_address1,
                                        ship_to_address2,
                                        ship_to_address3,
                                        ship_to_address4,
                                        city,
                                        state,
                                        post_code,
                                        country,
                                        order_number,
                                        distro_doc_type,
                                        trailer_nbr,
                                        carrier_node,
                                        net_weight,
                                        weight_uom_code,
                                        cust_order_nbr,
                                        lpn_id,
                                        item_ID,
                                        shipped_qty,
                                        ordered_qty,
                                        net_qty,
                                        line_number,
                                        order_source,
                                        delivery_id,
                                        delivery_name,
                                        virtual_warehouse,
                                        status,
                                        processing_message,
                                        created_by,
                                        creation_date,
                                        last_update_by,
                                        last_update_date,
                                        container_name)
                                 VALUES (
                                            v_seq_num,
                                            c_cur_main_shipment.To_Location_ID,
                                            c_cur_main_shipment.From_Location_ID,
                                            c_cur_main_shipment.BOL_NBR,
                                            c_cur_main_shipment.Shipment_Date,
                                            c_cur_main_shipment.Container_Qty,
                                            c_cur_main_shipment.Ship_To_Address1,
                                            c_cur_main_shipment.Ship_To_Address2,
                                            c_cur_main_shipment.Ship_To_Address3,
                                            c_cur_main_shipment.Ship_To_Address4,
                                            c_cur_main_shipment.Ship_To_City,
                                            SUBSTR (
                                                c_cur_main_shipment.Ship_To_State,
                                                1,
                                                3),
                                            c_cur_main_shipment.Ship_To_Zip,
                                            c_cur_main_shipment.Ship_To_Country,
                                            l_Distro_Number,
                                            ---  c_cur_main_shipment.Distro_Number        ,

                                            l_Distro_Doc_Type, ---- 200 Added for Distro Doc Type issue
                                            ---- c_cur_main_shipment.Distro_Doc_Type      ,

                                            c_cur_main_shipment.Trailer_NBR,
                                            SUBSTR (
                                                c_cur_main_shipment.Carrier_Node,
                                                1,
                                                4),
                                            c_cur_main_shipment.Net_Weight,
                                            c_cur_main_shipment.Weight_UOM_Code,
                                            c_cur_main_shipment.Customer_Order_Nbr,
                                            c_cur_main_shipment.Container_ID,
                                            c_cur_main_shipment.Item_ID,
                                            c_cur_main_shipment.Shipped_Quantity,
                                            c_cur_main_shipment.Ordered_Quantity,
                                            c_cur_main_shipment.Net_Quantity,
                                            c_cur_main_shipment.Line_Number,
                                            c_cur_main_shipment.Order_Source,
                                            c_cur_main_shipment.delivery_id,
                                            c_cur_main_shipment.delivery_name,
                                            c_cur_main_shipment.Virtual_Warehouse,
                                            'N',
                                            NULL,
                                            v_user_id,
                                            SYSDATE,
                                            v_user_id,
                                            SYSDATE,
                                            DECODE (
                                                c_cur_main_shipment.wms_enabled_flag,
                                                'Y', LPAD (
                                                         CAST (
                                                             apps.do_wms_interface.fix_container (
                                                                 c_cur_main_shipment.container_name)
                                                                 AS VARCHAR2 (20)),
                                                         20,
                                                         '0'),
                                                c_cur_main_shipment.container_name));
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Others Error While Inserting The Data Into The Staging Table');

                            fnd_file.put_line (fnd_file.LOG,
                                               'SQL Error Code :' || SQLCODE);

                            fnd_file.put_line (
                                fnd_file.LOG,
                                'SQL Error Message :' || SQLERRM);
                    END;
                END IF;

                ---------------------------------------------------------------------------------

                -- In the case of partial shipment such as ordered quantity <> shipped quantity

                -- we need to send a INT-009 status message to RMS and this can be obtained

                -- by cross check the ordered quantity - shipped quantity and there by getting

                -- the net quantity

                ---------------------------------------------------------------------------------

                IF (c_cur_main_shipment.Ordered_Quantity - c_cur_main_shipment.Ordered_Quantity) >
                   0
                THEN
                    /*xxdo_int_009_prc(lv_errbuf
                                   ,lv_retcode
                                   ,c_cur_main_shipment.To_Location_ID
                                   ,c_cur_main_shipment.Distro_Number
                                   ,c_cur_main_shipment.Distro_Doc_Type
                                   ,c_cur_main_shipment.Distro_Number
                                   ,c_cur_main_shipment.To_Location_ID
                                   ,c_cur_main_shipment.Item_ID
                                   ,c_cur_main_shipment.Line_Number
                                   ,c_cur_main_shipment.Ordered_Quantity - c_cur_main_shipment.Ordered_Quantity
                                   ,'NI');*/
                    NULL;
                ELSE
                    -- do nothing

                    NULL;
                END IF;
            END LOOP;

            COMMIT;
        END IF;

        -----------------------------------------------------

        -- If the process flag is Y which means the user is

        -- requesting for reprocessing and therefore

        -- we need to update the staging tables with the

        -- status as N for the values where the status is VE

        -- and for the dates

        -----------------------------------------------------

        IF (UPPER (v_reprocess_flag) = 'YES' OR UPPER (v_reprocess_flag) = 'Y')
        THEN
            BEGIN
                --------------------------------------

                -- Update the staging table

                --------------------------------------

                UPDATE xxdo_007_ship_int_stg
                   SET status = 'N', processed_flag = NULL, last_update_by = v_user_id
                 WHERE     status = 'VE'
                       AND last_update_date >=
                           TRUNC (
                               TO_DATE (v_reprocess_from_date,
                                        'YYYY/MM/DD HH24:MI:SS'))
                       AND last_update_date <=
                           TRUNC (
                               TO_DATE (v_reprocess_to_date,
                                        'YYYY/MM/DD HH24:MI:SS'));
            --------------------

            -- Exception Handler

            --------------------

            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'No Data Found While Updating The Table : xxdo_007_ship_int_stg');

                    fnd_file.put_line (fnd_file.LOG,
                                       'SQL Error Code:' || SQLCODE);

                    fnd_file.put_line (fnd_file.LOG,
                                       'SQL Error Message :' || SQLERRM);
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'No Data Found While Updating The Table : xxdo_007_ship_int_stg');

                    fnd_file.put_line (fnd_file.LOG,
                                       'SQL Error Code:' || SQLCODE);

                    fnd_file.put_line (fnd_file.LOG,
                                       'SQL Error Message :' || SQLERRM);
            END;
        END IF;

        --------------------------------------------------------------

        -- Calling the procedure which will send the messages to RIB

        --------------------------------------------------------------

        xxdo_int_007_processing_msgs (v_sysdate, p_deliver_number);
    -----------------------------------

    -- End of calling the procedure

    -----------------------------------

    END;



    PROCEDURE xxdo_int_007_main_prc_union (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_deliver_number IN VARCHAR2
                                           , p_reprocess_flag IN VARCHAR2, p_reprocess_from IN VARCHAR2, p_reprocess_to IN VARCHAR2)
    IS
        --------------------------------------------------------

        -- Cursor cur_main_shipment which is used to pull out

        -- the values and fetch the location ID, BOL_NBR,

        -- and all other sales order and shipment information

        -- for which we need to work on

        -- modified the cursor cur_main_shipment to sum up the order line item quantity by line,container_id  (CCR0002708)
        --------------------------------------------------------

        CURSOR cur_main_shipment (p_delivery_number   IN VARCHAR2,
                                  p_miss_delivery     IN VARCHAR2)
        IS
              SELECT to_location_id, from_location_id, bol_nbr,
                     shipment_date, container_qty, ship_to_address1,
                     ship_to_address2, ship_to_address3, ship_to_address4,
                     ship_to_city, ship_to_state, ship_to_zip,
                     ship_to_country, distro_number, distro_doc_type,
                     trailer_nbr, carrier_node, SUM (net_weight) net_weight,
                     weight_uom_code, customer_order_nbr, container_name,
                     container_id, item_id, SUM (shipped_quantity) shipped_quantity,
                     SUM (ordered_quantity) ordered_quantity, SUM (net_quantity) net_quantity, line_number,
                     split_from_line_id, order_source, delivery_id,
                     delivery_name, virtual_warehouse, header_id,
                     wms_enabled_flag             -- Added by Naga DFCT0010535
                FROM (SELECT --Start modification by BT Technogy Team on 22-Jul-2014,  v2.0
                                           -- drs.rms_store_id to_location_id,
                            flv.attribute8
                                to_location_id,
                            --End modification by BT Technogy Team on 22-Jul-2014,  v2.0
                            oola.line_id,
                            oola.ship_from_org_id
                                from_location_id,
                            SUBSTR (
                                NVL (
                                    wnd.waybill,
                                    NVL (
                                        DECODE (dess.pro_number,
                                                NULL, dess.tracking_number,
                                                dess.pro_number),
                                        wdd.tracking_number)),
                                1,
                                17)
                                bol_nbr,
                               TO_CHAR (TRUNC (oola.actual_shipment_date),
                                        'YYYY-MM-DD')
                            || 'T'
                            || TO_CHAR (oola.actual_shipment_date, 'HH:MI:SS')
                                shipment_date,
                            NVL (wnd.number_of_lpn, 0)
                                container_qty,
                            hzl.address1
                                ship_to_address1,
                            hzl.address2
                                ship_to_address2,
                            hzl.address3
                                ship_to_address3,
                            hzl.address4
                                ship_to_address4,
                            hzl.city
                                ship_to_city,
                            hzl.state
                                ship_to_state,
                            hzl.postal_code
                                ship_to_zip,
                            fnt.territory_code
                                ship_to_country,
                            (SUBSTR (oola.orig_sys_line_ref, 1, INSTR (oola.orig_sys_line_ref, '-') - 1))
                                distro_number,
                            (SUBSTR (oola.orig_sys_line_ref, INSTR (oola.orig_sys_line_ref, '-') + 1, 1))
                                distro_doc_type,
                            DECODE (dess.pro_number,
                                    NULL, dess.tracking_number,
                                    dess.pro_number)
                                trailer_nbr,
                            wnd.ship_method_code
                                carrier_node,
                            wdd.net_weight
                                net_weight,
                            wdd.weight_uom_code
                                weight_uom_code,
                            ooh.cust_po_number
                                customer_order_nbr,
                            NVL (apps.lpnid_to_lpn (
                                     (SELECT wdd1.lpn_id
                                        FROM apps.wsh_delivery_details wdd1, apps.wsh_delivery_assignments wda
                                       WHERE     wda.delivery_detail_id =
                                                 wdd.delivery_detail_id
                                             AND wda.parent_delivery_detail_id =
                                                 wdd1.delivery_detail_id)),
                                 0)
                                container_name,
                            (SELECT wdd1.lpn_id
                               FROM apps.wsh_delivery_details wdd1, apps.wsh_delivery_assignments wda
                              WHERE     wda.delivery_detail_id =
                                        wdd.delivery_detail_id
                                    AND wda.parent_delivery_detail_id =
                                        wdd1.delivery_detail_id)
                                container_id,
                            oola.inventory_item_id
                                item_id,
                            wdd.shipped_quantity
                                shipped_quantity,
                            wdd.requested_quantity
                                ordered_quantity,
                            wdd.requested_quantity - wdd.shipped_quantity
                                net_quantity,
                            oola.line_number
                                line_number,
                            oola.split_from_line_id,
                            oos.NAME
                                order_source,
                            wnd.delivery_id
                                delivery_id,
                            wnd.NAME
                                delivery_name,
                            xst2.dc_vw_id
                                virtual_warehouse,
                            -- xerm.virtual_warehouse Virtual_Warehouse,
                            oola.header_id,
                            mp.wms_enabled_flag,
                            oola.line_id
                       FROM (SELECT NVL (MAX (last_run_date_time - 1 / 1440), SYSDATE - 1000) dte
                               FROM xxdo_inv_itm_mvmt_table
                              WHERE integration_code = 'INT_007') dte -- added -1 to insure data comes back
                                                                     ,
                            apps.mtl_material_transactions mmt,
                            apps.oe_order_lines_all oola,
                            apps.wsh_delivery_details wdd,
                            apps.wsh_delivery_assignments wda,
                            xxdo_inv_int_026_stg2 xst2,
                            apps.wsh_new_deliveries wnd,
                            xxdo_ebs_rms_vw_map xerm,
                            apps.oe_order_headers_all ooh,
                            apps.oe_order_sources oos,
                            apps.mtl_parameters mp,
                            do_edi856_shipments dess,
                            apps.wsh_lookups wsl,
                            apps.hz_cust_site_uses_all hcsu,
                            apps.hz_cust_acct_sites_all hcasa,
                            apps.hz_party_sites hzps,
                            apps.hz_locations hzl,
                            apps.fnd_territories_tl fnt,
                            apps.fnd_lookup_values flv
                      --Start modification by BT Technogy Team on 22-Jul-2014,  v2.0
                      --                 do_retail.stores@datamart.deckers.com drs
                      --End modification by BT Technogy Team on 22-Jul-2014,  v2.0
                      WHERE     1 = 1
                            --Start modification by BT Technogy Team on 22-Jul-2014,  v2.0
                            --AND mmt.transaction_type_id = 33 -- Sales order Issues
                            AND mmt.transaction_type_id =
                                (SELECT TRANSACTION_TYPE_ID
                                   FROM MTL_TRANSACTION_TYPES
                                  WHERE TRANSACTION_TYPE_NAME =
                                        'Sales order issue')
                            --End modification by BT Technogy Team on 22-Jul-2014,  v2.0
                            AND oola.line_id = mmt.trx_source_line_id
                            -- order lines that match shipments
                            AND wdd.delivery_detail_id = mmt.picking_line_Id /* added on 07/10/2013 Defect :DFCT0010677 and CCR# :CCR0003240 */
                            AND UPPER (oola.flow_status_code) <> 'CANCELLED'
                            AND xst2.status = 1
                            AND xst2.distro_number =
                                SUBSTR (
                                    oola.orig_sys_line_ref,
                                    1,
                                    INSTR (oola.orig_sys_line_ref, '-') - 1) -- match distro number
                            --             AND xst2.xml_id =
                            --                    SUBSTR (oola.orig_sys_line_ref,
                            --                            INSTR (oola.orig_sys_line_ref, '-', -1) + 1
                            --                           )                                   -- match xml_id
                            --AND xst2.seq_no = xxdo_get_seq_no (md.line_id) --CCR0007197 Changes
                            AND oola.orig_sys_document_ref LIKE
                                       'RMS'
                                    || '-'
                                    || xst2.dest_id
                                    || '-'
                                    || xst2.dc_dest_id
                                    || '-%'    -- match dest_id and dc_dest_id
                            AND wdd.source_code = 'OE'
                            AND wdd.source_line_id = oola.line_id
                            AND wda.delivery_detail_id = wdd.delivery_detail_id
                            AND ((p_deliver_number IS NULL AND mmt.transaction_date >= dte.dte) OR (p_deliver_number IS NOT NULL AND wda.delivery_id = TO_NUMBER (p_deliver_number)))
                            AND wda.delivery_id = wnd.delivery_id
                            AND xerm.channel = 'OUTLET'
                            AND xerm.ORGANIZATION = oola.ship_from_org_id
                            AND ooh.header_id = oola.header_id
                            AND ooh.order_source_id = oos.order_source_id
                            AND ooh.org_id = xerm.org_id
                            AND mp.organization_id = oola.ship_from_org_id
                            AND oos.NAME = 'Retail'
                            AND wdd.source_header_id = ooh.header_id
                            AND wdd.source_line_id = oola.line_id
                            AND wnd.delivery_id = dess.shipment_id(+)
                            AND wnd.status_code = 'CL'
                            AND wnd.asn_status_code IS NULL /*added on 10/11/2013*/
                            AND wdd.released_status = 'C'
                            AND wsl.lookup_code = wdd.released_status
                            AND wsl.lookup_type = 'PICK_STATUS'
                            AND wsl.meaning = 'Shipped'
                            AND hcsu.site_use_id(+) = oola.ship_to_org_id
                            AND hcasa.cust_acct_site_id(+) =
                                hcsu.cust_acct_site_id
                            AND hzps.party_site_id(+) = hcasa.party_site_id
                            AND hzl.location_id(+) = hzps.location_id
                            AND fnt.territory_code = hzl.country
                            AND fnt.LANGUAGE = 'US'
                            --Start modification by BT Technogy Team on 22-Jul-2014,  v2.0
                            --   AND drs.ra_customer_id * 1 = ooh.sold_to_org_id)
                            AND flv.lookup_type = 'XXD_RETAIL_STORES'
                            AND flv.enabled_flag = 'Y'
                            AND TRUNC (NVL (flv.start_date_active, SYSDATE)) >=
                                SYSDATE
                            AND TRUNC (NVL (flv.end_date_active, SYSDATE)) <=
                                SYSDATE
                            AND flv.attribute1 * 1 = ooh.sold_to_org_id)
            --  AND drs.ra_customer_id * 1 = ooh.sold_to_org_id)
            --End modification by BT Technogy Team on 22-Jul-2014,  v2.0
            GROUP BY to_location_id, from_location_id, bol_nbr,
                     shipment_date, container_qty, ship_to_address1,
                     ship_to_address2, ship_to_address3, ship_to_address4,
                     ship_to_city, ship_to_state, ship_to_zip,
                     ship_to_country, distro_number, distro_doc_type,
                     trailer_nbr, carrier_node, weight_uom_code,
                     customer_order_nbr, container_name, container_id,
                     item_id, line_number, split_from_line_id,
                     order_source, delivery_id, delivery_name,
                     virtual_warehouse, header_id, wms_enabled_flag
            UNION
              SELECT to_location_id, from_location_id, bol_nbr,
                     shipment_date, container_qty, ship_to_address1,
                     ship_to_address2, ship_to_address3, ship_to_address4,
                     ship_to_city, ship_to_state, ship_to_zip,
                     ship_to_country, distro_number, distro_doc_type,
                     trailer_nbr, carrier_node, SUM (net_weight) net_weight,
                     weight_uom_code, customer_order_nbr, container_name,
                     container_id, item_id, SUM (shipped_quantity) shipped_quantity,
                     SUM (ordered_quantity) ordered_quantity, SUM (net_quantity) net_quantity, line_number,
                     split_from_line_id, order_source, delivery_id,
                     delivery_name, virtual_warehouse, header_id,
                     wms_enabled_flag
                FROM (SELECT --Start modification by BT Technogy Team on 22-Jul-2014,  v2.0
                                           -- drs.rms_store_id to_location_id,
                            flv.attribute8 to_location_id,
                            --Start modification by BT Technogy Team on 22-Jul-2014,  v2.0
                            md.from_location_id,
                            SUBSTR (
                                NVL (
                                    md.waybill,
                                    NVL (
                                        DECODE (dess.pro_number,
                                                NULL, dess.tracking_number,
                                                dess.pro_number),
                                        md.tracking_number)),
                                1,
                                17) bol_nbr,
                            md.shipment_date,
                            md.container_qty,
                            hzl.address1 ship_to_address1,
                            hzl.address2 ship_to_address2,
                            hzl.address3 ship_to_address3,
                            hzl.address4 ship_to_address4,
                            hzl.city ship_to_city,
                            hzl.state ship_to_state,
                            hzl.postal_code ship_to_zip,
                            fnt.territory_code ship_to_country,
                            md.distro_number,
                            md.distro_doc_type,
                            DECODE (dess.pro_number,
                                    NULL, dess.tracking_number,
                                    dess.pro_number) trailer_nbr,
                            md.carrier_node,
                            md.net_weight net_weight,
                            md.weight_uom_code,
                            md.customer_order_nbr,
                            NVL (apps.lpnid_to_lpn (
                                     (SELECT wdd1.lpn_id
                                        FROM apps.wsh_delivery_details wdd1, apps.wsh_delivery_assignments wda
                                       WHERE     wda.delivery_detail_id =
                                                 md.delivery_detail_id
                                             AND wda.parent_delivery_detail_id =
                                                 wdd1.delivery_detail_id)),
                                 0) container_name,
                            (SELECT wdd1.lpn_id
                               FROM apps.wsh_delivery_details wdd1, apps.wsh_delivery_assignments wda
                              WHERE     wda.delivery_detail_id =
                                        md.delivery_detail_id
                                    AND wda.parent_delivery_detail_id =
                                        wdd1.delivery_detail_id) container_id,
                            md.item_id,
                            md.shipped_quantity shipped_quantity,
                            md.ordered_quantity ordered_quantity,
                            md.net_quantity net_quantity,
                            md.line_number,
                            md.split_from_line_id,
                            md.order_source,
                            md.delivery_id,
                            md.delivery_name,
                            xst2.dc_vw_id virtual_warehouse,
                            md.header_id,
                            md.wms_enabled_flag   -- Added by Naga DFCT0010535
                       FROM (SELECT ool.ship_from_org_id from_location_id, wdd.tracking_number, wnd.waybill,
                                    wdd.delivery_detail_id, TO_CHAR (TRUNC (ool.actual_shipment_date), 'YYYY-MM-DD') || 'T' || TO_CHAR (ool.actual_shipment_date, 'HH:MI:SS') shipment_date, NVL (wnd.number_of_lpn, 0) container_qty,
                                    (SUBSTR (ool.orig_sys_line_ref, 1, INSTR (ool.orig_sys_line_ref, '-') - 1)) distro_number, (SUBSTR (ool.orig_sys_line_ref, INSTR (ool.orig_sys_line_ref, '-') + 1, 1)) distro_doc_type, wnd.ship_method_code carrier_node,
                                    wdd.net_weight net_weight, wdd.weight_uom_code weight_uom_code, ooh.cust_po_number customer_order_nbr,
                                    ool.inventory_item_id item_id, wdd.shipped_quantity shipped_quantity, wdd.requested_quantity ordered_quantity,
                                    wdd.requested_quantity - wdd.shipped_quantity net_quantity, ool.line_number line_number, ool.split_from_line_id,
                                    oos.NAME order_source, wnd.delivery_id delivery_id, wnd.NAME delivery_name,
                                    ool.header_id, mp.wms_enabled_flag, ool.line_id,
                                    ool.orig_sys_line_ref, ool.orig_sys_document_ref, ool.ship_from_org_id,
                                    ooh.org_id, wdd.released_status, ool.ship_to_org_id,
                                    ooh.sold_to_org_id
                               FROM apps.oe_order_headers_all ooh, apps.wsh_new_deliveries wnd, apps.oe_order_sources oos,
                                    apps.wsh_delivery_assignments wda, apps.wsh_delivery_details wdd, apps.oe_order_lines_all ool,
                                    apps.mtl_parameters mp
                              WHERE     ooh.header_id = wnd.source_header_id
                                    AND ooh.order_source_id =
                                        oos.order_source_id
                                    AND wnd.delivery_id = wda.delivery_id
                                    -- AND wnd.ASN_STATUS_CODE is NULL
                                    AND wda.delivery_detail_id =
                                        wdd.delivery_detail_id
                                    AND wdd.source_header_id = ooh.header_id
                                    AND wdd.source_code = 'OE'
                                    AND ool.header_id = ooh.header_id
                                    AND ool.line_id = wdd.source_line_id
                                    AND ool.order_source_id =
                                        oos.order_source_id
                                    AND oos.NAME = 'Retail'
                                    AND mp.organization_id =
                                        ool.ship_from_org_id
                                    --AND ool.LINE_ID=57182349
                                    AND TO_DATE (
                                            TRUNC (ool.actual_shipment_date)) >=
                                        TRUNC (SYSDATE - 30)
                                    --to_date('09/01/2012','MM/DD/RRRR')
                                    AND NOT EXISTS
                                            (SELECT 1
                                               FROM apps.xxdo_007_ship_int_stg
                                              WHERE delivery_id =
                                                    wnd.delivery_id)) md,
                            xxdo_inv_int_026_stg2 xst2,
                            xxdo_ebs_rms_vw_map xerm,
                            do_edi856_shipments dess,
                            -- apps.wsh_lookups               wsl ,
                            apps.hz_cust_site_uses_all hcsu,
                            apps.hz_cust_acct_sites_all hcasa,
                            apps.hz_party_sites hzps,
                            apps.hz_locations hzl,
                            apps.fnd_territories_tl fnt,
                            --Start modification by BT Technogy Team on 22-Jul-2014,  v2.0
                            apps.fnd_lookup_values flv
                      --         do_retail.stores@datamart.deckers.com drs
                      --End modification by BT Technogy Team on 22-Jul-2014,  v2.0
                      WHERE     xst2.status = 1
                            AND xst2.distro_number =
                                SUBSTR (md.orig_sys_line_ref,
                                        1,
                                        INSTR (md.orig_sys_line_ref, '-') - 1) -- match distro number
                            AND xst2.xml_id =
                                SUBSTR (
                                    md.orig_sys_line_ref,
                                    INSTR (md.orig_sys_line_ref, '-', -1) + 1) -- match xml_id
                            AND xst2.seq_no = xxdo_get_seq_no (md.line_id) --CCR0007197 Changes
                            AND md.orig_sys_document_ref LIKE
                                       'RMS'
                                    || '-'
                                    || xst2.dest_id
                                    || '-'
                                    || xst2.dc_dest_id
                                    || '-%'                   -- match dest_id
                            AND xerm.channel = 'OUTLET'
                            AND xerm.ORGANIZATION = md.ship_from_org_id
                            AND md.org_id = xerm.org_id
                            AND md.delivery_id = dess.shipment_id(+)
                            --             AND wsl.lookup_code = md.released_status
                            --             AND wsl.lookup_type = 'PICK_STATUS'
                            --             AND wsl.meaning = 'Shipped'
                            AND hcsu.site_use_id(+) = md.ship_to_org_id
                            AND hcasa.cust_acct_site_id(+) =
                                hcsu.cust_acct_site_id
                            AND hzps.party_site_id(+) = hcasa.party_site_id
                            AND hzl.location_id(+) = hzps.location_id
                            AND fnt.territory_code = hzl.country
                            AND fnt.LANGUAGE = 'US'
                            --Start modification by BT Technogy Team on 22-Jul-2014,  v2.0
                            AND flv.lookup_type = 'XXD_RETAIL_STORES'
                            AND flv.enabled_flag = 'Y'
                            AND TRUNC (NVL (flv.start_date_active, SYSDATE)) >=
                                SYSDATE
                            AND TRUNC (NVL (flv.end_date_active, SYSDATE)) <=
                                SYSDATE
                            AND flv.attribute1 * 1 = md.sold_to_org_id
                            AND 1 = NVL (p_miss_delivery, 1))
            --    AND drs.ra_customer_id * 1 = md.sold_to_org_id
            --End modification by BT Technogy Team on 22-Jul-2014,  v2.0
            GROUP BY to_location_id, from_location_id, bol_nbr,
                     shipment_date, container_qty, ship_to_address1,
                     ship_to_address2, ship_to_address3, ship_to_address4,
                     ship_to_city, ship_to_state, ship_to_zip,
                     ship_to_country, distro_number, distro_doc_type,
                     trailer_nbr, carrier_node, weight_uom_code,
                     customer_order_nbr, container_name, container_id,
                     item_id, line_number, split_from_line_id,
                     order_source, delivery_id, delivery_name,
                     virtual_warehouse, header_id, wms_enabled_flag;

        ----------------------

        -- Declaring Variables

        ----------------------

        v_reprocess_flag        VARCHAR2 (10) := p_reprocess_flag;
        v_reprocess_from_date   VARCHAR2 (100) := p_reprocess_from;
        v_reprocess_to_date     VARCHAR2 (100) := p_reprocess_to;
        v_location_id           NUMBER := 0;
        v_from_location_id      NUMBER := 0;
        v_bol_nbr               VARCHAR2 (100) := NULL;
        v_shipment_date         VARCHAR2 (100) := NULL;
        v_container_qty         NUMBER := 0;
        v_ship_to_address1      VARCHAR2 (100) := NULL;
        v_ship_to_address2      VARCHAR2 (100) := NULL;
        v_ship_to_address3      VARCHAR2 (100) := NULL;
        v_ship_to_address4      VARCHAR2 (100) := NULL;
        v_city                  VARCHAR2 (100) := NULL;
        v_state                 VARCHAR2 (100) := NULL;
        v_zip_code              NUMBER := 0;
        v_country               VARCHAR2 (100) := NULL;
        v_distro_number         VARCHAR2 (100) := NULL;
        v_disto_doc_type        VARCHAR2 (100) := NULL;
        v_trailer_nbr           VARCHAR2 (100) := NULL;
        v_carrier_node          VARCHAR2 (4) := NULL;
        v_net_weight            NUMBER := 0;
        v_weight_uom_code       VARCHAR2 (100) := NULL;
        v_cust_order_nbr        VARCHAR2 (100) := NULL;
        v_container_ID          VARCHAR2 (100) := NULL;
        v_item_id               NUMBER := 0;
        v_shipped_qty           NUMBER := 0;
        v_ordered_qty           NUMBER := 0;
        v_net_qty               NUMBER := 0;
        v_line_nbr              NUMBER := 0;
        v_order_source          VARCHAR2 (100) := NULL;
        v_delivery_id           NUMBER := 0;
        v_delivery_name         VARCHAR2 (100) := NULL;
        v_vw_id                 NUMBER := 0;
        v_seq_num               NUMBER := 0;
        v_user_id               NUMBER := 0;
        v_processed_flag        VARCHAR2 (200) := NULL;
        v_transmission_date     DATE := NULL;
        v_error_code            VARCHAR2 (240) := NULL;
        v_xmldata               CLOB := NULL;
        v_retval                CLOB := NULL;
        v_seq_no                NUMBER := 0;
        lc_return               CLOB;
        l_Distro_Doc_Type       VARCHAR2 (10);
        l_Distro_Number         VARCHAR2 (100) := NULL;
        buffer                  VARCHAR2 (32767);
        v_sysdate               DATE;
        lv_errbuf               VARCHAR2 (2000);
        lv_retcode              VARCHAR2 (2000);
        v_container_name        VARCHAR2 (200);
        v_delivery_name1        VARCHAR2 (200) := p_deliver_number;
        lv_count                NUMBER;
        p_miss_delivery         VARCHAR2 (2) := NULL;
    ------------------------------

    -- Beginning of the procedure

    ------------------------------

    BEGIN
        BEGIN
            SELECT SYSDATE INTO v_sysdate FROM DUAL;

            fnd_file.put_line (fnd_file.LOG, 'System Date Is :' || v_sysdate);
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_File.put_line (
                    fnd_file.LOG,
                    'Others error Found While getting the sysdate');
                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Code :' || SQLCODE);
                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Message:' || SQLERRM);
        END;

        ------------------------------------

        -- Select query to get the user ID

        ------------------------------------

        BEGIN
            ---------------------

            -- User name = BATCH

            ---------------------

            SELECT user_id
              INTO v_user_id
              FROM apps.fnd_user
             WHERE UPPER (user_name) = 'BATCH';
        EXCEPTION
            ----------------------

            -- Exception Handler

            ----------------------

            WHEN NO_DATA_FOUND
            THEN
                v_user_id   := 0;

                fnd_file.put_line (fnd_file.LOG,
                                   'No Data Found While Getting The User ID');

                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Code :' || SQLCODE);

                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Message :' || SQLERRM);
            WHEN OTHERS
            THEN
                v_user_id   := 0;

                fnd_file.put_line (
                    fnd_file.LOG,
                    'Others Error Found While Getting The User ID');

                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Code :' || SQLCODE);

                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Message :' || SQLERRM);
        --------------------------------------------

        -- End of the block to retrive the USER ID

        --------------------------------------------

        END;

        ----------------------------------------------------------

        -- check to see if the reprocess flag is ON and if requested

        -- if requested then we shouldn't run the cursor instead

        -- update the staging table with the flag as N so that

        -- it will be picked up for processing

        ----------------------------------------------------------


        BEGIN
            IF v_delivery_name1 IS NOT NULL
            THEN
                p_miss_delivery   := 1;
            ELSE
                p_miss_delivery   := 2;
            END IF;
        END;

        IF (UPPER (v_reprocess_flag) = 'NO' OR UPPER (v_reprocess_flag) = 'N')
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Delivery Number :' || v_delivery_name1);

            ------------------------------------------------

            -- If the reprocess flag = N which means

            -- We need to take in the correct shipments

            -- and then send the XML data

            ------------------------------------------------

            FOR c_cur_main_shipment
                IN cur_main_shipment (v_delivery_name1, p_miss_delivery)
            LOOP
                fnd_file.put_line (fnd_file.LOG, 'INside the loop');

                ----------------------------------------------

                -- Sequence which is used to take in the

                -- next val and store in the table

                ----------------------------------------------

                BEGIN
                    ------------------------------------------

                    -- We need to get the nextval from dual

                    ------------------------------------------

                    SELECT xxdo_ship_int_seq.NEXTVAL INTO v_seq_num FROM DUAL;
                ----------------------

                -- Exception Handler

                ----------------------

                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        v_user_id   := 0;

                        fnd_file.put_line (
                            fnd_file.LOG,
                            'No Data Found While Getting The Sequence Number');

                        fnd_file.put_line (fnd_file.LOG,
                                           'SQL Error Code :' || SQLCODE);

                        fnd_file.put_line (fnd_file.LOG,
                                           'SQL Error Message :' || SQLERRM);
                    WHEN OTHERS
                    THEN
                        v_user_id   := 0;

                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Others Error While Getting The Sequence Number');

                        fnd_file.put_line (fnd_file.LOG,
                                           'SQL Error Code :' || SQLCODE);

                        fnd_file.put_line (fnd_file.LOG,
                                           'SQL Error Message :' || SQLERRM);
                --------------------------------------------

                -- End of the block to retrive the USER ID

                --------------------------------------------

                END;

                ----------------------------------------------------
                ---  100 Distro Doctype fetch
                ----------------------------------------------------

                IF c_cur_main_shipment.Distro_Doc_Type = 'O'
                THEN
                    l_Distro_Doc_Type   := NULL;
                    l_Distro_Number     := NULL;

                    BEGIN
                        SELECT (SUBSTR (ool.orig_sys_line_ref, INSTR (ool.orig_sys_line_ref, '-') + 1, 1)), (SUBSTR (ool.orig_sys_line_ref, 1, INSTR (ool.orig_sys_line_ref, '-') - 1))
                          INTO l_Distro_Doc_Type, l_Distro_Number
                          FROM oe_order_lines_all ool
                         WHERE line_id =
                               (SELECT MIN (line_id)
                                  FROM apps.oe_order_lines_all
                                 WHERE     header_id =
                                           c_cur_main_shipment.header_id
                                       AND LINE_NUMBER =
                                           c_cur_main_shipment.LINE_NUMBER); --added sub query  by naga

                        -- c_cur_main_shipment.SPLIT_FROM_LINE_ID ;


                        fnd_file.put_line (
                            fnd_file.LOG,
                            'l_Distro_Number  ' || l_Distro_Number);
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'c_cur_main_shipment.SPLIT_FROM_LINE_ID  '
                            || c_cur_main_shipment.SPLIT_FROM_LINE_ID);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_Distro_Doc_Type   := 'E';

                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Others Error While Getting The Distro_Doc_Type for  split line id '
                                || c_cur_main_shipment.SPLIT_FROM_LINE_ID);

                            fnd_file.put_line (fnd_file.LOG,
                                               'SQL Error Code :' || SQLCODE);

                            fnd_file.put_line (
                                fnd_file.LOG,
                                'SQL Error Message :' || SQLERRM);
                    END;
                ELSE
                    l_Distro_Doc_Type   := NULL;
                    l_Distro_Number     := NULL;
                    l_Distro_Doc_Type   :=
                        c_cur_main_shipment.Distro_Doc_Type;
                    l_Distro_Number     := c_cur_main_shipment.Distro_Number;
                END IF;

                ---------------------------------------------------
                ----- End Distro type fetch  ---
                -----------------------------------------------------

                -- added by naga
                IF v_delivery_name1 IS NOT NULL
                THEN
                    lv_count   := 0;
                ELSE
                    BEGIN
                        lv_count   := NULL;

                        SELECT COUNT (*)
                          INTO lv_count
                          FROM apps.xxdo_007_ship_int_stg
                         WHERE     delivery_id =
                                   c_cur_main_shipment.delivery_id -- 148737242
                               AND ITEM_ID = c_cur_main_shipment.item_id --3282817;
                               AND LPN_ID = c_cur_main_shipment.Container_ID
                               AND order_number =
                                   c_cur_main_shipment.Distro_Number;
                    --    and status ='N'

                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_count   := 2;
                    END;
                END IF;

                -------------------------------------------

                -- Insert into xxdo_007_ship_int_stg

                -------------------------------------------

                IF lv_count = 0
                THEN                             -- if condition added by naga
                    BEGIN
                        INSERT INTO xxdo_007_ship_int_stg (
                                        seq_number,
                                        to_location_id,
                                        from_location_id,
                                        bol_nbr,
                                        shipment_date,
                                        container_qty,
                                        ship_to_address1,
                                        ship_to_address2,
                                        ship_to_address3,
                                        ship_to_address4,
                                        city,
                                        state,
                                        post_code,
                                        country,
                                        order_number,
                                        distro_doc_type,
                                        trailer_nbr,
                                        carrier_node,
                                        net_weight,
                                        weight_uom_code,
                                        cust_order_nbr,
                                        lpn_id,
                                        item_ID,
                                        shipped_qty,
                                        ordered_qty,
                                        net_qty,
                                        line_number,
                                        order_source,
                                        delivery_id,
                                        delivery_name,
                                        virtual_warehouse,
                                        status,
                                        processing_message,
                                        created_by,
                                        creation_date,
                                        last_update_by,
                                        last_update_date,
                                        container_name)
                                 VALUES (
                                            v_seq_num,
                                            c_cur_main_shipment.To_Location_ID,
                                            c_cur_main_shipment.From_Location_ID,
                                            c_cur_main_shipment.BOL_NBR,
                                            c_cur_main_shipment.Shipment_Date,
                                            c_cur_main_shipment.Container_Qty,
                                            c_cur_main_shipment.Ship_To_Address1,
                                            c_cur_main_shipment.Ship_To_Address2,
                                            c_cur_main_shipment.Ship_To_Address3,
                                            c_cur_main_shipment.Ship_To_Address4,
                                            c_cur_main_shipment.Ship_To_City,
                                            SUBSTR (
                                                c_cur_main_shipment.Ship_To_State,
                                                1,
                                                3),
                                            c_cur_main_shipment.Ship_To_Zip,
                                            c_cur_main_shipment.Ship_To_Country,
                                            l_Distro_Number,
                                            ---  c_cur_main_shipment.Distro_Number        ,

                                            l_Distro_Doc_Type, ---- 200 Added for Distro Doc Type issue
                                            ---- c_cur_main_shipment.Distro_Doc_Type      ,

                                            c_cur_main_shipment.Trailer_NBR,
                                            SUBSTR (
                                                c_cur_main_shipment.Carrier_Node,
                                                1,
                                                4),
                                            c_cur_main_shipment.Net_Weight,
                                            c_cur_main_shipment.Weight_UOM_Code,
                                            c_cur_main_shipment.Customer_Order_Nbr,
                                            c_cur_main_shipment.Container_ID,
                                            c_cur_main_shipment.Item_ID,
                                            c_cur_main_shipment.Shipped_Quantity,
                                            c_cur_main_shipment.Ordered_Quantity,
                                            c_cur_main_shipment.Net_Quantity,
                                            c_cur_main_shipment.Line_Number,
                                            c_cur_main_shipment.Order_Source,
                                            c_cur_main_shipment.delivery_id,
                                            c_cur_main_shipment.delivery_name,
                                            c_cur_main_shipment.Virtual_Warehouse,
                                            'N',
                                            NULL,
                                            v_user_id,
                                            SYSDATE,
                                            v_user_id,
                                            SYSDATE,
                                            DECODE (
                                                c_cur_main_shipment.wms_enabled_flag,
                                                'Y', LPAD (
                                                         CAST (
                                                             apps.do_wms_interface.fix_container (
                                                                 c_cur_main_shipment.container_name)
                                                                 AS VARCHAR2 (20)),
                                                         20,
                                                         '0'),
                                                c_cur_main_shipment.container_name));
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Others Error While Inserting The Data Into The Staging Table');

                            fnd_file.put_line (fnd_file.LOG,
                                               'SQL Error Code :' || SQLCODE);

                            fnd_file.put_line (
                                fnd_file.LOG,
                                'SQL Error Message :' || SQLERRM);
                    END;
                END IF;

                ---------------------------------------------------------------------------------

                -- In the case of partial shipment such as ordered quantity <> shipped quantity

                -- we need to send a INT-009 status message to RMS and this can be obtained

                -- by cross check the ordered quantity - shipped quantity and there by getting

                -- the net quantity

                ---------------------------------------------------------------------------------

                IF (c_cur_main_shipment.Ordered_Quantity - c_cur_main_shipment.Ordered_Quantity) >
                   0
                THEN
                    /*xxdo_int_009_prc(lv_errbuf
                                   ,lv_retcode
                                   ,c_cur_main_shipment.To_Location_ID
                                   ,c_cur_main_shipment.Distro_Number
                                   ,c_cur_main_shipment.Distro_Doc_Type
                                   ,c_cur_main_shipment.Distro_Number
                                   ,c_cur_main_shipment.To_Location_ID
                                   ,c_cur_main_shipment.Item_ID
                                   ,c_cur_main_shipment.Line_Number
                                   ,c_cur_main_shipment.Ordered_Quantity - c_cur_main_shipment.Ordered_Quantity
                                   ,'NI');*/
                    NULL;
                ELSE
                    -- do nothing

                    NULL;
                END IF;
            END LOOP;

            COMMIT;
        END IF;

        -----------------------------------------------------

        -- If the process flag is Y which means the user is

        -- requesting for reprocessing and therefore

        -- we need to update the staging tables with the

        -- status as N for the values where the status is VE

        -- and for the dates

        -----------------------------------------------------

        IF (UPPER (v_reprocess_flag) = 'YES' OR UPPER (v_reprocess_flag) = 'Y')
        THEN
            BEGIN
                --------------------------------------

                -- Update the staging table

                --------------------------------------

                UPDATE xxdo_007_ship_int_stg
                   SET status = 'N', processed_flag = NULL, last_update_by = v_user_id
                 WHERE     status = 'VE'
                       AND last_update_date >=
                           TRUNC (
                               TO_DATE (v_reprocess_from_date,
                                        'YYYY/MM/DD HH24:MI:SS'))
                       AND last_update_date <=
                           TRUNC (
                               TO_DATE (v_reprocess_to_date,
                                        'YYYY/MM/DD HH24:MI:SS'));
            --------------------

            -- Exception Handler

            --------------------

            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'No Data Found While Updating The Table : xxdo_007_ship_int_stg');

                    fnd_file.put_line (fnd_file.LOG,
                                       'SQL Error Code:' || SQLCODE);

                    fnd_file.put_line (fnd_file.LOG,
                                       'SQL Error Message :' || SQLERRM);
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'No Data Found While Updating The Table : xxdo_007_ship_int_stg');

                    fnd_file.put_line (fnd_file.LOG,
                                       'SQL Error Code:' || SQLCODE);

                    fnd_file.put_line (fnd_file.LOG,
                                       'SQL Error Message :' || SQLERRM);
            END;
        END IF;

        --------------------------------------------------------------

        -- Calling the procedure which will send the messages to RIB

        --------------------------------------------------------------

        xxdo_int_007_processing_msgs (v_sysdate, p_deliver_number);
    -----------------------------------

    -- End of calling the procedure

    -----------------------------------

    END;


    PROCEDURE xxdo_int_007_main_prc_new (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_deliver_number IN VARCHAR2
                                         , p_reprocess_flag IN VARCHAR2, p_reprocess_from IN VARCHAR2, p_reprocess_to IN VARCHAR2)
    IS
        --------------------------------------------------------

        -- Cursor cur_main_shipment which is used to pull out

        -- the values and fetch the location ID, BOL_NBR,

        -- and all other sales order and shipment information

        -- for which we need to work on

        -- modified the cursor cur_main_shipment to sum up the order line item quantity by line,container_id  (CCR0002708)
        --------------------------------------------------------

        CURSOR cur_main_shipment (p_delivery_number   IN VARCHAR2,
                                  p_miss_delivery     IN VARCHAR2)
        IS
              --    SELECT   to_location_id, from_location_id, bol_nbr, shipment_date,
              --         container_qty, ship_to_address1, ship_to_address2, ship_to_address3,
              --         ship_to_address4, ship_to_city, ship_to_state, ship_to_zip,
              --         ship_to_country, distro_number, distro_doc_type, trailer_nbr,
              --         carrier_node, SUM (net_weight) net_weight, weight_uom_code,
              --         customer_order_nbr, container_name, container_id, item_id,
              --         SUM (shipped_quantity) shipped_quantity,
              --         SUM (ordered_quantity) ordered_quantity,
              --         SUM (net_quantity) net_quantity, line_number, split_from_line_id,
              --         order_source, delivery_id, delivery_name, virtual_warehouse,
              --         header_id, wms_enabled_flag              -- Added by Naga DFCT0010535
              --    FROM (SELECT drs.rms_store_id to_location_id, oola.line_id,
              --                 oola.ship_from_org_id from_location_id,
              --                 SUBSTR (NVL (wnd.waybill,
              --                              NVL (DECODE (dess.pro_number,
              --                                           NULL, dess.tracking_number,
              --                                           dess.pro_number
              --                                          ),
              --                                   wdd.tracking_number
              --                                  )
              --                             ),
              --                         1,
              --                         17
              --                        ) bol_nbr,
              --                    TO_CHAR (TRUNC (oola.actual_shipment_date),
              --                             'YYYY-MM-DD'
              --                            )
              --                 || 'T'
              --                 || TO_CHAR (oola.actual_shipment_date, 'HH:MI:SS')
              --                                                                shipment_date,
              --                 NVL (wnd.number_of_lpn, 0) container_qty,
              --                 hzl.address1 ship_to_address1, hzl.address2 ship_to_address2,
              --                 hzl.address3 ship_to_address3, hzl.address4 ship_to_address4,
              --                 hzl.city ship_to_city, hzl.state ship_to_state,
              --                 hzl.postal_code ship_to_zip,
              --                 fnt.territory_code ship_to_country,
              --                 (SUBSTR (oola.orig_sys_line_ref,
              --                          1,
              --                          INSTR (oola.orig_sys_line_ref, '-') - 1
              --                         )
              --                 ) distro_number,
              --                 (SUBSTR (oola.orig_sys_line_ref,
              --                          INSTR (oola.orig_sys_line_ref, '-') + 1,
              --                          1
              --                         )
              --                 ) distro_doc_type,
              --                 DECODE (dess.pro_number,
              --                         NULL, dess.tracking_number,
              --                         dess.pro_number
              --                        ) trailer_nbr,
              --                 wnd.ship_method_code carrier_node, wdd.net_weight net_weight,
              --                 wdd.weight_uom_code weight_uom_code,
              --                 ooh.cust_po_number customer_order_nbr,
              --                 NVL
              --                    (apps.lpnid_to_lpn
              --                                     ((SELECT wdd1.lpn_id
              --                                         FROM apps.wsh_delivery_details wdd1,
              --                                              apps.wsh_delivery_assignments wda
              --                                        WHERE wda.delivery_detail_id =
              --                                                        wdd.delivery_detail_id
              --                                          AND wda.parent_delivery_detail_id =
              --                                                       wdd1.delivery_detail_id)
              --                                     ),
              --                     0
              --                    ) container_name,
              --                 (SELECT wdd1.lpn_id
              --                    FROM apps.wsh_delivery_details wdd1,
              --                         apps.wsh_delivery_assignments wda
              --                   WHERE wda.delivery_detail_id = wdd.delivery_detail_id
              --                     AND wda.parent_delivery_detail_id =
              --                                                       wdd1.delivery_detail_id)
              --                                                                 container_id,
              --                 oola.inventory_item_id item_id,
              --                 wdd.shipped_quantity shipped_quantity,
              --                 wdd.requested_quantity ordered_quantity,
              --                 wdd.requested_quantity - wdd.shipped_quantity net_quantity,
              --                 oola.line_number line_number, oola.split_from_line_id,
              --                 oos.NAME order_source, wnd.delivery_id delivery_id,
              --                 wnd.NAME delivery_name, xst2.dc_vw_id virtual_warehouse,
              --                 -- xerm.virtual_warehouse Virtual_Warehouse,
              --                 oola.header_id, mp.wms_enabled_flag, oola.line_id
              --            FROM (SELECT NVL (MAX (last_run_date_time - 1 / 1440),
              --                              SYSDATE - 1000
              --                             ) dte
              --                    FROM xxdo.xxdo_inv_itm_mvmt_table
              --                   WHERE integration_code = 'INT_007') dte
              --                                                          -- added -1 to insure data comes back
              --          ,
              --                   apps.mtl_material_transactions mmt,
              --                 apps.oe_order_lines_all oola,
              --                 apps.wsh_delivery_details wdd,
              --                 apps.wsh_delivery_assignments wda,
              --                 xxdo.xxdo_inv_int_026_stg2 xst2,
              --                 apps.wsh_new_deliveries wnd,
              --                 xxdo_ebs_rms_vw_map xerm,
              --                 apps.oe_order_headers_all ooh,
              --                 apps.oe_order_sources oos,
              --                 apps.mtl_parameters mp,
              --                 do_edi856_shipments dess,
              --                 apps.wsh_lookups wsl,
              --                 apps.hz_cust_site_uses_all hcsu,
              --                 apps.hz_cust_acct_sites_all hcasa,
              --                 apps.hz_party_sites hzps,
              --                 apps.hz_locations hzl,
              --                 apps.fnd_territories_tl fnt,
              --                 do_retail.stores@datamart.deckers.com drs
              --           WHERE 1 = 1
              --                   and mmt.transaction_type_id = 33                      -- Sales order Issues
              --              AND oola.line_id = mmt.trx_source_line_id
              --                                                      -- order lines that match shipments
              --             AND wdd.delivery_detail_id=mmt.picking_line_Id /* added on 07/10/2013 Defect :DFCT0010677 and CCR# :CCR0003240 */
              --             AND UPPER (oola.flow_status_code) <> 'CANCELLED'
              --             AND xst2.status = 1
              --             AND xst2.distro_number =
              --                    SUBSTR
              --                        (oola.orig_sys_line_ref,
              --                         1,
              --                         INSTR (oola.orig_sys_line_ref, '-') - 1
              --                        )                               -- match distro number
              ----  --           AND xst2.xml_id =
              ----                    SUBSTR (oola.orig_sys_line_ref,
              ----                            INSTR (oola.orig_sys_line_ref, '-', -1) + 1
              ----                           )                                   -- match xml_id
              --             AND oola.orig_sys_document_ref LIKE
              --                       'RMS'
              --                    || '-'
              --                    || xst2.dest_id
              --                    || '-'
              --                    || xst2.dc_dest_id
              --                    || '-%'                    -- match dest_id and dc_dest_id
              --             AND wdd.source_code = 'OE'
              --             AND wdd.source_line_id = oola.line_id
              --             AND wda.delivery_detail_id = wdd.delivery_detail_id
              --             AND (   (    p_deliver_number IS NULL
              --                      AND mmt.transaction_date  >= dte.dte
              --                     )
              --                  OR (    p_deliver_number IS NOT NULL
              --                      AND wda.delivery_id = TO_NUMBER (p_deliver_number)
              --                     )
              --                 )
              --             AND wda.delivery_id = wnd.delivery_id
              --             AND xerm.channel = 'OUTLET'
              --             AND xerm.ORGANIZATION = oola.ship_from_org_id
              --             AND ooh.header_id = oola.header_id
              --             AND ooh.order_source_id = oos.order_source_id
              --             AND ooh.org_id = xerm.org_id
              --             AND mp.organization_id = oola.ship_from_org_id
              --             AND oos.NAME = 'Retail'
              --             AND wdd.source_header_id = ooh.header_id
              --             AND wdd.source_line_id = oola.line_id
              --             AND wnd.delivery_id = dess.shipment_id(+)
              --             AND wnd.status_code = 'CL'
              --             AND wnd.asn_status_code is NULL    /*added on 10/11/2013*/
              --             AND wdd.released_status = 'C'
              --             AND wsl.lookup_code = wdd.released_status
              --             AND wsl.lookup_type = 'PICK_STATUS'
              --             AND wsl.meaning = 'Shipped'
              --             AND hcsu.site_use_id(+) = oola.ship_to_org_id
              --             AND hcasa.cust_acct_site_id(+) = hcsu.cust_acct_site_id
              --             AND hzps.party_site_id(+) = hcasa.party_site_id
              --             AND hzl.location_id(+) = hzps.location_id
              --             AND fnt.territory_code = hzl.country
              --             AND fnt.LANGUAGE = 'US'
              --             AND drs.ra_customer_id * 1 = ooh.sold_to_org_id
              --             )
              --GROUP BY to_location_id,
              --         from_location_id,
              --         bol_nbr,
              --         shipment_date,
              --         container_qty,
              --         ship_to_address1,
              --         ship_to_address2,
              --         ship_to_address3,
              --         ship_to_address4,
              --         ship_to_city,
              --         ship_to_state,
              --         ship_to_zip,
              --         ship_to_country,
              --         distro_number,
              --         distro_doc_type,
              --         trailer_nbr,
              --         carrier_node,
              --         weight_uom_code,
              --         customer_order_nbr,
              --         container_name,
              --         container_id,
              --         item_id,
              --         line_number,
              --         split_from_line_id,
              --         order_source,
              --         delivery_id,
              --         delivery_name,
              --         virtual_warehouse,
              --         header_id,
              --         wms_enabled_flag
              --UNION
              SELECT to_location_id, from_location_id, bol_nbr,
                     shipment_date, container_qty, ship_to_address1,
                     ship_to_address2, ship_to_address3, ship_to_address4,
                     ship_to_city, ship_to_state, ship_to_zip,
                     ship_to_country, distro_number, distro_doc_type,
                     trailer_nbr, carrier_node, -- SUM (unit_cost) unit_cost, Commented on 3/13 for Current production change
                                                unit_cost,
                     SUM (net_weight) net_weight, weight_uom_code, customer_order_nbr,
                     container_name, container_id, item_id,
                     SUM (shipped_quantity) shipped_quantity, SUM (ordered_quantity) ordered_quantity, SUM (net_quantity) net_quantity,
                     line_number, split_from_line_id, order_source,
                     delivery_id, delivery_name, virtual_warehouse,
                     header_id, wms_enabled_flag
                FROM (SELECT --Start modification by BT Technogy Team on 22-Jul-2014,  v2.0
                                          --  drs.rms_store_id To_Location_ID,
                            flv.attribute6 To_Location_ID,
                            --End modification by BT Technogy Team on 22-Jul-2014,  v2.0
                            md.from_location_id,
                            SUBSTR (
                                NVL (
                                    md.waybill,
                                    NVL (
                                        DECODE (dess.pro_number,
                                                NULL, dess.tracking_number,
                                                dess.pro_number),
                                        md.tracking_number)),
                                1,
                                17) bol_nbr,
                            md.shipment_date,
                            md.container_qty,
                            hzl.address1 ship_to_address1,
                            hzl.address2 ship_to_address2,
                            hzl.address3 ship_to_address3,
                            hzl.address4 ship_to_address4,
                            hzl.city ship_to_city,
                            hzl.state ship_to_state,
                            hzl.postal_code ship_to_zip,
                            fnt.territory_code ship_to_country,
                            md.distro_number,
                            md.distro_doc_type,
                            DECODE (dess.pro_number,
                                    NULL, dess.tracking_number,
                                    dess.pro_number) trailer_nbr,
                            md.carrier_node,
                            md.unit_cost,
                            md.net_weight net_weight,
                            md.weight_uom_code,
                            md.customer_order_nbr,
                            NVL (apps.lpnid_to_lpn (
                                     (SELECT wdd1.lpn_id
                                        FROM apps.wsh_delivery_details wdd1, apps.wsh_delivery_assignments wda
                                       WHERE     wda.delivery_detail_id =
                                                 md.delivery_detail_id
                                             AND wda.parent_delivery_detail_id =
                                                 wdd1.delivery_detail_id)),
                                 0) container_name,
                            (SELECT wdd1.lpn_id
                               FROM apps.wsh_delivery_details wdd1, apps.wsh_delivery_assignments wda
                              WHERE     wda.delivery_detail_id =
                                        md.delivery_detail_id
                                    AND wda.parent_delivery_detail_id =
                                        wdd1.delivery_detail_id) container_id,
                            md.item_id,
                            md.shipped_quantity shipped_quantity,
                            md.ordered_quantity ordered_quantity,
                            md.net_quantity net_quantity,
                            md.line_number,
                            md.split_from_line_id,
                            md.order_source,
                            md.delivery_id,
                            md.delivery_name,
                            xst2.dc_vw_id virtual_warehouse,
                            md.header_id,
                            md.wms_enabled_flag   -- Added by Naga DFCT0010535
                       FROM (SELECT   --ool.ship_from_org_id from_location_id,
                                    --Start modification by BT Technogy Team on 22-Jul-2014,  v2.0
                                    /*(SELECT lookup_code
                                       FROM fnd_lookup_values
                                      WHERE     lookup_type =
                                                   'XXD_1206_INV_ORG_MAPPING'
                                            AND attribute1 =
                                                   (SELECT organization_code
                                                      FROM org_organization_definitions
                                                     WHERE organization_id =
                                                              ool.ship_from_org_id)
                                            AND language = USERENV ('LANG')
                                            AND ROWNUM = 1)*/
                                    --Start of modification  BT Technogy Team on 03-jun-15  v2.1
                                    (SELECT DECODE (attribute1,  'US3', 152,  'US1', 1092,  'US2', 132,  'EU4', 334,  'HK1', 872,  'JP5', 892,  'CH3', 932,  lookup_code) org_id
                                       FROM fnd_lookup_values
                                      WHERE     lookup_type =
                                                'XXD_1206_INV_ORG_MAPPING'
                                            AND attribute1 =
                                                (SELECT organization_code
                                                   FROM org_organization_definitions
                                                  WHERE organization_id =
                                                        ool.ship_from_org_id)
                                            AND language = USERENV ('LANG')
                                            AND ROWNUM = 1)
                                        from_location_id,
                                    --End of changes by BT Technogy Team on 03-jun-15  v2.1
                                    --End modification by BT Technogy Team on 22-Jul-2014,  v2.0
                                    wdd.tracking_number,
                                    ool.actual_shipment_date,
                                    wnd.waybill,
                                    wdd.delivery_detail_id,
                                       TO_CHAR (
                                           TRUNC (
                                               NVL (ool.actual_shipment_date,
                                                    wnd.CONFIRM_DATE)),
                                           'YYYY-MM-DD')
                                    || 'T'
                                    || TO_CHAR (
                                           NVL (ool.actual_shipment_date,
                                                wnd.CONFIRM_DATE),
                                           'HH:MI:SS')
                                        shipment_date,
                                    NVL (wnd.number_of_lpn, 0)
                                        container_qty,
                                    (SUBSTR (ool.orig_sys_line_ref, 1, INSTR (ool.orig_sys_line_ref, '-') - 1))
                                        distro_number,
                                    (SUBSTR (ool.orig_sys_line_ref, INSTR (ool.orig_sys_line_ref, '-') + 1, 1))
                                        distro_doc_type,
                                    wnd.ship_method_code
                                        carrier_node,
                                    ool.unit_selling_price
                                        unit_cost,
                                    wdd.net_weight
                                        net_weight,
                                    wdd.weight_uom_code
                                        weight_uom_code,
                                    ooh.cust_po_number
                                        customer_order_nbr,
                                    ool.inventory_item_id
                                        item_id,
                                    wdd.shipped_quantity
                                        shipped_quantity,
                                    wdd.requested_quantity
                                        ordered_quantity,
                                      wdd.requested_quantity
                                    - wdd.shipped_quantity
                                        net_quantity,
                                    ool.line_number
                                        line_number,
                                    ool.split_from_line_id,
                                    --oos.NAME order_source, --Commented for change 4.0(Performance Fix)
                                    ooh.NAME
                                        order_source, --Added for change 4.0(Performance Fix)
                                    wnd.delivery_id
                                        delivery_id,
                                    wnd.NAME
                                        delivery_name,
                                    ool.header_id,
                                    mp.wms_enabled_flag,
                                    ool.line_id,
                                    ool.orig_sys_line_ref,
                                    ool.orig_sys_document_ref,
                                    ool.ship_from_org_id,
                                    ooh.org_id,
                                    wdd.released_status,
                                    ool.ship_to_org_id,
                                    ooh.sold_to_org_id
                               FROM --apps.oe_order_headers_all ooh, --Commented for change 4.0
                                    (SELECT src.name, h.*
                                       FROM apps.oe_order_sources src, apps.oe_order_headers_all h
                                      WHERE     1 = 1
                                            AND src.name = 'Retail'
                                            AND src.order_source_id =
                                                h.order_source_id
                                            AND h.request_date >
                                                (SYSDATE - gn_asn_publish_days))
                                    ooh, --Added for change 4.0(Performance Fix)
                                    apps.wsh_new_deliveries wnd,
                                    --apps.oe_order_sources oos, --Commented for change 4.0(Performance Fix)
                                    apps.wsh_delivery_assignments wda,
                                    apps.wsh_delivery_details wdd,
                                    apps.oe_order_lines_all ool,
                                    apps.mtl_parameters mp
                              WHERE     1 = 1
                                    -- AND ooh.header_id = wnd.source_header_id
                                    --AND oos.name = 'Retail' --Commented for change 4.0 (Performance Fix)
                                    --                        AND ooh.order_source_id = oos.order_source_id --Commented for change 4.0(Performance Fix)
                                    AND wnd.delivery_id = wda.delivery_id
                                    AND wnd.status_code = 'CL'
                                    -- AND wnd.ASN_STATUS_CODE is NULL
                                    AND wda.delivery_detail_id =
                                        wdd.delivery_detail_id
                                    AND wdd.source_header_id = ooh.header_id
                                    AND wdd.released_status = 'C'
                                    AND wdd.source_code = 'OE'
                                    --AND wda.DELIVERY_ID=nvl(p_delivery_number,wda.DELIVERY_ID)
                                    AND (p_delivery_number IS NULL OR wda.delivery_id = TO_NUMBER (p_delivery_number))
                                    -- AND ooh.ORDER_NUMBER in (8503828,8504016)
                                    AND ool.header_id = ooh.header_id
                                    AND ool.line_id = wdd.source_line_id
                                    --AND ool.order_source_id = oos.order_source_id  --Commented for change 4.0(Performance Fix)
                                    AND mp.organization_id =
                                        ool.ship_from_org_id
                                    --  AND ooh.order_number in ('8503828' ,'8504016' )
                                    --AND ool.LINE_ID=57182349
                                    -- AND TO_DATE (TRUNC (nvl(ool.actual_shipment_date,sysdate))) >=
                                    --         TRUNC (SYSDATE - 45)
                                    --to_date('09/01/2012','MM/DD/RRRR')
                                    AND (OOL.ACTUAL_SHIPMENT_DATE >= TRUNC (SYSDATE - 45) OR OOL.ACTUAL_SHIPMENT_DATE IS NULL)
                                    AND NOT EXISTS
                                            (SELECT 1
                                               FROM apps.xxdo_007_ship_int_stg
                                              WHERE delivery_id =
                                                    wnd.delivery_id)
                                    -- Start modification 12/03/15
                                    AND NOT EXISTS
                                            (SELECT NULL
                                               FROM wsh_delivery_assignments wda1, wsh_delivery_details wdd1, oe_order_lines_all oola1
                                              WHERE     wda1.delivery_id =
                                                        wnd.delivery_id
                                                    AND wdd1.delivery_detail_id =
                                                        wda1.delivery_detail_id
                                                    AND wdd1.source_code = 'OE'
                                                    AND oola1.line_id =
                                                        wdd1.source_line_id
                                                    AND oola1.flow_status_code !=
                                                        'CLOSED') --End modification 12/03/15
                                                                 ) md,
                            xxdo_inv_int_026_stg2 xst2,
                            xxdo_ebs_rms_vw_map xerm,
                            do_edi856_shipments dess,
                            -- apps.wsh_lookups               wsl ,
                            apps.hz_cust_site_uses_all hcsu,
                            apps.hz_cust_acct_sites_all hcasa,
                            apps.hz_party_sites hzps,
                            apps.hz_locations hzl,
                            apps.fnd_territories_tl fnt,
                            --Start modification by BT Technogy Team on 22-Jul-2014,  v2.0
                            fnd_lookup_values flv
                      --               do_retail.stores@datamart.deckers.com     drs
                      --End modification by BT Technogy Team on 22-Jul-2014,  v2.0
                      WHERE     xst2.status = 1
                            AND xst2.distro_number =
                                xxdo_get_distro_no (md.line_id)
                            AND xst2.xml_id = xxdo_get_xml_id (md.line_id)
                            AND xst2.seq_no = xxdo_get_seq_no (md.line_id) --CCR0007197 Changes
                            -- match xml_id
                            AND md.orig_sys_document_ref LIKE
                                       'RMS'
                                    || '-'
                                    || xst2.dest_id
                                    || '-'
                                    || xst2.dc_dest_id
                                    || '-%'                   -- match dest_id
                            -- Start modification by BT Team on 27-May
                            --                          AND xerm.channel = 'OUTLET'
                            -- End modification by BT Team on 27-May
                            AND xerm.ORGANIZATION = md.ship_from_org_id
                            AND xst2.dc_vw_id = xerm.VIRTUAL_WAREHOUSE
                            AND md.org_id = xerm.org_id
                            AND md.delivery_id = dess.shipment_id(+)
                            AND hcsu.site_use_id(+) = md.ship_to_org_id
                            AND hcasa.cust_acct_site_id(+) =
                                hcsu.cust_acct_site_id
                            AND hzps.party_site_id(+) = hcasa.party_site_id
                            AND hzl.location_id(+) = hzps.location_id
                            AND fnt.territory_code = hzl.country
                            AND fnt.LANGUAGE = 'US'
                            --Start modification by BT Technogy Team on 22-Jul-2014,  v2.0
                            --   AND drs.ra_customer_id * 1 = ooh.sold_to_org_id)
                            AND flv.lookup_type = 'XXD_RETAIL_STORES'
                            AND flv.enabled_flag = 'Y'
                            AND flv.language = USERENV ('LANG')
                            AND TRUNC (NVL (flv.start_date_active, SYSDATE)) <=
                                TRUNC (SYSDATE)
                            AND TRUNC (NVL (flv.end_date_active, SYSDATE)) >=
                                TRUNC (SYSDATE)
                            AND flv.attribute1 * 1 = md.sold_to_org_id)
            --                          AND drs.ra_customer_id * 1 = md.sold_to_org_id --  AND 1 = NVL (p_miss_delivery, 1)
            --End modification by BT Technogy Team on 22-Jul-2014,  v2.0
            GROUP BY to_location_id, from_location_id, bol_nbr,
                     shipment_date, container_qty, ship_to_address1,
                     ship_to_address2, ship_to_address3, ship_to_address4,
                     ship_to_city, ship_to_state, ship_to_zip,
                     ship_to_country, distro_number, distro_doc_type,
                     trailer_nbr, carrier_node, unit_cost, -- Added on 3/13 as part of current production change
                     weight_uom_code, customer_order_nbr, container_name,
                     container_id, item_id, line_number,
                     split_from_line_id, order_source, delivery_id,
                     delivery_name, virtual_warehouse, header_id,
                     wms_enabled_flag;

        ----------------------

        -- Declaring Variables

        ----------------------

        v_reprocess_flag        VARCHAR2 (10) := p_reprocess_flag;
        v_reprocess_from_date   VARCHAR2 (100) := p_reprocess_from;
        v_reprocess_to_date     VARCHAR2 (100) := p_reprocess_to;
        v_location_id           NUMBER := 0;
        v_from_location_id      NUMBER := 0;
        v_bol_nbr               VARCHAR2 (100) := NULL;
        v_shipment_date         VARCHAR2 (100) := NULL;
        v_container_qty         NUMBER := 0;
        v_ship_to_address1      VARCHAR2 (100) := NULL;
        v_ship_to_address2      VARCHAR2 (100) := NULL;
        v_ship_to_address3      VARCHAR2 (100) := NULL;
        v_ship_to_address4      VARCHAR2 (100) := NULL;
        v_city                  VARCHAR2 (100) := NULL;
        v_state                 VARCHAR2 (100) := NULL;
        v_zip_code              NUMBER := 0;
        v_country               VARCHAR2 (100) := NULL;
        v_distro_number         VARCHAR2 (100) := NULL;
        v_disto_doc_type        VARCHAR2 (100) := NULL;
        v_trailer_nbr           VARCHAR2 (100) := NULL;
        v_carrier_node          VARCHAR2 (4) := NULL;
        v_net_weight            NUMBER := 0;
        v_weight_uom_code       VARCHAR2 (100) := NULL;
        v_cust_order_nbr        VARCHAR2 (100) := NULL;
        v_container_ID          VARCHAR2 (100) := NULL;
        v_item_id               NUMBER := 0;
        v_shipped_qty           NUMBER := 0;
        v_ordered_qty           NUMBER := 0;
        v_net_qty               NUMBER := 0;
        v_line_nbr              NUMBER := 0;
        v_order_source          VARCHAR2 (100) := NULL;
        v_delivery_id           NUMBER := 0;
        v_delivery_name         VARCHAR2 (100) := NULL;
        v_vw_id                 NUMBER := 0;
        v_seq_num               NUMBER := 0;
        v_user_id               NUMBER := 0;
        v_processed_flag        VARCHAR2 (200) := NULL;
        v_transmission_date     DATE := NULL;
        v_error_code            VARCHAR2 (240) := NULL;
        v_xmldata               CLOB := NULL;
        v_retval                CLOB := NULL;
        v_seq_no                NUMBER := 0;
        lc_return               CLOB;
        l_Distro_Doc_Type       VARCHAR2 (10);
        l_Distro_Number         VARCHAR2 (100) := NULL;
        buffer                  VARCHAR2 (32767);
        v_sysdate               DATE;
        lv_errbuf               VARCHAR2 (2000);
        lv_retcode              VARCHAR2 (2000);
        v_container_name        VARCHAR2 (200);
        v_delivery_name1        VARCHAR2 (200) := p_deliver_number;
        lv_count                NUMBER;
        p_miss_delivery         VARCHAR2 (2) := NULL;
    ------------------------------

    -- Beginning of the procedure

    ------------------------------

    BEGIN
        BEGIN
            SELECT SYSDATE INTO v_sysdate FROM DUAL;

            fnd_file.put_line (fnd_file.LOG, 'System Date Is :' || v_sysdate);
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_File.put_line (
                    fnd_file.LOG,
                    'Others error Found While getting the sysdate');
                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Code :' || SQLCODE);
                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Message:' || SQLERRM);
        END;

        ------------------------------------

        -- Select query to get the user ID

        ------------------------------------

        BEGIN
            ---------------------

            -- User name = BATCH

            ---------------------

            SELECT user_id
              INTO v_user_id
              FROM apps.fnd_user
             WHERE UPPER (user_name) = 'BATCH';
        EXCEPTION
            ----------------------

            -- Exception Handler

            ----------------------

            WHEN NO_DATA_FOUND
            THEN
                v_user_id   := 0;

                fnd_file.put_line (fnd_file.LOG,
                                   'No Data Found While Getting The User ID');

                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Code :' || SQLCODE);

                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Message :' || SQLERRM);
            WHEN OTHERS
            THEN
                v_user_id   := 0;

                fnd_file.put_line (
                    fnd_file.LOG,
                    'Others Error Found While Getting The User ID');

                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Code :' || SQLCODE);

                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Message :' || SQLERRM);
        --------------------------------------------

        -- End of the block to retrive the USER ID

        --------------------------------------------

        END;

        ----------------------------------------------------------

        -- check to see if the reprocess flag is ON and if requested

        -- if requested then we shouldn't run the cursor instead

        -- update the staging table with the flag as N so that

        -- it will be picked up for processing

        ----------------------------------------------------------


        --        BEGIN
        --        IF v_delivery_name1 IS NOT NULL
        --         THEN
        --            p_miss_delivery := 1;
        --        ELSE
        --            p_miss_delivery := 2;
        --         END IF;
        --        END;

        IF (UPPER (v_reprocess_flag) = 'NO' OR UPPER (v_reprocess_flag) = 'N')
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Delivery Number :' || v_delivery_name1);

            ------------------------------------------------

            -- If the reprocess flag = N which means

            -- We need to take in the correct shipments

            -- and then send the XML data

            ------------------------------------------------

            FOR c_cur_main_shipment
                IN cur_main_shipment (v_delivery_name1, p_miss_delivery)
            LOOP
                fnd_file.put_line (fnd_file.LOG, 'INside the loop');

                ----------------------------------------------

                -- Sequence which is used to take in the

                -- next val and store in the table

                ----------------------------------------------

                BEGIN
                    ------------------------------------------

                    -- We need to get the nextval from dual

                    ------------------------------------------

                    SELECT xxdo_ship_int_seq.NEXTVAL INTO v_seq_num FROM DUAL;
                ----------------------

                -- Exception Handler

                ----------------------

                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        v_user_id   := 0;

                        fnd_file.put_line (
                            fnd_file.LOG,
                            'No Data Found While Getting The Sequence Number');

                        fnd_file.put_line (fnd_file.LOG,
                                           'SQL Error Code :' || SQLCODE);

                        fnd_file.put_line (fnd_file.LOG,
                                           'SQL Error Message :' || SQLERRM);
                    WHEN OTHERS
                    THEN
                        v_user_id   := 0;

                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Others Error While Getting The Sequence Number');

                        fnd_file.put_line (fnd_file.LOG,
                                           'SQL Error Code :' || SQLCODE);

                        fnd_file.put_line (fnd_file.LOG,
                                           'SQL Error Message :' || SQLERRM);
                --------------------------------------------

                -- End of the block to retrive the USER ID

                --------------------------------------------

                END;

                ----------------------------------------------------
                ---  100 Distro Doctype fetch
                ----------------------------------------------------

                IF c_cur_main_shipment.Distro_Doc_Type = 'O'
                THEN
                    l_Distro_Doc_Type   := NULL;
                    l_Distro_Number     := NULL;

                    BEGIN
                        SELECT (SUBSTR (ool.orig_sys_line_ref, INSTR (ool.orig_sys_line_ref, '-') + 1, 1)), (SUBSTR (ool.orig_sys_line_ref, 1, INSTR (ool.orig_sys_line_ref, '-') - 1))
                          INTO l_Distro_Doc_Type, l_Distro_Number
                          FROM oe_order_lines_all ool
                         WHERE line_id =
                               (SELECT MIN (line_id)
                                  FROM apps.oe_order_lines_all
                                 WHERE     header_id =
                                           c_cur_main_shipment.header_id
                                       AND LINE_NUMBER =
                                           c_cur_main_shipment.LINE_NUMBER); --added sub query  by naga

                        -- c_cur_main_shipment.SPLIT_FROM_LINE_ID ;


                        fnd_file.put_line (
                            fnd_file.LOG,
                            'l_Distro_Number  ' || l_Distro_Number);
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'c_cur_main_shipment.SPLIT_FROM_LINE_ID  '
                            || c_cur_main_shipment.SPLIT_FROM_LINE_ID);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_Distro_Doc_Type   := 'E';

                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Others Error While Getting The Distro_Doc_Type for  split line id '
                                || c_cur_main_shipment.SPLIT_FROM_LINE_ID);

                            fnd_file.put_line (fnd_file.LOG,
                                               'SQL Error Code :' || SQLCODE);

                            fnd_file.put_line (
                                fnd_file.LOG,
                                'SQL Error Message :' || SQLERRM);
                    END;
                ELSE
                    l_Distro_Doc_Type   := NULL;
                    l_Distro_Number     := NULL;
                    l_Distro_Doc_Type   :=
                        c_cur_main_shipment.Distro_Doc_Type;
                    l_Distro_Number     := c_cur_main_shipment.Distro_Number;
                END IF;

                ---------------------------------------------------
                ----- End Distro type fetch  ---
                -----------------------------------------------------

                -- added by naga
                IF v_delivery_name1 IS NOT NULL
                THEN
                    lv_count   := 0;
                ELSE
                    BEGIN
                        lv_count   := NULL;

                        SELECT COUNT (*)
                          INTO lv_count
                          FROM apps.xxdo_007_ship_int_stg
                         WHERE     delivery_id =
                                   c_cur_main_shipment.delivery_id -- 148737242
                               AND ITEM_ID = c_cur_main_shipment.item_id --3282817;
                               AND LPN_ID = c_cur_main_shipment.Container_ID
                               AND order_number =
                                   c_cur_main_shipment.Distro_Number;
                    --    and status ='N'

                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_count   := 2;
                    END;
                END IF;

                -------------------------------------------

                -- Insert into xxdo_007_ship_int_stg

                -------------------------------------------

                IF lv_count = 0
                THEN                             -- if condition added by naga
                    BEGIN
                        INSERT INTO xxdo_007_ship_int_stg (
                                        seq_number,
                                        to_location_id,
                                        from_location_id,
                                        bol_nbr,
                                        shipment_date,
                                        container_qty,
                                        ship_to_address1,
                                        ship_to_address2,
                                        ship_to_address3,
                                        ship_to_address4,
                                        city,
                                        state,
                                        post_code,
                                        country,
                                        order_number,
                                        distro_doc_type,
                                        trailer_nbr,
                                        carrier_node,
                                        unit_cost,
                                        net_weight,
                                        weight_uom_code,
                                        cust_order_nbr,
                                        lpn_id,
                                        item_ID,
                                        shipped_qty,
                                        ordered_qty,
                                        net_qty,
                                        line_number,
                                        order_source,
                                        delivery_id,
                                        delivery_name,
                                        virtual_warehouse,
                                        status,
                                        processing_message,
                                        created_by,
                                        creation_date,
                                        last_update_by,
                                        last_update_date,
                                        container_name)
                                 VALUES (
                                            v_seq_num,
                                            c_cur_main_shipment.To_Location_ID,
                                            c_cur_main_shipment.From_Location_ID,
                                            c_cur_main_shipment.BOL_NBR,
                                            c_cur_main_shipment.Shipment_Date,
                                            c_cur_main_shipment.Container_Qty,
                                            c_cur_main_shipment.Ship_To_Address1,
                                            c_cur_main_shipment.Ship_To_Address2,
                                            c_cur_main_shipment.Ship_To_Address3,
                                            c_cur_main_shipment.Ship_To_Address4,
                                            c_cur_main_shipment.Ship_To_City,
                                            SUBSTR (
                                                c_cur_main_shipment.Ship_To_State,
                                                1,
                                                3),
                                            c_cur_main_shipment.Ship_To_Zip,
                                            c_cur_main_shipment.Ship_To_Country,
                                            l_Distro_Number,
                                            ---  c_cur_main_shipment.Distro_Number        ,

                                            l_Distro_Doc_Type, ---- 200 Added for Distro Doc Type issue
                                            ---- c_cur_main_shipment.Distro_Doc_Type      ,

                                            c_cur_main_shipment.Trailer_NBR,
                                            SUBSTR (
                                                c_cur_main_shipment.Carrier_Node,
                                                1,
                                                4),
                                            c_cur_main_shipment.unit_cost,
                                            --c_cur_main_shipment.Net_Weight, --Commented by Infosys for 3.1
                                            NVL (
                                                c_cur_main_shipment.Net_Weight,
                                                0.01), --Added by Infosys for 3.1
                                            c_cur_main_shipment.Weight_UOM_Code,
                                            c_cur_main_shipment.Customer_Order_Nbr,
                                            c_cur_main_shipment.Container_ID,
                                            c_cur_main_shipment.Item_ID,
                                            c_cur_main_shipment.Shipped_Quantity,
                                            c_cur_main_shipment.Ordered_Quantity,
                                            c_cur_main_shipment.Net_Quantity,
                                            c_cur_main_shipment.Line_Number,
                                            c_cur_main_shipment.Order_Source,
                                            c_cur_main_shipment.delivery_id,
                                            c_cur_main_shipment.delivery_name,
                                            c_cur_main_shipment.Virtual_Warehouse,
                                            'N',
                                            NULL,
                                            v_user_id,
                                            SYSDATE,
                                            v_user_id,
                                            SYSDATE,
                                            DECODE (
                                                c_cur_main_shipment.wms_enabled_flag,
                                                'Y', LPAD (
                                                         CAST (
                                                             apps.do_wms_interface.fix_container (
                                                                 c_cur_main_shipment.container_name)
                                                                 AS VARCHAR2 (20)),
                                                         20,
                                                         '0'),
                                                -- c_cur_main_shipment.container_name -- Commented by Infosys for 3.1
                                                SUBSTR (
                                                    c_cur_main_shipment.container_name,
                                                    1,
                                                    20) -- Added by Infosys for 3.1
                                                       ));
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Others Error While Inserting The Data Into The Staging Table');

                            fnd_file.put_line (fnd_file.LOG,
                                               'SQL Error Code :' || SQLCODE);

                            fnd_file.put_line (
                                fnd_file.LOG,
                                'SQL Error Message :' || SQLERRM);
                    END;
                END IF;

                ---------------------------------------------------------------------------------

                -- In the case of partial shipment such as ordered quantity <> shipped quantity

                -- we need to send a INT-009 status message to RMS and this can be obtained

                -- by cross check the ordered quantity - shipped quantity and there by getting

                -- the net quantity

                ---------------------------------------------------------------------------------

                IF (c_cur_main_shipment.Ordered_Quantity - c_cur_main_shipment.Ordered_Quantity) >
                   0
                THEN
                    /*xxdo_int_009_prc(lv_errbuf
                                   ,lv_retcode
                                   ,c_cur_main_shipment.To_Location_ID
                                   ,c_cur_main_shipment.Distro_Number
                                   ,c_cur_main_shipment.Distro_Doc_Type
                                   ,c_cur_main_shipment.Distro_Number
                                   ,c_cur_main_shipment.To_Location_ID
                                   ,c_cur_main_shipment.Item_ID
                                   ,c_cur_main_shipment.Line_Number
                                   ,c_cur_main_shipment.Ordered_Quantity - c_cur_main_shipment.Ordered_Quantity
                                   ,'NI');*/
                    NULL;
                ELSE
                    -- do nothing

                    NULL;
                END IF;
            END LOOP;

            COMMIT;
        END IF;

        -----------------------------------------------------

        -- If the process flag is Y which means the user is

        -- requesting for reprocessing and therefore

        -- we need to update the staging tables with the

        -- status as N for the values where the status is VE

        -- and for the dates

        -----------------------------------------------------

        IF (UPPER (v_reprocess_flag) = 'YES' OR UPPER (v_reprocess_flag) = 'Y')
        THEN
            BEGIN
                --------------------------------------

                -- Update the staging table

                --------------------------------------

                UPDATE xxdo_007_ship_int_stg
                   SET status = 'N', processed_flag = NULL, last_update_by = v_user_id
                 WHERE     status = 'VE'
                       AND last_update_date >=
                           TRUNC (
                               TO_DATE (v_reprocess_from_date,
                                        'YYYY/MM/DD HH24:MI:SS'))
                       AND last_update_date <=
                           TRUNC (
                               TO_DATE (v_reprocess_to_date,
                                        'YYYY/MM/DD HH24:MI:SS'));
            --------------------

            -- Exception Handler

            --------------------

            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'No Data Found While Updating The Table : xxdo_007_ship_int_stg');

                    fnd_file.put_line (fnd_file.LOG,
                                       'SQL Error Code:' || SQLCODE);

                    fnd_file.put_line (fnd_file.LOG,
                                       'SQL Error Message :' || SQLERRM);
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'No Data Found While Updating The Table : xxdo_007_ship_int_stg');

                    fnd_file.put_line (fnd_file.LOG,
                                       'SQL Error Code:' || SQLCODE);

                    fnd_file.put_line (fnd_file.LOG,
                                       'SQL Error Message :' || SQLERRM);
            END;
        END IF;

        --------------------------------------------------------------

        -- Calling the procedure which will send the messages to RIB

        --------------------------------------------------------------

        fnd_file.put_line (fnd_file.LOG,
                           'Calling xxdo_int_007_processing_msgs');

        xxdo_int_007_processing_msgs (v_sysdate, p_deliver_number);
    -----------------------------------

    -- End of calling the procedure

    -----------------------------------

    END;

    -------------------------------------------------------

    -- Procedure xxdo_int_007_processing_msgs

    -- This procedure will pick up all the records for which

    -- the staging table records are N for which the status = VE

    -- and there by calling the WSDL and sending the data to

    -- RIB via WSDL

    -------------------------------------------------------

    PROCEDURE xxdo_int_007_processing_msgs (p_sysdate          IN DATE,
                                            p_deliver_number   IN VARCHAR2)
    IS
        v_sysdate             DATE := p_sysdate;

        -------------------------------------------

        -- Cursor cur_int_007_p_message which will

        -- the records for which the the status = N

        -- send the message to WSDL

        -------------------------------------------

        CURSOR cur_int_007_p_message IS
              /*select (Select (XMLELEMENT ("v13:ASNOutDesc",

                              XMLELEMENT ("v13:schedule_nbr",null),

                              XMLELEMENT ("v13:auto_receive",null),

                              XMLELEMENT ("v13:to_location",To_Location_ID),

                              XMLELEMENT ("v13:from_location",From_Location_ID),

                              XMLELEMENT ("v13:asn_nbr",delivery_name),

                              XMLELEMENT ("v13:asn_type",null),

                              XMLELEMENT ("v13:container_qty",Container_Qty),

                              XMLELEMENT ("v13:bol_nbr",bol_nbr),

                              XMLELEMENT ("v13:shipment_date",Shipment_Date),

                              XMLELEMENT ("v13:est_arr_date",null),

                              XMLELEMENT ("v13:ship_address1",Ship_To_Address1),

                              XMLELEMENT ("v13:ship_address2",Ship_To_Address2),

                              XMLELEMENT ("v13:ship_address3",Ship_To_Address3),

                              XMLELEMENT ("v13:ship_address4",Ship_To_Address4),

                              XMLELEMENT ("v13:ship_address5",null),

                              XMLELEMENT ("v13:ship_city",city),

                              XMLELEMENT ("v13:ship_state",state),

                              XMLELEMENT ("v13:ship_zip",postal_code),

                              XMLELEMENT ("v13:ship_country_id",country),

                              XMLELEMENT ("v13:trailer_nbr",Trailer_NBR),

                              XMLELEMENT ("v13:seal_nbr",null),

                              XMLELEMENT ("v13:carrier_code",Carrier_Node),

                              XMLELEMENT ("v13:transshipment_nbr",null),

                                 XMLELEMENT("v13:ASNOutDistro",

                                    XMLELEMENT ("v13:distro_nbr",order_number),

                                    XMLELEMENT ("v13:distro_doc_type",Distro_Doc_Type),

                                    XMLELEMENT ("v13:customer_order_nbr",order_number),

                                    XMLELEMENT ("v13:consumer_direct",null),

                                      XMLELEMENT ("v13:ASNOutCtn",

                                         XMLELEMENT ("v13:final_location",null),

                                         XMLELEMENT ("v13:container_id",Container_ID),

                                         XMLELEMENT ("v13:container_weight",null),

                                         XMLELEMENT ("v13:container_length",null),

                                         XMLELEMENT ("v13:container_width",null),

                                         XMLELEMENT ("v13:container_height",null),

                                         XMLELEMENT ("v13:container_cube",null),

                                         XMLELEMENT ("v13:expedite_flag",null),

                                         XMLELEMENT ("v13:in_store_date",null),

                                         XMLELEMENT ("v13:rma_nbr",null),

                                         XMLELEMENT ("v13:tracking_nbr",null),

                                         XMLELEMENT ("v13:freight_charge",null),

                                         XMLELEMENT ("v13:master_container_id",null),

                                            (select xmlagg(XMLELEMENT ("v13:ASNOutItem",

                                               XMLELEMENT ("v13:item_id",Item_ID),

                                               XMLELEMENT ("v13:unit_qty",Shipped_qty),

                                               XMLELEMENT ("v13:gross_cost",null),

                                               XMLELEMENT ("v13:priority_level",null),

                                               XMLELEMENT ("v13:order_line_nbr",null),

                                               XMLELEMENT ("v13:lot_nbr",null),

                                               XMLELEMENT ("v13:final_location",null),

                                               XMLELEMENT ("v13:from_disposition",null),

                                               XMLELEMENT ("v13:to_disposition",null),

                                               XMLELEMENT ("v13:voucher_number",null),

                                               XMLELEMENT ("v13:voucher_expiration_date",null),

                                               XMLELEMENT ("v13:container_qty",Container_Qty),

                                               XMLELEMENT ("v13:comments",null),

                                               XMLELEMENT ("v13:base_cost",null),

                                               XMLELEMENT ("v13:weight",Net_Weight),

                                               XMLELEMENT ("v13:weight_uom",Weight_UOM_Code)

                                                )

                                                           )

                                                          -- )

                                                           from xxdo_007_ship_int_stg xxdo

                                                           where xxdo.delivery_name =xx007.delivery_name

                                                     )

                                                  -- ) -- v13:ASNOutItem

                                                ) -- v13:ASNOutCtn

                                             ) -- v13:ASNOutDistr

                                         ) -- ASNOUTDESC

                                      ) XML

                          from dual) ship_xml,

                          seq_number seq_no,

                          delivery_name delivery_name,

                          From_Location_ID from_location_id,

                          to_location_id to_location_id

                          from xxdo_007_ship_int_stg xx007

                          where status = 'N'

                          and processed_flag is null

                          ;*/
              SELECT (XMLELEMENT (
                          "v13:ASNOutDesc",
                          XMLELEMENT ("v13:schedule_nbr", NULL),
                          XMLELEMENT ("v13:auto_receive", NULL),
                          XMLELEMENT ("v13:asn_type", NULL),
                          XMLELEMENT ("v13:est_arr_date", NULL),
                          XMLELEMENT ("v13:ship_address5", NULL),
                          XMLELEMENT ("v13:seal_nbr", NULL),
                          XMLELEMENT ("v13:transshipment_nbr", NULL),
                          XMLELEMENT ("v13:to_location", To_Location_ID),
                          XMLELEMENT ("v13:from_location", From_Location_ID),
                          XMLELEMENT ("v13:asn_nbr", delivery_name),
                          XMLELEMENT ("v13:container_qty", Container_Qty),
                          XMLELEMENT ("v13:bol_nbr", delivery_name),
                          XMLELEMENT ("v13:shipment_date", Shipment_Date),
                          XMLELEMENT ("v13:ship_address1", Ship_To_Address1),
                          XMLELEMENT ("v13:ship_address2", Ship_To_Address2),
                          XMLELEMENT ("v13:ship_address3", Ship_To_Address3),
                          XMLELEMENT ("v13:ship_address4", Ship_To_Address4),
                          XMLELEMENT ("v13:ship_city", city),
                          XMLELEMENT ("v13:ship_state", state),
                          XMLELEMENT ("v13:ship_zip", postal_code),
                          XMLELEMENT ("v13:ship_country_id", country),
                          XMLELEMENT ("v13:trailer_nbr", Trailer_NBR),
                          XMLELEMENT ("v13:carrier_code",
                                      TRIM (SUBSTR (Carrier_Node, 1, 4))),
                          XMLAGG (
                              XMLELEMENT (
                                  "v13:ASNOutDistro",
                                  XMLELEMENT ("v13:distro_nbr", order_number),
                                  XMLELEMENT ("v13:distro_doc_type",
                                              Distro_Doc_Type),
                                  XMLELEMENT ("v13:customer_order_nbr",
                                              order_number),
                                  XMLELEMENT ("v13:consumer_direct", NULL),
                                  XMLELEMENT (
                                      "v13:ASNOutCtn",
                                      XMLELEMENT ("v13:final_location", NULL),
                                      XMLELEMENT (
                                          "v13:container_id",
                                          SUBSTR (Container_name, 1, 20)), -- for version 3.1 added by Infosys team
                                      XMLELEMENT ("v13:container_weight", NULL),
                                      XMLELEMENT ("v13:container_length", NULL),
                                      XMLELEMENT ("v13:container_width", NULL),
                                      XMLELEMENT ("v13:container_height", NULL),
                                      XMLELEMENT ("v13:container_cube", NULL),
                                      XMLELEMENT ("v13:expedite_flag", NULL),
                                      XMLELEMENT ("v13:in_store_date", NULL),
                                      XMLELEMENT ("v13:rma_nbr", NULL),
                                      XMLELEMENT ("v13:tracking_nbr", NULL),
                                      XMLELEMENT ("v13:freight_charge", NULL),
                                      XMLELEMENT ("v13:master_container_id",
                                                  NULL),
                                      XMLELEMENT (
                                          "v13:ASNOutItem",
                                          XMLELEMENT ("v13:item_id", Item_ID),
                                          XMLELEMENT ("v13:unit_qty",
                                                      Shipped_qty),
                                          XMLELEMENT ("v13:gross_cost", NULL),
                                          XMLELEMENT ("v13:priority_level",
                                                      NULL),
                                          XMLELEMENT ("v13:order_line_nbr",
                                                      NULL),
                                          XMLELEMENT ("v13:lot_nbr", NULL),
                                          XMLELEMENT ("v13:final_location",
                                                      NULL),
                                          XMLELEMENT ("v13:from_disposition",
                                                      NULL),
                                          XMLELEMENT ("v13:to_disposition",
                                                      NULL),
                                          XMLELEMENT ("v13:voucher_number",
                                                      NULL),
                                          XMLELEMENT (
                                              "v13:voucher_expiration_date",
                                              NULL),
                                          XMLELEMENT ("v13:container_qty",
                                                      Container_Qty),
                                          XMLELEMENT ("v13:comments", NULL),
                                          XMLELEMENT ("v13:unit_cost",
                                                      unit_cost),
                                          XMLELEMENT ("v13:base_cost", NULL),
                                          XMLELEMENT ("v13:weight",
                                                      NVL (Net_Weight, 0.01)), -- for version 3.1 added by Infosys team
                                          XMLELEMENT ("v13:weight_uom",
                                                      Weight_UOM_Code)) -- v13:ASNOutItem
                                                                       ) -- v13:ASNOutCtn
                                                                        )) -- XMLAGG
                                                                          ) -- v13:ASNOutDistr
                                                                           --     ) -- ASNOUTDESC
                                                                           )
                         XML,
                     delivery_name
                         delivery_name,
                     From_Location_ID
                         from_location_id,
                     to_location_id
                         to_location_id
                FROM xxdo_007_ship_int_stg xx007
               WHERE status = 'N' AND processed_flag IS NULL
            GROUP BY To_Location_ID, From_Location_ID, Container_Qty,
                     delivery_name, Shipment_Date, Ship_To_Address1,
                     Ship_To_Address2, Ship_To_Address3, Ship_To_Address4,
                     city, state, postal_code,
                     country, Trailer_NBR, TRIM (SUBSTR (Carrier_Node, 1, 4)),
                     delivery_name, From_Location_ID, to_location_id;

        ----------------------

        -- Declaring Variables

        ----------------------

        v_processed_flag      VARCHAR2 (200) := NULL;
        v_transmission_date   DATE := NULL;
        v_error_code          VARCHAR2 (240) := NULL;
        --   v_xmldata                  clob             := null                          ;
        v_retval              CLOB := NULL;
        --   v_seq_no                   number           := 0                             ;
        lv_wsdl_ip            VARCHAR2 (25) := NULL;
        lv_wsdl_url           VARCHAR2 (4000) := NULL;
        lv_namespace          VARCHAR2 (4000) := NULL;
        lv_service            VARCHAR2 (4000) := NULL;
        lv_port               VARCHAR2 (4000) := NULL;
        lv_operation          VARCHAR2 (4000) := NULL;
        lv_targetname         VARCHAR2 (4000) := NULL;
        lx_xmltype_in         SYS.XMLTYPE;
        lx_xmltype_out        SYS.XMLTYPE;
        lc_return             CLOB;
        lv_errmsg             VARCHAR2 (240) := NULL;
        lv_from_loc_id        NUMBER := 0;
        lv_to_loc_id          NUMBER := 0;
        l_http_request        UTL_HTTP.req;
        l_http_response       UTL_HTTP.resp;
        l_buffer_size         NUMBER (10) := 512;
        l_line_size           NUMBER (10) := 50;
        l_lines_count         NUMBER (10) := 20;
        l_string_request      CLOB;
        l_line                VARCHAR2 (128);
        l_substring_msg       VARCHAR2 (512);
        l_raw_data            RAW (512);
        l_clob_response       CLOB;
        lv_ip                 VARCHAR2 (100);
        --   buffer                     varchar2(32767);
        httpData              CLOB;
        eof                   BOOLEAN;
        xml                   CLOB;
        env                   CLOB;
        --   resp                       clob;
        v_xmldata             CLOB := NULL;
        offset                PLS_INTEGER := 1;
        amount                PLS_INTEGER := 2000;
        buffer                VARCHAR2 (32767);
        v_length              BINARY_INTEGER;
    -------------------------

    -- Begin of the procedure

    -------------------------

    BEGIN
        fnd_file.put_line (fnd_file.output, 'The Records Transmitted To RMS');
        fnd_file.put_line (fnd_file.output,
                           '*******************************');

        ----------------------------------

        -- To get the profile values

        ----------------------------------

        /*       --Commented as part of 5.0 (start)

                BEGIN
                    SELECT DECODE (
                               APPLICATIONS_SYSTEM_NAME,
                               -- Start of modification by BT Technology Team on 17-Feb-2016 V2.0
                               --'PROD', APPS.FND_PROFILE.VALUE ('XXDO: RETAIL PROD'),
                               'EBSPROD', APPS.FND_PROFILE.VALUE (
                                              'XXDO: RETAIL PROD'),
                               -- End of modification by BT Technology Team on 17-Feb-2016 V2.0
                               'PCLN', APPS.FND_PROFILE.VALUE ('XXDO: RETAIL DEV'),
                               APPS.FND_PROFILE.VALUE ('XXDO: RETAIL TEST'))    FILE_SERVER_NAME
                      INTO lv_wsdl_ip
                      FROM APPS.FND_PRODUCT_GROUPS;
                -----------------------------

                -- Exception Handler

                -----------------------------

                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (apps.fnd_file.LOG,
                                           'Unable to fetch the File server name');
                END;

                ----------------------------------

                -- To get the IP Address and port

                ----------------------------------

                BEGIN
                    SELECT SUBSTR (lv_wsdl_ip, 1, INSTR (lv_wsdl_ip, ':') - 1),
                           SUBSTR (lv_wsdl_ip,
                                   INSTR (lv_wsdl_ip, ':') + 1,
                                   LENGTH (lv_wsdl_ip))
                      INTO lv_ip, lv_port
                      FROM DUAL;
                -----------------------------

                -- Exception Handler

                -----------------------------

                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (apps.fnd_file.LOG,
                                           'Unable to fetch the IP And Port');
                END;

                --------------------------------------------------------------

                -- Initializing the variables for calling the webservices

                -- The webservices takes the input parameter as wsd URL,

                -- name space, service, port, operation and target name

                --------------------------------------------------------------

                lv_wsdl_url :=
                       'http://'
                    || lv_wsdl_ip
                    || '//ASNOutPublishingBean/ASNOutPublishingService?WSDL';

                lv_namespace :=
                    'http://www.oracle.com/retail/igs/integration/services/ASNOutPublishingService/v1';

                lv_service := 'ASNOutPublishingService';

                lv_port := 'ASNOutPublishingPort';

                lv_operation := 'publishASNOutCreateUsingASNOutDesc';

                lv_targetname :=
                       'http://'
                    || lv_wsdl_ip
                    || '//ASNOutPublishingBean/ASNOutPublishingService';


            */
        --Commented as part of 5.0 (end)

        -----------------------------------------------------------------------------

        -- Begin loop to vary value of the cursor from 1 to cur_int_007_p_message

        -----------------------------------------------------------------------------

        FOR c_cur_int_007_p_message IN cur_int_007_p_message
        LOOP
            fnd_file.put_line (
                fnd_file.LOG,
                   'Inside  cur_int_007_p_message,  delivery '
                || c_cur_int_007_p_message.delivery_name);
            ----------------------------------------------
            -- Assigning variables to the cursor values
            ----------------------------------------------

            -- v_seq_no  := c_cur_int_007_p_message.seq_no                        ;

            --v_xmldata := xmltype.getclobval (c_cur_int_007_p_message.xml);      --Commented as part of 5.0
            --v_xmldata := XMLType.createXML(c_cur_int_007_p_message.xml)  ;

            lv_from_loc_id   := c_cur_int_007_p_message.from_location_id;
            lv_to_loc_id     := c_cur_int_007_p_message.to_location_id;

            ----------------------------
            -- Begin of the procedure
            ----------------------------

            --Commented as part of 5.0 (start)
            /*
                     BEGIN
                        ----------------------------------------------------------
                        -- Updating the staging table : xxdo_007_ship_int_stg
                        -- with the xmldata which was just retrived from the cursor
                        ----------------------------------------------------------

                      UPDATE xxdo_007_ship_int_stg
                           SET xmldata = v_xmldata
                         WHERE     delivery_name = c_cur_int_007_p_message.delivery_name
                               AND status = 'N'
                               AND processed_flag IS NULL                  --added by naga
                                                         --            and rownum <= 1

                        */

            --fnd_file.put_line(fnd_file.log,'Updated the XMLdata');
            -----------------------

            -- Exception Handler

            -----------------------
            /* --Commented as part of 5.0
                     EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                           UPDATE xxdo_007_ship_int_stg
                              SET status = 'VE', errorcode = 'Validation Error'
                            WHERE delivery_name = c_cur_int_007_p_message.delivery_name;

                           fnd_file.put_line (
                              fnd_file.LOG,
                              'No Data Found Error When Updating The Table xxdo_007_ship_int_stg');

                           fnd_file.put_line (fnd_file.LOG,
                                              'SQL Error Code :' || SQLCODE);

                           fnd_file.put_line (fnd_file.LOG,
                                              'SQL Error Message :' || SQLERRM);
                        WHEN OTHERS
                        THEN
                           UPDATE xxdo_007_ship_int_stg
                              SET status = 'VE', errorcode = 'Validation Error'
                            WHERE delivery_name = c_cur_int_007_p_message.delivery_name;

                           fnd_file.put_line (
                              fnd_file.LOG,
                              'Others Error Found When Updating The Table xxdo_007_ship_int_stg');

                           fnd_file.put_line (fnd_file.LOG,
                                              'SQL Error Code :' || SQLCODE);

                           fnd_file.put_line (fnd_file.LOG,
                                              'SQL Error Message :' || SQLERRM);
                     END;

                     -------------------------------------------------------------
                     -- Assigning the variables to call the webservices function
                     -------------------------------------------------------------

                     --fnd_file.put_line(fnd_file.log,v_xmldata);


                     BEGIN
                        l_string_request :=
                              '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:v1="http://www.oracle.com/retail/integration/bus/gateway/services/BusinessObjectId/v1" xmlns:v11="http://www.oracle.com/retail/integration/bus/gateway/services/RoutingInfos/v1" xmlns:v12="http://www.oracle.com/retail/igs/integration/services/ASNOutPublishingService/v1" xmlns:v13="http://www.oracle.com/retail/integration/base/bo/ASNOutDesc/v1" xmlns:v14="http://www.oracle.com/retail/integration/custom/bo/ExtOfASNOutDesc/v1"><soapenv:Header><v11:RoutingInfos><v11:routingInfo><name>from_phys_loc</name><value>'
                           || lv_from_loc_id
                           || '</value><v11:detail><v11:dtl_name>from_phys_loc_type</v11:dtl_name><v11:dtl_value>w</v11:dtl_value></v11:detail></v11:routingInfo><v11:routingInfo><name>to_phys_loc</name><value>'
                           || lv_to_loc_id
                           || '</value><v11:detail><v11:dtl_name>to_phys_loc_type</v11:dtl_name><v11:dtl_value>s</v11:dtl_value></v11:detail></v11:routingInfo><v11:routingInfo><name>facility_type</name>

            <value>PROD</value></v11:routingInfo></v11:RoutingInfos></soapenv:Header><soapenv:Body><v12:publishASNOutCreateUsingASNOutDesc>'
                           || v_xmldata
                           || '</v12:publishASNOutCreateUsingASNOutDesc></soapenv:Body></soapenv:Envelope>';
                     EXCEPTION
                        WHEN OTHERS
                        THEN
                           fnd_file.put_line (fnd_file.LOG, 'Error in string request');
                           fnd_file.put_line (fnd_file.LOG, 'SQL Error :' || SQLERRM);
                     END;
               */
            --Commented as part of 5.0 (end)


            fnd_file.put_line (
                fnd_file.LOG,
                   'Response is stored in the staging table  :'
                || c_cur_int_007_p_message.delivery_name);
            fnd_file.put_line (
                fnd_file.output,
                'Delivery/ASN Number :' || c_cur_int_007_p_message.delivery_name);


            --Added as part of 5.0
            BEGIN
                apps.wf_event.RAISE (p_event_name => 'oracle.apps.xxdo.retail_asn_event', p_event_key => c_cur_int_007_p_message.delivery_name, p_event_data => NULL
                                     , p_parameters => NULL);
            EXCEPTION
                WHEN OTHERS
                THEN
                    LV_ERRMSG   :=
                           'Error Message from event call :'
                        || apps.fnd_api.g_ret_sts_error
                        || ' SQL Error '
                        || SQLERRM;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error Message from event call :'
                        || apps.fnd_api.g_ret_sts_error
                        || ' SQL Error '
                        || SQLERRM);

                    BEGIN
                        UPDATE xxdo_007_ship_int_stg
                           SET retval = LV_ERRMSG, processed_flag = 'VE'
                         WHERE     delivery_name =
                                   c_cur_int_007_p_message.delivery_name
                               AND status = 'N'
                               AND processed_flag IS NULL      --added by naga
                                                         ;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (fnd_file.LOG,
                                               'Error here :' || SQLERRM);
                    END;
            END;

            COMMIT;
        --Added as part of 5.0
        ---------------------

        -----------------------------------------------

        -- Calling the web services using utl_http

        -----------------------------------------------
        /*  -- Commented as part of 5.0
 BEGIN

          ------------------------------------

          -- Calling the web services program

          ----------------------------------

          UTL_HTTP.set_transfer_timeout (60);

          ---------------------------------------------------------

          -- The utl_http program which is used to begin request

          ---------------------------------------------------------
          --fnd_file.put_line(fnd_file.log,'100 - Before calling the request');

          l_http_request :=
             UTL_HTTP.begin_request (url            => lv_wsdl_url,
                                     method         => 'POST',
                                     http_version   => 'HTTP/1.1');

          -------------------------

          -- Set header information

          -------------------------

          UTL_HTTP.set_header (l_http_request,
                               'User-Agent',
                               'Mozilla/4.0 (compatible)');

          UTL_HTTP.set_header (l_http_request,
                               'Content-Type',
                               'text/xml; charset=utf-8');

          UTL_HTTP.set_header (l_http_request, 'SOAPAction', '');
          v_length := DBMS_LOB.getlength (l_string_request);
          offset := 1;

          IF v_length <= 32767
          THEN
             UTL_HTTP.set_header (l_http_request,
                                  'Content-Length',
                                  LENGTH (l_string_request));

             UTL_HTTP.write_text (l_http_request, l_string_request);
          ELSIF v_length > 32767
          THEN
             UTL_HTTP.set_header (l_http_request,
                                  'Transfer-Encoding',
                                  'chunked');

             WHILE (offset < v_length)
             LOOP
                DBMS_LOB.read (l_string_request,
                               amount,
                               offset,
                               buffer);
                UTL_HTTP.write_text (l_http_request, buffer);
                offset := offset + amount;
             END LOOP;
          END IF;

          --fnd_file.put_line(fnd_file.log,'200 - After calling the request');

          ---------------------------------------

          -- Below command will get the response

          ---------------------------------------

          l_http_response := UTL_HTTP.get_response (l_http_request);

          ----------------------------------

          -- Reading the text

          ----------------------------------

          BEGIN
             UTL_HTTP.read_text (l_http_response, env);
          EXCEPTION
             WHEN UTL_HTTP.end_of_body
             THEN
                UTL_HTTP.end_response (l_http_response);
          END;

          ----------------------------------------------------

          -- If Env is null, which means response is null

          ----------------------------------------------------

          IF env IS NULL
          THEN
             fnd_file.put_line (
                fnd_file.LOG,
                'No Response :' || c_cur_int_007_p_message.delivery_name);
          END IF;

          -------------------------------------------------

          -- End the response

          -------------------------------------------------

          --          UTL_HTTP.end_response (l_http_response);

          --fnd_file.put_line(fnd_file.log,'ENV:'||env);

          --resp:=XMLType.createXML(env);

          -----------------------------

          -- If there is a response

          -----------------------------

          IF env IS NOT NULL
          THEN
             fnd_file.put_line (
                fnd_file.LOG,
                   'Response is stored in the staging table  :'
                || c_cur_int_007_p_message.delivery_name);
             fnd_file.put_line (
                fnd_file.output,
                   'Delivery/ASN Number :'
                || c_cur_int_007_p_message.delivery_name);

             ----------------------------

             -- Storing the return values

             ----------------------------

             --lc_return := xmltype.getClobVal(l_http_response);

             ------------------------------------------------------

             -- update the staging table : xxdo_inv_int_007

             ------------------------------------------------------

             BEGIN
                UPDATE xxdo_007_ship_int_stg
                   SET retval = env,
                       processed_flag = 'Y',
                       status = 'P',
                       transmission_date = SYSDATE
                 WHERE     delivery_name =
                              c_cur_int_007_p_message.delivery_name
                       AND status = 'N'
                       AND processed_flag IS NULL            --added by naga
                                                 ;
             EXCEPTION
                WHEN OTHERS
                THEN
                   fnd_file.put_line (fnd_file.LOG,
                                      'Error here :' || SQLERRM);
             END;
          ---------------------------------------------

          -- If there is no response from web services

          ---------------------------------------------

          ELSE
             FND_FILE.PUT_LINE (FND_FILE.OUTPUT, 'Response is NULL  ');

             lc_return := NULL;

             -------------------------------------------------

             -- Updating the staging table to set the processed

             -- flag = Validation Error and transmission date

             --  = sysdate for the sequence number
             -------------------------------------------------

             UPDATE xxdo_007_ship_int_stg
                SET retval = NULL,
                    processed_flag = 'VE',
                    transmission_date = SYSDATE
              WHERE delivery_name = c_cur_int_007_p_message.delivery_name;
          ---------------------------------
          -- Condition END IF
          ---------------------------------

          END IF;
       ---------------------
       -- Exception HAndler
       ---------------------

       EXCEPTION
          WHEN OTHERS
          THEN
             LV_ERRMSG := SQLERRM;

             --------------------------------

             -- Updating the staging table

             --------------------------------

             UPDATE xxdo_007_ship_int_stg
                SET STATUS = 'VE', ERRORCODE = LV_ERRMSG
              WHERE delivery_name = c_cur_int_007_p_message.delivery_name;

             FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                   'PROBLEM IN SENDING THE MESSAGE DETAILS STORED IN THE ERRORCODE OF THE STAGING TABLE   '
                || SQLERRM);
       END;


       UTL_HTTP.end_response (l_http_response);
 */
        -- -- Commented as part of 5.0
        END LOOP;

        -- if condition added by naga to restrict update for indivisual run

        IF p_deliver_number IS NULL
        THEN
            BEGIN
                UPDATE xxdo_inv_itm_mvmt_table
                   SET last_run_date_time   = v_sysdate
                 WHERE integration_code = 'INT_007';
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_File.put_line (
                        fnd_file.LOG,
                        'Others error Found While Updating the table');
                    fnd_file.put_line (fnd_file.LOG,
                                       'SQL Error Code :' || SQLCODE);
                    fnd_file.put_line (fnd_file.LOG,
                                       'SQL Error Message:' || SQLERRM);
            END;
        END IF;
    END;

    FUNCTION xxdo_Get_distro_no (v_line_id IN NUMBER)
        RETURN NUMBER
    IS
        V_HEADER_ID     NUMBER;
        V_LINE_NUM      NUMBER;
        V_COUNT         NUMBER;
        V_DISTOR_NUM    NUMBER;
        V_DISTOR_NUM1   NUMBER;
    BEGIN
        SELECT header_id, line_number
          INTO v_header_id, v_line_num
          FROM apps.oe_order_lines_all ola
         WHERE ola.line_id = v_line_id;

        SELECT COUNT (1)
          INTO v_count
          FROM apps.oe_order_lines_all
         WHERE header_id = v_header_id AND line_number = v_line_num;

        --Start modification by BT Technogy Team on 22-Jul-2014,  v2.0

        OPEN get_order_source_id_c;

        FETCH get_order_source_id_c INTO gn_order_source_id;

        IF get_order_source_id_c%NOTFOUND
        THEN
            gn_order_source_id   := NULL;

            fnd_file.put_line (fnd_file.LOG,
                               'Unable to derive Order source ID');
        END IF;

        IF get_order_source_id_c%ISOPEN
        THEN
            CLOSE get_order_source_id_c;
        END IF;

        --End modification by BT Technogy Team on 22-Jul-2014,  v2.0


        IF v_count > 1
        THEN
            BEGIN
                SELECT MIN (SUBSTR (a.orig_sys_line_ref, 1, INSTR (a.orig_sys_line_ref, '-') - 1))
                  INTO V_DISTOR_NUM
                  FROM apps.oe_order_lines_all a
                 WHERE     1 = 1
                       --Start modification by BT Technogy Team on 22-Jul-2014,  v2.0
                       --AND a.order_source_id = 1184
                       AND a.order_source_id = gn_order_source_id
                       --End modification by BT Technogy Team on 22-Jul-2014,  v2.0
                       AND a.LINE_SET_ID IN
                               (SELECT b.LINE_SET_ID
                                  FROM apps.oe_order_lines_all b
                                 WHERE     1 = 1 --Start modification by BT Technogy Team on 22-Jul-2014,  v2.0
                                       --AND b.order_source_id = 1184
                                       AND b.order_source_id =
                                           gn_order_source_id --End modification by BT Technogy Team on 22-Jul-2014,  v2.0
                                       AND b.line_id = v_line_id);

                RETURN V_DISTOR_NUM;
            EXCEPTION
                WHEN OTHERS
                THEN
                    RETURN NULL;
            END;
        ELSE
            BEGIN
                SELECT MIN (SUBSTR (a.orig_sys_line_ref, 1, INSTR (a.orig_sys_line_ref, '-') - 1))
                  INTO V_DISTOR_NUM1
                  FROM apps.oe_order_lines_all a
                 WHERE     1 = 1 --Start modification by BT Technogy Team on 22-Jul-2014,  v2.0
                       --AND a.order_source_id = 1184
                       AND a.order_source_id = gn_order_source_id --End modification by BT Technogy Team on 22-Jul-2014,  v2.0
                       AND a.line_id = v_line_id;

                RETURN V_DISTOR_NUM1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    RETURN NULL;
            END;
        END IF;
    END;

    FUNCTION xxdo_Get_xml_id (v_line_id NUMBER)
        RETURN NUMBER
    IS
        V_HEADER_ID   NUMBER;
        V_LINE_NUM    NUMBER;
        V_COUNT       NUMBER;
        V_XML_ID      NUMBER;
        V_XML_ID1     NUMBER;
    BEGIN
        SELECT header_id, line_number
          INTO v_header_id, v_line_num
          FROM apps.oe_order_lines_all ola
         WHERE ola.line_id = v_line_id;

        SELECT COUNT (1)
          INTO v_count
          FROM apps.oe_order_lines_all
         WHERE header_id = v_header_id AND line_number = v_line_num;

        --Start modification by BT Technogy Team on 22-Jul-2014,  v2.0

        OPEN get_order_source_id_c;

        FETCH get_order_source_id_c INTO gn_order_source_id;

        IF get_order_source_id_c%NOTFOUND
        THEN
            gn_order_source_id   := NULL;

            fnd_file.put_line (fnd_file.LOG,
                               'Unable to derive Order source ID');
        END IF;

        IF get_order_source_id_c%ISOPEN
        THEN
            CLOSE get_order_source_id_c;
        END IF;

        --End modification by BT Technogy Team on 22-Jul-2014,  v2.0

        IF v_count > 1
        THEN
            BEGIN
                SELECT MIN (SUBSTR (a.orig_sys_line_ref, INSTR (a.orig_sys_line_ref, '-', -1) + 1))
                  INTO V_XML_ID
                  FROM apps.oe_order_lines_all a
                 WHERE     1 = 1
                       --Start modification by BT Technogy Team on 22-Jul-2014,  v2.0
                       --AND a.order_source_id = 1184
                       AND a.order_source_id = gn_order_source_id
                       --End modification by BT Technogy Team on 22-Jul-2014,  v2.0
                       AND a.LINE_SET_ID IN
                               (SELECT b.LINE_SET_ID
                                  FROM apps.oe_order_lines_all b
                                 WHERE     1 = 1 --Start modification by BT Technogy Team on 22-Jul-2014,  v2.0
                                       --AND b.order_source_id = 1184
                                       AND b.order_source_id =
                                           gn_order_source_id --End modification by BT Technogy Team on 22-Jul-2014,  v2.0
                                       AND b.line_id = v_line_id);

                RETURN V_XML_ID;
            EXCEPTION
                WHEN OTHERS
                THEN
                    RETURN NULL;
            END;
        ELSE
            BEGIN
                SELECT MIN (SUBSTR (a.orig_sys_line_ref, INSTR (a.orig_sys_line_ref, '-', -1) + 1))
                  INTO V_XML_ID1
                  FROM apps.oe_order_lines_all a
                 WHERE     1 = 1 --Start modification by BT Technogy Team on 22-Jul-2014,  v2.0
                       --AND a.order_source_id = 1184
                       AND a.order_source_id = gn_order_source_id --End modification by BT Technogy Team on 22-Jul-2014,  v2.0
                       AND a.line_id = v_line_id;

                RETURN V_XML_ID1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    RETURN NULL;
            END;
        END IF;
    END;

    -- CCR0007197 Changes Start

    FUNCTION xxdo_Get_seq_no (v_line_id NUMBER)
        RETURN NUMBER
    IS
        V_HEADER_ID   NUMBER;
        V_LINE_NUM    NUMBER;
        V_COUNT       NUMBER;
        V_XML_ID      NUMBER;
        V_XML_ID1     NUMBER;
    BEGIN
        SELECT header_id, line_number
          INTO v_header_id, v_line_num
          FROM apps.oe_order_lines_all ola
         WHERE ola.line_id = v_line_id;

        SELECT COUNT (1)
          INTO v_count
          FROM apps.oe_order_lines_all
         WHERE header_id = v_header_id AND line_number = v_line_num;

        --Start modification by BT Technogy Team on 22-Jul-2014,  v2.0

        OPEN get_order_source_id_c;

        FETCH get_order_source_id_c INTO gn_order_source_id;

        IF get_order_source_id_c%NOTFOUND
        THEN
            gn_order_source_id   := NULL;

            fnd_file.put_line (fnd_file.LOG,
                               'Unable to derive Order source ID');
        END IF;

        IF get_order_source_id_c%ISOPEN
        THEN
            CLOSE get_order_source_id_c;
        END IF;

        --End modification by BT Technogy Team on 22-Jul-2014,  v2.0

        IF v_count > 1
        THEN
            BEGIN
                SELECT MIN (SUBSTR (a.orig_sys_line_ref,
                                      INSTR (a.orig_sys_line_ref, '-', 1,
                                             2)
                                    + 1,
                                      (  INSTR (a.orig_sys_line_ref, '-', 1,
                                                3)
                                       - INSTR (a.orig_sys_line_ref, '-', 1,
                                                2))
                                    - 1))
                  INTO V_XML_ID
                  FROM apps.oe_order_lines_all a
                 WHERE     1 = 1
                       --Start modification by BT Technogy Team on 22-Jul-2014,  v2.0
                       --AND a.order_source_id = 1184
                       AND a.order_source_id = gn_order_source_id
                       --End modification by BT Technogy Team on 22-Jul-2014,  v2.0
                       AND a.LINE_SET_ID IN
                               (SELECT b.LINE_SET_ID
                                  FROM apps.oe_order_lines_all b
                                 WHERE     1 = 1 --Start modification by BT Technogy Team on 22-Jul-2014,  v2.0
                                       --AND b.order_source_id = 1184
                                       AND b.order_source_id =
                                           gn_order_source_id --End modification by BT Technogy Team on 22-Jul-2014,  v2.0
                                       AND b.line_id = v_line_id);

                RETURN V_XML_ID;
            EXCEPTION
                WHEN OTHERS
                THEN
                    RETURN NULL;
            END;
        ELSE
            BEGIN
                SELECT MIN (SUBSTR (a.orig_sys_line_ref,
                                      INSTR (a.orig_sys_line_ref, '-', 1,
                                             2)
                                    + 1,
                                      (  INSTR (a.orig_sys_line_ref, '-', 1,
                                                3)
                                       - INSTR (a.orig_sys_line_ref, '-', 1,
                                                2))
                                    - 1))
                  INTO V_XML_ID1
                  FROM apps.oe_order_lines_all a
                 WHERE     1 = 1 --Start modification by BT Technogy Team on 22-Jul-2014,  v2.0
                       --AND a.order_source_id = 1184
                       AND a.order_source_id = gn_order_source_id --End modification by BT Technogy Team on 22-Jul-2014,  v2.0
                       AND a.line_id = v_line_id;

                RETURN V_XML_ID1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    RETURN NULL;
            END;
        END IF;
    END;
-- CCR0007197 Changes Ends

END XXDO_INT_007_PKG;
/
