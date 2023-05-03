--
-- XXDO_OM_INT_028_STG_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:30 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_OM_INT_028_STG_PKG"
IS
    /***************************************************************************************************************************************
     File Name    : xxdo_inv_int_008_atr_pkg.sql
     Created On   : 15-Feb-2012
     Created By   : < >
     Purpose      : Package Specification used for the following
                            1. to load the xml elements into xxdo_inv_int_026_stg2 table
                            2. To Insert the Parsed Records into Order Import Interface Tables
    ****************************************************************************************************************************************
    Modification History:
    Version     SCN#  By                Date          Comments
    1.0                                 05-Apr-2012   Initial Version
    ****************************************************************************************************************************************
    Parameters:
       1.1       100  C.M.Barath Kumar  10/21/2012    Return Reason Code changed to UNKNOWN
       1.2       200  Infosys           09/22/2014    BT Changes
       1.3            Infosys           04/17/2015    Modified to implement the Canada Virtual Warehouse change. Defect ID 958.
       1.4            Infosys           05/14/2015    To remove CHANNEL check in VW map.
       1.5            Infosys           15-Jul-2015   BT Improvements - Modified log messages.
       1.6            Infosys           25-Aug-2015   Modified to NOT populate Ship From Warehouse for defaulting rules to take care.
       1.7            Infosys           30-Sep-2015   Modified to rollback CR12 changes(Ver 1.6).
       2.0            Kranthi Bollam    29-Jun-2016   For CCR#CCR0005194 (Removed the dependency on the cross
                                                      reference table and inventory organization is derived based on to_location
                                                      Also restricted the zero quantity records)
    ***************************************************************************************************************************************/
    PROCEDURE load_xml_data (retcode OUT VARCHAR2, errbuf OUT VARCHAR2)
    AS
        /*Cursor to Parse XML Elements */
        CURSOR cur_xml_data IS
                         SELECT X28.ROWID, X28.xml_id, X281.*,
                                X282.*, x283.*
                           FROM XXDO.XXDO_INV_INT_028_STG1 X28,
                                XMLTABLE (
                                    '//ASNInDesc'
                                    PASSING X28.XML_TYPE_DATA
                                    COLUMNS to_location         VARCHAR2 (4000) PATH '/ASNInDesc/to_location', from_location       VARCHAR2 (4000) PATH '/ASNInDesc/from_location', asn_nbr             VARCHAR2 (4000) PATH '/ASNInDesc/asn_nbr',
                                            asn_type            VARCHAR2 (4000) PATH '/ASNInDesc/asn_type', h_container_qty     VARCHAR2 (4000) PATH '/ASNInDesc/container_qty', bol_nbr             VARCHAR2 (4000) PATH '/ASNInDesc/bol_nbr',
                                            shipment_date       VARCHAR2 (4000) PATH '/ASNInDesc/shipment_date', ship_address1       VARCHAR2 (4000) PATH '/ASNInDesc/ship_address1', ship_address2       VARCHAR2 (4000) PATH '/ASNInDesc/ship_address2',
                                            ship_address3       VARCHAR2 (4000) PATH '/ASNInDesc/ship_address3', ship_address4       VARCHAR2 (4000) PATH '/ASNInDesc/ship_address4', ship_address5       VARCHAR2 (4000) PATH '/ASNInDesc/ship_address5',
                                            ship_city           VARCHAR2 (4000) PATH '/ASNInDesc/ship_city', ship_state          VARCHAR2 (4000) PATH '/ASNInDesc/ship_state', ship_zip            VARCHAR2 (4000) PATH '/ASNInDesc/ship_zip',
                                            ship_country_id     VARCHAR2 (4000) PATH '/ASNInDesc/ship_country_id', trailer_nbr         VARCHAR2 (4000) PATH '/ASNInDesc/trailer_nbr', seal_nbr            VARCHAR2 (4000) PATH '/ASNInDesc/seal_nbr',
                                            carrier_code        VARCHAR2 (4000) PATH '/ASNInDesc/carrier_code', vendor_nbr          VARCHAR2 (4000) PATH '/ASNInDesc/vendor_nbr', po_nbr              VARCHAR2 (4000) PATH '/ASNInDesc/ASNInPO/po_nbr',
                                            doc_type            VARCHAR2 (4000) PATH '/ASNInDesc/ASNInPO/doc_type')
                                X281,
                                XMLTABLE (
                                    '//ASNInDesc/ASNInPO/ASNInCtn'
                                    PASSING X28.XML_TYPE_DATA
                                    COLUMNS container_id        VARCHAR2 (4000) PATH '/ASNInCtn/container_id', container_weight    VARCHAR2 (4000) PATH '/ASNInCtn/container_weight', container_length    VARCHAR2 (4000) PATH '/ASNInCtn/container_length',
                                            container_width     VARCHAR2 (4000) PATH '/ASNInCtn/container_width', container_height    VARCHAR2 (4000) PATH '/ASNInCtn/container_height', container_cube      VARCHAR2 (4000) PATH '/ASNInCtn/container_cube',
                                            expedite_flag       VARCHAR2 (4000) PATH '/ASNInCtn/expedite_flag', rma_nbr             VARCHAR2 (4000) PATH '/ASNInCtn/rma_nbr', tracking_nbr        VARCHAR2 (4000) PATH '/ASNInCtn/tracking_nbr',
                                            freight_charge      VARCHAR2 (4000) PATH '/ASNInCtn/freight_charge')
                                X283,
                                XMLTABLE (
                                    '//ASNInDesc/ASNInPO/ASNInCtn/ASNInItem'
                                    PASSING X28.XML_TYPE_DATA
                                    COLUMNS final_location      VARCHAR2 (4000) PATH '/ASNInItem/final_location', item_id             VARCHAR2 (4000) PATH '/ASNInItem/item_id', unit_qty            VARCHAR2 (4000) PATH '/ASNInItem/unit_qty',
                                            priority_level      VARCHAR2 (4000) PATH '/ASNInItem/priority_level', order_line_nbr      VARCHAR2 (4000) PATH '/ASNInItem/order_line_nbr', lot_nbr             VARCHAR2 (4000) PATH '/ASNInItem/lot_nbr',
                                            distro_nbr          VARCHAR2 (4000) PATH '/ASNInItem/distro_nbr', distro_doc_type     VARCHAR2 (4000) PATH '/ASNInItem/distro_doc_type', l_container_qty     VARCHAR2 (4000) PATH '/ASNInItem/container_qty')
                                X282
                          WHERE X28.STATUS = 0;

        lv_loop_counter   NUMBER := 0;
        lv_success        VARCHAR2 (1) := 'N';
        l_vw_id           NUMBER;
        l_num_org_id      NUMBER;                                       -- 1.2
        ln_ou_id          NUMBER;
    BEGIN
        BEGIN
            /*Update Statement to update the XML_TYPE_DATA column after removing namespace information from XML */
            UPDATE XXDO_INV_INT_028_STG1 X26
               SET XML_TYPE_DATA = XMLType (SUBSTR (XML_DATA, 1, INSTR (XML_DATA, 'xmlns', 1) - 2) || SUBSTR (XML_DATA, INSTR (XML_DATA, '">', 1) + 1))
             WHERE X26.STATUS = 0;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'No Data Found Error When Removing NameSpaces in XML Data');
                -- fnd_file.put_line(fnd_file.LOG,'SQL Error Code :'|| SQLCODE); -- Commented for 1.5.
                DBMS_OUTPUT.PUT_LINE (
                       'No Data Found Error When Removing NameSpaces in XML Data '
                    || SQLERRM);
                ROLLBACK;
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Error while Removing NameSpaces in XML Data.');
                --  fnd_file.put_line (fnd_file.LOG,'SQL Error Code :'|| SQLCODE); -- Commented for 1.5.
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error Code : '
                    || SQLCODE
                    || '. Error Message : '
                    || SQLERRM);                          -- Modified for 1.5.
                DBMS_OUTPUT.PUT_LINE (
                       'Error while Removing NameSpaces in XML Data :'
                    || SQLERRM);
                ROLLBACK;
                RETURN;
        END;

        FOR rec_xml_data IN cur_xml_data
        LOOP
            --Added if condition for change 2.0 to restrict zero qty records
            IF rec_xml_data.UNIT_QTY > 0
            THEN
                /*Loop Counter to display number of XML records parsed */
                lv_loop_counter   := lv_loop_counter + 1;

                l_vw_id           := 0;
                l_num_org_id      := 0;                                 -- 1.2
                ln_ou_id          := NULL;

                --Added the below code for Change 2.0--Start
                BEGIN
                    SELECT operating_unit
                      INTO ln_ou_id
                      FROM apps.xxd_retail_stores_v
                     WHERE rms_store_id = rec_xml_data.from_location;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_ou_id   := NULL;
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'Store does not exists in XXD_RETAIL_STORES lookup: ');
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'ASN Number: ' || rec_xml_data.asn_nbr);
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'Store ID: ' || rec_xml_data.from_location);
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'Inv Org ID: ' || rec_xml_data.to_location);
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'Item ID: ' || rec_xml_data.Item_id);
                    WHEN OTHERS
                    THEN
                        ln_ou_id   := NULL;
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'Others exception in load_xml_data_procedure while getting operating unit');
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'ASN Number: ' || rec_xml_data.asn_nbr);
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'Store ID: ' || rec_xml_data.from_location);
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'Inv Org ID: ' || rec_xml_data.to_location);
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'Item ID: ' || rec_xml_data.Item_id);
                        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                                'Exception is: ' || SQLERRM);
                END;

                BEGIN
                    SELECT ood.organization_id
                      INTO l_num_org_id
                      FROM apps.fnd_lookup_values flv, apps.org_organization_definitions ood
                     WHERE     flv.lookup_type = 'XXD_1206_INV_ORG_MAPPING'
                           AND flv.lookup_code = rec_xml_data.to_location
                           AND flv.attribute1 = ood.organization_code
                           AND flv.LANGUAGE = USERENV ('LANG');
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        l_num_org_id   := NULL;
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            '1206 and BT INV org mapping does not exists for below to_location in XXD_1206_INV_ORG_MAPPING lookup: ');
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'ASN Number: ' || rec_xml_data.asn_nbr);
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'Store ID: ' || rec_xml_data.from_location);
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'Inv Org ID: ' || rec_xml_data.to_location);
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'Item ID: ' || rec_xml_data.Item_id);
                    WHEN OTHERS
                    THEN
                        l_num_org_id   := NULL;
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'Others exception in load_xml_data_procedure while getting inv org id for below to_location');
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'ASN Number: ' || rec_xml_data.asn_nbr);
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'Store ID: ' || rec_xml_data.from_location);
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'Inv Org ID: ' || rec_xml_data.to_location);
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'Item ID: ' || rec_xml_data.Item_id);
                        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                                'Exception is: ' || SQLERRM);
                END;

                IF (ln_ou_id IS NOT NULL AND l_num_org_id IS NOT NULL)
                THEN
                    BEGIN
                        SELECT virtual_warehouse
                          INTO l_vw_id
                          FROM xxdo_ebs_rms_vw_map xervm
                         WHERE     1 = 1
                               AND xervm.organization = l_num_org_id
                               AND xervm.channel = 'CONCEPT'
                               AND xervm.org_id = ln_ou_id;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            l_vw_id   := 0;
                            apps.fnd_file.put_line (
                                apps.fnd_file.LOG,
                                'No Data found Exception in load_xml_data_procedure while getting virtual warehouse');
                            apps.fnd_file.put_line (
                                apps.fnd_file.LOG,
                                'ASN Number: ' || rec_xml_data.asn_nbr);
                            apps.fnd_file.put_line (
                                apps.fnd_file.LOG,
                                'Store ID: ' || rec_xml_data.from_location);
                            apps.fnd_file.put_line (
                                apps.fnd_file.LOG,
                                'Inv Org ID: ' || rec_xml_data.to_location);
                            apps.fnd_file.put_line (
                                apps.fnd_file.LOG,
                                'Item ID: ' || rec_xml_data.Item_id);
                        WHEN OTHERS
                        THEN
                            l_vw_id   := 0;
                            apps.fnd_file.put_line (
                                apps.fnd_file.LOG,
                                'Others exception in load_xml_data_procedure while getting virtual warehouse');
                            apps.fnd_file.put_line (
                                apps.fnd_file.LOG,
                                'ASN Number: ' || rec_xml_data.asn_nbr);
                            apps.fnd_file.put_line (
                                apps.fnd_file.LOG,
                                'Store ID: ' || rec_xml_data.from_location);
                            apps.fnd_file.put_line (
                                apps.fnd_file.LOG,
                                'Inv Org ID: ' || rec_xml_data.to_location);
                            apps.fnd_file.put_line (
                                apps.fnd_file.LOG,
                                'Item ID: ' || rec_xml_data.Item_id);
                            apps.fnd_file.put_line (
                                apps.fnd_file.LOG,
                                'Exception is: ' || SQLERRM);
                    END;
                END IF;

                --Change 2.0 --End

                --Code commented for change 2.0 --START
                --Removed the cross ref table to derive virtual warehouse
                /*
                begin
                    select VIRTUAL_WAREHOUSE into l_vw_id
                      from xxdo_vw_store_crs_ref_tbl
                     where rms_store_id =rec_xml_data.FROM_LOCATION;
                exception
                    when others then
                        fnd_file.put_line (fnd_file.LOG, 'Error while fetching virtual warehouse from XXDO_VW_STORE_CRS_REF_TBL.'); -- Added for 1.5.
                        fnd_file.put_line (fnd_file.LOG, 'Error Code : ' || SQLCODE || '. Error Message : '|| SQLERRM); -- Added for 1.5.
                        --   fnd_file.put_line(fnd_file.log,'l_vw_id '||sqlerrm); -- Commented for 1.5.

                end;

                -- Start 1.2
                BEGIN
                    SELECT organization
                      INTO l_num_org_id
                      FROM xxdo_ebs_rms_vw_map
                     WHERE virtual_warehouse = l_vw_id
                       -- AND channel = 'OUTLET'; -- Commented for 1.4.
                       AND ROWNUM = 1; -- Added for 1.4.

                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_num_org_id := NULL;
                        fnd_file.put_line (fnd_file.LOG, 'Error while fetching Organization from XXDO_EBS_RMS_VW_MAP for Virtual Warehouse : '||l_vw_id); -- Added for 1.5.
                        fnd_file.put_line (fnd_file.LOG, 'Error Code : ' || SQLCODE || '. Error Message : '|| SQLERRM); -- Added for 1.5.
                        --  fnd_file.put_line (fnd_file.LOG, 'Unable to fetch Organization for Vir.Whse ID :: ' || l_vw_id || ' :: ' || SQLERRM); -- Commented for 1.5.
                END;
                -- End 1.2
                */
                --Code commented for change 2.0 --END

                BEGIN
                    /* Insert Statement to insert the parsed records in XXDO_INV_INT_028_STG_TBL table */
                    INSERT INTO XXDO_INV_INT_028_STG2 (SEQ_NO,
                                                       XML_ID,
                                                       ASN_NBR,
                                                       ASN_TYPE,
                                                       BOL_NBR,
                                                       CARRIER_CODE,
                                                       DISTRO_DOC_TYPE,
                                                       DISTRO_NBR,
                                                       DOC_TYPE,
                                                       FINAL_LOCATION,
                                                       FROM_LOCATION,
                                                       H_CONTAINER_QTY,
                                                       ITEM_ID,
                                                       L_CONTAINER_QTY,
                                                       LOT_NBR,
                                                       ORDER_LINE_NBR,
                                                       PO_NBR,
                                                       PRIORITY_LEVEL,
                                                       REQUEST_ID,
                                                       SEAL_NBR,
                                                       SHIP_CITY,
                                                       SHIP_COUNTRY_ID,
                                                       SHIP_STATE,
                                                       SHIP_ZIP,
                                                       SHIPMENT_ADDRESS1,
                                                       SHIPMENT_ADDRESS2,
                                                       SHIPMENT_ADDRESS3,
                                                       SHIPMENT_ADDRESS4,
                                                       SHIPMENT_ADDRESS5,
                                                       SHIPMENT_DATE,
                                                       TO_LOCATION,
                                                       TRAILER_NBR,
                                                       UNIT_QTY,
                                                       VENDOR_NBR,
                                                       container_id,
                                                       container_weight,
                                                       container_length,
                                                       container_width,
                                                       container_height,
                                                       container_cube,
                                                       expedite_flag,
                                                       rma_nbr,
                                                       tracking_nbr,
                                                       freight_charge,
                                                       STATUS,
                                                       CREATED_BY,
                                                       CREATION_DATE,
                                                       LAST_UPDATED_BY,
                                                       LAST_UPDATE_DATE,
                                                       DC_VW_ID)
                         VALUES (xxdo_inv_int_028_seq1.NEXTVAL, rec_xml_data.xml_id, rec_xml_data.ASN_NBR, rec_xml_data.ASN_TYPE, rec_xml_data.BOL_NBR, rec_xml_data.CARRIER_CODE, rec_xml_data.DISTRO_DOC_TYPE, rec_xml_data.DISTRO_NBR, rec_xml_data.DOC_TYPE, rec_xml_data.FINAL_LOCATION, rec_xml_data.FROM_LOCATION, rec_xml_data.H_CONTAINER_QTY, rec_xml_data.ITEM_ID, rec_xml_data.L_CONTAINER_QTY, rec_xml_data.LOT_NBR, rec_xml_data.ORDER_LINE_NBR, rec_xml_data.PO_NBR, rec_xml_data.PRIORITY_LEVEL, FND_GLOBAL.conc_request_id, rec_xml_data.SEAL_NBR, rec_xml_data.SHIP_CITY, rec_xml_data.SHIP_COUNTRY_ID, rec_xml_data.SHIP_STATE, rec_xml_data.SHIP_ZIP, rec_xml_data.SHIP_ADDRESS1, rec_xml_data.SHIP_ADDRESS2, rec_xml_data.SHIP_ADDRESS3, rec_xml_data.SHIP_ADDRESS4, rec_xml_data.SHIP_ADDRESS5, TO_DATE (SUBSTR (rec_xml_data.SHIPMENT_DATE, 1, INSTR (rec_xml_data.SHIPMENT_DATE, 'T', 1) - 1), 'RRRR-MM-DD'), l_num_org_id -- rec_xml_data.TO_LOCATION
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  , rec_xml_data.TRAILER_NBR, rec_xml_data.UNIT_QTY, rec_xml_data.VENDOR_NBR, rec_xml_data.container_id, rec_xml_data.container_weight, rec_xml_data.container_length, rec_xml_data.container_width, rec_xml_data.container_height, rec_xml_data.container_cube, rec_xml_data.expedite_flag, rec_xml_data.rma_nbr, rec_xml_data.tracking_nbr, rec_xml_data.freight_charge, 0, FND_GLOBAL.USER_ID, SYSDATE, FND_GLOBAL.USER_ID
                                 , SYSDATE, l_vw_id);

                    lv_success   := 'Y';
                    DBMS_OUTPUT.PUT_LINE (
                           'lv_success'
                        || ' '
                        || lv_success
                        || ' '
                        || lv_loop_counter);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        /*  fnd_file.put_line(fnd_file.LOG,'Error while Inserting XML Elements into the table');
                       fnd_file.put_line(fnd_file.LOG,'SQL Error Code :'|| SQLCODE); */
                        -- Commented for 1.5.

                        -- START : 1.5.
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Error while Inserting XML Elements into the table XXDO_INV_INT_028_STG2.');
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error Code : '
                            || SQLCODE
                            || '. Error Message : '
                            || SQLERRM);
                        -- END : 1.5.

                        DBMS_OUTPUT.PUT_LINE (
                               'Error while Inserting XML Elements into the tab'
                            || ' '
                            || SQLERRM);
                        ROLLBACK;
                        lv_success   := 'N';
                END;

                IF NVL (lv_success, 'N') = 'Y'
                THEN
                    BEGIN
                        /*UPdate Statement to Update status to 1 after successfully parsing the XML Elements*/
                        UPDATE XXDO.XXDO_INV_INT_028_STG1 X28
                           SET X28.STATUS   = 1
                         WHERE X28.ROWID = rec_xml_data.ROWID;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'No Data Found Error When Updating Success Status into the table'
                                || SQLERRM);
                            --  fnd_file.put_line(fnd_file.LOG,'SQL Error Code :'|| SQLCODE); -- Commented for 1.5.
                            DBMS_OUTPUT.PUT_LINE (
                                   'No Data Found Error When Updating Success Status into the table :'
                                || SQLERRM);
                            ROLLBACK;
                        WHEN OTHERS
                        THEN
                            /*  fnd_file.put_line(fnd_file.LOG,'SQL Error Code :'|| SQLCODE);
                                fnd_file.put_line(fnd_file.LOG,'Error while Updating Success Status into the table'||SQLERRM); */
                            -- Commented for 1.5.

                            -- START : 1.5.
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Error while Updating Success Status into the table XXDO_INV_INT_028_STG1.');
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error Code : '
                                || SQLCODE
                                || '. Error Message : '
                                || SQLERRM);
                            -- END : 1.5.

                            DBMS_OUTPUT.PUT_LINE (
                                   'Error while Updating Success Status into the table :'
                                || SQLERRM);
                            ROLLBACK;
                    END;
                END IF;
            END IF;                       --End of If condition for change 2.0
        END LOOP;

        fnd_file.put_line (
            fnd_file.OUTPUT,
            'Number of XML Records Parsed : ' || lv_loop_counter);
        DBMS_OUTPUT.PUT_LINE (
            'Number of XML Records Parsed : ' || lv_loop_counter);
    /*COMMITting the final changes*/
    --       COMMIT;

    END load_xml_data;


    PROCEDURE INSERT_OE_IFACE_TABLES (retcode               OUT VARCHAR2,
                                      errbuf                OUT VARCHAR2,
                                      pv_reprocess       IN     VARCHAR2,
                                      pd_rp_start_date   IN     DATE,
                                      pd_rp_end_date     IN     DATE)
    IS
        CURSOR cur_order_lines (cn_from_location NUMBER, cn_to_location NUMBER, --                                         cn_po_nbr NUMBER,
                                                                                cn_brand VARCHAR2
                                , cn_status VARCHAR2)
        IS
            SELECT X28_2.ROWID, X28_2.*
              FROM XXDO_INV_INT_028_STG2 X28_2, MTL_ITEM_CATEGORIES MIC, MTL_CATEGORIES MC,
                   MTL_CATEGORY_SETS_TL MCS
             WHERE     MIC.CATEGORY_ID = MC.CATEGORY_ID
                   AND MCS.CATEGORY_SET_ID = MIC.CATEGORY_SET_ID
                   AND MIC.INVENTORY_ITEM_ID = X28_2.item_id
                   AND MIC.ORGANIZATION_ID = X28_2.to_location
                   AND UPPER (MCS.CATEGORY_SET_NAME) = 'INVENTORY'
                   --AND MC.STRUCTURE_ID = 101
                   AND MC.STRUCTURE_ID =
                       (SELECT structure_id
                          FROM mtl_category_sets
                         WHERE category_set_name = 'Inventory') ----W.r.t version 1.2
                   AND MCS.LANGUAGE = 'US'
                   AND X28_2.status = cn_status
                   AND X28_2.from_location = cn_from_location
                   AND X28_2.to_location = cn_to_location
                   --    AND X28_2.po_nbr = cn_po_nbr
                   AND MC.SEGMENT1 = cn_brand;


        TYPE lcur_cursor IS REF CURSOR;

        cur_xxdo28_stg2              lcur_cursor;

        lr_rec_stg2_from_location    NUMBER;
        lr_rec_stg2_to_location      NUMBER;
        lr_rec_stg2_dc_vw_id         NUMBER;
        lr_rec_stg2_brand            VARCHAR2 (20);
        lr_rec_stg2_status           NUMBER;
        lr_rec_stg2_po_nbr           VARCHAR2 (20);
        lr_rec_stg2_cancel_date      DATE;

        lv_cursor_stmt               VARCHAR2 (20000);
        lv_cursor_stmt_pcondition    VARCHAR2 (20000); /* Parameter Condition */
        lv_cursor_stmt_groupby       VARCHAR2 (20000);    /* Group by Clause*/
        lv_udate_stmt                VARCHAR2 (20000);

        ln_customer_id               NUMBER;
        ln_customer_number           NUMBER;
        ln_org_id                    NUMBER;
        ln_order_source_id           NUMBER;
        ln_order_type_id             NUMBER;

        lv_error_message             VARCHAR2 (32767);
        lv_status                    VARCHAR2 (1);

        ln_org_ref_sequence          NUMBER;

        lv_header_insertion_status   VARCHAR2 (1) := 'S';
        lv_line_insertion_status     VARCHAR2 (1) := 'S';

        ln_line_number               NUMBER := 0;

        lv_return_reason             VARCHAR2 (100);
    BEGIN
        --, MAX(PICK_NOT_AFTER_DATE) Cancel_Date

        lv_cursor_stmt   :=
            'SELECT X28_2.TO_LOCATION, X28_2.FROM_LOCATION,X28_2.DC_VW_ID, X28_2.STATUS, MC.SEGMENT1 BRAND
                                  FROM XXDO_INV_INT_028_STG2  X28_2
                                           ,MTL_ITEM_CATEGORIES MIC
                                           ,MTL_CATEGORIES MC
                                           ,MTL_CATEGORY_SETS_TL MCS
                                 WHERE MIC.CATEGORY_ID = MC.CATEGORY_ID
                                    AND MCS.CATEGORY_SET_ID = MIC.CATEGORY_SET_ID
                                    AND MIC.INVENTORY_ITEM_ID = X28_2.item_id
                                    AND MIC.ORGANIZATION_ID = X28_2.to_location
                                    AND UPPER(MCS.CATEGORY_SET_NAME) = ''INVENTORY''
                                    AND MC.STRUCTURE_ID = (  SELECT structure_id
                                           FROM mtl_category_sets
                                          WHERE category_set_name = ''Inventory'')
                                    AND MCS.LANGUAGE = ''US''
                                ';

        lv_cursor_stmt_groupby   :=
            'GROUP BY X28_2.FROM_LOCATION,X28_2.DC_VW_ID, X28_2.TO_LOCATION,  X28_2.STATUS, MC.SEGMENT1';

        IF NVL (pv_reprocess, 'N') = 'N'
        THEN
            lv_cursor_stmt_pcondition   := ' AND X28_2.STATUS = 0 ';

            lv_cursor_stmt              :=
                   lv_cursor_stmt                       /* Select Statement */
                || lv_cursor_stmt_pcondition   /* Parameter Where Condition */
                || lv_cursor_stmt_groupby;          /*Adding Group by Clause*/
        ELSE
            BEGIN                                            -- Added for 1.5.
                SELECT ' AND X28_2.STATUS = 2 AND X28_2.CREATION_DATE BETWEEN ''' || pd_rp_start_date || ''' AND ''' || DECODE (NVL (pv_reprocess, 'N'), 'Y', NVL (pd_rp_end_date, SYSDATE), NULL) || ''' '
                  INTO lv_cursor_stmt_pcondition
                  FROM DUAL;
            -- START : 1.5.
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Error while forming condition statement : LV_CURSOR_STMT_PCONDITION');
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error Code : '
                        || SQLCODE
                        || '. Error Message : '
                        || SQLERRM);
            END;

            -- END : 1.5.

            lv_cursor_stmt   :=
                   lv_cursor_stmt                       /* Select Statement */
                || lv_cursor_stmt_pcondition   /* Parameter Where Condition */
                || lv_cursor_stmt_groupby;          /*Adding Group by Clause*/
        END IF;

        --     lv_udate_stmt := 'UPDATE XXDO_INV_INT_026_STG2 SET request_id = '||FND_GLOBAL.CONC_REQUEST_ID||' WHERE (dc_dest_id, dest_id) IN ('||lv_cursor_stmt||')';
        lv_udate_stmt   :=
               'UPDATE XXDO_INV_INT_028_STG2 X28_2 SET request_id = '
            || FND_GLOBAL.CONC_REQUEST_ID
            || ' WHERE 1 = 1 '
            || lv_cursor_stmt_pcondition;


        DBMS_OUTPUT.PUT_LINE ('Cursor Statement :' || lv_cursor_stmt);
        DBMS_OUTPUT.PUT_LINE ('Update Statement :' || lv_udate_stmt);

        /* fnd_file.put_line(fnd_file.LOG, lv_cursor_stmt);
           fnd_file.put_line(fnd_file.LOG, lv_udate_stmt); */
        -- Commented for 1.5.

        -- START : 1.5.
        fnd_file.put_line (
            fnd_file.LOG,
            'Cursor Statement(LV_CURSOR_STMT) : ' || lv_cursor_stmt);
        fnd_file.put_line (
            fnd_file.LOG,
            'Update Statement(LV_UDATE_STMT) : ' || lv_udate_stmt);

        -- END : 1.5.

        BEGIN                                                -- Added for 1.5.
            EXECUTE IMMEDIATE lv_udate_stmt;
        -- START : 1.5.
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Error while executing update statement : LV_UDATE_STMT');
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error Code : '
                    || SQLCODE
                    || '. Error Message : '
                    || SQLERRM);
        END;

        -- END : 1.5.

        COMMIT;

        /*Fetching Order Source Information */
        FETCH_ORDER_SOURCE (ln_order_source_id, lv_status, lv_error_message);

        IF NVL (lv_status, 'S') = 'E'
        THEN
            -- fnd_file.put_line(fnd_file.LOG, lv_error_message); -- Commented for 1.5.
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error message from the procedure FETCH_ORDER_SOURCE : '
                || lv_error_message);                     -- Modified for 1.5.
            DBMS_OUTPUT.PUT_LINE (lv_error_message);
        END IF;

        /*Loop for Inserting Header Record into Order Header Interface Table*/
        OPEN cur_xxdo28_stg2 FOR lv_cursor_stmt;

        LOOP
            FETCH cur_xxdo28_stg2
                INTO lr_rec_stg2_to_location, lr_rec_stg2_from_location, lr_rec_stg2_dc_vw_id, lr_rec_stg2_status,
                     lr_rec_stg2_brand;           --, lr_rec_stg2_cancel_date;

            EXIT WHEN cur_xxdo28_stg2%NOTFOUND;

            FETCH_CUSTOMER_ID (lr_rec_stg2_from_location, ln_customer_id, ln_customer_number
                               , lv_status, lv_error_message);

            IF NVL (lv_status, 'S') = 'E'
            THEN
                --  fnd_file.put_line(fnd_file.LOG, lv_error_message); -- Commented for 1.5.
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error message from the procedure FETCH_CUSTOMER_ID : '
                    || lv_error_message);                 -- Modified for 1.5.
                DBMS_OUTPUT.PUT_LINE (lv_error_message);
            END IF;


            FETCH_ORG_ID (lr_rec_stg2_to_location, lr_rec_stg2_dc_vw_id, lr_rec_stg2_from_location
                          ,                                  -- Added for 1.3.
                            ln_org_id, lv_status, lv_error_message);

            IF NVL (lv_status, 'S') = 'E'
            THEN
                fnd_file.put_line (fnd_file.LOG, 'ln_org_id ' || ln_org_id);

                --   fnd_file.put_line(fnd_file.LOG, lv_error_message); -- Commented for 1.5.
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error message from the procedure FETCH_ORG_ID : '
                    || lv_error_message);                 -- Modified for 1.5.
                DBMS_OUTPUT.PUT_LINE (lv_error_message);
            END IF;

            fnd_file.put_line (fnd_file.LOG, 'ln_org_id ' || ln_org_id);

            FETCH_ORDER_TYPE ('RETURNS', ln_org_id, lr_rec_stg2_dc_vw_id,
                              lr_rec_stg2_from_location, ln_order_type_id, lv_status
                              , lv_error_message);

            fnd_file.put_line (
                fnd_file.LOG,
                'lr_rec_stg2_dc_vw_id ' || lr_rec_stg2_dc_vw_id);
            fnd_file.put_line (fnd_file.LOG,
                               'ln_order_type_id ' || ln_order_type_id);

            IF NVL (lv_status, 'S') = 'E'
            THEN
                --       fnd_file.put_line(fnd_file.LOG, lv_error_message); -- Commented for 1.5.
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error message from the procedure FETCH_ORDER_TYPE : '
                    || lv_error_message);                 -- Modified for 1.5.
                DBMS_OUTPUT.PUT_LINE (lv_error_message);
            END IF;

            /*Inserting into Order Header Interface Tables */
            BEGIN
                SELECT xxdo_inv_int_028_seq2.NEXTVAL
                  INTO ln_org_ref_sequence
                  FROM DUAL;

                INSERT INTO OE_HEADERS_IFACE_ALL (order_source_id, order_type_id, org_id, orig_sys_document_ref, created_by, creation_date, last_updated_by, last_update_date, operation_code, booked_flag--                      ,customer_number
                                                                                                                                                                                                          --                      ,customer_id
                                                                                                                                                                                                          , sold_to_org_id--                      ,ship_to_org_id
                                                                                                                                                                                                                          , customer_po_number
                                                  , attribute1, attribute5)
                         VALUES (
                                    ln_order_source_id,
                                    ln_order_type_id,
                                    ln_org_id,
                                       'RMS'
                                    || '-'
                                    || lr_rec_stg2_from_location
                                    || '-'
                                    || lr_rec_stg2_to_location
                                    || '-'
                                    || ln_org_ref_sequence,
                                    FND_GLOBAL.USER_ID,
                                    SYSDATE,
                                    FND_GLOBAL.USER_ID,
                                    SYSDATE,
                                    'INSERT',
                                    'Y'--                      ,ln_customer_number
                                       --                      ,ln_customer_id
                                       ,
                                    ln_customer_id--                      ,lr_rec_stg2_to_location
                                                  ,
                                       'RMS'
                                    || '-'
                                    || lr_rec_stg2_from_location
                                    || '-'
                                    || lr_rec_stg2_to_location
                                    || '-'
                                    || ln_org_ref_sequence--                      ,lr_rec_stg2_po_nbr
                                                          --                      ,TO_CHAR(lr_rec_stg2_cancel_date+365, 'DD-MON-RRRR')
                                                          --,TRUNC(SYSDATE) + 30  -- 1.2
                                                          ,
                                    TO_CHAR ((TRUNC (SYSDATE) + 30),
                                             'YYYY/MM/DD HH:MI:SS'),
                                    lr_rec_stg2_brand);

                lv_header_insertion_status   := 'S';
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_message             :=
                           lv_error_message
                        || ' - '
                        || 'Error while Inserting into Order Header Interface table : '
                        || SQLERRM;
                    /*
                    fnd_file.put_line(fnd_file.LOG,'SQL Error Code :'|| SQLCODE);
                    fnd_file.put_line(fnd_file.LOG,'Error while Inserting into Order Header Interface table : '|| SQLERRM); */
                    -- Commented for 1.5.

                    -- START : 1.5.
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Error while Inserting into Order Header Interface table : OE_HEADERS_IFACE_ALL.');
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error Code : '
                        || SQLCODE
                        || '. Error Message : '
                        || SQLERRM);
                    -- END : 1.5.

                    DBMS_OUTPUT.PUT_LINE (
                           'Error while Inserting into Order Header Interface table : '
                        || SQLERRM);
                    lv_header_insertion_status   := 'E';
            END;

            IF NVL (lv_header_insertion_status, 'S') = 'S'
            THEN
                ln_line_number             := 0;
                lv_line_insertion_status   := 'S';

                BEGIN
                    SELECT FLV.lookup_code
                      INTO lv_return_reason
                      FROM fnd_lookup_values FLV
                     WHERE     FLV.lookup_type = 'CREDIT_MEMO_REASON'
                           AND FLV.language = 'US'
                           AND FLV.meaning = 'UNKNOWN';
                --  AND FLV.meaning = 'MISCELLANEOUS';   ---100 Changes the Return Reason Code

                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_error_message   :=
                               lv_error_message
                            || ' - '
                            || 'Error while finding Return Reason - '
                            || lr_rec_stg2_from_location
                            || ' AND to_location - '
                            || lr_rec_stg2_to_location
                            || '  :'
                            || SQLERRM;
                        /*
                        fnd_file.put_line(fnd_file.LOG,'SQL Error Code :'|| SQLCODE);
                        fnd_file.put_line(fnd_file.LOG,'Error while finding Return Reason - '||lr_rec_stg2_from_location||' AND to_location - '||lr_rec_stg2_to_location ||'  :'||SQLERRM);   */
                        -- Commented for 1.5.

                        -- START : 1.5.
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Error while fetching Return Reason from lookup : CREDIT_MEMO_REASON.');
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error Code : '
                            || SQLCODE
                            || '. Error Message : '
                            || SQLERRM);
                        -- END : 1.5.

                        DBMS_OUTPUT.PUT_LINE (
                               'Error while finding Return Reason - '
                            || lr_rec_stg2_from_location
                            || ' AND to_location - '
                            || lr_rec_stg2_to_location
                            || '  :'
                            || SQLERRM);
                END;

                /*Loop For Inserting Records into Order Lines Interface Table */
                FOR rec_order_lines IN cur_order_lines (lr_rec_stg2_from_location, lr_rec_stg2_to_location, lr_rec_stg2_brand
                                                        , lr_rec_stg2_status)
                LOOP
                    BEGIN
                        ln_line_number             := ln_line_number + 1;

                        INSERT INTO OE_LINES_IFACE_ALL (order_source_id, org_id, orig_sys_document_ref, orig_sys_line_ref, INVENTORY_ITEM_ID, ORDERED_QUANTITY--  ,ship_from_org_id   -- Commented for 1.6.
                                                                                                                                                              , ship_from_org_id -- Uncommented for 1.7.
                                                                                                                                                                                , CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE--                                       ,sold_to_org_id
                                                                                                                                                                                                                                              , return_reason_code
                                                        , attribute1)
                                 VALUES (
                                            ln_order_source_id,
                                            ln_org_id,
                                               'RMS'
                                            || '-'
                                            || lr_rec_stg2_from_location
                                            || '-'
                                            || lr_rec_stg2_to_location
                                            || '-'
                                            || ln_org_ref_sequence,
                                               rec_order_lines.distro_nbr
                                            || '-'
                                            || rec_order_lines.distro_doc_type
                                            || '-'
                                            || rec_order_lines.po_nbr
                                            || '-'
                                            || rec_order_lines.xml_id
                                            || '-'
                                            || xxdo_inv_int_028_seq.NEXTVAL,
                                            rec_order_lines.item_id,
                                            rec_order_lines.unit_qty--   ,rec_order_lines.to_location    -- Commented for 1.6.
                                                                    ,
                                            rec_order_lines.to_location -- Uncommented for 1.7.
                                                                       ,
                                            FND_GLOBAL.USER_ID,
                                            SYSDATE,
                                            FND_GLOBAL.USER_ID,
                                            SYSDATE--                                     ,ln_customer_id
                                                   ,
                                            lv_return_reason--,TRUNC(SYSDATE) + 30  -- 1.2
                                                            ,
                                            TO_CHAR ((TRUNC (SYSDATE) + 30),
                                                     'YYYY/MM/DD HH:MI:SS'));

                        lv_line_insertion_status   := 'S';
                        COMMIT;

                        BEGIN
                            UPDATE XXDO_INV_INT_028_STG2 X28_2
                               SET X28_2.STATUS = 1, X28_2.BRAND = lr_rec_stg2_brand
                             WHERE X28_2.ROWID = rec_order_lines.ROWID;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_error_message   :=
                                       lv_error_message
                                    || ' - '
                                    || 'Error while Updating Status 2 for from_location - '
                                    || lr_rec_stg2_from_location
                                    || ' AND to_location - '
                                    || lr_rec_stg2_to_location
                                    || '  :'
                                    || SQLERRM;
                                /*
                                fnd_file.put_line(fnd_file.LOG,'SQL Error Code :'|| SQLCODE);
                                fnd_file.put_line(fnd_file.LOG,'Error while Updating Status 2 for from_location - '||lr_rec_stg2_from_location||' AND to_location - '||lr_rec_stg2_to_location ||'  :'||SQLERRM); */
                                -- Commented for 1.5.

                                -- START : 1.5.
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Error while Updating Status 1 for from_location - '
                                    || lr_rec_stg2_from_location
                                    || ' AND to_location - '
                                    || lr_rec_stg2_to_location);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Error Code : '
                                    || SQLCODE
                                    || '. Error Message : '
                                    || SQLERRM);
                                -- END : 1.5.

                                DBMS_OUTPUT.PUT_LINE (
                                       'Error while Updating Status 2 for from_location - '
                                    || lr_rec_stg2_from_location
                                    || ' AND to_location - '
                                    || lr_rec_stg2_to_location
                                    || '  :'
                                    || SQLERRM);
                        END;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            /* fnd_file.put_line(fnd_file.LOG,'SQL Error Code :'|| SQLCODE);
                               fnd_file.put_line(fnd_file.LOG,'Error while Inserting into Order Lines Interface table :'||SQLERRM); */
                            -- Commmented for 1.5.

                            -- START : 1.5.
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Error while Inserting into Order Line Interface table : OE_LINES_IFACE_ALL.');
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error Code : '
                                || SQLCODE
                                || '. Error Message : '
                                || SQLERRM);
                            -- END : 1.5.

                            DBMS_OUTPUT.PUT_LINE (
                                   'Error while Inserting into Order Lines Interface table :'
                                || SQLERRM);
                            lv_line_insertion_status   := 'E';

                            BEGIN
                                UPDATE XXDO_INV_INT_028_STG2 X28_2
                                   SET X28_2.STATUS = 2, X28_2.BRAND = lr_rec_stg2_brand, X28_2.ERROR_MESSAGE = 'Seq NO :' || rec_order_lines.seq_no || ' ' || lv_error_message
                                 WHERE     (X28_2.SEQ_NO) IN
                                               (SELECT X28_2.SEQ_NO
                                                  FROM XXDO_INV_INT_028_STG2 X28_2_1, MTL_ITEM_CATEGORIES MIC, MTL_CATEGORIES MC,
                                                       MTL_CATEGORY_SETS_TL MCS
                                                 WHERE     MIC.CATEGORY_ID =
                                                           MC.CATEGORY_ID
                                                       AND MCS.CATEGORY_SET_ID =
                                                           MIC.CATEGORY_SET_ID
                                                       AND MIC.INVENTORY_ITEM_ID =
                                                           X28_2_1.item_id
                                                       AND MIC.ORGANIZATION_ID =
                                                           X28_2_1.to_location
                                                       AND UPPER (
                                                               MCS.CATEGORY_SET_NAME) =
                                                           'INVENTORY'
                                                       --AND MC.STRUCTURE_ID = 101
                                                       AND MC.STRUCTURE_ID =
                                                           (SELECT structure_id
                                                              FROM mtl_category_sets
                                                             WHERE category_set_name =
                                                                   'Inventory') ----W.r.t version 1.2
                                                       AND MCS.LANGUAGE =
                                                           'US'
                                                       AND X28_2_1.to_location =
                                                           lr_rec_stg2_to_location
                                                       AND X28_2_1.from_location =
                                                           lr_rec_stg2_from_location
                                                       AND X28_2_1.status =
                                                           lr_rec_stg2_status
                                                       --                                                                                AND X28_2_1.po_nbr = lr_rec_stg2_po_nbr
                                                       AND MC.SEGMENT1 =
                                                           lr_rec_stg2_brand)
                                       AND X28_2.REQUEST_ID =
                                           FND_GLOBAL.CONC_REQUEST_ID;
                            --                              UPDATE XXDO_INV_INT_026_STG2 X26_2
                            --                                    SET X26_2.STATUS = 2,
                            --                                           X26_2.ERROR_MESSAGE = 'Seq NO :'||rec_order_lines.seq_no||' '||lv_error_message
                            --                                WHERE X26_2.ROWID = rec_order_lines.ROWID;

                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Code :' || SQLCODE);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Error while Updating Status 2 from location - '
                                        || lr_rec_stg2_from_location
                                        || ' AND To Location - '
                                        || lr_rec_stg2_to_location
                                        || '  :'
                                        || SQLERRM);
                                    DBMS_OUTPUT.PUT_LINE (
                                           'Error while Updating Status 2 from location - '
                                        || lr_rec_stg2_from_location
                                        || ' AND To Location - '
                                        || lr_rec_stg2_to_location
                                        || '  :'
                                        || SQLERRM);
                            END;
                    END;
                END LOOP;
            ELSE
                BEGIN
                    UPDATE XXDO_INV_INT_028_STG2 X28_2
                       SET X28_2.STATUS = 2, X28_2.BRAND = lr_rec_stg2_brand, X28_2.ERROR_MESSAGE = lv_error_message
                     WHERE     (X28_2.SEQ_NO) IN
                                   (SELECT X28_2.SEQ_NO
                                      FROM XXDO_INV_INT_028_STG2 X28_2_1, MTL_ITEM_CATEGORIES MIC, MTL_CATEGORIES MC,
                                           MTL_CATEGORY_SETS_TL MCS
                                     WHERE     MIC.CATEGORY_ID =
                                               MC.CATEGORY_ID
                                           AND MCS.CATEGORY_SET_ID =
                                               MIC.CATEGORY_SET_ID
                                           AND MIC.INVENTORY_ITEM_ID =
                                               X28_2_1.item_id
                                           AND MIC.ORGANIZATION_ID =
                                               X28_2_1.to_location
                                           AND UPPER (MCS.CATEGORY_SET_NAME) =
                                               'INVENTORY'
                                           --AND MC.STRUCTURE_ID = 101
                                           AND MC.STRUCTURE_ID =
                                               (SELECT structure_id
                                                  FROM mtl_category_sets
                                                 WHERE category_set_name =
                                                       'Inventory') ----W.r.t version 1.2
                                           AND MCS.LANGUAGE = 'US'
                                           AND X28_2_1.to_location =
                                               lr_rec_stg2_to_location
                                           AND X28_2_1.from_location =
                                               lr_rec_stg2_from_location
                                           AND X28_2_1.status =
                                               lr_rec_stg2_status
                                           --                                                                AND X28_2_1.po_nbr = lr_rec_stg2_po_nbr
                                           AND MC.SEGMENT1 =
                                               lr_rec_stg2_brand)
                           AND X28_2.REQUEST_ID = FND_GLOBAL.CONC_REQUEST_ID;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (fnd_file.LOG,
                                           'SQL Error Code :' || SQLCODE);
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error while Updating Status 2 for Dest_id - '
                            || lr_rec_stg2_from_location
                            || ' AND dc_dest_id - '
                            || lr_rec_stg2_to_location
                            || '  :'
                            || SQLERRM);
                        DBMS_OUTPUT.PUT_LINE (
                               'Error while Updating Status 2 for Dest_id - '
                            || lr_rec_stg2_from_location
                            || ' AND dc_dest_id - '
                            || lr_rec_stg2_to_location
                            || '  :'
                            || SQLERRM);
                END;
            END IF;
        END LOOP;

        CLOSE cur_xxdo28_stg2;

        /*COMMITting The Inserts and Updates*/
        COMMIT;

        /*Calling Order Import Program*/
        CALL_ORDER_IMPORT;

        /*Calling Procedure to Print Audit Report in the Concurrent Request Output*/
        PRINT_AUDIT_REPORT;
    END INSERT_OE_IFACE_TABLES;

    PROCEDURE CALL_ORDER_IMPORT
    IS
        CURSOR cur_order_import IS
            SELECT DISTINCT OEI.org_id org_id, OEI.order_source_id order_source_id
              FROM OE_HEADERS_IFACE_ALL OEI, OE_ORDER_SOURCES OOS
             WHERE     oos.order_source_id = oei.order_source_id
                   AND UPPER (OOS.name) = 'RETAIL';

        --EXISTS(SELECT 1
        --                                FROM XXDO_INV_INT_028_STG2  X26_2
        --                              WHERE X26_2.FROM_LOCATION  = SUBSTR(orig_sys_document_ref, INSTR(orig_sys_document_ref, '-', 1, 1)+1, (INSTR(orig_sys_document_ref, '-', 1, 2)-INSTR(orig_sys_document_ref, '-', 1, 1))-1)
        --                                  AND X26_2.TO_LOCATION = SUBSTR(orig_sys_document_ref, INSTR(orig_sys_document_ref, '-', 1, 2)+1, (INSTR(orig_sys_document_ref, '-', 1, 3)-INSTR(orig_sys_document_ref, '-', 1, 2))-1)
        --                                  AND X26_2.REQUEST_ID = FND_GLOBAL.CONC_REQUEST_ID
        --                                  AND X26_2.STATUS = 1);

        ln_request_id   NUMBER;

        lv_submit       NUMBER := 0;
        lv_success      BOOLEAN;

        lv_dev_phase    VARCHAR2 (50);
        lv_dev_status   VARCHAR2 (50);
        lv_status       VARCHAR2 (50);
        lv_phase        VARCHAR2 (50);
        lv_message      VARCHAR2 (240);
    BEGIN
        FOR rec_order_import IN cur_order_import
        LOOP
            ln_request_id   :=
                FND_REQUEST.SUBMIT_REQUEST (
                    application   => 'ONT',
                    program       => 'OEOIMP',
                    description   => 'Order Import',
                    start_time    => SYSDATE,
                    sub_request   => NULL,
                    argument1     => rec_order_import.org_id,
                    argument2     => rec_order_import.order_source_id,
                    argument3     => NULL,
                    argument4     => NULL,
                    argument5     => 'N',
                    argument6     => '1',
                    argument7     => '4',
                    argument8     => NULL,
                    argument9     => NULL,
                    argument10    => NULL,
                    argument11    => 'Y',
                    argument12    => 'N',
                    argument13    => 'Y',
                    argument14    => '2',
                    argument15    => 'Y');

            COMMIT;

            --   FND_FILE.PUT_LINE(FND_FILE.LOG,'ln_request_id  '||ln_request_id); -- Commented for 1.5.
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'Order Import Request Id : ' || ln_request_id); -- Modified for 1.5.

            IF (ln_request_id != 0)
            THEN
                lv_success   :=
                    fnd_concurrent.get_request_status (
                        request_id       => ln_request_id, --rec_oint_req_id.oint_request_id,    -- Request ID
                        appl_shortname   => NULL,
                        program          => NULL,
                        phase            => lv_phase, -- Phase displayed on screen
                        status           => lv_status, -- Status displayed on screen
                        dev_phase        => lv_dev_phase, -- Phase available for developer
                        dev_status       => lv_dev_status, -- Status available for developer
                        MESSAGE          => lv_message    -- Execution Message
                                                      );

                LOOP
                    lv_success   :=
                        fnd_concurrent.wait_for_request (
                            request_id   => ln_request_id,       -- Request ID
                            INTERVAL     => 10,
                            phase        => lv_phase, -- Phase displyed on screen
                            status       => lv_status, -- Status displayed on screen
                            dev_phase    => lv_dev_phase, -- Phase available for developer
                            dev_status   => lv_dev_status, -- Status available for developer
                            MESSAGE      => lv_message    -- Execution Message
                                                      );

                    EXIT WHEN lv_dev_phase = 'COMPLETE';
                END LOOP;
            END IF;
        END LOOP;
    END CALL_ORDER_IMPORT;

    PROCEDURE FETCH_CUSTOMER_ID (pn_dest_id           IN     NUMBER,
                                 pn_customer_id          OUT NUMBER,
                                 pn_customer_number      OUT NUMBER,
                                 pv_status               OUT VARCHAR2,
                                 pv_error_message        OUT VARCHAR2)
    IS
        ln_customer_id       NUMBER;
        ln_customer_number   NUMBER;
        lv_customer_name     VARCHAR2 (240);
    BEGIN
        BEGIN
            --         SELECT tag
            --             INTO ln_customer_id
            --            FROM FND_LOOKUP_VALUES FLV
            --         WHERE FLV.lookup_type = 'XXDO_RETAIL_STORE_CUST_MAPPING'
            --             AND FLV.lookup_code = pn_dest_id
            --             AND LANGUAGE = 'US';

            SELECT ra_customer_id
              INTO ln_customer_id
              FROM XXD_RETAIL_STORES_V --XXDO.XXDO_stores DRS -- do_retail.stores@datamart.deckers.com DRS
             WHERE rms_store_id = pn_dest_id AND ROWNUM = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                -- START : 1.5.
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error while fetching Customer Id from XXD_RETAIL_STORES_V for Dest ID : '
                    || pn_dest_id);                          -- Added for 1.5.
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error Code : '
                    || SQLCODE
                    || '. Error Message : '
                    || SQLERRM);                             -- Added for 1.5.
                -- END : 1.5.
                pv_error_message   :=
                       'Error while Fetching Customer Information from do_retail.stores@datamart.deckers.com TABLE : '
                    || pn_dest_id
                    || ' '
                    || SQLERRM;
                pv_status   := 'E';
                RETURN;
        END;

        fnd_file.put_line (
            fnd_file.LOG,
               'ln_customer_id '
            || ln_customer_id
            || 'pn_dest_id '
            || pn_dest_id);

        BEGIN
            --starts W.r.t 1.2
            SELECT CUSTOMER_NUMBER, CUSTOMER_NAME
              INTO ln_customer_number, lv_customer_name
              FROM RA_HCUSTOMERS RC
             WHERE RC.CUSTOMER_ID = ln_customer_id;

            /*
                    SELECT PARTY_NUMBER,
                        PARTY_NAME
               INTO ln_customer_number,
                        lv_customer_name
              FROM hz_parties RC
            WHERE RC.PARTY_ID = ln_customer_id;   */
            --Ends W.r.t 1.2


            pn_customer_id       := ln_customer_id;
            pn_customer_number   := ln_customer_number;
            pv_status            := 'S';
        EXCEPTION
            WHEN OTHERS
            THEN
                -- START : 1.5.
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error while fetching Customer details from RA_HCUSTOMERS for Customer ID : '
                    || ln_customer_id);                      -- Added for 1.5.
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error Code : '
                    || SQLCODE
                    || '. Error Message : '
                    || SQLERRM);                             -- Added for 1.5.
                -- END : 1.5.
                pv_error_message   :=
                       'Error While Fetching Customer using Customer_id '
                    || ln_customer_id
                    || ' '
                    || SQLERRM;
                pv_status   := 'E';
        END;
    END FETCH_CUSTOMER_ID;

    PROCEDURE FETCH_ORG_ID (pn_dc_dest_id      IN     NUMBER,
                            pn_vm_id           IN     NUMBER,
                            pn_dest_id         IN     NUMBER -- Added for 1.3.
                                                            ,
                            pn_org_id             OUT NUMBER,
                            pv_status             OUT VARCHAR2,
                            pv_error_message      OUT VARCHAR2)
    IS
        ln_org_id   NUMBER;
    BEGIN
        --     SELECT operating_unit
        --        INTO ln_org_id
        --       FROM ORG_ORGANIZATION_DEFINITIONS OOD
        --     WHERE OOD.organization_id =  pn_dc_dest_id;

        /*
           SELECT ORG_ID
             INTO ln_org_id
            FROM xxdo_ebs_rms_vw_map XVM
          WHERE XVM.ORGANIZATION = pn_dc_dest_id
            and XVM.VIRTUAL_WAREHOUSE= pn_vm_id
            AND XVM.CHANNEL = 'OUTLET'; */
        -- Commented for 1.3.

        -- BEGIN : Added for 1.3.
        SELECT operating_unit
          INTO ln_org_id
          FROM apps.xxd_retail_stores_v
         WHERE rms_store_id = pn_dest_id;

        -- END : Added for 1.3.

        pn_org_id   := ln_org_id;
        pv_status   := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.PUT_LINE (
                   'Error while Fetching Organization Information :'
                || 'DC DEST: '
                || pn_dc_dest_id
                || 'VM : '
                || pn_vm_id
                || SQLERRM);
            pv_status   := 'E';
            pv_error_message   :=
                   'Error while Fetching Organization Information :'
                || 'DC DEST: '
                || pn_dc_dest_id
                || 'VM : '
                || pn_vm_id
                || SQLERRM;
            -- START : 1.5.
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error while fetching Operating Unit from XXD_RETAIL_STORES_V for RMS Store ID : '
                || pn_dest_id);                              -- Added for 1.5.
            fnd_file.put_line (
                fnd_file.LOG,
                'Error Code : ' || SQLCODE || '. Error Message : ' || SQLERRM); -- Added for 1.5.
    -- END : 1.5.

    END FETCH_ORG_ID;

    PROCEDURE FETCH_ORDER_SOURCE (pn_order_source_id OUT NUMBER, pv_status OUT VARCHAR2, pv_error_message OUT VARCHAR2)
    IS
        ln_order_source_id   NUMBER;
    BEGIN
        SELECT order_source_id
          INTO ln_order_source_id
          FROM OE_ORDER_SOURCES OOS
         WHERE UPPER (NAME) LIKE 'RETAIL';

        pn_order_source_id   := ln_order_source_id;
        pv_status            := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.PUT_LINE (
                'Error while Fetching Order Source Information :' || SQLERRM);
            pv_status   := 'E';
            pv_error_message   :=
                'Error while Fetching Order Source Information :' || SQLERRM;
            -- START : 1.5.
            fnd_file.put_line (
                fnd_file.LOG,
                'Error while fetching Order Source from OE_ORDER_SOURCES for RETAIL.'); -- Added for 1.5.
            fnd_file.put_line (
                fnd_file.LOG,
                'Error Code : ' || SQLCODE || '. Error Message : ' || SQLERRM); -- Added for 1.5.
    -- END : 1.5.

    END FETCH_ORDER_SOURCE;

    PROCEDURE FETCH_ORDER_TYPE (pv_ship_return IN VARCHAR2, pn_org_id IN NUMBER, pn_vw_id IN NUMBER, pn_str_nbr IN NUMBER, pn_order_type_id OUT NUMBER, pv_status OUT VARCHAR2
                                , pv_error_message OUT VARCHAR2)
    IS
        ln_order_type_id   NUMBER;
    BEGIN
        ln_order_type_id   := 0;


        BEGIN
            SELECT a.ORDER_TYPE_ID
              INTO ln_order_type_id
              FROM apps.hz_cust_site_uses_all a, apps.hz_cust_acct_sites_all b, XXD_RETAIL_STORES_V c --XXDO.XXDO_STORES c -- do_retail.stores@datamart.deckers.com c
             WHERE     1 = 1
                   AND a.site_use_code = 'BILL_TO'
                   AND a.org_id = pn_org_id
                   AND a.cust_acct_site_id = b.cust_acct_site_id
                   AND c.ra_customer_id = b.cust_account_id
                   AND a.primary_flag = 'Y'
                   AND c.rms_store_id = pn_str_nbr;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_order_type_id   := 0;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Order type Not Defined at Customer Level, Store : '
                    || pn_str_nbr);
                fnd_file.put_line (fnd_file.LOG, 'org id :' || pn_org_id);
        END;

        fnd_file.put_line (
            fnd_file.LOG,
               ' pv_ship_return : '
            || pv_ship_return
            || ' pn_org_id - '
            || pn_org_id
            || ' pn_vw_id '
            || pn_vw_id);

        IF ln_order_type_id = 0 OR ln_order_type_id IS NULL
        THEN
            SELECT ottl.transaction_type_id
              INTO ln_order_type_id
              FROM FND_LOOKUP_VALUES_VL FLV, HR_OPERATING_UNITS HOU, OE_TRANSACTION_TYPES_TL OTTL
             WHERE     FLV.lookup_type = 'XXDO_RMS_SO_RMA_ALLOCATION'
                   AND UPPER (FLV.LOOKUP_CODE) = UPPER (OTTL.NAME)
                   AND HOU.name = FLV.tag
                   AND FLV.description = pv_ship_return
                   AND HOU.organization_id = pn_org_id
                   AND OTTL.language = 'US'
                   AND flv.ENABLED_FLAG = 'Y'
                   -- AND FLV.language = 'US';
                   AND FLV.ATTRIBUTE_CATEGORY = 'XXDO_RMS_SO_RMA_ALLOCATION'
                   AND (FLV.ATTRIBUTE11 = pn_vw_id OR FLV.ATTRIBUTE9 = pn_vw_id OR FLV.ATTRIBUTE2 = pn_vw_id OR FLV.ATTRIBUTE1 = pn_vw_id OR FLV.ATTRIBUTE3 = pn_vw_id OR FLV.ATTRIBUTE4 = pn_vw_id OR FLV.ATTRIBUTE5 = pn_vw_id OR FLV.ATTRIBUTE6 = pn_vw_id OR FLV.ATTRIBUTE7 = pn_vw_id OR FLV.ATTRIBUTE8 = pn_vw_id OR FLV.ATTRIBUTE10 = pn_vw_id OR FLV.ATTRIBUTE12 = pn_vw_id OR FLV.ATTRIBUTE13 = pn_vw_id OR FLV.ATTRIBUTE14 = pn_vw_id OR FLV.ATTRIBUTE15 = pn_vw_id);
        END IF;

        fnd_file.put_line (fnd_file.LOG, 'org id :' || ln_order_type_id);
        pn_order_type_id   := ln_order_type_id;
        pv_status          := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.PUT_LINE (
                'Error while Fetching Order Source Information :' || SQLERRM);
            pv_status   := 'E';
            pv_error_message   :=
                   'Error while Fetching Order Source Information :'
                || 'ORG : '
                || pn_org_id
                || 'VW : '
                || pn_vw_id
                || SQLERRM;
            -- START : 1.5.
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error while fetching Transaction Type from lookup : XXDO_RMS_SO_RMA_ALLOCATION for Virtual Warehouse : '
                || pn_vw_id
                || ', PV_SHIP_RETURN : '
                || pv_ship_return
                || ', PN_ORG_ID : '
                || pn_org_id);
            fnd_file.put_line (
                fnd_file.LOG,
                'Error Code : ' || SQLCODE || '. Error Message : ' || SQLERRM);
    -- END : 1.5.

    END FETCH_ORDER_TYPE;

    PROCEDURE FETCH_ITEM_BRAND (pn_dc_dest_id      IN     NUMBER,
                                pn_item_id         IN     NUMBER,
                                pv_item_brand         OUT VARCHAR2,
                                pv_status             OUT VARCHAR2,
                                pv_error_message      OUT VARCHAR2)
    IS
        lv_item_brand   VARCHAR2 (10);
    BEGIN
        SELECT MC.SEGMENT1
          INTO lv_item_brand
          FROM MTL_ITEM_CATEGORIES MIC, MTL_CATEGORIES MC, MTL_CATEGORY_SETS_TL MCS
         WHERE     MIC.CATEGORY_ID = MC.CATEGORY_ID
               AND MCS.CATEGORY_SET_ID = MIC.CATEGORY_SET_ID
               AND MIC.INVENTORY_ITEM_ID = pn_item_id
               AND MIC.ORGANIZATION_ID = pn_dc_dest_id
               AND UPPER (MCS.CATEGORY_SET_NAME) = 'INVENTORY'
               --AND MC.STRUCTURE_ID = 101
               AND MC.STRUCTURE_ID = (SELECT structure_id
                                        FROM mtl_category_sets
                                       WHERE category_set_name = 'Inventory') ----W.r.t version 1.2
               AND MCS.LANGUAGE = 'US';


        pv_status       := 'S';
        pv_item_brand   := lv_item_brand;
    EXCEPTION
        WHEN OTHERS
        THEN
            /*  DBMS_OUTPUT.PUT_LINE('Error while Fetching Order Source Information :'|| SQLERRM);
                pv_status  := 'E';
                pv_error_message := 'Error while Fetching Order Source Information :'|| SQLERRM; */
            -- Commented for 1.5.

            -- START : 1.5.
            DBMS_OUTPUT.PUT_LINE (
                   'Error while fetching Item Brand for Item : '
                || pn_item_id
                || ', Organization : '
                || pn_dc_dest_id
                || '. Error : '
                || SQLERRM);
            pv_status   := 'E';
            pv_error_message   :=
                   'Error while fetching Item Brand for Item : '
                || pn_item_id
                || ', Organization : '
                || pn_dc_dest_id
                || '. Error : '
                || SQLERRM;

            fnd_file.put_line (
                fnd_file.LOG,
                   'Error while fetching Item Brand for Item : '
                || pn_item_id
                || ', Organization : '
                || pn_dc_dest_id);
            fnd_file.put_line (
                fnd_file.LOG,
                'Error Code : ' || SQLCODE || '. Error Message : ' || SQLERRM);
    -- END : 1.5.

    END FETCH_ITEM_BRAND;

    PROCEDURE PRINT_AUDIT_REPORT
    AS
        CURSOR cur_print_audit_e IS
              SELECT X28_2.ROWID, X28_2.*
                FROM XXDO_INV_INT_028_STG2 X28_2
               WHERE     X28_2.REQUEST_ID = FND_GLOBAL.CONC_REQUEST_ID
                     AND STATUS = 2
            ORDER BY x28_2.SEQ_NO, x28_2.FROM_LOCATION, X28_2.TO_LOCATION,
                     X28_2.ITEM_ID;

        CURSOR cur_print_iface_e1 IS
              SELECT OPM.Original_sys_document_ref
                FROM oe_processing_msgs OPM, oe_processing_msgs_tl OPMT, OE_ORDER_SOURCES OOS,
                     oe_headers_iface_all ohi, xxdo_inv_int_028_stg2 X28_2
               WHERE     OPM.transaction_id = OPMT.transaction_id
                     AND ohi.ORIG_SYS_DOCUMENT_REF =
                         OPM.ORIGINAL_SYS_DOCUMENT_REF
                     AND OOS.order_source_id = OHI.order_source_id
                     AND UPPER (OOS.NAME) LIKE 'RETAIL'
                     AND SUBSTR (OPM.Original_sys_document_ref,
                                 1,
                                   INSTR (OPM.Original_sys_document_ref, '-', 1
                                          , 3)
                                 - 1) =
                            'RMS'
                         || '-'
                         || X28_2.FROM_LOCATION
                         || '-'
                         || X28_2.TO_LOCATION
                     AND OHI.ATTRIBUTE5 = X28_2.BRAND
                     AND OPMT.language = 'US'
                     AND NVL (OHI.ERROR_FLAG, 'N') = 'Y'
                     AND X28_2.REQUEST_ID = FND_GLOBAL.CONC_REQUEST_ID
            GROUP BY OPM.Original_sys_document_ref;

        CURSOR cur_print_iface_e2 (cv_doc_ref VARCHAR2)
        IS
              SELECT OPM.Original_sys_document_ref, OPMT.MESSAGE_TEXT, X28_2.*
                FROM oe_processing_msgs OPM, oe_processing_msgs_tl OPMT, oe_order_sources OOS,
                     oe_headers_iface_all ohi, xxdo_inv_int_028_stg2 X28_2
               WHERE     OPM.transaction_id = OPMT.transaction_id
                     AND ohi.ORIG_SYS_DOCUMENT_REF =
                         OPM.ORIGINAL_SYS_DOCUMENT_REF
                     AND OOS.order_source_id = OHI.order_source_id
                     AND UPPER (OOS.NAME) LIKE 'RETAIL'
                     AND SUBSTR (OPM.Original_sys_document_ref,
                                 1,
                                   INSTR (OPM.Original_sys_document_ref, '-', 1
                                          , 3)
                                 - 1) =
                            'RMS'
                         || '-'
                         || X28_2.FROM_LOCATION
                         || '-'
                         || X28_2.TO_LOCATION
                     AND OHI.ATTRIBUTE5 = X28_2.BRAND
                     AND OPMT.language = 'US'
                     AND NVL (OHI.ERROR_FLAG, 'N') = 'Y'
                     AND X28_2.REQUEST_ID = FND_GLOBAL.CONC_REQUEST_ID
                     AND OPM.Original_sys_document_ref = cv_doc_ref
            ORDER BY x28_2.SEQ_NO, x28_2.FROM_LOCATION, x28_2.TO_LOCATION,
                     x28_2.ITEM_ID, OPMT.MESSAGE_TEXT;

        CURSOR cur_print_audit_s1 IS
              SELECT x28_2.FROM_LOCATION, x28_2.TO_LOCATION, X28_2.PO_NBR,
                     x28_2.BRAND
                FROM XXDO_INV_INT_028_STG2 x28_2
               WHERE     x28_2.REQUEST_ID = FND_GLOBAL.CONC_REQUEST_ID
                     AND STATUS = 1
            GROUP BY x28_2.FROM_LOCATION, x28_2.TO_LOCATION, x28_2.PO_NBR,
                     x28_2.BRAND
            ORDER BY x28_2.FROM_LOCATION, x28_2.TO_LOCATION, X28_2.PO_NBR,
                     x28_2.BRAND;

        CURSOR cur_print_audit_s2 (cv_to_location NUMBER, cv_from_location NUMBER, cv_po_nbr NUMBER
                                   , cv_brand VARCHAR2)
        IS
              SELECT X28_2.ROWID, X28_2.*
                FROM XXDO_INV_INT_028_STG2 X28_2
               WHERE     X28_2.REQUEST_ID = FND_GLOBAL.CONC_REQUEST_ID
                     AND X28_2.STATUS = 1
                     AND X28_2.to_location = cv_to_location
                     AND X28_2.from_location = cv_from_location
                     AND X28_2.BRAND = cv_brand
            ORDER BY X28_2.SEQ_NO, X28_2.FROM_LOCATION, X28_2.TO_LOCATION,
                     X28_2.ITEM_ID;

        CURSOR cur_chk_order_schedule IS
              SELECT X28_2.*
                FROM OE_ORDER_HEADERS_ALL OEH, OE_ORDER_LINES_ALL OEL, OE_ORDER_SOURCES OES,
                     XXDO_INV_INT_028_STG2 X28_2
               WHERE     OEH.HEADER_ID = OEL.HEADER_ID
                     AND OEH.ORDER_SOURCE_ID = OES.ORDER_SOURCE_ID
                     AND X28_2.DISTRO_NBR = SUBSTR (OEL.ORIG_SYS_LINE_REF,
                                                    1,
                                                      INSTR (OEL.ORIG_SYS_LINE_REF, '-', 1
                                                             , 1)
                                                    - 1)
                     AND    'RMS'
                         || '-'
                         || X28_2.FROM_LOCATION
                         || '-'
                         || X28_2.TO_LOCATION =
                         SUBSTR (OEL.ORIG_SYS_DOCUMENT_REF,
                                 1,
                                   INSTR (OEL.ORIG_SYS_DOCUMENT_REF, '-', 1,
                                          3)
                                 - 1)
                     --        AND NVL(X28_2.SCHEDULE_CHECK, 'N') <> 'Y'
                     AND NVL (X28_2.STATUS, 0) = 1
                     AND UPPER (OES.NAME) = 'RETAIL'
            ORDER BY OEH.ORDER_NUMBER, OEL.LINE_NUMBER;
    BEGIN
        /*Report for Errored REcords */
        fnd_file.put_line (
            fnd_file.OUTPUT,
            '*********************************** Errored in Staging ********************************');
        fnd_file.put_line (
            fnd_file.OUTPUT,
               RPAD ('Seq No', 8)
            || RPAD ('Distro Number', 15)
            || RPAD ('D Type', 8)
            || RPAD ('DC Dest ID', 12)
            || RPAD ('Dest ID', 10)
            || RPAD ('Brand ', 8)
            || RPAD ('Item ID', 10)
            || RPAD ('Error Message', 250));

        FOR rec_x26_e IN cur_print_audit_e
        LOOP
            fnd_file.put_line (
                fnd_file.OUTPUT,
                   RPAD (rec_x26_e.seq_no, 8)
                || RPAD (rec_x26_e.distro_nbr, 15)
                || RPAD (rec_x26_e.distro_doc_type, 8)
                || RPAD (rec_x26_e.to_location, 12)
                || RPAD (rec_x26_e.to_location, 10)
                || RPAD (rec_x26_e.brand, 8)
                || RPAD (rec_x26_e.item_id, 10)
                || RPAD (rec_x26_e.error_message, 250));
        END LOOP;

        fnd_file.put_line (fnd_file.OUTPUT, ' ');
        fnd_file.put_line (fnd_file.OUTPUT, ' ');

        /*Report for Processed Records */
        fnd_file.put_line (
            fnd_file.OUTPUT,
            '************************************ Processed from Staging ***********************************');
        fnd_file.put_line (
            fnd_file.OUTPUT,
               RPAD ('Seq No', 8)
            || RPAD ('Distro Number', 15)
            || RPAD ('D Type', 8)
            || RPAD ('To Location', 12)
            || RPAD ('From Loc', 10)
            || RPAD ('Brand ', 8)
            || RPAD ('Item ID', 10));

        FOR rec_x26_S1 IN cur_print_audit_s1
        LOOP
            FOR rec_x26_S2 IN cur_print_audit_s2 (rec_x26_S1.to_location, rec_x26_S1.from_location, rec_x26_S1.po_nbr
                                                  , rec_x26_S1.brand)
            LOOP
                fnd_file.put_line (
                    fnd_file.OUTPUT,
                       RPAD (rec_x26_s2.seq_no, 8)
                    || RPAD (rec_x26_s2.distro_nbr, 15)
                    || RPAD (rec_x26_s2.distro_doc_type, 8)
                    || RPAD (rec_x26_s2.to_location, 12)
                    || RPAD (rec_x26_s2.from_location, 10)
                    || RPAD (rec_x26_s2.brand, 8)
                    || RPAD (rec_x26_s2.item_id, 10));
            END LOOP;

            fnd_file.put_line (fnd_file.OUTPUT, '--- ');
            fnd_file.put_line (fnd_file.OUTPUT, '--- ');
        END LOOP;


        /*Report for Errored REcords */
        fnd_file.put_line (
            fnd_file.OUTPUT,
            '****************************************************************************************');
        fnd_file.put_line (
            fnd_file.OUTPUT,
            '*********************************** Errored From Order Import ********************************');
        fnd_file.put_line (
            fnd_file.OUTPUT,
            '****************************************************************************************');

        FOR rec_print_iface_e1 IN cur_print_iface_e1
        LOOP
            fnd_file.put_line (fnd_file.OUTPUT, '--- ');
            fnd_file.put_line (
                fnd_file.OUTPUT,
                'Document Reference ::' || rec_print_iface_e1.Original_sys_document_ref);
            fnd_file.put_line (fnd_file.OUTPUT, '--- ');
            fnd_file.put_line (
                fnd_file.OUTPUT,
                   RPAD ('Seq No', 8)
                || RPAD ('Distro Number', 15)
                || RPAD ('D Type', 8)
                || RPAD ('To Location', 12)
                || RPAD ('From Loc', 10)
                || RPAD ('Brand ', 8)
                || RPAD ('Item ID', 10)
                || RPAD ('Error Message', 250));

            FOR rec_print_iface_e2
                IN cur_print_iface_e2 (
                       rec_print_iface_e1.Original_sys_document_ref)
            LOOP
                fnd_file.put_line (
                    fnd_file.OUTPUT,
                       RPAD (rec_print_iface_e2.seq_no, 8)
                    || RPAD (rec_print_iface_e2.distro_nbr, 15)
                    || RPAD (rec_print_iface_e2.distro_doc_type, 8)
                    || RPAD (rec_print_iface_e2.to_location, 12)
                    || RPAD (rec_print_iface_e2.from_location, 10)
                    || RPAD (rec_print_iface_e2.brand, 8)
                    || RPAD (rec_print_iface_e2.item_id, 10)
                    || RPAD (rec_print_iface_e2.MESSAGE_TEXT, 250));
            END LOOP;
        END LOOP;
    END PRINT_AUDIT_REPORT;

    PROCEDURE SO_CANCEL_PRC (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_header_id IN NUMBER
                             , p_line_id IN NUMBER, p_status OUT VARCHAR2)
    AS
        /*******************************************************************************************
        --*  NAME       : geun_ont_bmso_so_cancel_prc
        --*  APPLICATION: Oracle Order Management
        --*
        --*  AUTHOR     : Sivakumar Boothathan(TCS)
        --*  DATE       : 30-Sep-2011
        --*
        --*  DESCRIPTION: This procedure is used to cancel the sales order lines
        --*               The input is the project number from the user
        --*               The program will have a cursor which is used to extract on all the open lines
        --*               These lines will be sent to the API which will cancel the sales orders
        --*
        --*  REVISION HISTORY:
        --*  Change Date                         By                              Change Description
        --*  30-Sep-2011              Sivakumar Boothathan(TCS)                  Initial Creation
        **********************************************************************************************/
        v_header_id                NUMBER := p_header_id;
        v_order_number             NUMBER := 0;
        v_line_id                  NUMBER := p_line_id;
        v_line_number              NUMBER := 0;
        v_project_number           NUMBER := 0;
        --   v_project_id                                   number       := p_project_id   ;
        x_msg_count                NUMBER (20);
        x_msg_data                 VARCHAR2 (1000);
        v_msg_data                 VARCHAR2 (8000);
        v_msg_index_out            NUMBER;
        x_return_status            VARCHAR2 (1000);
        x_header_rec               Oe_Order_Pub.Header_Rec_Type;
        x_header_val_rec           Oe_Order_Pub.Header_Val_Rec_Type;
        x_Header_Adj_tbl           Oe_Order_Pub.Header_Adj_Tbl_Type;
        x_Header_Adj_val_tbl       Oe_Order_Pub.Header_Adj_Val_Tbl_Type;
        x_Header_price_Att_tbl     Oe_Order_Pub.Header_Price_Att_Tbl_Type;
        x_Header_Adj_Att_tbl       Oe_Order_Pub.Header_Adj_Att_Tbl_Type;
        x_Header_Adj_Assoc_tbl     Oe_Order_Pub.Header_Adj_Assoc_Tbl_Type;
        x_Header_Scredit_tbl       Oe_Order_Pub.Header_Scredit_Tbl_Type;
        x_Header_Scredit_val_tbl   Oe_Order_Pub.Header_Scredit_Val_Tbl_Type;
        x_line_tbl                 Oe_Order_Pub.Line_Tbl_Type;
        x_line_val_tbl             Oe_Order_Pub.Line_Val_Tbl_Type;
        x_Line_Adj_tbl             Oe_Order_Pub.Line_Adj_Tbl_Type;
        x_Line_Adj_val_tbl         Oe_Order_Pub.Line_Adj_Val_Tbl_Type;
        x_Line_price_Att_tbl       Oe_Order_Pub.Line_Price_Att_Tbl_Type;
        x_Line_Adj_Att_tbl         Oe_Order_Pub.Line_Adj_Att_Tbl_Type;
        x_Line_Adj_Assoc_tbl       Oe_Order_Pub.Line_Adj_Assoc_Tbl_Type;
        x_Line_Scredit_tbl         Oe_Order_Pub.Line_Scredit_Tbl_Type;
        x_Line_Scredit_val_tbl     Oe_Order_Pub.Line_Scredit_Val_Tbl_Type;
        x_Lot_Serial_tbl           Oe_Order_Pub.Lot_Serial_Tbl_Type;
        x_Lot_Serial_val_tbl       Oe_Order_Pub.Lot_Serial_Val_Tbl_Type;
        x_action_request_tbl       Oe_Order_Pub.Request_Tbl_Type;
        x_header_rec2              Oe_Order_Pub.Header_Rec_Type;
        x_line_tbl2                Oe_Order_Pub.Line_Tbl_Type;
        x_line_tbl_null            Oe_Order_Pub.Line_Tbl_Type;
        x_header_rec_null          Oe_Order_Pub.Header_Rec_Type;
        x_debug_file               VARCHAR2 (100);
        v_message_index            NUMBER := 1;

        -------------------------------------------------
        -- Select query to get the header_id, order_number
        -- Line_id, line_number and proejct_number
        -------------------------------------------------
        CURSOR cur_cancel_so IS
            SELECT oha.header_id Header_id, oha.order_number Order_Number, ola.line_id Line_id,
                   ola.line_number || '.' || ola.shipment_number Line_Number
              FROM apps.oe_order_headers_all OHA, apps.oe_order_lines_all OLA, apps.mtl_system_items MSI
             WHERE     OLA.header_id = OHA.header_id
                   AND OLA.ship_from_org_id = MSI.organization_id
                   AND OLA.inventory_item_id = MSI.inventory_item_id
                   AND NVL (OLA.open_flag, 'N') = 'Y'
                   AND OLA.LINE_ID = NVL (p_line_id, OLA.line_id)
                   AND OHA.HEADER_ID = NVL (p_header_id, OHA.header_id)--AND OLA.line_id = 277130
                                                                       ;
    -------------------------
    -- Begin of the procedure
    -------------------------
    BEGIN
        --------------------------------------------------------------------------------------------
        -- Begin loop to vary value of the index from 1 to cursor variable : geun_bmso_cancel_so
        --------------------------------------------------------------------------------------------
        FOR rec_cancel_so IN cur_cancel_so
        LOOP
            ----------------------------------
            -- Assigning the value to the loop
            ----------------------------------
            v_header_id      := rec_cancel_so.header_id;
            v_order_number   := rec_cancel_so.order_number;
            v_line_id        := rec_cancel_so.line_id;
            v_line_number    := rec_cancel_so.line_number;

            --         v_project_number  :=  rec_cancel_so.project_number         ;
            BEGIN
                --         fnd_client_info.set_org_context(102);
                oe_debug_pub.initialize;
                oe_debug_pub.SetDebugLevel (1);
                X_DEBUG_FILE                       := OE_DEBUG_PUB.Set_Debug_Mode ('TABLE');
                x_line_tbl2                        := x_line_tbl_null;
                x_line_tbl2 (1)                    := oe_order_pub.g_miss_line_rec;
                x_line_tbl2 (1).line_id            := v_line_id;
                x_line_tbl2 (1).cancelled_flag     := 'Y';
                x_line_tbl2 (1).ordered_quantity   := 0;
                x_line_tbl2 (1).change_reason      := 'SYSTEM';
                x_line_tbl2 (1).operation          := Oe_Globals.g_opr_update;
                Oe_Order_Pub.Process_Order (
                    p_api_version_number       => 1.0,
                    p_init_msg_list            => fnd_api.g_false,
                    p_return_values            => fnd_api.g_false,
                    p_action_commit            => fnd_api.g_false,
                    x_return_status            => x_return_status,
                    x_msg_count                => x_msg_count,
                    x_msg_data                 => x_msg_data,
                    p_line_tbl                 => x_line_tbl2,
                    x_header_rec               => x_header_rec,
                    x_header_val_rec           => x_header_val_rec,
                    x_Header_Adj_tbl           => x_Header_Adj_tbl,
                    x_Header_Adj_val_tbl       => x_Header_Adj_val_tbl,
                    x_Header_price_Att_tbl     => x_Header_price_Att_tbl,
                    x_Header_Adj_Att_tbl       => x_Header_Adj_Att_tbl,
                    x_Header_Adj_Assoc_tbl     => x_Header_Adj_Assoc_tbl,
                    x_Header_Scredit_tbl       => x_Header_Scredit_tbl,
                    x_Header_Scredit_val_tbl   => x_Header_Scredit_val_tbl,
                    x_line_tbl                 => x_line_tbl,
                    x_line_val_tbl             => x_line_val_tbl,
                    x_Line_Adj_tbl             => x_Line_Adj_tbl,
                    x_Line_Adj_val_tbl         => x_Line_Adj_val_tbl,
                    x_Line_price_Att_tbl       => x_Line_price_Att_tbl,
                    x_Line_Adj_Att_tbl         => x_Line_Adj_Att_tbl,
                    x_Line_Adj_Assoc_tbl       => x_Line_Adj_Assoc_tbl,
                    x_Line_Scredit_tbl         => x_Line_Scredit_tbl,
                    x_Line_Scredit_val_tbl     => x_Line_Scredit_val_tbl,
                    x_Lot_Serial_tbl           => x_Lot_Serial_tbl,
                    x_Lot_Serial_val_tbl       => x_Lot_Serial_val_tbl,
                    x_action_request_tbl       => x_action_request_tbl);
                COMMIT;
            END;

            ---------------------------------------------------------------------------------
            -- IF the API returns Error then the error message is displayed in log to track
            ---------------------------------------------------------------------------------
            IF ((x_return_status = 'E') OR (x_return_status = 'U'))
            THEN
                ROLLBACK;
                p_status   := 'E';
                oe_Msg_Pub.get (p_msg_index => v_message_index, p_encoded => Fnd_Api.G_FALSE, p_data => v_msg_data
                                , p_msg_index_out => v_msg_index_out);
                fnd_file.put_line (
                    fnd_file.LOG,
                    'The Error Message Count is :-' || v_msg_index_out);
                fnd_file.put_line (fnd_file.LOG,
                                   'The Error Message is :-' || v_msg_data);
                DBMS_OUTPUT.PUT_LINE (
                    'The Error Message is :-' || v_msg_data);
                COMMIT;
                fnd_file.put_line (
                    fnd_file.output,
                    '*******************************************************');
                fnd_file.put_line (fnd_file.output, 'Failure');
                fnd_file.put_line (
                    fnd_file.output,
                    'The Sales Order Number :' || v_order_number);
                fnd_file.put_line (
                    fnd_file.output,
                    'The Sales Order Line Number :' || v_Line_number);
                fnd_file.put_line (
                    fnd_file.output,
                    'The Error Message Count:' || v_msg_index_out);
                fnd_file.put_line (fnd_file.output,
                                   'The Error Message Data:' || v_msg_data);
            ELSIF (x_return_status = 'S')
            THEN
                COMMIT;
                p_status   := 'S';
                fnd_file.put_line (
                    fnd_file.output,
                    '*******************************************************');
                fnd_file.put_line (fnd_file.output, 'Success');
                DBMS_OUTPUT.put_line ('Success');
                fnd_file.put_line (
                    fnd_file.output,
                    'The Sales Order Number :' || v_order_number);
                fnd_file.put_line (
                    fnd_file.output,
                    'The Sales Order Line Number :' || v_Line_number);
            END IF;
        END LOOP;
    END SO_CANCEL_PRC;

    PROCEDURE CHK_ORDER_SCHEDULE (errbuf OUT VARCHAR2, retcode OUT VARCHAR2)
    AS
        CURSOR cur_chk_order_schedule IS
              SELECT /*+ INDEX(OES OE_ORDER_SOURCES_U1) */
                     DISTINCT OEH.ORDER_NUMBER, OEH.HEADER_ID, OEL.LINE_NUMBER || '.' || OEL.SHIPMENT_NUMBER ORDER_LINE_NUM,
                              OEL.LINE_ID, X26_2.DISTRO_NUMBER, X26_2.DEST_ID,
                              X26_2.DC_DEST_ID, X26_2.DOCUMENT_TYPE, X26_2.REQUESTED_QTY,
                              X26_2.XML_ID, OEL.SCHEDULE_STATUS_CODE, OEH.BOOKED_FLAG,
                              OEL.INVENTORY_ITEM_ID, DECODE (OEL.SCHEDULE_STATUS_CODE, 'SCHEDULED', 'DS', 'NI') STATUS, X26_2.ROWID
                FROM OE_ORDER_HEADERS_ALL OEH, OE_ORDER_LINES_ALL OEL, OE_ORDER_SOURCES OES,
                     XXDO_INV_INT_026_STG2 X26_2
               WHERE     OEH.HEADER_ID = OEL.HEADER_ID
                     AND OEH.ORDER_SOURCE_ID = OES.ORDER_SOURCE_ID
                     AND X26_2.DISTRO_NUMBER = SUBSTR (OEL.ORIG_SYS_LINE_REF,
                                                       1,
                                                         INSTR (OEL.ORIG_SYS_LINE_REF, '-', 1
                                                                , 1)
                                                       - 1)
                     AND    'RMS'
                         || '-'
                         || X26_2.DEST_ID
                         || '-'
                         || X26_2.DC_DEST_ID =
                         SUBSTR (OEH.ORIG_SYS_DOCUMENT_REF,
                                 1,
                                   INSTR (OEH.ORIG_SYS_DOCUMENT_REF, '-', 1,
                                          3)
                                 - 1)
                     AND X26_2.ITEM_ID = OEL.INVENTORY_ITEM_ID
                     AND NVL (X26_2.SCHEDULE_CHECK, 'N') <> 'Y'
                     AND NVL (X26_2.STATUS, 0) = 1
                     --        AND NVL(OEH.BOOKED_FLAG, 'N') = 'Y'
                     AND NVL (OEL.CANCELLED_FLAG, 'N') = 'N'
                     AND UPPER (OES.NAME) = 'RETAIL'
                     AND TRUNC (OEH.CREATION_DATE) = TRUNC (SYSDATE)
            ORDER BY OEH.ORDER_NUMBER, OEL.LINE_NUMBER || '.' || OEL.SHIPMENT_NUMBER;

        lv_errbuf          VARCHAR2 (100);
        lv_retcode         VARCHAR2 (100);

        lv_cancel_status   VARCHAR2 (1) := 'S';
    BEGIN
        fnd_file.put_line (
            fnd_file.OUTPUT,
            '*******************************************************************');
        fnd_file.put_line (
            fnd_file.OUTPUT,
               RPAD ('Order Num', 10)
            || RPAD ('Line Num', 9)
            || RPAD ('Distro Number', 15)
            || RPAD ('Qty', 7)
            || RPAD ('Book Flag', 10)
            || RPAD ('Sch Status ', 11)
            || RPAD ('Status', 20));

        FOR rec_order_sch IN cur_chk_order_schedule
        LOOP
            IF rec_order_sch.STATUS = 'DS'
            THEN
                xxdo_int_009_prc (lv_errbuf,
                                  lv_retcode,
                                  rec_order_sch.dc_dest_id,
                                  rec_order_sch.distro_number,
                                  rec_order_sch.document_type,
                                  rec_order_sch.distro_number,
                                  rec_order_sch.dest_id,
                                  rec_order_sch.inventory_item_id,
                                  rec_order_sch.ORDER_lINE_NUM,
                                  rec_order_sch.REQUESTED_QTY,
                                  rec_order_sch.status);

                fnd_file.put_line (
                    fnd_file.OUTPUT,
                       RPAD (rec_order_sch.order_number, 10)
                    || RPAD (rec_order_sch.order_line_num, 9)
                    || RPAD (rec_order_sch.distro_number, 15)
                    || RPAD (rec_order_sch.requested_qty, 7)
                    || RPAD (rec_order_sch.booked_flag, 10)
                    || RPAD (rec_order_sch.schedule_status_code, 11)
                    || RPAD (rec_order_sch.status, 10));
            ELSIF rec_order_sch.STATUS = 'NI'
            THEN
                SO_CANCEL_PRC (lv_errbuf, lv_retcode, rec_order_sch.header_id
                               , rec_order_sch.line_id, lv_cancel_status);

                IF NVL (lv_cancel_status, 'E') = 'S'
                THEN
                    fnd_file.put_line (
                        fnd_file.OUTPUT,
                           RPAD (rec_order_sch.order_number, 10)
                        || RPAD (rec_order_sch.order_line_num, 9)
                        || RPAD (rec_order_sch.distro_number, 15)
                        || RPAD (rec_order_sch.requested_qty, 7)
                        || RPAD (rec_order_sch.booked_flag, 10)
                        || RPAD (rec_order_sch.schedule_status_code, 11)
                        || RPAD ('Cancelled', 10));


                    xxdo_int_009_prc (lv_errbuf,
                                      lv_retcode,
                                      rec_order_sch.dc_dest_id,
                                      rec_order_sch.distro_number,
                                      rec_order_sch.document_type,
                                      rec_order_sch.distro_number,
                                      rec_order_sch.dest_id,
                                      rec_order_sch.INVENTORY_ITEM_ID,
                                      rec_order_sch.order_line_num,
                                      rec_order_sch.REQUESTED_QTY,
                                      rec_order_sch.status);

                    fnd_file.put_line (
                        fnd_file.OUTPUT,
                           RPAD (rec_order_sch.order_number, 10)
                        || RPAD (rec_order_sch.order_line_num, 9)
                        || RPAD (rec_order_sch.distro_number, 15)
                        || RPAD (rec_order_sch.requested_qty, 7)
                        || RPAD (rec_order_sch.booked_flag, 10)
                        || RPAD (rec_order_sch.schedule_status_code, 11)
                        || RPAD (rec_order_sch.status, 10));
                END IF;
            END IF;

            UPDATE XXDO_INV_INT_026_STG2 X26_2
               SET SCHEDULE_CHECK   = 'Y'
             WHERE X26_2.ROWID = rec_order_sch.ROWID;
        END LOOP;

        fnd_file.put_line (
            fnd_file.OUTPUT,
            '*******************************************************************');
    END CHK_ORDER_SCHEDULE;
END xxdo_om_int_028_stg_pkg;
/
