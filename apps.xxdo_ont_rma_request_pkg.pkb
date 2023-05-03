--
-- XXDO_ONT_RMA_REQUEST_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:25 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_ONT_RMA_REQUEST_PKG"
AS
    /*
    **********************************************************************************************
    $Header:  xxdo_ont_rma_request_pkg_b.sql   1.0    2014/07/31   10:00:00   Infosys $
    **********************************************************************************************
    */
    -- ***************************************************************************
    --                (c) Copyright Deckers Outdoor Corp.
    --                    All rights reserved
    -- ***************************************************************************
    --
    -- Package Name :  xxdo_ont_rma_request_pkg
    --deckers123!

    -- Description  :  This is package  for WMS to EBS UnExpected Return Request Inbound Interface
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- Date          Author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 18-Aug-2014    Infosys            1.0       Created
    -- 02-Jan-2015    Infosys            2.0       Modified for BT Remediation
    -- 03-Feb-2015    Infosys            2.1       Addtion of  Archive Logic(PURGE_ARCHIVE)  , CR - DAMAGE_CODE,FACTORY_CODE,PROD_CODE
    --  ,RMA_NUMBER
    -- 15-Apr-2015    Infosys            2.2       Single Org OU_BUG Issue
    -- ***************************************************************************

    --------------------------
    --Declare global variables
    --
    --------------------------------------------------------------------------------
    -- PROCEDURE  : msg
    -- Description: PROCEDURE to print debug messages
    --------------------------------------------------------------------------------
    g_package_name   VARCHAR2 (240) := 'XXDO_ONT_RMA_REQUEST_PKG';

    PROCEDURE msg (in_chr_message VARCHAR2)
    IS
    BEGIN
        IF g_num_debug = 1
        THEN
            fnd_file.put_line (fnd_file.LOG, in_chr_message);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Unexpected Error: ' || SQLERRM);
    END;

    /*Commented for version 1.1 start*/
                                   /*
   PROCEDURE purge_data (p_purge IN VARCHAR2)
   IS
      lv_procedure   VARCHAR2 (100) := '.PURGE_DATA';
   BEGIN
      DELETE FROM xxdo.xxdo_ont_rma_hdr_stg
            WHERE last_update_date < (SYSDATE - p_purge);

      COMMIT;
      msg ('No of rows purged from XXDO_ONT_RMA_HDR_STG ' || SQL%ROWCOUNT);

      DELETE FROM xxdo.xxdo_ont_rma_line_stg
            WHERE last_update_date < (SYSDATE - p_purge);

      COMMIT;
      msg ('No of rows purged from XXDO_ONT_RMA_LINE_STG ' || SQL%ROWCOUNT);

      DELETE FROM xxdo.xxdo_ont_rma_line_serl_stg
            WHERE last_update_date < (SYSDATE - p_purge);

      COMMIT;
      msg (   'No of rows purged from XXDO_ONT_RMA_LINE_SERL_STG '
           || SQL%ROWCOUNT
          );

      DELETE FROM xxdo.xxdo_ont_rma_xml_stg
            WHERE last_update_date < (SYSDATE - p_purge);

      COMMIT;
      msg ('No of rows purged from XXDO_ONT_RMA_XML_STG ' || SQL%ROWCOUNT);
   EXCEPTION
      WHEN OTHERS
      THEN
         msg ('Error occured in PROCEDURE  ' || lv_procedure || '-' || SQLERRM
             );
   END purge_data;
/*Commented for version 1.1 end*/
    /*Added for version 1.1 start*/
    /****************************************************************************
  -- Procedure Name      :  purge_archive
  --
  -- Description         :  This procedure is to archive and purge the old records


  -- Parameters          : p_errbuf      OUT : Error message
  --                              p_retcode     OUT : Execution
  -
  -- Return/Exit         :  none
  --
  --
  -- DEVELOPMENT and MAINTENANCE HISTORY
  --
  -- date          author             Version  Description
  -- ------------  -----------------  -------

  --------------------------------
  -- 2015/02/02 Infosys            1.0  Initial Version.
  --
  --
  ***************************************************************************/
    PROCEDURE purge_archive (p_errbuf       OUT VARCHAR2,
                             p_retcode      OUT NUMBER,
                             p_purge     IN     NUMBER)
    IS
        lv_procedure    VARCHAR2 (100) := '.PURGE_ARCHIVE';
        l_dte_sysdate   DATE := SYSDATE;
    BEGIN
        msg ('Purging ' || p_purge || ' days old records...');


        /*RA Receipt header interface*/
        BEGIN
            INSERT INTO xxdo_ont_rma_hdr_stg_log (wh_id,
                                                  rma_number,
                                                  rma_receipt_date,
                                                  rma_reference,
                                                  customer_id,
                                                  order_number,
                                                  order_number_type,
                                                  customer_name,
                                                  customer_addr1,
                                                  customer_addr2,
                                                  customer_addr3,
                                                  customer_city,
                                                  customer_state,
                                                  customer_zip,
                                                  customer_phone,
                                                  customer_email,
                                                  comments,
                                                  rma_type,
                                                  notified_to_wms,
                                                  company,
                                                  customer_country_code,
                                                  customer_country_name,
                                                  request_id,
                                                  creation_date,
                                                  created_by,
                                                  last_update_date,
                                                  last_updated_by,
                                                  last_update_login,
                                                  attribute1,
                                                  attribute2,
                                                  attribute3,
                                                  attribute4,
                                                  attribute5,
                                                  attribute6,
                                                  attribute7,
                                                  attribute8,
                                                  attribute9,
                                                  attribute10,
                                                  attribute11,
                                                  attribute12,
                                                  attribute13,
                                                  attribute14,
                                                  attribute15,
                                                  attribute16,
                                                  attribute17,
                                                  attribute18,
                                                  attribute19,
                                                  attribute20,
                                                  source,
                                                  destination,
                                                  header_id,
                                                  process_status,
                                                  error_message,
                                                  retcode,
                                                  result_code,
                                                  record_type,
                                                  receipt_header_seq_id,
                                                  archive_request_id,
                                                  archive_date)
                SELECT wh_id, rma_number, rma_receipt_date,
                       rma_reference, customer_id, order_number,
                       order_number_type, customer_name, customer_addr1,
                       customer_addr2, customer_addr3, customer_city,
                       customer_state, customer_zip, customer_phone,
                       customer_email, comments, rma_type,
                       notified_to_wms, company, customer_country_code,
                       customer_country_name, request_id, creation_date,
                       created_by, last_update_date, last_updated_by,
                       last_update_login, attribute1, attribute2,
                       attribute3, attribute4, attribute5,
                       attribute6, attribute7, attribute8,
                       attribute9, attribute10, attribute11,
                       attribute12, attribute13, attribute14,
                       attribute15, attribute16, attribute17,
                       attribute18, attribute19, attribute20,
                       source, destination, header_id,
                       process_status, error_message, retcode,
                       result_code, record_type, receipt_header_seq_id,
                       g_num_request_id, l_dte_sysdate
                  FROM xxdo_ont_rma_hdr_stg
                 WHERE TRUNC (creation_date) <
                       TRUNC (l_dte_sysdate) - p_purge;

            DELETE FROM
                xxdo_ont_rma_hdr_stg
                  WHERE TRUNC (creation_date) <
                        TRUNC (l_dte_sysdate) - p_purge;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_retcode   := 1;
                p_errbuf    :=
                       'Error happened while archiving RA Receipt Header '
                    || SQLERRM;
                msg (
                       'Error happened while archiving RA Receipt Header Data '
                    || SQLERRM);
        END;

        /*RA Receipt line interface*/
        BEGIN
            INSERT INTO xxdo_ont_rma_line_stg_log (wh_id,
                                                   rma_number,
                                                   rma_reference,
                                                   line_number,
                                                   item_number,
                                                   type1,
                                                   disposition,
                                                   comments,
                                                   qty,
                                                   employee_id,
                                                   employee_name,
                                                   cust_return_reason,
                                                   factory_code,
                                                   damage_code,
                                                   prod_code,
                                                   uom,
                                                   host_subinventory,
                                                   attribute1,
                                                   attribute2,
                                                   attribute3,
                                                   attribute4,
                                                   attribute5,
                                                   attribute6,
                                                   attribute7,
                                                   attribute8,
                                                   attribute9,
                                                   attribute10,
                                                   attribute11,
                                                   attribute12,
                                                   attribute13,
                                                   attribute14,
                                                   attribute15,
                                                   attribute16,
                                                   attribute17,
                                                   attribute18,
                                                   attribute19,
                                                   attribute20,
                                                   request_id,
                                                   creation_date,
                                                   created_by,
                                                   last_update_date,
                                                   last_updated_by,
                                                   last_update_login,
                                                   source,
                                                   destination,
                                                   record_type,
                                                   header_id,
                                                   line_id,
                                                   process_status,
                                                   error_message,
                                                   inventory_item_id,
                                                   ship_from_org_id,
                                                   result_code,
                                                   GROUP_ID,
                                                   retcode,
                                                   receipt_header_seq_id,
                                                   receipt_line_seq_id,
                                                   rma_receipt_date,
                                                   archive_request_id,
                                                   archive_date)
                SELECT wh_id, rma_number, rma_reference,
                       line_number, item_number, type1,
                       disposition, comments, qty,
                       employee_id, employee_name, cust_return_reason,
                       factory_code, damage_code, prod_code,
                       uom, host_subinventory, attribute1,
                       attribute2, attribute3, attribute4,
                       attribute5, attribute6, attribute7,
                       attribute8, attribute9, attribute10,
                       attribute11, attribute12, attribute13,
                       attribute14, attribute15, attribute16,
                       attribute17, attribute18, attribute19,
                       attribute20, request_id, creation_date,
                       created_by, last_update_date, last_updated_by,
                       last_update_login, source, destination,
                       record_type, header_id, line_id,
                       process_status, error_message, inventory_item_id,
                       ship_from_org_id, result_code, GROUP_ID,
                       retcode, receipt_header_seq_id, receipt_line_seq_id,
                       rma_receipt_date, g_num_request_id, l_dte_sysdate
                  FROM xxdo_ont_rma_line_stg
                 WHERE TRUNC (creation_date) <
                       TRUNC (l_dte_sysdate) - p_purge;

            DELETE FROM
                xxdo_ont_rma_line_stg
                  WHERE TRUNC (creation_date) <
                        TRUNC (l_dte_sysdate) - p_purge;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_retcode   := 1;
                p_errbuf    :=
                       'Error happened while archiving RA Receipt Details '
                    || SQLERRM;
                msg (
                       'Error happened while archiving RA Receipt Header Details '
                    || SQLERRM);
        END;



        /*RA Receipt line serial interface*/
        BEGIN
            INSERT INTO xxdo_ont_rma_line_serl_stg_log (wh_id, rma_number, line_number, item_number, serial_number, rma_reference, request_id, creation_date, created_by, last_update_date, last_updated_by, last_update_login, source, destination, record_type, header_id, line_id, line_serial_id, attribute1, attribute2, attribute3, attribute4, attribute5, attribute6, attribute7, attribute8, attribute9, attribute10, attribute11, attribute12, attribute13, attribute14, attribute15, attribute16, attribute17, attribute18, attribute19, attribute20, process_status, error_message, receipt_header_seq_id, receipt_line_seq_id, receipt_serial_seq_id, result_code, retcode, inventory_item_id, organization_id, archive_request_id
                                                        , archive_date)
                SELECT wh_id, rma_number, line_number,
                       item_number, serial_number, rma_reference,
                       request_id, creation_date, created_by,
                       last_update_date, last_updated_by, last_update_login,
                       source, destination, record_type,
                       header_id, line_id, line_serial_id,
                       attribute1, attribute2, attribute3,
                       attribute4, attribute5, attribute6,
                       attribute7, attribute8, attribute9,
                       attribute10, attribute11, attribute12,
                       attribute13, attribute14, attribute15,
                       attribute16, attribute17, attribute18,
                       attribute19, attribute20, process_status,
                       error_message, receipt_header_seq_id, receipt_line_seq_id,
                       receipt_serial_seq_id, result_code, retcode,
                       inventory_item_id, organization_id, g_num_request_id,
                       l_dte_sysdate
                  FROM xxdo_ont_rma_line_serl_stg
                 WHERE TRUNC (creation_date) <
                       TRUNC (l_dte_sysdate) - p_purge;

            DELETE FROM
                xxdo_ont_rma_line_serl_stg
                  WHERE TRUNC (creation_date) <
                        TRUNC (l_dte_sysdate) - p_purge;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_retcode   := 1;
                p_errbuf    :=
                       'Error happened while archiving RA Receipt Serial Details '
                    || SQLERRM;
                msg (
                       'Error happened while archiving RA Receipt Header Serial Details '
                    || SQLERRM);
        END;



        /*RA XML Staging interface*/
        BEGIN
            INSERT INTO xxdo_ont_rma_xml_stg_log (process_status, xml_document, file_name, error_message, request_id, creation_date, created_by, last_update_date, last_updated_by, record_type, rma_xml_seq_id, archive_request_id
                                                  , archive_date)
                SELECT process_status, xml_document, file_name,
                       error_message, request_id, creation_date,
                       created_by, last_update_date, last_updated_by,
                       record_type, rma_xml_seq_id, g_num_request_id,
                       l_dte_sysdate
                  FROM xxdo_ont_rma_xml_stg
                 WHERE TRUNC (creation_date) <
                       TRUNC (l_dte_sysdate) - p_purge;

            DELETE FROM
                xxdo_ont_rma_xml_stg
                  WHERE TRUNC (creation_date) <
                        TRUNC (l_dte_sysdate) - p_purge;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_retcode   := 1;
                p_errbuf    :=
                       'Error happened while archiving RA XML Statging table '
                    || SQLERRM;
                msg (
                       'Error happened while archiving RA XML Stating table '
                    || SQLERRM);
        END;
    /*
    DELETE FROM xxdo.xxdo_ont_rma_hdr_stg
          WHERE last_update_date < (SYSDATE - p_purge);

    COMMIT;
    msg ('No of rows purged from XXDO_ONT_RMA_HDR_STG ' || SQL%ROWCOUNT);

    DELETE FROM xxdo.xxdo_ont_rma_line_stg
          WHERE last_update_date < (SYSDATE - p_purge);

    COMMIT;
    msg ('No of rows purged from XXDO_ONT_RMA_LINE_STG ' || SQL%ROWCOUNT);

    DELETE FROM xxdo.xxdo_ont_rma_line_serl_stg
          WHERE last_update_date < (SYSDATE - p_purge);

    COMMIT;
    msg (   'No of rows purged from XXDO_ONT_RMA_LINE_SERL_STG '
         || SQL%ROWCOUNT
        );

    DELETE FROM xxdo.xxdo_ont_rma_xml_stg
          WHERE last_update_date < (SYSDATE - p_purge);

    COMMIT;
    msg ('No of rows purged from XXDO_ONT_RMA_XML_STG ' || SQL%ROWCOUNT);  */
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Error occured in PROCEDURE  '
                || lv_procedure
                || '-'
                || SQLERRM);
    END purge_archive;

    /*Added for version 1.1 end*/
    PROCEDURE set_in_process (p_retcode OUT NUMBER, p_error_buf OUT VARCHAR2, p_total_count OUT NUMBER
                              , p_wh_code VARCHAR2, p_rma_no VARCHAR2)
    IS
        lv_procedure   VARCHAR2 (100) := g_package_name || '.set_in_process';
        lv_tot_count   NUMBER := 0;
    BEGIN
        p_error_buf     := NULL;
        p_retcode       := '0';
        p_total_count   := 0;

        UPDATE xxdo_ont_rma_hdr_stg
           SET process_status = 'INPROCESS', request_id = g_num_request_id, last_updated_by = g_num_user_id,
               last_update_date = SYSDATE                                  --,
         WHERE     process_status = 'NEW'
               AND rma_reference = NVL (p_rma_no, rma_reference)
               AND wh_id = NVL (p_wh_code, wh_id)
               AND rma_reference IS NOT NULL
               AND rma_number IS NULL;

        lv_tot_count    := SQL%ROWCOUNT;
        p_total_count   := p_total_count + lv_tot_count;
        msg (
               'No of rows updated  from XXDO_ONT_RMA_HDR_STG to INPROCESS '
            || lv_tot_count);
        lv_tot_count    := 0;

        UPDATE xxdo_ont_rma_line_stg
           SET process_status = 'INPROCESS', request_id = g_num_request_id, last_updated_by = g_num_user_id,
               last_update_date = SYSDATE
         WHERE     process_status = 'NEW'
               AND rma_reference = NVL (p_rma_no, rma_reference)
               AND wh_id = NVL (p_wh_code, wh_id)
               AND rma_reference IS NOT NULL
               AND rma_number IS NULL;

        lv_tot_count    := SQL%ROWCOUNT;
        p_total_count   := p_total_count + lv_tot_count;
        msg (
               'No of rows updated  from XXDO_ONT_RMA_LINE_STG to INPROCESS '
            || lv_tot_count);
        lv_tot_count    := 0;

        UPDATE xxdo_ont_rma_line_serl_stg
           SET process_status = 'INPROCESS', request_id = g_num_request_id, last_updated_by = g_num_user_id,
               last_update_date = SYSDATE
         WHERE     receipt_line_seq_id IN
                       (SELECT l.receipt_line_seq_id
                          FROM xxdo_ont_rma_line_stg l
                         WHERE     l.request_id = g_num_request_id
                               AND l.process_status = 'INPROCESS')
               AND rma_reference IS NOT NULL
               AND rma_number IS NULL;

        lv_tot_count    := SQL%ROWCOUNT;
        p_total_count   := p_total_count + lv_tot_count;
        msg (
               'No of rows updated  from xxdo_ont_rma_line_serl_stg to INPROCESS '
            || lv_tot_count);
        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('Error in ' || lv_procedure);
            p_retcode     := 2;
            p_error_buf   := SQLERRM;
    END set_in_process;

    PROCEDURE apply_hold (ph_line_tbl IN OUT oe_holds_pvt.order_tbl_type, p_hold_comment IN VARCHAR2, p_return_status OUT NUMBER
                          , p_error_message OUT VARCHAR2)
    IS
        lv_order_tbl       oe_holds_pvt.order_tbl_type;
        lv_hold_id         NUMBER;
        lv_i               NUMBER;
        lv_comment         VARCHAR2 (100);
        lv_return_status   VARCHAR2 (1);
        lv_msg_count       NUMBER;
        lv_msg_data        VARCHAR2 (1000);
        lv_procedure       VARCHAR2 (240)
            := SUBSTR (g_package_name || '.process_unplanned_rma', 1, 240);
        lv_cnt             NUMBER;
    BEGIN
        p_error_message   := NULL;
        p_return_status   := 0;                              -- g_ret_success;
        lv_order_tbl      := ph_line_tbl;

        BEGIN
            SELECT hold_id
              INTO lv_hold_id
              FROM oe_hold_definitions
             WHERE NAME = 'WMS_UNKNOWN_RMA_HOLD';
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                msg (p_error_message);
                p_error_message   :=
                    'Hold WMS_OVER_RECEIPT_HOLD is not defined';
                p_return_status   := 2;
                RETURN;
            WHEN OTHERS
            THEN
                p_error_message   := SQLERRM;
                msg (p_error_message);
                p_return_status   := 2;
                RETURN;
        END;

        lv_comment        :=
            NVL (p_hold_comment,
                 'Hold applied by Deckers Unexpected RMAS program');
        msg ('Calling Apply Hold Api');
        oe_holds_pub.apply_holds (
            p_api_version        => 1.0,
            p_init_msg_list      => fnd_api.g_false,
            p_commit             => fnd_api.g_false,
            p_validation_level   => fnd_api.g_valid_level_full,
            p_order_tbl          => lv_order_tbl,
            p_hold_id            => lv_hold_id,
            p_hold_until_date    => NULL,
            p_hold_comment       => lv_comment,
            x_return_status      => lv_return_status,
            x_msg_count          => lv_msg_count,
            x_msg_data           => lv_msg_data);

        IF NVL (lv_return_status, 'X') <> 'S'
        THEN
            p_return_status   := 2;
            p_error_message   := lv_msg_data;

            FOR i IN lv_order_tbl.FIRST .. lv_order_tbl.LAST
            LOOP
                UPDATE xxdo_ont_rma_line_stg line
                   SET process_status = 'ERROR', result_code = 'E', type1 = 'PLANNED',
                       error_message = 'Hold Couldnt be applied for reason ' || lv_msg_data, last_updated_by = g_num_user_id, last_update_date = SYSDATE,
                       last_update_login = g_num_login_id
                 WHERE     process_status IN ('PROCESSED')
                       AND result_code = 'C'
                       AND request_id = g_num_request_id
                       AND line_id = lv_order_tbl (i).line_id;

                COMMIT;
            END LOOP;

            RETURN;
        ELSIF NVL (lv_return_status, 'X') = 'S'
        THEN
            COMMIT;

            FOR k IN lv_order_tbl.FIRST .. lv_order_tbl.LAST
            LOOP
                UPDATE xxdo_ont_rma_line_stg line
                   SET process_status = 'HOLD', result_code = 'H', type1 = 'PLANNED',
                       error_message = '', last_updated_by = g_num_user_id, last_update_date = SYSDATE,
                       last_update_login = g_num_login_id
                 WHERE     process_status IN ('PROCESSED')
                       AND result_code = 'C'
                       AND request_id = g_num_request_id
                       AND line_number = lv_order_tbl (k).line_id
                       AND EXISTS
                               (SELECT 'x'
                                  FROM oe_order_holds_all oh, oe_hold_sources_all ohs
                                 WHERE     oh.header_id =
                                           lv_order_tbl (k).header_id
                                       AND oh.line_id =
                                           lv_order_tbl (k).line_id
                                       AND oh.hold_source_id =
                                           ohs.hold_source_id
                                       AND ohs.hold_id = lv_hold_id
                                       AND oh.released_flag = 'N');

                COMMIT;
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_return_status   := 2;
            p_error_message   := SQLERRM;
            msg ('Error in process apply_hold' || SQLERRM);
    END apply_hold;

    /*
    ***********************************************************************************
     Procedure/Function Name  :  wait_for_request
     Description              :  This procedure waits for the child concurrent programs
                                 that are spawned by current program
    **********************************************************************************
    */
    PROCEDURE wait_for_request (in_num_parent_req_id IN NUMBER)
    AS
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

    PROCEDURE derive_order_header (in_chr_order_number_type IN VARCHAR2, in_chr_order_number IN VARCHAR2, in_num_customer_id IN VARCHAR2
                                   , out_num_header_id OUT NUMBER)
    IS
    BEGIN
        IF in_chr_order_number_type = 'HOSTORDER'
        THEN
            SELECT header_id
              INTO out_num_header_id
              FROM oe_order_headers_all
             WHERE order_number = in_chr_order_number;
        END IF;

        IF in_chr_order_number_type = 'WMSORDER'
        THEN
            SELECT ooh.header_id
              INTO out_num_header_id
              FROM wsh_new_deliveries wnd, wsh_delivery_assignments wda, wsh_delivery_details wdd,
                   oe_order_lines_all ool, oe_order_headers_all ooh, mtl_parameters mp
             WHERE     wnd.delivery_id = TO_NUMBER (in_chr_order_number)
                   AND wnd.delivery_id = wda.delivery_id
                   AND wda.delivery_detail_id = wdd.delivery_detail_id
                   AND ool.line_id = wdd.source_line_id
                   AND ool.header_id = ooh.header_id
                   AND ROWNUM = 1;
        END IF;

        IF in_chr_order_number_type = 'CUSTOMERPO'
        THEN
            SELECT ooh.header_id
              INTO out_num_header_id
              FROM oe_order_headers_all ooh, hz_cust_accounts hca
             WHERE     ooh.cust_po_number = in_chr_order_number
                   AND ooh.sold_to_org_id = hca.cust_account_id
                   AND hca.account_number = in_num_customer_id;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            UPDATE xxdo_ont_rma_hdr_stg x
               SET process_status = 'ERROR', result_code = 'E', error_message = 'Unable to derive order reference'
             WHERE     request_id = g_num_request_id
                   AND process_status = 'INPROCESS'
                   AND order_number_type = in_chr_order_number_type
                   AND order_number = in_chr_order_number
                   AND NVL (customer_id, -999) =
                       NVL (in_num_customer_id, NVL (customer_id, -999));

            UPDATE xxdo_ont_rma_line_stg x
               SET process_status = 'ERROR', result_code = 'E', error_message = 'Header is in error'
             WHERE     request_id = g_num_request_id
                   AND process_status = 'INPROCESS'
                   AND receipt_header_seq_id IN
                           (SELECT y.receipt_header_seq_id
                              FROM xxdo_ont_rma_hdr_stg y
                             WHERE     request_id = g_num_request_id
                                   AND process_status = 'ERROR');

            COMMIT;
            fnd_file.put_line (fnd_file.LOG,
                               'Error in derive order header: ' || SQLERRM);
            out_num_header_id   := 0;
    END derive_order_header;

    PROCEDURE derive_order_line (in_chr_order_number_type   IN     VARCHAR2,
                                 in_chr_order_number        IN     VARCHAR2,
                                 in_num_item_id             IN     NUMBER,
                                 in_num_qty                 IN     NUMBER,
                                 in_num_customer_id         IN     VARCHAR2,
                                 in_num_wh_id                      NUMBER,
                                 out_num_header_id             OUT NUMBER,
                                 out_num_line_id               OUT NUMBER)
    IS
    BEGIN
        msg ('Start of derive line');
        out_num_header_id   := 0;
        out_num_line_id     := 0;

        IF in_chr_order_number_type = 'HOSTORDER'
        THEN
            BEGIN
                SELECT y.header_id, y.line_id
                  INTO out_num_header_id, out_num_line_id
                  FROM (SELECT shipped_quantity,
                               ool.line_id,
                               ool.header_id,
                               (SELECT SUM (ordered_quantity)
                                  FROM oe_order_lines_all rl
                                 WHERE     rl.ship_from_org_id = in_num_wh_id
                                       AND rl.reference_line_id = ool.line_id) return_qty
                          FROM oe_order_lines_all ool, oe_order_headers_all ooh
                         WHERE     ooh.order_number = in_chr_order_number
                               AND ooh.header_id = ool.header_id
                               AND ool.inventory_item_id = in_num_item_id
                               AND ool.ship_from_org_id = in_num_wh_id
                               AND ool.shipped_quantity > 0) y
                 WHERE     y.shipped_quantity - NVL (y.return_qty, 0) >=
                           in_num_qty
                       AND ROWNUM = 1;

                msg ('HOSTORDER header_id :' || out_num_header_id);
                msg ('HOSTORDER line_id :' || out_num_line_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    out_num_header_id   := 0;
                    out_num_line_id     := 0;
                    msg (
                           'HOSTORDER exception header_id :'
                        || out_num_header_id);
                    msg ('HOSTORDER exception line_id :' || out_num_line_id);
            END;
        END IF;

        IF in_chr_order_number_type = 'CUSTOMERPO'
        THEN
            BEGIN
                SELECT y.header_id, y.line_id
                  INTO out_num_header_id, out_num_line_id
                  FROM (SELECT shipped_quantity,
                               ool.line_id,
                               ool.header_id,
                               (SELECT SUM (ordered_quantity)
                                  FROM oe_order_lines_all rl
                                 WHERE     rl.ship_from_org_id = in_num_wh_id
                                       AND rl.reference_line_id = ool.line_id) return_qty
                          FROM oe_order_lines_all ool, oe_order_headers_all ooh, hz_cust_accounts_all hca
                         WHERE     ooh.cust_po_number = in_chr_order_number
                               AND ooh.sold_to_org_id = hca.cust_account_id
                               AND hca.account_number = in_num_customer_id
                               AND ooh.header_id = ool.header_id
                               AND ool.inventory_item_id = in_num_item_id
                               AND ool.ship_from_org_id = in_num_wh_id
                               AND ool.shipped_quantity > 0) y
                 WHERE     y.shipped_quantity - NVL (y.return_qty, 0) >=
                           in_num_qty
                       AND ROWNUM = 1;

                msg ('CUSTOMERPO header_id :' || out_num_header_id);
                msg ('CUSTOMERPO line_id :' || out_num_line_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    out_num_header_id   := 0;
                    out_num_line_id     := 0;
                    msg (
                           'CUSTOMERPO exception header_id :'
                        || out_num_header_id);
                    msg ('CUSTOMERPO exception line_id :' || out_num_line_id);
            END;
        END IF;

        IF in_chr_order_number_type = 'WMSORDER'
        THEN
            BEGIN
                SELECT y.header_id, y.line_id
                  INTO out_num_header_id, out_num_line_id
                  FROM (SELECT DISTINCT ool.shipped_quantity,
                                        ool.line_id,
                                        ool.header_id,
                                        (SELECT SUM (ordered_quantity)
                                           FROM oe_order_lines_all rl
                                          WHERE     rl.ship_from_org_id =
                                                    in_num_wh_id
                                                AND rl.reference_line_id =
                                                    ool.line_id) return_qty
                          FROM wsh_new_deliveries wnd, wsh_delivery_assignments wda, wsh_delivery_details wdd,
                               oe_order_lines_all ool
                         WHERE     wnd.delivery_id =
                                   TO_NUMBER (in_chr_order_number)
                               AND wnd.organization_id = in_num_wh_id
                               AND wnd.delivery_id = wda.delivery_id
                               AND wda.delivery_detail_id =
                                   wdd.delivery_detail_id
                               AND wdd.source_line_id = ool.line_id
                               AND ool.inventory_item_id = in_num_item_id
                               AND ool.ship_from_org_id = in_num_wh_id
                               AND ool.shipped_quantity > 0) y
                 WHERE     y.shipped_quantity - NVL (y.return_qty, 0) >=
                           in_num_qty
                       AND ROWNUM = 1;

                msg ('WMSORDER1 header_id :' || out_num_header_id);
                msg ('WMSORDER1 line_id :' || out_num_line_id);
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    BEGIN
                        SELECT y.header_id, y.line_id
                          INTO out_num_header_id, out_num_line_id
                          FROM (SELECT DISTINCT ool.shipped_quantity,
                                                ool.line_id,
                                                ool.header_id,
                                                (SELECT SUM (ordered_quantity)
                                                   FROM oe_order_lines_all rl
                                                  WHERE rl.reference_line_id =
                                                        ool.line_id) return_qty
                                  FROM wsh_new_deliveries wnd, wsh_delivery_assignments wda, wsh_delivery_details wdd,
                                       oe_order_lines_all ool
                                 WHERE     wnd.attribute11 =
                                           in_chr_order_number
                                       AND wnd.delivery_id = wda.delivery_id
                                       AND wnd.organization_id = in_num_wh_id
                                       AND wda.delivery_detail_id =
                                           wdd.delivery_detail_id
                                       AND wdd.source_line_id = ool.line_id
                                       AND ool.inventory_item_id =
                                           in_num_item_id
                                       AND ool.ship_from_org_id =
                                           in_num_wh_id
                                       AND ool.shipped_quantity > 0) y
                         WHERE     y.shipped_quantity - NVL (y.return_qty, 0) >=
                                   in_num_qty
                               AND ROWNUM = 1;

                        msg ('WMSORDER2 header_id :' || out_num_header_id);
                        msg ('WMSORDER2 line_id :' || out_num_line_id);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            out_num_header_id   := 0;
                            out_num_line_id     := 0;
                            msg (
                                   'WMSORDER2 exception header_id :'
                                || out_num_header_id);
                            msg (
                                   'WMSORDER2 exception line_id :'
                                || out_num_line_id);
                    END;
                WHEN OTHERS
                THEN
                    out_num_header_id   := 0;
                    out_num_line_id     := 0;
                    msg (
                           'WMSORDER1 exception header_id :'
                        || out_num_header_id);
                    msg ('WMSORDER1 exception line_id :' || out_num_line_id);
            END;
        END IF;

        msg ('final header_id :' || out_num_header_id);
        msg ('final line_id :' || out_num_line_id);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Exception in derive lines ' || SQLERRM);
            msg ('derive line exception header_id :' || out_num_header_id);
            msg ('derive line exception line_id :' || out_num_line_id);
    END;

    PROCEDURE create_unplan_rma (p_leap_days IN NUMBER, p_return_status OUT NUMBER, p_error_message OUT VARCHAR2)
    IS
        l_header_rec              oe_order_pub.header_rec_type;
        l_line_tbl                oe_order_pub.line_tbl_type;
        l_action_request_tbl      oe_order_pub.request_tbl_type;
        l_header_adj_tbl          oe_order_pub.header_adj_tbl_type;
        l_line_adj_tbl            oe_order_pub.line_adj_tbl_type;
        l_header_scr_tbl          oe_order_pub.header_scredit_tbl_type;
        l_line_scredit_tbl        oe_order_pub.line_scredit_tbl_type;
        l_request_rec             oe_order_pub.request_rec_type;
        l_return_status           VARCHAR2 (1000);
        l_msg_count               NUMBER;
        l_msg_data                VARCHAR2 (1000);
        p_api_version_number      NUMBER := 1.0;
        p_init_msg_list           VARCHAR2 (10) := fnd_api.g_false;
        p_return_values           VARCHAR2 (10) := fnd_api.g_false;
        p_action_commit           VARCHAR2 (10) := fnd_api.g_false;
        x_return_status           VARCHAR2 (1);
        x_msg_count               NUMBER;
        x_msg_data                VARCHAR2 (100);
        p_header_rec              oe_order_pub.header_rec_type
                                      := oe_order_pub.g_miss_header_rec;
        p_line_tbl                oe_order_pub.line_tbl_type
                                      := oe_order_pub.g_miss_line_tbl;
        x_debug_file              VARCHAR2 (100);
        lv_header_id              NUMBER;
        p_adj_tbl                 oe_order_pub.line_adj_tbl_type;
        lv_order_tbl              oe_holds_pvt.order_tbl_type;
        --   lv_i NUMBER := 1;
        lv_hold_exists            NUMBER := 1;
        lv_header_exists          NUMBER;
        lv_proc_name              VARCHAR2 (240)
                                      := g_package_name || '.create_unplan_rma';
        l_num_header_id           NUMBER;
        l_num_line_id             NUMBER;
        l_num_sold_to_org_id      NUMBER;
        l_num_invoice_to_org_id   NUMBER;
        l_num_ship_to_org_id      NUMBER;
        l_chr_brand               VARCHAR2 (30);
        l_num_sales_rep           NUMBER;
        l_num_order_type_ref      NUMBER;
        l_num_order_type_noref    NUMBER;
        l_num_order_type          NUMBER;
        l_num_operating_unit      NUMBER;

        CURSOR c_rma_hdr IS
            SELECT *
              FROM xxdo_ont_rma_hdr_stg
             WHERE     process_status = 'INPROCESS'
                   AND result_code = 'P'
                   AND request_id = g_num_request_id;

        CURSOR cur_rma_line (p_hdr_seq IN NUMBER)
        IS
            SELECT *
              FROM xxdo_ont_rma_line_stg
             WHERE     process_status = 'INPROCESS'
                   AND result_code = 'P'
                   AND request_id = g_num_request_id
                   AND receipt_header_seq_id = p_hdr_seq;

        l_num_count               NUMBER := 0;
        l_num_request_id          NUMBER := 0;
        l_chr_order_import        VARCHAR2 (1) := 'N';
        l_num_order_source        NUMBER;
        l_chr_return_context      VARCHAR2 (10);
        /*variables added for version 1.1*/
        l_num_vendor_id           NUMBER;
        l_chr_prod_code           NUMBER;
        l_chr_ret_reason          VARCHAR (100);
    BEGIN
        p_error_message   := NULL;
        p_return_status   := 0;
        oe_msg_pub.initialize;
        oe_debug_pub.initialize;
        x_debug_file      := oe_debug_pub.set_debug_mode ('FILE');
        oe_debug_pub.setdebuglevel (5);
        msg ('Start of Building RMA Header , Lines and Create Orders');

        BEGIN
            SELECT order_source_id
              INTO l_num_order_source
              FROM oe_order_sources
             WHERE NAME = 'WMS';
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (fnd_file.LOG, 'Order source is missing');
                l_num_order_source   := -1;
        END;

        SELECT transaction_type_id
          INTO l_num_order_type_ref
          FROM oe_transaction_types_tl
         WHERE LANGUAGE = 'US' AND NAME IN ('WMS Returns-Ref');

        SELECT transaction_type_id
          INTO l_num_order_type_noref
          FROM oe_transaction_types_tl
         WHERE LANGUAGE = 'US' AND NAME IN ('WMS Returns-NoRef');

        FOR c_rma_hdr_rec IN c_rma_hdr
        LOOP
            msg ('Processing RMA Reference: ' || c_rma_hdr_rec.rma_reference);
            l_num_sold_to_org_id      := NULL;
            l_num_invoice_to_org_id   := NULL;
            l_num_ship_to_org_id      := NULL;
            l_chr_brand               := NULL;
            l_num_sales_rep           := NULL;
            l_chr_return_context      := 'ORDER';

            /* derive current inventory orgs operating unit into global operating unit variable. */
            BEGIN
                l_num_operating_unit   := -1;

                SELECT operating_unit
                  INTO l_num_operating_unit
                  FROM org_organization_definitions ood
                 WHERE ood.organization_code = c_rma_hdr_rec.wh_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_num_operating_unit   := 2;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Unable to derive operating unit for warehouse : '
                        || c_rma_hdr_rec.wh_id);
            END;

            IF     c_rma_hdr_rec.order_number_type IN
                       ('WMSORDER', 'CUSTOMERPO', 'HOSTORDER')
               AND c_rma_hdr_rec.order_number IS NOT NULL
            THEN
                derive_order_header (c_rma_hdr_rec.order_number_type, c_rma_hdr_rec.order_number, c_rma_hdr_rec.customer_id
                                     , l_num_header_id);
                msg ('Header Id derived:' || l_num_header_id);

                IF l_num_header_id > 0
                THEN
                    BEGIN
                        SELECT ooh.sold_to_org_id, ooh.invoice_to_org_id, ooh.ship_to_org_id,
                               ooh.attribute5, ooh.salesrep_id, org_id
                          INTO l_num_sold_to_org_id, l_num_invoice_to_org_id, l_num_ship_to_org_id, l_chr_brand,
                                                   l_num_sales_rep, l_num_operating_unit
                          FROM oe_order_headers_all ooh
                         WHERE ooh.header_id = l_num_header_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error while deriving sales order details '
                                || SQLERRM);
                    END;

                    l_num_order_type   := l_num_order_type_ref;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Operating unit ID for the reference order : '
                        || l_num_operating_unit);
                END IF;
            ELSIF     c_rma_hdr_rec.order_number_type = 'UNKNOWN'
                  AND c_rma_hdr_rec.customer_id IS NOT NULL
            THEN
                l_num_sold_to_org_id      := NULL;
                l_num_invoice_to_org_id   := NULL;
                l_num_ship_to_org_id      := NULL;
                l_chr_brand               := NULL;
                l_num_sales_rep           := -3;
                l_num_order_type          := l_num_order_type_noref;

                BEGIN
                    SELECT hca.cust_account_id
                      INTO l_num_sold_to_org_id
                      FROM hz_cust_accounts_all hca
                     WHERE hca.account_number =
                           TO_CHAR (c_rma_hdr_rec.customer_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error while deriving customer details '
                            || SQLERRM);
                END;

                BEGIN
                    SELECT mcb.segment1
                      INTO l_chr_brand
                      FROM mtl_system_items msi, mtl_categories_b mcb, mtl_item_categories mic,
                           xxdo_ont_rma_line_stg xol
                     WHERE     xol.receipt_header_seq_id =
                               c_rma_hdr_rec.receipt_header_seq_id
                           AND xol.request_id = g_num_request_id
                           AND xol.process_status = 'INPROCESS'
                           AND mic.category_set_id = 1
                           AND mcb.category_id = mic.category_id
                           AND msi.inventory_item_id = xol.inventory_item_id
                           AND msi.organization_id = xol.ship_from_org_id
                           AND msi.inventory_item_id = mic.inventory_item_id
                           AND mic.organization_id = msi.organization_id
                           AND ROWNUM = 1;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Error while deriving brand details ' || SQLERRM);
                        l_chr_brand   := 'UGG';
                END;
            END IF;

            l_num_count               := 0;

            /* insert RMA header record */
            IF l_num_sold_to_org_id > 0
            THEN
                BEGIN
                    INSERT INTO oe_headers_iface_all (order_source_id, orig_sys_document_ref, org_id, creation_date, created_by, last_update_date, last_updated_by, operation_code, sold_to_org_id, order_type_id, booked_flag, attribute1, attribute5, salesrep_id, invoice_to_org_id
                                                      , ship_to_org_id)
                         VALUES (l_num_order_source, c_rma_hdr_rec.rma_reference, l_num_operating_unit, SYSDATE, g_num_user_id, SYSDATE, g_num_user_id, 'INSERT', l_num_sold_to_org_id, l_num_order_type, 'Y', SYSDATE + p_leap_days, l_chr_brand, l_num_sales_rep, l_num_invoice_to_org_id
                                 , l_num_ship_to_org_id);

                    l_num_count   := 1;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Error while inserting header record');
                        ROLLBACK;
                        l_num_count   := 0;
                END;
            END IF;

            IF l_num_count = 1
            THEN
                FOR c_rma_line_rec
                    IN cur_rma_line (c_rma_hdr_rec.receipt_header_seq_id)
                LOOP
                    msg (
                        'Processing line number: ' || c_rma_line_rec.line_number);
                    l_num_header_id        := 0;
                    l_num_line_id          := 0;
                    l_chr_return_context   := 'ORDER';
                    derive_order_line (c_rma_hdr_rec.order_number_type, c_rma_hdr_rec.order_number, c_rma_line_rec.inventory_item_id, c_rma_line_rec.qty, c_rma_hdr_rec.customer_id, c_rma_line_rec.ship_from_org_id
                                       , l_num_header_id, l_num_line_id);

                    IF l_num_line_id = 0
                    THEN
                        l_num_line_id          := NULL;
                        l_num_header_id        := NULL;
                        l_chr_return_context   := NULL;
                    END IF;

                    IF c_rma_line_rec.factory_code IS NOT NULL
                    THEN
                        BEGIN
                            SELECT aps.vendor_id
                              INTO l_num_vendor_id
                              FROM ap_suppliers aps
                             WHERE     aps.vendor_type_lookup_code =
                                       'MANUFACTURER'
                                   AND NVL (aps.start_date_active, SYSDATE) <
                                       SYSDATE + 1
                                   AND NVL (aps.end_date_active, SYSDATE) >=
                                       SYSDATE
                                   AND NVL (aps.enabled_flag, 'N') = 'Y'
                                   AND aps.attribute1 =
                                       c_rma_line_rec.factory_code;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_num_vendor_id   := '';
                        END;
                    END IF;

                    /*If condition added for version 1.1*/
                    IF c_rma_line_rec.prod_code IS NOT NULL
                    THEN
                        BEGIN
                            SELECT dom.MONTH_YEAR_CODE
                              INTO l_chr_prod_code
                              FROM DO_BOM_MONTH_YEAR_V dom
                             WHERE dom.MONTH_YEAR_CODE =
                                   c_rma_line_rec.prod_code;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_chr_prod_code   := '';
                        END;
                    END IF;

                    l_chr_ret_reason       :=
                        NVL (
                            c_rma_line_rec.cust_return_reason,
                            NVL (
                                fnd_profile.VALUE (
                                    'XXDO_3PL_EDI_RET_REASON_CODE'),
                                'UAR - 0010'));

                    BEGIN
                        INSERT INTO oe_lines_iface_all (
                                        order_source_id,
                                        orig_sys_document_ref,
                                        orig_sys_line_ref,
                                        inventory_item_id,
                                        ordered_quantity,
                                        operation_code,
                                        created_by,
                                        creation_date,
                                        last_updated_by,
                                        last_update_date,
                                        return_reason_code,
                                        return_context,
                                        return_attribute1,
                                        return_attribute2,
                                        ship_from_org_id,
                                        inventory_item,
                                        sold_to_org_id,
                                        /*added for version 1.1*/
                                        attribute12,           /*DAMAGE_CODE*/
                                        attribute4,            /*DEFECT_CODE*/
                                        attribute5               /*PROD_CODE*/
                                                  )
                             VALUES (l_num_order_source, c_rma_hdr_rec.rma_reference, c_rma_line_rec.line_number, c_rma_line_rec.inventory_item_id, c_rma_line_rec.qty, 'INSERT', g_num_user_id, SYSDATE, g_num_user_id, SYSDATE, l_chr_ret_reason, -- Added for Defualt Value of RETURN_REASON_CODE
                                                                                                                                                                                                                                                    l_chr_return_context, l_num_header_id, l_num_line_id, c_rma_line_rec.ship_from_org_id, c_rma_line_rec.item_number, l_num_sold_to_org_id, /*added for version 1.1*/
                                                                                                                                                                                                                                                                                                                                                                                             c_rma_line_rec.damage_code /*DAMAGE_CODE*/
                                     , l_num_vendor_id        /*FACTORY_CODE*/
                                                      , l_chr_prod_code /*PROD_CODE*/
                                                                       );

                        l_num_count   := l_num_count + 1;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (fnd_file.LOG,
                                               'Error:' || SQLERRM);
                    END;
                END LOOP;

                msg ('Count value :' || l_num_count);

                IF l_num_count >= 2
                THEN
                    l_chr_order_import   := 'Y';
                    COMMIT;
                ELSE
                    ROLLBACK;
                END IF;
            END IF;
        END LOOP;

        IF l_chr_order_import = 'Y'
        THEN
            l_num_request_id   :=
                fnd_request.submit_request (
                    application   => 'ONT',
                    program       => 'OEOIMP',
                    argument1     => l_num_operating_unit,
                    argument2     => l_num_order_source,
                    argument3     => NULL,
                    argument4     => NULL,
                    argument5     => 'N',
                    argument6     => 1,
                    argument7     => 4,
                    argument8     => NULL,
                    argument9     => NULL,
                    argument10    => NULL,
                    argument11    => 'Y',
                    argument12    => 'N',
                    argument13    => 'Y',
                    argument14    => 2,
                    argument15    => 'Y');
            COMMIT;
            wait_for_request (g_num_request_id);
        END IF;

        UPDATE xxdo_ont_rma_hdr_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'Failed during order import request :' || l_num_request_id
         WHERE     process_status = 'INPROCESS'
               AND request_id = g_num_request_id
               AND EXISTS
                       (SELECT 1
                          FROM oe_headers_iface_all oh
                         WHERE     oh.orig_sys_document_ref = x.rma_reference
                               AND oh.request_id >= l_num_request_id
                               AND oh.order_source_id = l_num_order_source
                               AND oh.error_flag = 'Y');

        UPDATE xxdo_ont_rma_line_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'Failed during order import request :' || l_num_request_id
         WHERE     process_status = 'INPROCESS'
               AND request_id = g_num_request_id
               AND EXISTS
                       (SELECT 1
                          FROM oe_headers_iface_all oh
                         WHERE     oh.orig_sys_document_ref = x.rma_reference
                               AND oh.request_id >= l_num_request_id
                               AND oh.order_source_id = l_num_order_source
                               AND oh.error_flag = 'Y');

        UPDATE xxdo_ont_rma_line_serl_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'Failed during order import request :' || l_num_request_id
         WHERE     process_status = 'INPROCESS'
               AND request_id = g_num_request_id
               AND receipt_header_seq_id IN
                       (SELECT receipt_header_seq_id
                          FROM xxdo_ont_rma_hdr_stg h
                         WHERE     h.process_status = 'ERROR'
                               AND h.request_id = g_num_request_id);

        COMMIT;

        UPDATE xxdo_ont_rma_hdr_stg x
           SET process_status   = 'RMA_CREATED',
               result_code      = 'C',
               error_message    = NULL,
               (rma_number, header_id)   =
                   (SELECT oh.order_number, oh.header_id
                      FROM oe_order_headers_all oh
                     WHERE     oh.orig_sys_document_ref = x.rma_reference
                           AND oh.order_source_id = l_num_order_source
                           AND ROWNUM = 1)
         WHERE     process_status = 'INPROCESS'
               AND request_id = g_num_request_id
               AND EXISTS
                       (SELECT 1
                          FROM oe_order_headers_all oh
                         WHERE     oh.orig_sys_document_ref = x.rma_reference
                               AND oh.order_source_id = l_num_order_source);

        UPDATE xxdo_ont_rma_line_stg x
           SET process_status   = 'PROCESSED',
               result_code      = 'C',
               error_message    = NULL,
               (rma_number, header_id, line_number)   =
                   (SELECT oh.order_number, oh.header_id, ol.line_id
                      FROM oe_order_headers_all oh, oe_order_lines_all ol
                     WHERE     oh.orig_sys_document_ref = x.rma_reference
                           AND oh.order_source_id = l_num_order_source
                           AND oh.header_id = ol.header_id
                           AND ol.orig_sys_line_ref = x.line_number
                           AND ROWNUM = 1)
         WHERE     process_status = 'INPROCESS'
               AND request_id = g_num_request_id
               AND EXISTS
                       (SELECT 1
                          FROM oe_order_headers_all oh, oe_order_lines_all ol
                         WHERE     oh.orig_sys_document_ref = x.rma_reference
                               AND oh.order_source_id = l_num_order_source
                               AND oh.header_id = ol.header_id
                               AND ol.orig_sys_line_ref = x.line_number);

        UPDATE xxdo_ont_rma_line_serl_stg x
           SET process_status   = 'PROCESSED',
               (rma_number, header_id, line_number)   =
                   (SELECT l.rma_number, l.header_id, l.line_number
                      FROM xxdo_ont_rma_line_stg l
                     WHERE     l.receipt_line_seq_id = x.receipt_line_seq_id
                           AND l.process_status = 'PROCESSED'
                           AND l.request_id = g_num_request_id
                           AND ROWNUM = 1),
               result_code      = 'C',
               error_message    = NULL
         WHERE     process_status = 'INPROCESS'
               AND request_id = g_num_request_id
               AND receipt_line_seq_id IN
                       (SELECT line.receipt_line_seq_id
                          FROM xxdo_ont_rma_line_stg line
                         WHERE     line.process_status = 'PROCESSED'
                               AND line.request_id = g_num_request_id);

        COMMIT;

        FOR c_hold_rec
            IN (SELECT DISTINCT header_id, line_number
                  FROM xxdo_ont_rma_line_stg
                 WHERE     process_status = 'PROCESSED'
                       AND result_code = 'C'
                       AND request_id = g_num_request_id)
        LOOP
            lv_order_tbl (lv_hold_exists).header_id   := c_hold_rec.header_id;
            lv_order_tbl (lv_hold_exists).line_id     :=
                c_hold_rec.line_number;
            lv_hold_exists                            := lv_hold_exists + 1;
        END LOOP;

        IF lv_order_tbl.EXISTS (1)
        THEN
            BEGIN
                apply_hold (lv_order_tbl, 'Hold applied', p_return_status,
                            p_error_message);
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_return_status   := 2;
                    msg ('Error while calling process_unplanned_rma');
                    p_error_message   :=
                           'Error while calling process_unplanned_rma'
                        || SQLERRM;
            END;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_return_status   := 2;
            p_error_message   := SQLERRM;
            msg ('Error In  -' || lv_proc_name || '-' || SQLERRM);
    END create_unplan_rma;

    PROCEDURE extract_xml_data (p_errbuf                 OUT VARCHAR2,
                                p_retcode                OUT NUMBER,
                                p_in_num_bulk_limit   IN     NUMBER)
    IS
        lv_num_request_id            NUMBER := fnd_global.conc_request_id;
        lv_num_user_id               NUMBER := fnd_global.user_id;
        lv_chr_xml_message_type      VARCHAR2 (30);
        lv_chr_xml_environment       VARCHAR2 (30);
        lv_chr_environment           VARCHAR2 (30);
        lv_num_error_count           NUMBER := 0;
        lv_rma_request_headers_tab   g_rma_request_headers_tab_type;
        lv_rma_request_dtls_tab      g_rma_request_dtls_tab_type;
        lv_rma_sers_tab              g_rma_sers_tab_type;
        lv_exe_env_no_match          EXCEPTION;
        lv_exe_msg_type_no_match     EXCEPTION;
        lv_exe_bulk_fetch_failed     EXCEPTION;
        lv_exe_bulk_insert_failed    EXCEPTION;
        lv_exe_dml_errors            EXCEPTION;
        PRAGMA EXCEPTION_INIT (lv_exe_dml_errors, -24381);

        CURSOR cur_xml_file_counts IS
            SELECT ROWID row_id, file_name
              FROM xxdo_ont_rma_xml_stg
             WHERE process_status = 'NEW';

        CURSOR cur_rma_request_headers IS
            SELECT EXTRACTVALUE (VALUE (par), 'RMA/wh_id') wh_id, EXTRACTVALUE (VALUE (par), 'RMA/rma_number') rma_number, TO_DATE (EXTRACTVALUE (VALUE (par), 'RMA/rma_receipt_date'), 'YYYY-MM-DD HH24:MI:SS') rma_receipt_date,
                   EXTRACTVALUE (VALUE (par), 'RMA/rma_ref') rma_reference, EXTRACTVALUE (VALUE (par), 'RMA/customer_id') customer_id, EXTRACTVALUE (VALUE (par), 'RMA/order_number') order_number,
                   EXTRACTVALUE (VALUE (par), 'RMA/order_number_type') order_number_type, EXTRACTVALUE (VALUE (par), 'RMA/customer_name') customer_name, EXTRACTVALUE (VALUE (par), 'RMA/customer_addr1') customer_addr1,
                   EXTRACTVALUE (VALUE (par), 'RMA/customer_addr2') customer_addr2, EXTRACTVALUE (VALUE (par), 'RMA/customer_addr3') customer_addr3, EXTRACTVALUE (VALUE (par), 'RMA/customer_city') customer_city,
                   EXTRACTVALUE (VALUE (par), 'RMA/customer_zip') customer_zip, EXTRACTVALUE (VALUE (par), 'RMA/customer_state') customer_state, EXTRACTVALUE (VALUE (par), 'RMA/customer_phone') customer_phone,
                   EXTRACTVALUE (VALUE (par), 'RMA/customer_email') customer_email, EXTRACTVALUE (VALUE (par), 'RMA/comments') comments, EXTRACTVALUE (VALUE (par), 'RMA/rma_type') rma_type,
                   EXTRACTVALUE (VALUE (par), 'RMA/notified_to_wms') notified_to_wms, EXTRACTVALUE (VALUE (par), 'RMA/company') company, EXTRACTVALUE (VALUE (par), 'RMA/customer_country_code') customer_country_code,
                   EXTRACTVALUE (VALUE (par), 'RMA/customer_country_name') customer_country_name, lv_num_request_id request_id, SYSDATE creation_date,
                   lv_num_user_id created_by, SYSDATE last_update_date, lv_num_user_id last_updated_by,
                   lv_num_user_id last_update_login, NULL attribute1, NULL attribute2,
                   NULL attribute3, NULL attribute4, NULL attribute5,
                   NULL attribute6, NULL attribute7, NULL attribute8,
                   NULL attribute9, NULL attribute10, NULL attribute11,
                   NULL attribute12, NULL attribute13, NULL attribute14,
                   NULL attribute15, NULL attribute16, NULL attribute17,
                   NULL attribute18, NULL attribute19, NULL attribute20,
                   'WMS' SOURCE, 'EBS' destination, NULL header_id,
                   'NEW' process_status, NULL error_message, NULL result_code,
                   NULL retcode, 'INSERT' record_type, xxdo_ont_rma_hdr_stg_s.NEXTVAL receipt_header_seq_id
              FROM xxdo_ont_rma_xml_stg xml_tab, TABLE (XMLSEQUENCE (EXTRACT (xml_tab.xml_document, (CHR (47) || CHR (47) || 'RARequestMessage/RMAs' || CHR (47) || CHR (42))))) par
             WHERE process_status = 'NEW';

        CURSOR cur_rma_request_dtls IS
            SELECT EXTRACTVALUE (VALUE (par), 'RMADetail/wh_id') wh_id, EXTRACTVALUE (VALUE (par), 'RMADetail/rma_number') rma_number, EXTRACTVALUE (VALUE (par), 'RMADetail/rma_ref') rma_reference,
                   EXTRACTVALUE (VALUE (par), 'RMADetail/line_number') line_number, EXTRACTVALUE (VALUE (par), 'RMADetail/item_number') item_number, EXTRACTVALUE (VALUE (par), 'RMADetail/type1') type1,
                   EXTRACTVALUE (VALUE (par), 'RMADetail/disposition') disposition, EXTRACTVALUE (VALUE (par), 'RMADetail/comments') comments, EXTRACTVALUE (VALUE (par), 'RMADetail/qty') qty,
                   EXTRACTVALUE (VALUE (par), 'RMADetail/employee_id') employee_id, EXTRACTVALUE (VALUE (par), 'RMADetail/employee_name') employee_name, EXTRACTVALUE (VALUE (par), 'RMADetail/cust_return_reason') cust_return_reason,
                   EXTRACTVALUE (VALUE (par), 'RMADetail/factory_code') factory_code, EXTRACTVALUE (VALUE (par), 'RMADetail/damage_code') damage_code, EXTRACTVALUE (VALUE (par), 'RMADetail/prod_code') prod_code,
                   EXTRACTVALUE (VALUE (par), 'RMADetail/uom') uom, EXTRACTVALUE (VALUE (par), 'RMADetail/host_subinventory') host_subinventory, NULL attribute1,
                   NULL attribute2, NULL attribute3, NULL attribute4,
                   NULL attribute5, NULL attribute6, NULL attribute7,
                   NULL attribute8, NULL attribute9, NULL attribute10,
                   NULL attribute11, NULL attribute12, NULL attribute13,
                   NULL attribute14, NULL attribute15, NULL attribute16,
                   NULL attribute17, NULL attribute18, NULL attribute19,
                   NULL attribute20, lv_num_request_id request_id, SYSDATE creation_date,
                   lv_num_user_id created_by, SYSDATE last_update_date, lv_num_user_id last_updated_by,
                   lv_num_user_id last_update_login, 'WMS' SOURCE, 'EBS' destination,
                   'INSERT' record_type, NULL header_id, NULL line_id,
                   'NEW' process_status, NULL error_message, NULL inventory_item_id,
                   NULL ship_from_org_id, NULL result_code, NULL GROUP_ID,
                   NULL retcode, NULL receipt_header_seq_id, xxdo_ont_rma_line_stg_s.NEXTVAL receipt_line_seq_id,
                   NULL rma_receipt_date, NULL org_id
              FROM xxdo_ont_rma_xml_stg xml_tab, TABLE (XMLSEQUENCE (EXTRACT (xml_tab.xml_document, (CHR (47) || CHR (47) || 'RARequestMessage/RMAs/RMA/RMADetails' || CHR (47) || CHR (42))))) par
             WHERE process_status = 'NEW';

        CURSOR cur_serials IS
            SELECT EXTRACTVALUE (VALUE (par), 'RMADetailSerial/wh_id') wh_id, EXTRACTVALUE (VALUE (par), 'RMADetailSerial/rma_number') rma_number, EXTRACTVALUE (VALUE (par), 'RMADetailSerial/line_number') line_number,
                   EXTRACTVALUE (VALUE (par), 'RMADetailSerial/item_number') item_number, EXTRACTVALUE (VALUE (par), 'RMADetailSerial/serial_number') serial_number, EXTRACTVALUE (VALUE (par), 'RMADetailSerial/rma_ref') rma_reference,
                   lv_num_request_id request_id, SYSDATE creation_date, lv_num_user_id created_by,
                   SYSDATE last_update_date, lv_num_user_id last_updated_by, lv_num_user_id last_update_login,
                   'WMS' SOURCE, 'EBS' destination, 'INSERT' record_type,
                   NULL header_id, NULL line_id, NULL line_serial_id,
                   NULL attribute1, NULL attribute2, NULL attribute3,
                   NULL attribute4, NULL attribute5, NULL attribute6,
                   NULL attribute7, NULL attribute8, NULL attribute9,
                   NULL attribute10, NULL attribute11, NULL attribute12,
                   NULL attribute13, NULL attribute14, NULL attribute15,
                   NULL attribute16, NULL attribute17, NULL attribute18,
                   NULL attribute19, NULL attribute20, 'NEW' process_status,
                   NULL error_message, NULL receipt_header_seq_id, NULL receipt_line_seq_id,
                   xxdo_ont_rma_line_serl_stg_s.NEXTVAL receipt_serial_seq_id, NULL result_code, NULL retcode,
                   NULL inventory_item_id, NULL organization_id
              FROM xxdo_ont_rma_xml_stg xml_tab, TABLE (XMLSEQUENCE (EXTRACT (xml_tab.xml_document, (CHR (47) || CHR (47) || 'RARequestMessage/RMAs/RMA/RMADetails/RMADetail/RMADetailSerials' || CHR (47) || CHR (42))))) par
             WHERE process_status = 'NEW';
    BEGIN
        p_retcode            := '0';
        p_errbuf             := NULL;
        fnd_file.put_line (fnd_file.LOG,
                           'Starting the XML Specific validations');

        -- Get the instance name from DBA view
        BEGIN
            SELECT NAME INTO lv_chr_environment FROM v$database;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_chr_environment   := '-1';
        END;

        fnd_file.put_line (fnd_file.LOG,
                           'Current Database name : ' || lv_chr_environment);

        -- Get the message type and environment details from XML
        BEGIN
            SELECT stg.xml_document.EXTRACT ('//OutboundShipmentsMessage/MessageHeader/MessageType/text()').getstringval (), stg.xml_document.EXTRACT ('//OutboundShipmentsMessage/MessageHeader/Environment/text()').getstringval ()
              INTO lv_chr_xml_message_type, lv_chr_xml_environment
              FROM xxdo_ont_rma_xml_stg stg
             WHERE stg.process_status = 'NEW';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_chr_xml_message_type   := '-1';
                lv_chr_xml_environment    := '-1';
        END;

        fnd_file.put_line (
            fnd_file.LOG,
            'Database name in XML: ' || lv_chr_xml_environment);
        fnd_file.put_line (
            fnd_file.LOG,
            'Message type in XML: ' || lv_chr_xml_message_type);

        IF lv_chr_environment <> lv_chr_xml_environment
        THEN
            RAISE lv_exe_env_no_match;
        END IF;

        fnd_file.put_line (fnd_file.LOG,
                           'Environment Validation is Successful');

        IF lv_chr_xml_message_type <> g_chr_rma_receipt_msg_type
        THEN
            RAISE lv_exe_msg_type_no_match;
        END IF;

        fnd_file.put_line (fnd_file.LOG,
                           'Message Type Validation is Successful');

        SAVEPOINT l_sv_before_load_rma_req;
        fnd_file.put_line (
            fnd_file.LOG,
            'l_sv_before_load_rma_req - Savepoint Established');

        -- Logic to insert ASN Headers
        OPEN cur_rma_request_headers;

        LOOP
            IF lv_rma_request_headers_tab.EXISTS (1)
            THEN
                lv_rma_request_headers_tab.DELETE;
            END IF;

            BEGIN
                FETCH cur_rma_request_headers
                    BULK COLLECT INTO lv_rma_request_headers_tab
                    LIMIT p_in_num_bulk_limit;
            EXCEPTION
                WHEN OTHERS
                THEN
                    CLOSE cur_rma_request_headers;

                    p_errbuf   :=
                           'Unexcepted error in BULK Fetch of RMA Request Headers : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_errbuf);
                    RAISE lv_exe_bulk_fetch_failed;
            END;                                           --end of bulk fetch

            IF NOT lv_rma_request_headers_tab.EXISTS (1)
            THEN
                EXIT;
            END IF;

            BEGIN
                FORALL lv_num_ind
                    IN lv_rma_request_headers_tab.FIRST ..
                       lv_rma_request_headers_tab.LAST
                  SAVE EXCEPTIONS
                    INSERT INTO xxdo_ont_rma_hdr_stg
                         VALUES lv_rma_request_headers_tab (lv_num_ind);
            EXCEPTION
                WHEN lv_exe_dml_errors
                THEN
                    lv_num_error_count   := SQL%BULK_EXCEPTIONS.COUNT;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Number of statements that failed during Bulk Insert of RMA Request headers: '
                        || lv_num_error_count);

                    FOR i IN 1 .. lv_num_error_count
                    LOOP
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error #'
                            || i
                            || ' occurred during '
                            || 'iteration #'
                            || SQL%BULK_EXCEPTIONS (i).ERROR_INDEX);
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error message is '
                            || SQLERRM (-SQL%BULK_EXCEPTIONS (i).ERROR_CODE));
                    END LOOP;
                --                              CLOSE cur_asn_receipt_headers;
                --                              RAISE l_exe_bulk_insert_failed;
                WHEN OTHERS
                THEN
                    CLOSE cur_rma_request_headers;

                    p_errbuf   :=
                           'Unexcepted error in BULK Insert of RMA Request Receipt Headers : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_errbuf);
                    RAISE lv_exe_bulk_insert_failed;
            END;
        END LOOP;                                -- Receipt headers fetch loop

        CLOSE cur_rma_request_headers;

        -- Logic to insert ASN Details
        OPEN cur_rma_request_dtls;

        LOOP
            IF lv_rma_request_dtls_tab.EXISTS (1)
            THEN
                lv_rma_request_dtls_tab.DELETE;
            END IF;

            BEGIN
                FETCH cur_rma_request_dtls
                    BULK COLLECT INTO lv_rma_request_dtls_tab
                    LIMIT p_in_num_bulk_limit;
            EXCEPTION
                WHEN OTHERS
                THEN
                    CLOSE cur_rma_request_dtls;

                    p_errbuf   :=
                           'Unexcepted error in BULK Fetch of RMA Request Details : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_errbuf);
                    RAISE lv_exe_bulk_fetch_failed;
            END;                                           --end of bulk fetch

            IF NOT lv_rma_request_dtls_tab.EXISTS (1)
            THEN
                EXIT;
            END IF;

            BEGIN
                FORALL l_num_ind
                    IN lv_rma_request_dtls_tab.FIRST ..
                       lv_rma_request_dtls_tab.LAST
                  SAVE EXCEPTIONS
                    INSERT INTO xxdo_ont_rma_line_stg
                         VALUES lv_rma_request_dtls_tab (l_num_ind);
            EXCEPTION
                WHEN lv_exe_dml_errors
                THEN
                    lv_num_error_count   := SQL%BULK_EXCEPTIONS.COUNT;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Number of statements that failed during Bulk Insert of RMA Request Details: '
                        || lv_num_error_count);

                    FOR i IN 1 .. lv_num_error_count
                    LOOP
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error #'
                            || i
                            || ' occurred during '
                            || 'iteration #'
                            || SQL%BULK_EXCEPTIONS (i).ERROR_INDEX);
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error message is '
                            || SQLERRM (-SQL%BULK_EXCEPTIONS (i).ERROR_CODE));
                    END LOOP;
                --                              CLOSE cur_asn_receipt_dtls;
                --                              RAISE l_exe_bulk_insert_failed;
                WHEN OTHERS
                THEN
                    CLOSE cur_rma_request_dtls;

                    p_errbuf   :=
                           'Unexcepted error in BULK Insert of RMA Request Details: '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_errbuf);
                    RAISE lv_exe_bulk_insert_failed;
            END;
        END LOOP;                                -- Receipt details fetch loop

        CLOSE cur_rma_request_dtls;

        -- Logic to insert ASN Serials
        OPEN cur_serials;

        LOOP
            IF lv_rma_sers_tab.EXISTS (1)
            THEN
                lv_rma_sers_tab.DELETE;
            END IF;

            BEGIN
                FETCH cur_serials
                    BULK COLLECT INTO lv_rma_sers_tab
                    LIMIT p_in_num_bulk_limit;
            EXCEPTION
                WHEN OTHERS
                THEN
                    CLOSE cur_serials;

                    p_errbuf   :=
                           'Unexcepted error in BULK Fetch of RMA Request Serials : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_errbuf);
                    RAISE lv_exe_bulk_fetch_failed;
            END;                                           --end of bulk fetch

            IF NOT lv_rma_sers_tab.EXISTS (1)
            THEN
                EXIT;
            END IF;

            BEGIN
                FORALL lv_num_ind
                    IN lv_rma_sers_tab.FIRST .. lv_rma_sers_tab.LAST
                  SAVE EXCEPTIONS
                    INSERT INTO xxdo_ont_rma_line_serl_stg
                         VALUES lv_rma_sers_tab (lv_num_ind);
            EXCEPTION
                WHEN lv_exe_dml_errors
                THEN
                    lv_num_error_count   := SQL%BULK_EXCEPTIONS.COUNT;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Number of statements that failed during Bulk Insert of RMA Request Serials: '
                        || lv_num_error_count);

                    FOR i IN 1 .. lv_num_error_count
                    LOOP
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error #'
                            || i
                            || ' occurred during '
                            || 'iteration #'
                            || SQL%BULK_EXCEPTIONS (i).ERROR_INDEX);
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error message is '
                            || SQLERRM (-SQL%BULK_EXCEPTIONS (i).ERROR_CODE));
                    END LOOP;
                --                              CLOSE cur_serials;
                --                              RAISE l_exe_bulk_insert_failed;
                WHEN OTHERS
                THEN
                    CLOSE cur_serials;

                    p_errbuf   :=
                           'Unexcepted error in BULK Insert of RMA Request Serials : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_errbuf);
                    RAISE lv_exe_bulk_insert_failed;
            END;
        END LOOP;                                -- Receipt details fetch loop

        CLOSE cur_serials;

        -- Update the XML file extract status and commit
        BEGIN
            UPDATE xxdo_ont_rma_xml_stg
               SET process_status = 'PROCESSED', last_update_date = SYSDATE, last_updated_by = lv_num_user_id
             WHERE process_status = 'NEW' AND request_id = g_num_request_id;

            fnd_file.put_line (fnd_file.LOG,
                               'Updated the process status to PROCESSED');
            -- Commit the status update along with all the inserts done before
            COMMIT;
            fnd_file.put_line (fnd_file.LOG,
                               'Commited the staging tables load');
            fnd_file.put_line (fnd_file.LOG, 'End of Loading');
        EXCEPTION
            WHEN OTHERS
            THEN
                p_retcode   := '2';
                p_errbuf    :=
                       'Updating the process status in the XML table failed due to : '
                    || SQLERRM;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Updating the process status in the XML table failed due to : '
                    || SQLERRM);
                ROLLBACK TO l_sv_before_load_rma_req;
        END;

        -- Logic to link the child records

        -- Update the details table
        BEGIN
            UPDATE xxdo_ont_rma_line_stg dtl
               SET dtl.receipt_header_seq_id   =
                       (SELECT receipt_header_seq_id
                          FROM xxdo_ont_rma_hdr_stg headers
                         WHERE     headers.request_id = g_num_request_id
                               AND headers.process_status = 'NEW'
                               AND headers.wh_id = dtl.wh_id
                               AND headers.rma_reference = dtl.rma_reference)
             WHERE     dtl.request_id = g_num_request_id
                   AND dtl.process_status = 'NEW';
        EXCEPTION
            WHEN OTHERS
            THEN
                p_retcode   := '2';
                p_errbuf    :=
                       'Unexpected error while updating the sequence ids in the RMA Request details table : '
                    || SQLERRM;
                fnd_file.put_line (fnd_file.LOG, p_errbuf);
                ROLLBACK TO l_sv_before_load_rma_req;
        END;

        -- Update the serials table
        BEGIN
            UPDATE xxdo_ont_rma_line_serl_stg ser
               SET (ser.receipt_header_seq_id, ser.receipt_line_seq_id)   =
                       (SELECT receipt_header_seq_id, receipt_line_seq_id
                          FROM xxdo_ont_rma_line_stg dtl
                         WHERE     dtl.request_id = g_num_request_id
                               AND dtl.process_status = 'NEW'
                               AND dtl.wh_id = ser.wh_id
                               AND dtl.rma_reference = ser.rma_reference
                               AND dtl.line_number = ser.line_number
                               AND dtl.item_number = ser.item_number)
             WHERE     ser.request_id = g_num_request_id
                   AND ser.process_status = 'NEW';
        EXCEPTION
            WHEN OTHERS
            THEN
                p_retcode   := '2';
                p_errbuf    :=
                       'Unexpected error while updating the sequence ids in the RMA Request serials table : '
                    || SQLERRM;
                fnd_file.put_line (fnd_file.LOG, p_errbuf);
                ROLLBACK TO l_sv_before_load_rma_req;
        END;

        -- Error out the records which don't have parent
        lv_num_error_count   := 0;

        BEGIN
            UPDATE xxdo_ont_rma_line_stg
               SET process_status = 'ERROR', error_message = 'No RMA Request Header Record in XML', last_updated_by = g_num_user_id,
                   last_update_date = SYSDATE
             WHERE     process_status = 'NEW'
                   AND request_id = g_num_request_id
                   AND receipt_header_seq_id IS NULL;

            lv_num_error_count   := SQL%ROWCOUNT;

            UPDATE xxdo_ont_rma_line_serl_stg
               SET process_status = 'ERROR', error_message = 'No RMA Request Detail Parent Record in XML', last_updated_by = g_num_user_id,
                   last_update_date = SYSDATE
             WHERE     process_status = 'NEW'
                   AND request_id = g_num_request_id
                   AND receipt_line_seq_id IS NULL;

            IF lv_num_error_count = 0
            THEN
                lv_num_error_count   := SQL%ROWCOUNT;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_retcode   := '1';
                p_errbuf    :=
                       'Unexpected error while Updating the records without parent : '
                    || SQLERRM;
                fnd_file.put_line (fnd_file.LOG, p_errbuf);
        --                 ROLLBACK TO l_savepoint_before_load;
        END;

        IF lv_num_error_count <> 0
        THEN
            p_retcode   := '1';
            p_errbuf    :=
                'There are detail or serial records without parent records in XML. Please review the XML';
        END IF;

        --Commit all the changes
        COMMIT;
    EXCEPTION
        WHEN lv_exe_env_no_match
        THEN
            p_retcode   := 2;
            p_errbuf    := 'Environment name in XML is not correct';

            UPDATE xxdo_ont_rma_xml_stg
               SET process_status = 'ERROR', error_message = p_errbuf, last_update_date = SYSDATE,
                   last_updated_by = fnd_global.user_id
             WHERE process_status = 'NEW' AND request_id = g_num_request_id;

            fnd_file.put_line (fnd_file.LOG,
                               'Updated the process status to ERROR');
            COMMIT;
        WHEN lv_exe_msg_type_no_match
        THEN
            p_retcode   := 2;
            p_errbuf    := 'Message Type in XML is not correct';

            UPDATE xxdo_ont_rma_xml_stg
               SET process_status = 'ERROR', error_message = p_errbuf, last_update_date = SYSDATE,
                   last_updated_by = fnd_global.user_id
             WHERE process_status = 'NEW' AND request_id = g_num_request_id;

            fnd_file.put_line (fnd_file.LOG,
                               'Updated the process status to ERROR');
            COMMIT;
        WHEN lv_exe_bulk_fetch_failed
        THEN
            p_retcode   := 2;
            ROLLBACK TO l_sv_before_load_rma_req;

            UPDATE xxdo_ont_rma_xml_stg
               SET process_status = 'ERROR', error_message = p_errbuf, last_update_date = SYSDATE,
                   last_updated_by = fnd_global.user_id
             WHERE process_status = 'NEW' AND request_id = g_num_request_id;

            fnd_file.put_line (fnd_file.LOG,
                               'Updated the process status to ERROR');
            COMMIT;
        WHEN lv_exe_bulk_insert_failed
        THEN
            p_retcode   := 2;
            ROLLBACK TO l_sv_before_load_rma_req;

            UPDATE xxdo_ont_rma_xml_stg
               SET process_status = 'ERROR', error_message = p_errbuf, last_update_date = SYSDATE,
                   last_updated_by = fnd_global.user_id
             WHERE process_status = 'NEW' AND request_id = g_num_request_id;

            fnd_file.put_line (fnd_file.LOG,
                               'Updated the process status to ERROR');
            COMMIT;
        WHEN OTHERS
        THEN
            p_retcode   := 2;
            p_errbuf    :=
                   'Unexpected error while extracting the data from XML : '
                || SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected error while extracting the data from XML.'
                || CHR (10)
                || 'Error : '
                || SQLERRM
                || CHR (10)
                || 'Error Code : '
                || SQLCODE);
            ROLLBACK TO l_sv_before_load_rma_req;

            UPDATE xxdo_ont_rma_xml_stg
               SET process_status = 'ERROR', error_message = p_errbuf, last_update_date = SYSDATE,
                   last_updated_by = fnd_global.user_id
             WHERE process_status = 'NEW' AND request_id = g_num_request_id;

            fnd_file.put_line (fnd_file.LOG,
                               'Updated the process status to ERROR');
            COMMIT;
    END extract_xml_data;

    PROCEDURE upload_xml (p_errbuf OUT VARCHAR2, p_retcode OUT NUMBER, p_in_chr_inbound_directory VARCHAR2
                          , p_in_chr_file_name VARCHAR2)
    IS
        lv_bfi_file_location   BFILE;
        lv_num_amount          INTEGER := DBMS_LOB.lobmaxsize;
        lv_clo_xml_doc         CLOB;
        lv_num_warning         NUMBER;
        lv_num_lang_ctx        NUMBER := DBMS_LOB.default_lang_ctx;
        lv_num_src_off         NUMBER := 1;
        lv_num_dest_off        NUMBER := 1;
        lv_xml_doc             XMLTYPE;
        lv_chr_errbuf          VARCHAR2 (2000);
        lv_chr_retcode         NUMBER;
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           'Directory Name: ' || p_in_chr_inbound_directory);
        fnd_file.put_line (fnd_file.LOG, 'File Name: ' || p_in_chr_file_name);
        -- Reading the OS Location for XML Files
        lv_bfi_file_location   :=
            BFILENAME (p_in_chr_inbound_directory, p_in_chr_file_name);
        DBMS_LOB.createtemporary (lv_clo_xml_doc, FALSE);
        DBMS_LOB.OPEN (lv_bfi_file_location, DBMS_LOB.lob_readonly);
        fnd_file.put_line (fnd_file.LOG, 'Loading the file into CLOB');
        DBMS_LOB.loadclobfromfile (lv_clo_xml_doc, lv_bfi_file_location, lv_num_amount, lv_num_src_off, lv_num_dest_off, DBMS_LOB.default_csid
                                   , lv_num_lang_ctx, lv_num_warning);
        DBMS_LOB.CLOSE (lv_bfi_file_location);
        fnd_file.put_line (fnd_file.LOG, 'converting the data into XML type');
        lv_xml_doc   := XMLTYPE (lv_clo_xml_doc);
        DBMS_LOB.freetemporary (lv_clo_xml_doc);
        -- Establish a save point
        -- If error at any stage, rollback to this save point
        -- SAVEPOINT lv_savepoint_before_load;

        fnd_file.put_line (fnd_file.LOG,
                           'Loading the XML file into database');

        BEGIN
            -- Insert statement to upload the XML files
            INSERT INTO xxdo_ont_rma_xml_stg (process_status,
                                              xml_document,
                                              file_name,
                                              request_id,
                                              created_by,
                                              creation_date,
                                              last_updated_by,
                                              last_update_date,
                                              rma_xml_seq_id)
                     VALUES ('NEW',
                             lv_xml_doc,
                             p_in_chr_file_name,
                             fnd_global.conc_request_id,
                             fnd_global.user_id,
                             SYSDATE,
                             fnd_global.user_id,
                             SYSDATE,
                             xxdo_ont_rma_xml_stg_s.NEXTVAL);
        EXCEPTION
            WHEN OTHERS
            THEN
                p_errbuf    :=
                       'Error while Inserting XML file into XML Staging table'
                    || SQLERRM;
                p_retcode   := 2;
        END;

        COMMIT;

        BEGIN
            extract_xml_data (p_errbuf              => lv_chr_errbuf,
                              p_retcode             => lv_chr_retcode,
                              p_in_num_bulk_limit   => 1000);
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'XML data is not loaded into database due to :'
                    || SQLERRM);
                p_retcode   := 2;
                p_errbuf    := SQLERRM;
        END;

        IF lv_chr_retcode = 2
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'XML data is not loaded into database due to :'
                || lv_chr_errbuf);
        ELSIF lv_chr_retcode = 1
        THEN
            fnd_file.put_line (fnd_file.LOG, p_errbuf);
        ELSE
            fnd_file.put_line (fnd_file.LOG,
                               'XML data is loaded into database');
        END IF;

        p_retcode    := lv_chr_retcode;
        p_errbuf     := lv_chr_errbuf;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_retcode   := '2';
            p_errbuf    :=
                   'Unexpected error while loading the XML into database : '
                || SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected error while loading the XML into database.'
                || CHR (10)
                || 'Error : '
                || SQLERRM
                || CHR (10)
                || 'Error Code : '
                || SQLCODE);
    END upload_xml;

    PROCEDURE update_all_records (p_return_status   OUT NUMBER,
                                  p_error_message   OUT VARCHAR2)
    IS
        lv_cnt              NUMBER := 0;
        lv_status           VARCHAR2 (2000);
        lv_error_message    VARCHAR2 (1000);
        lv_process_status   VARCHAR2 (1000);
        lv_retcode          VARCHAR2 (10);
        lv_procedure        VARCHAR2 (100)
                                := g_package_name || '.update_all_records';
    BEGIN
        COMMIT;

        --Update Hold Record
        UPDATE xxdo_ont_rma_hdr_stg hdr
           SET process_status = 'HOLD', error_message = '', result_code = 'H',
               last_updated_by = g_num_user_id, last_update_login = g_num_login_id, last_update_date = SYSDATE
         WHERE     process_status IN ('RMA_CREATED')
               AND result_code = 'C'
               AND request_id = g_num_request_id
               AND EXISTS
                       (SELECT 1
                          FROM oe_order_holds_all ooh, oe_order_headers_all oeh, oe_order_lines_all oel
                         WHERE     ooh.header_id = oeh.header_id
                               AND ooh.released_flag = 'N'
                               AND oeh.order_number = hdr.rma_number
                               AND oeh.header_id = oel.header_id
                               AND ooh.line_id = oel.line_id);

        COMMIT;

        UPDATE xxdo_ont_rma_line_serl_stg serial
           SET process_status = 'HOLD', error_message = '', result_code = 'H',
               last_updated_by = g_num_user_id, last_update_login = g_num_login_id, last_update_date = SYSDATE
         WHERE     request_id = g_num_request_id
               AND process_status = 'INPROCESS'
               AND EXISTS
                       (SELECT 1
                          FROM xxdo_ont_rma_line_stg line
                         WHERE     line.receipt_line_seq_id =
                                   serial.receipt_line_seq_id
                               AND line.request_id = g_num_request_id
                               AND line.process_status = 'HOLD');

        COMMIT;
        -- To send notification for hold records
        mail_hold_report (p_out_chr_errbuf    => lv_error_message,
                          p_out_chr_retcode   => lv_retcode);

        IF lv_retcode <> '0'
        THEN
            p_error_message   := lv_error_message;
            p_return_status   := '1';
            fnd_file.put_line (
                fnd_file.LOG,
                'Unable to send Hold Report due to : ' || p_error_message);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('Error in  ' || lv_procedure || SQLERRM);
            p_return_status   := 2;
            p_error_message   := SQLERRM;
    END;

    PROCEDURE validate_all_records (p_retcode     OUT NUMBER,
                                    p_error_buf   OUT VARCHAR2)
    IS
    BEGIN
        msg ('Validations of all RMA starting');

        /*Update Ship_from_org_id*/
        UPDATE xxdo_ont_rma_line_stg x
           SET ship_from_org_id   =
                   (SELECT organization_id
                      FROM mtl_parameters mp
                     WHERE mp.organization_code = x.wh_id)
         WHERE request_id = g_num_request_id AND result_code IS NULL;

        /*Update Inventory Item Id*/
        UPDATE xxdo_ont_rma_line_stg x
           SET inventory_item_id   =
                   (SELECT msi.inventory_item_id
                      FROM mtl_system_items_kfv msi --Replaced table mtl_system_items with mtl_system_items_kfv for BT Remediation
                     WHERE     msi.organization_id = x.ship_from_org_id
                           /*commented for BT Remediation
                            AND msi.segment1 || '-' || msi.segment2 || '-'
                                 || msi.segment3 = x.item_number)  */
                           AND msi.concatenated_segments = x.item_number) --Added for BT Remediation
         WHERE request_id = g_num_request_id AND result_code IS NULL;

        /*
        *************************************
        Header level validations
        *************************************
        */

        /**Update if Warehouse code is not valid*/
        UPDATE xxdo_ont_rma_hdr_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'Warehouse code is not eligible'
         WHERE     request_id = g_num_request_id
               AND process_status = 'INPROCESS'
               AND x.wh_id NOT IN
                       (SELECT lookup_code
                          FROM fnd_lookup_values fvl
                         WHERE     fvl.lookup_type = 'XXONT_WMS_WHSE'
                               AND NVL (LANGUAGE, USERENV ('LANG')) =
                                   USERENV ('LANG')
                               AND fvl.enabled_flag = 'Y')
               AND result_code IS NULL;

        /**Update if RMA Type is null*/
        UPDATE xxdo_ont_rma_hdr_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'RMA Type cannot be null'
         WHERE     request_id = g_num_request_id
               AND process_status = 'INPROCESS'
               AND rma_type IS NULL
               AND result_code IS NULL;

        COMMIT;

        /**Update if RMA Type is not valid*/
        UPDATE xxdo_ont_rma_hdr_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'RMA Type is not Valid'
         WHERE     request_id = g_num_request_id
               AND process_status = 'INPROCESS'
               AND rma_type NOT IN ('REFUND', 'REPLACE', 'EXCHANGE')
               AND result_code IS NULL;

        COMMIT;

        /**Update if header MISSINGREF valid*/
        UPDATE xxdo_ont_rma_hdr_stg x
           SET process_status   = 'MISSINGREF'
         WHERE     request_id = g_num_request_id
               AND process_status = 'INPROCESS'
               AND order_number_type IS NULL
               AND customer_id IS NULL
               AND result_code IS NULL;

        COMMIT;

        /**Update if RMA Date cannot be null*/
        UPDATE xxdo_ont_rma_hdr_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'RMA date cannot be null'
         WHERE     request_id = g_num_request_id
               AND process_status = 'INPROCESS'
               AND rma_receipt_date IS NULL
               AND result_code IS NULL;

        /**Update if RMA Date is future Date*/
        UPDATE xxdo_ont_rma_hdr_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'RMA date cannot be future date'
         WHERE     request_id = g_num_request_id
               AND process_status = 'INPROCESS'
               AND rma_receipt_date > SYSDATE /*vvap - timezone difference??*/
               AND result_code IS NULL;

        /**Update if Order Number type is null not valid*/
        UPDATE xxdo_ont_rma_hdr_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'RMA reference Order Number Type is Mandatory'
         WHERE     request_id = g_num_request_id
               AND process_status = 'INPROCESS'
               AND order_number IS NOT NULL
               AND order_number_type IS NULL
               AND result_code IS NULL;

        COMMIT;

        UPDATE xxdo_ont_rma_hdr_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'RMA already exists with given RMA reference'
         WHERE     request_id = g_num_request_id
               AND process_status = 'INPROCESS'
               AND EXISTS
                       (SELECT 1
                          FROM oe_order_headers_all oeh, oe_order_sources oos
                         WHERE     oeh.orig_sys_document_ref =
                                   x.rma_reference
                               AND oeh.order_source_id = oos.order_source_id
                               AND oos.NAME = 'WMS');

        UPDATE xxdo_ont_rma_hdr_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'RMA Order Type does not have valid value'
         WHERE     request_id = g_num_request_id
               AND process_status = 'INPROCESS'
               AND order_number_type NOT IN ('WMSORDER', 'CUSTOMERPO', 'HOSTORDER',
                                             'UNKNOWN')
               AND order_number_type IS NOT NULL
               AND result_code IS NULL;

        COMMIT;

        UPDATE xxdo_ont_rma_hdr_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'Customer ID is required if order number type is CUSTOMERPO or UNKNOWN'
         WHERE     request_id = g_num_request_id
               AND process_status = 'INPROCESS'
               AND order_number_type IN ('CUSTOMERPO', 'UNKNOWN')
               AND x.customer_id IS NULL
               AND result_code IS NULL;

        UPDATE xxdo_ont_rma_hdr_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'Customer ID is not valid'
         WHERE     request_id = g_num_request_id
               AND process_status = 'INPROCESS'
               AND order_number_type IN ('CUSTOMERPO', 'UNKNOWN')
               --     AND x.order_number IS NULL
               AND NOT EXISTS
                       (SELECT 1
                          FROM hz_cust_accounts_all hca
                         WHERE     hca.account_number =
                                   TO_CHAR (x.customer_id)
                               AND hca.status = 'A')
               AND result_code IS NULL;

        UPDATE xxdo_ont_rma_hdr_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'RMA already exists with the given RMA reference'
         WHERE     request_id = g_num_request_id
               AND process_status = 'INPROCESS'
               AND EXISTS
                       (SELECT 1
                          FROM oe_order_headers_all ooh, oe_order_sources oos
                         WHERE     oos.order_source_id = ooh.order_source_id
                               AND oos.NAME = 'WMS'
                               AND ooh.orig_sys_document_ref =
                                   x.rma_reference)
               AND result_code IS NULL;

        /*
        *************************************
        Line level validations
        *************************************
        */

        /**Update if Header is in Error*/
        UPDATE xxdo_ont_rma_line_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'RMA header is in error'
         WHERE     request_id = g_num_request_id
               AND process_status = 'INPROCESS'
               AND receipt_header_seq_id IN
                       (SELECT h.receipt_header_seq_id
                          FROM xxdo_ont_rma_hdr_stg h
                         WHERE     h.request_id = g_num_request_id
                               AND h.process_status = 'ERROR')
               AND result_code IS NULL;

        UPDATE xxdo_ont_rma_line_serl_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'RMA header is in error'
         WHERE     request_id = g_num_request_id
               AND process_status = 'INPROCESS'
               AND receipt_header_seq_id IN
                       (SELECT h.receipt_header_seq_id
                          FROM xxdo_ont_rma_hdr_stg h
                         WHERE     h.request_id = g_num_request_id
                               AND h.process_status = 'ERROR')
               AND result_code IS NULL;

        /*Start of DAMAGE_CODE*/
        UPDATE xxdo_ont_rma_line_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'Invalid damaged_code values'
         WHERE     request_id = g_num_request_id
               AND process_status = 'INPROCESS'
               AND damage_code NOT IN
                       (SELECT fvvl.flex_value
                          FROM fnd_flex_value_sets fvs, fnd_flex_values_vl fvvl
                         WHERE     fvs.flex_value_set_name =
                                   'DO_OM_DEFECT_VS'
                               AND fvs.flex_value_set_id =
                                   fvvl.flex_value_set_id
                               AND fvvl.enabled_flag = 'Y')
               AND result_code IS NULL;

        /*Ends of DAMAGE_CODE*/
        /*Update all lines for MISSINGGREF*/
        UPDATE xxdo_ont_rma_line_stg x
           SET process_status   = 'MISSINGREF'
         WHERE     request_id = g_num_request_id
               AND process_status = 'INPROCESS'
               AND EXISTS
                       (SELECT 1
                          FROM xxdo_ont_rma_hdr_stg y
                         WHERE     process_status = 'MISSINGREF'
                               AND request_id = g_num_request_id
                               AND x.rma_reference = y.rma_reference);

        COMMIT;

        /**Update if Item is null*/
        UPDATE xxdo_ont_rma_line_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'Item can not be null'
         WHERE     request_id = g_num_request_id
               AND process_status = 'INPROCESS'
               AND item_number IS NULL
               AND result_code IS NULL;

        /**Update if Item is not valid*/
        UPDATE xxdo_ont_rma_line_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'Invalid Item'
         WHERE     request_id = g_num_request_id
               AND process_status = 'INPROCESS'
               AND NOT EXISTS
                       (SELECT 1
                          FROM mtl_system_items msi
                         WHERE     msi.organization_id = x.ship_from_org_id
                               AND msi.inventory_item_id =
                                   x.inventory_item_id)
               AND result_code IS NULL;

        UPDATE xxdo_ont_rma_line_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'Type should be Unplanned for RA Request'
         WHERE     request_id = g_num_request_id
               AND process_status = 'INPROCESS'
               AND type1 <> 'UNPLANNED'
               AND result_code IS NULL;

        /**Update if Quantity is not valid*/
        UPDATE xxdo_ont_rma_line_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'Invalid quantity'
         WHERE     request_id = g_num_request_id
               AND process_status = 'INPROCESS'
               AND NVL (qty, 0) <= 0
               AND result_code IS NULL;

        /**Update if Return Reason is not valid*/
        UPDATE xxdo_ont_rma_line_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'Invalid return reason'
         WHERE     request_id = g_num_request_id
               AND process_status = 'INPROCESS'
               AND cust_return_reason NOT IN
                       (SELECT lookup_code
                          FROM ar_lookups al
                         WHERE     lookup_type = 'CREDIT_MEMO_REASON'
                               AND enabled_flag = 'Y')
               AND result_code IS NULL;

        /**Update if SubInventory is not valid*/
        UPDATE xxdo_ont_rma_line_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'Invalid subinventory'
         WHERE     request_id = g_num_request_id
               AND process_status = 'INPROCESS'
               AND host_subinventory NOT IN
                       (SELECT secondary_inventory_name
                          FROM mtl_secondary_inventories msi
                         WHERE msi.organization_id = x.ship_from_org_id)
               AND result_code IS NULL;

        /**Update if ar header level reference not found*/
        UPDATE xxdo_ont_rma_line_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'No header reference'
         WHERE     request_id = g_num_request_id
               AND process_status = 'INPROCESS'
               AND NOT EXISTS
                       (SELECT 1
                          FROM xxdo_ont_rma_hdr_stg y
                         WHERE     y.receipt_header_seq_id =
                                   x.receipt_header_seq_id
                               AND y.request_id = g_num_request_id)
               AND result_code IS NULL;

        COMMIT;

        BEGIN
            UPDATE xxdo_ont_rma_line_stg x
               SET rma_receipt_date   =
                       (SELECT rma_receipt_date
                          FROM xxdo_ont_rma_hdr_stg y
                         WHERE     x.rma_reference = y.rma_reference
                               AND x.wh_id = y.wh_id
                               AND y.rma_reference IS NOT NULL
                               AND ROWNUM = 1)
             WHERE     request_id = g_num_request_id
                   AND process_status = 'INPROCESS'
                   AND x.rma_reference IS NOT NULL
                   AND result_code IS NULL;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg ('No records updated at line level' || SQLERRM);
        END;

        COMMIT;

        /*
        *************************************
        Serial level validations
        *************************************
        */
        UPDATE xxdo_ont_rma_line_serl_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'RMA line is in error'
         WHERE     request_id = g_num_request_id
               AND process_status = 'INPROCESS'
               AND x.receipt_line_seq_id IN
                       (SELECT y.receipt_line_seq_id
                          FROM xxdo_ont_rma_line_stg y
                         WHERE     y.request_id = g_num_request_id
                               AND y.process_status = 'ERROR')
               AND result_code IS NULL;

        UPDATE xxdo_ont_rma_line_serl_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'No RMA Line reference'
         WHERE     request_id = g_num_request_id
               AND process_status = 'INPROCESS'
               AND NOT EXISTS
                       (SELECT 1
                          FROM xxdo_ont_rma_line_stg y
                         WHERE     y.receipt_line_seq_id =
                                   x.receipt_line_seq_id
                               AND y.request_id = g_num_request_id)
               AND result_code IS NULL;

        BEGIN
            UPDATE xxdo_ont_rma_line_serl_stg x
               SET process_status = 'ERROR', result_code = 'E', error_message = 'Serial number is null'
             WHERE     request_id = g_num_request_id
                   AND process_status = 'INPROCESS'
                   AND serial_number IS NULL
                   AND result_code IS NULL;

            UPDATE xxdo_ont_rma_line_serl_stg x
               SET organization_id   =
                       (SELECT organization_id
                          FROM mtl_parameters mp
                         WHERE mp.organization_code = x.wh_id)
             WHERE     request_id = g_num_request_id
                   AND process_status = 'INPROCESS'
                   AND result_code IS NULL;

            UPDATE xxdo_ont_rma_line_serl_stg x
               SET inventory_item_id   =
                       (SELECT msi.inventory_item_id
                          FROM mtl_system_items_kfv msi --Replaced table mtl_system_items with mtl_system_items_kfv for BT Remediation
                         WHERE     msi.organization_id = x.organization_id
                               /*commented for BT Remediation
                                 AND    msi.segment1
                                     || '-'
                                     || msi.segment2
                                     || '-'
                                     || msi.segment3 = x.item_number) */
                               AND msi.concatenated_segments = x.item_number) --Added for BT Remediation
             WHERE     request_id = g_num_request_id
                   AND process_status = 'INPROCESS'
                   AND result_code IS NULL;

            COMMIT;

            /*
            *************************************
            QR Validation
            *************************************
            */
            UPDATE xxdo_ont_rma_line_stg line
               SET process_status = 'ERROR', error_message = 'Serial quantity mismatch', result_code = 'E'
             WHERE     xxdo_iid_to_serial (line.inventory_item_id,
                                           line.ship_from_org_id) =
                       'Y'
                   AND line.qty <>
                       (SELECT COUNT (1)
                          FROM xxdo_ont_rma_line_serl_stg serial
                         WHERE     serial.receipt_line_seq_id =
                                   line.receipt_line_seq_id
                               AND serial.process_status = 'INPROCESS'
                               AND serial.request_id = g_num_request_id
                               AND serial.result_code IS NULL)
                   AND line.process_status = 'INPROCESS'
                   AND line.request_id = g_num_request_id
                   AND result_code IS NULL;

            COMMIT;

            /*
            *************************************
            Final error update at all levels
            *************************************
            */
            UPDATE xxdo_ont_rma_line_stg x
               SET process_status = 'ERROR', result_code = 'E', error_message = 'One ore more RMA serial records are in error'
             WHERE     request_id = g_num_request_id
                   AND process_status = 'INPROCESS'
                   AND receipt_header_seq_id IN
                           (SELECT l.receipt_header_seq_id
                              FROM xxdo_ont_rma_line_serl_stg l
                             WHERE     l.request_id = g_num_request_id
                                   AND l.process_status = 'ERROR'
                                   AND ROWNUM = 1);

            UPDATE xxdo_ont_rma_hdr_stg x
               SET process_status = 'ERROR', result_code = 'E', error_message = 'One ore more RMA lines or serials are in error'
             WHERE     request_id = g_num_request_id
                   AND process_status = 'INPROCESS'
                   AND receipt_header_seq_id IN
                           (SELECT l.receipt_header_seq_id
                              FROM xxdo_ont_rma_line_stg l
                             WHERE     l.request_id = g_num_request_id
                                   AND l.process_status = 'ERROR'
                                   AND ROWNUM = 1);

            COMMIT;

            /**Update if Header is in Error*/
            UPDATE xxdo_ont_rma_line_stg x
               SET process_status = 'ERROR', result_code = 'E', error_message = 'One or more lines in this RMA are in error'
             WHERE     request_id = g_num_request_id
                   AND process_status = 'INPROCESS'
                   AND receipt_header_seq_id IN
                           (SELECT h.receipt_header_seq_id
                              FROM xxdo_ont_rma_hdr_stg h
                             WHERE     h.request_id = g_num_request_id
                                   AND h.process_status = 'ERROR')
                   AND result_code IS NULL;

            UPDATE xxdo_ont_rma_line_serl_stg x
               SET process_status = 'ERROR', result_code = 'E', error_message = 'One or more lines or serials in this RMA are in error'
             WHERE     request_id = g_num_request_id
                   AND process_status = 'INPROCESS'
                   AND receipt_header_seq_id IN
                           (SELECT h.receipt_header_seq_id
                              FROM xxdo_ont_rma_hdr_stg h
                             WHERE     h.request_id = g_num_request_id
                                   AND h.process_status = 'ERROR')
                   AND result_code IS NULL;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg ('No records updated at line level' || SQLERRM);
        END;

        COMMIT;
        msg ('End of Validate all records');
    EXCEPTION
        WHEN OTHERS
        THEN
            p_retcode   := 2;
            p_error_buf   :=
                   'Unexpected error while executing Validate all records : '
                || SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected error while executing Validate all records'
                || CHR (10)
                || 'Error : '
                || SQLERRM
                || CHR (10)
                || 'Error Code : '
                || SQLCODE);
    END;

    PROCEDURE mail_hold_report (p_out_chr_errbuf    OUT VARCHAR2,
                                p_out_chr_retcode   OUT VARCHAR2)
    IS
        l_rid_lookup_rec_rowid     ROWID;
        l_chr_from_mail_id         VARCHAR2 (2000);
        l_chr_to_mail_ids          VARCHAR2 (2000);
        --      l_chr_report_last_run_time VARCHAR2(60);
        --      l_dte_report_last_run_time DATE;
        l_num_return_value         NUMBER;
        l_chr_header_sent          VARCHAR2 (1) := 'N';
        l_chr_instance             VARCHAR2 (60);
        l_exe_bulk_fetch_failed    EXCEPTION;
        l_exe_no_interface_setup   EXCEPTION;
        l_exe_mail_error           EXCEPTION;
        l_exe_instance_not_known   EXCEPTION;

        CURSOR cur_error_records IS
              SELECT header.wh_id, line.host_subinventory, header.rma_reference,
                     header.rma_number,                         /*RMA_NUMBER*/
                                        header.rma_receipt_date, header.order_number,
                     header.order_number_type, header.customer_id, header.customer_name,
                     line.line_number, line.item_number, line.type1,
                     line.qty, --                        NVL(line.error_message, header.error_message) error_message,
                               line.cust_return_reason, line.damage_code, /*DAMAGE_CODE*/
                     line.employee_id, line.employee_name, line.creation_date,
                     line.last_update_date
                FROM xxdo_ont_rma_hdr_stg header, xxdo_ont_rma_line_stg line
               WHERE     header.receipt_header_seq_id =
                         line.receipt_header_seq_id
                     AND line.process_status = 'HOLD'
                     AND line.request_id = g_num_request_id
                     AND header.rma_reference IS NOT NULL
            ORDER BY header.wh_id, line.host_subinventory, header.rma_reference,
                     header.rma_receipt_date, header.order_number, line.line_number;

        TYPE l_error_records_tab_type IS TABLE OF cur_error_records%ROWTYPE
            INDEX BY BINARY_INTEGER;

        l_error_records_tab        l_error_records_tab_type;
    BEGIN
        p_out_chr_errbuf    := NULL;
        p_out_chr_retcode   := '0';
        fnd_file.put_line (fnd_file.LOG, '');

        BEGIN
            SELECT instance_name INTO l_chr_instance FROM v$instance;
        EXCEPTION
            WHEN OTHERS
            THEN
                RAISE l_exe_instance_not_known;
        END;

        -- Derive the last report run time, FROM email id and TO email ids
        BEGIN
            SELECT flv.ROWID, flv.attribute10, flv.attribute11
              INTO l_rid_lookup_rec_rowid, l_chr_from_mail_id, l_chr_to_mail_ids
              FROM fnd_lookup_values flv
             WHERE     flv.LANGUAGE = 'US'
                   AND flv.lookup_type = 'XXDO_WMS_INTERFACES_SETUP'
                   AND flv.enabled_flag = 'Y'
                   AND flv.lookup_code = g_chr_rma_request_prgm_name;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Unable to get the inteface setup due to ' || SQLERRM);
                RAISE l_exe_no_interface_setup;
        END;

        -- Convert the FROM email id instance specific
        IF l_chr_from_mail_id IS NULL
        THEN
            l_chr_from_mail_id   := 'WMSInterfacesErrorReporting@deckers.com';
        END IF;

        -- Replace comma with semicolon in TO Ids
        l_chr_to_mail_ids   := TRANSLATE (l_chr_to_mail_ids, ',', ';');

        -- Logic to send the error records
        OPEN cur_error_records;

        LOOP
            IF l_error_records_tab.EXISTS (1)
            THEN
                l_error_records_tab.DELETE;
            END IF;

            BEGIN
                FETCH cur_error_records
                    BULK COLLECT INTO l_error_records_tab
                    LIMIT 1000;
            EXCEPTION
                WHEN OTHERS
                THEN
                    CLOSE cur_error_records;

                    p_out_chr_errbuf   :=
                           'Unexcepted error in BULK Fetch of RMA Request Hold records : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RAISE l_exe_bulk_fetch_failed;
            END;                                           --end of bulk fetch

            IF NOT l_error_records_tab.EXISTS (1)
            THEN
                EXIT;
            END IF;

            IF l_chr_header_sent = 'N'
            THEN
                send_mail_header (l_chr_from_mail_id, l_chr_to_mail_ids, l_chr_instance || ' - RMA Requests on Hold'
                                  , l_num_return_value);

                IF l_num_return_value <> 0
                THEN
                    p_out_chr_errbuf   := 'Unable to send the mail header';
                    RAISE l_exe_mail_error;
                END IF;

                send_mail_line (
                    'Content-Type: multipart/mixed; boundary=boundarystring',
                    l_num_return_value);
                send_mail_line ('--boundarystring', l_num_return_value);
                send_mail_line ('Content-Type: text/plain',
                                l_num_return_value);
                send_mail_line ('', l_num_return_value);
                send_mail_line (
                       'Please refer the attached file for details of RMA requests held in '
                    || l_chr_instance
                    || '.',
                    l_num_return_value);
                send_mail_line (
                       'These were held by the concurrent request id :  '
                    || g_num_request_id,
                    l_num_return_value);
                send_mail_line ('', l_num_return_value);
                send_mail_line ('--boundarystring', l_num_return_value);
                send_mail_line ('Content-Type: text/xls', l_num_return_value);
                send_mail_line (
                    'Content-Disposition: attachment; filename="RMA_request_hold_details.xls"',
                    l_num_return_value);
                send_mail_line ('--boundarystring', l_num_return_value);
                send_mail_line (
                       'Warehouse'
                    || CHR (9)
                    || 'Subinventory'
                    || CHR (9)
                    || 'RMA Reference'
                    || CHR (9)
                    || 'RMA Number'                             /*RMA_NUMBER*/
                    || CHR (9)
                    || 'RMA Request Date'
                    || CHR (9)
                    || 'Order Number'
                    || CHR (9)
                    || 'Order Number Type'
                    || CHR (9)
                    || 'Customer ID'
                    || CHR (9)
                    || 'Customer Name'
                    || CHR (9)
                    || 'Line Number'
                    || CHR (9)
                    || 'Item Number'
                    || CHR (9)
                    || 'Type'
                    || CHR (9)
                    || 'Qty'
                    || CHR (9)
                    || 'Damage Code'                           /*DAMAGE_CODE*/
                    || CHR (9)
                    || 'Return Reason'
                    || CHR (9)
                    || 'Employee ID'
                    || CHR (9)
                    || 'Employee Name'
                    || CHR (9)
                    || 'Received from WMS at'
                    || CHR (9)
                    || 'Processed in EBS at'
                    || CHR (9),
                    l_num_return_value);
                l_chr_header_sent   := 'Y';
            END IF;

            FOR l_num_ind IN l_error_records_tab.FIRST ..
                             l_error_records_tab.LAST
            LOOP
                send_mail_line (
                       l_error_records_tab (l_num_ind).wh_id
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).host_subinventory
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).rma_reference
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).rma_number /*RMA_NUMBER*/
                    || CHR (9)
                    || TO_CHAR (
                           l_error_records_tab (l_num_ind).rma_receipt_date,
                           'DD-Mon-RRRR HH24:MI:SS')
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).order_number
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).order_number_type
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).customer_id
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).customer_name
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).line_number
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).item_number
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).type1
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).qty
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).damage_code /*DAMAGE_CODE*/
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).cust_return_reason
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).employee_id
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).employee_name
                    || CHR (9)
                    || TO_CHAR (
                           l_error_records_tab (l_num_ind).creation_date,
                           'DD-Mon-RRRR HH24:MI:SS')
                    || CHR (9)
                    || TO_CHAR (
                           l_error_records_tab (l_num_ind).last_update_date,
                           'DD-Mon-RRRR HH24:MI:SS')
                    || CHR (9),
                    l_num_return_value);

                IF l_num_return_value <> 0
                THEN
                    p_out_chr_errbuf   :=
                        'Unable to generate the attachment file';
                    RAISE l_exe_mail_error;
                END IF;
            END LOOP;
        END LOOP;                                  -- Error headers fetch loop

        -- Close the cursor
        CLOSE cur_error_records;

        -- Close the mail connection
        send_mail_close (l_num_return_value);

        IF l_num_return_value <> 0
        THEN
            p_out_chr_errbuf   := 'Unable to close the mail connection';
            RAISE l_exe_mail_error;
        END IF;
    EXCEPTION
        WHEN l_exe_mail_error
        THEN
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        WHEN l_exe_no_interface_setup
        THEN
            p_out_chr_errbuf    :=
                'No Interface setup to generate RMA Request hold report';
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        WHEN l_exe_instance_not_known
        THEN
            p_out_chr_errbuf    :=
                'Unable to derive the instance at mail hold report procedure';
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        WHEN l_exe_bulk_fetch_failed
        THEN
            p_out_chr_errbuf    :=
                'Bulk fetch failed at mail hold report procedure';
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        WHEN OTHERS
        THEN
            p_out_chr_errbuf    :=
                   'Unexpected error at mail hold report report procedure : '
                || SQLERRM;
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
    END mail_hold_report;

    PROCEDURE send_mail_header (p_in_chr_msg_from IN VARCHAR2, p_in_chr_msg_to IN VARCHAR2, p_in_chr_msg_subject IN VARCHAR2
                                , p_out_num_status OUT NUMBER)
    IS
        l_num_status              NUMBER := 0;
        l_chr_msg_to              VARCHAR2 (2000) := NULL;
        l_chr_mail_temp           VARCHAR2 (2000) := NULL;
        l_chr_mail_id             VARCHAR2 (255);
        l_num_counter             NUMBER := 0;
        l_exe_conn_already_open   EXCEPTION;
    BEGIN
        IF g_num_connection_flag <> 0
        THEN
            RAISE l_exe_conn_already_open;
        END IF;

        g_smtp_connection       := UTL_SMTP.open_connection ('127.0.0.1');
        g_num_connection_flag   := 1;
        l_num_status            := 1;
        UTL_SMTP.helo (g_smtp_connection, 'localhost');
        UTL_SMTP.mail (g_smtp_connection, p_in_chr_msg_from);


        l_chr_mail_temp         := TRIM (p_in_chr_msg_to);

        IF (INSTR (l_chr_mail_temp, ';', 1) = 0)
        THEN
            l_chr_mail_id   := l_chr_mail_temp;
            fnd_file.put_line (fnd_file.LOG,
                               CHR (10) || 'Email ID: ' || l_chr_mail_id);
            UTL_SMTP.rcpt (g_smtp_connection, TRIM (l_chr_mail_id));
        ELSE
            WHILE (LENGTH (l_chr_mail_temp) > 0)
            LOOP
                IF (INSTR (l_chr_mail_temp, ';', 1) = 0)
                THEN
                    -- Last Mail ID
                    l_chr_mail_id   := l_chr_mail_temp;
                    fnd_file.put_line (
                        fnd_file.LOG,
                        CHR (10) || 'Email ID: ' || l_chr_mail_id);
                    UTL_SMTP.rcpt (g_smtp_connection, TRIM (l_chr_mail_id));
                    EXIT;
                ELSE
                    -- Next Mail ID
                    l_chr_mail_id   :=
                        TRIM (
                            SUBSTR (l_chr_mail_temp,
                                    1,
                                    INSTR (l_chr_mail_temp, ';', 1) - 1));
                    fnd_file.put_line (
                        fnd_file.LOG,
                        CHR (10) || 'Email ID: ' || l_chr_mail_id);
                    UTL_SMTP.rcpt (g_smtp_connection, TRIM (l_chr_mail_id));
                END IF;

                l_chr_mail_temp   :=
                    TRIM (
                        SUBSTR (l_chr_mail_temp,
                                INSTR (l_chr_mail_temp, ';', 1) + 1,
                                LENGTH (l_chr_mail_temp)));
            END LOOP;
        END IF;


        l_chr_msg_to            :=
            '  ' || TRANSLATE (TRIM (p_in_chr_msg_to), ';', ' ');


        UTL_SMTP.open_data (g_smtp_connection);
        l_num_status            := 2;
        UTL_SMTP.write_data (g_smtp_connection,
                             'To: ' || l_chr_msg_to || UTL_TCP.CRLF);
        UTL_SMTP.write_data (g_smtp_connection,
                             'From: ' || p_in_chr_msg_from || UTL_TCP.CRLF);
        UTL_SMTP.write_data (
            g_smtp_connection,
            'Subject: ' || p_in_chr_msg_subject || UTL_TCP.CRLF);

        p_out_num_status        := 0;
    EXCEPTION
        WHEN l_exe_conn_already_open
        THEN
            p_out_num_status   := -2;
        WHEN OTHERS
        THEN
            IF l_num_status = 2
            THEN
                UTL_SMTP.close_data (g_smtp_connection);
            END IF;

            IF l_num_status > 0
            THEN
                UTL_SMTP.quit (g_smtp_connection);
            END IF;

            g_num_connection_flag   := 0;
            p_out_num_status        := -255;
    END send_mail_header;


    PROCEDURE send_mail_line (p_in_chr_msg_text   IN     VARCHAR2,
                              p_out_num_status       OUT NUMBER)
    IS
        l_exe_not_connected   EXCEPTION;
    BEGIN
        IF g_num_connection_flag = 0
        THEN
            RAISE l_exe_not_connected;
        END IF;

        UTL_SMTP.write_data (g_smtp_connection,
                             p_in_chr_msg_text || UTL_TCP.CRLF);

        p_out_num_status   := 0;
    EXCEPTION
        WHEN l_exe_not_connected
        THEN
            p_out_num_status   := -2;
        WHEN OTHERS
        THEN
            p_out_num_status   := -255;
    END send_mail_line;

    PROCEDURE send_mail_close (p_out_num_status OUT NUMBER)
    IS
        l_exe_not_connected   EXCEPTION;
    BEGIN
        IF g_num_connection_flag = 0
        THEN
            RAISE l_exe_not_connected;
        END IF;

        UTL_SMTP.close_data (g_smtp_connection);
        UTL_SMTP.quit (g_smtp_connection);

        g_num_connection_flag   := 0;
        p_out_num_status        := 0;
    EXCEPTION
        WHEN l_exe_not_connected
        THEN
            p_out_num_status   := 0;
        WHEN OTHERS
        THEN
            p_out_num_status        := -255;
            g_num_connection_flag   := 0;
    END send_mail_close;

    --------------------------------------------------------------------------------
    -- PROCEDURE  : main_validate
    -- Description: PROCEDURE will be called to perform various validations on
    --              different rma headers and lines
    --------------------------------------------------------------------------------
    PROCEDURE main_validate (errbuf OUT VARCHAR2, retcode OUT NUMBER, p_wh_code IN VARCHAR2, p_rma_ref IN VARCHAR2, p_source IN VARCHAR2 DEFAULT 'WMS', p_destination IN VARCHAR2 DEFAULT 'EBS'
                             , p_purge_days IN NUMBER DEFAULT 30, p_debug IN VARCHAR2 DEFAULT 'Y', p_leap_days IN NUMBER DEFAULT 30)
    IS
        -----------------Declaration of Local Variables
        lv_procedure             VARCHAR2 (100) := '.main_validate';
        lv_operation_name        VARCHAR2 (100);
        lv_retcode               NUMBER;
        lv_error_buf             VARCHAR2 (2000);
        lv_count                 NUMBER;
        lv_row                   NUMBER := 1;
        lv_group_id              NUMBER := -1;
        lv_org                   VARCHAR (5);
        lv_rma_ref               VARCHAR (10);
        lv_line_id               NUMBER;
        lv_header_id             NUMBER;
        lv_header_id_n           NUMBER;
        lv_hdr_row               NUMBER := 1;
        lv_ret_cnt               VARCHAR2 (100);
        lv_total_cnt             NUMBER;
        lv_ship_to_org_id        NUMBER;
        lv_invoice_to_org_id     NUMBER;
        lv_cust_ship_to_org_id   NUMBER;
        lv_exe_lock_err          EXCEPTION;
        lv_exe_val_err           EXCEPTION;
        lv_pro_rec               NUMBER := 0;
    ----------------------------------------------
    BEGIN
        -----------------------------------------------------------------
        lv_operation_name   := 'Writing to log file';
        -----------------------------------------------------------------
        fnd_file.put_line (fnd_file.LOG, 'p_rma_ref->' || p_rma_ref);
        fnd_file.put_line (fnd_file.LOG, 'p_source->' || p_source);
        fnd_file.put_line (fnd_file.LOG, 'p_destination->' || p_destination);
        fnd_file.put_line (fnd_file.LOG, 'p_purge_days->' || p_purge_days);

        IF p_debug = 'Y'
        THEN
            g_num_debug   := 1;
        ELSE
            g_num_debug   := 0;
        END IF;

        -----------------------------------------------------------------
        lv_operation_name   := 'Purging Data from staging tables';
        -----------------------------------------------------------------
        /* Delete history data from staging tables */
        --purge_data (p_purge_days);                  --commented for version 1.1
        /* Delete archive and purge data from staging tables */
        /*Start of PURGE_ARCHIVE*/
        /*    purge_archive (lv_retcode,
                               lv_error_buf,
                               p_purge_days);
      /*End of PURGE_ARCHIVE*/

        -----------------------------------------------------------------
        lv_operation_name   := 'Set all the records to In Process status';
        -----------------------------------------------------------------
        msg (lv_operation_name);

        /*update records by setting them to INPROCESS*/
        BEGIN
            set_in_process (lv_retcode, lv_error_buf, lv_total_cnt,
                            p_wh_code, p_rma_ref);

            IF lv_retcode <> 0
            THEN
                errbuf   := 'Error in Set In process : ' || lv_error_buf;
                msg (errbuf);
                RAISE lv_exe_lock_err;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                retcode   := 2;
                errbuf    :=
                       'Unexpected error while invoking lock records procedure : '
                    || SQLERRM;
                fnd_file.put_line (fnd_file.LOG, errbuf);
                RAISE lv_exe_lock_err;
        END;

        IF NVL (lv_total_cnt, 0) = 0
        THEN
            errbuf   := 'There are no elligible records to process';
        ELSE
            -----------------------------------------------------------------
            lv_operation_name   := 'Validate All RMA records';

            -----------------------------------------------------------------

            /*Validate ALL RMA Records*/
            BEGIN
                validate_all_records (lv_retcode, lv_error_buf);

                IF lv_retcode <> 0
                THEN
                    errbuf   :=
                        'Error in Validate all records : ' || lv_error_buf;
                    msg (errbuf);
                    RAISE lv_exe_val_err;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    retcode   := 2;
                    errbuf    :=
                           'Unexpected error while invoking validate records procedure : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, errbuf);
                    RAISE lv_exe_val_err;
            END;

            -----------------------------------------------------------------
            lv_operation_name   :=
                'Processing Logic Create Unplanned RMA begins here';

            -----------------------------------------------------------------
            UPDATE xxdo_ont_rma_hdr_stg
               SET result_code   = 'P'
             WHERE     request_id = g_num_request_id
                   AND process_status = 'INPROCESS';

            UPDATE xxdo_ont_rma_line_stg
               SET result_code   = 'P'
             WHERE     request_id = g_num_request_id
                   AND process_status = 'INPROCESS';

            COMMIT;

            BEGIN
                create_unplan_rma (p_leap_days, lv_retcode, lv_error_buf);
            EXCEPTION
                WHEN OTHERS
                THEN
                    msg (
                           'Error while create_unplan_rma_line: '
                        || lv_error_buf);
                    retcode   := 2;
                    errbuf    := lv_error_buf;
            END;

            BEGIN
                update_all_records (lv_retcode, lv_error_buf);
            EXCEPTION
                WHEN OTHERS
                THEN
                    msg (
                        'Error while updating all records: ' || lv_error_buf);
                    retcode   := 2;
                    errbuf    := lv_error_buf;
            END;
        END IF;
    EXCEPTION
        WHEN lv_exe_lock_err
        THEN
            retcode   := 2;
            errbuf    := errbuf;
        WHEN lv_exe_val_err
        THEN
            retcode   := 2;
            errbuf    := errbuf;
        WHEN OTHERS
        THEN
            retcode   := 2;
            errbuf    := SQLERRM;
            msg (
                   'ERROR in procedure '
                || lv_procedure
                || '--'
                || retcode
                || '--'
                || errbuf);
            msg (SQLERRM);
    END main_validate;
END xxdo_ont_rma_request_pkg;
/
