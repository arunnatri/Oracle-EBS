--
-- XXDO_PO_EXTRACT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:04 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_PO_EXTRACT_PKG"
AS
    /***********************************************************************************************
       $Header:  xxdo_po_extract_pkg.sql   1.0    2014/07/07    10:00:00   Infosys $
       **********************************************************************************************
       */
    -- ***************************************************************************
    --                (c) Copyright Deckers Outdoor Corp.
    --                    All rights reserved
    -- ***************************************************************************
    /* NAME:       xxdo_po_extract_pkg
  --
  -- Description  :  This is package Body for EBS to WMS to extract PO data
  --
  -- DEVELOPMENT and MAINTENANCE HISTORY

     Ver        Date        Author           Description
     ---------  ----------  ---------------  ------------------------------------
     1.0        7/7/2014      Infosys        Created initial version.
     1.1       11/08/2015     Infosys        Added Substring for all the values which are gettign inserted into the staging table
                                                                           ; Identified by TRIM_DATA
     1.2      11/08/2015     Infosys        Included logic to trigger the XML generation program if atlease one header record
                                              is inserted in the staging table; Identified by LAUNCH_XML
     1.3       11/08/2015     Infosys         LAST run Date modified to take current date too ; Identified by LAST_RUN_DATE
  ******************************************************************************/
    g_num_user_id        NUMBER := fnd_global.user_id;
    g_num_login_id       NUMBER := fnd_global.login_id;
    g_dte_current_date   DATE := SYSDATE;
    g_num_request_id     NUMBER := fnd_global.conc_request_id;
    c_num_debug          NUMBER := 0;

    --------------------------------------------------------------------------------
    -- Procedure  : msg
    -- Description: procedure to print debug messages
    --------------------------------------------------------------------------------
    PROCEDURE msg (in_var_message IN VARCHAR2)
    IS
    BEGIN
        IF c_num_debug = 1
        THEN
            fnd_file.put_line (fnd_file.LOG, in_var_message);
        END IF;
    END msg;

    -- ***********************************************************************************
    -- Procedure/Function Name  :  wait_for_request
    --
    -- Description              :  The purpose of this procedure is to make the
    --                             parent request to wait untill unless child
    --                             request completes
    --
    -- parameters               :  in_num_parent_req_id  in : Parent Request Id
    --
    -- Return/Exit              :  N/A
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2009/08/03    Infosys            12.0.1    Initial Version
    -- ***************************************************************************
    PROCEDURE wait_for_request (in_num_parent_req_id IN NUMBER)
    AS
        ------------------------------
        --Local Variable Declaration--
        ------------------------------
        ln_count                NUMBER := 0;
        ln_num_intvl            NUMBER := 5;
        ln_data_set_id          NUMBER := NULL;
        ln_num_max_wait         NUMBER := 120000;
        lv_chr_phase            VARCHAR2 (250) := NULL;
        lv_chr_status           VARCHAR2 (250) := NULL;
        lv_chr_dev_phase        VARCHAR2 (250) := NULL;
        lv_chr_dev_status       VARCHAR2 (250) := NULL;
        lv_chr_msg              VARCHAR2 (250) := NULL;
        lb_bol_request_status   BOOLEAN;

        ------------------------------------------
        --Cursor to fetch the child request id's--
        ------------------------------------------
        CURSOR cur_child_req_id IS
            SELECT request_id
              FROM fnd_concurrent_requests
             WHERE parent_request_id = in_num_parent_req_id;
    ---------------
    --Begin Block--
    ---------------
    BEGIN
        ------------------------------------------------------
        --Loop for each child request to wait for completion--
        ------------------------------------------------------
        FOR rec_child_req_id IN cur_child_req_id
        LOOP
            --Wait for request to complete
            lb_bol_request_status   :=
                fnd_concurrent.wait_for_request (rec_child_req_id.request_id,
                                                 ln_num_intvl,
                                                 ln_num_max_wait,
                                                 lv_chr_phase, -- out parameter
                                                 lv_chr_status, -- out parameter
                                                 lv_chr_dev_phase,
                                                 -- out parameter
                                                 lv_chr_dev_status,
                                                 -- out parameter
                                                 lv_chr_msg   -- out parameter
                                                           );

            IF    UPPER (lv_chr_dev_status) = 'WARNING'
               OR UPPER (lv_chr_dev_status) = 'ERROR'
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error in submitting the request, request_id = '
                    || rec_child_req_id.request_id);
                fnd_file.put_line (fnd_file.LOG,
                                   'Error,lv_chr_phase =' || lv_chr_phase);
                fnd_file.put_line (fnd_file.LOG,
                                   'Error,lv_chr_status =' || lv_chr_status);
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Error,lv_chr_dev_status =' || lv_chr_dev_status);
                fnd_file.put_line (fnd_file.LOG,
                                   'Error,lv_chr_msg =' || lv_chr_msg);
            ELSE
                fnd_file.put_line (fnd_file.LOG, 'Request completed');
                fnd_file.put_line (
                    fnd_file.LOG,
                    'request_id = ' || rec_child_req_id.request_id);
                fnd_file.put_line (fnd_file.LOG,
                                   'lv_chr_msg =' || lv_chr_msg);
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Error:' || SQLERRM);
    END wait_for_request;



    /*
    ***********************************************************************************
     Procedure/Function Name  :  Copy Files
     Description              :  Copy files to out directory
    **********************************************************************************

    */
    PROCEDURE copy_files (in_num_request_id IN NUMBER, in_chr_entity IN VARCHAR2, in_chr_warehouse IN VARCHAR2
                          , retcode OUT VARCHAR2, errbuf OUT VARCHAR2)
    IS
        l_num_request_id      NUMBER;
        l_chr_transfer_flag   VARCHAR2 (1);
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Start of copy files');

        SELECT attribute8
          INTO l_chr_transfer_flag
          FROM fnd_lookup_values
         WHERE     lookup_type LIKE 'XXDO_WMS_INTERFACES_SETUP'
               AND language = 'US'
               AND enabled_flag = 'Y'
               AND lookup_code =
                   DECODE (in_chr_entity,
                           'PO', 'XXDO_PO_EXT',
                           'PICK', 'XXDO_PICK_PROC',
                           'RMA', 'XXONT_RMA_PROC',
                           'ASN', 'XXDOASNE',
                           'REQRES', 'XXDO_REQ_RESP');

        IF l_chr_transfer_flag = 'Y'
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Copy flag is Yes');

            l_num_request_id   :=
                fnd_request.submit_request ('XXDO', 'XXDOCOPYFILES', NULL,
                                            NULL, FALSE, in_chr_warehouse,
                                            in_num_request_id, in_chr_entity);
            COMMIT;

            wait_for_request (g_num_request_id);
        ELSE
            fnd_file.put_line (fnd_file.LOG, 'Copy flag is No');
        END IF;

        fnd_file.put_line (fnd_file.LOG, 'End of copy files');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Unexpected error in copy files :' || SQLERRM);
            retcode   := '2';
            errbuf    := 'Erorr in file copy';
    END copy_files;


    -- ***************************************************************************
    --                (c) Copyright Deckers
    --                    All rights reserved
    -- ***************************************************************************
    --
    -- Package Name   :   xxdo_po_extract_pkg
    -- PROCEDURE Name :   extract_po_stage_data
    -- Description    :  This is PROCEDURE Body to extract PO data
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- DATE          Author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    --
    -- 2014/08/05    Infosys            12.0.6   Initial
    -- 2014/12/23    Infosys            12.2.3   Modified for BT Remediation
    -- ***************************************************************************
    PROCEDURE extract_po_stage_data (p_in_num_organization   IN     NUMBER,
                                     p_in_var_ponumber       IN     VARCHAR2,
                                     p_last_run_date         IN     DATE,
                                     p_in_var_source         IN     VARCHAR2,
                                     p_in_var_dest           IN     VARCHAR2,
                                     p_in_var_purge_days     IN     VARCHAR2,
                                     p_out_var_retcode          OUT VARCHAR2,
                                     p_out_var_errbuf           OUT VARCHAR2)
    IS
        CURSOR cur_org IS
            SELECT organization_id
              FROM mtl_parameters mp
             WHERE     mp.organization_id =
                       NVL (p_in_num_organization, mp.organization_id)
                   AND mp.organization_code IN
                           (SELECT lookup_code
                              FROM fnd_lookup_values fvl
                             WHERE     fvl.lookup_type = 'XXONT_WMS_WHSE'
                                   AND NVL (LANGUAGE, USERENV ('LANG')) =
                                       USERENV ('LANG')
                                   AND fvl.enabled_flag = 'Y');

        CURSOR cur_po_hdr (in_num_wh_id IN NUMBER)
        IS
            SELECT DISTINCT poh.po_header_id
              FROM po_headers poh, po_lines pol, po_line_locations pll
             WHERE     1 = 1
                   AND poh.segment1 = NVL (p_in_var_ponumber, poh.segment1)
                   AND poh.po_header_id = pol.po_header_id
                   AND pol.po_line_id = pll.po_line_id
                   AND pll.ship_to_organization_id = in_num_wh_id
                   AND poh.approved_flag = 'Y'
                   AND (p_in_var_ponumber IS NOT NULL OR poh.last_update_date >= p_last_run_date OR pol.last_update_date >= p_last_run_date /*LAST_RUN_DATE*/
                                                                                                                                            OR pll.last_update_date >= p_last_run_date /*LAST_RUN_DATE*/
                                                                                                                                                                                      )
                   AND pll.quantity_received = 0;

        CURSOR cur_po_data (in_num_wh_id       IN NUMBER,
                            in_num_header_id   IN NUMBER)
        IS
              SELECT mp.organization_code warehouse_code, poh.segment1 po_number, poh.closed_code status,
                     poh.type_lookup_code TYPE, poh.creation_date create_date, aps.segment1 vendor_code,
                     aps.vendor_name vendor_name, poh.comments comments, apss.vendor_site_code factory_code,
                     apss.vendor_site_code_alt factory_name, pol.line_num line_number, /*commented for BT Remediation
                                                                                          msi.segment1
                                                                                       || '-'
                                                                                       || msi.segment2
                                                                                       || '-'
                                                                                       || msi.segment3 item_number,
                                                                                       */
                                                                                       msi.concatenated_segments item_number, --Added for BT Remediation
                     (poll.quantity - poll.quantity_cancelled) qty, pol.vendor_product_num vendor_item_number, --TO_DATE (poh.attribute3, 'DD-MON-YYYY') confirm_xf_date,                commented because of date format
                                                                                                               TO_CHAR (TO_DATE (poh.attribute3, 'YYYY/MM/DD HH24:MI:SS')) confirm_xf_date, --added to correct the date format
                     pav.agent_name originator, pol.unit_meas_lookup_code order_uom, poll.closed_code line_status
                FROM mtl_parameters mp, mtl_system_items_kfv msi, --Replaced table mtl_system_items_b with mtl_system_items_kfv for BT Remediation
                                                                  po_headers poh,
                     ap_suppliers aps, ap_supplier_sites apss, po_lines pol,
                     po_line_locations poll, po_agents_v pav
               WHERE     1 = 1
                     AND mp.organization_id = in_num_wh_id
                     AND poh.po_header_id = in_num_header_id
                     AND poh.po_header_id = pol.po_header_id
                     AND pol.po_line_id = poll.po_line_id
                     AND poll.ship_to_organization_id = mp.organization_id
                     AND poh.vendor_id = aps.vendor_id
                     AND poh.vendor_site_id = apss.vendor_site_id
                     AND pav.agent_id = poh.agent_id
                     AND pol.item_id = msi.inventory_item_id
                     AND msi.organization_id = mp.organization_id
            ORDER BY mp.organization_code, poh.segment1, pol.line_num,
                     poll.line_location_id;

        l_chr_commit          VARCHAR2 (1);
        l_var_print_msg       VARCHAR (500);
        lv_print_msg          VARCHAR (500);
        l_chr_err_buf         VARCHAR (500);
        lv_request_id         NUMBER;
        lv_phase              VARCHAR2 (20);
        lv_status             VARCHAR2 (20);
        lv_dev_phase          VARCHAR2 (20);
        lv_dev_status         VARCHAR2 (20);
        lv_prev_req_status    BOOLEAN;
        lv_conc_message       VARCHAR2 (4000);
        lv_msg_out            VARCHAR2 (2000);
        lv_interval           NUMBER := 30;
        lv_max_wait           NUMBER := 900;
        lv_message            VARCHAR2 (500);
        lv_hdr_count          NUMBER;
        lv_line_count         NUMBER;
        lv_number             NUMBER;
        lv_fact_count         NUMBER;
        l_var_source_type     VARCHAR2 (10) := 'ORDER';
        r_do_po_hdr_stg       xxdo_po_hdr_stg%ROWTYPE;
        r_do_po_factory_stg   xxdo_po_factory_stg%ROWTYPE;
        r_do_po_detail_stg    xxdo_po_detail_stg%ROWTYPE;
        l_num_count           NUMBER := 0;
        l_chr_warehouse       VARCHAR2 (10);
        l_num_po_num          NUMBER;
        lv_number_hdr         NUMBER;
        lv_number_fact        NUMBER;
        lv_number_dtl         NUMBER;
        l_num_header_id       NUMBER;
        l_num_factory_id      NUMBER;
        l_num_line_id         NUMBER;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Extracting PO detail');
        l_chr_commit      := 'N';
        l_chr_warehouse   := '-ZZ';
        l_num_po_num      := -999;
        l_chr_commit      := 'N';

        FOR cur_org_rec IN cur_org
        LOOP
            FOR cur_po_hdr_rec IN cur_po_hdr (cur_org_rec.organization_id)
            LOOP
                FOR cur_po_data_rec
                    IN cur_po_data (cur_org_rec.organization_id,
                                    cur_po_hdr_rec.po_header_id)
                LOOP
                    msg ('Warehouse: ' || cur_po_data_rec.warehouse_code);
                    msg ('PO Number: ' || cur_po_data_rec.po_number);
                    msg ('Line Number: ' || cur_po_data_rec.line_number);

                    IF    l_chr_warehouse <> cur_po_data_rec.warehouse_code
                       OR l_num_po_num <> cur_po_data_rec.po_number
                    THEN
                        IF l_chr_commit = 'Y'
                        THEN
                            COMMIT;
                            /*Commit previous header if that is already inserted */
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'commmit records for warehouse, po number: '
                                || l_chr_warehouse
                                || '  '
                                || l_num_po_num);
                        ELSIF l_num_po_num <> -999
                        THEN
                            ROLLBACK;
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'rollback records for warehouse, po number: '
                                || l_chr_warehouse
                                || '  '
                                || l_num_po_num);
                        END IF;

                        l_chr_commit       := 'Y';
                        /* this flag will be set to N if any insertion fails for this header */
                        fnd_file.put_line (fnd_file.LOG,
                                           'New header processing for : ');
                        /* records will be committed only when all records are successfully inserted for a given return order */
                        l_chr_warehouse    := cur_po_data_rec.warehouse_code;
                        l_num_po_num       := cur_po_data_rec.po_number;
                        l_num_count        := 0;
                        fnd_file.put_line (fnd_file.LOG,
                                           'warehouse :' || l_chr_warehouse);
                        fnd_file.put_line (fnd_file.LOG,
                                           'PO  :' || l_num_po_num);

                        UPDATE xxdo_po_hdr_stg
                           SET process_status = 'OBSOLETE', last_update_date = SYSDATE, last_updated_by = g_num_user_id,
                               last_update_login = g_num_login_id
                         WHERE     po_number = l_num_po_num
                               AND warehouse_code = l_chr_warehouse
                               AND process_status <> 'OBSOLETE';

                        l_num_count        := SQL%ROWCOUNT;

                        UPDATE xxdo_po_factory_stg
                           SET process_status = 'OBSOLETE', last_update_date = SYSDATE, last_updated_by = g_num_user_id,
                               last_update_login = g_num_login_id
                         WHERE     po_number = l_num_po_num
                               AND warehouse_code = l_chr_warehouse
                               AND process_status <> 'OBSOLETE';

                        UPDATE xxdo_po_detail_stg
                           SET process_status = 'OBSOLETE', last_update_date = SYSDATE, last_updated_by = g_num_user_id,
                               last_update_login = g_num_login_id
                         WHERE     po_number = l_num_po_num
                               AND warehouse_code = l_chr_warehouse
                               AND process_status <> 'OBSOLETE';

                        msg ('updated obsolete status');
                        msg ('Inserting new header record');
                        l_num_header_id    := 0;
                        l_num_factory_id   := 0;

                        SELECT xxdo_po_hdr_s.NEXTVAL, xxdo_po_factory_s.NEXTVAL
                          INTO l_num_header_id, l_num_factory_id
                          FROM DUAL;

                        BEGIN
                            INSERT INTO xxdo_po_hdr_stg (header_id, warehouse_code, po_number, status, TYPE, create_date, vendor_code, vendor_name, comments, process_status, request_id, creation_date, created_by, last_update_date, last_updated_by, last_update_login, SOURCE, destination
                                                         , record_type)
                                     VALUES (
                                                l_num_header_id,
                                                SUBSTR (
                                                    cur_po_data_rec.warehouse_code,
                                                    1,
                                                    10),         /*TRIM_DATA*/
                                                SUBSTR (
                                                    cur_po_data_rec.po_number,
                                                    1,
                                                    30),         /*TRIM_DATA*/
                                                DECODE (
                                                    cur_po_data_rec.status,
                                                    'CLOSED', 'C',
                                                    'OPEN', 'O'),
                                                SUBSTR (cur_po_data_rec.TYPE,
                                                        1,
                                                        30),     /*TRIM_DATA*/
                                                cur_po_data_rec.create_date,
                                                SUBSTR (
                                                    cur_po_data_rec.vendor_code,
                                                    1,
                                                    10),         /*TRIM_DATA*/
                                                SUBSTR (
                                                    cur_po_data_rec.vendor_name,
                                                    1,
                                                    50),         /*TRIM_DATA*/
                                                SUBSTR (
                                                    cur_po_data_rec.comments,
                                                    1,
                                                    1000),
                                                'NEW',
                                                g_num_request_id,
                                                SYSDATE,
                                                g_num_user_id,
                                                SYSDATE,
                                                g_num_user_id,
                                                g_num_login_id,
                                                p_in_var_source,
                                                p_in_var_dest,
                                                DECODE (l_num_count,
                                                        0, 'NEW',
                                                        'UPDATE'));
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                p_out_var_retcode   := 2;
                                p_out_var_errbuf    :=
                                       'Error occured for PO header insert '
                                    || SQLERRM;
                                fnd_file.put_line (fnd_file.LOG,
                                                   p_out_var_errbuf);
                                l_chr_commit        := 'N';
                        END;

                        msg ('Processing factory for PO');
                        msg ('Inserting factory records');

                        BEGIN
                            INSERT INTO xxdo_po_factory_stg (
                                            header_id,
                                            record_id,
                                            warehouse_code,
                                            po_number,
                                            vendor_code,
                                            factory_code,
                                            factory_name,
                                            process_status,
                                            request_id,
                                            creation_date,
                                            created_by,
                                            last_update_date,
                                            last_updated_by,
                                            last_update_login,
                                            SOURCE,
                                            destination,
                                            record_type)
                                 VALUES (l_num_header_id, l_num_factory_id, SUBSTR (cur_po_data_rec.warehouse_code, 1, 10), /*TRIM_DATA*/
                                                                                                                            SUBSTR (cur_po_data_rec.po_number, 1, 30), /*TRIM_DATA*/
                                                                                                                                                                       SUBSTR (cur_po_data_rec.vendor_code, 1, 10), /*TRIM_DATA*/
                                                                                                                                                                                                                    SUBSTR (cur_po_data_rec.factory_code, 1, 20), /*TRIM_DATA*/
                                                                                                                                                                                                                                                                  SUBSTR (cur_po_data_rec.factory_name, 1, 50), /*TRIM_DATA*/
                                                                                                                                                                                                                                                                                                                'NEW', g_num_request_id, SYSDATE, g_num_user_id, SYSDATE, g_num_user_id, g_num_login_id, p_in_var_source
                                         , p_in_var_dest, 'NEW');
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                p_out_var_retcode   := 2;
                                p_out_var_errbuf    :=
                                       'Error occured for PO factory insert '
                                    || SQLERRM;
                                fnd_file.put_line (fnd_file.LOG,
                                                   p_out_var_errbuf);
                                l_chr_commit        := 'N';
                        END;
                    END IF;                     /* end of header processing */

                    msg ('Processing deatils for PO');
                    msg ('Inserting detail records');
                    l_num_line_id   := 0;

                    SELECT xxdo_po_detail_s.NEXTVAL
                      INTO l_num_line_id
                      FROM DUAL;

                    BEGIN
                        INSERT INTO xxdo_po_detail_stg (header_id, line_id, warehouse_code, po_number, line_number, item_number, qty, vendor_item_number, confirm_xf_date, originator, order_uom, line_status, process_status, request_id, creation_date, created_by, last_update_date, last_updated_by, last_update_login, SOURCE, destination
                                                        , record_type)
                             VALUES (l_num_header_id, l_num_line_id, SUBSTR (cur_po_data_rec.warehouse_code, 1, 10), /*TRIM_DATA*/
                                                                                                                     SUBSTR (cur_po_data_rec.po_number, 1, 30), /*TRIM_DATA*/
                                                                                                                                                                SUBSTR (cur_po_data_rec.line_number, 1, 20), /*TRIM_DATA*/
                                                                                                                                                                                                             SUBSTR (cur_po_data_rec.item_number, 1, 30), /*TRIM_DATA*/
                                                                                                                                                                                                                                                          cur_po_data_rec.qty, SUBSTR (cur_po_data_rec.vendor_item_number, 1, 30), /*TRIM_DATA*/
                                                                                                                                                                                                                                                                                                                                   cur_po_data_rec.confirm_xf_date, SUBSTR (cur_po_data_rec.originator, 1, 25), /*TRIM_DATA*/
                                                                                                                                                                                                                                                                                                                                                                                                                SUBSTR (cur_po_data_rec.order_uom, 1, 10), /*TRIM_DATA*/
                                                                                                                                                                                                                                                                                                                                                                                                                                                           DECODE (cur_po_data_rec.line_status,  'CLOSED', 'C',  'OPEN', 'O'), 'NEW', g_num_request_id, SYSDATE, g_num_user_id, SYSDATE, g_num_user_id, g_num_login_id, p_in_var_source, p_in_var_dest
                                     , 'NEW');
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            p_out_var_retcode   := 2;
                            p_out_var_errbuf    :=
                                   'Error occured for PO detail  insert '
                                || SQLERRM;
                            fnd_file.put_line (fnd_file.LOG,
                                               p_out_var_errbuf);
                            l_chr_commit        := 'N';
                    END;
                END LOOP;
            END LOOP;
        END LOOP;

        IF l_chr_commit = 'Y'
        THEN
            COMMIT;       /* commit last header if that is already inserted */
            fnd_file.put_line (
                fnd_file.LOG,
                   'commmit records for warehouse, order number: '
                || l_chr_warehouse
                || '  '
                || l_num_po_num);
        ELSIF l_num_po_num <> -999
        THEN
            ROLLBACK;
            fnd_file.put_line (
                fnd_file.LOG,
                   'rollback records for warehouse, order number: '
                || l_chr_warehouse
                || '  '
                || l_num_po_num);
        END IF;

        fnd_file.put_line (fnd_file.LOG, 'PO detail extraction completed');
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_var_errbuf    := 'Unexpected error: ' || SQLERRM;
            ROLLBACK;
            p_out_var_retcode   := 2;
            fnd_file.put_line (fnd_file.LOG, p_out_var_errbuf);
    END extract_po_stage_data;

    PROCEDURE update_process_status (in_chr_warehouse VARCHAR2, in_chr_from_status VARCHAR2, in_chr_to_status VARCHAR2)
    IS
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Start of update process status');
        msg ('warehouse: ' || in_chr_warehouse);
        msg ('from status: ' || in_chr_from_status);
        msg ('to status: ' || in_chr_to_status);

        UPDATE xxdo_po_hdr_stg
           SET process_status = in_chr_to_status, last_update_date = SYSDATE, last_updated_by = g_num_user_id,
               last_update_login = g_num_login_id
         WHERE     process_status = in_chr_from_status
               AND request_id = g_num_request_id
               AND warehouse_code = in_chr_warehouse;

        UPDATE xxdo_po_factory_stg
           SET process_status = in_chr_to_status, last_update_date = SYSDATE, last_updated_by = g_num_user_id,
               last_update_login = g_num_login_id
         WHERE     process_status = in_chr_from_status
               AND request_id = g_num_request_id
               AND warehouse_code = in_chr_warehouse;

        UPDATE xxdo_po_detail_stg
           SET process_status = in_chr_to_status, last_update_date = SYSDATE, last_updated_by = g_num_user_id,
               last_update_login = g_num_login_id
         WHERE     process_status = in_chr_from_status
               AND request_id = g_num_request_id
               AND warehouse_code = in_chr_warehouse;

        fnd_file.put_line (fnd_file.LOG, 'end of update process status');
        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected error in update process status for status '
                || in_chr_to_status
                || ' '
                || SQLERRM);
            ROLLBACK;
    END update_process_status;

    --***************************************************************************
    --                (c) Copyright Deckers
    --                     All rights reserved
    -- ***************************************************************************
    --
    -- Package Name:  xxdo_ont_po_extract_pkg
    -- PROCEDURE Name :main_extract
    -- Description:  This PROCEDURE to call purchase order

    -- DEVELOPMENT MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/30/06   Infosys              12.0.0    Initial version

    -- ***************************************************************************
    PROCEDURE main_extract (p_out_var_errbuf OUT VARCHAR2, p_out_var_retcode OUT VARCHAR2, p_organization IN NUMBER, p_po_number IN VARCHAR2, p_debug_level IN VARCHAR2, p_source IN VARCHAR2
                            , p_dest IN VARCHAR2, p_purge_days IN NUMBER)
    IS
        CURSOR cur_org (in_chr_status VARCHAR2)
        IS
            SELECT DISTINCT warehouse_code, request_id
              FROM xxdo_po_hdr_stg
             WHERE     process_status = in_chr_status
                   AND request_id = g_num_request_id;

        l_chr_instance        VARCHAR2 (20) := NULL;
        lv_request_id         NUMBER;
        l_var_print_msg       VARCHAR (500);
        c_dte_sysdate         DATE := SYSDATE;
        lv_print_msg          VARCHAR (500);
        l_chr_err_buf         VARCHAR (500);
        lv_phase              VARCHAR2 (20);
        lv_status             VARCHAR2 (20);
        lv_dev_phase          VARCHAR2 (20);
        lv_dev_status         VARCHAR2 (20);
        lv_prev_req_status    BOOLEAN;
        lv_conc_message       VARCHAR2 (4000);
        lv_msg_out            VARCHAR2 (2000);
        lv_interval           NUMBER := 30;
        lv_max_wait           NUMBER := 900;
        lv_message            VARCHAR2 (500);
        lv_hdr_count          NUMBER;
        lv_fact_count         NUMBER;
        lv_line_count         NUMBER;
        lv_latest_date        DATE;
        l_chr_ret_code        NUMBER;
        l_chr_status          VARCHAR (5) := NULL;
        lv_pick_rel_req       NUMBER;
        lv_del_order_no       NUMBER;
        l_dte_last_run_time   DATE;
        l_dte_next_run_time   DATE;
        l_num_conc_prog_id    NUMBER := fnd_global.conc_program_id;
        l_num_rec_count       NUMBER := 0;
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
               'Main program started for PO interface:'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
        fnd_file.put_line (fnd_file.LOG, 'Input Parameters:');
        fnd_file.put_line (fnd_file.LOG,
                           'Organization :- ' || p_organization);
        fnd_file.put_line (fnd_file.LOG, 'Po Number :- ' || p_po_number);
        fnd_file.put_line (fnd_file.LOG, 'Source :- ' || p_source);
        fnd_file.put_line (fnd_file.LOG, 'Destination :- ' || p_dest);
        fnd_file.put_line (fnd_file.LOG, 'Purge Days :- ' || p_purge_days);
        p_out_var_errbuf      := NULL;
        p_out_var_retcode     := '0';

        IF p_debug_level = 'Y'
        THEN
            c_num_debug   := 1;
        ELSE
            c_num_debug   := 0;
        END IF;

        -- Get the interface setup
        BEGIN
            l_dte_last_run_time   :=
                xxdo_ont_wms_intf_util_pkg.get_last_run_time (
                    p_in_chr_interface_prgm_name => NULL);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Last run time : '
                || TO_CHAR (l_dte_last_run_time, 'DD-Mon-RRRR HH24:MI:SS'));
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_var_errbuf   :=
                    'Unable to get the inteface setup due to ' || SQLERRM;
                fnd_file.put_line (fnd_file.LOG, p_out_var_errbuf);
        END;

        l_dte_next_run_time   := SYSDATE;

        DELETE FROM xxdo_po_hdr_stg
              WHERE last_update_date < (SYSDATE - p_purge_days);

        COMMIT;
        msg ('No of rows purged from xxdo_po_hdr_stg ' || SQL%ROWCOUNT);

        DELETE FROM xxdo_po_factory_stg
              WHERE last_update_date < (SYSDATE - p_purge_days);

        COMMIT;
        msg ('No of rows purged from xxdo_po_factory_stg ' || SQL%ROWCOUNT);

        DELETE FROM xxdo_po_detail_stg
              WHERE last_update_date < (SYSDATE - p_purge_days);

        COMMIT;
        msg ('No of rows purged from xxdo_po_detail_stg ' || SQL%ROWCOUNT);
        /*Call Extraction program*/
        extract_po_stage_data (p_organization, p_po_number, l_dte_last_run_time, p_source, p_dest, p_purge_days
                               , l_chr_ret_code, l_chr_err_buf);

        IF l_chr_ret_code = 1
        THEN
            p_out_var_retcode   := 1;
            p_out_var_retcode   := 'WARNING';
        END IF;

        /* update the last run details if the program is not run with specific inputs */
        IF p_po_number IS NULL AND p_organization IS NULL
        THEN
            -- updating the interface with next run time
            BEGIN
                xxdo_ont_wms_intf_util_pkg.set_last_run_time (
                    p_in_chr_interface_prgm_name   => NULL,
                    p_in_dte_run_time              => l_dte_next_run_time);
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_out_var_errbuf   :=
                           'Unexpected error while updating the next run time : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_out_var_errbuf);
            END;
        END IF;

        fnd_file.put_line (fnd_file.LOG,
                           'Calling Generate XML concurrent program');

        /*IF l_chr_err_buf IS NULL
            THEN*/

        /*LAUNCH_XML*/

        SELECT COUNT (*)
          INTO l_num_rec_count
          FROM xxdo_po_hdr_stg
         WHERE request_id = g_num_request_id AND process_status = 'NEW';

        IF l_num_rec_count >= 1
        THEN
            /*LAUNCH_XML - END*/
            SELECT NAME INTO l_chr_instance FROM v$database;

            FOR cur_org_rec IN cur_org ('NEW')
            LOOP
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Warehouse  : ' || cur_org_rec.warehouse_code);
                update_process_status (cur_org_rec.warehouse_code,
                                       'NEW',
                                       'INPROCESS');
                lv_request_id   :=
                    fnd_request.submit_request ('PO',
                                                'XXDO_PO_DATA',
                                                NULL,
                                                NULL,
                                                FALSE,
                                                cur_org_rec.warehouse_code,
                                                l_chr_instance,
                                                g_num_request_id);
                COMMIT;
                fnd_file.put_line (fnd_file.LOG,
                                   'Child request ID: ' || lv_request_id);
            END LOOP;
        END IF;

        COMMIT;
        /* wait for child program completion - below procesure will wait till all child programs are completed */
        wait_for_request (g_num_request_id);
        fnd_file.put_line (fnd_file.LOG, 'Updating staging table status');
        /* update staging table entries as processed */
        fnd_file.put_line (fnd_file.LOG,
                           'Updating status for staging records');

        FOR cur_org_rec IN cur_org ('INPROCESS')
        LOOP
            l_chr_status    := '-z';
            fnd_file.put_line (fnd_file.LOG,
                               'Warehouse' || cur_org_rec.warehouse_code);

            lv_request_id   := 0;

            BEGIN
                SELECT status_code, request_id
                  INTO l_chr_status, lv_request_id
                  FROM fnd_concurrent_requests
                 WHERE     parent_request_id = g_num_request_id
                       AND argument1 = cur_org_rec.warehouse_code;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_chr_status    := '-z';
                    lv_request_id   := 0;
            END;

            fnd_file.put_line (fnd_file.LOG, ' status code' || l_chr_status);
            msg ('child request id ' || lv_request_id);

            IF l_chr_status IN ('C', 'G')
            THEN
                update_process_status (cur_org_rec.warehouse_code,
                                       'INPROCESS',
                                       'PROCESSED');

                copy_files (lv_request_id, 'PO', cur_org_rec.warehouse_code,
                            p_out_var_retcode, p_out_var_errbuf);
            ELSE
                update_process_status (cur_org_rec.warehouse_code,
                                       'INPROCESS',
                                       'ERROR');
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error occured in Main extract at step '
                || lv_print_msg
                || '-'
                || SQLERRM);
            p_out_var_retcode   := 2;
            p_out_var_errbuf    := SQLERRM;
    END main_extract;
END xxdo_po_extract_pkg;
/
