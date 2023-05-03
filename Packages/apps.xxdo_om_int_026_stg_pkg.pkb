--
-- XXDO_OM_INT_026_STG_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:32 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_OM_INT_026_STG_PKG"
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
    Version       Pointer         SCN#   By                      Date              Comments
    1.0                                                   05-Apr-2012       Initial Version
    ****************************************************************************************************************************************
    1.1    100      INC0124362  C.M.Barath Kumar         15-Oct-2012        Interface Line Insert Cursor fixed
    1.2    200      C.M.Barath Kumar                 11-Nov-2012         Regional Parameter added
    1.3    300       Parameters:
    1.4    400      PO threshold enhancement                  12-Sep-2014        cmbarathkumar
    1.5    500      BT Changes                                03-Dec-2014        Infosys
    1.6    600      Fix Sit defect# 1119                      23-Mar-2015        Infosys
    1.7    700      Modified for Pricelist                    30-Mar-2015        Infosys
    1.8             Modified to implement the Canada
                      Virtual Warehouse change. Defect ID 958      17-Apr-2015     Infosys
    1.9             To remove KCO object reference and to remove
                      CHANNEL check in VW map                     14-May-2015     Infosys
    2.0             BT Improvements - Modified log messages.        10-Jul-2015     Infosys.
    2.1             Modified to NOT populate Ship From Warehouse
                    for defaulting rules to take care.            25-Aug-2015     Infosys.
    2.2             Modified to rollback CR12 changes(Ver 2.1)    30-Sep-2015    Infosys
    2.3             Modified for FND_ILE issue                    12-May-2016    Infosys
    2.4             Added org_id condition to the cursors         28-Jul-2016    Kranthi Bollam
                    in chk_order_schedule procedure to pick OU
                    specific records(CCR#CCR0005299)
    2.5              Added the Profile option for restricting the      06-Feb-2016    Infosys
                     debug messages
    2.6            Added the Parallel hint in the cursor                07-Apr-2016      Infosys
    2.7            Changes for Replenishment Automation CCR0007197        03-May-2018        Middleware
    ***************************************************************************************************************************************/

    --PROCEDURE load_xml_data (retcode OUT VARCHAR2, errbuf OUT VARCHAR2); -- W.r.t Version 1.6
    PROCEDURE load_xml_data (errbuf OUT VARCHAR2, retcode OUT NUMBER)
    -- W.r.t Version 1.6
    AS
        /* Removing NameSpaces in XML Data */
        CURSOR cur_rem_space_data                         -- W.r.t Version 1.6
                                  IS
            SELECT *
              FROM xxdo.xxdo_inv_int_026_stg1 x26
             WHERE x26.status = 0 AND update_timestamp > TRUNC (SYSDATE - 7);

        /*Cursor to Parse XML Elements */
        CURSOR cur_xml_data IS
                             SELECT x26.ROWID, x26.xml_id, x261.*,
                                    x262.*
                               FROM xxdo.xxdo_inv_int_026_stg1 x26,
                                    XMLTABLE (
                                        '//SODesc'
                                        PASSING X26.XML_TYPE_DATA
                                        COLUMNS distro_nbr              VARCHAR2 (4000) PATH '/SODesc/distro_nbr', document_type           VARCHAR2 (4000) PATH '/SODesc/document_type', dc_dest_id              VARCHAR2 (4000) PATH '/SODesc/dc_dest_id',
                                                order_type              VARCHAR2 (4000) PATH '/SODesc/order_type', pick_not_before_date    VARCHAR2 (4000) PATH '/SODesc/pick_not_before_date', pick_not_after_date     VARCHAR2 (4000) PATH '/SODesc/pick_not_after_date')
                                    X261,
                                    XMLTABLE (
                                        '//SODesc/SODtlDesc'
                                        PASSING X26.XML_TYPE_DATA
                                        COLUMNS dest_id                 VARCHAR2 (4000) PATH '/SODtlDesc/dest_id', item_id                 VARCHAR2 (4000) PATH '/SODtlDesc/item_id', requested_unit_qty      VARCHAR2 (4000) PATH '/SODtlDesc/requested_unit_qty',
                                                retail_price            VARCHAR2 (4000) PATH '/SODtlDesc/retail_price', selling_uom             VARCHAR2 (4000) PATH '/SODtlDesc/selling_uom', store_ord_mult          VARCHAR2 (4000) PATH '/SODtlDesc/store_ord_mult',
                                                expedite_flag           VARCHAR2 (4000) PATH '/SODtlDesc/expedite_flag')
                                    X262
                              WHERE     x26.status = 0
                                    AND update_timestamp >
                                        TRUNC (SYSDATE - 7);

        lv_loop_counter      NUMBER := 0;
        lv_success           VARCHAR2 (1) := 'N';
        l_vw_id              NUMBER;
        ln_count             NUMBER;
        lv_dist_status       NUMBER;
        ln_organization_id   NUMBER;                                     --1.5
        l_num_org_id         NUMBER;                                    -- 1.5
    BEGIN
        FOR rec_rem_space_data IN cur_rem_space_data      -- W.r.t Version 1.6
        LOOP
            BEGIN
                -- Update Statement to update the XML_TYPE_DATA column after removing namespace information from XML
                UPDATE xxdo_inv_int_026_stg1 x26
                   SET xml_type_data = XMLTYPE (SUBSTR (xml_data, 1, INSTR (xml_data, 'xmlns', 1) - 2) || SUBSTR (xml_data, INSTR (xml_data, '">', 1) + 1))
                 WHERE x26.status = 0 AND xml_id = rec_rem_space_data.xml_id;
            -- W.r.t Version 1.6
            -- and trunc(Update_Timestamp) >= trunc(sysdate-2);
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    /* fnd_file.put_line
                          (fnd_file.LOG,
                              'No Data Found Error When Removing NameSpaces in XML Data for XML ID :'
                           || rec_rem_space_data.xml_id
                          );
                       fnd_file.put_line (fnd_file.LOG, 'SQL Error Code :' || SQLCODE);
                       fnd_file.put_line
                          (fnd_file.LOG,
                              'No Data Found Error When Removing NameSpaces in XML Data for XML ID : '
                           || rec_rem_space_data.xml_id
                           || SQLERRM
                          ); */
                    -- Commented for 2.0.
                    -- START : 2.0.
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'No Data Found Error When Removing NameSpaces in XML Data for XML ID :'
                        || rec_rem_space_data.xml_id);
                    -- END : 2.0.
                    ROLLBACK;
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error while Removing NameSpaces in XML Data for XML ID : '
                        || rec_rem_space_data.xml_id
                        || '  '
                        || SQLERRM);
                    fnd_file.put_line (fnd_file.LOG,
                                       'SQL Error Code :' || SQLCODE);
                    retcode   := 1;                       -- W.r.t Version 1.6
                    errbuf    :=
                           'Error while Removing NameSpaces in XML Data : for XML ID : '
                        || rec_rem_space_data.xml_id
                        || SQLERRM;                       -- W.r.t Version 1.6
            --ROLLBACK; -- W.r.t Version 1.6
            --RETURN;  -- W.r.t Version 1.6
            END;
        END LOOP;                              --RETURN;  -- W.r.t Version 1.6

        FOR rec_xml_data IN cur_xml_data
        LOOP
            /*Loop Counter to display number of XML records parsed */
            lv_loop_counter   := lv_loop_counter + 1;
            l_vw_id           := 0;
            l_num_org_id      := 0;                                     -- 1.5

            BEGIN
                SELECT wh_id
                  INTO l_vw_id
                  FROM --alc_xref@EBSDEV1_APPS_TO_RMSDEV  ---2.6 for DBlink issue
                       alc_xref@xxdo_retail_rms                          --1.5
                 --RMS13PROD.alc_xref@RMSPROD   --1.5
                 WHERE     xref_alloc_no = rec_xml_data.distro_nbr
                       AND item_id = rec_xml_data.item_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    --  fnd_file.put_line (fnd_file.LOG, 'l_vw_id ' || l_vw_id); -- Commented for 2.0.
                    -- START : 2.0.
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error Code : '
                        || SQLCODE
                        || '. Error Message : '
                        || SQLERRM);
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Unable to retrieve Virtual Warehouse ID for Distro Nbr : '
                        || rec_xml_data.distro_nbr
                        || ' and Item : '
                        || rec_xml_data.item_id);
            -- END : 2.0.
            END;

            -- Start 1.5
            BEGIN
                SELECT ORGANIZATION
                  INTO l_num_org_id
                  FROM xxdo_ebs_rms_vw_map
                 WHERE virtual_warehouse = l_vw_id -- AND channel = 'OUTLET'; -- Commented for 1.9.
                                                   AND ROWNUM = 1; -- Added for 1.9.
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_num_org_id   := NULL;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Unable to fetch Organization for Vir.Whse ID :: '
                        || l_vw_id
                        -- START : 2.0.
                        || ' :: '
                        || 'Error Code : '
                        || SQLCODE
                        || '. Error Message : '
                        -- END : 2.0.
                        || SQLERRM);
            END;

            -- End 1.5
            BEGIN
                /* 300 */
                lv_dist_status   := NULL;
                ln_count         := NULL;

                SELECT COUNT (1)
                  INTO ln_count
                  FROM xxdo_inv_int_026_stg2
                 WHERE     distro_number = rec_xml_data.distro_nbr
                       AND dest_id = rec_xml_data.dest_id
                       AND requested_qty > 0;

                IF ln_count >= 1
                THEN
                    lv_dist_status   := 99;
                ELSIF ln_count = 0
                THEN
                    lv_dist_status   := 0;
                END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lv_dist_status   := 0;
                WHEN OTHERS
                THEN
                    lv_dist_status   := 99;
            END;

            BEGIN                                    --START W.R.T VERSION 1.5
                SELECT organization_id
                  INTO ln_organization_id
                  FROM mtl_parameters
                 WHERE organization_code =
                       fnd_profile.VALUE ('XXDO: ORGANIZATION CODE');
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Error while fetching ORGANIZATION ID.');
            END;

            BEGIN
                /* Insert Statement to insert the parsed records in XXDO_INV_INT_028_STG_TBL table */
                INSERT INTO xxdo_inv_int_026_stg2 (seq_no, xml_id, distro_number, document_type, dc_dest_id, order_type, pick_not_before_date, pick_not_after_date, dest_id, item_id, requested_qty, retail_price, selling_uom, store_id_multi, expenditure_flag, status, created_by, creation_date, last_update_by, last_update_date, dc_vw_id
                                                   , CLASS, gender)
                         VALUES (
                                    xxdo_inv_int_026_seq2.NEXTVAL,
                                    rec_xml_data.xml_id,
                                    rec_xml_data.distro_nbr,
                                    rec_xml_data.document_type,
                                    l_num_org_id,
                                    -- rec_xml_data.dc_dest_id,  -- 1.5
                                    rec_xml_data.order_type,
                                    TO_DATE (
                                        SUBSTR (
                                            rec_xml_data.pick_not_before_date,
                                            1,
                                              INSTR (
                                                  rec_xml_data.pick_not_before_date,
                                                  'T',
                                                  1)
                                            - 1),
                                        'RRRR-MM-DD'),
                                    TO_DATE (
                                        SUBSTR (
                                            rec_xml_data.pick_not_after_date,
                                            1,
                                              INSTR (
                                                  rec_xml_data.pick_not_after_date,
                                                  'T',
                                                  1)
                                            - 1),
                                        'RRRR-MM-DD'),
                                    rec_xml_data.dest_id,
                                    rec_xml_data.item_id,
                                    rec_xml_data.requested_unit_qty,
                                    rec_xml_data.retail_price,
                                    rec_xml_data.selling_uom,
                                    rec_xml_data.store_ord_mult,
                                    rec_xml_data.expedite_flag,
                                    lv_dist_status,
                                    fnd_global.user_id,
                                    SYSDATE,
                                    fnd_global.user_id,
                                    SYSDATE,
                                    l_vw_id,
                                    xxdoinv006_pkg.get_ebs_class_f (
                                        rec_xml_data.item_id,
                                        ln_organization_id               --1.5
                                                          ),
                                    xxdoinv006_pkg.get_ebs_gender_f (
                                        rec_xml_data.item_id,
                                        ln_organization_id               --1.5
                                                          ));

                COMMIT;
                lv_success   := 'Y';
                fnd_file.put_line (
                    fnd_file.LOG,
                       'lv_success'
                    || ' '
                    || lv_success
                    || ' '
                    || lv_loop_counter);
            EXCEPTION
                WHEN OTHERS
                THEN
                    /* fnd_file.put_line
                                 (fnd_file.LOG,
                                  'Error while Inserting XML Elements into the table'
                                 );
                       fnd_file.put_line (fnd_file.LOG, 'SQL Error Code :' || SQLCODE);
                       fnd_file.put_line
                                 (fnd_file.LOG,
                                     'Error while Inserting XML Elements into the tab'
                                  || ' '
                                  || SQLERRM
                                 ); */
                    -- Commented for 2.0.
                    -- START : 2.0.
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Error while Inserting XML Elements into the table XXDO_INV_INT_026_STG2.');
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error Code : '
                        || SQLCODE
                        || '. Error Message : '
                        || SQLERRM);
                    -- END : 2.0.

                    ROLLBACK;
                    lv_success   := 'N';
            END;

            IF NVL (lv_success, 'N') = 'Y'
            THEN
                BEGIN
                    /*UPdate Statement to Update status to 1 after successfully parsing the XML Elements*/
                    UPDATE xxdo.xxdo_inv_int_026_stg1 x26
                       SET x26.status   = 1
                     WHERE x26.ROWID = rec_xml_data.ROWID;
                EXCEPTION
                    /* WHEN NO_DATA_FOUND
                       THEN
                          fnd_file.put_line
                             (fnd_file.LOG,
                                 'No Data Found Error When Updating Success Status into the table'
                              || SQLERRM
                             );
                          fnd_file.put_line (fnd_file.LOG,
                                             'SQL Error Code :' || SQLCODE
                                            );
                          fnd_file.put_line
                             (fnd_file.LOG,
                                 'No Data Found Error When Updating Success Status into the table :'
                              || SQLERRM
                             );
                       ROLLBACK;
                       */
                    -- Commented for 2.0. Dead Code : UPDATE statement never returns NO_DATA_FOUND exception.
                    WHEN OTHERS
                    THEN
                        /* fnd_file.put_line (fnd_file.LOG,
                                              'SQL Error Code :' || SQLCODE
                                             );
                           fnd_file.put_line
                               (fnd_file.LOG,
                                   'Error while Updating Success Status into the table'
                                || SQLERRM
                               );
                           fnd_file.put_line
                              (fnd_file.LOG,
                                  'Error while Updating Success Status into the table :'
                               || SQLERRM
                              ); */
                        -- Commented for 2.0.
                        -- START : 2.0.
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Error while Updating Success Status into the table XXDO_INV_INT_026_STG1.');
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error Code : '
                            || SQLCODE
                            || '. Error Message : '
                            || SQLERRM);
                        -- END : 2.0.
                        ROLLBACK;
                END;
            END IF;
        END LOOP;

        fnd_file.put_line (
            fnd_file.output,
            'Number of XML Records Parsed : ' || lv_loop_counter);
        fnd_file.put_line (
            fnd_file.LOG,
            'Number of XML Records Parsed : ' || lv_loop_counter);
        /*COMMITting the final changes*/
        COMMIT;
    END load_xml_data;

    PROCEDURE insert_oe_iface_tables (retcode OUT VARCHAR2, errbuf OUT VARCHAR2, pv_reprocess IN VARCHAR2, pd_rp_start_date IN DATE, pd_rp_end_date IN DATE, pv_dblink IN VARCHAR2
                                      , p_region IN VARCHAR2)
    IS
        CURSOR cur_order_lines (cn_dest_id      NUMBER,
                                cn_dc_dest_id   NUMBER,
                                cn_status       NUMBER,
                                cn_brand        VARCHAR2,
                                cn_pgroup       VARCHAR2,
                                cn_gender       VARCHAR2,
                                cn_class        VARCHAR2,
                                cn_context      VARCHAR2,
                                cn_vw_id        VARCHAR2)
        IS
            SELECT x26_2.ROWID, x26_2.*
              FROM xxdo_inv_int_026_stg2 x26_2, mtl_item_categories mic, mtl_categories_b mc,
                   mtl_category_sets_tl mcs
             WHERE     mic.category_id = mc.category_id
                   AND mcs.category_set_id = mic.category_set_id
                   AND mic.inventory_item_id = x26_2.item_id
                   AND mic.organization_id = x26_2.dc_dest_id
                   AND UPPER (mcs.category_set_name) = 'INVENTORY'
                   --AND mc.structure_id = 101
                   AND mc.structure_id =
                       (SELECT structure_id
                          FROM mtl_category_sets
                         WHERE UPPER (category_set_name) = 'INVENTORY')
                   ----W.r.t version 1.5
                   AND mcs.LANGUAGE = 'US'
                   AND x26_2.dest_id = NVL (cn_dest_id, x26_2.dest_id)
                   AND x26_2.dc_dest_id =
                       NVL (cn_dc_dest_id, x26_2.dc_dest_id)
                   AND x26_2.status = NVL (cn_status, x26_2.status)
                   AND mc.segment1 = NVL (cn_brand, mc.segment1)
                   AND mc.segment2 = NVL (cn_gender, mc.segment2)  --W.r.t 1.5
                   AND mc.segment3 = NVL (cn_pgroup, mc.segment3)  --W.r.t 1.5
                   AND mc.segment4 = NVL (cn_class, mc.segment4)
                   --AND DECODE(cn_context, NULL, '-',  X26_2.CONTEXT_CODE) = NVL(cn_context, '-')  ---- commented for INC0124362
                   AND DECODE (NVL (cn_context, '9'),
                               '9', NVL (x26_2.context_code, '9'),
                               x26_2.context_code) =
                       NVL (cn_context, '9')     --- 100 added for  INC0124362
                   AND dc_vw_id = cn_vw_id
                   -- Added by VIK on 03-SEP-2013 on DFCT0010624
                   AND x26_2.requested_qty > 0;

        CURSOR cur_so_orderby (x_region VARCHAR2)
        IS
              SELECT flv.lookup_code lookup_code_usr, flv1.lookup_code, DECODE (flv.enabled_flag, 'Y', flv1.description, 'NULL') description,
                     DECODE (flv.enabled_flag, 'Y', flv1.tag, 20) tag, DECODE (flv.enabled_flag, 'Y', flv.description, NULL) datatype
                FROM apps.fnd_lookup_values flv, apps.fnd_lookup_values flv1
               WHERE     1 = 1
                     AND flv.lookup_code = flv1.lookup_code
                     AND flv.lookup_type = 'RMS_SO_GROUPING_SO_' || x_region
                     AND flv1.lookup_type = 'RMS_SQL_GRP_BY_CLAUSE'
                     AND flv.LANGUAGE = 'US'
                     --AND flv.enabled_flag = 'Y'
                     AND flv1.LANGUAGE = 'US'
                     AND flv1.enabled_flag = 'Y'
                     AND flv.tag = x_region
            ORDER BY TO_NUMBER (flv1.tag) ASC;

        CURSOR cur_class (y_region VARCHAR2)
        IS
              SELECT lookup_code, DECODE (lookup_code, 'OTHERS', 999, 1) ordby, lookup_type
                FROM apps.fnd_lookup_values flv
               WHERE     flv.lookup_type =
                         'XXDO_RMS_SO_GROUPING_CLASS_' || y_region
                     AND flv.enabled_flag = 'Y'
                     AND LANGUAGE = 'US'
            ORDER BY 2;

        /*UNION
        (SELECT NULL, '1', NULL
           FROM DUAL
          WHERE  EXISTS (
                   SELECT lookup_code
                     FROM apps.fnd_lookup_values flv
                    WHERE flv.lookup_type = 'XXDO_RMS_SO_GROUPING_CLASS_'||y_region
                    and flv.enabled_flag = 'N'
                      AND LANGUAGE = 'US')); */

        /*SELECT flv.LOOKUP_CODE LOOKUP_CODE_USR,
                 flv1.LOOKUP_CODE,
                 flv1.description,
                 flv1.tag,
                 flv.description datatype
            FROM apps.fnd_lookup_values flv, apps.fnd_lookup_values flv1
           WHERE     1 = 1
                 AND flv.LOOKUP_CODE = flv1.LOOKUP_CODE
                 AND flv.LOOKUP_TYPE = 'RMS_SO_GROUPING_SO_' ||x_region
                 AND flv1.LOOKUP_TYPE = 'RMS_SQL_GRP_BY_CLAUSE'
                 AND flv.language = 'US'
                 AND flv.enabled_flag = 'Y'
                 AND flv1.language = 'US'
                 AND flv1.enabled_flag = 'Y'
                 AND flv.tag =x_region
        ORDER BY flv1.tag;*/
        TYPE lcur_cursor IS REF CURSOR;

        cur_xxdo26_stg2              lcur_cursor;
        lr_rec_stg2_dest_id          NUMBER;
        lr_rec_stg2_dc_dest_id       NUMBER;
        lr_rec_stg2_dc_vm_id         NUMBER;
        lr_rec_stg2_brand            VARCHAR2 (20);
        lr_rec_stg2_pgroup           VARCHAR2 (240);
        lr_rec_stg2_gender           VARCHAR2 (240);
        lr_rec_stg2_context_code     VARCHAR2 (240);
        lr_rec_stg2_context_value    VARCHAR2 (240);
        lr_rec_stg2_class            VARCHAR2 (240);
        lr_rec_stg2_cancel_date      DATE;
        lr_rec_stg2_status           NUMBER;
        lv_cursor_stmt               VARCHAR2 (20000);
        lv_cursor_stmt_pcondition    VARCHAR2 (20000); /* Parameter Condition */
        lv_cursor_stmt_groupby       VARCHAR2 (20000);    /* Group by Clause*/
        lv_udate_stmt                VARCHAR2 (20000);
        lv_update_stmt1              VARCHAR2 (20000);
        lv_update_stmt2              VARCHAR2 (20000);
        ln_customer_id               NUMBER;
        ln_customer_number           NUMBER;
        ln_org_id                    NUMBER;
        lv_inv_org_code              VARCHAR2 (20);
        ln_order_source_id           NUMBER;
        ln_order_type_id             NUMBER;
        lv_error_message             VARCHAR2 (32767);
        lv_status                    VARCHAR2 (1);
        ln_org_ref_sequence          NUMBER;
        lv_header_insertion_status   VARCHAR2 (1) := 'S';
        lv_line_insertion_status     VARCHAR2 (1) := 'S';
        ln_line_number               NUMBER := 0;
        ln_line_number_canc          NUMBER := 1;
        lv_cursor_stmt0              VARCHAR2 (32767);
        lv_cursor_cls_stmt           VARCHAR2 (32767);
        lv_type_create               VARCHAR2 (2000) := NULL;
        lv_type_create_new           VARCHAR2 (2000) := NULL;
        lv_region                    VARCHAR2 (10) := p_region;
        ln_exists                    NUMBER;
        lv_errbuf                    VARCHAR2 (100);
        lv_retcode                   VARCHAR2 (100);
        ln_line_count                NUMBER;
        ln_organization_id           NUMBER;
        ln_row_updated               NUMBER;
    --1.5
    -- l_hdr_type     xxdo_po_import_hdr_type ;

    BEGIN
        lv_cursor_stmt0   := NULL;
        lv_type_create    :=
            'CREATE OR REPLACE TYPE xxdo_po_import_hdr_type AS OBJECT( ';

        FOR rec_order_classes IN cur_class (p_region)
        LOOP
            fnd_file.put_line (fnd_file.LOG, 'Class Loop Begin ');
            lv_cursor_stmt0          := NULL;
            lv_type_create           := NULL;

            FOR rec_order_lines IN cur_so_orderby (p_region)
            LOOP
                lv_cursor_stmt0   :=
                    lv_cursor_stmt0 || rec_order_lines.description || ',';
            -- lv_type_create :=lv_type_create||substr(rec_order_lines.description,(instr(rec_order_lines.description,'.',1)+1),length(rec_order_lines.description)  )||'  '||rec_order_lines.datatype||',';

            --select substr(lv_type_create, 1,( instr(lv_type_create,',',-1)-1))||')' into  lv_type_create_new from dual;
            END LOOP;

            fnd_file.put_line (
                fnd_file.LOG,
                'lv_cursor_stmt0 clause before ' || lv_cursor_stmt0);

            IF rec_order_classes.lookup_code = 'OTHERS'
            THEN
                lv_cursor_cls_stmt   :=
                       ' AND UPPER(MC.SEGMENT4) IN (select LOOKUP_CODE from apps.fnd_lookup_values flv
                                where  flv.LOOKUP_TYPE = '''
                    || rec_order_classes.lookup_type
                    || '''
                                and language =''US''
                                and enabled_flag =''N''
                                and LOOKUP_CODE not in (''OTHERS'')
                                ) ';
                lv_cursor_stmt0   :=
                    REPLACE (lv_cursor_stmt0, 'MC.SEGMENT4', 'NULL');
                fnd_file.put_line (
                    fnd_file.LOG,
                    'lv_cursor_stmt0 clause when others ' || lv_cursor_stmt0);
            ELSE
                lv_cursor_cls_stmt   :=
                       ' AND UPPER(MC.SEGMENT4) = NVL('''
                    || rec_order_classes.lookup_code
                    || ''',UPPER(MC.SEGMENT4)) ';
            END IF;

            fnd_file.put_line (
                fnd_file.LOG,
                'lv_cursor_stmt0 clause after' || lv_cursor_stmt0);
            lv_cursor_stmt           :=
                   'SELECT '
                || lv_cursor_stmt0
                || '  X26_2.STATUS,
                                             MAX(PICK_NOT_AFTER_DATE) Cancel_Date
                                  FROM XXDO_INV_INT_026_STG2  X26_2
                                           ,MTL_ITEM_CATEGORIES MIC
                                           ,MTL_CATEGORIES_B MC
                                           ,MTL_CATEGORY_SETS_TL MCS
                                 WHERE MIC.CATEGORY_ID = MC.CATEGORY_ID
                                    AND MCS.CATEGORY_SET_ID = MIC.CATEGORY_SET_ID
                                    AND MIC.INVENTORY_ITEM_ID = X26_2.item_id
                                    AND MIC.ORGANIZATION_ID = X26_2.dc_dest_id
                                    AND UPPER(MCS.CATEGORY_SET_NAME) = ''INVENTORY''
                                    AND MC.STRUCTURE_ID = 
                                                           (SELECT structure_id
                                                                    FROM mtl_category_sets
                                                                  WHERE UPPER (category_set_name) = ''INVENTORY'')
                                    AND MCS.LANGUAGE = ''US''
                                ';
            lv_cursor_stmt_groupby   :=
                'GROUP BY ' || lv_cursor_stmt0 || '  X26_2.STATUS';

            IF NVL (pv_reprocess, 'N') = 'N'
            THEN
                --  lv_cursor_stmt_pcondition := ' AND X26_2.STATUS = 0 AND X26_2.REQUESTED_QTY > 0 AND X26_2.DEST_ID IN (SELECT RMS_STORE_ID FROM DO_RETAIL.STORES@DATAMART.DECKERS.COM WHERE REGION ='''||P_REGION||''') '; --1.5
                lv_cursor_stmt_pcondition   :=
                       ' AND X26_2.STATUS = 0 AND X26_2.REQUESTED_QTY > 0 AND X26_2.DEST_ID IN (SELECT RMS_STORE_ID FROM xxd_retail_stores_v WHERE REGION ='''
                    || p_region
                    || ''') ';                                           --1.5
                lv_cursor_stmt   :=
                       lv_cursor_stmt                   /* Select Statement */
                    || lv_cursor_stmt_pcondition /* Parameter Where Condition */
                    || lv_cursor_cls_stmt                /* Specific  Class */
                    || lv_cursor_stmt_groupby;      /*Adding Group by Clause*/
            ELSE
                -- SELECT ' AND X26_2.REQUESTED_QTY > 0 AND X26_2.STATUS = 2 AND X26_2.DEST_ID IN (SELECT RMS_STORE_ID FROM DO_RETAIL.STORES@DATAMART.DECKERS.COM WHERE REGION ='''||P_REGION||''') AND X26_2.CREATION_DATE BETWEEN '''||pd_rp_start_date||''' AND '''||DECODE(NVL(pv_reprocess, 'N'), 'Y', NVL(pd_rp_end_date, SYSDATE), NULL) ||''' '  --1.5

                BEGIN                                        -- Added for 2.0.
                    SELECT ' AND X26_2.REQUESTED_QTY > 0 AND X26_2.STATUS = 2 AND X26_2.DEST_ID IN (SELECT RMS_STORE_ID FROM xxd_retail_stores_v WHERE REGION =''' || p_region || ''') AND X26_2.CREATION_DATE BETWEEN ''' || pd_rp_start_date || ''' AND ''' || DECODE (NVL (pv_reprocess, 'N'), 'Y', NVL (pd_rp_end_date, SYSDATE), NULL) || ''' '
                      INTO lv_cursor_stmt_pcondition
                      FROM DUAL;
                -- START : 2.0.
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Error while preparing cursor statement condition : LV_CURSOR_STMT_PCONDITION');
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error Code : '
                            || SQLCODE
                            || '. Error Message : '
                            || SQLERRM);
                END;

                -- END : 2.0.
                lv_cursor_stmt   :=
                       lv_cursor_stmt                   /* Select Statement */
                    || lv_cursor_stmt_pcondition /* Parameter Where Condition */
                    || lv_cursor_stmt_groupby;      /*Adding Group by Clause*/
            END IF;

            --     lv_udate_stmt := 'UPDATE XXDO_INV_INT_026_STG2 SET request_id = '||FND_GLOBAL.CONC_REQUEST_ID||' WHERE (dc_dest_id, dest_id) IN ('||lv_cursor_stmt||')';
            lv_udate_stmt            :=
                   'UPDATE XXDO_INV_INT_026_STG2 X26_2 SET request_id = '
                || fnd_global.conc_request_id
                || ' WHERE 1 = 1 '
                || lv_cursor_stmt_pcondition;
            lv_update_stmt1          :=
                   'UPDATE XXDO_INV_INT_026_STG2 X26_2 SET (CONTEXT_CODE, CONTEXT_VALUE) = (SELECT CONTEXT_TYPE, CONTEXT_VALUE FROM ALLOC_HEADER@'
                || pv_dblink
                || ' AH WHERE AH.ALLOC_NO = X26_2.DISTRO_NUMBER) where 1= 1';
            fnd_file.put_line (fnd_file.LOG,
                               'Cursor Statement :' || lv_cursor_stmt);
            fnd_file.put_line (fnd_file.LOG,
                               'Update Statement :' || lv_udate_stmt);

            BEGIN                                            -- Added for 2.0.
                EXECUTE IMMEDIATE lv_udate_stmt;
            -- START : 2.0.
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

            -- END : 2.0.

            COMMIT;
            lv_update_stmt1          :=
                lv_update_stmt1 || ' ' || lv_cursor_stmt_pcondition;

            BEGIN                                            -- Added for 2.0.
                EXECUTE IMMEDIATE lv_update_stmt1;
            -- START : 2.0.
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Error while executing update statement : LV_UPDATE_STMT1');
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error Code : '
                        || SQLCODE
                        || '. Error Message : '
                        || SQLERRM);
            END;

            -- END : 2.0.

            COMMIT;
            -- Added By Sivakumar Boothathan on 09/28/2012 for ignoring the Orphan Allocations

            -- lv_update_stmt2 := 'UPDATE XXDO_INV_INT_026_STG2 X26_2 SET STATUS = 9 WHERE X26_2.STATUS = 0 AND X26_2.DEST_ID IN (SELECT RMS_STORE_ID FROM DO_RETAIL.STORES@DATAMART.DECKERS.COM WHERE REGION ='''||P_REGION||''') AND X26_2.DISTRO_NUMBER NOT IN (SELECT AH.ALLOC_NO FROM ALLOC_HEADER@'||pv_dblink||' AH WHERE AH.ALLOC_NO = X26_2.DISTRO_NUMBER)'; --1.5
            lv_update_stmt2          :=
                   'UPDATE XXDO_INV_INT_026_STG2 X26_2 SET STATUS = 9 WHERE X26_2.STATUS = 0 AND X26_2.DEST_ID IN (SELECT RMS_STORE_ID FROM xxd_retail_stores_v WHERE REGION ='''
                || p_region
                || ''') AND X26_2.DISTRO_NUMBER NOT IN (SELECT AH.ALLOC_NO FROM ALLOC_HEADER@'
                || pv_dblink
                || ' AH WHERE AH.ALLOC_NO = X26_2.DISTRO_NUMBER)';
            -- Added By Sivakumar Boothathan on 09/28/2012 for ignoring the Orphan Allocations
            fnd_file.put_line (fnd_file.LOG,
                               'Update Statement :' || lv_update_stmt2);

            BEGIN                                            -- Added for 2.0.
                EXECUTE IMMEDIATE lv_update_stmt2;
            -- START : 2.0.
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Error while executing update statement : LV_UPDATE_STMT2');
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error Code : '
                        || SQLCODE
                        || '. Error Message : '
                        || SQLERRM);
            END;

            -- END : 2.0.

            ln_row_updated           := SQL%ROWCOUNT;
            fnd_file.put_line (fnd_file.LOG,
                               ' Rows updated ' || ln_row_updated);
            COMMIT;
            --- fnd_file.put_line(fnd_file.log,'xxdo_po_import_hdr_type definition '||lv_type_create_new);

            --  EXECUTE IMMEDIATE 'DROP type xxdo_po_import_hdr_type';

            --  EXECUTE IMMEDIATE lv_type_create_new;

            /*Fetching Order Source Information */
            fetch_order_source (ln_order_source_id,
                                lv_status,
                                lv_error_message);

            IF NVL (lv_status, 'S') = 'E'
            THEN
                fnd_file.put_line (fnd_file.LOG, lv_error_message);
                --  fnd_file.put_line (fnd_file.LOG, lv_error_message); -- Commented for 2.0.
                fnd_file.put_line (fnd_file.OUTPUT, lv_error_message); -- Added for 2.0.
            END IF;

            /*Loop for Inserting Header Record into Order Header Interface Table*/
            OPEN cur_xxdo26_stg2 FOR lv_cursor_stmt;

            LOOP
                FETCH cur_xxdo26_stg2
                    INTO lr_rec_stg2_dc_dest_id, lr_rec_stg2_dc_vm_id, lr_rec_stg2_dest_id, lr_rec_stg2_brand,
                         lr_rec_stg2_gender, lr_rec_stg2_pgroup,         --1.5
                                                                 lr_rec_stg2_class,
                         lr_rec_stg2_context_code, lr_rec_stg2_context_value, lr_rec_stg2_status,
                         lr_rec_stg2_cancel_date;

                EXIT WHEN cur_xxdo26_stg2%NOTFOUND;
                fetch_customer_id (lr_rec_stg2_dest_id, ln_customer_id, ln_customer_number
                                   , lv_status, lv_error_message);

                IF NVL (lv_status, 'S') = 'E'
                THEN
                    fnd_file.put_line (fnd_file.LOG, lv_error_message);
                    --  fnd_file.put_line (fnd_file.LOG, lv_error_message); -- Commented for 2.0.
                    fnd_file.put_line (fnd_file.OUTPUT, lv_error_message); -- Added for 2.0.
                END IF;

                fetch_org_id (lr_rec_stg2_dc_dest_id, lr_rec_stg2_dc_vm_id, lr_rec_stg2_dest_id, -- Added for 1.8
                                                                                                 ln_org_id, lv_inv_org_code, lv_status
                              , lv_error_message);
                fnd_file.put_line (fnd_file.LOG, ' ln_org_id ' || ln_org_id);

                IF NVL (lv_status, 'S') = 'E'
                THEN
                    fnd_file.put_line (fnd_file.LOG, lv_error_message);
                    --  fnd_file.put_line (fnd_file.LOG, lv_error_message); -- Commented for 2.0.
                    fnd_file.put_line (fnd_file.OUTPUT, lv_error_message); -- Added for 2.0.
                END IF;

                fetch_order_type ('SHIP', ln_org_id, lr_rec_stg2_dc_vm_id,
                                  lr_rec_stg2_dest_id, ln_order_type_id, lv_status
                                  , lv_error_message);
                /* fnd_file.put_line (fnd_file.LOG,
                                         'SHIP'
                                      || ln_order_type_id
                                      || ' Error '
                                      || lv_error_message
                                     ); */
                -- Commented for 2.0.

                -- Added for 2.0.
                fnd_file.put_line (
                    fnd_file.LOG,
                       'FETCH_ORDER_TYPE returned : '
                    || ln_order_type_id
                    || ' for SHIP, '
                    || 'LN_ORG_ID : '
                    || ln_org_id
                    || '. LR_REC_STG2_DC_VM_ID : '
                    || lr_rec_stg2_dc_vm_id
                    || '. LR_REC_STG2_DEST_ID : '
                    || lr_rec_stg2_dest_id
                    || '. Error : '
                    || lv_error_message);


                IF NVL (lv_status, 'S') = 'E'
                THEN
                    fnd_file.put_line (fnd_file.LOG, lv_error_message);
                    --  fnd_file.put_line (fnd_file.LOG, lv_error_message); -- Commented for 2.0.
                    fnd_file.put_line (fnd_file.OUTPUT, lv_error_message); -- Added for 2.0.
                END IF;

                /*Inserting into Order Header Interface Tables */
                BEGIN
                    SELECT xxdo_inv_int_026_seq.NEXTVAL
                      INTO ln_org_ref_sequence
                      FROM DUAL;

                    INSERT INTO oe_headers_iface_all (order_source_id, order_type_id, org_id, orig_sys_document_ref, created_by, creation_date, last_updated_by, last_update_date, operation_code, booked_flag --                      ,customer_number
                                          --                      ,customer_id
                                                      , sold_to_org_id, customer_po_number, attribute1, attribute5, shipping_method_code
                                                      , shipping_method)
                         VALUES (ln_order_source_id, ln_order_type_id, ln_org_id, 'RMS' || '-' || lr_rec_stg2_dest_id || '-' || lr_rec_stg2_dc_dest_id || '-' || ln_org_ref_sequence, fnd_global.user_id, SYSDATE, fnd_global.user_id, SYSDATE, 'INSERT', 'N' --- Changed to 'N' on 18th May
                                                                                                                                                                                                                                                             --                      ,ln_customer_number
                                                                                                                                                                                                                                                             --                      ,ln_customer_id
                                                                                                                                                                                                                                                             , ln_customer_id, 'RMS' || '-' || lr_rec_stg2_dest_id || '-' || lr_rec_stg2_dc_dest_id || '-' || ln_org_ref_sequence, --TO_CHAR (lr_rec_stg2_cancel_date + 5,
                                                                                                                                                                                                                                                                                                                                                                                   --         'DD-MON-RRRR'
                                                                                                                                                                                                                                                                                                                                                                                   --        ),  -- 1.5
                                                                                                                                                                                                                                                                                                                                                                                   TO_CHAR (lr_rec_stg2_cancel_date + 5, 'YYYY/MM/DD HH:MI:SS'), -- 1.5
                                                                                                                                                                                                                                                                                                                                                                                                                                                 lr_rec_stg2_brand, lr_rec_stg2_context_code
                                 , lr_rec_stg2_context_value);

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
                        fnd_file.put_line (fnd_file.LOG,
                                           'SQL Error Code :' || SQLCODE
                                          );
                        fnd_file.put_line
                           (fnd_file.LOG,
                               'Error while Inserting into Order Header Interface table : '
                            || SQLERRM
                           );
                        fnd_file.put_line
                           (fnd_file.LOG,
                               'Error while Inserting into Order Header Interface table : '
                            || SQLERRM
                           ); */
                        -- Commented for 2.0.

                        -- START : 2.0.
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Error while Inserting into Order Header Interface table : OE_HEADERS_IFACE_ALL');
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error Code : '
                            || SQLCODE
                            || '. Error Message : '
                            || SQLERRM);
                        -- END : 2.0.

                        lv_header_insertion_status   := 'E';
                END;

                IF NVL (lv_header_insertion_status, 'S') = 'S'
                THEN
                    ln_line_number             := 0;
                    lv_line_insertion_status   := 'S';

                    /*Loop For Inserting Records into Order Lines Interface Table */
                    FOR rec_order_lines
                        IN cur_order_lines (lr_rec_stg2_dest_id,
                                            lr_rec_stg2_dc_dest_id,
                                            lr_rec_stg2_status,
                                            lr_rec_stg2_brand,
                                            lr_rec_stg2_pgroup,
                                            lr_rec_stg2_gender,
                                            lr_rec_stg2_class,
                                            lr_rec_stg2_context_code,
                                            lr_rec_stg2_dc_vm_id)
                    LOOP
                        /* Contition to verify whether item exists in price list or not */
                        ln_exists   := NULL;

                        -- Commented Start 1.7 Modified for Price list
                        /*BEGIN
                           --START W.R.T Version 1.5
                           SELECT organization_id
                             INTO ln_organization_id
                             FROM mtl_parameters
                            WHERE organization_code =
                                       fnd_profile.VALUE ('XXDO: ORGANIZATION CODE');


                              SELECT xxdoinv006_pkg.get_region_cost_f
                                                              (rec_order_lines.item_id,
                                                               7,
                                                               lv_region
                                                              )
                               INTO ln_exists
                                FROM DUAL;

                           SELECT xxdoinv006_pkg.get_region_cost_f
                                                           (rec_order_lines.item_id,
                                                            ln_organization_id,
                                                            lv_region
                                                           )
                             INTO ln_exists
                             FROM DUAL;
                        --END W.R.T Version 1.5
                        EXCEPTION
                           WHEN OTHERS
                           THEN
                              fnd_file.put_line
                                  (fnd_file.LOG,
                                      'Error while vefifying price list condition:'
                                   || SQLERRM
                                  );
                              ln_exists := 0;
                        END;*/
                        -- Commented End 1.7 Modified for Price list

                        -- Commented Start 1.7 Modified for Price list
                        --IF ln_exists = 1
                        --THEN
                        BEGIN
                            ln_line_number             := ln_line_number + 1;

                            INSERT INTO oe_lines_iface_all (
                                            order_source_id,
                                            org_id,
                                            orig_sys_document_ref,
                                            orig_sys_line_ref,
                                            inventory_item_id,
                                            ordered_quantity --            ,order_quantity_uom
                                                            ,
                                            unit_selling_price,
                                            --    ship_from_org_id,         -- Commented for 2.1.
                                            ship_from_org_id, -- Uncommented for 2.2.
                                            request_date,
                                            created_by,
                                            creation_date,
                                            last_updated_by,
                                            last_update_date,
                                            attribute1 --                                       ,sold_to_org_id
                                                      )
                                     VALUES (
                                                ln_order_source_id,
                                                ln_org_id,
                                                   'RMS'
                                                || '-'
                                                || lr_rec_stg2_dest_id
                                                || '-'
                                                || lr_rec_stg2_dc_dest_id
                                                || '-'
                                                || ln_org_ref_sequence,
                                                   rec_order_lines.distro_number
                                                || '-'
                                                || rec_order_lines.document_type
                                                || '-'
                                                || xxdo_inv_int_026_seq.NEXTVAL
                                                || '-'
                                                || rec_order_lines.xml_id,
                                                rec_order_lines.item_id,
                                                rec_order_lines.requested_qty --             ,rec_order_lines.selling_uom
                                                                             ,
                                                rec_order_lines.retail_price,
                                                --    rec_order_lines.dc_dest_id,    -- Commented for 2.1.
                                                rec_order_lines.dc_dest_id, -- Uncommented for 2.2.
                                                rec_order_lines.pick_not_before_date,
                                                fnd_global.user_id,
                                                SYSDATE,
                                                fnd_global.user_id,
                                                SYSDATE,
                                                --TO_CHAR (lr_rec_stg2_cancel_date + 5,
                                                --         'DD-MON-RRRR'
                                                --        )
                                                TO_CHAR (
                                                      lr_rec_stg2_cancel_date
                                                    + 5,
                                                    'YYYY/MM/DD HH:MI:SS') -- 1.5
                                                                          --                                     ,ln_customer_id
                                                                          );

                            lv_line_insertion_status   := 'S';

                            BEGIN
                                UPDATE xxdo_inv_int_026_stg2 x26_2
                                   SET x26_2.status = 1, x26_2.brand = lr_rec_stg2_brand
                                 WHERE x26_2.ROWID = rec_order_lines.ROWID;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    /*   lv_error_message :=
                                               lv_error_message
                                            || ' - '
                                            || 'Error while Updating Status 2 for Dest_id - '
                                            || lr_rec_stg2_dest_id
                                            || ' AND dc_dest_id - '
                                            || lr_rec_stg2_dc_dest_id
                                            || '  :'
                                            || SQLERRM;
                                         fnd_file.put_line (fnd_file.LOG,
                                                            'SQL Error Code :' || SQLCODE
                                                           );
                                         fnd_file.put_line
                                            (fnd_file.LOG,
                                                'Error while Updating Status 2 for Dest_id - '
                                             || lr_rec_stg2_dest_id
                                             || ' AND dc_dest_id - '
                                             || lr_rec_stg2_dc_dest_id
                                             || '  :'
                                             || SQLERRM
                                            );
                                         fnd_file.put_line
                                            (fnd_file.LOG,
                                                'Error while Updating Status 2 for Dest_id - '
                                             || lr_rec_stg2_dest_id
                                             || ' AND dc_dest_id - '
                                             || lr_rec_stg2_dc_dest_id
                                             || '  :'
                                             || SQLERRM
                                            ); */
                                    -- Commented for 2.0.

                                    -- START : 2.0.
                                    lv_error_message   :=
                                           lv_error_message
                                        || ' - '
                                        || 'Error while Updating Status 1 for Brand : '
                                        || lr_rec_stg2_brand
                                        || ' AND ROW_ID : '
                                        || rec_order_lines.ROWID;
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Error while Updating Status 1 for Brand : '
                                        || lr_rec_stg2_brand
                                        || ' AND ROW_ID : '
                                        || rec_order_lines.ROWID);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Error Code : '
                                        || SQLCODE
                                        || '. Error Message : '
                                        || SQLERRM);
                            -- END : 2.0.

                            END;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                /* fnd_file.put_line (fnd_file.LOG,
                                                      'SQL Error Code :' || SQLCODE
                                                     );
                                   fnd_file.put_line
                                      (fnd_file.LOG,
                                          'Error while Inserting into Order Lines Interface table :'
                                       || SQLERRM
                                      );
                                   fnd_file.put_line
                                      (fnd_file.LOG,
                                          'Error while Inserting into Order Lines Interface table :'
                                       || SQLERRM
                                      ); */
                                -- Commented for 2.0.

                                -- START : 2.0.
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Error while Inserting into Order Lines Interface table : OE_LINES_IFACE_ALL.');
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Error Code : '
                                    || SQLCODE
                                    || '. Error Message : '
                                    || SQLERRM);
                                -- END : 2.0.

                                lv_line_insertion_status   := 'E';

                                BEGIN
                                    UPDATE xxdo_inv_int_026_stg2 x26_2
                                       SET x26_2.status = 2, x26_2.brand = lr_rec_stg2_brand, x26_2.error_message = 'Seq NO :' || rec_order_lines.seq_no || ' ' || lv_error_message
                                     WHERE     (x26_2.seq_no) IN
                                                   (SELECT x26_2.seq_no
                                                      FROM xxdo_inv_int_026_stg2 x26_2_1, mtl_item_categories mic, mtl_categories_b mc,
                                                           mtl_category_sets_tl mcs
                                                     WHERE     mic.category_id =
                                                               mc.category_id
                                                           AND mcs.category_set_id =
                                                               mic.category_set_id
                                                           AND mic.inventory_item_id =
                                                               x26_2_1.item_id
                                                           AND mic.organization_id =
                                                               x26_2_1.dc_dest_id
                                                           AND UPPER (
                                                                   mcs.category_set_name) =
                                                               'INVENTORY'
                                                           -- AND MC.STRUCTURE_ID = 101
                                                           AND mc.structure_id =
                                                               (SELECT structure_id
                                                                  FROM mtl_category_sets
                                                                 WHERE UPPER (
                                                                           category_set_name) =
                                                                       'INVENTORY')
                                                           --1.5
                                                           AND mcs.LANGUAGE =
                                                               'US'
                                                           AND x26_2_1.dc_dest_id =
                                                               lr_rec_stg2_dc_dest_id
                                                           AND x26_2_1.dest_id =
                                                               lr_rec_stg2_dc_dest_id
                                                           AND mc.segment1 =
                                                               lr_rec_stg2_brand
                                                           --  AND mc.segment2 =lr_rec_stg2_pgroup  --W.r.t 1.5
                                                           -- AND mc.segment3 = lr_rec_stg2_gender  --W.r.t 1.5
                                                           AND mc.segment2 =
                                                               lr_rec_stg2_gender
                                                           --W.r.t 1.5
                                                           AND mc.segment3 =
                                                               lr_rec_stg2_pgroup
                                                           --W.r.t 1.5
                                                           AND mc.segment4 =
                                                               lr_rec_stg2_class)
                                           AND x26_2.request_id =
                                               fnd_global.conc_request_id;
                                --                              UPDATE XXDO_INV_INT_026_STG2 X26_2
                                --                                    SET X26_2.STATUS = 2,
                                --                                           X26_2.ERROR_MESSAGE = 'Seq NO :'||rec_order_lines.seq_no||' '||lv_error_message
                                --                                WHERE X26_2.ROWID = rec_order_lines.ROWID;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        /*  fnd_file.put_line (fnd_file.LOG,
                                                                  'SQL Error Code :'
                                                               || SQLCODE
                                                              );
                                            fnd_file.put_line
                                               (fnd_file.LOG,
                                                   'Error while Updating Status 2 for Dest_id - '
                                                || lr_rec_stg2_dest_id
                                                || ' AND dc_dest_id - '
                                                || lr_rec_stg2_dc_dest_id
                                                || '  :'
                                                || SQLERRM
                                               );
                                            fnd_file.put_line
                                               (fnd_file.LOG,
                                                   'Error while Updating Status 2 for Dest_id - '
                                                || lr_rec_stg2_dest_id
                                                || ' AND dc_dest_id - '
                                                || lr_rec_stg2_dc_dest_id
                                                || '  :'
                                                || SQLERRM
                                               ); */
                                        -- Commented for 2.0.
                                        -- START : 2.0.
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                               'Error while Updating Status 2 for DEST_ID - '
                                            || lr_rec_stg2_dest_id
                                            || ' AND DC_DEST_ID - '
                                            || lr_rec_stg2_dc_dest_id);
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                               'Error Code : '
                                            || SQLCODE
                                            || '. Error Message : '
                                            || SQLERRM);
                                -- END : 2.0.
                                END;
                        END;
                    /*ELSIF ln_exists = 0
                    THEN
                       BEGIN
                          xxdo_int_009_prc (lv_errbuf,
                                            lv_retcode,
                                            rec_order_lines.dc_dest_id,
                                            rec_order_lines.distro_number,
                                            rec_order_lines.document_type,
                                            rec_order_lines.distro_number,
                                            lr_rec_stg2_dest_id,
                                            rec_order_lines.item_id,
                                            1     --rec_order_sch.order_line_num
                                             ,
                                            rec_order_lines.requested_qty,
                                            'NI'
                                           );

                          BEGIN
                             UPDATE xxdo_inv_int_026_stg2 x26_2
                                SET schedule_check = 'Y',
                                    x26_2.status = 9,
                                    x26_2.brand = lr_rec_stg2_brand,
                                    x26_2.error_message =
                                                        'ITEM NOT IN PRICE LIST'
                              WHERE x26_2.ROWID = rec_order_lines.ROWID;
                          EXCEPTION
                             WHEN OTHERS
                             THEN
                                fnd_file.put_line
                                   (fnd_file.LOG,
                                       'Error while Updating Schedule Check NI '
                                    || rec_order_lines.distro_number
                                    || ' - '
                                    || rec_order_lines.dc_dest_id
                                    || ' --- '
                                    || SQLERRM
                                   );
                          END;
                       END;
                    END IF;*/
                    --Commented End 1.7
                    END LOOP;
                ELSE
                    BEGIN
                        UPDATE xxdo_inv_int_026_stg2 x26_2
                           SET x26_2.status = 2, x26_2.brand = lr_rec_stg2_brand, x26_2.error_message = lv_error_message
                         WHERE     (x26_2.seq_no) IN
                                       (SELECT x26_2.seq_no
                                          FROM xxdo_inv_int_026_stg2 x26_2_1, mtl_item_categories mic, mtl_categories_b mc,
                                               mtl_category_sets_tl mcs
                                         WHERE     mic.category_id =
                                                   mc.category_id
                                               AND mcs.category_set_id =
                                                   mic.category_set_id
                                               AND mic.inventory_item_id =
                                                   x26_2_1.item_id
                                               AND mic.organization_id =
                                                   x26_2_1.dc_dest_id
                                               AND UPPER (
                                                       mcs.category_set_name) =
                                                   'INVENTORY'
                                               --AND MC.STRUCTURE_ID = 101
                                               AND mc.structure_id =
                                                   (SELECT structure_id
                                                      FROM mtl_category_sets
                                                     WHERE UPPER (
                                                               category_set_name) =
                                                           'INVENTORY')
                                               --1.5
                                               AND mcs.LANGUAGE = 'US'
                                               AND x26_2_1.requested_qty > 0
                                               AND x26_2_1.dc_dest_id =
                                                   lr_rec_stg2_dc_dest_id
                                               AND x26_2_1.dest_id =
                                                   lr_rec_stg2_dc_dest_id
                                               AND mc.segment1 =
                                                   lr_rec_stg2_brand
                                               -- AND mc.segment2 = lr_rec_stg2_pgroup --W.r.t 1.5
                                               -- AND mc.segment3 = lr_rec_stg2_gender --W.r.t 1.5
                                               AND mc.segment2 =
                                                   lr_rec_stg2_gender
                                               --W.r.t 1.5
                                               AND mc.segment3 =
                                                   lr_rec_stg2_pgroup
                                               --W.r.t 1.5
                                               AND mc.segment4 =
                                                   lr_rec_stg2_class)
                               AND x26_2.request_id =
                                   fnd_global.conc_request_id;
                    --                  UPDATE XXDO_INV_INT_026_STG2 X26_2
                    --                        SET X26_2.STATUS = 2
                    --                              ,ERROR_MESSAGE = lv_error_message
                    --                    WHERE X26_2.DC_DEST_ID = lr_rec_stg2_dc_dest_id
                    --                        AND X26_2.DEST_ID = lr_rec_stg2_dest_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            /*   fnd_file.put_line (fnd_file.LOG,
                                                    'SQL Error Code :' || SQLCODE
                                                   );
                                 fnd_file.put_line
                                        (fnd_file.LOG,
                                            'Error while Updating Status 2 for Dest_id - '
                                         || lr_rec_stg2_dest_id
                                         || ' AND dc_dest_id - '
                                         || lr_rec_stg2_dc_dest_id
                                         || '  :'
                                         || SQLERRM
                                        );
                                 fnd_file.put_line
                                        (fnd_file.LOG,
                                            'Error while Updating Status 2 for Dest_id - '
                                         || lr_rec_stg2_dest_id
                                         || ' AND dc_dest_id - '
                                         || lr_rec_stg2_dc_dest_id
                                         || '  :'
                                         || SQLERRM
                                        );
                             */
                            -- Commented for 2.0.
                            -- START : 2.0.
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error while Updating Status 2 for DEST_ID - '
                                || lr_rec_stg2_dest_id
                                || ' AND DC_DEST_ID - '
                                || lr_rec_stg2_dc_dest_id);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error Code : '
                                || SQLCODE
                                || '. Error Message : '
                                || SQLERRM);
                    -- END : 2.0.

                    END;
                END IF;

                /* Query to fetch the count of lines for header */
                BEGIN
                    ln_line_count   := 0;

                    SELECT COUNT (1)
                      INTO ln_line_count
                      FROM apps.oe_lines_iface_all
                     WHERE     error_flag IS NULL
                           AND request_id IS NULL
                           AND orig_sys_document_ref =
                                  'RMS'
                               || '-'
                               || lr_rec_stg2_dest_id
                               || '-'
                               || lr_rec_stg2_dc_dest_id
                               || '-'
                               || ln_org_ref_sequence
                           AND order_source_id = ln_order_source_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        /*  fnd_file.put_line (fnd_file.LOG,
                                               'SQL Error Code :' || SQLCODE
                                              );
                            fnd_file.put_line
                               (fnd_file.LOG,
                                   'Error while select count of lines for docunment referece - RMS'
                                || lr_rec_stg2_dest_id
                                || ' AND dc_dest_id - '
                                || lr_rec_stg2_dc_dest_id
                                || '-'
                                || ln_org_ref_sequence
                                || '  :'
                                || SQLERRM
                               ); */
                        -- Commented for 2.0.
                        -- START : 2.0.
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error while selecting count of lines for docunment referece - RMS'
                            || lr_rec_stg2_dest_id
                            || ' AND dc_dest_id - '
                            || lr_rec_stg2_dc_dest_id
                            || '-'
                            || ln_org_ref_sequence);
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error Code : '
                            || SQLCODE
                            || '. Error Message : '
                            || SQLERRM);
                -- END : 2.0.
                END;

                IF ln_line_count <= 0
                THEN
                    BEGIN
                        DELETE FROM
                            apps.oe_headers_iface_all
                              WHERE     orig_sys_document_ref =
                                           'RMS'
                                        || '-'
                                        || lr_rec_stg2_dest_id
                                        || '-'
                                        || lr_rec_stg2_dc_dest_id
                                        || '-'
                                        || ln_org_ref_sequence
                                    AND error_flag IS NULL
                                    AND request_id IS NULL
                                    AND order_source_id = ln_order_source_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            /*   fnd_file.put_line (fnd_file.LOG,
                                                    'SQL Error Code :' || SQLCODE
                                                   );
                                 fnd_file.put_line
                                    (fnd_file.LOG,
                                        'Error while deleting header line for docunment referece - RMS'
                                     || lr_rec_stg2_dest_id
                                     || ' AND dc_dest_id - '
                                     || lr_rec_stg2_dc_dest_id
                                     || '-'
                                     || ln_org_ref_sequence
                                     || '  :'
                                     || SQLERRM
                                    ); */
                            -- Commented for 2.0.
                            -- START : 2.0.
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error while deleting header record for docunment referece - RMS - '
                                || lr_rec_stg2_dest_id
                                || ' AND dc_dest_id - '
                                || lr_rec_stg2_dc_dest_id
                                || '-'
                                || ln_org_ref_sequence);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error Code : '
                                || SQLCODE
                                || '. Error Message : '
                                || SQLERRM);
                    -- END : 2.0.
                    END;
                END IF;
            END LOOP;

            CLOSE cur_xxdo26_stg2;
        END LOOP;

        /*COMMITting The Inserts and Updates*/
        COMMIT;
        /*Calling Order Import Program*/
        call_order_import;
        /*Calling Procedure to Print Audit Report in the Concurrent Request Output*/
        print_audit_report;
    END insert_oe_iface_tables;

    PROCEDURE call_order_import
    IS
        CURSOR cur_order_import IS
            SELECT DISTINCT oei.org_id org_id, oei.order_source_id order_source_id
              FROM oe_headers_iface_all oei
             WHERE EXISTS
                       (SELECT 1
                          FROM xxdo_inv_int_026_stg2 x26_2
                         WHERE     TO_CHAR (x26_2.dest_id) =
                                   SUBSTR (orig_sys_document_ref,
                                             INSTR (orig_sys_document_ref, '-', 1
                                                    , 1)
                                           + 1,
                                             (  INSTR (orig_sys_document_ref, '-', 1
                                                       , 2)
                                              - INSTR (orig_sys_document_ref, '-', 1
                                                       , 1))
                                           - 1)
                               -- Fixed on June 14th as it is erroring with Invalid Number
                               AND x26_2.dc_dest_id =
                                   SUBSTR (orig_sys_document_ref,
                                             INSTR (orig_sys_document_ref, '-', 1
                                                    , 2)
                                           + 1,
                                             (  INSTR (orig_sys_document_ref, '-', 1
                                                       , 3)
                                              - INSTR (orig_sys_document_ref, '-', 1
                                                       , 2))
                                           - 1)
                               AND x26_2.request_id =
                                   fnd_global.conc_request_id
                               AND x26_2.requested_qty > 0
                               AND x26_2.status = 1);

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
                fnd_request.submit_request (
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
            --  fnd_file.put_line (fnd_file.LOG, 'ln_request_id  ' || ln_request_id); -- Commented for 2.0.
            fnd_file.put_line (fnd_file.LOG,
                               'Order Import Request id : ' || ln_request_id); -- Modified for 2.0.

            IF (ln_request_id != 0)
            THEN
                lv_success   :=
                    fnd_concurrent.get_request_status (
                        request_id       => ln_request_id,
                        --rec_oint_req_id.oint_request_id,    -- Request ID
                        appl_shortname   => NULL,
                        program          => NULL,
                        phase            => lv_phase,
                        -- Phase displayed on screen
                        status           => lv_status,
                        -- Status displayed on screen
                        dev_phase        => lv_dev_phase,
                        -- Phase available for developer
                        dev_status       => lv_dev_status,
                        -- Status available for developer
                        MESSAGE          => lv_message    -- Execution Message
                                                      );

                LOOP
                    lv_success   :=
                        fnd_concurrent.wait_for_request (
                            request_id   => ln_request_id,
                            -- Request ID
                            INTERVAL     => 10,
                            phase        => lv_phase,
                            -- Phase displyed on screen
                            status       => lv_status,
                            -- Status displayed on screen
                            dev_phase    => lv_dev_phase,
                            -- Phase available for developer
                            dev_status   => lv_dev_status,
                            -- Status available for developer
                            MESSAGE      => lv_message    -- Execution Message
                                                      );
                    EXIT WHEN lv_dev_phase = 'COMPLETE';
                END LOOP;
            END IF;
        END LOOP;
    END call_order_import;

    PROCEDURE fetch_customer_id (pn_dest_id           IN     NUMBER,
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
              FROM xxd_retail_stores_v drs
             --do_retail.stores@datamart.deckers.com drs  --W.R.T VErsion 1.5
             WHERE drs.rms_store_id = pn_dest_id AND ROWNUM = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                --    pv_error_message :='Error while Fetching Customer Information from XXDO_RETAIL_STORE_CUST_MAPPING lookup :'|| SQLERRM; -- Commented for 2.0.
                pv_error_message   :=
                       'Error while Fetching Customer Information from XXD_RETAIL_STORES_V. Error : '
                    || SQLERRM;                           -- Modified for 2.0.
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error while Fetching Customer Information from XXD_RETAIL_STORES_V. Error : '
                    || SQLERRM);                             -- Added for 2.0.
                pv_status   := 'E';
                RETURN;
        END;

        BEGIN
            SELECT customer_number, customer_name
              INTO ln_customer_number, lv_customer_name
              -- FROM RA_CUSTOMERS RC
              FROM ra_hcustomers rc                                      --1.5
             WHERE rc.customer_id = ln_customer_id;

            pn_customer_id       := ln_customer_id;
            pn_customer_number   := ln_customer_number;
            pv_status            := 'S';
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_error_message   :=
                       'Error While Fetching Customer using Customer_id '
                    || ln_customer_id
                    || ' '
                    || ' pn_dest_id '
                    || pn_dest_id
                    || ' '
                    || SQLERRM;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error While Fetching Customer using Customer_id '
                    || ln_customer_id
                    || ' '
                    || ' pn_dest_id '
                    || pn_dest_id
                    || ' '
                    || SQLERRM);                             -- Added for 2.0.
                pv_status   := 'E';
        END;
    END fetch_customer_id;

    PROCEDURE fetch_org_id (pn_dc_dest_id IN NUMBER, pn_vm_id IN NUMBER, pn_dest_id IN NUMBER, -- Added for 1.8.
                                                                                               pn_org_id OUT NUMBER, pv_inv_org_code OUT VARCHAR2, pv_status OUT VARCHAR2
                            , pv_error_message OUT VARCHAR2)
    IS
        ln_org_id         NUMBER;
        lv_inv_org_code   VARCHAR2 (20);
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
               ' fetch_org_id'
            || ' pn_dc_dest_id '
            || pn_dc_dest_id
            || ' pn_vm_id '
            || pn_vm_id);

        /*    SELECT org_id
                INTO ln_org_id
                FROM xxdo_ebs_rms_vw_map xvm
               WHERE xvm.ORGANIZATION = pn_dc_dest_id
                 AND xvm.virtual_warehouse = pn_vm_id
                 AND xvm.channel = 'OUTLET'; */
        -- Commented for 1.8.

        -- BEGIN : Added for 1.8.
        SELECT operating_unit
          INTO ln_org_id
          FROM apps.xxd_retail_stores_v
         WHERE rms_store_id = pn_dest_id;

        -- END : Added for 1.8.


        pn_org_id         := ln_org_id;

        SELECT organization_code
          INTO lv_inv_org_code
          FROM org_organization_definitions ood
         WHERE ood.organization_id = pn_dc_dest_id;

        pv_inv_org_code   := lv_inv_org_code;
        pv_status         := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error while Fetching Organization Information :'
                || SQLERRM
                || ' For dest id '
                || pn_dc_dest_id
                || ' for vm id'
                || pn_vm_id);
            pv_status   := 'E';
            pv_error_message   :=
                'Error while Fetching Organization Information :' || SQLERRM;
    END fetch_org_id;

    PROCEDURE fetch_order_type (pv_ship_return IN VARCHAR2, pn_org_id IN NUMBER, pn_vw_id IN NUMBER, pn_str_nbr IN NUMBER, pn_order_type_id OUT NUMBER, pv_status OUT VARCHAR2
                                , pv_error_message OUT VARCHAR2)
    IS
        ln_order_type_id   NUMBER;
    BEGIN
        ln_order_type_id   := 0;

        BEGIN
            SELECT a.order_type_id
              INTO ln_order_type_id
              FROM apps.hz_cust_site_uses_all a, apps.hz_cust_acct_sites_all b, xxd_retail_stores_v c
             --do_retail.stores@datamart.deckers.com c  --W.R.T VErsion 1.5
             WHERE     1 = 1
                   AND a.site_use_code = 'SHIP_TO'
                   AND a.org_id = pn_org_id
                   AND a.cust_acct_site_id = b.cust_acct_site_id
                   AND c.ra_customer_id = b.cust_account_id
                   AND a.primary_flag = 'Y'
                   AND c.rms_store_id = pn_str_nbr;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_order_type_id   := 0;
        /* --W.r.t Version 2.3
        fnd_file.put_line
                 (fnd_file.LOG,
                     'Order type Not Defined at Customer Level, Store : '
                  || pn_str_nbr
                 );
                 */
        --W.r.t Version 2.3
        END;


        IF ln_order_type_id = 0 OR ln_order_type_id IS NULL
        THEN
            SELECT ottl.transaction_type_id
              INTO ln_order_type_id
              FROM fnd_lookup_values_vl flv, hr_operating_units hou, oe_transaction_types_tl ottl
             WHERE     flv.lookup_type = 'XXDO_RMS_SO_RMA_ALLOCATION'
                   AND UPPER (flv.lookup_code) = UPPER (ottl.NAME)
                   AND hou.NAME = flv.tag
                   AND flv.description = pv_ship_return
                   AND hou.organization_id = pn_org_id
                   AND ottl.LANGUAGE = 'US'
                   AND flv.enabled_flag = 'Y'
                   -- AND FLV.language = 'US'
                   AND flv.attribute_category = 'XXDO_RMS_SO_RMA_ALLOCATION'
                   AND (flv.attribute11 = pn_vw_id OR flv.attribute9 = pn_vw_id OR flv.attribute2 = pn_vw_id OR flv.attribute1 = pn_vw_id OR flv.attribute3 = pn_vw_id OR flv.attribute4 = pn_vw_id OR flv.attribute5 = pn_vw_id OR flv.attribute6 = pn_vw_id OR flv.attribute7 = pn_vw_id OR flv.attribute8 = pn_vw_id OR flv.attribute10 = pn_vw_id OR flv.attribute12 = pn_vw_id OR flv.attribute13 = pn_vw_id OR flv.attribute14 = pn_vw_id OR flv.attribute15 = pn_vw_id);
        END IF;

        pn_order_type_id   := ln_order_type_id;
        pv_status          := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            /*  fnd_file.put_line
                               (fnd_file.LOG,
                                   'Error while Fetching Order Source Information :'
                                || SQLERRM
                               ); */
            -- Commented for 2.0;
               /* --W.r.t Version 2.3
fnd_file.put_line
           (fnd_file.LOG,
               'Error while Fetching Order Type from the lookup XXDO_RMS_SO_RMA_ALLOCATION. Error Code : '
            || SQLCODE
            || '. Message : '
            || SQLERRM
               ); -- Modified for 2.0;
               */
            --W.r.t Version 2.3
            pv_status   := 'E';
            -- pv_error_message :='Error while Fetching Order Source Information :' || SQLERRM; -- Commented for 2.0.
            pv_error_message   :=
                   'Error while Fetching Order Type from the lookup XXDO_RMS_SO_RMA_ALLOCATION.  For  Org '
                || pn_org_id
                || ' pn_vw_id '
                || pn_vw_id
                || 'ln_order_type_id '
                || ln_order_type_id
                || ' pv_ship_return '
                || pv_ship_return
                || ' Error  '
                || SQLCODE
                || '. Message : '
                || SQLERRM;                               -- Modified for 2.0.
    END fetch_order_type;

    PROCEDURE fetch_order_source (pn_order_source_id OUT NUMBER, pv_status OUT VARCHAR2, pv_error_message OUT VARCHAR2)
    IS
        ln_order_source_id   NUMBER;
    BEGIN
        SELECT order_source_id
          INTO ln_order_source_id
          FROM oe_order_sources oos
         WHERE UPPER (NAME) LIKE 'RETAIL';

        pn_order_source_id   := ln_order_source_id;
        pv_status            := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Error while Fetching Order Source Information :' || SQLERRM);
            pv_status   := 'E';
            pv_error_message   :=
                'Error while Fetching Order Source Information :' || SQLERRM;
    END fetch_order_source;

    PROCEDURE fetch_item_brand (pn_dc_dest_id      IN     NUMBER,
                                pn_item_id         IN     NUMBER,
                                pv_item_brand         OUT VARCHAR2,
                                pv_status             OUT VARCHAR2,
                                pv_error_message      OUT VARCHAR2)
    IS
        lv_item_brand   VARCHAR2 (10);
    BEGIN
        SELECT mc.segment1
          INTO lv_item_brand
          FROM mtl_item_categories mic, mtl_categories_b mc, mtl_category_sets_tl mcs
         WHERE     mic.category_id = mc.category_id
               AND mcs.category_set_id = mic.category_set_id
               AND mic.inventory_item_id = pn_item_id
               AND mic.organization_id = pn_dc_dest_id
               AND UPPER (mcs.category_set_name) = 'INVENTORY'
               --AND MC.STRUCTURE_ID = 101
               AND mc.structure_id =
                   (SELECT structure_id
                      FROM mtl_category_sets
                     WHERE UPPER (category_set_name) = 'INVENTORY')
               --1.5
               AND mcs.LANGUAGE = 'US';

        pv_status       := 'S';
        pv_item_brand   := lv_item_brand;
    EXCEPTION
        WHEN OTHERS
        THEN
            /*  fnd_file.put_line
                               (fnd_file.LOG,
                                   'Error while Fetching Order Source Information :'
                                || SQLERRM
                               ); */
            -- Commented for 2.0.
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error while Fetching Item Brand. Error Code : '
                || SQLCODE
                || '. Message : '
                || SQLERRM);                              -- Modified for 2.0;
            pv_status   := 'E';
            --  pv_error_message :='Error while Fetching Order Source Information :' || SQLERRM; -- Commented for 2.0.
            pv_error_message   :=
                   'Error while Fetching Item Brand. Error Code : '
                || SQLCODE
                || '. Message : '
                || SQLERRM;                               -- Modified for 2.0.
    END fetch_item_brand;

    PROCEDURE print_audit_report
    AS
        CURSOR cur_print_audit_e IS
              SELECT x26_2.ROWID, x26_2.*
                FROM xxdo_inv_int_026_stg2 x26_2
               WHERE     x26_2.request_id = fnd_global.conc_request_id
                     AND status = 2
                     AND x26_2.requested_qty > 0
            ORDER BY x26_2.seq_no, x26_2.dest_id, x26_2.dc_dest_id,
                     x26_2.item_id;

        CURSOR cur_print_iface_e1 IS
              SELECT opm.original_sys_document_ref
                FROM oe_processing_msgs opm, oe_processing_msgs_tl opmt, oe_order_sources oos,
                     oe_headers_iface_all ohi, xxdo_inv_int_026_stg2 x26_2
               WHERE     opm.transaction_id = opmt.transaction_id
                     AND ohi.orig_sys_document_ref =
                         opm.original_sys_document_ref
                     AND oos.order_source_id = ohi.order_source_id
                     AND UPPER (oos.NAME) LIKE 'RETAIL'
                     AND SUBSTR (opm.original_sys_document_ref,
                                 1,
                                   INSTR (opm.original_sys_document_ref, '-', 1
                                          , 3)
                                 - 1) =
                            'RMS'
                         || '-'
                         || x26_2.dest_id
                         || '-'
                         || x26_2.dc_dest_id
                     AND ohi.attribute5 = x26_2.brand
                     AND opmt.LANGUAGE = 'US'
                     AND NVL (ohi.error_flag, 'N') = 'Y'
                     AND x26_2.requested_qty > 0
                     AND x26_2.request_id = fnd_global.conc_request_id
            GROUP BY opm.original_sys_document_ref;

        CURSOR cur_print_iface_e2 (cv_doc_ref VARCHAR2)
        IS
              SELECT opm.original_sys_document_ref, opmt.MESSAGE_TEXT, x26_2.*
                FROM oe_processing_msgs opm, oe_processing_msgs_tl opmt, oe_order_sources oos,
                     oe_headers_iface_all ohi, xxdo_inv_int_026_stg2 x26_2
               WHERE     opm.transaction_id = opmt.transaction_id
                     AND ohi.orig_sys_document_ref =
                         opm.original_sys_document_ref
                     AND oos.order_source_id = ohi.order_source_id
                     AND UPPER (oos.NAME) LIKE 'RETAIL'
                     AND SUBSTR (opm.original_sys_document_ref,
                                 1,
                                   INSTR (opm.original_sys_document_ref, '-', 1
                                          , 3)
                                 - 1) =
                            'RMS'
                         || '-'
                         || x26_2.dest_id
                         || '-'
                         || x26_2.dc_dest_id
                     AND ohi.attribute5 = x26_2.brand
                     AND opmt.LANGUAGE = 'US'
                     AND NVL (ohi.error_flag, 'N') = 'Y'
                     AND x26_2.requested_qty > 0
                     AND x26_2.request_id = fnd_global.conc_request_id
                     AND opm.original_sys_document_ref = cv_doc_ref
            ORDER BY x26_2.seq_no, x26_2.dest_id, x26_2.dc_dest_id,
                     x26_2.item_id, opmt.MESSAGE_TEXT;

        CURSOR cur_print_audit_s1 IS
              SELECT x26_2.dest_id, x26_2.dc_dest_id, x26_2.brand
                FROM xxdo_inv_int_026_stg2 x26_2
               WHERE     x26_2.request_id = fnd_global.conc_request_id
                     AND x26_2.requested_qty > 0
                     AND status = 1
            GROUP BY x26_2.dest_id, x26_2.dc_dest_id, x26_2.brand
            ORDER BY x26_2.dest_id, x26_2.dc_dest_id, x26_2.brand;

        CURSOR cur_print_audit_s2 (cv_dc_dest_id   NUMBER,
                                   cv_dest_id      NUMBER,
                                   cv_brand        VARCHAR2)
        IS
              SELECT x26_2.ROWID, x26_2.*
                FROM xxdo_inv_int_026_stg2 x26_2
               WHERE     x26_2.request_id = fnd_global.conc_request_id
                     AND x26_2.status = 1
                     AND x26_2.dc_dest_id = cv_dc_dest_id
                     AND x26_2.dest_id = cv_dest_id
                     AND x26_2.requested_qty > 0
                     AND x26_2.brand = cv_brand
            ORDER BY x26_2.seq_no, x26_2.dest_id, x26_2.dc_dest_id,
                     x26_2.item_id;

        CURSOR cur_chk_order_schedule IS
              SELECT x26_2.*
                FROM oe_order_headers_all oeh, oe_order_lines_all oel, oe_order_sources oes,
                     xxdo_inv_int_026_stg2 x26_2
               WHERE     oeh.header_id = oel.header_id
                     AND oeh.order_source_id = oes.order_source_id
                     AND x26_2.distro_number = SUBSTR (oel.orig_sys_line_ref,
                                                       1,
                                                         INSTR (oel.orig_sys_line_ref, '-', 1
                                                                , 1)
                                                       - 1)
                     AND    'RMS'
                         || '-'
                         || x26_2.dest_id
                         || '-'
                         || x26_2.dc_dest_id =
                         SUBSTR (oel.orig_sys_document_ref,
                                 1,
                                   INSTR (oel.orig_sys_document_ref, '-', 1,
                                          3)
                                 - 1)
                     AND NVL (x26_2.schedule_check, 'N') <> 'Y'
                     AND NVL (x26_2.status, 0) = 1
                     AND x26_2.requested_qty > 0
                     AND UPPER (oes.NAME) = 'RETAIL'
            ORDER BY oeh.order_number, oel.line_number;
    BEGIN
        /*Report for Errored REcords */
        fnd_file.put_line (
            fnd_file.output,
            '*********************************** Errored in Staging ********************************');
        fnd_file.put_line (
            fnd_file.output,
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
                fnd_file.output,
                   RPAD (rec_x26_e.seq_no, 8)
                || RPAD (rec_x26_e.distro_number, 15)
                || RPAD (rec_x26_e.document_type, 8)
                || RPAD (rec_x26_e.dc_dest_id, 12)
                || RPAD (rec_x26_e.dest_id, 10)
                || RPAD (rec_x26_e.brand, 8)
                || RPAD (rec_x26_e.item_id, 10)
                || RPAD (rec_x26_e.error_message, 250));
        END LOOP;

        fnd_file.put_line (fnd_file.output, ' ');
        fnd_file.put_line (fnd_file.output, ' ');
        /*Report for Processed Records */
        fnd_file.put_line (
            fnd_file.output,
            '************************************ Processed from Staging ***********************************');
        fnd_file.put_line (
            fnd_file.output,
               RPAD ('Seq No', 8)
            || RPAD ('Distro Number', 15)
            || RPAD ('D Type', 8)
            || RPAD ('DC Dest ID', 12)
            || RPAD ('Dest ID', 10)
            || RPAD ('Brand ', 8)
            || RPAD ('Item ID', 10));

        FOR rec_x26_s1 IN cur_print_audit_s1
        LOOP
            FOR rec_x26_s2
                IN cur_print_audit_s2 (rec_x26_s1.dc_dest_id,
                                       rec_x26_s1.dest_id,
                                       rec_x26_s1.brand)
            LOOP
                fnd_file.put_line (
                    fnd_file.output,
                       RPAD (rec_x26_s2.seq_no, 8)
                    || RPAD (rec_x26_s2.distro_number, 15)
                    || RPAD (rec_x26_s2.document_type, 8)
                    || RPAD (rec_x26_s2.dc_dest_id, 12)
                    || RPAD (rec_x26_s2.dest_id, 10)
                    || RPAD (rec_x26_s2.brand, 8)
                    || RPAD (rec_x26_s2.item_id, 10));
            END LOOP;

            fnd_file.put_line (fnd_file.output, '--- ');
            fnd_file.put_line (fnd_file.output, '--- ');
        END LOOP;

        /*Report for Errored REcords */
        fnd_file.put_line (
            fnd_file.output,
            '****************************************************************************************');
        fnd_file.put_line (
            fnd_file.output,
            '*********************************** Errored From Order Import ********************************');
        fnd_file.put_line (
            fnd_file.output,
            '****************************************************************************************');

        FOR rec_print_iface_e1 IN cur_print_iface_e1
        LOOP
            fnd_file.put_line (fnd_file.output, '--- ');
            fnd_file.put_line (
                fnd_file.output,
                'Document Reference ::' || rec_print_iface_e1.original_sys_document_ref);
            fnd_file.put_line (fnd_file.output, '--- ');
            fnd_file.put_line (
                fnd_file.output,
                   RPAD ('Seq No', 8)
                || RPAD ('Distro Number', 15)
                || RPAD ('D Type', 8)
                || RPAD ('DC Dest ID', 12)
                || RPAD ('Dest ID', 10)
                || RPAD ('Brand ', 8)
                || RPAD ('Item ID', 10)
                || RPAD ('Error Message', 250));

            FOR rec_print_iface_e2
                IN cur_print_iface_e2 (
                       rec_print_iface_e1.original_sys_document_ref)
            LOOP
                fnd_file.put_line (
                    fnd_file.output,
                       RPAD (rec_print_iface_e2.seq_no, 8)
                    || RPAD (rec_print_iface_e2.distro_number, 15)
                    || RPAD (rec_print_iface_e2.document_type, 8)
                    || RPAD (rec_print_iface_e2.dc_dest_id, 12)
                    || RPAD (rec_print_iface_e2.dest_id, 10)
                    || RPAD (rec_print_iface_e2.brand, 8)
                    || RPAD (rec_print_iface_e2.item_id, 10)
                    || RPAD (rec_print_iface_e2.MESSAGE_TEXT, 250));
            END LOOP;
        END LOOP;
    END print_audit_report;

    PROCEDURE so_cancel_prc (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_header_id IN NUMBER
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
        l_org                      NUMBER := 0;
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
        x_header_rec               oe_order_pub.header_rec_type;
        x_header_val_rec           oe_order_pub.header_val_rec_type;
        x_header_adj_tbl           oe_order_pub.header_adj_tbl_type;
        x_header_adj_val_tbl       oe_order_pub.header_adj_val_tbl_type;
        x_header_price_att_tbl     oe_order_pub.header_price_att_tbl_type;
        x_header_adj_att_tbl       oe_order_pub.header_adj_att_tbl_type;
        x_header_adj_assoc_tbl     oe_order_pub.header_adj_assoc_tbl_type;
        x_header_scredit_tbl       oe_order_pub.header_scredit_tbl_type;
        x_header_scredit_val_tbl   oe_order_pub.header_scredit_val_tbl_type;
        x_line_tbl                 oe_order_pub.line_tbl_type;
        x_line_val_tbl             oe_order_pub.line_val_tbl_type;
        x_line_adj_tbl             oe_order_pub.line_adj_tbl_type;
        x_line_adj_val_tbl         oe_order_pub.line_adj_val_tbl_type;
        x_line_price_att_tbl       oe_order_pub.line_price_att_tbl_type;
        x_line_adj_att_tbl         oe_order_pub.line_adj_att_tbl_type;
        x_line_adj_assoc_tbl       oe_order_pub.line_adj_assoc_tbl_type;
        x_line_scredit_tbl         oe_order_pub.line_scredit_tbl_type;
        x_line_scredit_val_tbl     oe_order_pub.line_scredit_val_tbl_type;
        x_lot_serial_tbl           oe_order_pub.lot_serial_tbl_type;
        x_lot_serial_val_tbl       oe_order_pub.lot_serial_val_tbl_type;
        x_action_request_tbl       oe_order_pub.request_tbl_type;
        x_header_rec2              oe_order_pub.header_rec_type;
        x_line_tbl2                oe_order_pub.line_tbl_type;
        x_line_tbl_null            oe_order_pub.line_tbl_type;
        x_header_rec_null          oe_order_pub.header_rec_type;
        x_debug_file               VARCHAR2 (100);
        v_message_index            NUMBER := 1;
        v_qty                      NUMBER := 0;
        v_action_request_tbl_out   oe_order_pub.request_tbl_type;
        v_action_request_tbl       oe_order_pub.request_tbl_type;

        -------------------------------------------------
        -- Select query to get the header_id, order_number
        -- Line_id, line_number and proejct_number
        -------------------------------------------------
        CURSOR cur_cancel_so IS
            SELECT oha.header_id header_id, oha.order_number order_number, ola.line_id line_id,
                   ola.line_number || '.' || ola.shipment_number line_number, ola.ordered_quantity ordered_quantity
              FROM apps.oe_order_headers_all oha, apps.oe_order_lines_all ola, apps.mtl_system_items msi
             WHERE     ola.header_id = oha.header_id
                   AND ola.ship_from_org_id = msi.organization_id
                   AND ola.inventory_item_id = msi.inventory_item_id
                   AND NVL (ola.open_flag, 'N') = 'Y'
                   AND ola.line_id = NVL (p_line_id, ola.line_id)
                   AND oha.header_id = NVL (p_header_id, oha.header_id) --AND OLA.line_id = 277130
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
            v_qty            := rec_cancel_so.ordered_quantity;

            BEGIN
                --         fnd_client_info.set_org_context(102);
                BEGIN
                    SELECT order_number, org_id
                      INTO v_order_number, l_org
                      FROM apps.oe_order_headers_all
                     WHERE header_id = v_header_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error while getting the order number : '
                            || v_order_number);
                        fnd_file.put_line (fnd_file.LOG,
                                           'SQL Error Code :' || SQLCODE);
                        fnd_file.put_line (fnd_file.LOG,
                                           'SQL Error Message :' || SQLERRM);
                END;

                mo_global.init ('ONT');
                --fnd_global.apps_initialize(user_id      => 2585,
                --                          resp_id      => 50864,
                --                         resp_appl_id => 660);
                fnd_file.put_line (fnd_file.LOG, 'ORG ID IS :' || l_org);
                mo_global.set_policy_context ('S', l_org);
                --fnd_client_info.set_org_context(l_org);
                --  fnd_global.apps_initialize(user_id      => 32270,
                --                      resp_id      => 53826,
                --                   resp_appl_id => 20024);
                --mo_global.set_policy_context('M', l_org);
                --fnd_client_info.set_org_context(l_org);
                --fnd_file.put_line(fnd_file.log,'ORG ID IS :'||l_org);
                oe_msg_pub.initialize;
                oe_debug_pub.initialize;

                IF GV_XXDO_SCHEDULE_DEBUG_VALUE = 'Y'
                THEN                                                     --2.5
                    oe_debug_pub.setdebuglevel (1);
                END IF;                                                  --2.5

                x_debug_file                       := oe_debug_pub.set_debug_mode ('FILE');
                x_line_tbl2                        := x_line_tbl_null;
                x_line_tbl2 (1)                    := oe_order_pub.g_miss_line_rec;
                x_line_tbl2 (1).header_id          := v_header_id;
                x_line_tbl2 (1).line_id            := v_line_id;
                x_line_tbl2 (1).cancelled_flag     := 'Y';
                x_line_tbl2 (1).ordered_quantity   := 0;
                x_line_tbl2 (1).change_reason      := 'SYSTEM';
                x_line_tbl2 (1).operation          := oe_globals.g_opr_update;
                v_action_request_tbl (1)           :=
                    oe_order_pub.g_miss_request_rec;
                oe_order_pub.process_order (
                    p_org_id                   => l_org,
                    p_api_version_number       => 1.0,
                    p_init_msg_list            => fnd_api.g_false,
                    p_return_values            => fnd_api.g_false,
                    p_action_commit            => fnd_api.g_false -- ,p_action_request_tbl          => v_action_request_tbl
                                                                 ,
                    x_return_status            => x_return_status,
                    x_msg_count                => x_msg_count,
                    x_msg_data                 => x_msg_data,
                    p_line_tbl                 => x_line_tbl2,
                    x_header_rec               => x_header_rec,
                    x_header_val_rec           => x_header_val_rec,
                    x_header_adj_tbl           => x_header_adj_tbl,
                    x_header_adj_val_tbl       => x_header_adj_val_tbl,
                    x_header_price_att_tbl     => x_header_price_att_tbl,
                    x_header_adj_att_tbl       => x_header_adj_att_tbl,
                    x_header_adj_assoc_tbl     => x_header_adj_assoc_tbl,
                    x_header_scredit_tbl       => x_header_scredit_tbl,
                    x_header_scredit_val_tbl   => x_header_scredit_val_tbl,
                    x_line_tbl                 => x_line_tbl,
                    x_line_val_tbl             => x_line_val_tbl,
                    x_line_adj_tbl             => x_line_adj_tbl,
                    x_line_adj_val_tbl         => x_line_adj_val_tbl,
                    x_line_price_att_tbl       => x_line_price_att_tbl,
                    x_line_adj_att_tbl         => x_line_adj_att_tbl,
                    x_line_adj_assoc_tbl       => x_line_adj_assoc_tbl,
                    x_line_scredit_tbl         => x_line_scredit_tbl,
                    x_line_scredit_val_tbl     => x_line_scredit_val_tbl,
                    x_lot_serial_tbl           => x_lot_serial_tbl,
                    x_lot_serial_val_tbl       => x_lot_serial_val_tbl,
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
                oe_msg_pub.get (p_msg_index => v_message_index, p_encoded => fnd_api.g_false, p_data => v_msg_data
                                , p_msg_index_out => v_msg_index_out);
                /*  fnd_file.put_line (fnd_file.LOG,
                                       'The Error Message Count is :-' || v_msg_index_out
                                      );
                    fnd_file.put_line (fnd_file.LOG,
                                       'The Error Message is :-' || v_msg_data
                                      );
                    fnd_file.put_line (fnd_file.LOG,
                                       'The Error Message is :-' || v_msg_data
                                      );
                    fnd_file.put_line (fnd_file.LOG,
                                       'The Error Message is :-' || v_msg_index_out
                                      ); */
                -- Commented for 2.0.

                -- START : 2.0.
                fnd_file.put_line (
                    fnd_file.LOG,
                    'The Error Message Count is :-' || v_msg_index_out);
                fnd_file.put_line (
                    fnd_file.OUTPUT,
                    'The Error Message Count is :-' || v_msg_index_out);
                fnd_file.put_line (fnd_file.LOG,
                                   'The Error Message is :-' || v_msg_data);
                fnd_file.put_line (fnd_file.OUTPUT,
                                   'The Error Message is :-' || v_msg_data);
            -- END : 2.0.
            /* COMMIT;
             fnd_file.put_line(fnd_file.output,
                               '*******************************************************');
             fnd_file.put_line(fnd_file.output,'Failure');
             fnd_file.put_line(fnd_file.output,
                               'The Sales Order Number :' ||
                               v_order_number);
             fnd_file.put_line(fnd_file.output,
                               'The Sales Order Line Number :' ||
                               v_Line_number);
             fnd_file.put_line(fnd_file.output,
                               'The Error Message Count:' ||v_msg_index_out);
             fnd_file.put_line(fnd_file.output,
                               'The Error Message Data:' ||v_msg_data);*/
            ELSIF (x_return_status = 'S')
            THEN
                COMMIT;
                p_status   := 'S';
            /*fnd_file.put_line(fnd_file.output,
                              '*******************************************************');
            fnd_file.put_line(fnd_file.output,'Success');
            fnd_file.put_line(fnd_file.log,'Success');
            fnd_file.put_line(fnd_file.output,
                              'The Sales Order Number :' ||
                              v_order_number);
            fnd_file.put_line(fnd_file.output,
                              'The Sales Order Line Number :' ||
                              v_Line_number);*/
            END IF;
        END LOOP;
    END so_cancel_prc;

    PROCEDURE chk_order_schedule (errbuf OUT VARCHAR2, retcode OUT VARCHAR2)
    AS
        --Commented By Naga DFCT0010450

        /*CURSOR cur_split_line IS
                SELECT
                            DISTINCT
                            OEH.ORDER_NUMBER
                           ,OEH.HEADER_ID
                           ,OEH.BOOKED_FLAG
                           ,OEH.org_id
                           ,X26_2.DC_VW_ID
                  FROM  OE_ORDER_HEADERS_ALL OEH
                           ,OE_ORDER_LINES_ALL OEL
                           ,OE_ORDER_SOURCES OES
                           ,XXDO_INV_INT_026_STG2 X26_2
                WHERE OEH.HEADER_ID = OEL.HEADER_ID
                    AND OEH.ORDER_SOURCE_ID = OES.ORDER_SOURCE_ID
                    AND X26_2.DISTRO_NUMBER = SUBSTR(OEL.ORIG_SYS_LINE_REF, 1, INSTR(OEL.ORIG_SYS_LINE_REF, '-', 1, 1)-1)
                    AND TO_CHAR(X26_2.XML_ID) = SUBSTR(OEL.ORIG_SYS_LINE_REF, INSTR(OEL.ORIG_SYS_LINE_REF, '-', 1, 3)+1)-- added by naga 14-FEB-2013
                    AND 'RMS'||'-'||X26_2.DEST_ID||'-'||X26_2.DC_DEST_ID = SUBSTR(OEH.ORIG_SYS_DOCUMENT_REF, 1, INSTR(OEH.ORIG_SYS_DOCUMENT_REF, '-', 1, 3)-1)
                    AND X26_2.ITEM_ID = OEL.INVENTORY_ITEM_ID
                    AND NVL(X26_2.SCHEDULE_CHECK, 'N') <> 'Y'
                    AND NVL(X26_2.STATUS, 0) = 1
        --            AND NVL(OEL.SCHEDULE_STATUS_CODE, 'NS') <> 'SCHEDULED'
        --            AND NVL(OEH.BOOKED_FLAG, 'N') = 'Y'
                    AND NVL(OEL.CANCELLED_FLAG, 'N') = 'N'
                    AND UPPER(OES.NAME) = 'RETAIL'
                    AND X26_2.REQUESTED_QTY > 0
                    AND OEH.order_type_id = FETCH_ORDER_TYPE('SHIP', OEH.org_id,X26_2.DC_VW_ID )
                    AND TRUNC(OEH.CREATION_DATE) = TRUNC(SYSDATE);*/

        -- Added below query by Naga DFCT0010450
        CURSOR cur_split_line (pn_org_id IN NUMBER) --Added parameter to cursor for change 2.4
        --      CURSOR cur_split_line --Commented for change 2.4
        IS
              SELECT /*+ parallel(10) */
                     COUNT (*), ooha.order_number, ooha.header_id, ---Added by 2.6 change
                     ooha.booked_flag, ooha.org_id, x26_2.dc_vw_id
                FROM apps.oe_order_sources oes, apps.oe_order_headers_all ooha, apps.oe_transaction_types_tl ottt,
                     apps.hr_operating_units hou, apps.fnd_lookup_values_vl flv, apps.oe_order_lines_all oola,
                     apps.xxdo_inv_int_026_stg2 x26_2
               WHERE     oes.NAME = 'Retail'
                     AND ooha.order_source_id = oes.order_source_id
                     --    and trunc(ooha.creation_Date) = trunc(sysdate)
                     AND ooha.creation_date >= TRUNC (SYSDATE - 1)
                     AND ooha.org_id = pn_org_id --Added operating unit condition for change 2.4
                     AND ottt.transaction_type_id = ooha.order_type_id
                     AND ottt.LANGUAGE = 'US'
                     AND UPPER (flv.lookup_code) = UPPER (ottt.NAME)
                     AND hou.organization_id = ooha.org_id
                     AND flv.lookup_type = 'XXDO_RMS_SO_RMA_ALLOCATION'
                     AND flv.description IN ('SHIP', 'LSHIP')
                     AND flv.enabled_flag = 'Y'
                     AND flv.attribute_category = 'XXDO_RMS_SO_RMA_ALLOCATION'
                     AND flv.tag = hou.NAME
                     AND oola.header_id = ooha.header_id
                     AND (oola.cancelled_flag IS NULL OR oola.cancelled_flag = 'N')
                     AND x26_2.distro_number = SUBSTR (oola.orig_sys_line_ref,
                                                       1,
                                                         INSTR (oola.orig_sys_line_ref, '-', 1
                                                                , 1)
                                                       - 1)
                     AND TO_CHAR (x26_2.xml_id) =
                         SUBSTR (oola.orig_sys_line_ref,
                                   INSTR (oola.orig_sys_line_ref, '-', 1,
                                          3)
                                 + 1)
                     -- Changes for CCR0007197
                     AND TO_CHAR (x26_2.seq_no) =
                         (SUBSTR (oola.orig_sys_line_ref,
                                    INSTR (oola.orig_sys_line_ref, '-', 1,
                                           2)
                                  + 1,
                                    (  INSTR (oola.orig_sys_line_ref, '-', 1,
                                              3)
                                     - INSTR (oola.orig_sys_line_ref, '-', 1,
                                              2))
                                  - 1))
                     -- Changes for CCR0007197
                     AND (x26_2.schedule_check IS NULL OR x26_2.schedule_check != 'Y')
                     AND (x26_2.status IS NOT NULL OR x26_2.status = 1)
                     AND x26_2.requested_qty > 0
                     AND x26_2.item_id = oola.inventory_item_id
                     AND x26_2.dc_vw_id IN
                             (flv.attribute11, flv.attribute9, flv.attribute2,
                              flv.attribute1, flv.attribute3, flv.attribute4,
                              flv.attribute5, flv.attribute6, flv.attribute7,
                              flv.attribute8, flv.attribute10, flv.attribute12,
                              flv.attribute13, flv.attribute14, flv.attribute15)
                     AND    'RMS'
                         || '-'
                         || x26_2.dest_id
                         || '-'
                         || x26_2.dc_dest_id =
                         SUBSTR (ooha.orig_sys_document_ref,
                                 1,
                                   INSTR (ooha.orig_sys_document_ref, '-', 1,
                                          3)
                                 - 1)
            GROUP BY ooha.order_number, ooha.header_id, ooha.booked_flag,
                     ooha.org_id, x26_2.dc_vw_id;

        --Commented by Naga DFCT0010450
        /*   CURSOR cur_chk_order_schedule IS
              SELECT /*+ INDEX(OES OE_ORDER_SOURCES_U1)
                                INDEX(X26_2 XXDO_INV_INT_26_U1)
                    DISTINCT
                    OEH.ORDER_NUMBER
                   ,OEH.HEADER_ID
                   ,OEL.LINE_NUMBER ORDER_LINE_NUM
                   ,OEL.LINE_ID
                   ,X26_2.DISTRO_NUMBER
                   ,X26_2.DEST_ID
                   ,X26_2.DC_DEST_ID
                   ,X26_2.DOCUMENT_TYPE
                   ,OEL.ORDERED_QUANTITY QTY
                   ,X26_2.XML_ID
                   ,OEL.SCHEDULE_STATUS_CODE
                   ,OEH.BOOKED_FLAG
                   ,OEL.INVENTORY_ITEM_ID
                   ,DECODE(OEL.SCHEDULE_STATUS_CODE, 'SCHEDULED', 'DS', 'NI') STATUS
                   ,X26_2.ROWID
          FROM  OE_ORDER_HEADERS_ALL OEH
                   ,OE_ORDER_LINES_ALL OEL
                   ,OE_ORDER_SOURCES OES
                   ,XXDO_INV_INT_026_STG2 X26_2
        WHERE OEH.HEADER_ID = OEL.HEADER_ID
            AND OEH.ORDER_SOURCE_ID = OES.ORDER_SOURCE_ID
            AND X26_2.DISTRO_NUMBER = SUBSTR(OEL.ORIG_SYS_LINE_REF, 1, INSTR(OEL.ORIG_SYS_LINE_REF, '-', 1, 1)-1)
            AND TO_CHAR(X26_2.XML_ID) = SUBSTR(OEL.ORIG_SYS_LINE_REF, INSTR(OEL.ORIG_SYS_LINE_REF, '-', 1, 3)+1)-- added by naga 14-FEB-2013
            AND 'RMS'||'-'||X26_2.DEST_ID||'-'||X26_2.DC_DEST_ID = SUBSTR(OEH.ORIG_SYS_DOCUMENT_REF, 1, INSTR(OEH.ORIG_SYS_DOCUMENT_REF, '-', 1, 3)-1)
            AND X26_2.ITEM_ID = OEL.INVENTORY_ITEM_ID
            AND NVL(X26_2.SCHEDULE_CHECK, 'N') <> 'Y'
            AND NVL(X26_2.STATUS, 0) = 1
    --        AND NVL(OEH.BOOKED_FLAG, 'N') = 'Y'
            AND NVL(OEL.CANCELLED_FLAG, 'N') = 'N'
            AND UPPER(OES.NAME) = 'RETAIL'
                AND X26_2.REQUESTED_QTY > 0
            AND OEH.order_type_id = FETCH_ORDER_TYPE('SHIP', OEH.org_id,X26_2.DC_VW_ID)
            AND TRUNC(OEH.CREATION_DATE) = TRUNC(SYSDATE)
        UNION ALL
                  SELECT /*+ INDEX(X26_2 XXDO_INV_INT_26_U1)
                    OEH.ORDER_NUMBER
                   ,OEH.HEADER_ID
                   ,OEL1.LINE_NUMBER ORDER_LINE_NUM
                   ,OEL1.LINE_ID
                   ,X26_2.DISTRO_NUMBER
                   ,X26_2.DEST_ID
                   ,X26_2.DC_DEST_ID
                   ,X26_2.DOCUMENT_TYPE
                   ,OEL1.ORDERED_QUANTITY QTY
                   ,X26_2.XML_ID
                   ,OEL1.SCHEDULE_STATUS_CODE
                   ,OEH.BOOKED_FLAG
                   ,OEL1.INVENTORY_ITEM_ID
                   ,DECODE(OEL1.SCHEDULE_STATUS_CODE, 'SCHEDULED', 'DS', 'NI') STATUS
                   ,X26_2.ROWID
          FROM  OE_ORDER_HEADERS_ALL OEH
                   ,OE_ORDER_LINES_ALL OEL
                   ,OE_ORDER_LINES_ALL OEL1
                   ,OE_ORDER_SOURCES OES
                   ,XXDO_INV_INT_026_STG2 X26_2
        WHERE OEL1.HEADER_ID = OEH.HEADER_ID
            AND OEL1.ORDER_SOURCE_ID = OES.ORDER_SOURCE_ID
            AND OEH.ORDER_SOURCE_ID = OES.ORDER_SOURCE_ID
            AND OEL.LINE_ID = OEL1.SPLIT_FROM_LINE_ID
            AND OEL1.SPLIT_FROM_LINE_ID IS NOT NULL
            AND X26_2.DISTRO_NUMBER = SUBSTR(OEL.ORIG_SYS_LINE_REF, 1, INSTR(OEL.ORIG_SYS_LINE_REF, '-', 1, 1)-1)
            AND TO_CHAR(X26_2.XML_ID) = SUBSTR(OEL.ORIG_SYS_LINE_REF, INSTR(OEL.ORIG_SYS_LINE_REF, '-', 1, 3)+1)-- added by naga 14-FEB-2013
            AND 'RMS'||'-'||X26_2.DEST_ID||'-'||X26_2.DC_DEST_ID = SUBSTR(OEH.ORIG_SYS_DOCUMENT_REF, 1, INSTR(OEH.ORIG_SYS_DOCUMENT_REF, '-', 1, 3)-1)
            AND X26_2.ITEM_ID = OEL1.INVENTORY_ITEM_ID
            AND X26_2.ITEM_ID = OEL.INVENTORY_ITEM_ID
            AND NVL(X26_2.SCHEDULE_CHECK, 'N') <> 'Y'
            AND NVL(X26_2.STATUS, 0) = 1
    --        AND NVL(OEH.BOOKED_FLAG, 'N') = 'Y'
            AND NVL(OEL1.CANCELLED_FLAG, 'N') = 'N'
            AND NVL(OEL.CANCELLED_FLAG, 'N') = 'N'
            AND UPPER(OES.NAME) = 'RETAIL'
            AND NVL(OEL1.OPEN_FLAG, 'N') = 'Y'
            AND NVL(OEL.OPEN_FLAG, 'N') = 'Y'
            --AND OEH.ORG_ID = 2
            AND OEH.ORDER_TYPE_ID = xxdo_om_int_026_stg_pkg.FETCH_ORDER_TYPE('SHIP', OEH.ORG_ID,X26_2.DC_VW_ID)
            AND TRUNC(OEH.CREATION_DATE) = TRUNC(SYSDATE)
                AND X26_2.REQUESTED_QTY > 0
        ORDER BY 1, 3;*/

        --Added below cursor by Naga DFCT0010450
        CURSOR cur_chk_order_schedule (pn_org_id IN NUMBER) --Added operating unit parameter for change 2.4
        --CURSOR cur_chk_order_schedule --Commented for change 2.4
        IS
            /*+ INDEX(OES OE_ORDER_SOURCES_U1)
                            INDEX(X26_2 XXDO_INV_INT_26_U1)*/

            SELECT /*+ parallel(10) */
                   DISTINCT oeh.order_number, oeh.header_id, ---Added by 2.6 change of parallel hint
                                                             oel.line_number order_line_num,
                            oel.line_id, x26_2.distro_number, x26_2.dest_id,
                            x26_2.dc_dest_id, x26_2.document_type, oel.ordered_quantity qty,
                            x26_2.xml_id, oel.schedule_status_code, oeh.booked_flag,
                            oel.inventory_item_id, DECODE (oel.schedule_status_code, 'SCHEDULED', 'DS', 'NI') status, x26_2.ROWID
              FROM oe_order_headers_all oeh, oe_order_lines_all oel, oe_order_sources oes,
                   xxdo_inv_int_026_stg2 x26_2, apps.fnd_lookup_values_vl flv, apps.hr_operating_units hou,
                   apps.oe_transaction_types_tl ottl
             WHERE     oeh.header_id = oel.header_id
                   AND oeh.order_source_id = oes.order_source_id
                   AND NVL (oel.cancelled_flag, 'N') = 'N'
                   AND UPPER (oes.NAME) = 'RETAIL'
                   AND oeh.org_id = pn_org_id --Added operating unit condition for change 2.4
                   --AND OEH.order_type_id = FETCH_ORDER_TYPE('SHIP', OEH.org_id,X26_2.DC_VW_ID)
                   AND oeh.order_type_id = ottl.transaction_type_id
                   ---  AND TRUNC(OEH.CREATION_DATE) = TRUNC(SYSDATE)
                   AND oeh.creation_date >= TRUNC (SYSDATE - 1)
                   AND flv.lookup_type = 'XXDO_RMS_SO_RMA_ALLOCATION'
                   AND UPPER (flv.lookup_code) = UPPER (ottl.NAME)
                   AND hou.NAME = flv.tag
                   AND flv.description IN ('SHIP', 'LSHIP')
                   AND hou.organization_id = oeh.org_id
                   AND ottl.LANGUAGE = 'US'
                   AND flv.enabled_flag = 'Y'
                   AND flv.attribute_category = 'XXDO_RMS_SO_RMA_ALLOCATION'
                   AND (flv.attribute1 = x26_2.dc_vw_id OR flv.attribute2 = x26_2.dc_vw_id OR flv.attribute3 = x26_2.dc_vw_id OR flv.attribute4 = x26_2.dc_vw_id OR flv.attribute5 = x26_2.dc_vw_id OR flv.attribute6 = x26_2.dc_vw_id OR flv.attribute7 = x26_2.dc_vw_id OR flv.attribute8 = x26_2.dc_vw_id OR flv.attribute9 = x26_2.dc_vw_id OR flv.attribute10 = x26_2.dc_vw_id OR flv.attribute11 = x26_2.dc_vw_id OR flv.attribute12 = x26_2.dc_vw_id OR flv.attribute13 = x26_2.dc_vw_id OR flv.attribute14 = x26_2.dc_vw_id OR flv.attribute15 = x26_2.dc_vw_id)
                   AND x26_2.requested_qty > 0
                   AND x26_2.distro_number = SUBSTR (oel.orig_sys_line_ref,
                                                     1,
                                                       INSTR (oel.orig_sys_line_ref, '-', 1
                                                              , 1)
                                                     - 1)
                   AND TO_CHAR (x26_2.xml_id) =
                       SUBSTR (oel.orig_sys_line_ref,
                                 INSTR (oel.orig_sys_line_ref, '-', 1,
                                        3)
                               + 1)               -- added by naga 14-FEB-2013
                   -- Changes for CCR0007197
                   AND TO_CHAR (x26_2.seq_no) =
                       (SUBSTR (oel.orig_sys_line_ref,
                                  INSTR (oel.orig_sys_line_ref, '-', 1,
                                         2)
                                + 1,
                                  (  INSTR (oel.orig_sys_line_ref, '-', 1,
                                            3)
                                   - INSTR (oel.orig_sys_line_ref, '-', 1,
                                            2))
                                - 1))
                   -- Changes for CCR0007197
                   AND    'RMS'
                       || '-'
                       || x26_2.dest_id
                       || '-'
                       || x26_2.dc_dest_id =
                       SUBSTR (oeh.orig_sys_document_ref,
                               1,
                                 INSTR (oeh.orig_sys_document_ref, '-', 1,
                                        3)
                               - 1)
                   AND x26_2.item_id = oel.inventory_item_id
                   AND NVL (x26_2.schedule_check, 'N') <> 'Y'
                   AND NVL (x26_2.status, 0) = 1
            UNION ALL
            SELECT /*+ INDEX(X26_2 XXDO_INV_INT_26_U1)*/
                   oeh.order_number, oeh.header_id, oel1.line_number order_line_num,
                   oel1.line_id, x26_2.distro_number, x26_2.dest_id,
                   x26_2.dc_dest_id, x26_2.document_type, oel1.ordered_quantity qty,
                   x26_2.xml_id, oel1.schedule_status_code, oeh.booked_flag,
                   oel1.inventory_item_id, DECODE (oel1.schedule_status_code, 'SCHEDULED', 'DS', 'NI') status, x26_2.ROWID
              FROM oe_order_headers_all oeh, oe_order_lines_all oel, oe_order_lines_all oel1,
                   oe_order_sources oes, xxdo_inv_int_026_stg2 x26_2, apps.fnd_lookup_values_vl flv,
                   apps.hr_operating_units hou, apps.oe_transaction_types_tl ottl
             WHERE     oel1.header_id = oeh.header_id
                   AND oel1.order_source_id = oes.order_source_id
                   AND oeh.order_source_id = oes.order_source_id
                   AND oel.line_id = oel1.split_from_line_id
                   AND oel1.split_from_line_id IS NOT NULL
                   AND NVL (oel1.cancelled_flag, 'N') = 'N'
                   AND NVL (oel.cancelled_flag, 'N') = 'N'
                   AND UPPER (oes.NAME) = 'RETAIL'
                   AND oeh.org_id = pn_org_id --Added operating unit condition for change 2.4
                   AND NVL (oel1.open_flag, 'N') = 'Y'
                   AND NVL (oel.open_flag, 'N') = 'Y'
                   -- AND OEH.ORDER_TYPE_ID = xxdo_om_int_026_stg_pkg.FETCH_ORDER_TYPE('SHIP', OEH.ORG_ID,X26_2.DC_VW_ID)
                   AND oeh.order_type_id = ottl.transaction_type_id
                   --   AND TRUNC(OEH.CREATION_DATE) = TRUNC(SYSDATE)
                   AND oeh.creation_date >= SYSDATE - 1
                   AND flv.lookup_type = 'XXDO_RMS_SO_RMA_ALLOCATION'
                   AND UPPER (flv.lookup_code) = UPPER (ottl.NAME)
                   AND hou.NAME = flv.tag
                   AND flv.description IN ('SHIP', 'LSHIP')
                   AND hou.organization_id = oeh.org_id
                   AND ottl.LANGUAGE = 'US'
                   AND flv.enabled_flag = 'Y'
                   AND flv.attribute_category = 'XXDO_RMS_SO_RMA_ALLOCATION'
                   AND (flv.attribute1 = x26_2.dc_vw_id OR flv.attribute2 = x26_2.dc_vw_id OR flv.attribute3 = x26_2.dc_vw_id OR flv.attribute4 = x26_2.dc_vw_id OR flv.attribute5 = x26_2.dc_vw_id OR flv.attribute6 = x26_2.dc_vw_id OR flv.attribute7 = x26_2.dc_vw_id OR flv.attribute8 = x26_2.dc_vw_id OR flv.attribute9 = x26_2.dc_vw_id OR flv.attribute10 = x26_2.dc_vw_id OR flv.attribute11 = x26_2.dc_vw_id OR flv.attribute12 = x26_2.dc_vw_id OR flv.attribute13 = x26_2.dc_vw_id OR flv.attribute14 = x26_2.dc_vw_id OR flv.attribute15 = x26_2.dc_vw_id)
                   AND x26_2.distro_number = SUBSTR (oel.orig_sys_line_ref,
                                                     1,
                                                       INSTR (oel.orig_sys_line_ref, '-', 1
                                                              , 1)
                                                     - 1)
                   AND TO_CHAR (x26_2.xml_id) =
                       SUBSTR (oel.orig_sys_line_ref,
                                 INSTR (oel.orig_sys_line_ref, '-', 1,
                                        3)
                               + 1)               -- added by naga 14-FEB-2013
                   -- Changes for CCR0007197
                   AND TO_CHAR (x26_2.seq_no) =
                       (SUBSTR (oel.orig_sys_line_ref,
                                  INSTR (oel.orig_sys_line_ref, '-', 1,
                                         2)
                                + 1,
                                  (  INSTR (oel.orig_sys_line_ref, '-', 1,
                                            3)
                                   - INSTR (oel.orig_sys_line_ref, '-', 1,
                                            2))
                                - 1))
                   -- Changes for CCR0007197
                   AND    'RMS'
                       || '-'
                       || x26_2.dest_id
                       || '-'
                       || x26_2.dc_dest_id =
                       SUBSTR (oeh.orig_sys_document_ref,
                               1,
                                 INSTR (oeh.orig_sys_document_ref, '-', 1,
                                        3)
                               - 1)
                   AND x26_2.item_id = oel1.inventory_item_id
                   AND x26_2.item_id = oel.inventory_item_id
                   AND NVL (x26_2.schedule_check, 'N') <> 'Y'
                   AND NVL (x26_2.status, 0) = 1
                   AND x26_2.requested_qty > 0
            ORDER BY 1, 3;

        lv_errbuf          VARCHAR2 (100);
        lv_retcode         VARCHAR2 (100);
        lv_cancel_status   VARCHAR2 (1) := 'S';
        --    ln_kco_no          NUMBER; -- Commented for 1.9.
        ln_org_id          NUMBER := apps.fnd_global.org_id; --Added for change 2.4
    BEGIN
        ---2.5 Start
        GV_XXDO_SCHEDULE_DEBUG_VALUE   := NULL;

        BEGIN
            SELECT APPS.FND_PROFILE.VALUE ('XXDO_OM_SCHEDULE_DEBUG_USE')
              INTO GV_XXDO_SCHEDULE_DEBUG_VALUE
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.output,
                    'This Profile option is not set to any value');
        END;

        ---2.5 End

        IF GV_XXDO_SCHEDULE_DEBUG_VALUE = 'Y'
        THEN                                                           ----2.5
            fnd_file.put_line (
                fnd_file.output,
                '******************Splitting Order*************************');
            fnd_file.put_line (fnd_file.output, RPAD ('Order Number', 20));
        END IF;                                                          --2.5

        FOR rec_split_line IN cur_split_line (ln_org_id) --Added parameter for change 2.4
        --      FOR rec_split_line IN cur_split_line --Commented for change 2.4
        LOOP
            /* -- BEGIN : Commented for 1.9.
               BEGIN
                  --fnd_file.put_line(Fnd_file.log,'KCO Beginning');
                  ln_kco_no :=
                     xxdo_get_kco_header_id (rec_split_line.header_id,
                                             rec_split_line.dc_vw_id
                                            );
                  fnd_file.put_line (fnd_file.LOG, '**KCO**');

                  fnd_file.put_line (fnd_file.LOG,
                                        'SALES ORDER HEADER ID :'
                                     || rec_split_line.header_id
                                    );
                  fnd_file.put_line (fnd_file.LOG, 'KCO ID :' || ln_kco_no);
                  --insert into xxdo_kco(header_id,kco_id) values (rec_split_line.header_id,ln_kco_no);
                  COMMIT;

                  BEGIN
                     UPDATE oe_order_headers_all oeh
                        SET attribute9 = TO_CHAR (ln_kco_no)
                      WHERE header_id = rec_split_line.header_id
                        AND org_id = rec_split_line.org_id;
                  EXCEPTION
                     WHEN OTHERS
                     THEN
                        fnd_file.put_line (fnd_file.LOG,
                                           'Exception while updating KCO'
                                          );
                        fnd_file.put_line (fnd_file.LOG,
                                           'Header ID :' || rec_split_line.header_id
                                          );
                        fnd_file.put_line (fnd_file.LOG, 'KCO ID :' || ln_kco_no);
                  END;

                  COMMIT;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     fnd_file.put_line (fnd_file.LOG,
                                           'Error while Updating the KCO Details :'
                                        || SQLERRM
                                       );
                     fnd_file.put_line (fnd_file.LOG,
                                           'Error while Updating the KCO Details :'
                                        || SQLERRM
                                       );
               END;
               */
            -- END : Commented for 1.9.

            /* Booking the Order by passing order header id */
            BEGIN
                xxdo_rms_book_order (rec_split_line.header_id);
                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    /*   fnd_file.put_line (fnd_file.LOG,
                                               'Error while Booking The Sales Order:'
                                            || SQLERRM
                                           );
                         fnd_file.put_line (fnd_file.LOG,
                                               'Error while Booking The Sales Order :'
                                            || SQLERRM
                                           ); */
                    -- Commented for 2.0.

                    -- START : 2.0.
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error while Booking The Sales Order. Error Code : '
                        || SQLCODE
                        || '. Error Message : '
                        || SQLERRM);
                    fnd_file.put_line (
                        fnd_file.OUTPUT,
                           'Error while Booking The Sales Order. Error Code : '
                        || SQLCODE
                        || '. Error Message : '
                        || SQLERRM);
            -- END : 2.0.
            END;

            /*Split and Schedule Lines */
            BEGIN
                do_oe_utils.split_and_schedule (
                    p_oi_header_id => rec_split_line.header_id);

                IF GV_XXDO_SCHEDULE_DEBUG_VALUE = 'Y'
                THEN                                                     --2.5
                    fnd_file.put_line (
                        fnd_file.output,
                        RPAD (rec_split_line.order_number, 20));
                END IF;                                                  --2.5
            EXCEPTION
                WHEN OTHERS
                THEN
                    /* fnd_file.put_line (fnd_file.LOG,
                                             'Error while Doing Split and Schedule:'
                                          || SQLERRM
                                         );
                       fnd_file.put_line (fnd_file.LOG,
                                             'Error while Doing Split and Schedule:'
                                          || SQLERRM
                                         ); */
                    -- Commented for 2.0.
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error while Doing Split and Schedule. Error Code : '
                        || SQLCODE
                        || '. Error Message : '
                        || SQLERRM);
                    fnd_file.put_line (
                        fnd_file.OUTPUT,
                           'Error while Doing Split and Schedule. Error Code : '
                        || SQLCODE
                        || '. Error Message : '
                        || SQLERRM);
            END;
        END LOOP;

        IF GV_XXDO_SCHEDULE_DEBUG_VALUE = 'Y'
        THEN                                                             --2.5
            fnd_file.put_line (
                fnd_file.output,
                '*******************************************************************');
            fnd_file.put_line (
                fnd_file.output,
                   RPAD ('Order Num', 10)
                || RPAD ('Line Num', 9)
                || RPAD ('Distro Number', 15)
                || RPAD ('Qty', 7)
                || RPAD ('Book Flag', 10)
                || RPAD ('Sch Status ', 11)
                || RPAD ('Status', 20));
        END IF;                                                          --2.5

        FOR rec_order_sch IN cur_chk_order_schedule (ln_org_id) --Added for change 2.4
        --FOR rec_order_sch IN cur_chk_order_schedule  --Commented for change 2.4
        LOOP
            IF GV_XXDO_SCHEDULE_DEBUG_VALUE = 'Y'
            THEN                                                         --2.5
                fnd_file.put_line (
                    fnd_file.LOG,
                    'TEST 100-   ' || rec_order_sch.dc_dest_id);
            END IF;                                                      --2.5

            IF rec_order_sch.status = 'DS'
            THEN
                IF GV_XXDO_SCHEDULE_DEBUG_VALUE = 'Y'
                THEN                                                     --2.5
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'DS TEST 100-   ' || rec_order_sch.dc_dest_id);
                END IF;                                                  --2.5

                xxdo_int_009_prc (lv_errbuf, lv_retcode, rec_order_sch.dc_dest_id, rec_order_sch.distro_number, rec_order_sch.document_type, rec_order_sch.distro_number, rec_order_sch.dest_id, rec_order_sch.inventory_item_id, rec_order_sch.order_line_num
                                  , rec_order_sch.qty, rec_order_sch.status);

                IF GV_XXDO_SCHEDULE_DEBUG_VALUE = 'Y'
                THEN                                                     --2.5
                    fnd_file.put_line (
                        fnd_file.output,
                           RPAD (rec_order_sch.order_number, 10)
                        || RPAD (rec_order_sch.order_line_num, 9)
                        || RPAD (rec_order_sch.distro_number, 15)
                        || RPAD (rec_order_sch.qty, 7)
                        || RPAD (rec_order_sch.booked_flag, 10)
                        || RPAD (rec_order_sch.schedule_status_code, 11)
                        || RPAD (rec_order_sch.status, 10));
                END IF;                                                  --2.5

                BEGIN
                    UPDATE xxdo_inv_int_026_stg2 x26_2
                       SET schedule_check   = 'Y'
                     WHERE x26_2.ROWID = rec_order_sch.ROWID;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error while Updating Schedule Check DS '
                            || rec_order_sch.header_id
                            || ' - '
                            || rec_order_sch.line_id
                            || ' --- '
                            || SQLERRM);
                END;
            ELSIF rec_order_sch.status = 'NI'
            THEN
                IF GV_XXDO_SCHEDULE_DEBUG_VALUE = 'Y'
                THEN                                                     --2.5
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'NI TEST 100-   ' || rec_order_sch.dc_dest_id);
                END IF;                                                  --2.5

                BEGIN
                    so_cancel_prc (lv_errbuf, lv_retcode, rec_order_sch.header_id
                                   , rec_order_sch.line_id, lv_cancel_status);

                    IF GV_XXDO_SCHEDULE_DEBUG_VALUE = 'Y'
                    THEN                                                 --2.5
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Cancel Status :' || lv_cancel_status);
                    END IF;                                              --2.5
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error in Cancelling the Sales Order '
                            || rec_order_sch.header_id
                            || ' - '
                            || rec_order_sch.line_id
                            || ' --- '
                            || SQLERRM);
                END;

                IF NVL (lv_cancel_status, 'E') = 'S'
                THEN
                    IF GV_XXDO_SCHEDULE_DEBUG_VALUE = 'Y'
                    THEN                                                 --2.5
                        fnd_file.put_line (
                            fnd_file.output,
                               RPAD (rec_order_sch.order_number, 10)
                            || RPAD (rec_order_sch.order_line_num, 9)
                            || RPAD (rec_order_sch.distro_number, 15)
                            || RPAD (rec_order_sch.qty, 7)
                            || RPAD (rec_order_sch.booked_flag, 10)
                            || RPAD (rec_order_sch.schedule_status_code, 11)
                            || RPAD ('Cancelled', 10));
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'NI TEST 100-   ' || rec_order_sch.dc_dest_id);
                    END IF;                                              --2.5

                    xxdo_int_009_prc (lv_errbuf,
                                      lv_retcode,
                                      rec_order_sch.dc_dest_id,
                                      rec_order_sch.distro_number,
                                      rec_order_sch.document_type,
                                      rec_order_sch.distro_number,
                                      rec_order_sch.dest_id,
                                      rec_order_sch.inventory_item_id,
                                      rec_order_sch.order_line_num,
                                      rec_order_sch.qty,
                                      rec_order_sch.status);

                    IF GV_XXDO_SCHEDULE_DEBUG_VALUE = 'Y'
                    THEN                                                 --2.5
                        fnd_file.put_line (
                            fnd_file.output,
                               RPAD (rec_order_sch.order_number, 10)
                            || RPAD (rec_order_sch.order_line_num, 9)
                            || RPAD (rec_order_sch.distro_number, 15)
                            || RPAD (rec_order_sch.qty, 7)
                            || RPAD (rec_order_sch.booked_flag, 10)
                            || RPAD (rec_order_sch.schedule_status_code, 11)
                            || RPAD (rec_order_sch.status, 10));
                    END IF;                                              --2.5

                    BEGIN
                        UPDATE xxdo_inv_int_026_stg2 x26_2
                           SET schedule_check   = 'Y'
                         WHERE x26_2.ROWID = rec_order_sch.ROWID;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error while Updating Schedule Check NI '
                                || rec_order_sch.header_id
                                || ' - '
                                || rec_order_sch.line_id
                                || ' --- '
                                || SQLERRM);
                    END;
                END IF;
            END IF;
        END LOOP;

        fnd_file.put_line (
            fnd_file.output,
            '*******************************************************************');
    END chk_order_schedule;

    FUNCTION fetch_order_type (pv_ship_return IN VARCHAR2, pn_org_id IN NUMBER, pn_vw_id IN NUMBER
                               , pn_str_nbr IN NUMBER)
        RETURN NUMBER
    AS
        ln_order_type_id   NUMBER;
        lv_status          VARCHAR2 (10);
        lv_error_message   VARCHAR2 (240);
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        fetch_order_type (pv_ship_return, pn_org_id, pn_vw_id,
                          pn_str_nbr, ln_order_type_id, lv_status,
                          lv_error_message);
        RETURN ln_order_type_id;
    -- START : 2.0.
    EXCEPTION
        WHEN OTHERS
        THEN
            --W.r.t version 2.3
            BEGIN
                INSERT INTO custom.do_debug (created_by,
                                             application_id,
                                             CREATION_DATE,
                                             debug_text,
                                             session_id,
                                             call_stack)
                         VALUES (
                                    '-1',
                                    'SOA',
                                    SYSDATE,
                                    lv_error_message,
                                    USERENV ('SESSIONID'),
                                    SUBSTR (
                                        ('ship_return' || pv_ship_return || 'Org id' || pn_org_id || 'vw_id' || pn_vw_id || 'str_nbr' || pn_str_nbr || ' lv_status ' || lv_status || ' order_type_id ' || ln_order_type_id),
                                        1,
                                        2000));
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            COMMIT;

            NULL;
    /*
    fnd_file.put_line
            (fnd_file.LOG,
                'Error while fetching Order Type for PV_SHIP_RETURN : '
             || pv_ship_return
             || ', PN_ORG_ID : '
             || pn_org_id
             || ', PN_VW_ID : '
             || pn_vw_id
             || ', PN_STR_NBR : '
             || pn_str_nbr
             || '. Error Code : '
             || SQLCODE
             || '. Error Message : '
             || SQLERRM
            );
            */
    -- END : 2.0.
    END;

    PROCEDURE schedule_order (retcode             OUT VARCHAR2,
                              errbuf              OUT VARCHAR2,
                              p_order_number   IN     NUMBER)
    IS
        l_scheduled_ship_date   DATE;
        ln_request_id           NUMBER;
        lv_submit               NUMBER := 0;
        lv_success              BOOLEAN;
        lv_dev_phase            VARCHAR2 (50);
        lv_dev_status           VARCHAR2 (50);
        lv_status               VARCHAR2 (50);
        lv_phase                VARCHAR2 (50);
        lv_message              VARCHAR2 (240);
        lv_errbuf               VARCHAR2 (100);
        lv_cancel_status        VARCHAR2 (1) := 'S';
        lv_retcode              VARCHAR2 (100);

        -- Commented by Naga DFCT0010450
        /*cursor c_order_in_booked_status(p_order_number number)
        is

         SELECT  distinct
                            OEH.ORDER_NUMBER
                           ,OEH.HEADER_ID
                           ,OEH.BOOKED_FLAG
                           ,OEH.org_id
                           ,oeh.CUST_PO_NUMBER
                      --     ,oel.LINE_ID
                      --     ,oel.line_number
                      --     ,oel.INVENTORY_ITEM_ID
                       --    ,oel.ordered_quantity
                      --     ,do_inv_utils_pub.item_onhand_quantity(oel.ship_from_org_id,oel.inventory_item_id) onhand_qty
                        --   ,oel.ship_from_org_id
                          -- ,oel.flow_status_code
                  FROM  apps.OE_ORDER_HEADERS_ALL OEH
                           ,apps.OE_ORDER_LINES_ALL OEL
                           ,apps.OE_ORDER_SOURCES OES
                           ,xxdo.XXDO_INV_INT_026_STG2 X26_2
                WHERE OEH.HEADER_ID = OEL.HEADER_ID
                    AND OEH.ORDER_SOURCE_ID = OES.ORDER_SOURCE_ID
                    AND X26_2.DISTRO_NUMBER = SUBSTR(OEL.ORIG_SYS_LINE_REF, 1, INSTR(OEL.ORIG_SYS_LINE_REF, '-', 1, 1)-1)
                    AND TO_CHAR(X26_2.XML_ID) = SUBSTR(OEL.ORIG_SYS_LINE_REF, INSTR(OEL.ORIG_SYS_LINE_REF, '-', 1, 3)+1)-- added by naga 14-FEB-2013
                    AND 'RMS'||'-'||X26_2.DEST_ID||'-'||X26_2.DC_DEST_ID = SUBSTR(OEH.ORIG_SYS_DOCUMENT_REF, 1, INSTR(OEH.ORIG_SYS_DOCUMENT_REF, '-', 1, 3)-1)
                    AND X26_2.ITEM_ID = OEL.INVENTORY_ITEM_ID
                    AND NVL(X26_2.STATUS, 0) = 1
                    AND NVL(OEH.BOOKED_FLAG, 'N') = 'Y'
                    AND NVL(OEL.CANCELLED_FLAG, 'N') = 'N'
                    and oel.flow_status_code ='BOOKED'
                    AND UPPER(OES.NAME) = 'RETAIL'
                    and oel.ORDERED_QUANTITY<=do_inv_utils_pub.item_onhand_quantity(oel.ship_from_org_id,oel.inventory_item_id)
                    AND X26_2.REQUESTED_QTY > 0
                    AND OEH.order_type_id =xxdo_om_int_026_stg_pkg.FETCH_ORDER_TYPE('SHIP', OEH.org_id,X26_2.DC_VW_ID)
                    and oeh.order_number=nvl(p_order_number,oeh.order_number); */

        -- Added below query by Naga DFCT0010450
        CURSOR c_order_in_booked_status (p_order_number NUMBER)
        IS
              SELECT COUNT (*), oeh.order_number, oeh.header_id,
                     oeh.booked_flag, oeh.org_id, oeh.cust_po_number
                FROM apps.oe_order_headers_all oeh, apps.oe_order_lines_all oel, apps.oe_order_sources oes,
                     xxdo.xxdo_inv_int_026_stg2 x26_2, apps.fnd_lookup_values_vl flv, apps.hr_operating_units hou,
                     apps.oe_transaction_types_tl ottl
               WHERE     oeh.header_id = oel.header_id
                     AND oeh.order_source_id = oes.order_source_id
                     AND NVL (oeh.booked_flag, 'N') = 'Y'
                     AND NVL (oel.cancelled_flag, 'N') = 'N'
                     AND oel.flow_status_code = 'BOOKED'
                     AND UPPER (oes.NAME) = 'RETAIL'
                     AND oel.ordered_quantity <=
                         do_inv_utils_pub.item_onhand_quantity (
                             oel.ship_from_org_id,
                             oel.inventory_item_id)
                     --AND OEH.order_type_id =xxdo_om_int_026_stg_pkg.FETCH_ORDER_TYPE('SHIP', OEH.ORG_ID,X26_2.DC_VW_ID)
                     AND oeh.order_type_id = ottl.transaction_type_id
                     AND flv.lookup_type = 'XXDO_RMS_SO_RMA_ALLOCATION'
                     AND UPPER (flv.lookup_code) = UPPER (ottl.NAME)
                     AND hou.NAME = flv.tag
                     AND flv.description IN ('SHIP', 'LSHIP')
                     AND hou.organization_id = oeh.org_id
                     AND ottl.LANGUAGE = 'US'
                     AND flv.enabled_flag = 'Y'
                     AND flv.attribute_category = 'XXDO_RMS_SO_RMA_ALLOCATION'
                     AND x26_2.distro_number = SUBSTR (oel.orig_sys_line_ref,
                                                       1,
                                                         INSTR (oel.orig_sys_line_ref, '-', 1
                                                                , 1)
                                                       - 1)
                     AND TO_CHAR (x26_2.xml_id) =
                         SUBSTR (oel.orig_sys_line_ref,
                                   INSTR (oel.orig_sys_line_ref, '-', 1,
                                          3)
                                 + 1)             -- added by naga 14-FEB-2013
                     -- Changes for CCR0007197
                     AND TO_CHAR (x26_2.seq_no) =
                         (SUBSTR (oel.orig_sys_line_ref,
                                    INSTR (oel.orig_sys_line_ref, '-', 1,
                                           2)
                                  + 1,
                                    (  INSTR (oel.orig_sys_line_ref, '-', 1,
                                              3)
                                     - INSTR (oel.orig_sys_line_ref, '-', 1,
                                              2))
                                  - 1))
                     -- Changes for CCR0007197
                     AND    'RMS'
                         || '-'
                         || x26_2.dest_id
                         || '-'
                         || x26_2.dc_dest_id =
                         SUBSTR (oeh.orig_sys_document_ref,
                                 1,
                                   INSTR (oeh.orig_sys_document_ref, '-', 1,
                                          3)
                                 - 1)
                     AND x26_2.item_id = oel.inventory_item_id
                     AND NVL (x26_2.status, 0) = 1
                     AND x26_2.requested_qty > 0
                     AND oeh.order_number =
                         NVL (p_order_number, oeh.order_number)
            GROUP BY oeh.order_number, oeh.header_id, oeh.booked_flag,
                     oeh.org_id, oeh.cust_po_number;

        CURSOR cur_chk_order_schedule (pn_order_number NUMBER)
        IS
            SELECT /*+ INDEX(OES OE_ORDER_SOURCES_U1)
                      INDEX(X26_2 XXDO_INV_INT_26_U1)*/
                   DISTINCT oeh.order_number, oeh.header_id, oel.line_number order_line_num,
                            oel.line_id, x26_2.distro_number, x26_2.dest_id,
                            x26_2.dc_dest_id, x26_2.document_type, oel.ordered_quantity qty,
                            x26_2.xml_id, oel.schedule_status_code, oeh.booked_flag,
                            oel.inventory_item_id, DECODE (oel.schedule_status_code, 'SCHEDULED', 'DS', 'NI') status, x26_2.ROWID
              FROM oe_order_headers_all oeh, oe_order_lines_all oel, oe_order_sources oes,
                   xxdo_inv_int_026_stg2 x26_2, apps.fnd_lookup_values_vl flv, apps.hr_operating_units hou,
                   apps.oe_transaction_types_tl ottl
             WHERE     oeh.header_id = oel.header_id
                   AND oeh.order_source_id = oes.order_source_id
                   AND NVL (oel.cancelled_flag, 'N') = 'N'
                   AND UPPER (oes.NAME) = 'RETAIL'
                   --AND OEH.order_type_id = FETCH_ORDER_TYPE('SHIP', OEH.org_id,X26_2.DC_VW_ID)
                   AND oeh.order_type_id = ottl.transaction_type_id
                   AND flv.lookup_type = 'XXDO_RMS_SO_RMA_ALLOCATION'
                   AND UPPER (flv.lookup_code) = UPPER (ottl.NAME)
                   AND hou.NAME = flv.tag
                   AND flv.description IN ('SHIP', 'LSHIP')
                   AND hou.organization_id = oeh.org_id
                   AND ottl.LANGUAGE = 'US'
                   AND flv.enabled_flag = 'Y'
                   AND flv.attribute_category = 'XXDO_RMS_SO_RMA_ALLOCATION'
                   AND (flv.attribute11 = x26_2.dc_vw_id OR flv.attribute9 = x26_2.dc_vw_id OR flv.attribute2 = x26_2.dc_vw_id)
                   AND x26_2.requested_qty > 0
                   AND x26_2.distro_number = SUBSTR (oel.orig_sys_line_ref,
                                                     1,
                                                       INSTR (oel.orig_sys_line_ref, '-', 1
                                                              , 1)
                                                     - 1)
                   AND TO_CHAR (x26_2.xml_id) =
                       SUBSTR (oel.orig_sys_line_ref,
                                 INSTR (oel.orig_sys_line_ref, '-', 1,
                                        3)
                               + 1)               -- added by naga 14-FEB-2013
                   -- Changes for CCR0007197
                   AND TO_CHAR (x26_2.seq_no) =
                       (SUBSTR (oel.orig_sys_line_ref,
                                  INSTR (oel.orig_sys_line_ref, '-', 1,
                                         2)
                                + 1,
                                  (  INSTR (oel.orig_sys_line_ref, '-', 1,
                                            3)
                                   - INSTR (oel.orig_sys_line_ref, '-', 1,
                                            2))
                                - 1))
                   -- Changes for CCR0007197
                   AND    'RMS'
                       || '-'
                       || x26_2.dest_id
                       || '-'
                       || x26_2.dc_dest_id =
                       SUBSTR (oeh.orig_sys_document_ref,
                               1,
                                 INSTR (oeh.orig_sys_document_ref, '-', 1,
                                        3)
                               - 1)
                   AND x26_2.item_id = oel.inventory_item_id
                   AND NVL (x26_2.schedule_check, 'N') <> 'Y'
                   AND NVL (x26_2.status, 0) = 1
                   AND oeh.order_number = pn_order_number
            UNION ALL
            SELECT /*+ INDEX(X26_2 XXDO_INV_INT_26_U1)*/
                   oeh.order_number, oeh.header_id, oel1.line_number order_line_num,
                   oel1.line_id, x26_2.distro_number, x26_2.dest_id,
                   x26_2.dc_dest_id, x26_2.document_type, oel1.ordered_quantity qty,
                   x26_2.xml_id, oel1.schedule_status_code, oeh.booked_flag,
                   oel1.inventory_item_id, DECODE (oel1.schedule_status_code, 'SCHEDULED', 'DS', 'NI') status, x26_2.ROWID
              FROM oe_order_headers_all oeh, oe_order_lines_all oel, oe_order_lines_all oel1,
                   oe_order_sources oes, xxdo_inv_int_026_stg2 x26_2, apps.fnd_lookup_values_vl flv,
                   apps.hr_operating_units hou, apps.oe_transaction_types_tl ottl
             WHERE     oel1.header_id = oeh.header_id
                   AND oel1.order_source_id = oes.order_source_id
                   AND oeh.order_source_id = oes.order_source_id
                   AND oel.line_id = oel1.split_from_line_id
                   AND oel1.split_from_line_id IS NOT NULL
                   AND NVL (oel1.cancelled_flag, 'N') = 'N'
                   AND NVL (oel.cancelled_flag, 'N') = 'N'
                   AND UPPER (oes.NAME) = 'RETAIL'
                   AND NVL (oel1.open_flag, 'N') = 'Y'
                   AND NVL (oel.open_flag, 'N') = 'Y'
                   -- AND OEH.ORDER_TYPE_ID = xxdo_om_int_026_stg_pkg.FETCH_ORDER_TYPE('SHIP', OEH.ORG_ID,X26_2.DC_VW_ID)
                   AND oeh.order_type_id = ottl.transaction_type_id
                   AND flv.lookup_type = 'XXDO_RMS_SO_RMA_ALLOCATION'
                   AND UPPER (flv.lookup_code) = UPPER (ottl.NAME)
                   AND hou.NAME = flv.tag
                   AND flv.description IN ('SHIP', 'LSHIP')
                   AND hou.organization_id = oeh.org_id
                   AND ottl.LANGUAGE = 'US'
                   AND flv.enabled_flag = 'Y'
                   AND flv.attribute_category = 'XXDO_RMS_SO_RMA_ALLOCATION'
                   AND (flv.attribute11 = x26_2.dc_vw_id OR flv.attribute9 = x26_2.dc_vw_id OR flv.attribute2 = x26_2.dc_vw_id)
                   AND x26_2.distro_number = SUBSTR (oel.orig_sys_line_ref,
                                                     1,
                                                       INSTR (oel.orig_sys_line_ref, '-', 1
                                                              , 1)
                                                     - 1)
                   AND TO_CHAR (x26_2.xml_id) =
                       SUBSTR (oel.orig_sys_line_ref,
                                 INSTR (oel.orig_sys_line_ref, '-', 1,
                                        3)
                               + 1)               -- added by naga 14-FEB-2013
                   -- Changes for CCR0007197
                   AND TO_CHAR (x26_2.seq_no) =
                       (SUBSTR (oel.orig_sys_line_ref,
                                  INSTR (oel.orig_sys_line_ref, '-', 1,
                                         2)
                                + 1,
                                  (  INSTR (oel.orig_sys_line_ref, '-', 1,
                                            3)
                                   - INSTR (oel.orig_sys_line_ref, '-', 1,
                                            2))
                                - 1))
                   -- Changes for CCR0007197
                   AND    'RMS'
                       || '-'
                       || x26_2.dest_id
                       || '-'
                       || x26_2.dc_dest_id =
                       SUBSTR (oeh.orig_sys_document_ref,
                               1,
                                 INSTR (oeh.orig_sys_document_ref, '-', 1,
                                        3)
                               - 1)
                   AND x26_2.item_id = oel1.inventory_item_id
                   AND x26_2.item_id = oel.inventory_item_id
                   AND NVL (x26_2.schedule_check, 'N') <> 'Y'
                   AND NVL (x26_2.status, 0) = 1
                   AND x26_2.requested_qty > 0
                   AND oeh.order_number = pn_order_number
            ORDER BY 1, 3;
    BEGIN
        FOR booked_lines_rec IN c_order_in_booked_status (p_order_number)
        LOOP
            ln_request_id   :=
                fnd_request.submit_request (application => 'ONT', program => 'SCHORD', description => 'Schedule Orders', start_time => SYSDATE, sub_request => NULL, argument1 => booked_lines_rec.org_id, argument2 => booked_lines_rec.order_number, argument3 => booked_lines_rec.order_number, argument4 => NULL, argument5 => NULL, argument6 => NULL, argument7 => NULL, argument8 => NULL --order type
                                                                                                                                                                                                                                                                                                                                                                                                , argument9 => NULL --customer
                                                                                                                                                                                                                                                                                                                                                                                                                   , argument10 => NULL, argument11 => NULL, argument12 => NULL --warehouse
                                                                                                                                                                                                                                                                                                                                                                                                                                                                               , argument13 => NULL --item
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   , argument14 => NULL, argument15 => NULL, argument16 => NULL, argument17 => NULL, argument18 => NULL, argument19 => NULL, argument20 => NULL, argument21 => NULL, argument22 => NULL, argument23 => NULL, argument24 => NULL, argument25 => NULL, argument26 => NULL, argument27 => NULL, argument28 => NULL, argument29 => NULL, argument30 => NULL, argument31 => NULL
                                            , argument32 => NULL);
            COMMIT;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Submitted Schedule Orders program Request Id:'
                || ln_request_id);

            IF (ln_request_id != 0)
            THEN
                lv_success   :=
                    fnd_concurrent.get_request_status (
                        request_id       => ln_request_id,
                        --rec_oint_req_id.oint_request_id,    -- Request ID
                        appl_shortname   => NULL,
                        program          => NULL,
                        phase            => lv_phase,
                        -- Phase displayed on screen
                        status           => lv_status,
                        -- Status displayed on screen
                        dev_phase        => lv_dev_phase,
                        -- Phase available for developer
                        dev_status       => lv_dev_status,
                        -- Status available for developer
                        MESSAGE          => lv_message    -- Execution Message
                                                      );

                LOOP
                    lv_success   :=
                        fnd_concurrent.wait_for_request (
                            request_id   => ln_request_id,
                            -- Request ID
                            INTERVAL     => 10,
                            phase        => lv_phase,
                            -- Phase displyed on screen
                            status       => lv_status,
                            -- Status displayed on screen
                            dev_phase    => lv_dev_phase,
                            -- Phase available for developer
                            dev_status   => lv_dev_status,
                            -- Status available for developer
                            MESSAGE      => lv_message    -- Execution Message
                                                      );
                    EXIT WHEN lv_dev_phase = 'COMPLETE';
                END LOOP;
            END IF;

            FOR rec_order_sch
                IN cur_chk_order_schedule (booked_lines_rec.order_number)
            LOOP
                fnd_file.put_line (
                    fnd_file.LOG,
                    'TEST 100-   ' || rec_order_sch.dc_dest_id);

                IF rec_order_sch.status = 'DS'
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'DS TEST 100-   ' || rec_order_sch.dc_dest_id);
                    xxdo_int_009_prc (lv_errbuf,
                                      lv_retcode,
                                      rec_order_sch.dc_dest_id,
                                      rec_order_sch.distro_number,
                                      rec_order_sch.document_type,
                                      rec_order_sch.distro_number,
                                      rec_order_sch.dest_id,
                                      rec_order_sch.inventory_item_id,
                                      rec_order_sch.order_line_num,
                                      rec_order_sch.qty,
                                      rec_order_sch.status);
                    fnd_file.put_line (
                        fnd_file.output,
                           RPAD (rec_order_sch.order_number, 10)
                        || RPAD (rec_order_sch.order_line_num, 9)
                        || RPAD (rec_order_sch.distro_number, 15)
                        || RPAD (rec_order_sch.qty, 7)
                        || RPAD (rec_order_sch.booked_flag, 10)
                        || RPAD (rec_order_sch.schedule_status_code, 11)
                        || RPAD (rec_order_sch.status, 10));

                    BEGIN
                        UPDATE xxdo_inv_int_026_stg2 x26_2
                           SET schedule_check   = 'Y'
                         WHERE x26_2.ROWID = rec_order_sch.ROWID;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error while Updating Schedule Check DS '
                                || rec_order_sch.header_id
                                || ' - '
                                || rec_order_sch.line_id
                                || ' --- '
                                || SQLERRM);
                    END;
                ELSIF rec_order_sch.status = 'NI'
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'NI TEST 100-   ' || rec_order_sch.dc_dest_id);

                    BEGIN
                        so_cancel_prc (lv_errbuf,
                                       lv_retcode,
                                       rec_order_sch.header_id,
                                       rec_order_sch.line_id,
                                       lv_cancel_status);
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Cancel Status :' || lv_cancel_status);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error in Cancelling the Sales Order '
                                || rec_order_sch.header_id
                                || ' - '
                                || rec_order_sch.line_id
                                || ' --- '
                                || SQLERRM);
                    END;

                    IF NVL (lv_cancel_status, 'E') = 'S'
                    THEN
                        fnd_file.put_line (
                            fnd_file.output,
                               RPAD (rec_order_sch.order_number, 10)
                            || RPAD (rec_order_sch.order_line_num, 9)
                            || RPAD (rec_order_sch.distro_number, 15)
                            || RPAD (rec_order_sch.qty, 7)
                            || RPAD (rec_order_sch.booked_flag, 10)
                            || RPAD (rec_order_sch.schedule_status_code, 11)
                            || RPAD ('Cancelled', 10));
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'NI TEST 100-   ' || rec_order_sch.dc_dest_id);
                        xxdo_int_009_prc (lv_errbuf,
                                          lv_retcode,
                                          rec_order_sch.dc_dest_id,
                                          rec_order_sch.distro_number,
                                          rec_order_sch.document_type,
                                          rec_order_sch.distro_number,
                                          rec_order_sch.dest_id,
                                          rec_order_sch.inventory_item_id,
                                          rec_order_sch.order_line_num,
                                          rec_order_sch.qty,
                                          rec_order_sch.status);
                        fnd_file.put_line (
                            fnd_file.output,
                               RPAD (rec_order_sch.order_number, 10)
                            || RPAD (rec_order_sch.order_line_num, 9)
                            || RPAD (rec_order_sch.distro_number, 15)
                            || RPAD (rec_order_sch.qty, 7)
                            || RPAD (rec_order_sch.booked_flag, 10)
                            || RPAD (rec_order_sch.schedule_status_code, 11)
                            || RPAD (rec_order_sch.status, 10));

                        BEGIN
                            UPDATE xxdo_inv_int_026_stg2 x26_2
                               SET schedule_check   = 'Y'
                             WHERE x26_2.ROWID = rec_order_sch.ROWID;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Error while Updating Schedule Check NI '
                                    || rec_order_sch.header_id
                                    || ' - '
                                    || rec_order_sch.line_id
                                    || ' --- '
                                    || SQLERRM);
                        END;
                    END IF;
                END IF;
            END LOOP;
        END LOOP;

        fnd_file.put_line (
            fnd_file.output,
            '*******************************************************************');
    /*  do_oe_utils.schedule_line(p_line_id            => booked_lines_rec.line_id,
                                p_do_commit          => 1,
                                x_schedule_ship_date => l_scheduled_ship_date);
      fnd_file.put_line(fnd_file.LOG,'New Scheduled Ship date for the Order line id'||booked_lines_rec.line_id||' is '||l_scheduled_ship_date);
      */
    EXCEPTION
        WHEN OTHERS
        THEN
            /*   fnd_file.put_line
                              (fnd_file.LOG,
                               'Error while executing the procedure schedule_order'
                              );
               fnd_file.put_line (fnd_file.LOG, 'SQL Error Code :' || SQLCODE);
               fnd_file.put_line
                           (fnd_file.LOG,
                               'Error while executing the procedure schedule_order:'
                            || SQLERRM
                           ); */
            -- Commented for 2.0.
            fnd_file.put_line (
                fnd_file.LOG,
                'Error while executing the procedure SCHEDULE_ORDER.');
            fnd_file.put_line (
                fnd_file.LOG,
                   'SQL Error Code : '
                || SQLCODE
                || '. SQL Error Message : '
                || SQLERRM);
    END schedule_order;

    PROCEDURE insert_oe_iface_tables_th (retcode OUT VARCHAR2, errbuf OUT VARCHAR2, pv_reprocess IN VARCHAR2, pd_rp_start_date IN DATE, pd_rp_end_date IN DATE, pv_dblink IN VARCHAR2, p_region IN VARCHAR2, p_threshold IN NUMBER, p_debug IN VARCHAR2
                                         , p_sql_display IN VARCHAR2)
    IS
        CURSOR cur_order_lines (cn_dest_id NUMBER, cn_dc_dest_id NUMBER, cn_status NUMBER, cn_brand VARCHAR2, cn_pgroup VARCHAR2, cn_gender VARCHAR2, cn_class VARCHAR2, cn_context VARCHAR2, cn_vw_id VARCHAR2
                                , p_threshold NUMBER)
        IS
            SELECT x26_2.ROWID, x26_2.*
              FROM xxdo_inv_int_026_stg2 x26_2, mtl_item_categories mic, mtl_categories_b mc,
                   mtl_category_sets_tl mcs
             WHERE     mic.category_id = mc.category_id
                   AND mcs.category_set_id = mic.category_set_id
                   AND mic.inventory_item_id = x26_2.item_id
                   AND mic.organization_id = x26_2.dc_dest_id
                   AND UPPER (mcs.category_set_name) = 'INVENTORY'
                   -- AND MC.STRUCTURE_ID = 101
                   AND mc.structure_id =
                       (SELECT structure_id
                          FROM mtl_category_sets
                         WHERE UPPER (category_set_name) = 'INVENTORY')
                   --1.5
                   AND mcs.LANGUAGE = 'US'
                   AND x26_2.dest_id = NVL (cn_dest_id, x26_2.dest_id)
                   AND x26_2.dc_dest_id =
                       NVL (cn_dc_dest_id, x26_2.dc_dest_id)
                   AND x26_2.status = NVL (cn_status, x26_2.status)
                   AND mc.segment1 = NVL (cn_brand, mc.segment1)
                   -- AND mc.segment2 = NVL (cn_pgroup, mc.segment2)
                   -- AND mc.segment3 = NVL (cn_gender, mc.segment3)
                   AND mc.segment2 = NVL (cn_gender, mc.segment2)  --W.r.t 1.5
                   AND mc.segment3 = NVL (cn_pgroup, mc.segment3)  --W.r.t 1.5
                   AND mc.segment4 = NVL (cn_class, mc.segment4)
                   --AND DECODE(cn_context, NULL, '-',  X26_2.CONTEXT_CODE) = NVL(cn_context, '-')  ---- commented for INC0124362
                   AND DECODE (NVL (cn_context, '9'),
                               '9', NVL (x26_2.context_code, '9'),
                               x26_2.context_code) =
                       NVL (cn_context, '9')     --- 100 added for  INC0124362
                   AND dc_vw_id = cn_vw_id
                   -- Added by VIK on 03-SEP-2013 on DFCT0010624
                   AND x26_2.requested_qty > 0;

        /* sample line query below  cursor not used */
        CURSOR cur_order_lines_th (cn_dest_id NUMBER, cn_dc_dest_id NUMBER, cn_status NUMBER, cn_brand VARCHAR2, cn_pgroup VARCHAR2, cn_gender VARCHAR2, cn_class VARCHAR2, cn_context VARCHAR2, cn_vw_id VARCHAR2
                                   , p_threshold NUMBER)
        IS
            SELECT distro_number, dc_dest_id, dest_id,
                   item_id, xml_id, document_type,
                   requested_qty, retail_price, cancel_date,
                   segment1, segment2, segment3,
                   context_code, context_value, status,
                   DENSE_RANK () OVER (ORDER BY batch) batch
              FROM (SELECT distro_number,
                           dc_dest_id,
                           dest_id,
                           item_id,
                           xml_id,
                           document_type,
                           requested_qty,
                           retail_price,
                           cancel_date,
                           segment1,
                           segment2,
                           segment3,
                           context_code,
                           context_value,
                           status,
                             (    (  (SUM (requested_qty)
                                          OVER (PARTITION BY segment1, segment2, segment3,
                                                             context_code, context_value, status
                                                --,
                                                -- cancel_date
                                                ORDER BY
                                                    segment1, segment2, segment3,
                                                    context_code, context_value, status --,
                                                --  cancel_date
                                                ROWS UNBOUNDED PRECEDING))
                                   - (MOD (
                                          SUM (requested_qty)
                                              OVER (PARTITION BY segment1, segment2, segment3,
                                                                 context_code, context_value, status
                                                    --,
                                                    -- cancel_date
                                                    ORDER BY
                                                        segment1, segment2, segment3,
                                                        context_code, context_value, status --,
                                                    --  cancel_date
                                                    ROWS UNBOUNDED PRECEDING),
                                          p_threshold)))
                                / p_threshold
                              + 1)
                           - SIGN (
                                 TRUNC (
                                       (requested_qty - p_threshold)
                                     / p_threshold)) batch
                      FROM (  SELECT x26_2.ROWID, x26_2.distro_number, x26_2.document_type,
                                     x26_2.xml_id, x26_2.item_id, x26_2.requested_qty,
                                     x26_2.retail_price, x26_2.dc_dest_id, x26_2.dest_id,
                                     x26_2.pick_not_before_date cancel_date, mc.segment1, mc.segment2,
                                     mc.segment3, x26_2.context_code, x26_2.context_value,
                                     x26_2.status
                                FROM apps.xxdo_inv_int_026_stg2 x26_2, apps.mtl_item_categories mic, apps.mtl_categories_b mc,
                                     apps.mtl_category_sets_tl mcs
                               WHERE     mic.category_id = mc.category_id
                                     AND mcs.category_set_id =
                                         mic.category_set_id
                                     AND mic.inventory_item_id = x26_2.item_id
                                     AND mic.organization_id = x26_2.dc_dest_id
                                     AND UPPER (mcs.category_set_name) =
                                         'INVENTORY'
                                     --AND mc.structure_id = 101
                                     AND mc.structure_id =
                                         (SELECT structure_id
                                            FROM mtl_category_sets
                                           WHERE UPPER (category_set_name) =
                                                 'INVENTORY')
                                     --1.5
                                     AND mcs.LANGUAGE = 'US'
                                     AND x26_2.dest_id =
                                         NVL (cn_dest_id, x26_2.dest_id)
                                     AND x26_2.dc_dest_id =
                                         NVL (cn_dc_dest_id, x26_2.dc_dest_id)
                                     AND x26_2.status =
                                         NVL (cn_status, x26_2.status)
                                     AND mc.segment1 =
                                         NVL (cn_brand, mc.segment1)
                                     -- AND mc.segment2 = NVL (cn_pgroup, mc.segment2) --W.r.t 1.5
                                     --  AND mc.segment3 = NVL (cn_gender, mc.segment3) --W.r.t 1.5
                                     AND mc.segment2 =
                                         NVL (cn_gender, mc.segment2)
                                     --W.r.t 1.5
                                     AND mc.segment3 =
                                         NVL (cn_pgroup, mc.segment3)
                                     --W.r.t 1.5
                                     AND mc.segment4 =
                                         NVL (cn_class, mc.segment4)
                                     AND DECODE (
                                             NVL (cn_context, '9'),
                                             '9', NVL (x26_2.context_code, '9'),
                                             x26_2.context_code) =
                                         NVL (cn_context, '9')
                                     AND x26_2.requested_qty > 0
                            ORDER BY dc_dest_id, dest_id, requested_qty,
                                     item_id));

        CURSOR cur_so_orderby (x_region VARCHAR2)
        IS
              SELECT flv.lookup_code lookup_code_usr, flv1.lookup_code, DECODE (flv.enabled_flag, 'Y', flv1.description, 'NULL') description,
                     DECODE (flv.enabled_flag, 'Y', flv1.tag, 20) tag, DECODE (flv.enabled_flag, 'Y', flv.description, NULL) datatype
                FROM apps.fnd_lookup_values flv, apps.fnd_lookup_values flv1
               WHERE     1 = 1
                     AND flv.lookup_code = flv1.lookup_code
                     AND flv.lookup_type = 'RMS_SO_GROUPING_SO_' || x_region
                     AND flv1.lookup_type = 'RMS_SQL_GRP_BY_CLAUSE'
                     AND flv.LANGUAGE = 'US'
                     --AND flv.enabled_flag = 'Y'
                     AND flv1.LANGUAGE = 'US'
                     AND flv1.enabled_flag = 'Y'
                     AND flv.tag = x_region
            ORDER BY TO_NUMBER (flv1.tag) ASC;

        CURSOR cur_class (y_region VARCHAR2)
        IS
              SELECT lookup_code, DECODE (lookup_code, 'OTHERS', 999, 1) ordby, lookup_type
                FROM apps.fnd_lookup_values flv
               WHERE     flv.lookup_type =
                         'XXDO_RMS_SO_GROUPING_CLASS_' || y_region
                     AND flv.enabled_flag = 'Y'
                     AND LANGUAGE = 'US'
                     AND EXISTS
                             (SELECT 1
                                FROM apps.xxdo_inv_int_026_stg2 x26_2
                               WHERE     1 = 1
                                     AND x26_2.status = 0
                                     AND x26_2.requested_qty > 0
                                     AND UPPER (x26_2.CLASS) =
                                         UPPER (flv.lookup_code)
                                     AND x26_2.dest_id IN
                                             (SELECT rms_store_id
                                                FROM xxd_retail_stores_v drs
                                               --do_retail.stores@datamart.deckers.com drs  --W.R.T VErsion 1.5
                                               WHERE region = y_region)
                                     AND ROWNUM = 1
                              UNION
                              SELECT 1
                                FROM DUAL
                               WHERE 'OTHERS' = flv.lookup_code)
            ORDER BY 2;

        CURSOR cur_gender (z_region VARCHAR2)
        IS
              SELECT COUNT (*) cnt, DECODE (description, 'OTHERS', 999, 1) ordby, description gender,
                     lookup_type
                FROM apps.fnd_lookup_values flv
               WHERE     flv.lookup_type =
                         'XXDO_RMS_SO_GROUPING_GENDER_' || z_region
                     AND flv.enabled_flag = 'Y'
                     AND LANGUAGE = 'US'
                     AND EXISTS
                             (SELECT 1
                                FROM apps.xxdo_inv_int_026_stg2 x26_2
                               WHERE     1 = 1
                                     AND x26_2.status = 0
                                     AND x26_2.requested_qty > 0
                                     AND UPPER (x26_2.gender) =
                                         UPPER (flv.lookup_code)
                                     -- Added Upper 1.5
                                     AND x26_2.dest_id IN
                                             (SELECT rms_store_id
                                                FROM xxd_retail_stores_v drs
                                               --do_retail.stores@datamart.deckers.com drs  --W.R.T VErsion 1.5
                                               WHERE region = z_region)
                                     AND ROWNUM = 1
                              UNION
                              SELECT 1
                                FROM DUAL
                               WHERE 'OTHERS' = flv.lookup_code)
            GROUP BY DECODE (description, 'OTHERS', 999, 1), description, lookup_type
            ORDER BY 2;

        TYPE lcur_cursor IS REF CURSOR;

        cur_xxdo26_stg2              lcur_cursor;

        TYPE lcur_cursor_line IS REF CURSOR;

        cur_xxdo26_stg2_line         lcur_cursor_line;
        lr_rec_stg2_dest_id          NUMBER;
        lr_rec_stg2_dc_dest_id       NUMBER;
        lr_rec_stg2_dc_vm_id         NUMBER;
        lr_rec_stg2_brand            VARCHAR2 (20);
        lr_rec_stg2_pgroup           VARCHAR2 (240);
        lr_rec_stg2_gender           VARCHAR2 (240);
        lr_rec_stg2_context_code     VARCHAR2 (240);
        lr_rec_stg2_context_value    VARCHAR2 (240);
        lr_rec_stg2_class            VARCHAR2 (240);
        lr_rec_stg2_cancel_date      DATE;
        lr_rec_stg2_status           NUMBER;
        lv_cursor_stmt               VARCHAR2 (20000);
        lv_cursor_stmt_pcondition    VARCHAR2 (20000); /* Parameter Condition */
        lv_cursor_stmt_groupby       VARCHAR2 (20000);    /* Group by Clause*/
        lv_cursor_line               CLOB := NULL;
        lv_udate_stmt                VARCHAR2 (20000);
        lv_update_stmt1              VARCHAR2 (20000);
        lv_update_stmt2              VARCHAR2 (20000);
        ln_customer_id               NUMBER;
        ln_customer_number           NUMBER;
        ln_org_id                    NUMBER;
        lv_inv_org_code              VARCHAR2 (20);
        ln_order_source_id           NUMBER;
        ln_order_type_id             NUMBER;
        lv_error_message             VARCHAR2 (32767);
        lv_status                    VARCHAR2 (1);
        ln_org_ref_sequence          NUMBER;
        lv_header_insertion_status   VARCHAR2 (1) := 'S';
        lv_line_insertion_status     VARCHAR2 (1) := 'S';
        ln_line_number               NUMBER := 0;
        ln_line_number_canc          NUMBER := 1;
        lv_cursor_stmt0              VARCHAR2 (32767);
        lv_cursor_stmt00             VARCHAR2 (32767);
        lv_cursor_stmt0_line         VARCHAR2 (32767);
        lv_cursor_stmt00_line        VARCHAR2 (32767);
        lv_cursor_cls_stmt           VARCHAR2 (32767);
        lv_cursor_cls_stmt_gen       VARCHAR2 (32767);
        lv_cursor_cls_stmt_gen_ln    VARCHAR2 (32767);
        lv_type_create               VARCHAR2 (2000) := NULL;
        lv_type_create_new           VARCHAR2 (2000) := NULL;
        lv_region                    VARCHAR2 (10) := p_region;
        ln_exists                    NUMBER;
        lv_errbuf                    VARCHAR2 (100);
        lv_retcode                   VARCHAR2 (100);
        ln_line_count                NUMBER;
        ln_organization_id           NUMBER;

        TYPE t_ln_distro_number IS TABLE OF INTEGER
            INDEX BY BINARY_INTEGER;

        TYPE t_ln_rn IS TABLE OF VARCHAR2 (200)
            INDEX BY BINARY_INTEGER;

        TYPE t_ln_dc_dest_id IS TABLE OF INTEGER
            INDEX BY BINARY_INTEGER;

        TYPE t_ln_dest_id IS TABLE OF INTEGER
            INDEX BY BINARY_INTEGER;

        TYPE t_ln_item_id IS TABLE OF INTEGER
            INDEX BY BINARY_INTEGER;

        TYPE t_ln_xml_id IS TABLE OF INTEGER
            INDEX BY BINARY_INTEGER;

        TYPE t_ln_seq_no IS TABLE OF INTEGER
            INDEX BY BINARY_INTEGER;

        TYPE t_ln_requested_qty IS TABLE OF INTEGER
            INDEX BY BINARY_INTEGER;

        TYPE t_ln_retail_price IS TABLE OF INTEGER
            INDEX BY BINARY_INTEGER;

        TYPE t_ln_document_type IS TABLE OF VARCHAR2 (200)
            INDEX BY BINARY_INTEGER;

        TYPE t_ln_cancel IS TABLE OF DATE
            INDEX BY BINARY_INTEGER;

        TYPE t_ln_segment1 IS TABLE OF VARCHAR2 (200)
            INDEX BY BINARY_INTEGER;

        TYPE t_ln_segment2 IS TABLE OF VARCHAR2 (200)
            INDEX BY BINARY_INTEGER;

        TYPE t_ln_segment3 IS TABLE OF VARCHAR2 (200)
            INDEX BY BINARY_INTEGER;

        TYPE t_ln_segment4 IS TABLE OF VARCHAR2 (200)
            INDEX BY BINARY_INTEGER;

        TYPE t_ln_context_code IS TABLE OF VARCHAR2 (200)
            INDEX BY BINARY_INTEGER;

        TYPE t_ln_context_value IS TABLE OF VARCHAR2 (200)
            INDEX BY BINARY_INTEGER;

        TYPE t_ln_status IS TABLE OF VARCHAR2 (200)
            INDEX BY BINARY_INTEGER;

        TYPE t_ln_batch IS TABLE OF INTEGER
            INDEX BY BINARY_INTEGER;

        TYPE ln_rec IS RECORD
        (
            ln_rn               t_ln_rn,
            ln_distro_number    t_ln_distro_number,
            ln_dc_dest_id       t_ln_dc_dest_id,
            ln_dest_id          t_ln_dest_id,
            ln_item_id          t_ln_item_id,
            ln_xml_id           t_ln_xml_id,
            ln_seq_no           t_ln_seq_no,
            ln_requested_qty    t_ln_requested_qty,
            ln_retail_price     t_ln_retail_price,
            ln_document_type    t_ln_document_type,
            ln_cancel           t_ln_cancel,
            ln_segment1         t_ln_segment1,
            ln_segment2         t_ln_segment2,
            ln_segment3         t_ln_segment3,
            ln_segment4         t_ln_segment4,
            ln_context_code     t_ln_context_code,
            ln_context_value    t_ln_context_value,
            ln_status           t_ln_status,
            ln_batch            t_ln_batch
        );

        ln_blk_col                   ln_rec;
        ln_batch                     NUMBER := 0;
        v_curr_val                   NUMBER := 0;
    -- l_hdr_type     xxdo_po_import_hdr_type ;
    BEGIN
        lv_cursor_stmt0         := NULL;
        lv_cursor_stmt00        := NULL;
        lv_cursor_stmt0_line    := NULL;
        lv_cursor_stmt00_line   := NULL;

        FOR rec_order_gender IN cur_gender (p_region)
        LOOP
            FOR rec_order_classes IN cur_class (p_region)
            LOOP
                IF p_debug = 'Y'
                THEN
                    fnd_file.put_line (fnd_file.LOG, 'Class Loop Begin ');
                END IF;

                lv_cursor_stmt0         := NULL;
                lv_cursor_stmt00        := NULL;
                lv_cursor_stmt0_line    := NULL;
                lv_cursor_stmt00_line   := NULL;
                lv_type_create          := NULL;

                FOR rec_order_lines IN cur_so_orderby (p_region)
                LOOP
                    lv_cursor_stmt0   :=
                        lv_cursor_stmt0 || rec_order_lines.description || ',';
                    lv_cursor_stmt00   :=
                           lv_cursor_stmt00
                        || SUBSTR (
                               rec_order_lines.description,
                                 INSTR (rec_order_lines.description, '.', 1)
                               + 1,
                               LENGTH (rec_order_lines.description))
                        || ',';
                END LOOP;

                IF p_sql_display = 'Y'
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'lv_cursor_stmt0 clause before ' || lv_cursor_stmt0);
                    fnd_file.put_line (fnd_file.LOG,
                                       '==============================');
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'lv_cursor_stmt00 clause before ' || lv_cursor_stmt00);
                    fnd_file.put_line (fnd_file.LOG,
                                       '==============================');
                END IF;

                IF p_debug = 'Y'
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'rec_order_classes.lookup_code ' || rec_order_classes.lookup_code);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'rec_order_gender.gender ' || rec_order_gender.gender);
                    fnd_file.put_line (fnd_file.LOG,
                                       '==============================');
                END IF;

                IF     rec_order_classes.lookup_code = 'OTHERS'
                   AND rec_order_gender.gender = 'OTHERS'
                THEN
                    lv_cursor_cls_stmt   :=                 -- 1.5 Added UPPER
                           ' AND UPPER(MC.SEGMENT4) IN (select LOOKUP_CODE from apps.fnd_lookup_values flv
                                where  flv.LOOKUP_TYPE = '''
                        || rec_order_classes.lookup_type
                        || '''
                                and language =''US''
                                and enabled_flag =''N''
                                and LOOKUP_CODE not in (''OTHERS'')
                                ) ';
                    lv_cursor_cls_stmt_gen   :=
                           -- Changed Segment2 instead of Segment3  Added Upper
                           ' AND UPPER(MC.SEGMENT2) IN
                        (SELECT lookup_code
                           FROM apps.fnd_lookup_values flv
                          WHERE     flv.lookup_type ='''
                        || rec_order_gender.lookup_type
                        || '''                                       
                                AND flv.enabled_flag = ''Y''
                                AND LANGUAGE = ''US''
                                AND LOOKUP_CODE NOT IN (''OTHERS'')) ';
                    lv_cursor_stmt0   :=
                        REPLACE (
                            REPLACE (lv_cursor_stmt0, 'MC.SEGMENT4', 'NULL'),
                            'MC.SEGMENT3',
                            'NULL');
                    --lv_cursor_stmt0_line:=  replace(lv_cursor_stmt0,'X26_2.DC_DEST_ID,X26_2.DC_VW_ID,X26_2.DEST_ID,','');
                    lv_cursor_stmt00   :=
                        REPLACE (REPLACE (lv_cursor_stmt00, 'SEGMENT4,', ''),
                                 'SEGMENT3,',
                                 '');
                    lv_cursor_stmt00_line   :=
                        REPLACE (lv_cursor_stmt00,
                                 'DC_DEST_ID,DC_VW_ID,DEST_ID,',
                                 '');

                    IF p_sql_display = 'Y'
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'lv_cursor_stmt0 clause when others '
                            || lv_cursor_stmt0);
                    END IF;
                ELSIF     rec_order_classes.lookup_code = 'OTHERS'
                      AND rec_order_gender.gender <> 'OTHERS'
                THEN
                    IF p_debug = 'Y'
                    THEN
                        fnd_file.put_line (fnd_file.LOG,
                                           '==============================');
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'rec_order_classes.lookup_code '
                            || rec_order_classes.lookup_code);
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'rec_order_gender.gender ' || rec_order_gender.gender);
                        fnd_file.put_line (fnd_file.LOG,
                                           '==============================');
                    END IF;

                    lv_cursor_stmt0   :=
                        REPLACE (
                            REPLACE (lv_cursor_stmt0, 'MC.SEGMENT4', 'NULL'),
                            'MC.SEGMENT3',
                            'NULL');
                    lv_cursor_cls_stmt_gen   :=
                           -- Changed Segment2 instead of segment3 Added UPPER
                           ' AND UPPER(MC.SEGMENT2) IN
                        (SELECT lookup_code
                           FROM apps.fnd_lookup_values flv
                          WHERE     flv.lookup_type ='''
                        || rec_order_gender.lookup_type
                        || '''                                       
                                AND flv.enabled_flag = ''Y''
                                AND LANGUAGE = ''US''
                                AND description  IN ('''
                        || rec_order_gender.gender
                        || ''' )) ';
                    lv_cursor_cls_stmt   :=                 -- Added Upper 1.5
                           ' AND UPPER(MC.SEGMENT4) IN (select LOOKUP_CODE from apps.fnd_lookup_values flv
                                where  flv.LOOKUP_TYPE = '''
                        || rec_order_classes.lookup_type
                        || '''
                                and language =''US''
                                and enabled_flag =''N''
                                and LOOKUP_CODE not in (''OTHERS'')
                                ) ';
                    lv_cursor_stmt00   :=
                        REPLACE (REPLACE (lv_cursor_stmt00, 'SEGMENT4,', ''),
                                 'SEGMENT3,',
                                 '');
                    lv_cursor_stmt00_line   :=
                        REPLACE (lv_cursor_stmt00,
                                 'DC_DEST_ID,DC_VW_ID,DEST_ID,',
                                 '');
                ELSE
                    IF p_debug = 'Y'
                    THEN
                        fnd_file.put_line (fnd_file.LOG,
                                           '==============================');
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'rec_order_classes.lookup_code '
                            || rec_order_classes.lookup_code);
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'rec_order_gender.gender ' || rec_order_gender.gender);
                        fnd_file.put_line (fnd_file.LOG,
                                           '==============================');
                    END IF;

                    lv_cursor_stmt0   :=
                        REPLACE (lv_cursor_stmt0, 'MC.SEGMENT3', 'NULL');
                    lv_cursor_stmt00   :=
                        REPLACE (lv_cursor_stmt00, 'SEGMENT3,', '');
                    lv_cursor_stmt00_line   :=
                        REPLACE (lv_cursor_stmt00,
                                 'DC_DEST_ID,DC_VW_ID,DEST_ID,',
                                 '');
                    lv_cursor_cls_stmt   :=
                           -- 1.5 Added Upper for Segment4 (NVL cond also)
                           ' AND UPPER(MC.SEGMENT4) = NVL('''
                        || rec_order_classes.lookup_code
                        || ''',UPPER(MC.SEGMENT4)) ';
                    lv_cursor_cls_stmt_gen   :=
                           -- 1.5 Added UPPER and Changed Segment2 instead of Segment3
                           ' AND UPPER(MC.SEGMENT2) IN  
                        (SELECT lookup_code
                           FROM apps.fnd_lookup_values flv
                          WHERE     flv.lookup_type ='''
                        || rec_order_gender.lookup_type
                        || '''                                       
                                AND flv.enabled_flag = ''Y''
                                AND LANGUAGE = ''US''
                                AND description  IN ('''
                        || rec_order_gender.gender
                        || ''' )) ';
                END IF;

                IF p_sql_display = 'Y'
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'lv_cursor_stmt0 clause after' || lv_cursor_stmt0);
                END IF;

                lv_cursor_stmt          :=
                       'SELECT '
                    || lv_cursor_stmt0
                    || '  X26_2.STATUS,
                                             MAX(PICK_NOT_AFTER_DATE) Cancel_Date
                                  FROM XXDO_INV_INT_026_STG2  X26_2
                                           ,MTL_ITEM_CATEGORIES MIC
                                           ,MTL_CATEGORIES_B MC
                                           ,MTL_CATEGORY_SETS_TL MCS
                                 WHERE MIC.CATEGORY_ID = MC.CATEGORY_ID
                                    AND MCS.CATEGORY_SET_ID = MIC.CATEGORY_SET_ID
                                    AND MIC.INVENTORY_ITEM_ID = X26_2.item_id
                                    AND MIC.ORGANIZATION_ID = X26_2.dc_dest_id
                                    AND UPPER(MCS.CATEGORY_SET_NAME) = ''INVENTORY''
                                    AND MC.STRUCTURE_ID = 
                                                (SELECT structure_id
                                                            FROM mtl_category_sets
                                                    WHERE UPPER (category_set_name) = ''INVENTORY'')
                                    AND MCS.LANGUAGE = ''US''
                                ';
                lv_cursor_stmt_groupby   :=
                    'GROUP BY ' || lv_cursor_stmt0 || '  X26_2.STATUS';
                lv_cursor_line          :=
                       'select rn,
      distro_number,
       dc_dest_id,
       dest_id,
       item_id,
       xml_id,
       SEQ_NO,
       requested_qty,
       retail_price,
       document_type,
       cancel_date,
       segment1,
       segment2,
       segment3,
       segment4,
       context_code,
       context_value,
       status,
      dense_rank() over(order by batch) batch
  from(SELECT rn, distro_number,
       dc_dest_id,
       dest_id,
       item_id,
       xml_id,
       SEQ_NO,
       requested_qty,
       retail_price,
       document_type,
       cancel_date,
       segment1,
       segment2,
       segment3,
       segment4,
       context_code,
       context_value,
       status, (((SUM (
          requested_qty)
       OVER (
          PARTITION BY '
                    || lv_cursor_stmt00_line
                    || '
                       status
          ORDER BY requested_qty, 
             '
                    || lv_cursor_stmt00_line
                    || '
             status
          ROWS UNBOUNDED PRECEDING))-(mod(SUM (
          requested_qty)
       OVER (
          PARTITION BY '
                    || lv_cursor_stmt00_line
                    || '
                       status
          ORDER BY requested_qty,
             '
                    || lv_cursor_stmt00_line
                    || '
             status
          ROWS UNBOUNDED PRECEDING),'
                    || p_threshold
                    || ')))/'
                    || p_threshold
                    || '+1)- sign(trunc((requested_qty-'
                    || p_threshold
                    || ')/'
                    || p_threshold
                    || ')) batch
  FROM (  SELECT x26_2.ROWID rn, 
                 x26_2.distro_number,
                 x26_2.xml_id,
                 X26_2.SEQ_NO,
                 x26_2.item_id,
                 x26_2.requested_qty,
                 x26_2.retail_price,
                 x26_2.document_type,
                 x26_2.dc_dest_id,
                 x26_2.dest_id,
                 x26_2.pick_not_before_date cancel_date,
                 mc.segment1,
                 mc.segment2,
                 mc.segment3,
                 mc.segment4,
                 x26_2.context_code,
                 x26_2.context_value,
                 x26_2.status
            FROM APPS.mtl_item_categories mic,
                 APPS.mtl_categories_b mc,
                 APPS.mtl_category_sets_tl mcs,
                 APPS.xxdo_inv_int_026_stg2 x26_2                 
           WHERE 1=1
             AND    mic.category_id = mc.category_id
             AND mcs.category_set_id = mic.category_set_id
             AND mcs.category_set_name = ''Inventory''
             AND mc.structure_id =
                   (SELECT structure_id
                      FROM mtl_category_sets
                     WHERE UPPER (category_set_name) = ''INVENTORY'')
             AND mcs.LANGUAGE = ''US''
             AND (:cn_brand is null or  mc.segment1 =:cn_brand)
             AND (:cn_pgroup is null or  mc.segment2 =:cn_pgroup) 
             '
                    || lv_cursor_cls_stmt_gen
                    || '  
             AND (:cn_class is null or  mc.segment4 =:cn_class)                              
             AND mic.inventory_item_id = x26_2.item_id
             AND mic.organization_id = x26_2.dc_dest_id                               
             AND (:cn_dest_id is null or  x26_2.dest_id =:cn_dest_id) 
             AND dc_vw_id = :cn_vw_id
             AND (:cn_dc_dest_id is null or  x26_2.dc_dest_id =:cn_dc_dest_id)  
             AND x26_2.requested_qty > 0
             AND x26_2.status =NVL (:cn_status, x26_2.status)                             
             AND DECODE (NVL (:cn_context, ''9''),''9'', NVL (x26_2.context_code, ''9''),x26_2.context_code) =NVL (:cn_context, ''9'')                      
        ORDER BY dc_dest_id,
                 dest_id,
                 requested_qty,
                 item_id
                 )
                 ) ';

                IF NVL (pv_reprocess, 'N') = 'N'
                THEN
                    lv_cursor_stmt_pcondition   :=
                           ' AND X26_2.STATUS = 0 AND X26_2.REQUESTED_QTY > 0 AND X26_2.DEST_ID IN (SELECT RMS_STORE_ID FROM xxd_retail_stores_v WHERE REGION ='''
                        || p_region
                        || ''') ';
                    lv_cursor_stmt   :=
                           lv_cursor_stmt               /* Select Statement */
                        || lv_cursor_stmt_pcondition /* Parameter Where Condition */
                        || lv_cursor_cls_stmt_gen        /* Specific Gender */
                        || lv_cursor_cls_stmt            /* Specific  Class */
                        || lv_cursor_stmt_groupby;  /*Adding Group by Clause*/
                ELSE
                    SELECT ' AND X26_2.REQUESTED_QTY > 0 AND X26_2.STATUS = 2 AND X26_2.DEST_ID IN (SELECT RMS_STORE_ID FROM xxd_retail_stores_v WHERE REGION =''' || p_region || ''') AND X26_2.CREATION_DATE BETWEEN ''' || pd_rp_start_date || ''' AND ''' || DECODE (NVL (pv_reprocess, 'N'), 'Y', NVL (pd_rp_end_date, SYSDATE), NULL) || ''' '
                      INTO lv_cursor_stmt_pcondition
                      FROM DUAL;

                    lv_cursor_stmt   :=
                           lv_cursor_stmt               /* Select Statement */
                        || lv_cursor_stmt_pcondition /* Parameter Where Condition */
                        || lv_cursor_stmt_groupby;  /*Adding Group by Clause*/
                END IF;

                --     lv_udate_stmt := 'UPDATE XXDO_INV_INT_026_STG2 SET request_id = '||FND_GLOBAL.CONC_REQUEST_ID||' WHERE (dc_dest_id, dest_id) IN ('||lv_cursor_stmt||')';
                lv_udate_stmt           :=
                       'UPDATE XXDO_INV_INT_026_STG2 X26_2 SET request_id = '
                    || fnd_global.conc_request_id
                    || ' WHERE 1 = 1 '
                    || lv_cursor_stmt_pcondition;
                lv_update_stmt1         :=
                       'UPDATE XXDO_INV_INT_026_STG2 X26_2 SET (CONTEXT_CODE, CONTEXT_VALUE) = (SELECT CONTEXT_TYPE, CONTEXT_VALUE
                                                                                                                                                                    FROM ALLOC_HEADER@'
                    || pv_dblink
                    || ' AH
                                                                                                                                                                  WHERE AH.ALLOC_NO = X26_2.DISTRO_NUMBER)
                                   where 1= 1';

                IF p_sql_display = 'Y'
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Cursor Statement :' || lv_cursor_stmt);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        '==================================== :');
                    fnd_file.put_line (fnd_file.LOG,
                                       'Update Statement :' || lv_udate_stmt);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        '==================================== :');
                END IF;

                EXECUTE IMMEDIATE lv_udate_stmt;

                COMMIT;
                lv_update_stmt1         :=
                    lv_update_stmt1 || ' ' || lv_cursor_stmt_pcondition;

                IF p_debug = 'Y'
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'lv_update_stmt1 :' || lv_update_stmt1);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        '==================================== :');
                END IF;

                EXECUTE IMMEDIATE lv_update_stmt1;

                COMMIT;
                -- Added By Sivakumar Boothathan on 09/28/2012 for ignoring the Orphan Allocations

                --lv_update_stmt2 := 'UPDATE XXDO_INV_INT_026_STG2 X26_2 SET STATUS = 9 WHERE X26_2.STATUS = 0 AND X26_2.DEST_ID IN (SELECT RMS_STORE_ID FROM DO_RETAIL.STORES@DATAMART.DECKERS.COM WHERE REGION ='''||P_REGION||''') AND X26_2.DISTRO_NUMBER NOT IN (SELECT AH.ALLOC_NO FROM ALLOC_HEADER@'||pv_dblink||' AH WHERE AH.ALLOC_NO = X26_2.DISTRO_NUMBER)'; --1.5
                lv_update_stmt2         :=
                       'UPDATE XXDO_INV_INT_026_STG2 X26_2 SET STATUS = 9 WHERE X26_2.STATUS = 0 AND X26_2.DEST_ID IN (SELECT RMS_STORE_ID FROM xxd_retail_stores_v WHERE REGION ='''
                    || p_region
                    || ''') AND X26_2.DISTRO_NUMBER NOT IN (SELECT AH.ALLOC_NO FROM ALLOC_HEADER@'
                    || pv_dblink
                    || ' AH WHERE AH.ALLOC_NO = X26_2.DISTRO_NUMBER)';

                IF p_sql_display = 'Y'
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'lv_update_stmt2 :' || lv_update_stmt2);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        '==================================== :');
                    fnd_file.put_line (fnd_file.LOG,
                                       'lv_cursor_line ' || lv_cursor_line);
                END IF;

                EXECUTE IMMEDIATE lv_update_stmt2;

                COMMIT;
                /*Fetching Order Source Information */
                fetch_order_source (ln_order_source_id,
                                    lv_status,
                                    lv_error_message);

                IF NVL (lv_status, 'S') = 'E'
                THEN
                    fnd_file.put_line (fnd_file.LOG, lv_error_message);
                    -- fnd_file.put_line (fnd_file.LOG, lv_error_message); -- Commented for 2.0.
                    fnd_file.put_line (fnd_file.OUTPUT, lv_error_message); -- Modified for 2.0.
                END IF;

                /*Loop for Inserting Header Record into Order Header Interface Table*/
                OPEN cur_xxdo26_stg2 FOR lv_cursor_stmt;

                LOOP
                    FETCH cur_xxdo26_stg2
                        INTO lr_rec_stg2_dc_dest_id, lr_rec_stg2_dc_vm_id, lr_rec_stg2_dest_id, lr_rec_stg2_brand,
                             lr_rec_stg2_gender, lr_rec_stg2_pgroup,     --1.5
                                                                     lr_rec_stg2_class,
                             lr_rec_stg2_context_code, lr_rec_stg2_context_value, lr_rec_stg2_status,
                             lr_rec_stg2_cancel_date;

                    EXIT WHEN cur_xxdo26_stg2%NOTFOUND;
                    fetch_customer_id (lr_rec_stg2_dest_id, ln_customer_id, ln_customer_number
                                       , lv_status, lv_error_message);

                    IF NVL (lv_status, 'S') = 'E'
                    THEN
                        fnd_file.put_line (fnd_file.LOG, lv_error_message);
                        fnd_file.put_line (fnd_file.LOG, lv_error_message);
                    END IF;

                    fetch_org_id (lr_rec_stg2_dc_dest_id, lr_rec_stg2_dc_vm_id, lr_rec_stg2_dest_id, -- Added for 1.8.
                                                                                                     ln_org_id, lv_inv_org_code, lv_status
                                  , lv_error_message);

                    IF NVL (lv_status, 'S') = 'E'
                    THEN
                        fnd_file.put_line (fnd_file.LOG, lv_error_message);
                        fnd_file.put_line (fnd_file.LOG, lv_error_message);
                    END IF;

                    fetch_order_type ('SHIP', ln_org_id, lr_rec_stg2_dc_vm_id, lr_rec_stg2_dest_id, ln_order_type_id, lv_status
                                      , lv_error_message);

                    IF NVL (lv_status, 'S') = 'E'
                    THEN
                        fnd_file.put_line (fnd_file.LOG, lv_error_message);
                        fnd_file.put_line (fnd_file.LOG, lv_error_message);
                    END IF;

                    fnd_file.put_line (
                        fnd_file.LOG,
                        '==================================== :');
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'lr_rec_stg2_brand ' || lr_rec_stg2_brand);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'lr_rec_stg2_pgroup ' || lr_rec_stg2_pgroup);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'lr_rec_stg2_class ' || lr_rec_stg2_class);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'lr_rec_stg2_dest_id ' || lr_rec_stg2_dest_id);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'lr_rec_stg2_dc_vm_id ' || lr_rec_stg2_dc_vm_id);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'lr_rec_stg2_dc_dest_id ' || lr_rec_stg2_dc_dest_id);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'lr_rec_stg2_status ' || lr_rec_stg2_status);
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'lr_rec_stg2_context_code '
                        || lr_rec_stg2_context_code);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        '==================================== :');

                    OPEN cur_xxdo26_stg2_line FOR TO_CHAR (lv_cursor_line)
                        USING                                   --p_threshold,
                             lr_rec_stg2_brand, lr_rec_stg2_brand, lr_rec_stg2_pgroup,
                    lr_rec_stg2_pgroup, -- lr_rec_stg2_gender,
                                        lr_rec_stg2_class, lr_rec_stg2_class,
                    lr_rec_stg2_dest_id, lr_rec_stg2_dest_id, lr_rec_stg2_dc_vm_id,
                    lr_rec_stg2_dc_dest_id, lr_rec_stg2_dc_dest_id, lr_rec_stg2_status,
                    lr_rec_stg2_context_code, lr_rec_stg2_context_code;

                    FETCH cur_xxdo26_stg2_line
                        BULK COLLECT INTO ln_blk_col.ln_rn, ln_blk_col.ln_distro_number, ln_blk_col.ln_dc_dest_id,
                             ln_blk_col.ln_dest_id, ln_blk_col.ln_item_id, ln_blk_col.ln_xml_id,
                             ln_blk_col.ln_seq_no, ln_blk_col.ln_requested_qty, ln_blk_col.ln_retail_price,
                             ln_blk_col.ln_document_type, ln_blk_col.ln_cancel, ln_blk_col.ln_segment1,
                             ln_blk_col.ln_segment2, ln_blk_col.ln_segment3, ln_blk_col.ln_segment4,
                             ln_blk_col.ln_context_code, ln_blk_col.ln_context_value, ln_blk_col.ln_status,
                             ln_blk_col.ln_batch;

                    CLOSE cur_xxdo26_stg2_line;

                    ln_batch   := 0;

                    FOR i IN 1 .. ln_blk_col.ln_rn.COUNT
                    LOOP
                        /*Inserting into Order Header Interface Tables */
                        IF p_debug = 'Y'
                        THEN
                            fnd_file.put_line (fnd_file.LOG,
                                               'ln_batch H0 ' || ln_batch);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'ln_blk_col.ln_batch(i) H0  ' || ln_blk_col.ln_batch (i));
                            fnd_file.put_line (fnd_file.LOG,
                                               '====================');
                        END IF;

                        IF ln_blk_col.ln_batch (i) > ln_batch
                        THEN
                            BEGIN
                                IF p_debug = 'Y'
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'ln_batch ' || ln_batch);
                                    /*  fnd_file.put_line (fnd_file.LOG,
                                                              'ln_blk_col.ln_batch(i) '
                                                           || ln_blk_col.ln_batch (i)
                                                          ); */
                                    -- Commented for 2.0.
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'ln_blk_col.ln_batch('
                                        || i
                                        || ') : '
                                        || ln_blk_col.ln_batch (i)); -- Modified for 2.0.
                                    fnd_file.put_line (
                                        fnd_file.output,
                                        '====================');
                                    fnd_file.put_line (
                                        fnd_file.output,
                                           'RMS'
                                        || '-'
                                        || ln_blk_col.ln_dest_id (i)
                                        || '-'
                                        || ln_blk_col.ln_dc_dest_id (i)
                                        || '-'
                                        || ln_org_ref_sequence);
                                END IF;

                                SELECT xxdo_inv_int_026_seq.NEXTVAL
                                  INTO ln_org_ref_sequence
                                  FROM DUAL;

                                INSERT INTO oe_headers_iface_all (
                                                order_source_id,
                                                order_type_id,
                                                org_id,
                                                orig_sys_document_ref,
                                                created_by,
                                                creation_date,
                                                last_updated_by,
                                                last_update_date,
                                                operation_code,
                                                booked_flag --                      ,customer_number
                                          --                      ,customer_id
                                                ,
                                                sold_to_org_id,
                                                customer_po_number,
                                                attribute1,
                                                attribute5,
                                                shipping_method_code,
                                                shipping_method)
                                     VALUES (ln_order_source_id, ln_order_type_id, ln_org_id, 'RMS' || '-' || lr_rec_stg2_dest_id || '-' || lr_rec_stg2_dc_dest_id || '-' || ln_org_ref_sequence, fnd_global.user_id, SYSDATE, fnd_global.user_id, SYSDATE, 'INSERT', 'N' --- Changed to 'N' on 18th May
                                                                                                                                                                                                                                                                         --                      ,ln_customer_number
                                                                                                                                                                                                                                                                         --                      ,ln_customer_id
                                                                                                                                                                                                                                                                         , ln_customer_id, 'RMS' || '-' || lr_rec_stg2_dest_id || '-' || lr_rec_stg2_dc_dest_id || '-' || ln_org_ref_sequence, --TO_CHAR (lr_rec_stg2_cancel_date + 5,
                                                                                                                                                                                                                                                                                                                                                                                               --         'DD-MON-RRRR'
                                                                                                                                                                                                                                                                                                                                                                                               --        ),
                                                                                                                                                                                                                                                                                                                                                                                               TO_CHAR (lr_rec_stg2_cancel_date + 5, 'YYYY/MM/DD HH:MI:SS'), -- 1.5
                                                                                                                                                                                                                                                                                                                                                                                                                                                             lr_rec_stg2_brand, lr_rec_stg2_context_code
                                             , lr_rec_stg2_context_value);

                                lv_header_insertion_status   := 'S';
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    lv_error_message             :=
                                           lv_error_message
                                        || ' - '
                                        || 'Error while Inserting into Order Header Interface table : '
                                        || SQLERRM;
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Code :' || SQLCODE);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Error while Inserting into Order Header Interface table : '
                                        || SQLERRM);
                                    /* fnd_file.put_line
                                          (fnd_file.LOG,
                                              'Error while Inserting into Order Header Interface table : '
                                           || SQLERRM
                                          ); */
                                    -- Commented for 2.0.
                                    -- START : 2.0.
                                    fnd_file.put_line (
                                        fnd_file.OUTPUT,
                                           'Error while Inserting into Order Header Interface table : '
                                        || SQLERRM);
                                    -- END : 2.0.
                                    lv_header_insertion_status   := 'E';
                            END;

                            --------11
                            IF NVL (lv_header_insertion_status, 'S') = 'S'
                            THEN
                                ln_line_number             := 0;
                                lv_line_insertion_status   := 'S';
                                /* Contition to verify whether item exists in price list or not */
                                ln_exists                  := NULL;
                                ln_organization_id         := NULL;     -- 1.5

                                -- Commented Start 1.7 Modified for Price list
                                /*BEGIN
                                   --START W.R.T Version 1.5
                                   SELECT organization_id
                                     INTO ln_organization_id
                                     FROM mtl_parameters
                                    WHERE organization_code =
                                             fnd_profile.VALUE
                                                            ('XXDO: ORGANIZATION CODE');

                                   SELECT xxdoinv006_pkg.get_region_cost_f
                                                            (ln_blk_col.ln_item_id (i),
                                                             ln_organization_id,  --7,
                                                             lv_region
                                                            )
                                     INTO ln_exists
                                     FROM DUAL;
                                EXCEPTION
                                   WHEN OTHERS
                                   THEN
                                      fnd_file.put_line
                                         (fnd_file.LOG,
                                             'Error while vefifying price list condition:'
                                          || SQLERRM
                                         );
                                      ln_exists := 0;
                                END;*/

                                -- Commented Start 1.7 Modified for Price list
                                --IF ln_exists = 1
                                --THEN
                                BEGIN
                                    ln_line_number             := ln_line_number + 1;

                                    INSERT INTO oe_lines_iface_all (
                                                    order_source_id,
                                                    org_id,
                                                    orig_sys_document_ref,
                                                    orig_sys_line_ref,
                                                    inventory_item_id,
                                                    ordered_quantity --            ,order_quantity_uom
                                                                    ,
                                                    unit_selling_price,
                                                    --     ship_from_org_id,      -- Commented for 2.1.
                                                    ship_from_org_id, -- Uncommented for 2.2.
                                                    request_date,
                                                    created_by,
                                                    creation_date,
                                                    last_updated_by,
                                                    last_update_date,
                                                    attribute1 --                                       ,sold_to_org_id
                                                              )
                                             VALUES (
                                                        ln_order_source_id,
                                                        ln_org_id,
                                                           'RMS'
                                                        || '-'
                                                        || ln_blk_col.ln_dest_id (
                                                               i)
                                                        || '-'
                                                        || ln_blk_col.ln_dc_dest_id (
                                                               i)
                                                        || '-'
                                                        || ln_org_ref_sequence,
                                                           ln_blk_col.ln_distro_number (
                                                               i)
                                                        || '-'
                                                        || ln_blk_col.ln_document_type (
                                                               i)
                                                        || '-'
                                                        || xxdo_inv_int_026_seq.NEXTVAL
                                                        || '-'
                                                        || ln_blk_col.ln_xml_id (
                                                               i),
                                                        ln_blk_col.ln_item_id (
                                                            i),
                                                        ln_blk_col.ln_requested_qty (
                                                            i) --             ,rec_order_lines.selling_uom
                                                              ,
                                                        ln_blk_col.ln_retail_price (
                                                            i),
                                                        --     ln_blk_col.ln_dc_dest_id (i),     -- Commented for 2.1.
                                                        ln_blk_col.ln_dc_dest_id (
                                                            i), -- Uncommented for 2.2.
                                                        ln_blk_col.ln_cancel (
                                                            i) -----rec_order_lines.pick_not_before_date
                                                              ,
                                                        fnd_global.user_id,
                                                        SYSDATE,
                                                        fnd_global.user_id,
                                                        SYSDATE,
                                                        --TO_CHAR (lr_rec_stg2_cancel_date
                                                        --         + 5,
                                                        --         'DD-MON-RRRR'
                                                        --        )
                                                        TO_CHAR (
                                                              lr_rec_stg2_cancel_date
                                                            + 5,
                                                            'YYYY/MM/DD HH:MI:SS') -- 1.5
                                                                                  --                                     ,ln_customer_id
                                                                                  );

                                    lv_line_insertion_status   := 'S';

                                    IF p_debug = 'Y'
                                    THEN
                                        fnd_file.put_line (
                                            fnd_file.output,
                                               ln_blk_col.ln_distro_number (
                                                   i)
                                            || '-'
                                            || ln_blk_col.ln_document_type (
                                                   i)
                                            || '-'
                                            || ln_blk_col.ln_xml_id (i));
                                    END IF;

                                    BEGIN
                                        UPDATE xxdo_inv_int_026_stg2 x26_2
                                           SET x26_2.status = 1, x26_2.brand = lr_rec_stg2_brand
                                         WHERE x26_2.ROWID =
                                               ln_blk_col.ln_rn (i);
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            lv_error_message   :=
                                                   lv_error_message
                                                || ' - '
                                                --     || 'Error while Updating Status 2 for Dest_id - ' -- Commented for 2.0.
                                                || 'Error while Updating Status 1 for Dest_id - ' -- Modified for 2.0.
                                                || lr_rec_stg2_dest_id
                                                || ' AND dc_dest_id - '
                                                || lr_rec_stg2_dc_dest_id
                                                || '  :'
                                                || SQLERRM;
                                            fnd_file.put_line (
                                                fnd_file.LOG,
                                                'SQL Error Code :' || SQLCODE);
                                            /*  fnd_file.put_line
                                                   (fnd_file.LOG,
                                                       'Error while Updating Status 2 for Dest_id - '
                                                    || lr_rec_stg2_dest_id
                                                    || ' AND dc_dest_id - '
                                                    || lr_rec_stg2_dc_dest_id
                                                    || '  :'
                                                    || SQLERRM
                                                   );
                                                fnd_file.put_line
                                                   (fnd_file.LOG,
                                                       'Error while Updating Status 2 for Dest_id - '
                                                    || lr_rec_stg2_dest_id
                                                    || ' AND dc_dest_id - '
                                                    || lr_rec_stg2_dc_dest_id
                                                    || '  :'
                                                    || SQLERRM
                                                   ); */
                                            -- Commented for 2.0.
                                            -- START : 2.0.
                                            fnd_file.put_line (
                                                fnd_file.LOG,
                                                   'Error while Updating Status 1 for Dest_id - '
                                                || lr_rec_stg2_dest_id
                                                || ' AND dc_dest_id - '
                                                || lr_rec_stg2_dc_dest_id
                                                || '  :'
                                                || SQLERRM);

                                            fnd_file.put_line (
                                                fnd_file.OUTPUT,
                                                   'Error while Updating Status 1 for Dest_id - '
                                                || lr_rec_stg2_dest_id
                                                || ' AND dc_dest_id - '
                                                || lr_rec_stg2_dc_dest_id
                                                || '  :'
                                                || SQLERRM);
                                    -- END : 2.0.
                                    END;

                                    COMMIT;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                            'SQL Error Code :' || SQLCODE);
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                               'Error while Inserting into Order Lines Interface table :'
                                            || SQLERRM);
                                        /*  fnd_file.put_line
                                               (fnd_file.LOG,
                                                   'Error while Inserting into Order Lines Interface table :'
                                                || SQLERRM
                                               ); */
                                        -- Commented for 2.0.
                                        fnd_file.put_line (
                                            fnd_file.OUTPUT,
                                               'Error while Inserting into Order Lines Interface table : '
                                            || SQLERRM);
                                        lv_line_insertion_status   := 'E';

                                        BEGIN
                                            UPDATE xxdo_inv_int_026_stg2 x26_2
                                               SET x26_2.status = 2, x26_2.brand = lr_rec_stg2_brand, x26_2.error_message = 'Seq NO :' || ln_blk_col.ln_seq_no (i) || ' ' || lv_error_message
                                             WHERE     (x26_2.seq_no) IN
                                                           (SELECT x26_2.seq_no
                                                              FROM xxdo_inv_int_026_stg2 x26_2_1, mtl_item_categories mic, mtl_categories_b mc,
                                                                   mtl_category_sets_tl mcs
                                                             WHERE     mic.category_id =
                                                                       mc.category_id
                                                                   AND mcs.category_set_id =
                                                                       mic.category_set_id
                                                                   AND mic.inventory_item_id =
                                                                       x26_2_1.item_id
                                                                   AND mic.organization_id =
                                                                       x26_2_1.dc_dest_id
                                                                   AND UPPER (
                                                                           mcs.category_set_name) =
                                                                       'INVENTORY'
                                                                   -- AND MC.STRUCTURE_ID = 101
                                                                   AND mc.structure_id =
                                                                       (SELECT structure_id
                                                                          FROM mtl_category_sets
                                                                         WHERE UPPER (
                                                                                   category_set_name) =
                                                                               'INVENTORY')
                                                                   --1.5
                                                                   AND mcs.LANGUAGE =
                                                                       'US'
                                                                   AND x26_2_1.dc_dest_id =
                                                                       lr_rec_stg2_dc_dest_id
                                                                   AND x26_2_1.dest_id =
                                                                       lr_rec_stg2_dc_dest_id
                                                                   AND mc.segment1 =
                                                                       lr_rec_stg2_brand
                                                                   --  AND mc.segment2 =lr_rec_stg2_pgroup --1.5
                                                                   --  AND mc.segment3 =lr_rec_stg2_gender --1.5
                                                                   AND mc.segment2 =
                                                                       lr_rec_stg2_gender
                                                                   AND mc.segment3 =
                                                                       lr_rec_stg2_pgroup
                                                                   AND mc.segment4 =
                                                                       lr_rec_stg2_class)
                                                   AND x26_2.request_id =
                                                       fnd_global.conc_request_id;
                                        --                              UPDATE XXDO_INV_INT_026_STG2 X26_2
                                        --                                    SET X26_2.STATUS = 2,
                                        --                                           X26_2.ERROR_MESSAGE = 'Seq NO :'||rec_order_lines.seq_no||' '||lv_error_message
                                        --                                WHERE X26_2.ROWID = rec_order_lines.ROWID;
                                        EXCEPTION
                                            WHEN OTHERS
                                            THEN
                                                fnd_file.put_line (
                                                    fnd_file.LOG,
                                                       'SQL Error Code :'
                                                    || SQLCODE);
                                                fnd_file.put_line (
                                                    fnd_file.LOG,
                                                       'Error while Updating Status 2 for Dest_id - '
                                                    || lr_rec_stg2_dest_id
                                                    || ' AND dc_dest_id - '
                                                    || lr_rec_stg2_dc_dest_id
                                                    || '  :'
                                                    || SQLERRM);
                                                /* fnd_file.put_line
                                                      (fnd_file.LOG,
                                                          'Error while Updating Status 2 for Dest_id - '
                                                       || lr_rec_stg2_dest_id
                                                       || ' AND dc_dest_id - '
                                                       || lr_rec_stg2_dc_dest_id
                                                       || '  :'
                                                       || SQLERRM
                                                      ); */
                                                -- Commented for 2.0.

                                                -- START : 2.0.
                                                fnd_file.put_line (
                                                    fnd_file.OUTPUT,
                                                       'Error while Updating Status 2 for Dest_id - '
                                                    || lr_rec_stg2_dest_id
                                                    || ' AND dc_dest_id - '
                                                    || lr_rec_stg2_dc_dest_id
                                                    || '  :'
                                                    || SQLERRM);
                                        -- END : 2.0.
                                        END;
                                END;
                            /*ELSIF ln_exists = 0
                            THEN
                               BEGIN
                                  xxdo_int_009_prc
                                                (lv_errbuf,
                                                 lv_retcode,
                                                 ln_blk_col.ln_dc_dest_id (i),
                                                 ln_blk_col.ln_distro_number (i),
                                                 ln_blk_col.ln_document_type (i),
                                                 ln_blk_col.ln_distro_number (i),
                                                 ln_blk_col.ln_dest_id (i),
                                                 ln_blk_col.ln_item_id (i),
                                                 1  --rec_order_sch.order_line_num
                                                  ,
                                                 ln_blk_col.ln_requested_qty (i),
                                                 'NI'
                                                );

                                  BEGIN
                                     UPDATE xxdo_inv_int_026_stg2 x26_2
                                        SET schedule_check = 'Y',
                                            x26_2.status = 9,
                                            x26_2.brand = lr_rec_stg2_brand,
                                            x26_2.error_message =
                                                          'ITEM NOT IN PRICE LIST'
                                      WHERE x26_2.ROWID = ln_blk_col.ln_rn (i);
                                  EXCEPTION
                                     WHEN OTHERS
                                     THEN
                                        fnd_file.put_line
                                           (fnd_file.LOG,
                                               'Error while Updating Schedule Check NI '
                                            || ln_blk_col.ln_distro_number (i)
                                            || ' - '
                                            || ln_blk_col.ln_dc_dest_id (i)
                                            || ' --- '
                                            || SQLERRM
                                           );
                                  END;
                               END;
                            END IF;*/
                            -- -- Commented End 1.7 Modified for Price list
                            ELSE
                                BEGIN
                                    UPDATE xxdo_inv_int_026_stg2 x26_2
                                       SET x26_2.status = 2, x26_2.brand = lr_rec_stg2_brand, x26_2.error_message = lv_error_message
                                     WHERE     (x26_2.seq_no) IN
                                                   (SELECT x26_2.seq_no
                                                      FROM xxdo_inv_int_026_stg2 x26_2_1, mtl_item_categories mic, mtl_categories_b mc,
                                                           mtl_category_sets_tl mcs
                                                     WHERE     mic.category_id =
                                                               mc.category_id
                                                           AND mcs.category_set_id =
                                                               mic.category_set_id
                                                           AND mic.inventory_item_id =
                                                               x26_2_1.item_id
                                                           AND mic.organization_id =
                                                               x26_2_1.dc_dest_id
                                                           AND UPPER (
                                                                   mcs.category_set_name) =
                                                               'INVENTORY'
                                                           --AND MC.STRUCTURE_ID = 101
                                                           AND mc.structure_id =
                                                               (SELECT structure_id
                                                                  FROM mtl_category_sets
                                                                 WHERE UPPER (
                                                                           category_set_name) =
                                                                       'INVENTORY')
                                                           --1.5
                                                           AND mcs.LANGUAGE =
                                                               'US'
                                                           AND x26_2_1.requested_qty >
                                                               0
                                                           AND x26_2_1.dc_dest_id =
                                                               lr_rec_stg2_dc_dest_id
                                                           AND x26_2_1.dest_id =
                                                               lr_rec_stg2_dc_dest_id
                                                           AND mc.segment1 =
                                                               lr_rec_stg2_brand
                                                           -- AND mc.segment2 = lr_rec_stg2_pgroup  --W.r.t 1.5
                                                           --   AND mc.segment3 = lr_rec_stg2_gender  --W.r.t 1.5
                                                           AND mc.segment2 =
                                                               lr_rec_stg2_gender
                                                           --W.r.t 1.5
                                                           AND mc.segment3 =
                                                               lr_rec_stg2_pgroup
                                                           --W.r.t 1.5
                                                           AND mc.segment4 =
                                                               lr_rec_stg2_class)
                                           AND x26_2.request_id =
                                               fnd_global.conc_request_id;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                            'SQL Error Code :' || SQLCODE);
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                               'Error while Updating Status 2 for Dest_id - '
                                            || lr_rec_stg2_dest_id
                                            || ' AND dc_dest_id - '
                                            || lr_rec_stg2_dc_dest_id
                                            || '  :'
                                            || SQLERRM);
                                        /* fnd_file.put_line
                                              (fnd_file.LOG,
                                                  'Error while Updating Status 2 for Dest_id - '
                                               || lr_rec_stg2_dest_id
                                               || ' AND dc_dest_id - '
                                               || lr_rec_stg2_dc_dest_id
                                               || '  :'
                                               || SQLERRM
                                              ); */
                                        -- Commented for 2.0.

                                        -- START : 2.0.
                                        fnd_file.put_line (
                                            fnd_file.OUTPUT,
                                               'Error while Updating Status 2 for Dest_id - '
                                            || lr_rec_stg2_dest_id
                                            || ' AND dc_dest_id - '
                                            || lr_rec_stg2_dc_dest_id
                                            || '  :'
                                            || SQLERRM);
                                -- END : 2.0.
                                END;
                            END IF;

                            ln_batch   := ln_blk_col.ln_batch (i);

                            IF p_debug = 'Y'
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'ln_batch H1 ' || ln_batch);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'ln_org_ref_sequence H1 '
                                    || ln_org_ref_sequence);

                                SELECT xxdo_inv_int_026_seq.CURRVAL
                                  INTO v_curr_val
                                  FROM DUAL;

                                fnd_file.put_line (fnd_file.LOG,
                                                   'seq ' || v_curr_val);
                                fnd_file.put_line (fnd_file.LOG,
                                                   '====================');
                            END IF;
                        ELSE
                            --------11
                            IF NVL (lv_header_insertion_status, 'S') = 'S'
                            THEN
                                ln_line_number             := 0;
                                lv_line_insertion_status   := 'S';
                                /* Contition to verify whether item exists in price list or not */
                                ln_exists                  := NULL;

                                -- Commented 1.7
                                /*BEGIN
                                   --START W.R.T Version 1.5
                                   SELECT organization_id
                                     INTO ln_organization_id
                                     FROM mtl_parameters
                                    WHERE organization_code =
                                             fnd_profile.VALUE
                                                            ('XXDO: ORGANIZATION CODE');

                                   SELECT xxdoinv006_pkg.get_region_cost_f
                                                            (ln_blk_col.ln_item_id (i),
                                                             ln_organization_id,
                                                             --7, 1.5
                                                             lv_region
                                                            )
                                     INTO ln_exists
                                     FROM DUAL;
                                EXCEPTION
                                   WHEN OTHERS
                                   THEN
                                      fnd_file.put_line
                                         (fnd_file.LOG,
                                             'Error while vefifying price list condition:'
                                          || SQLERRM
                                         );
                                      ln_exists := 0;
                                END;*/

                                -- Commented 1.7
                                --IF ln_exists = 1
                                --THEN
                                BEGIN
                                    ln_line_number             := ln_line_number + 1;

                                    INSERT INTO oe_lines_iface_all (
                                                    order_source_id,
                                                    org_id,
                                                    orig_sys_document_ref,
                                                    orig_sys_line_ref,
                                                    inventory_item_id,
                                                    ordered_quantity --            ,order_quantity_uom
                                                                    ,
                                                    unit_selling_price,
                                                    --    ship_from_org_id,        --    Commented for 2.1.
                                                    ship_from_org_id, --    Uncommented for 2.2.
                                                    request_date,
                                                    created_by,
                                                    creation_date,
                                                    last_updated_by,
                                                    last_update_date,
                                                    attribute1 --                                       ,sold_to_org_id
                                                              )
                                             VALUES (
                                                        ln_order_source_id,
                                                        ln_org_id,
                                                           'RMS'
                                                        || '-'
                                                        || ln_blk_col.ln_dest_id (
                                                               i)
                                                        || '-'
                                                        || ln_blk_col.ln_dc_dest_id (
                                                               i)
                                                        || '-'
                                                        || ln_org_ref_sequence,
                                                           ln_blk_col.ln_distro_number (
                                                               i)
                                                        || '-'
                                                        || ln_blk_col.ln_document_type (
                                                               i)
                                                        || '-'
                                                        || xxdo_inv_int_026_seq.NEXTVAL
                                                        || '-'
                                                        || ln_blk_col.ln_xml_id (
                                                               i),
                                                        ln_blk_col.ln_item_id (
                                                            i),
                                                        ln_blk_col.ln_requested_qty (
                                                            i) --             ,rec_order_lines.selling_uom
                                                              ,
                                                        ln_blk_col.ln_retail_price (
                                                            i),
                                                        --   ln_blk_col.ln_dc_dest_id (i), -- Commented for 2.1.
                                                        ln_blk_col.ln_dc_dest_id (
                                                            i), -- Uncommented for 2.2.
                                                        ln_blk_col.ln_cancel (
                                                            i) -----rec_order_lines.pick_not_before_date
                                                              ,
                                                        fnd_global.user_id,
                                                        SYSDATE,
                                                        fnd_global.user_id,
                                                        SYSDATE,
                                                        --TO_CHAR (lr_rec_stg2_cancel_date
                                                        --         + 5,
                                                        --         'DD-MON-RRRR'
                                                        --       )
                                                        TO_CHAR (
                                                              lr_rec_stg2_cancel_date
                                                            + 5,
                                                            'YYYY/MM/DD HH:MI:SS') -- 1.5
                                                                                  --                                     ,ln_customer_id
                                                                                  );

                                    lv_line_insertion_status   := 'S';
                                    fnd_file.put_line (
                                        fnd_file.output,
                                           'RMS'
                                        || '-'
                                        || ln_blk_col.ln_dest_id (i)
                                        || '-'
                                        || ln_blk_col.ln_dc_dest_id (i)
                                        || '-'
                                        || ln_org_ref_sequence);
                                    fnd_file.put_line (
                                        fnd_file.output,
                                           ln_blk_col.ln_distro_number (i)
                                        || '-'
                                        || ln_blk_col.ln_document_type (i)
                                        || '-'
                                        || ln_blk_col.ln_xml_id (i));

                                    BEGIN
                                        UPDATE xxdo_inv_int_026_stg2 x26_2
                                           SET x26_2.status = 1, x26_2.brand = lr_rec_stg2_brand
                                         WHERE x26_2.ROWID =
                                               ln_blk_col.ln_rn (i);
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            lv_error_message   :=
                                                   lv_error_message
                                                || ' - '
                                                -- || 'Error while Updating Status 2 for Dest_id - ' -- Commented for 2.0.
                                                || 'Error while Updating Status 1 for Dest_id - ' -- Modified for 2.0.
                                                || lr_rec_stg2_dest_id
                                                || ' AND dc_dest_id - '
                                                || lr_rec_stg2_dc_dest_id
                                                || '  :'
                                                || SQLERRM;
                                            fnd_file.put_line (
                                                fnd_file.LOG,
                                                'SQL Error Code :' || SQLCODE);
                                            /*   fnd_file.put_line
                                                    (fnd_file.LOG,
                                                        'Error while Updating Status 2 for Dest_id - '
                                                     || lr_rec_stg2_dest_id
                                                     || ' AND dc_dest_id - '
                                                     || lr_rec_stg2_dc_dest_id
                                                     || '  :'
                                                     || SQLERRM
                                                    );
                                                 fnd_file.put_line
                                                    (fnd_file.LOG,
                                                        'Error while Updating Status 2 for Dest_id - '
                                                     || lr_rec_stg2_dest_id
                                                     || ' AND dc_dest_id - '
                                                     || lr_rec_stg2_dc_dest_id
                                                     || '  :'
                                                     || SQLERRM
                                                    ); */
                                            -- Commented for 2.0.

                                            -- START : 2.0.
                                            fnd_file.put_line (
                                                fnd_file.LOG,
                                                   'Error while Updating Status 1 for Dest_id - '
                                                || lr_rec_stg2_dest_id
                                                || ' AND dc_dest_id - '
                                                || lr_rec_stg2_dc_dest_id
                                                || '  :'
                                                || SQLERRM);
                                            fnd_file.put_line (
                                                fnd_file.LOG,
                                                   'Error while Updating Status 1 for Dest_id - '
                                                || lr_rec_stg2_dest_id
                                                || ' AND dc_dest_id - '
                                                || lr_rec_stg2_dc_dest_id
                                                || '  :'
                                                || SQLERRM);
                                    -- END : 2.0.
                                    END;

                                    COMMIT;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                            'SQL Error Code :' || SQLCODE);
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                               'Error while Inserting into Order Lines Interface table :'
                                            || SQLERRM);
                                        /* fnd_file.put_line
                                              (fnd_file.LOG,
                                                  'Error while Inserting into Order Lines Interface table :'
                                               || SQLERRM
                                              ); */
                                        -- Commented for 2.0.

                                        -- START : 2.0.
                                        fnd_file.put_line (
                                            fnd_file.OUTPUT,
                                               'Error while Inserting into Order Lines Interface table : '
                                            || SQLERRM);
                                        -- END : 2.0.

                                        lv_line_insertion_status   := 'E';

                                        BEGIN
                                            UPDATE xxdo_inv_int_026_stg2 x26_2
                                               SET x26_2.status = 2, x26_2.brand = lr_rec_stg2_brand, x26_2.error_message = 'Seq NO :' || ln_blk_col.ln_seq_no (i) || ' ' || lv_error_message
                                             WHERE     (x26_2.seq_no) IN
                                                           (SELECT x26_2.seq_no
                                                              FROM xxdo_inv_int_026_stg2 x26_2_1, mtl_item_categories mic, mtl_categories_b mc,
                                                                   mtl_category_sets_tl mcs
                                                             WHERE     mic.category_id =
                                                                       mc.category_id
                                                                   AND mcs.category_set_id =
                                                                       mic.category_set_id
                                                                   AND mic.inventory_item_id =
                                                                       x26_2_1.item_id
                                                                   AND mic.organization_id =
                                                                       x26_2_1.dc_dest_id
                                                                   AND UPPER (
                                                                           mcs.category_set_name) =
                                                                       'INVENTORY'
                                                                   -- AND MC.STRUCTURE_ID = 101
                                                                   AND mc.structure_id =
                                                                       (SELECT structure_id
                                                                          FROM mtl_category_sets
                                                                         WHERE UPPER (
                                                                                   category_set_name) =
                                                                               'INVENTORY')
                                                                   --1.5
                                                                   AND mcs.LANGUAGE =
                                                                       'US'
                                                                   AND x26_2_1.dc_dest_id =
                                                                       lr_rec_stg2_dc_dest_id
                                                                   AND x26_2_1.dest_id =
                                                                       lr_rec_stg2_dc_dest_id
                                                                   AND mc.segment1 =
                                                                       lr_rec_stg2_brand
                                                                   --   AND mc.segment2 =lr_rec_stg2_pgroup  --W.r.t 1.5
                                                                   --    AND mc.segment3 =lr_rec_stg2_gender  --W.r.t 1.5
                                                                   AND mc.segment2 =
                                                                       lr_rec_stg2_gender
                                                                   --W.r.t 1.5
                                                                   AND mc.segment3 =
                                                                       lr_rec_stg2_pgroup
                                                                   --W.r.t 1.5
                                                                   AND mc.segment4 =
                                                                       lr_rec_stg2_class)
                                                   AND x26_2.request_id =
                                                       fnd_global.conc_request_id;
                                        EXCEPTION
                                            WHEN OTHERS
                                            THEN
                                                fnd_file.put_line (
                                                    fnd_file.LOG,
                                                       'SQL Error Code :'
                                                    || SQLCODE);
                                                fnd_file.put_line (
                                                    fnd_file.LOG,
                                                       'Error while Updating Status 2 for Dest_id - '
                                                    || lr_rec_stg2_dest_id
                                                    || ' AND dc_dest_id - '
                                                    || lr_rec_stg2_dc_dest_id
                                                    || '  :'
                                                    || SQLERRM);
                                                /*   fnd_file.put_line
                                                        (fnd_file.LOG,
                                                            'Error while Updating Status 2 for Dest_id - '
                                                         || lr_rec_stg2_dest_id
                                                         || ' AND dc_dest_id - '
                                                         || lr_rec_stg2_dc_dest_id
                                                         || '  :'
                                                         || SQLERRM
                                                        ); */
                                                -- Commented for 2.0.

                                                -- START : 2.0.
                                                fnd_file.put_line (
                                                    fnd_file.OUTPUT,
                                                       'Error while Updating Status 2 for Dest_id - '
                                                    || lr_rec_stg2_dest_id
                                                    || ' AND dc_dest_id - '
                                                    || lr_rec_stg2_dc_dest_id
                                                    || '  :'
                                                    || SQLERRM);
                                        -- END : 2.0.
                                        END;
                                END;
                            /*ELSIF ln_exists = 0 -- Commented start 1.7
                            THEN
                               BEGIN
                                  xxdo_int_009_prc
                                                (lv_errbuf,
                                                 lv_retcode,
                                                 ln_blk_col.ln_dc_dest_id (i),
                                                 ln_blk_col.ln_distro_number (i),
                                                 ln_blk_col.ln_document_type (i),
                                                 ln_blk_col.ln_distro_number (i),
                                                 ln_blk_col.ln_dest_id (i),
                                                 ln_blk_col.ln_item_id (i),
                                                 1  --rec_order_sch.order_line_num
                                                  ,
                                                 ln_blk_col.ln_requested_qty (i),
                                                 'NI'
                                                );

                                  BEGIN
                                     UPDATE xxdo_inv_int_026_stg2 x26_2
                                        SET schedule_check = 'Y',
                                            x26_2.status = 9,
                                            x26_2.brand = lr_rec_stg2_brand,
                                            x26_2.error_message =
                                                          'ITEM NOT IN PRICE LIST'
                                      WHERE x26_2.ROWID = ln_blk_col.ln_rn (i);
                                  EXCEPTION
                                     WHEN OTHERS
                                     THEN
                                        fnd_file.put_line
                                           (fnd_file.LOG,
                                               'Error while Updating Schedule Check NI '
                                            || ln_blk_col.ln_distro_number (i)
                                            || ' - '
                                            || ln_blk_col.ln_dc_dest_id (i)
                                            || ' --- '
                                            || SQLERRM
                                           );
                                  END;
                               END;
                            END IF;*/
                            -- Commented End 1.7
                            ELSE
                                BEGIN
                                    UPDATE xxdo_inv_int_026_stg2 x26_2
                                       SET x26_2.status = 2, x26_2.brand = lr_rec_stg2_brand, x26_2.error_message = lv_error_message
                                     WHERE     (x26_2.seq_no) IN
                                                   (SELECT x26_2.seq_no
                                                      FROM xxdo_inv_int_026_stg2 x26_2_1, mtl_item_categories mic, mtl_categories_b mc,
                                                           mtl_category_sets_tl mcs
                                                     WHERE     mic.category_id =
                                                               mc.category_id
                                                           AND mcs.category_set_id =
                                                               mic.category_set_id
                                                           AND mic.inventory_item_id =
                                                               x26_2_1.item_id
                                                           AND mic.organization_id =
                                                               x26_2_1.dc_dest_id
                                                           AND UPPER (
                                                                   mcs.category_set_name) =
                                                               'INVENTORY'
                                                           --AND MC.STRUCTURE_ID = 101
                                                           AND mc.structure_id =
                                                               (SELECT structure_id
                                                                  FROM mtl_category_sets
                                                                 WHERE UPPER (
                                                                           category_set_name) =
                                                                       'INVENTORY')
                                                           --1.5
                                                           AND mcs.LANGUAGE =
                                                               'US'
                                                           AND x26_2_1.requested_qty >
                                                               0
                                                           AND x26_2_1.dc_dest_id =
                                                               lr_rec_stg2_dc_dest_id
                                                           AND x26_2_1.dest_id =
                                                               lr_rec_stg2_dc_dest_id
                                                           AND mc.segment1 =
                                                               lr_rec_stg2_brand
                                                           --  AND mc.segment2 = lr_rec_stg2_pgroup  --W.r.t 1.5
                                                           --  AND mc.segment3 = lr_rec_stg2_gender  --W.r.t 1.5
                                                           AND mc.segment2 =
                                                               lr_rec_stg2_gender
                                                           --W.r.t 1.5
                                                           AND mc.segment3 =
                                                               lr_rec_stg2_pgroup
                                                           --W.r.t 1.5
                                                           AND mc.segment4 =
                                                               lr_rec_stg2_class)
                                           AND x26_2.request_id =
                                               fnd_global.conc_request_id;
                                --
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                            'SQL Error Code :' || SQLCODE);
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                               'Error while Updating Status 2 for Dest_id - '
                                            || lr_rec_stg2_dest_id
                                            || ' AND dc_dest_id - '
                                            || lr_rec_stg2_dc_dest_id
                                            || '  :'
                                            || SQLERRM);
                                        /*   fnd_file.put_line
                                                (fnd_file.LOG,
                                                    'Error while Updating Status 2 for Dest_id - '
                                                 || lr_rec_stg2_dest_id
                                                 || ' AND dc_dest_id - '
                                                 || lr_rec_stg2_dc_dest_id
                                                 || '  :'
                                                 || SQLERRM
                                                ); */
                                        -- Commented for 2.0.

                                        -- START : 2.0.
                                        fnd_file.put_line (
                                            fnd_file.OUTPUT,
                                               'Error while Updating Status 2 for Dest_id - '
                                            || lr_rec_stg2_dest_id
                                            || ' AND dc_dest_id - '
                                            || lr_rec_stg2_dc_dest_id
                                            || '  :'
                                            || SQLERRM);
                                -- END : 2.0.
                                END;
                            END IF;

                            --------11
                            ln_batch   := ln_blk_col.ln_batch (i);

                            IF p_debug = 'Y'
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'ln_batch H1 ' || ln_batch);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'ln_org_ref_sequence H1 '
                                    || ln_org_ref_sequence);
                                v_curr_val   := 0;

                                SELECT xxdo_inv_int_026_seq.CURRVAL
                                  INTO v_curr_val
                                  FROM DUAL;

                                fnd_file.put_line (fnd_file.LOG,
                                                   'seq ' || v_curr_val);
                                fnd_file.put_line (fnd_file.LOG,
                                                   '====================');
                            END IF;
                        END IF;
                    -- EXIT WHEN cur_xxdo26_stg2_line%NOTFOUND;
                    END LOOP;

                    /* Query to fetch the count of lines for header */
                    BEGIN
                        ln_line_count   := 0;

                        SELECT COUNT (1)
                          INTO ln_line_count
                          FROM apps.oe_lines_iface_all
                         WHERE     error_flag IS NULL
                               AND request_id IS NULL
                               AND orig_sys_document_ref =
                                      'RMS'
                                   || '-'
                                   || lr_rec_stg2_dest_id
                                   || '-'
                                   || lr_rec_stg2_dc_dest_id
                                   || '-'
                                   || ln_org_ref_sequence
                               AND order_source_id = ln_order_source_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (fnd_file.LOG,
                                               'SQL Error Code :' || SQLCODE);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error while select count of lines for docunment referece - RMS'
                                || lr_rec_stg2_dest_id
                                || ' AND dc_dest_id - '
                                || lr_rec_stg2_dc_dest_id
                                || '-'
                                || ln_org_ref_sequence
                                || '  :'
                                || SQLERRM);
                    END;

                    IF ln_line_count <= 0
                    THEN
                        BEGIN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'delete '
                                || 'RMS'
                                || '-'
                                || lr_rec_stg2_dest_id
                                || '-'
                                || lr_rec_stg2_dc_dest_id
                                || '-'
                                || ln_org_ref_sequence);

                            DELETE FROM
                                apps.oe_headers_iface_all
                                  WHERE     orig_sys_document_ref =
                                               'RMS'
                                            || '-'
                                            || lr_rec_stg2_dest_id
                                            || '-'
                                            || lr_rec_stg2_dc_dest_id
                                            || '-'
                                            || ln_org_ref_sequence
                                        AND error_flag IS NULL
                                        AND request_id IS NULL
                                        AND order_source_id =
                                            ln_order_source_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'SQL Error Code :' || SQLCODE);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Error while deleting header line for docunment referece - RMS'
                                    || lr_rec_stg2_dest_id
                                    || ' AND dc_dest_id - '
                                    || lr_rec_stg2_dc_dest_id
                                    || '-'
                                    || ln_org_ref_sequence
                                    || '  :'
                                    || SQLERRM);
                        END;
                    END IF;
                END LOOP;

                CLOSE cur_xxdo26_stg2;
            END LOOP;
        END LOOP;

        /*COMMITting The Inserts and Updates*/
        COMMIT;
        apps.xxdo_po_import_exception_rep.xxdo_po_import_excp_rep_proc (
            SYSDATE,
            p_region);
        /*Calling Order Import Program*/
        call_order_import;
        /*Calling Procedure to Print Audit Report in the Concurrent Request Output*/
        print_audit_report;
    END insert_oe_iface_tables_th;
END xxdo_om_int_026_stg_pkg;
/


GRANT EXECUTE ON APPS.XXDO_OM_INT_026_STG_PKG TO SOA_INT
/
