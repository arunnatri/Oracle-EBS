--
-- XXDO_ONT_RMA_RECEIPT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:26 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_ONT_RMA_RECEIPT_PKG"
AS
    /*
    **********************************************************************************************
    $Header:  xxdo_ont_rma_receipt_pkg.sql   1.0    2014/07/31   10:00:00   Infosys $
    **********************************************************************************************
    */
    -- ***************************************************************************
    --                (c) Copyright Deckers Outdoor Corp.
    --                    All rights reserved
    -- ***************************************************************************
    --
    -- Package Name :  xxdo_ont_rma_receipt_pkg
    --
    -- Description  :  This is package  for WMS to EBS Return Receiving Inbound Interface
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- Date          Author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 18-Aug-2014    Infosys            1.0       Created
    -- 31-Dec-2014    Infosys            2.0      Modified for BT Remediation
    -- 02-Feb-2015    Infosys            2.1      Addtion of CR - DAMAGE_CODE and Archive Logic(PURGE_ARCHIVE)
    --                                                             - FACTORY_CODE,PROD_CODE
    -- 10-Apr-2015    Infosys            2.2      Single Org OU_BUG Issue
    --21-Sep-2015     Infosys            1.3      RA with past receipt date ;Identified with PAST_RECEIPT
    --                                                      Error  record deleted from RCV_TRANSACTIONS_INTERFACE ;Identified with DELETE_TRAN
    --01-Oct-2015     Infosys             1.4      Unplanned line set to null even of HJ sends line number;identified with UNPLAN_NULL
    --25-May-2017  Infosys    1.5   Modification as per CCR CCR0006313 for Ra lines stuck in NEW status; Identified with RA_NEW_STUCK
    --15-May-2019     Tejaswi Gangumalla  1.6      Modification as per CCR CCR0007954 for file processing issue
    -- ***************************************************************************

    --------------------------
    --Declare global variables
    --
    --------------------------------------------------------------------------------
    -- PROCEDURE  : msg
    -- Description: PROCEDURE to print debug messages
    --------------------------------------------------------------------------------
    g_package_name       VARCHAR2 (240) := 'XXDO_ONT_RMA_RECEIPT_PKG';
    /*FACTORY_CODE,PROD_CODE varibable Declarations*/
    g_chr_f_col_name     VARCHAR2 (100);
    g_chr_f_tname_name   VARCHAR2 (100);
    g_chr_f_whr_clause   VARCHAR2 (2000);


    g_chr_p_col_name     VARCHAR2 (100);
    g_chr_p_tname_name   VARCHAR2 (100);
    g_chr_p_whr_clause   VARCHAR2 (2000);

    /*Ends FACTORY_CODE,PROD_CODE varibable Declarations*/

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

    /*commented purge_data and added purge_archive start*/
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
       END purge_data;              */
    /*commented purge_data and added purge_archive END*/
    /*Added purge_archive procedure start*/
    /*OU_BUG*/
    /** ****************************************************************************
   -- Procedure Name      :  get_resp_details
   --
   -- Description         :  This procedure is to archive and purge the old records


   -- Parameters          : p_resp_id      OUT : Responsibility ID
   --                              p_resp_appl_id     OUT : Application ID
   -
   -- Return/Exit         :  none
   --
   --
   -- DEVELOPMENT and MAINTENANCE HISTORY
   --
   -- date          author             Version  Description
   -- ------------  -----------------  -------

   --------------------------------
   -- 2015/04/01 Infosys            1.0  Initial Version.
   --
   --
   ***************************************************************************/
    PROCEDURE get_resp_details (p_org_id IN NUMBER, p_module_name IN VARCHAR2, p_resp_id OUT NUMBER
                                , p_resp_appl_id OUT NUMBER)
    IS
        lv_mo_resp_id           NUMBER;
        lv_mo_resp_appl_id      NUMBER;
        lv_const_om_resp_name   VARCHAR2 (200)
                                    := 'Order Management Super User - ';
        lv_const_po_resp_name   VARCHAR2 (200) := 'Purchasing Super User - ';
        lv_const_ou_name        VARCHAR2 (200);
        lv_var_ou_name          VARCHAR2 (200);
    BEGIN
        IF p_module_name = 'ONT'
        THEN
            BEGIN
                SELECT resp.responsibility_id, resp.application_id, resp.responsibility_name
                  INTO lv_mo_resp_id, lv_mo_resp_appl_id, lv_const_po_resp_name
                  FROM fnd_lookup_values flv, hr_operating_units hou, fnd_responsibility_vl resp
                 WHERE     flv.lookup_code = UPPER (hou.name)
                       AND flv.lookup_type = 'XXDO_APPL_RESP_SETUP'
                       AND flv.enabled_flag = 'Y'
                       AND language = 'US'
                       AND hou.organization_id = p_org_id
                       AND flv.description = resp.responsibility_name
                       AND end_date_active IS NULL
                       AND end_date IS NULL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_resp_id        := NULL;
                    p_resp_appl_id   := NULL;
            END;
        ELSIF p_module_name = 'PO'
        THEN
            BEGIN
                SELECT resp.responsibility_id, resp.application_id, resp.responsibility_name
                  INTO lv_mo_resp_id, lv_mo_resp_appl_id, lv_const_po_resp_name
                  FROM fnd_lookup_values flv, hr_operating_units hou, fnd_responsibility_vl resp
                 WHERE     flv.lookup_code = UPPER (hou.name)
                       AND flv.lookup_type = 'XXDO_APPL_RESP_SETUP'
                       AND flv.enabled_flag = 'Y'
                       AND language = 'US'
                       AND hou.organization_id = p_org_id
                       AND meaning = resp.responsibility_name
                       AND end_date_active IS NULL
                       AND end_date IS NULL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_resp_id        := NULL;
                    p_resp_appl_id   := NULL;

                    BEGIN
                        SELECT resp.responsibility_id, resp.application_id, resp.responsibility_name
                          INTO lv_mo_resp_id, lv_mo_resp_appl_id, lv_const_po_resp_name
                          FROM fnd_responsibility_vl resp
                         WHERE responsibility_name =
                               fnd_profile.VALUE ('XXDO_PO_RESP_NAME');
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_mo_resp_id           := NULL;
                            lv_mo_resp_appl_id      := NULL;
                            lv_const_po_resp_name   := NULL;
                    END;
            END;
        END IF;

        msg (
               'Responsbility Application Id '
            || lv_mo_resp_appl_id
            || '-'
            || lv_mo_resp_id);

        msg (
               'Responsbility Details '
            || p_module_name
            || '-'
            || lv_const_po_resp_name);
        p_resp_id        := lv_mo_resp_id;
        p_resp_appl_id   := lv_mo_resp_appl_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_resp_id        := NULL;
            p_resp_appl_id   := NULL;
    END get_resp_details;

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
    -- 2016/07/12 Infosys            1.1 Purge Not error records
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
                                                  archive_date,
                                                  message_id)
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
                       g_num_request_id, l_dte_sysdate, message_id
                  FROM xxdo_ont_rma_hdr_stg hdr
                 WHERE     TRUNC (creation_date) <
                           TRUNC (l_dte_sysdate) - p_purge
                       /***********************************************************************/
                       /*Infosys Ver 1.1: Purge only processed and marked processed records;  */
                       /*                   condition to check records not in error status    */
                       /***********************************************************************/

                       AND process_status = 'PROCESSED'
                       AND NOT EXISTS
                               (SELECT 1
                                  FROM apps.xxdo_ont_rma_line_stg LN
                                 WHERE     LN.receipt_header_seq_id =
                                           hdr.receipt_header_seq_id
                                       AND LN.process_status = 'ERROR');



            DELETE FROM
                xxdo_ont_rma_hdr_stg hdr
                  WHERE     TRUNC (creation_date) <
                            TRUNC (l_dte_sysdate) - p_purge
                        /***********************************************************************/
                        /*Infosys Ver 1.1: Purge only processed and marked processed records;  */
                        /*                   condition to check records not in error status    */
                        /***********************************************************************/

                        AND process_status = 'PROCESSED'
                        AND NOT EXISTS
                                (SELECT 1
                                   FROM apps.xxdo_ont_rma_line_stg LN
                                  WHERE     LN.receipt_header_seq_id =
                                            hdr.receipt_header_seq_id
                                        AND LN.process_status = 'ERROR');



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
                 WHERE     TRUNC (creation_date) <
                           TRUNC (l_dte_sysdate) - p_purge
                       AND process_status = 'PROCESSED';



            DELETE FROM
                xxdo_ont_rma_line_stg
                  WHERE     TRUNC (creation_date) <
                            TRUNC (l_dte_sysdate) - p_purge
                        AND process_status = 'PROCESSED';



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
                 WHERE     TRUNC (creation_date) <
                           TRUNC (l_dte_sysdate) - p_purge
                       AND process_status = 'PROCESSED';

            DELETE FROM
                xxdo_ont_rma_line_serl_stg
                  WHERE     TRUNC (creation_date) <
                            TRUNC (l_dte_sysdate) - p_purge
                        AND process_status = 'PROCESSED';

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
                                                  , archive_date, message_id)
                SELECT process_status, xml_document, file_name,
                       error_message, request_id, creation_date,
                       created_by, last_update_date, last_updated_by,
                       record_type, rma_xml_seq_id, g_num_request_id,
                       l_dte_sysdate, message_id
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
    /*   DELETE FROM xxdo.xxdo_ont_rma_hdr_stg
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
       msg ('No of rows purged from XXDO_ONT_RMA_XML_STG ' || SQL%ROWCOUNT); */
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Error occured in PROCEDURE  '
                || lv_procedure
                || '-'
                || SQLERRM);
            p_errbuf    := SQLERRM;
            p_retcode   := 2;
    END purge_archive;

    /*Added purge_archive procedure END*/
    PROCEDURE set_in_process (p_retcode OUT NUMBER, p_error_buf OUT VARCHAR2, p_total_count OUT NUMBER
                              , p_wh_code VARCHAR2, p_rma_no VARCHAR2)
    IS
        lv_tot_count   NUMBER := 0;
    BEGIN
        p_error_buf     := NULL;
        p_retcode       := '0';

        UPDATE xxdo_ont_rma_hdr_stg
           SET process_status = 'INPROCESS', request_id = g_num_request_id, last_updated_by = g_num_user_id,
               last_update_date = SYSDATE
         WHERE     process_status IN ('NEW')
               AND rma_number = NVL (p_rma_no, rma_number)
               AND wh_id = NVL (p_wh_code, wh_id)
               AND rma_number IS NOT NULL;

        msg ('No of headers updated  to INPROCESS ' || SQL%ROWCOUNT);
        p_total_count   := SQL%ROWCOUNT;
        lv_tot_count    := p_total_count + lv_tot_count;


        /*Start with UNPLAN_NULL*/
        /* line ID needs to be null for unplanned lines - 10/1/2015 */
        UPDATE xxdo_ont_rma_line_stg
           SET line_number   = -1
         WHERE     process_status IN ('NEW')
               AND rma_number = NVL (p_rma_no, rma_number)
               AND wh_id = NVL (p_wh_code, wh_id)
               AND rma_number IS NOT NULL
               AND type1 = 'UNPLANNED'
               AND line_number > 0;

        /*End with UNPLAN_NULL*/

        -- COMMIT;
        UPDATE xxdo_ont_rma_line_stg
           SET process_status = 'INPROCESS', request_id = g_num_request_id, last_updated_by = g_num_user_id,
               last_update_date = SYSDATE, line_id = NVL (line_id, line_number)
         WHERE     process_status IN ('NEW')
               AND rma_number = NVL (p_rma_no, rma_number)
               AND wh_id = NVL (p_wh_code, wh_id)
               AND rma_number IS NOT NULL;

        msg ('No of lines updated   to INPROCESS ' || SQL%ROWCOUNT);
        -- p_total_count := SQL%ROWCOUNT ;
        --     commit;
        p_total_count   := SQL%ROWCOUNT;
        lv_tot_count    := p_total_count + lv_tot_count;

        UPDATE xxdo_ont_rma_hdr_stg hdr
           SET process_status = 'INPROCESS', request_id = g_num_request_id, last_updated_by = g_num_user_id,
               last_update_date = SYSDATE                                  --,
         --   result_code = decode(process_status,'HOLD','A','')
         WHERE     process_status IN ('HOLD')
               AND rma_number = NVL (p_rma_no, rma_number)
               AND wh_id = NVL (p_wh_code, wh_id)
               AND EXISTS
                       (SELECT 1
                          FROM oe_order_holds_all ooh, oe_order_headers_all oeh, oe_order_lines_all oel
                         WHERE     ooh.header_id = oeh.header_id
                               AND ooh.released_flag = 'Y'
                               AND oeh.order_number = rma_number
                               AND oeh.header_id = oel.header_id
                               AND ooh.line_id = oel.line_id)
               AND rma_number IS NOT NULL;

        msg ('No of headers-1 updated  to INPROCESS ' || SQL%ROWCOUNT);
        p_total_count   := SQL%ROWCOUNT;
        lv_tot_count    := p_total_count + lv_tot_count;

        UPDATE xxdo_ont_rma_line_stg line
           SET process_status = 'INPROCESS', request_id = g_num_request_id, last_updated_by = g_num_user_id,
               last_update_date = SYSDATE, line_id = NVL (line_id, line_number)
         WHERE     process_status IN ('HOLD')
               AND rma_number = NVL (p_rma_no, rma_number)
               AND wh_id = NVL (p_wh_code, wh_id)
               AND EXISTS
                       (SELECT 1
                          FROM oe_order_holds_all ooh
                         WHERE     ooh.line_id = line.line_number
                               AND ooh.released_flag = 'Y')
               AND rma_number IS NOT NULL;

        msg ('No of lines-1 updated to INPROCESS ' || SQL%ROWCOUNT);
        p_total_count   := SQL%ROWCOUNT;
        lv_tot_count    := p_total_count + lv_tot_count;
        msg (
               'No of rows updated  from XXDO_ONT_RMA_LINE_STG to INPROCESS '
            || SQL%ROWCOUNT);

        UPDATE xxdo_ont_rma_line_serl_stg
           SET process_status = 'INPROCESS', request_id = g_num_request_id, last_updated_by = g_num_user_id,
               last_update_date = SYSDATE
         --      result_code = decode(process_status,'HOLD','A','')
         WHERE     receipt_line_seq_id IN
                       (SELECT l.receipt_line_seq_id
                          FROM xxdo_ont_rma_line_stg l
                         WHERE     l.request_id = g_num_request_id
                               AND l.process_status = 'INPROCESS')
               AND rma_number IS NOT NULL;

        msg ('No of serials updated to INPROCESS ' || SQL%ROWCOUNT);

        IF lv_tot_count <> 0
        THEN
            p_total_count   := lv_tot_count;
        ELSE
            p_total_count   := 0;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_retcode     := 2;
            p_error_buf   := SQLERRM;
    END set_in_process;

    PROCEDURE validate_line (p_return_status   OUT NUMBER,
                             p_error_message   OUT VARCHAR2)
    IS
        /*Line CURSOR RMA*/
        CURSOR cur_spl_rma_line IS
              SELECT DISTINCT rma_line.line_number, oel.line_id, oel.header_id,
                              oel.line_number OE_LINE_NUMBER, --<Ver 1.1 : Get Order line number>
                                                              oel.ORDERED_ITEM, --<Ver 1.1 : Get Order line number>
                                                                                oel.ordered_quantity,
                              rma_line.qty, receipt_line_seq_id, rma_line.process_status,
                              oel.flow_status_code order_line_status
                FROM xxdo_ont_rma_line_stg rma_line, oe_order_lines_all oel, oe_order_headers_all oeh
               WHERE     rma_line.process_status IN ('INPROCESS')
                     AND rma_line.request_id = g_num_request_id
                     AND EXISTS
                             (SELECT 1
                                FROM fnd_lookup_values
                               WHERE     lookup_type = 'XXONT_WMS_WHSE'
                                     AND NVL (LANGUAGE, USERENV ('LANG')) =
                                         USERENV ('LANG')
                                     AND enabled_flag = 'Y'
                                     AND lookup_code = rma_line.wh_id)
                     AND rma_line.rma_number = oeh.order_number
                     AND oeh.header_id = oel.header_id
                     AND rma_line.line_number = oel.line_id
            ORDER BY oel.ordered_item, rma_line.receipt_line_seq_id, oel.line_id;

        --   and  rma_line.rma_number=nvl(p_rma_num,rma_line.rma_number)
        lv_pn                  VARCHAR2 (240)
                                   := SUBSTR (g_package_name || '.VALIDATE_LINE', 1, 240);
        lv_row_cnt             NUMBER := 0;
        lv_num_index           NUMBER;
        lv_temp_line_id        NUMBER;
        lv_flow_status_code    VARCHAR (50);
        lv_num_qty             NUMBER;
        l_split_count          NUMBER := 0;
        --  l_split_count_hdr      NUMBER;
        ex_invaild_line_id     EXCEPTION;
        ex_already_processed   EXCEPTION;
    BEGIN
        p_error_message   := NULL;
        p_return_status   := 0;                               --g_ret_success;

        FOR rec_cur_rma_line_rec IN cur_spl_rma_line
        LOOP
            lv_num_index          := lv_num_index + 1;
            lv_temp_line_id       := NULL;
            lv_flow_status_code   := NULL;

            /***********************************************************************/
            /*Infosys Ver 1.1: Commenting below code and identifying open line  ;  */
            /*                   Based on line number in order line table          */
            /***********************************************************************/


            msg (
                   'WMS line number: '
                || rec_cur_rma_line_rec.line_id
                || ';Status= '
                || rec_cur_rma_line_rec.order_line_status);

            FOR i IN 1 .. 50
            LOOP
                IF rec_cur_rma_line_rec.order_line_status = 'AWAITING_RETURN'
                THEN
                    EXIT;
                END IF;

                BEGIN
                    SELECT line_id, flow_status_code
                      INTO lv_temp_line_id, lv_flow_status_code
                      FROM oe_order_lines_all
                     WHERE     header_id = rec_cur_rma_line_rec.header_id
                           AND split_from_line_id =
                               rec_cur_rma_line_rec.line_number;

                    msg (
                           'Temp Id and Flow status Code'
                        || lv_temp_line_id
                        || '-'
                        || lv_flow_status_code);
                    rec_cur_rma_line_rec.line_number   := lv_temp_line_id;
                    rec_cur_rma_line_rec.order_line_status   :=
                        lv_flow_status_code;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_flow_status_code   := NULL;
                        lv_temp_line_id       := NULL;
                        EXIT;
                END;
            END LOOP;


            msg (
                   'Processing Line ID='
                || rec_cur_rma_line_rec.line_number
                || ';Status= '
                || rec_cur_rma_line_rec.order_line_status
                || ';Line Seq ID='
                || rec_cur_rma_line_rec.receipt_line_seq_id
                || ';Qty='
                || rec_cur_rma_line_rec.qty
                || ';Process Status'
                || rec_cur_rma_line_rec.process_status
                || '; OLD Line_ID='
                || rec_cur_rma_line_rec.line_id);

            IF rec_cur_rma_line_rec.order_line_status != 'AWAITING_RETURN'
            THEN
                BEGIN
                    SELECT line_id, flow_status_code
                      INTO lv_temp_line_id, lv_flow_status_code
                      FROM oe_order_lines_all line
                     WHERE     header_id = rec_cur_rma_line_rec.header_id
                           AND line_number =
                               rec_cur_rma_line_rec.OE_LINE_NUMBER
                           AND flow_status_code = 'AWAITING_RETURN'
                           AND NOT EXISTS
                                   (SELECT 1
                                      FROM oe_order_holds_all ooh
                                     WHERE     ooh.line_id = line.line_id
                                           AND NVL (ooh.released_flag, 'N') =
                                               'N');

                    msg (
                           'Temp Id and Flow status Code'
                        || lv_temp_line_id
                        || '-'
                        || lv_flow_status_code);
                    rec_cur_rma_line_rec.line_number   := lv_temp_line_id;
                    rec_cur_rma_line_rec.order_line_status   :=
                        lv_flow_status_code;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_flow_status_code   := NULL;
                        lv_temp_line_id       := NULL;
                END;
            END IF;



            IF rec_cur_rma_line_rec.order_line_status <> 'AWAITING_RETURN'
            THEN
                /***********************************************************************/
                /*Infosys Ver 1.1: If there is no open line then create new line    ;  */
                /*                   Mark record type as UNPLANNED to create new line  */
                /***********************************************************************/

                /*UPDATE xxdo_ont_rma_line_stg
                        process_status = 'ERROR',
                       result_code = 'E',
                                          error_message = 'No Open quantity on RMA line'
                                WHERE     receipt_line_seq_id =
                              rec_cur_rma_line_rec.receipt_line_seq_id
                       AND request_id = g_num_request_id;*/

                UPDATE xxdo_ont_rma_line_stg
                   SET type1 = 'UNPLANNED', Line_number = -1, result_code = NULL
                 WHERE     receipt_line_seq_id =
                           rec_cur_rma_line_rec.receipt_line_seq_id
                       AND request_id = g_num_request_id;
            ELSE
                IF rec_cur_rma_line_rec.line_number <>
                   rec_cur_rma_line_rec.line_id
                THEN
                    BEGIN
                        SELECT ordered_quantity
                          INTO rec_cur_rma_line_rec.ordered_quantity
                          FROM oe_order_lines_all
                         WHERE line_id = rec_cur_rma_line_rec.line_number;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'error while deriving qty for line ID : '
                                || rec_cur_rma_line_rec.line_number
                                || ' Error: '
                                || SQLERRM);
                            rec_cur_rma_line_rec.ordered_quantity   := 0;
                    END;
                END IF;

                IF rec_cur_rma_line_rec.qty >
                   rec_cur_rma_line_rec.ordered_quantity
                THEN
                    msg ('Open Quantity is less than received Quantity');

                    /***********************************************************************/
                    /*Infosys Ver 1.1:   No sufficient quantity then create new line    ;  */
                    /*                   Mark record type as UNPLANNED to create new line  */
                    /***********************************************************************/

                    /* UPDATE xxdo_ont_rma_line_stg
                        SET process_status = 'ERROR',
                            result_code = 'E',
                            error_message =
                               'Open Quantity is less than received Quantity'
                      WHERE     receipt_line_seq_id =
                                   rec_cur_rma_line_rec.receipt_line_seq_id
                            AND request_id = g_num_request_id;*/

                    UPDATE xxdo_ont_rma_line_stg
                       SET type1 = 'UNPLANNED', Line_number = -1, result_code = NULL
                     WHERE     receipt_line_seq_id =
                               rec_cur_rma_line_rec.receipt_line_seq_id
                           AND request_id = g_num_request_id;



                    COMMIT;
                ELSE
                    msg (
                        'Updating line number to :' || rec_cur_rma_line_rec.line_number);

                    UPDATE xxdo_ont_rma_line_stg
                       SET line_number   = rec_cur_rma_line_rec.line_number
                     WHERE     process_status IN ('INPROCESS')
                           AND receipt_line_seq_id =
                               rec_cur_rma_line_rec.receipt_line_seq_id
                           AND request_id = g_num_request_id;

                    msg ('Updated Line Number count =' || SQL%ROWCOUNT);

                    /***********************************************************************/
                    /*Infosys Ver 1.1:   To avoid subroutine error RVTPT-020 ; Processing  */
                    /*                   only one line for given split line ID             */
                    /***********************************************************************/


                    msg (
                           'Marking Error for line with same  LINE ID :'
                        || rec_cur_rma_line_rec.Line_id);

                    l_split_count   := 0;

                    BEGIN
                        SELECT COUNT (1)
                          INTO l_split_count
                          FROM xxdo_ont_rma_line_stg x
                         WHERE     request_id = g_num_request_id
                               AND process_status = 'INPROCESS'
                               AND receipt_line_seq_id !=
                                   rec_cur_rma_line_rec.receipt_line_seq_id
                               AND line_number = rec_cur_rma_line_rec.line_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_split_count   := -1;
                    END;

                    /*Only if more than one line available for same sequence ID mark it as SPLIT and later error*/
                    IF l_split_count > 0
                    THEN
                        UPDATE xxdo_ont_rma_line_stg x
                           SET process_status = 'SPLIT', error_message = 'Unable to split more than one line in single process ', line_number = line_id
                         WHERE     request_id = g_num_request_id
                               AND process_status = 'INPROCESS'
                               AND receipt_line_seq_id !=
                                   rec_cur_rma_line_rec.receipt_line_seq_id
                               AND line_number = rec_cur_rma_line_rec.line_id;

                        msg ('Updated count =' || SQL%ROWCOUNT);
                    END IF;

                    msg (
                           'Marking Error for line with same  LINE Number :'
                        || rec_cur_rma_line_rec.Line_id);
                -- /*Start with RA_NEW_STUCK*/
                --  l_split_count_hdr := 0;

                /*  BEGIN
                     SELECT COUNT (1)
                       INTO l_split_count_hdr
                       FROM xxdo_ont_rma_line_stg x
                      WHERE     request_id = g_num_request_id
                            AND process_status = 'INPROCESS'
                            AND receipt_line_seq_id !=
                                   rec_cur_rma_line_rec.receipt_line_seq_id
                            AND line_number = rec_cur_rma_line_rec.line_number;
                  EXCEPTION
                     WHEN OTHERS
                     THEN
                        l_split_count_hdr := -1;
                  END;

                  /*Only if more than one line available for same sequence ID mark it as SPLIT and later error*/
                /* IF l_split_count_hdr > 0
                 THEN
                    UPDATE xxdo_ont_rma_line_stg x
                       SET process_status = 'SPLIT',
                           error_message =
                              'Unable to split more than one line in single process ',
                           line_number = line_id
                     WHERE     request_id = g_num_request_id
                           AND process_status = 'INPROCESS'
                           AND receipt_line_seq_id !=
                                  rec_cur_rma_line_rec.receipt_line_seq_id
                           AND line_number = rec_cur_rma_line_rec.line_number;

                    msg ('Updated Line Number count =' || SQL%ROWCOUNT);
                 END IF;
         -- /*End with RA_NEW_STUCK*/

                END IF;
            END IF;

            COMMIT;
        END LOOP;

        UPDATE xxdo_ont_rma_hdr_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'One or more lines in this RMA are in error'
         WHERE     request_id = g_num_request_id
               AND process_status = 'INPROCESS'
               AND receipt_header_seq_id IN
                       (SELECT l.receipt_header_seq_id
                          FROM xxdo_ont_rma_line_stg l
                         WHERE     l.request_id = g_num_request_id
                               AND l.process_status = 'ERROR')
               AND result_code IS NULL;

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
           SET process_status = 'ERROR', result_code = 'E', error_message = 'One or more lines in this RMA are in error'
         WHERE     request_id = g_num_request_id
               AND process_status = 'INPROCESS'
               AND receipt_header_seq_id IN
                       (SELECT h.receipt_header_seq_id
                          FROM xxdo_ont_rma_hdr_stg h
                         WHERE     h.request_id = g_num_request_id
                               AND h.process_status = 'ERROR')
               AND result_code IS NULL;

        /***********************************************************************/
        /*Infosys Ver 1.1:   Mark all lines which are marked split to ERROR    */
        /***********************************************************************/

        UPDATE xxdo_ont_rma_line_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'Unable to split more than one line in single process '
         WHERE request_id = g_num_request_id AND process_status = 'SPLIT';



        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_return_status   := 2;
            p_error_message   := SUBSTR (SQLERRM, 1, 240);
            RETURN;
    END validate_line;

    PROCEDURE update_return_line (p_header_id IN NUMBER, p_line_id IN NUMBER, p_cust_ret_reason VARCHAR2
                                  , p_org_id NUMBER, p_return_status OUT NUMBER, p_error_message OUT VARCHAR2)
    IS
        lv_procedure                   VARCHAR2 (100)
                                           := g_package_name || '.update_return_line';
        l_header_rec                   oe_order_pub.header_rec_type;
        l_line_tbl                     oe_order_pub.line_tbl_type;
        lv_line_tbl                    oe_order_pub.line_tbl_type;
        l_action_request_tbl           oe_order_pub.request_tbl_type;
        l_header_adj_tbl               oe_order_pub.header_adj_tbl_type;
        l_line_adj_tbl                 oe_order_pub.line_adj_tbl_type;
        l_header_scr_tbl               oe_order_pub.header_scredit_tbl_type;
        l_line_scredit_tbl             oe_order_pub.line_scredit_tbl_type;
        l_request_rec                  oe_order_pub.request_rec_type;
        l_return_status                VARCHAR2 (1000);
        l_msg_count                    NUMBER;
        l_msg_data                     VARCHAR2 (1000);
        p_api_version_number           NUMBER := 1.0;
        p_init_msg_list                VARCHAR2 (10) := fnd_api.g_false;
        p_return_values                VARCHAR2 (10) := fnd_api.g_false;
        p_action_commit                VARCHAR2 (10) := fnd_api.g_false;
        x_return_status                VARCHAR2 (1);
        x_msg_count                    NUMBER;
        x_msg_data                     VARCHAR2 (100);
        p_header_rec                   oe_order_pub.header_rec_type
                                           := oe_order_pub.g_miss_header_rec;
        p_old_header_rec               oe_order_pub.header_rec_type
                                           := oe_order_pub.g_miss_header_rec;
        p_header_val_rec               oe_order_pub.header_val_rec_type
                                           := oe_order_pub.g_miss_header_val_rec;
        p_old_header_val_rec           oe_order_pub.header_val_rec_type
                                           := oe_order_pub.g_miss_header_val_rec;
        p_header_adj_tbl               oe_order_pub.header_adj_tbl_type
                                           := oe_order_pub.g_miss_header_adj_tbl;
        p_old_header_adj_tbl           oe_order_pub.header_adj_tbl_type
                                           := oe_order_pub.g_miss_header_adj_tbl;
        p_header_adj_val_tbl           oe_order_pub.header_adj_val_tbl_type
                                           := oe_order_pub.g_miss_header_adj_val_tbl;
        p_old_header_adj_val_tbl       oe_order_pub.header_adj_val_tbl_type
            := oe_order_pub.g_miss_header_adj_val_tbl;
        p_header_price_att_tbl         oe_order_pub.header_price_att_tbl_type
            := oe_order_pub.g_miss_header_price_att_tbl;
        p_old_header_price_att_tbl     oe_order_pub.header_price_att_tbl_type
            := oe_order_pub.g_miss_header_price_att_tbl;
        p_header_adj_att_tbl           oe_order_pub.header_adj_att_tbl_type
            := oe_order_pub.g_miss_header_adj_att_tbl;
        p_old_header_adj_att_tbl       oe_order_pub.header_adj_att_tbl_type
            := oe_order_pub.g_miss_header_adj_att_tbl;
        p_header_adj_assoc_tbl         oe_order_pub.header_adj_assoc_tbl_type
            := oe_order_pub.g_miss_header_adj_assoc_tbl;
        p_old_header_adj_assoc_tbl     oe_order_pub.header_adj_assoc_tbl_type
            := oe_order_pub.g_miss_header_adj_assoc_tbl;
        p_header_scredit_tbl           oe_order_pub.header_scredit_tbl_type
            := oe_order_pub.g_miss_header_scredit_tbl;
        p_old_header_scredit_tbl       oe_order_pub.header_scredit_tbl_type
            := oe_order_pub.g_miss_header_scredit_tbl;
        p_header_scredit_val_tbl       oe_order_pub.header_scredit_val_tbl_type
            := oe_order_pub.g_miss_header_scredit_val_tbl;
        p_old_header_scredit_val_tbl   oe_order_pub.header_scredit_val_tbl_type
            := oe_order_pub.g_miss_header_scredit_val_tbl;
        p_line_tbl                     oe_order_pub.line_tbl_type
                                           := oe_order_pub.g_miss_line_tbl;
        p_old_line_tbl                 oe_order_pub.line_tbl_type
                                           := oe_order_pub.g_miss_line_tbl;
        p_line_val_tbl                 oe_order_pub.line_val_tbl_type
            := oe_order_pub.g_miss_line_val_tbl;
        p_old_line_val_tbl             oe_order_pub.line_val_tbl_type
            := oe_order_pub.g_miss_line_val_tbl;
        p_line_adj_tbl                 oe_order_pub.line_adj_tbl_type
            := oe_order_pub.g_miss_line_adj_tbl;
        p_old_line_adj_tbl             oe_order_pub.line_adj_tbl_type
            := oe_order_pub.g_miss_line_adj_tbl;
        p_line_adj_val_tbl             oe_order_pub.line_adj_val_tbl_type
            := oe_order_pub.g_miss_line_adj_val_tbl;
        p_old_line_adj_val_tbl         oe_order_pub.line_adj_val_tbl_type
            := oe_order_pub.g_miss_line_adj_val_tbl;
        p_line_price_att_tbl           oe_order_pub.line_price_att_tbl_type
            := oe_order_pub.g_miss_line_price_att_tbl;
        p_old_line_price_att_tbl       oe_order_pub.line_price_att_tbl_type
            := oe_order_pub.g_miss_line_price_att_tbl;
        p_line_adj_att_tbl             oe_order_pub.line_adj_att_tbl_type
            := oe_order_pub.g_miss_line_adj_att_tbl;
        p_old_line_adj_att_tbl         oe_order_pub.line_adj_att_tbl_type
            := oe_order_pub.g_miss_line_adj_att_tbl;
        p_line_adj_assoc_tbl           oe_order_pub.line_adj_assoc_tbl_type
            := oe_order_pub.g_miss_line_adj_assoc_tbl;
        p_old_line_adj_assoc_tbl       oe_order_pub.line_adj_assoc_tbl_type
            := oe_order_pub.g_miss_line_adj_assoc_tbl;
        p_line_scredit_tbl             oe_order_pub.line_scredit_tbl_type
            := oe_order_pub.g_miss_line_scredit_tbl;
        p_old_line_scredit_tbl         oe_order_pub.line_scredit_tbl_type
            := oe_order_pub.g_miss_line_scredit_tbl;
        p_line_scredit_val_tbl         oe_order_pub.line_scredit_val_tbl_type
            := oe_order_pub.g_miss_line_scredit_val_tbl;
        p_old_line_scredit_val_tbl     oe_order_pub.line_scredit_val_tbl_type
            := oe_order_pub.g_miss_line_scredit_val_tbl;
        p_lot_serial_tbl               oe_order_pub.lot_serial_tbl_type
            := oe_order_pub.g_miss_lot_serial_tbl;
        p_old_lot_serial_tbl           oe_order_pub.lot_serial_tbl_type
            := oe_order_pub.g_miss_lot_serial_tbl;
        p_lot_serial_val_tbl           oe_order_pub.lot_serial_val_tbl_type
            := oe_order_pub.g_miss_lot_serial_val_tbl;
        p_old_lot_serial_val_tbl       oe_order_pub.lot_serial_val_tbl_type
            := oe_order_pub.g_miss_lot_serial_val_tbl;
        p_action_request_tbl           oe_order_pub.request_tbl_type
                                           := oe_order_pub.g_miss_request_tbl;
        x_header_val_rec               oe_order_pub.header_val_rec_type;
        x_header_adj_tbl               oe_order_pub.header_adj_tbl_type;
        x_header_adj_val_tbl           oe_order_pub.header_adj_val_tbl_type;
        x_header_price_att_tbl         oe_order_pub.header_price_att_tbl_type;
        x_header_adj_att_tbl           oe_order_pub.header_adj_att_tbl_type;
        x_header_adj_assoc_tbl         oe_order_pub.header_adj_assoc_tbl_type;
        x_header_scredit_tbl           oe_order_pub.header_scredit_tbl_type;
        x_header_scredit_val_tbl       oe_order_pub.header_scredit_val_tbl_type;
        x_line_val_tbl                 oe_order_pub.line_val_tbl_type;
        x_line_adj_tbl                 oe_order_pub.line_adj_tbl_type;
        x_line_adj_val_tbl             oe_order_pub.line_adj_val_tbl_type;
        x_line_price_att_tbl           oe_order_pub.line_price_att_tbl_type;
        x_line_adj_att_tbl             oe_order_pub.line_adj_att_tbl_type;
        x_line_adj_assoc_tbl           oe_order_pub.line_adj_assoc_tbl_type;
        x_line_scredit_tbl             oe_order_pub.line_scredit_tbl_type;
        x_line_scredit_val_tbl         oe_order_pub.line_scredit_val_tbl_type;
        x_lot_serial_tbl               oe_order_pub.lot_serial_tbl_type;
        x_lot_serial_val_tbl           oe_order_pub.lot_serial_val_tbl_type;
        x_action_request_tbl           oe_order_pub.request_tbl_type;
        x_debug_file                   VARCHAR2 (100);
        l_msg_index_out                NUMBER (10);
        l_line_tbl_index               NUMBER;
        lv_next_msg                    NUMBER;
        lv_header_id                   NUMBER;
        lv_ship_from_org_id            NUMBER;
        lv_inventory_item_id           NUMBER;
        lv_line_id                     NUMBER;
        lv_order_tbl                   oe_holds_pvt.order_tbl_type;
        lv_retcode                     NUMBER;
        lv_error_buf                   VARCHAR (1000);
        lv_hold_exists                 NUMBER;
        j                              NUMBER;
        lv_num                         NUMBER := 1;
        lv_hold_index                  NUMBER := 0;
        lv_mo_resp_id                  NUMBER;
        lv_mo_resp_appl_id             NUMBER;
    BEGIN
        p_error_message                     := NULL;
        p_return_status                     := 0;            -- g_ret_success;
        get_resp_details (p_org_id, 'ONT', lv_mo_resp_id,
                          lv_mo_resp_appl_id);


        apps.fnd_global.apps_initialize (user_id        => g_num_user_id,
                                         resp_id        => lv_mo_resp_id,
                                         resp_appl_id   => lv_mo_resp_appl_id);
        mo_global.init ('ONT');


        /***************************
        apps.fnd_global.apps_initialize (user_id        => 2531,
                                         resp_id        => 50744,
                                         resp_appl_id   => 660);
        mo_global.init ('ONT');
        MO_GLOBAL.SET_POLICY_CONTEXT ('S', 95);
        msg ('CRP3..');
        /****************************/
        oe_msg_pub.initialize;
        oe_debug_pub.initialize;
        x_debug_file                        := oe_debug_pub.set_debug_mode ('FILE');
        oe_debug_pub.setdebuglevel (5);
        msg ('Begining of Process Order API for updating Line');
        -- l_line_tbl_index := 1;
        l_line_tbl (1)                      := oe_order_pub.g_miss_line_rec;
        l_line_tbl (1).header_id            := p_header_id;
        l_line_tbl (1).line_id              := p_line_id;
        l_line_tbl (1).return_reason_code   := p_cust_ret_reason;
        l_line_tbl (1).operation            := oe_globals.g_opr_update;
        msg ('Calling process order API to update line');
        oe_order_pub.process_order (
            p_api_version_number       => 1.0,
            p_init_msg_list            => fnd_api.g_false,
            p_return_values            => fnd_api.g_false,
            p_action_commit            => fnd_api.g_false,
            x_return_status            => l_return_status,
            x_msg_count                => l_msg_count,
            x_msg_data                 => l_msg_data,
            p_header_rec               => l_header_rec,
            p_line_tbl                 => l_line_tbl,
            p_action_request_tbl       => l_action_request_tbl,
            x_header_rec               => l_header_rec,
            x_header_val_rec           => x_header_val_rec,
            x_header_adj_tbl           => x_header_adj_tbl,
            x_header_adj_val_tbl       => x_header_adj_val_tbl,
            x_header_price_att_tbl     => x_header_price_att_tbl,
            x_header_adj_att_tbl       => x_header_adj_att_tbl,
            x_header_adj_assoc_tbl     => x_header_adj_assoc_tbl,
            x_header_scredit_tbl       => x_header_scredit_tbl,
            x_header_scredit_val_tbl   => x_header_scredit_val_tbl,
            x_line_tbl                 => lv_line_tbl,
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
            x_action_request_tbl       => l_action_request_tbl);
        COMMIT;
        -- Retrieve messages
        msg ('Order Line msg' || l_msg_count);

        FOR k IN 1 .. l_msg_count
        LOOP
            oe_msg_pub.get (p_msg_index => k, p_encoded => fnd_api.g_false, p_data => l_msg_data
                            , p_msg_index_out => lv_next_msg);
            fnd_file.put_line (fnd_file.LOG, 'message is:' || l_msg_data);
        END LOOP;

        -- Check the return status
        IF l_return_status = fnd_api.g_ret_sts_success
        THEN
            msg ('Process Order Sucess');
            msg ('Line update with WMS return reason');
            COMMIT;
        ELSE
            msg (
                'Api failing with error for updating Line' || l_return_status);

            UPDATE xxdo_ont_rma_line_stg
               SET process_status = 'ERROR', result_code = 'E', error_message = 'API Failed while updating Line return reason'
             WHERE     request_id = g_num_request_id
                   AND process_status = 'INPROCESS'
                   AND line_number = p_line_id;

            COMMIT;
        -- RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_return_status   := 2;
            p_error_message   := SQLERRM;
            msg ('Error In ' || lv_procedure || SQLERRM);
    END;

    PROCEDURE rcv_headers_insert (p_shipment_num VARCHAR2, p_receipt_date DATE, p_organization_id NUMBER, p_group_id NUMBER, p_customer_id NUMBER:= NULL, p_vendor_id NUMBER:= NULL
                                  , --   p_employee_id             NUMBER,  ---CRP Issue
                                    p_org_id NUMBER, p_return_status OUT NUMBER, p_error_message OUT VARCHAR2)
    IS
    BEGIN
        p_error_message   := NULL;
        p_return_status   := 0;                              ---g_ret_success;

        INSERT INTO rcv_headers_interface (header_interface_id, GROUP_ID, processing_status_code, receipt_source_code, transaction_type, auto_transact_code, last_update_date, last_updated_by, last_update_login, creation_date, created_by, shipment_num, ship_to_organization_id, expected_receipt_date, -- employee_id,  ---CRP Issue
                                                                                                                                                                                                                                                                                                            validation_flag
                                           , customer_id, vendor_id, ORG_ID)
            (SELECT rcv_headers_interface_s.NEXTVAL      --header_interface_id
                                                   , p_group_id     --group_id
                                                               , 'PENDING' --processing_status_code
                                                                          , 'CUSTOMER' --receipt_source_code
                                                                                      , 'NEW' --transaction_type
                                                                                             , 'DELIVER' --auto_transact_code
                                                                                                        , SYSDATE --last_update_date
                                                                                                                 , fnd_global.user_id --last_update_by
                                                                                                                                     , USERENV ('SESSIONID') --last_update_login
                                                                                                                                                            , SYSDATE --creation_date
                                                                                                                                                                     , fnd_global.user_id --created_by
                                                                                                                                                                                         , p_shipment_num --shipment_num
                                                                                                                                                                                                         , p_organization_id --ship_to_organization_id
                                                                                                                                                                                                                            , p_receipt_date --expected_receipt_date
                                                                                                                                                                                                                                            , --      p_employee_id                                  --employee_id   ---CRP Issue

                                                                                                                                                                                                                                              'Y' --validation_flag
                                                                                                                                                                                                                                                 , p_customer_id, p_vendor_id, p_org_id FROM DUAL);

        COMMIT;

        p_return_status   := 0;                               --g_ret_success;
        msg ('Header Record inserted-' || p_shipment_num);
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('Header Record inserted-Error occured' || p_shipment_num);
            p_return_status   := 2;
            p_error_message   := SQLERRM;
    END;

    PROCEDURE rcv_lines_insert (p_org_id NUMBER, p_receipt_source_code VARCHAR2, p_source_document_code VARCHAR2, p_group_id NUMBER, p_location_id NUMBER, p_subinventory VARCHAR2, p_header_interface_id NUMBER, p_shipment_num VARCHAR2, p_receipt_date DATE, p_item_id NUMBER, --   p_employee_id                         NUMBER,  ---CRP Issue
                                                                                                                                                                                                                                                                                  p_uom VARCHAR2, p_quantity NUMBER, p_return_status OUT NUMBER, p_error_message OUT VARCHAR2, p_shipment_header_id NUMBER:= NULL, p_shipment_line_id NUMBER:= NULL, p_ship_to_location_id NUMBER:= NULL, p_from_organization_id NUMBER:= NULL, p_to_organization_id NUMBER:= NULL, p_requisition_line_id NUMBER:= NULL, p_requisition_distribution_id NUMBER:= NULL, p_deliver_to_person_id NUMBER:= NULL, p_deliver_to_location_id NUMBER:= NULL, p_locator_id NUMBER:= NULL, p_oe_order_header_id NUMBER:= NULL, p_oe_order_line_id NUMBER:= NULL, p_customer_id NUMBER:= NULL
                                , p_customer_site_id NUMBER:= NULL, p_vendor_id NUMBER:= NULL, p_parent_transaction_id NUMBER:= NULL)
    IS
        lv_cnt        NUMBER;
        lv_trx_type   VARCHAR2 (20);
    BEGIN
        SELECT COUNT (1)
          INTO lv_cnt
          FROM apps.rcv_shipment_lines rsl, apps.po_line_locations_all plla, apps.fnd_lookup_values flv
         WHERE     rsl.shipment_line_id = p_shipment_line_id
               AND plla.line_location_id = rsl.po_line_location_id
               AND flv.lookup_type = 'RCV_ROUTING_HEADERS'
               AND flv.LANGUAGE = 'US'
               AND flv.lookup_code = TO_CHAR (plla.receiving_routing_id)
               AND flv.view_application_id = 0
               AND flv.security_group_id = 0
               AND flv.meaning = 'Standard Receipt';

        IF lv_cnt = 1
        THEN
            lv_trx_type   := 'DELIVER';
        ELSE
            lv_trx_type   := 'RECEIVE';
        END IF;

        INSERT INTO rcv_transactions_interface (interface_transaction_id,
                                                GROUP_ID,
                                                org_id,
                                                last_update_date,
                                                last_updated_by,
                                                creation_date,
                                                created_by,
                                                last_update_login,
                                                transaction_type,
                                                transaction_date,
                                                processing_status_code,
                                                processing_mode_code,
                                                transaction_status_code,
                                                quantity,
                                                unit_of_measure,
                                                interface_source_code,
                                                item_id,
                                                -- employee_id,  ---CRP Issue
                                                auto_transact_code,
                                                shipment_header_id,
                                                shipment_line_id,
                                                ship_to_location_id,
                                                receipt_source_code,
                                                to_organization_id,
                                                source_document_code,
                                                requisition_line_id,
                                                req_distribution_id,
                                                destination_type_code,
                                                deliver_to_person_id,
                                                location_id,
                                                deliver_to_location_id,
                                                subinventory,
                                                shipment_num,
                                                expected_receipt_date,
                                                header_interface_id,
                                                validation_flag,
                                                locator_id,
                                                oe_order_header_id,
                                                oe_order_line_id,
                                                customer_id,
                                                customer_site_id,
                                                vendor_id,
                                                parent_transaction_id)
            (SELECT rcv_transactions_interface_s.NEXTVAL -- interface_transaction_id
                                                        , p_group_id --group_id
                                                                    , p_org_id, SYSDATE --last_update_date
                                                                                       , fnd_global.user_id --last_updated_by
                                                                                                           , SYSDATE --creation_date
                                                                                                                    , apps.fnd_global.user_id --created_by
                                                                                                                                             , USERENV ('SESSIONID') --last_update_login
                                                                                                                                                                    , 'RECEIVE', -- lv_trx_type                                --transaction_type
                                                                                                                                                                                 /* 9/15 if the receipt date is in old month, default it to sysdate */
                                                                                                                                                                                 --p_receipt_date                             --transaction_date
                                                                                                                                                                                 DECODE (TO_CHAR (p_receipt_date, 'YYYYMM'), TO_CHAR (SYSDATE, 'YYYYMM'), p_receipt_date, SYSDATE), --PAST_RECEIPT
                                                                                                                                                                                                                                                                                    'PENDING' --processing_status_code
                                                                                                                                                                                                                                                                                             , 'BATCH' --processing_mode_code
                                                                                                                                                                                                                                                                                                      , 'PENDING' --transaction_status_code
                                                                                                                                                                                                                                                                                                                 , p_quantity --quantity
                                                                                                                                                                                                                                                                                                                             , '', --p_uom                                       --unit_of_measure
                                                                                                                                                                                                                                                                                                                                   'RCV' --interface_source_code
                                                                                                                                                                                                                                                                                                                                        , p_item_id --item_id
                                                                                                                                                                                                                                                                                                                                                   , --    p_employee_id                                   --employee_id    ---CRP Issue

                                                                                                                                                                                                                                                                                                                                                     'DELIVER' --auto_transact_code
                                                                                                                                                                                                                                                                                                                                                              , p_shipment_header_id --shipment_header_id
                                                                                                                                                                                                                                                                                                                                                                                    , p_shipment_line_id --shipment_line_id
                                                                                                                                                                                                                                                                                                                                                                                                        , p_ship_to_location_id --ship_to_location_id
                                                                                                                                                                                                                                                                                                                                                                                                                               , p_receipt_source_code --receipt_source_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                      , p_to_organization_id --to_organization_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                            , p_source_document_code --source_document_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    , p_requisition_line_id --requisition_line_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           , p_requisition_distribution_id --req_distribution_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          , 'INVENTORY' --destination_type_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       , p_deliver_to_person_id --deliver_to_person_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               , p_location_id --location_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              , p_deliver_to_location_id --deliver_to_location_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        , p_subinventory --subinventory
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        , p_shipment_num --shipment_num
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        , p_receipt_date --expected_receipt_date,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        , p_header_interface_id --header_interface_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               , 'Y' --validation_flag
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    , p_locator_id, p_oe_order_header_id, p_oe_order_line_id, p_customer_id, p_customer_site_id, p_vendor_id, p_parent_transaction_id FROM DUAL);

        COMMIT;


        p_return_status   := 0;                               --g_ret_success;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_return_status   := 2;                           --2 g_ret_error;
            p_error_message   := SQLERRM;
    END;

    PROCEDURE receive_return_tbl (p_group_id OUT NUMBER, p_return_status OUT NUMBER, p_error_message OUT VARCHAR2)
    IS
        CURSOR c_det_cur IS
              SELECT *
                FROM xxdo_ont_rma_line_stg
               WHERE     process_status = 'INPROCESS'
                     AND result_code = 'P'
                     AND type1 = 'PLANNED'
                     AND request_id = g_num_request_id
            ORDER BY org_id;


        lv_procedure               VARCHAR2 (240)
            := SUBSTR (g_package_name || '.receive_return_tbl', 1, 240);
        x_ret                      NUMBER;
        x_msg_cnt                  NUMBER;
        x_msg_data                 VARCHAR2 (2000);
        l_dummy                    NUMBER;
        ex_invalid_qty             EXCEPTION;
        lv_ret_process             VARCHAR2 (1) := 'P';
        lv_customer_id             NUMBER;
        lv_org_id                  NUMBER;
        lv_ord_customer_id         NUMBER;
        lv_ord_org_id              NUMBER;
        lv_ord_header_id           NUMBER;
        lv_ord_inventory_item_id   NUMBER;
        lv_ord_uom                 VARCHAR2 (240);
        lv_ord_subinventory        VARCHAR2 (240);
        lv_default_location_id     NUMBER;
        lv_ord_unit_of_measure     VARCHAR2 (240);
        lv_order_qty               NUMBER;
        p_locator_id               NUMBER := NULL;
        lv_do_return               BOOLEAN := TRUE;
        lv_exists                  NUMBER;
        lv_customer_number         VARCHAR (30);
        lv_sold_to_id              NUMBER;
        lv_file_val                VARCHAR2 (500);
        lv_header_interface_id     NUMBER;
        lv_group_id                NUMBER;
        lv_locator_id              NUMBER;
        lv_ship_to_org_id          NUMBER;
        lv_prev_rma_number         VARCHAR2 (60) := '-1';
        --x_return_status varchar2(1);
        lv_line_ret_reason         VARCHAR2 (100);
        p_shipment_header_id       NUMBER := NULL;
        p_receipt_num              VARCHAR2 (200) := NULL;
        lv_actual_quantity         NUMBER;
        lv_less_quantity           NUMBER;
        lv_more_quantity           NUMBER;
        lv_first                   NUMBER;
        lv_n_org_id                NUMBER;
        lv_i                       NUMBER := 1;
        lv_locator                 NUMBER;
        lv_mo_org_id               NUMBER;
        lv_old_org_id              NUMBER := '-1';
    BEGIN
        p_error_message                                           := NULL;
        p_return_status                                           := 0; -- g_ret_success;
        inv_rcv_common_apis.g_po_startup_value.transaction_mode   := 'BATCH';

        FOR c_det_cur_rec IN c_det_cur
        LOOP
            BEGIN
                IF (lv_i = 1 OR lv_old_org_id <> c_det_cur_rec.org_id)
                THEN
                    SELECT apps.rcv_interface_groups_s.NEXTVAL
                      INTO lv_first
                      FROM DUAL;

                    lv_group_id   := lv_first;
                ELSE
                    lv_group_id   := lv_first;
                END IF;

                msg ('Group ID created is' || lv_group_id);
                msg ('Fetching Data Required Mandatory Data ');
                lv_ord_header_id         := NULL;
                lv_ord_unit_of_measure   := NULL;
                lv_n_org_id              := NULL;
                lv_sold_to_id            := NULL;
                lv_ship_to_org_id        := NULL;
                lv_line_ret_reason       := NULL;

                SELECT oola.header_id, oola.order_quantity_uom, ooh.org_id,
                       ooh.sold_to_org_id, oola.ship_to_org_id, oola.return_reason_code
                  INTO lv_ord_header_id, lv_ord_unit_of_measure, lv_n_org_id, lv_sold_to_id,
                                       lv_ship_to_org_id, lv_line_ret_reason
                  FROM oe_order_lines_all oola, oe_order_headers_all ooh
                 WHERE     oola.line_id = c_det_cur_rec.line_number
                       AND ooh.header_id = oola.header_id;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    NULL;
            END;

            BEGIN
                SELECT locator_type
                  INTO lv_locator
                  FROM mtl_secondary_inventories
                 WHERE     organization_id = c_det_cur_rec.ship_from_org_id
                       AND secondary_inventory_name =
                           c_det_cur_rec.host_subinventory;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_locator      := 1;                 --lv_locator := 999;
                    lv_locator_id   := NULL;
            END;

            --Derive the locator ID
            IF lv_locator <> 1
            THEN
                BEGIN
                    SELECT MIN (inventory_location_id)
                      INTO lv_locator_id
                      FROM mtl_item_locations
                     WHERE     organization_id =
                               c_det_cur_rec.ship_from_org_id
                           AND subinventory_code =
                               c_det_cur_rec.host_subinventory
                           AND SYSDATE <= NVL (disable_date, SYSDATE);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_locator_id   := NULL;
                END;
            END IF;

            IF lv_line_ret_reason <> c_det_cur_rec.cust_return_reason
            THEN
                msg (
                    'Return Reason are not same,then call process_order to update the line');
                update_return_line (c_det_cur_rec.header_id,
                                    c_det_cur_rec.line_number,
                                    c_det_cur_rec.cust_return_reason,
                                    lv_n_org_id,
                                    p_return_status,
                                    p_error_message);
            END IF;

            ---  -- Insert header record only once for each RMA number
            IF lv_prev_rma_number <> c_det_cur_rec.rma_number
            THEN
                SELECT MAX (header_interface_id)
                  INTO lv_header_interface_id
                  FROM apps.rcv_headers_interface
                 WHERE     last_update_login = USERENV ('SESSIONID')
                       AND receipt_source_code = 'CUSTOMER'
                       AND NVL (shipment_num, 'NoShipMentXXX') =
                           NVL (c_det_cur_rec.rma_number, 'NoShipMentXXX')
                       AND processing_status_code = 'PENDING';

                IF lv_header_interface_id IS NULL
                THEN
                    msg ('Inserting Lines into rcv_headers_interface');
                    rcv_headers_insert (
                        p_shipment_num      => c_det_cur_rec.rma_number,
                        p_receipt_date      => c_det_cur_rec.rma_receipt_date,
                        p_organization_id   => c_det_cur_rec.ship_from_org_id,
                        p_group_id          => lv_group_id,
                        p_customer_id       => lv_sold_to_id,
                        p_vendor_id         => NULL,
                        p_org_id            => lv_n_org_id,
                        --    p_employee_id          => c_det_cur_rec.employee_id,   ---CRP Issue
                        p_return_status     => x_ret,
                        p_error_message     => x_msg_data);

                    IF x_ret != 0
                    THEN
                        fnd_file.put_line (fnd_file.LOG, x_msg_data);
                        RETURN;
                    ELSE
                        lv_prev_rma_number   := c_det_cur_rec.rma_number;
                    END IF;
                END IF;
            END IF;

            SELECT MAX (header_interface_id)
              INTO lv_header_interface_id
              FROM apps.rcv_headers_interface
             WHERE     last_update_login = USERENV ('SESSIONID')
                   AND receipt_source_code = 'CUSTOMER'
                   AND NVL (shipment_num, 'NoShipMentXXX') =
                       NVL (c_det_cur_rec.rma_number, 'NoShipMentXXX');

            ---Insert Line record
            IF lv_header_interface_id IS NOT NULL
            THEN
                msg ('Inserting Lines into rcv_transactions_interface');
                rcv_lines_insert (
                    p_org_id                        => c_det_cur_rec.org_id,
                    p_receipt_source_code           => 'CUSTOMER',
                    p_source_document_code          => 'RMA',
                    p_group_id                      => lv_group_id,
                    p_location_id                   => NULL,
                    p_subinventory                  =>
                        c_det_cur_rec.host_subinventory,
                    p_header_interface_id           => lv_header_interface_id,
                    p_shipment_num                  => c_det_cur_rec.rma_number,
                    p_receipt_date                  => c_det_cur_rec.rma_receipt_date,
                    p_item_id                       =>
                        c_det_cur_rec.inventory_item_id,
                    --     p_employee_id                      => c_det_cur_rec.employee_id,   ---CRP Issue
                    p_uom                           => lv_ord_unit_of_measure,
                    p_quantity                      => c_det_cur_rec.qty,
                    p_return_status                 => x_ret,
                    p_error_message                 => x_msg_data,
                    p_shipment_header_id            => NULL,
                    p_shipment_line_id              => NULL,
                    p_ship_to_location_id           => NULL,
                    p_from_organization_id          => NULL,
                    p_to_organization_id            => NULL,
                    p_requisition_line_id           => NULL,
                    p_requisition_distribution_id   => NULL,
                    p_deliver_to_person_id          => NULL,
                    p_deliver_to_location_id        => NULL,
                    p_locator_id                    => lv_locator_id,
                    p_oe_order_header_id            => c_det_cur_rec.header_id,
                    p_oe_order_line_id              =>
                        c_det_cur_rec.line_number,
                    p_customer_id                   => lv_sold_to_id,
                    p_customer_site_id              => lv_ship_to_org_id,
                    p_vendor_id                     => NULL,
                    p_parent_transaction_id         => NULL);
            END IF;

            --END IF;
            IF x_ret != 0
            THEN
                msg (
                       'Error Occured in inserting into transaction interface table'
                    || x_msg_data);
                RETURN;
            END IF;

            lv_i            := lv_i + 1;
                             /*Start of DAMAGE_CODE,FACTORY_CODE,PROD_CODE
    BEGIN

update oe_order_lines_all
set attribute12=c_det_cur_rec.damage_code,
      attribute4=c_det_cur_rec.factory_code,
      attribute5=c_det_cur_rec.prod_code
where line_id = c_det_cur_rec.line_number
and     header_id=   c_det_cur_rec.header_id; */
            --and attribute12 is null;
            /**
         EXCEPTION
         WHEN OTHERS THEN
         msg('Updated Failed for Damage Code/factory/prod_code');
         END;
           /*Start of DAMAGE_CODE,FACTORY_CODE,PROD_CODE*/
            msg ('Receirpt Line Seq Id' || c_det_cur_rec.receipt_line_seq_id);
            msg ('Receirpt Line Group ID' || lv_group_id);

            UPDATE xxdo_ont_rma_line_stg
               SET GROUP_ID   = lv_group_id
             WHERE receipt_line_seq_id = c_det_cur_rec.receipt_line_seq_id;

            COMMIT;
            lv_old_org_id   := c_det_cur_rec.org_id;
        END LOOP;

        p_group_id                                                :=
            lv_group_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_return_status   := 2;
            p_error_message   := SQLERRM;
            msg ('Error In ' || lv_procedure || '-' || SQLERRM);
    END receive_return_tbl;

    PROCEDURE apply_hold (ph_line_tbl       IN OUT oe_holds_pvt.order_tbl_type,
                          p_org_id          IN     NUMBER,
                          p_hold_comment    IN     VARCHAR2,
                          p_return_status      OUT NUMBER,
                          p_error_message      OUT VARCHAR2)
    IS
        lv_order_tbl       oe_holds_pvt.order_tbl_type;
        lv_hold_id         NUMBER;
        lv_comment         VARCHAR2 (100);
        lv_return_status   VARCHAR2 (10);
        ln_msg_count       NUMBER;
        lv_msg_data        VARCHAR2 (200);
        lv_procedure       VARCHAR2 (240)
            := SUBSTR (g_package_name || '.apply_hold', 1, 240);
        lv_cnt             NUMBER;
    BEGIN
        p_error_message   := NULL;
        p_return_status   := 0;                              -- g_ret_success;
        lv_order_tbl      := ph_line_tbl;
        msg ('Calling Hold Package');

        BEGIN
            SELECT hold_id
              INTO lv_hold_id
              FROM oe_hold_definitions
             WHERE NAME = 'WMS_OVER_RECEIPT_HOLD';
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                p_error_message   :=
                    'Hold WMS_OVER_RECEIPT_HOLD is not defined';
                p_return_status   := 2;
                RETURN;
            WHEN OTHERS
            THEN
                p_error_message   := SQLERRM;
                p_return_status   := 2;
                RETURN;
        END;

        lv_comment        :=
            NVL (p_hold_comment,
                 'Hold applied by Deckers Expected Returns program');
        msg ('Calling Apply Hold');
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
            x_msg_count          => ln_msg_count,
            x_msg_data           => lv_msg_data);

        IF lv_return_status <> 'S'
        THEN
            p_return_status   := 2;
            p_error_message   := lv_msg_data;

            FOR i IN lv_order_tbl.FIRST .. lv_order_tbl.LAST
            LOOP
                UPDATE xxdo_ont_rma_line_stg line
                   SET process_status = 'ERROR', result_code = 'E', type1 = 'PLANNED',
                       error_message = 'Hold Couldnt be applied for reason ' || lv_msg_data, last_updated_by = g_num_user_id, last_update_date = SYSDATE,
                       last_update_login = g_num_login_id
                 WHERE     process_status IN ('INPROCESS')
                       AND request_id = g_num_request_id
                       AND line_id = lv_order_tbl (i).line_id;

                COMMIT;
            END LOOP;

            RETURN;
        END IF;

        IF NVL (lv_return_status, 'X') = 'S'
        THEN
            COMMIT;

            FOR i IN lv_order_tbl.FIRST .. lv_order_tbl.LAST
            LOOP
                UPDATE xxdo_ont_rma_line_stg line
                   SET process_status = 'HOLD', result_code = 'H', type1 = 'PLANNED',
                       error_message = '', last_updated_by = g_num_user_id, last_update_date = SYSDATE,
                       last_update_login = g_num_login_id
                 WHERE     process_status IN ('INPROCESS')
                       AND request_id = g_num_request_id
                       AND line_number = lv_order_tbl (i).line_id
                       AND EXISTS
                               (SELECT 'x'
                                  FROM oe_order_holds_all oh, oe_hold_sources_all ohs
                                 WHERE     oh.header_id =
                                           lv_order_tbl (i).header_id
                                       AND oh.line_id =
                                           lv_order_tbl (i).line_id
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
            msg ('Error in ' || lv_procedure || SQLERRM);
    END apply_hold;

    PROCEDURE create_unplan_rma_line (p_return_status   OUT NUMBER,
                                      p_error_message   OUT VARCHAR2)
    IS
        CURSOR c_det_unplan_cur IS
              SELECT *
                FROM xxdo_ont_rma_line_stg
               WHERE     process_status = 'INPROCESS'
                     AND result_code = 'U'
                     AND request_id = g_num_request_id
            ORDER BY org_id ASC;


        lv_procedure                   VARCHAR2 (100)
                                           := g_package_name || '.create_unplan_rma_line';
        l_header_rec                   oe_order_pub.header_rec_type;
        l_line_tbl                     oe_order_pub.line_tbl_type;
        lv_line_tbl                    oe_order_pub.line_tbl_type;
        l_action_request_tbl           oe_order_pub.request_tbl_type;
        l_header_adj_tbl               oe_order_pub.header_adj_tbl_type;
        l_line_adj_tbl                 oe_order_pub.line_adj_tbl_type;
        l_header_scr_tbl               oe_order_pub.header_scredit_tbl_type;
        l_line_scredit_tbl             oe_order_pub.line_scredit_tbl_type;
        l_request_rec                  oe_order_pub.request_rec_type;
        l_return_status                VARCHAR2 (1000);
        l_msg_count                    NUMBER;
        l_msg_data                     VARCHAR2 (1000);
        p_api_version_number           NUMBER := 1.0;
        p_init_msg_list                VARCHAR2 (10) := fnd_api.g_false;
        p_return_values                VARCHAR2 (10) := fnd_api.g_false;
        p_action_commit                VARCHAR2 (10) := fnd_api.g_false;
        x_return_status                VARCHAR2 (1);
        x_msg_count                    NUMBER;
        x_msg_data                     VARCHAR2 (100);
        p_header_rec                   oe_order_pub.header_rec_type
                                           := oe_order_pub.g_miss_header_rec;
        p_old_header_rec               oe_order_pub.header_rec_type
                                           := oe_order_pub.g_miss_header_rec;
        p_header_val_rec               oe_order_pub.header_val_rec_type
                                           := oe_order_pub.g_miss_header_val_rec;
        p_old_header_val_rec           oe_order_pub.header_val_rec_type
                                           := oe_order_pub.g_miss_header_val_rec;
        p_header_adj_tbl               oe_order_pub.header_adj_tbl_type
                                           := oe_order_pub.g_miss_header_adj_tbl;
        p_old_header_adj_tbl           oe_order_pub.header_adj_tbl_type
                                           := oe_order_pub.g_miss_header_adj_tbl;
        p_header_adj_val_tbl           oe_order_pub.header_adj_val_tbl_type
                                           := oe_order_pub.g_miss_header_adj_val_tbl;
        p_old_header_adj_val_tbl       oe_order_pub.header_adj_val_tbl_type
            := oe_order_pub.g_miss_header_adj_val_tbl;
        p_header_price_att_tbl         oe_order_pub.header_price_att_tbl_type
            := oe_order_pub.g_miss_header_price_att_tbl;
        p_old_header_price_att_tbl     oe_order_pub.header_price_att_tbl_type
            := oe_order_pub.g_miss_header_price_att_tbl;
        p_header_adj_att_tbl           oe_order_pub.header_adj_att_tbl_type
            := oe_order_pub.g_miss_header_adj_att_tbl;
        p_old_header_adj_att_tbl       oe_order_pub.header_adj_att_tbl_type
            := oe_order_pub.g_miss_header_adj_att_tbl;
        p_header_adj_assoc_tbl         oe_order_pub.header_adj_assoc_tbl_type
            := oe_order_pub.g_miss_header_adj_assoc_tbl;
        p_old_header_adj_assoc_tbl     oe_order_pub.header_adj_assoc_tbl_type
            := oe_order_pub.g_miss_header_adj_assoc_tbl;
        p_header_scredit_tbl           oe_order_pub.header_scredit_tbl_type
            := oe_order_pub.g_miss_header_scredit_tbl;
        p_old_header_scredit_tbl       oe_order_pub.header_scredit_tbl_type
            := oe_order_pub.g_miss_header_scredit_tbl;
        p_header_scredit_val_tbl       oe_order_pub.header_scredit_val_tbl_type
            := oe_order_pub.g_miss_header_scredit_val_tbl;
        p_old_header_scredit_val_tbl   oe_order_pub.header_scredit_val_tbl_type
            := oe_order_pub.g_miss_header_scredit_val_tbl;
        p_line_tbl                     oe_order_pub.line_tbl_type
                                           := oe_order_pub.g_miss_line_tbl;
        p_old_line_tbl                 oe_order_pub.line_tbl_type
                                           := oe_order_pub.g_miss_line_tbl;
        p_line_val_tbl                 oe_order_pub.line_val_tbl_type
            := oe_order_pub.g_miss_line_val_tbl;
        p_old_line_val_tbl             oe_order_pub.line_val_tbl_type
            := oe_order_pub.g_miss_line_val_tbl;
        p_line_adj_tbl                 oe_order_pub.line_adj_tbl_type
            := oe_order_pub.g_miss_line_adj_tbl;
        p_old_line_adj_tbl             oe_order_pub.line_adj_tbl_type
            := oe_order_pub.g_miss_line_adj_tbl;
        p_line_adj_val_tbl             oe_order_pub.line_adj_val_tbl_type
            := oe_order_pub.g_miss_line_adj_val_tbl;
        p_old_line_adj_val_tbl         oe_order_pub.line_adj_val_tbl_type
            := oe_order_pub.g_miss_line_adj_val_tbl;
        p_line_price_att_tbl           oe_order_pub.line_price_att_tbl_type
            := oe_order_pub.g_miss_line_price_att_tbl;
        p_old_line_price_att_tbl       oe_order_pub.line_price_att_tbl_type
            := oe_order_pub.g_miss_line_price_att_tbl;
        p_line_adj_att_tbl             oe_order_pub.line_adj_att_tbl_type
            := oe_order_pub.g_miss_line_adj_att_tbl;
        p_old_line_adj_att_tbl         oe_order_pub.line_adj_att_tbl_type
            := oe_order_pub.g_miss_line_adj_att_tbl;
        p_line_adj_assoc_tbl           oe_order_pub.line_adj_assoc_tbl_type
            := oe_order_pub.g_miss_line_adj_assoc_tbl;
        p_old_line_adj_assoc_tbl       oe_order_pub.line_adj_assoc_tbl_type
            := oe_order_pub.g_miss_line_adj_assoc_tbl;
        p_line_scredit_tbl             oe_order_pub.line_scredit_tbl_type
            := oe_order_pub.g_miss_line_scredit_tbl;
        p_old_line_scredit_tbl         oe_order_pub.line_scredit_tbl_type
            := oe_order_pub.g_miss_line_scredit_tbl;
        p_line_scredit_val_tbl         oe_order_pub.line_scredit_val_tbl_type
            := oe_order_pub.g_miss_line_scredit_val_tbl;
        p_old_line_scredit_val_tbl     oe_order_pub.line_scredit_val_tbl_type
            := oe_order_pub.g_miss_line_scredit_val_tbl;
        p_lot_serial_tbl               oe_order_pub.lot_serial_tbl_type
            := oe_order_pub.g_miss_lot_serial_tbl;
        p_old_lot_serial_tbl           oe_order_pub.lot_serial_tbl_type
            := oe_order_pub.g_miss_lot_serial_tbl;
        p_lot_serial_val_tbl           oe_order_pub.lot_serial_val_tbl_type
            := oe_order_pub.g_miss_lot_serial_val_tbl;
        p_old_lot_serial_val_tbl       oe_order_pub.lot_serial_val_tbl_type
            := oe_order_pub.g_miss_lot_serial_val_tbl;
        p_action_request_tbl           oe_order_pub.request_tbl_type
                                           := oe_order_pub.g_miss_request_tbl;
        x_header_val_rec               oe_order_pub.header_val_rec_type;
        x_header_adj_tbl               oe_order_pub.header_adj_tbl_type;
        x_header_adj_val_tbl           oe_order_pub.header_adj_val_tbl_type;
        x_header_price_att_tbl         oe_order_pub.header_price_att_tbl_type;
        x_header_adj_att_tbl           oe_order_pub.header_adj_att_tbl_type;
        x_header_adj_assoc_tbl         oe_order_pub.header_adj_assoc_tbl_type;
        x_header_scredit_tbl           oe_order_pub.header_scredit_tbl_type;
        x_header_scredit_val_tbl       oe_order_pub.header_scredit_val_tbl_type;
        x_line_val_tbl                 oe_order_pub.line_val_tbl_type;
        x_line_adj_tbl                 oe_order_pub.line_adj_tbl_type;
        x_line_adj_val_tbl             oe_order_pub.line_adj_val_tbl_type;
        x_line_price_att_tbl           oe_order_pub.line_price_att_tbl_type;
        x_line_adj_att_tbl             oe_order_pub.line_adj_att_tbl_type;
        x_line_adj_assoc_tbl           oe_order_pub.line_adj_assoc_tbl_type;
        x_line_scredit_tbl             oe_order_pub.line_scredit_tbl_type;
        x_line_scredit_val_tbl         oe_order_pub.line_scredit_val_tbl_type;
        x_lot_serial_tbl               oe_order_pub.lot_serial_tbl_type;
        x_lot_serial_val_tbl           oe_order_pub.lot_serial_val_tbl_type;
        x_action_request_tbl           oe_order_pub.request_tbl_type;
        x_debug_file                   VARCHAR2 (100);
        l_msg_index_out                NUMBER (10);
        l_line_tbl_index               NUMBER;
        lv_next_msg                    NUMBER;
        lv_header_id                   NUMBER;
        lv_ship_from_org_id            NUMBER;
        lv_inventory_item_id           NUMBER;
        lv_line_id                     NUMBER;
        lv_order_tbl                   oe_holds_pvt.order_tbl_type;
        lv_retcode                     NUMBER;
        lv_error_buf                   VARCHAR (1000);
        lv_hold_exists                 NUMBER;
        j                              NUMBER;
        lv_num                         NUMBER := 1;
        lv_hold_index                  NUMBER := 0;
        lv_mo_resp_id                  NUMBER;
        lv_mo_resp_appl_id             NUMBER;
        lv_org_exists                  NUMBER;
        lv_num_first                   NUMBER := 0;
        /* 10/1 - added 2 variables */
        l_num_rma_line_number          NUMBER;                 /*UNPLAN_NULL*/
    BEGIN
        p_error_message   := NULL;
        p_return_status   := 0;                              -- g_ret_success;


        --  lv_mo_org_id := NVL (mo_global.get_current_org_id,fnd_profile.VALUE ('ORG_ID'));

        oe_msg_pub.initialize;
        oe_debug_pub.initialize;
        x_debug_file      := oe_debug_pub.set_debug_mode ('FILE');
        oe_debug_pub.setdebuglevel (5);
        msg ('Begining of Process Order API');

        FOR c_det_unplan_rec IN c_det_unplan_cur
        LOOP
            l_line_tbl_index                          := 1;
            l_line_tbl (l_line_tbl_index)             := oe_order_pub.g_miss_line_rec;
            l_line_tbl (l_line_tbl_index).header_id   :=
                c_det_unplan_rec.header_id;
            --Mandatory fields like qty, inventory item id are to be passed
            msg ('Deriving Values');

            IF lv_num_first = 0
            THEN
                lv_org_exists   := c_det_unplan_rec.org_id;
            END IF;


            SELECT oe_order_lines_s.NEXTVAL
              INTO l_line_tbl (l_line_tbl_index).line_id
              FROM DUAL;

            SELECT organization_id
              INTO l_line_tbl (l_line_tbl_index).ship_from_org_id
              FROM mtl_parameters
             WHERE organization_code = c_det_unplan_rec.wh_id;

            msg (
                   'Organization id '
                || l_line_tbl (l_line_tbl_index).ship_from_org_id);

            /*SELECT org_id
              INTO p_header_rec.org_id
              FROM oe_order_lines_all
             WHERE header_id = c_det_unplan_rec.header_id AND ROWNUM = 1; */

            SELECT order_type_id
              INTO p_header_rec.order_type_id
              FROM oe_order_headers_all
             WHERE header_id = c_det_unplan_rec.header_id;

            /* 10/1 - create unplanned RMA line with shipment 2 so it wont get extracted again */
            /*Start with UNPLAN_NULL*/
            l_num_rma_line_number                     := 0;

            BEGIN
                SELECT MAX (TO_NUMBER (line_number))
                  INTO l_num_rma_line_number
                  FROM oe_order_lines_all
                 WHERE header_id = c_det_unplan_rec.header_id;

                IF l_num_rma_line_number > 0
                THEN
                    l_line_tbl (l_line_tbl_index).line_number       :=
                        l_num_rma_line_number + 1;
                    l_line_tbl (l_line_tbl_index).shipment_number   := 2;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error while fetching line number for order header :'
                        || c_det_unplan_rec.header_id
                        || ' '
                        || SQLERRM);
            END;

            /*Ends with UNPLAN_NULL*/

            IF (lv_num_first = 0 OR (lv_org_exists <> c_det_unplan_rec.org_id)) /*OU_BUG issue*/
            THEN
                get_resp_details (c_det_unplan_rec.org_id, 'ONT', lv_mo_resp_id
                                  , lv_mo_resp_appl_id);
                --     FND_CLIENT_INFO.SET_ORG_CONTEXT( p_header_rec.org_id );
                apps.fnd_global.apps_initialize (
                    user_id        => g_num_user_id,
                    resp_id        => lv_mo_resp_id, --54066,-- 56626,--g_num_resp_id,--50225,--g_num_resp_id,--_id54066,
                    resp_appl_id   => lv_mo_resp_appl_id --20003-- 20024--g_num_resp_app_id
                                                        );
                mo_global.init ('ONT');
            /****************************
            apps.fnd_global.apps_initialize (user_id        => 2531,
                                             resp_id        => 50744,
                                             resp_appl_id   => 660);
            mo_global.init ('ONT');
            --MO_GLOBAL.SET_POLICY_CONTEXT('S', 95);
            msg ('CRP3..'); */



            END IF;

            /*OU_BUG issue*/
            --   mo_global.set_policy_context ('S', p_header_rec.org_id);
            l_line_tbl (l_line_tbl_index).ordered_quantity   :=
                c_det_unplan_rec.qty;
            l_line_tbl (l_line_tbl_index).org_id      :=
                c_det_unplan_rec.org_id;
            l_line_tbl (l_line_tbl_index).inventory_item_id   :=
                c_det_unplan_rec.inventory_item_id;
            --   := pu_line_tbl (l_line_tbl_index).ship_from_org_id;
            l_line_tbl (l_line_tbl_index).subinventory   :=
                c_det_unplan_rec.host_subinventory;

            l_line_tbl (l_line_tbl_index).return_reason_code   :=
                NVL (
                    c_det_unplan_rec.cust_return_reason,
                    NVL (fnd_profile.VALUE ('XXDO_3PL_EDI_RET_REASON_CODE'),
                         'UAR - 0010'));
            msg (
                   'Customer return reason'
                || l_line_tbl (l_line_tbl_index).return_reason_code);
            l_line_tbl (l_line_tbl_index).flow_status_code   :=
                'AWAITING_RETURN';
            msg ('p_header_rec.order_type_id' || p_header_rec.order_type_id);
            msg (' p_header_rec.org_id' || c_det_unplan_rec.org_id);

            BEGIN
                SELECT default_inbound_line_type_id
                  INTO l_line_tbl (l_line_tbl_index).line_type_id
                  FROM oe_transaction_types_all
                 WHERE     transaction_type_id = p_header_rec.order_type_id
                       AND org_id = c_det_unplan_rec.org_id;

                msg (
                       'Line type id '
                    || l_line_tbl (l_line_tbl_index).line_type_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_line_tbl (l_line_tbl_index).line_type_id   := NULL;
            END;

            /*--added for version 1.1*/
            -- l_line_tbl (l_line_tbl_index).attribute12 := c_det_unplan_rec.damage_code;                           --Added for Damege code
            l_line_tbl (l_line_tbl_index).operation   :=
                oe_globals.g_opr_create;
            msg ('Calling process order API');
            oe_order_pub.process_order (
                p_api_version_number       => 1.0,
                p_init_msg_list            => fnd_api.g_false,
                p_return_values            => fnd_api.g_false,
                p_action_commit            => fnd_api.g_false,
                x_return_status            => l_return_status,
                x_msg_count                => l_msg_count,
                x_msg_data                 => l_msg_data,
                p_header_rec               => l_header_rec,
                p_line_tbl                 => l_line_tbl,
                p_action_request_tbl       => l_action_request_tbl,
                x_header_rec               => l_header_rec,
                x_header_val_rec           => x_header_val_rec,
                x_header_adj_tbl           => x_header_adj_tbl,
                x_header_adj_val_tbl       => x_header_adj_val_tbl,
                x_header_price_att_tbl     => x_header_price_att_tbl,
                x_header_adj_att_tbl       => x_header_adj_att_tbl,
                x_header_adj_assoc_tbl     => x_header_adj_assoc_tbl,
                x_header_scredit_tbl       => x_header_scredit_tbl,
                x_header_scredit_val_tbl   => x_header_scredit_val_tbl,
                x_line_tbl                 => lv_line_tbl,
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
                x_action_request_tbl       => l_action_request_tbl);
            COMMIT;
            -- Retrieve messages
            msg ('Order Line msg' || l_msg_count);

            FOR k IN 1 .. l_msg_count
            LOOP
                oe_msg_pub.get (p_msg_index => k, p_encoded => fnd_api.g_false, p_data => l_msg_data
                                , p_msg_index_out => lv_next_msg);
                fnd_file.put_line (fnd_file.LOG, 'message is:' || l_msg_data);
            END LOOP;

            -- Check the return status
            IF l_return_status = fnd_api.g_ret_sts_success
            THEN
                msg ('Process Order Sucess');
                msg ('Total Line ' || l_line_tbl.COUNT);

                FOR j IN 1 .. l_line_tbl.COUNT
                LOOP
                    msg ('Process Order Sucess');
                    lv_hold_exists   := 1;

                    UPDATE xxdo_ont_rma_line_stg
                       SET line_number = l_line_tbl (l_line_tbl_index).line_id, attribute1 = l_line_tbl (l_line_tbl_index).line_id, result_code = 'C'
                     WHERE     request_id = g_num_request_id
                           AND process_status = 'INPROCESS'
                           AND receipt_line_seq_id =
                               c_det_unplan_rec.receipt_line_seq_id;

                    UPDATE xxdo_ont_rma_line_serl_stg
                       SET line_number = l_line_tbl (l_line_tbl_index).line_id
                     WHERE     request_id = g_num_request_id
                           AND process_status = 'INPROCESS'
                           AND receipt_line_seq_id =
                               c_det_unplan_rec.receipt_line_seq_id;

                    COMMIT;
                END LOOP;
            ELSE
                FOR m IN 1 .. l_line_tbl.COUNT
                LOOP
                    msg ('Api failing with error' || l_return_status);

                    UPDATE xxdo_ont_rma_line_stg
                       SET line_number = c_det_unplan_rec.line_number, process_status = 'ERROR', result_code = 'E',
                           error_message = 'API Failed while creating Line'
                     WHERE     request_id = g_num_request_id
                           AND process_status = 'INPROCESS'
                           AND receipt_line_seq_id =
                               c_det_unplan_rec.receipt_line_seq_id;

                    COMMIT;
                -- RETURN;
                END LOOP;
            END IF;

            lv_num_first                              :=
                lv_num_first + 1;
            lv_org_exists                             :=
                c_det_unplan_rec.org_id;


            IF lv_hold_exists = 1
            THEN
                FOR c_hold_data_rec
                    IN (SELECT header_id, line_number, org_id
                          FROM xxdo_ont_rma_line_stg
                         WHERE     process_status = 'INPROCESS'
                               AND result_code = 'C'
                               AND request_id = g_num_request_id
                               AND receipt_line_seq_id =
                                   c_det_unplan_rec.receipt_line_seq_id)
                LOOP
                    lv_order_tbl (lv_num).header_id   :=
                        c_hold_data_rec.header_id;
                    lv_order_tbl (lv_num).line_id   :=
                        c_hold_data_rec.line_number;

                    -- lv_num := lv_num + 1; /*OU_BUG issue*/
                    BEGIN
                        apply_hold (lv_order_tbl, c_hold_data_rec.org_id, 'Hold applied'
                                    , lv_retcode, lv_error_buf);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            p_return_status   := 2;
                            msg ('Error while calling process_unplanned_rma');
                            p_error_message   :=
                                   'Error while calling process_unplanned_rma'
                                || SQLERRM;
                    END;
                /*OU_BUG issue*/
                END LOOP;
            END IF;
        END LOOP;                           /*Main Cursor for Line ends here*/
    /*OU_BUG issue*/
    /*  IF lv_hold_exists = 1
      THEN
         BEGIN
            apply_hold (lv_order_tbl,
                        'Hold applied',
                        lv_retcode,
                        lv_error_buf
                       );
         EXCEPTION
            WHEN OTHERS
            THEN
               p_return_status := 2;
               msg ('Error while calling process_unplanned_rma');
               p_error_message :=
                       'Error while calling process_unplanned_rma' || SQLERRM;
         END;
      END IF; */
    /*OU_BUG issue*/
    --    END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_return_status   := 2;
            p_error_message   := SQLERRM;
            msg ('Error In ' || lv_procedure || SQLERRM);
    END;

    PROCEDURE process_rtp (p_group_id IN NUMBER, p_wait IN VARCHAR2:= 'Y', p_return_status OUT NUMBER
                           , p_error_message OUT VARCHAR2)
    IS
        lv_req_id                NUMBER;
        lv_req_status            BOOLEAN;
        lv_phase                 VARCHAR2 (80);
        lv_status                VARCHAR2 (80);
        lv_dev_phase             VARCHAR2 (80);
        lv_dev_status            VARCHAR2 (80);
        lv_message               VARCHAR2 (255);
        lv_new_mo_resp_id        NUMBER;
        lv_new_mo_resp_appl_id   NUMBER;
        lv_org_exists            NUMBER;
        lv_num_first             NUMBER := 0;
        lv_procedure             VARCHAR2 (100)
                                     := g_package_name || '.process_rtp';
    BEGIN
        p_error_message   := NULL;
        p_return_status   := 0;                               --g_ret_success;

        /*OU_BUG issue*/
        FOR org_rec
            IN (  SELECT DISTINCT GROUP_ID, org_id
                    FROM xxdo_ont_rma_line_stg rti
                   WHERE     process_status = 'INPROCESS'
                         AND request_id = g_num_request_id
                ORDER BY GROUP_ID)
        LOOP
            IF lv_num_first = 0
            THEN
                lv_org_exists   := org_rec.org_id;
            END IF;

            IF (lv_num_first = 0 OR (lv_org_exists != org_rec.org_id)) /*OU_BUG issue*/
            THEN
                msg ('Org id is-' || org_rec.org_id);
                get_resp_details (org_rec.org_id, 'PO', lv_new_mo_resp_id,
                                  lv_new_mo_resp_appl_id);
                apps.fnd_global.apps_initialize (
                    user_id        => g_num_user_id,
                    resp_id        => lv_new_mo_resp_id,
                    resp_appl_id   => lv_new_mo_resp_appl_id);
                --  mo_global.set_policy_context('M',org_rec.org_id);
                mo_global.init ('PO');
            END IF;

            /*OU_BUG issue*/
            lv_req_id       :=
                fnd_request.submit_request (
                    application   => 'PO',
                    program       => 'RVCTP',
                    argument1     => 'BATCH',
                    argument2     => TO_CHAR (org_rec.GROUP_ID),
                    argument3     => org_rec.org_id);

            COMMIT;

            IF NVL (p_wait, 'Y') = 'Y'
            THEN
                lv_req_status   :=
                    fnd_concurrent.wait_for_request (
                        request_id   => lv_req_id,
                        INTERVAL     => 10,
                        max_wait     => 0,
                        phase        => lv_phase,
                        status       => lv_status,
                        dev_phase    => lv_dev_phase,
                        dev_status   => lv_dev_status,
                        MESSAGE      => lv_message);

                IF NVL (lv_dev_status, 'ERROR') != 'NORMAL'
                THEN
                    IF NVL (lv_dev_status, 'ERROR') = 'WARNING'
                    THEN
                        p_return_status   := 1;           --g_ret_sts_warning;
                    ELSE
                        p_return_status   := 2;    -- fnd_api.g_ret_sts_error;
                    END IF;

                    p_error_message   :=
                        NVL (
                            lv_message,
                               'The receiving transaction processor request ended with a status of '
                            || NVL (lv_dev_status, 'ERROR'));
                    msg ('Error In Receiing Transaction processor');
                ELSE
                    UPDATE xxdo_ont_rma_line_stg
                       SET GROUP_ID   = p_group_id
                     WHERE     process_status = 'INPROCESS'
                           AND request_id = g_num_request_id;

                    COMMIT;
                END IF;
            END IF;

            lv_num_first    := lv_num_first + 1;
            lv_org_exists   := org_rec.org_id;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_return_status   := 2;
            p_error_message   := SQLERRM;
            msg ('Error In ' || lv_procedure || SQLERRM);
    END;

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
        UPDATE xxdo_ont_rma_line_stg dtl
           SET (dtl.error_message, dtl.process_status)   =
                   (SELECT SUBSTR (pie.error_message, 1, 1000), 'ERROR'
                      FROM po_interface_errors pie, rcv_transactions_interface rti
                     WHERE     pie.interface_line_id =
                               rti.interface_transaction_id
                           --AND rti.transaction_status_code = 'ERROR'
                           AND rti.oe_order_header_id = dtl.header_id
                           AND rti.oe_order_line_id = dtl.line_number
                           AND dtl.GROUP_ID = rti.GROUP_ID
                           AND ROWNUM = 1),
               last_updated_by     = g_num_user_id,
               last_update_date    = SYSDATE,
               last_update_login   = g_num_login_id
         WHERE     dtl.process_status = 'INPROCESS'
               AND dtl.request_id = g_num_request_id
               AND EXISTS
                       (SELECT 1
                          FROM po_interface_errors pie, rcv_transactions_interface rti
                         WHERE     pie.interface_line_id =
                                   rti.interface_transaction_id
                               --AND rti.transaction_status_code = 'ERROR'
                               AND rti.oe_order_header_id = dtl.header_id
                               AND rti.oe_order_line_id = dtl.line_number
                               AND dtl.GROUP_ID = rti.GROUP_ID);

        COMMIT;

        /* 9/15 delete error records from receiving interface */
        /*Start with DELETE_TRAN*/
        DELETE FROM
            po_interface_errors pie
              WHERE pie.interface_line_id IN
                        (SELECT rti.interface_transaction_id
                           FROM rcv_transactions_interface rti
                          WHERE     rti.processing_status_code = 'ERROR'
                                AND rti.GROUP_ID IN
                                        (SELECT x.GROUP_ID
                                           FROM xxdo_ont_rma_line_stg x
                                          WHERE     x.process_status =
                                                    'ERROR'
                                                AND x.request_id =
                                                    g_num_request_id));

        DELETE FROM
            rcv_transactions_interface rti
              WHERE     rti.processing_status_code = 'ERROR'
                    AND rti.GROUP_ID IN
                            (SELECT x.GROUP_ID
                               FROM xxdo_ont_rma_line_stg x
                              WHERE     x.process_status = 'ERROR'
                                    AND x.request_id = g_num_request_id);

        COMMIT;

        /*Ends with DELETE_TRAN*/

        UPDATE xxdo_ont_rma_line_stg line
           SET process_status = 'HOLD', error_message = '', result_code = 'H',
               type1 = 'PLANNED', last_updated_by = g_num_user_id, last_update_date = SYSDATE,
               last_update_login = g_num_login_id
         WHERE     process_status IN ('INPROCESS')
               AND request_id = g_num_request_id
               AND EXISTS
                       (SELECT 1
                          FROM oe_order_holds_all ooh
                         WHERE     ooh.line_id = line.line_id
                               AND ooh.released_flag = 'N');

        COMMIT;

        UPDATE xxdo.xxdo_ont_rma_line_stg
           SET process_status = 'PROCESSED', result_code = 'P', error_message = '',
               last_updated_by = g_num_user_id, last_update_login = g_num_login_id, last_update_date = SYSDATE
         WHERE process_status = 'INPROCESS' AND request_id = g_num_request_id;

        COMMIT;

        ---------Updating the RA Header Data
        UPDATE xxdo_ont_rma_hdr_stg head
           SET head.process_status = 'ERROR', result_code = 'E', error_message = 'Error Due to Line Record',
               last_updated_by = g_num_user_id, last_update_login = g_num_login_id, last_update_date = SYSDATE
         WHERE     head.process_status = 'INPROCESS'
               AND head.request_id = g_num_request_id
               AND EXISTS
                       (SELECT 1
                          FROM xxdo_ont_rma_line_stg dtl
                         WHERE     dtl.receipt_header_seq_id =
                                   head.receipt_header_seq_id
                               AND dtl.request_id = g_num_request_id
                               AND dtl.process_status = 'ERROR');

        COMMIT;



        --Update Hold Record
        UPDATE xxdo_ont_rma_hdr_stg hdr
           SET process_status = 'HOLD', error_message = '', result_code = 'H',
               last_updated_by = g_num_user_id, last_update_login = g_num_login_id, last_update_date = SYSDATE
         WHERE     process_status IN ('INPROCESS')
               AND request_id = g_num_request_id
               AND EXISTS
                       (SELECT 1
                          FROM oe_order_holds_all ooh, oe_order_headers_all oeh, oe_order_lines_all oel
                         WHERE     ooh.header_id = oeh.header_id
                               AND ooh.released_flag = 'N'
                               AND oeh.order_number = rma_number
                               AND oeh.header_id = oel.header_id
                               AND ooh.line_id = oel.line_id);

        COMMIT;

        UPDATE xxdo.xxdo_ont_rma_hdr_stg
           SET process_status = 'PROCESSED', result_code = 'P', error_message = '',
               last_updated_by = g_num_user_id, last_update_login = g_num_login_id, last_update_date = SYSDATE
         WHERE process_status = 'INPROCESS' AND request_id = g_num_request_id;

        COMMIT;
        lv_status   := '';
        lv_cnt      := 0;

        ---Update Serial Records to error
        UPDATE xxdo_ont_rma_line_serl_stg serial
           SET serial.process_status = 'ERROR', result_code = 'P', last_updated_by = g_num_user_id,
               last_update_login = g_num_login_id, last_update_date = SYSDATE
         WHERE     serial.process_status = 'INPROCESS'
               AND serial.request_id = g_num_request_id
               AND EXISTS
                       (SELECT 1
                          FROM xxdo_ont_rma_line_stg dtl
                         WHERE     dtl.receipt_line_seq_id =
                                   serial.receipt_line_seq_id
                               AND dtl.request_id = g_num_request_id
                               AND dtl.process_status = 'ERROR');

        ---Update Serial Records to hold
        UPDATE xxdo_ont_rma_line_serl_stg serial
           SET serial.process_status = 'HOLD', result_code = 'P', last_updated_by = g_num_user_id,
               last_update_login = g_num_login_id, last_update_date = SYSDATE
         WHERE     serial.process_status = 'INPROCESS'
               AND serial.request_id = g_num_request_id
               AND EXISTS
                       (SELECT 1
                          FROM xxdo_ont_rma_line_stg dtl
                         WHERE     dtl.receipt_line_seq_id =
                                   serial.receipt_line_seq_id
                               AND dtl.request_id = g_num_request_id
                               AND dtl.process_status = 'HOLD');

        ---Update Serial Records to processed
        UPDATE xxdo_ont_rma_line_serl_stg serial
           SET serial.process_status = 'PROCESSED', result_code = 'P', last_updated_by = g_num_user_id,
               last_update_login = g_num_login_id, last_update_date = SYSDATE
         WHERE     serial.process_status = 'INPROCESS'
               AND serial.request_id = g_num_request_id
               AND EXISTS
                       (SELECT 1
                          FROM xxdo_ont_rma_line_stg dtl
                         WHERE     dtl.receipt_line_seq_id =
                                   serial.receipt_line_seq_id
                               AND dtl.request_id = g_num_request_id
                               AND dtl.process_status = 'PROCESSED');

        COMMIT;

        UPDATE xxdo.xxdo_serial_temp xst
           SET (source_code, source_code_reference, inventory_item_id,
                organization_id)   =
                   (SELECT 'RMA_RECEIPT', xos.line_number, xos.inventory_item_id,
                           xos.organization_id
                      FROM xxdo_ont_rma_line_serl_stg xos, mtl_parameters mp, mtl_system_items_kfv msi --Replaced table mtl_system_items with mtl_system_items_kfv for BT Remediation
                     WHERE     xos.process_status = 'PROCESSED'
                           AND xos.serial_number = xst.serial_number
                           /*commented for BT Remediation
                            AND xos.item_number =
                                      msi.segment1
                                   || '-'
                                   || msi.segment2
                                   || '-'
                                   || msi.segment3 */
                           AND xos.item_number = msi.concatenated_segments --Added for BT Remediation
                           AND xos.wh_id = mp.organization_code
                           AND msi.organization_id = mp.organization_id
                           --   and   xos.inventory_item_id =xst.inventory_item_id
                           --   and  xos.organization_id=xst.organization_id
                           AND xos.request_id = g_num_request_id)
         WHERE EXISTS
                   (SELECT 1
                      FROM xxdo_ont_rma_line_serl_stg xos
                     WHERE     xos.process_status = 'PROCESSED'
                           AND xos.serial_number = xst.serial_number
                           --   and   xos.inventory_item_id =xst.inventory_item_id
                           --       and  xos.organization_id=xst.organization_id
                           AND xos.request_id = g_num_request_id);

        COMMIT;

        INSERT INTO xxdo.xxdo_serial_temp xst (serial_number, inventory_item_id, last_update_date, last_updated_by, creation_date, created_by, organization_id, source_code, source_code_reference
                                               , status_id)
            SELECT xos.serial_number, xos.inventory_item_id, SYSDATE,
                   g_num_user_id, SYSDATE, g_num_user_id,
                   xos.organization_id, 'RMA_RECEIPT', xos.line_number,
                   1
              FROM xxdo_ont_rma_line_serl_stg xos, mtl_parameters mp, mtl_system_items_kfv msi --Replaced table mtl_system_items with mtl_system_items_kfv for BT Remediation
             WHERE     xos.process_status = 'PROCESSED'
                   AND xos.request_id = g_num_request_id
                   /*commented for BT Remediation
                   AND xos.item_number =
                           msi.segment1 || '-' || msi.segment2 || '-' || msi.segment3  */
                   AND xos.item_number = msi.concatenated_segments --Added for BT Remediation
                   --   AND xos.inventory_item_id =msi.inventory_item_id
                   AND msi.organization_id = mp.organization_id
                   AND xos.wh_id = mp.organization_code
                   AND NOT EXISTS
                           (SELECT 1
                              FROM xxdo.xxdo_serial_temp xst
                             WHERE xos.serial_number = xst.serial_number);

        COMMIT;

        /*Start updating DAMAGE_CODE,FACTORY_CODE,PROD_CODE*/

        BEGIN
            UPDATE oe_order_lines_all oel
               SET oel.attribute12   =
                       (SELECT line.damage_code
                          FROM xxdo_ont_rma_line_stg line
                         WHERE     line.process_status IN
                                       ('PROCESSED', 'HOLD')
                               AND line.request_id = g_num_request_id
                               AND oel.header_id = line.header_id
                               AND oel.line_id = line.line_number)
             WHERE --oel.flow_status_code IN ('RETURNED', 'CLOSED')                 --commented for version 1.1
                   EXISTS
                       (SELECT 1
                          FROM xxdo_ont_rma_line_stg line
                         WHERE     line.process_status IN
                                       ('PROCESSED', 'HOLD')
                               AND line.request_id = g_num_request_id
                               AND oel.header_id = line.header_id
                               AND oel.line_id = line.line_number);
        EXCEPTION
            WHEN OTHERS
            THEN
                msg (
                    'Records in error while updating damage_code' || SQLERRM);
        END;

        BEGIN
            UPDATE oe_order_lines_all oel
               SET (attribute4)   =
                       (SELECT aps.vendor_id
                          FROM xxdo_ont_rma_line_stg line, ap_suppliers aps
                         WHERE     line.request_id = g_num_request_id
                               AND line.process_status IN
                                       ('PROCESSED', 'HOLD')
                               AND oel.header_id = line.header_id
                               AND oel.line_id = line.line_number
                               AND aps.vendor_type_lookup_code =
                                   'MANUFACTURER'
                               AND NVL (aps.start_date_active, SYSDATE) <
                                   SYSDATE + 1
                               AND NVL (aps.end_date_active, SYSDATE) >=
                                   SYSDATE
                               AND NVL (aps.enabled_flag, 'N') = 'Y'
                               AND aps.attribute1 = line.factory_code)
             WHERE --oel.flow_status_code IN ('RETURNED', 'CLOSED')                                   --commented for version 1.1
                   EXISTS
                       (SELECT 1
                          FROM xxdo_ont_rma_line_stg line
                         WHERE     line.process_status IN
                                       ('PROCESSED', 'HOLD')
                               AND line.request_id = g_num_request_id
                               AND oel.header_id = line.header_id
                               AND oel.line_id = line.line_number);
        EXCEPTION
            WHEN OTHERS
            THEN
                msg (
                    'Records in error while updating Factory Code' || SQLERRM);
        END;

        BEGIN
            UPDATE oe_order_lines_all oel
               SET attribute5   =
                       (SELECT dom.MONTH_YEAR_CODE
                          FROM xxdo_ont_rma_line_stg line1, DO_BOM_MONTH_YEAR_V dom
                         WHERE     dom.MONTH_YEAR_CODE = line1.prod_code
                               AND line1.request_id = g_num_request_id
                               AND line1.process_status IN
                                       ('PROCESSED', 'HOLD')
                               AND oel.header_id = line1.header_id
                               AND oel.line_id = line1.line_number)
             WHERE --oel.flow_status_code IN ('RETURNED', 'CLOSED')                                 --commented for version 1.1
                   EXISTS
                       (SELECT 1
                          FROM xxdo_ont_rma_line_stg line
                         WHERE     line.process_status IN
                                       ('PROCESSED', 'HOLD')
                               AND line.request_id = g_num_request_id
                               AND oel.header_id = line.header_id
                               AND oel.line_id = line.line_number);
        EXCEPTION
            WHEN OTHERS
            THEN
                msg ('Records in error while updating Prod Code' || SQLERRM);
        END;
    /*Ends  updating FACTORY_CODE,PROD_CODE*/
    -- To send notification for hold records
    /* 10/1/2015 commented holds report as there is seperate alert for this */
    /*
      mail_hold_report (p_out_chr_errbuf    => lv_error_message,
                        p_out_chr_retcode   => lv_retcode);

      IF lv_retcode <> '0'
      THEN
         p_error_message := lv_error_message;
         p_return_status := '1';
         fnd_file.put_line (
            fnd_file.LOG,
            'Unable to send Hold Report due to : ' || p_error_message);
      END IF;
      */
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('Error in  ' || lv_procedure || SQLERRM);
            p_return_status   := 2;
            p_error_message   := SQLERRM;
    END;

    PROCEDURE check_hold_released (p_return_status   OUT NUMBER,
                                   p_error_message   OUT VARCHAR2)
    IS
        lv_procedure   VARCHAR2 (100)
                           := g_package_name || '.check_hold_released';
        lv_rel_cnt     NUMBER;
        lv_yes_hold    VARCHAR (2);
    BEGIN
        UPDATE xxdo_ont_rma_line_stg rma_line
           SET process_status = 'INPROCESS', result_code = 'P', error_message = '',
               request_id = g_num_request_id
         WHERE     rma_line.process_status IN ('HOLD')
               AND rma_number IS NOT NULL
               AND NOT EXISTS
                       (SELECT 1
                          FROM oe_order_holds_all ooh
                         WHERE     ooh.line_id = rma_line.line_number
                               AND ooh.released_flag = 'N');

        UPDATE xxdo_ont_rma_hdr_stg h
           SET process_status = 'INPROCESS', result_code = 'P', error_message = '',
               request_id = g_num_request_id
         WHERE     process_status IN ('HOLD')
               AND h.receipt_header_seq_id IN
                       (SELECT l.receipt_header_seq_id
                          FROM xxdo_ont_rma_line_stg l
                         WHERE     l.request_id = g_num_request_id
                               AND l.process_status = 'INPROCESS');

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('Error In  ' || lv_procedure || SQLERRM);
            p_return_status   := 2;
            p_error_message   := SQLERRM;
    END;

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
        lv_rma_receipt_headers_tab   g_rma_receipt_headers_tab_type;
        lv_rma_receipt_dtls_tab      g_rma_receipt_dtls_tab_type;
        lv_rma_sers_tab              g_carton_sers_tab_type;
        lv_exe_env_no_match          EXCEPTION;
        lv_exe_msg_type_no_match     EXCEPTION;
        lv_exe_bulk_fetch_failed     EXCEPTION;
        lv_exe_bulk_insert_failed    EXCEPTION;
        lv_exe_dml_errors            EXCEPTION;
        lv_no_records_flag           VARCHAR2 (1);
        PRAGMA EXCEPTION_INIT (lv_exe_dml_errors, -24381);

        CURSOR cur_xml_file_counts IS
            SELECT ROWID row_id, file_name
              FROM xxdo_ont_rma_xml_stg
             WHERE process_status = 'NEW';

        CURSOR cur_rma_receipt_headers IS
            SELECT EXTRACTVALUE (VALUE (par), 'RMA/wh_id') wh_id, EXTRACTVALUE (VALUE (par), 'RMA/rma_number') rma_number, TO_DATE (EXTRACTVALUE (VALUE (par), 'RMA/rma_receipt_date'), 'YYYY-MM-DD HH24:MI:SS') rma_receipt_date,
                   EXTRACTVALUE (VALUE (par), 'RMA/rma_reference') rma_reference, EXTRACTVALUE (VALUE (par), 'RMA/customer_id') customer_id, EXTRACTVALUE (VALUE (par), 'RMA/order_number') order_number,
                   EXTRACTVALUE (VALUE (par), 'RMA/order_number_type') order_number_type, EXTRACTVALUE (VALUE (par), 'RMA/customer_name') customer_name, EXTRACTVALUE (VALUE (par), 'RMA/customer_addr1') customer_addr1,
                   EXTRACTVALUE (VALUE (par), 'RMA/customer_addr2') customer_addr2, EXTRACTVALUE (VALUE (par), 'RMA/customer_addr3') customer_addr3, EXTRACTVALUE (VALUE (par), 'RMA/customer_city') customer_city,
                   EXTRACTVALUE (VALUE (par), 'RMA/customer_zip') customer_zip, EXTRACTVALUE (VALUE (par), 'RMA/customer_state') customer_state, EXTRACTVALUE (VALUE (par), 'RMA/customer_phone') customer_phone,
                   EXTRACTVALUE (VALUE (par), 'RMA/customer_email') customer_email, EXTRACTVALUE (VALUE (par), 'RMA/comments') comments, EXTRACTVALUE (VALUE (par), 'RMA/rma_type') rma_type,
                   EXTRACTVALUE (VALUE (par), 'RMA/notified_to_wms') notified_to_wms, EXTRACTVALUE (VALUE (par), 'RMA/COMPANY') company, EXTRACTVALUE (VALUE (par), 'RMA/CUSTOMER_COUNTRY_CODE') customer_country_code,
                   EXTRACTVALUE (VALUE (par), 'RMA/CUSTOMER_COUNTRY_NAME') customer_country_name, lv_num_request_id request_id, SYSDATE creation_date,
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
                   NULL retcode, 'INSERT' record_type, xxdo_ont_rma_hdr_stg_s.NEXTVAL receipt_header_seq_id,
                   message_id,                      --Added For CCR CCR0007954
                               NULL rma_xml_seq_id
              FROM xxdo_ont_rma_xml_stg xml_tab, TABLE (XMLSEQUENCE (EXTRACT (xml_tab.xml_document, (CHR (47) || CHR (47) || 'RAReceiptMessage/RMAs' || CHR (47) || CHR (42))))) par
             WHERE process_status = 'NEW';

        CURSOR cur_rma_receipt_dtls IS
            SELECT EXTRACTVALUE (VALUE (par), 'RMADetail/wh_id') wh_id, EXTRACTVALUE (VALUE (par), 'RMADetail/rma_number') rma_number, NULL rma_reference,
                   EXTRACTVALUE (VALUE (par), 'RMADetail/line_number') line_number, EXTRACTVALUE (VALUE (par), 'RMADetail/item_number') item_number, EXTRACTVALUE (VALUE (par), 'RMADetail/type') type1,
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
                   NULL rma_receipt_date, NULL org_id,        /*OU_BUG issue*/
                                                       NULL rma_xml_seq_id
              FROM xxdo_ont_rma_xml_stg xml_tab, TABLE (XMLSEQUENCE (EXTRACT (xml_tab.xml_document, (CHR (47) || CHR (47) || 'RAReceiptMessage/RMAs/RMA/RMADetails' || CHR (47) || CHR (42))))) par
             WHERE process_status = 'NEW';

        CURSOR cur_serials IS
            SELECT EXTRACTVALUE (VALUE (par), 'RMADetailSerial/wh_id') wh_id, EXTRACTVALUE (VALUE (par), 'RMADetailSerial/rma_number') rma_number, EXTRACTVALUE (VALUE (par), 'RMADetailSerial/line_number') line_number,
                   EXTRACTVALUE (VALUE (par), 'RMADetailSerial/item_number') item_number, EXTRACTVALUE (VALUE (par), 'RMADetailSerial/serial_number') serial_number, EXTRACTVALUE (VALUE (par), 'RMADetailSerial/rma_reference') rma_reference,
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
              FROM xxdo_ont_rma_xml_stg xml_tab, TABLE (XMLSEQUENCE (EXTRACT (xml_tab.xml_document, (CHR (47) || CHR (47) || 'RAReceiptMessage/RMAs/RMA/RMADetails/RMADetail/RMADetailSerials' || CHR (47) || CHR (42))))) par
             WHERE process_status = 'NEW';
    BEGIN
        p_retcode   := '0';
        p_errbuf    := NULL;
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
            WHEN NO_DATA_FOUND
            THEN
                fnd_file.put_line (fnd_file.LOG, 'No Records To Process');
                lv_no_records_flag   := 'Y';
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Error While Extracting msg type and env' || SQLERRM);
                lv_chr_xml_message_type   := '-1';
                lv_chr_xml_environment    := '-1';
        END;

        fnd_file.put_line (
            fnd_file.LOG,
            'Database name in XML: ' || lv_chr_xml_environment);
        fnd_file.put_line (
            fnd_file.LOG,
            'Message type in XML: ' || lv_chr_xml_message_type);

        IF NVL (lv_no_records_flag, 'N') <> 'Y'
        THEN
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

            SAVEPOINT l_sv_before_load_rma_rec;
            fnd_file.put_line (
                fnd_file.LOG,
                'l_sv_before_load_rma_rec - Savepoint Established');

            -- Logic to insert ASN Headers
            OPEN cur_rma_receipt_headers;

            LOOP
                IF lv_rma_receipt_headers_tab.EXISTS (1)
                THEN
                    lv_rma_receipt_headers_tab.DELETE;
                END IF;

                --   BEGIN
                --     for i in lv_rma_receipt_headers_tab.FIRST .. lv_rma_receipt_headers_tab.LAST
                --     loop
                --   msg('wh_id'||lv_rma_receipt_headers_tab(i).wh_id);
                --     msg('rma_number'||lv_rma_receipt_headers_tab(i).rma_number);
                --    msg('rma receipt date'||lv_rma_receipt_headers_tab(i).rma_receipt_date);
                --    end loop;
                --  END
                BEGIN
                    FETCH cur_rma_receipt_headers
                        BULK COLLECT INTO lv_rma_receipt_headers_tab
                        LIMIT p_in_num_bulk_limit;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        CLOSE cur_rma_receipt_headers;

                        p_errbuf   :=
                               'Unexcepted error in BULK Fetch of RMA Receipt Headers : '
                            || SQLERRM;
                        fnd_file.put_line (fnd_file.LOG, p_errbuf);
                        RAISE lv_exe_bulk_fetch_failed;
                END;                                       --end of bulk fetch

                IF NOT lv_rma_receipt_headers_tab.EXISTS (1)
                THEN
                    EXIT;
                END IF;

                --;
                BEGIN
                    FORALL lv_num_ind
                        IN lv_rma_receipt_headers_tab.FIRST ..
                           lv_rma_receipt_headers_tab.LAST
                      SAVE EXCEPTIONS
                        INSERT INTO xxdo_ont_rma_hdr_stg
                             VALUES lv_rma_receipt_headers_tab (lv_num_ind);
                EXCEPTION
                    WHEN lv_exe_dml_errors
                    THEN
                        lv_num_error_count   := SQL%BULK_EXCEPTIONS.COUNT;
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Number of statements that failed during Bulk Insert of RMA Receipt headers: '
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
                                || SQLERRM (
                                       -SQL%BULK_EXCEPTIONS (i).ERROR_CODE));
                        END LOOP;
                    --                              CLOSE cur_asn_receipt_headers;
                    --                              RAISE l_exe_bulk_insert_failed;
                    WHEN OTHERS
                    THEN
                        CLOSE cur_rma_receipt_headers;

                        p_errbuf   :=
                               'Unexcepted error in BULK Insert of RMA Receipt Headers : '
                            || SQLERRM;
                        fnd_file.put_line (fnd_file.LOG, p_errbuf);
                        RAISE lv_exe_bulk_insert_failed;
                END;
            END LOOP;                            -- Receipt headers fetch loop

            CLOSE cur_rma_receipt_headers;

            -- Logic to insert ASN Details
            OPEN cur_rma_receipt_dtls;

            LOOP
                IF lv_rma_receipt_dtls_tab.EXISTS (1)
                THEN
                    lv_rma_receipt_dtls_tab.DELETE;
                END IF;

                BEGIN
                    FETCH cur_rma_receipt_dtls
                        BULK COLLECT INTO lv_rma_receipt_dtls_tab
                        LIMIT p_in_num_bulk_limit;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        CLOSE cur_rma_receipt_dtls;

                        p_errbuf   :=
                               'Unexcepted error in BULK Fetch of RMA Receipt Details : '
                            || SQLERRM;
                        fnd_file.put_line (fnd_file.LOG, p_errbuf);
                        RAISE lv_exe_bulk_fetch_failed;
                END;                                       --end of bulk fetch

                IF NOT lv_rma_receipt_dtls_tab.EXISTS (1)
                THEN
                    EXIT;
                END IF;

                BEGIN
                    FORALL l_num_ind
                        IN lv_rma_receipt_dtls_tab.FIRST ..
                           lv_rma_receipt_dtls_tab.LAST
                      SAVE EXCEPTIONS
                        INSERT INTO xxdo_ont_rma_line_stg
                             VALUES lv_rma_receipt_dtls_tab (l_num_ind);
                EXCEPTION
                    WHEN lv_exe_dml_errors
                    THEN
                        lv_num_error_count   := SQL%BULK_EXCEPTIONS.COUNT;
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Number of statements that failed during Bulk Insert of RMA Receipt Details: '
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
                                || SQLERRM (
                                       -SQL%BULK_EXCEPTIONS (i).ERROR_CODE));
                        END LOOP;
                    --                              CLOSE cur_asn_receipt_dtls;
                    --                              RAISE l_exe_bulk_insert_failed;
                    WHEN OTHERS
                    THEN
                        CLOSE cur_rma_receipt_dtls;

                        p_errbuf   :=
                               'Unexcepted error in BULK Insert of RMA Receipt Details: '
                            || SQLERRM;
                        fnd_file.put_line (fnd_file.LOG, p_errbuf);
                        RAISE lv_exe_bulk_insert_failed;
                END;
            END LOOP;                            -- Receipt details fetch loop

            CLOSE cur_rma_receipt_dtls;

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
                               'Unexcepted error in BULK Fetch of RMA Serials : '
                            || SQLERRM;
                        fnd_file.put_line (fnd_file.LOG, p_errbuf);
                        RAISE lv_exe_bulk_fetch_failed;
                END;                                       --end of bulk fetch

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
                               'Number of statements that failed during Bulk Insert of RMA Serials: '
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
                                || SQLERRM (
                                       -SQL%BULK_EXCEPTIONS (i).ERROR_CODE));
                        END LOOP;
                    --                              CLOSE cur_serials;
                    --                              RAISE l_exe_bulk_insert_failed;
                    WHEN OTHERS
                    THEN
                        CLOSE cur_serials;

                        p_errbuf   :=
                               'Unexcepted error in BULK Insert of RMA Serials : '
                            || SQLERRM;
                        fnd_file.put_line (fnd_file.LOG, p_errbuf);
                        RAISE lv_exe_bulk_insert_failed;
                END;
            END LOOP;                            -- Receipt details fetch loop

            CLOSE cur_serials;

            -- Update the XML file extract status and commit
            BEGIN
                UPDATE xxdo_ont_rma_xml_stg
                   SET process_status = 'PROCESSED', last_update_date = SYSDATE, last_updated_by = lv_num_user_id
                 WHERE     process_status = 'NEW'
                       AND request_id = g_num_request_id;

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
                    ROLLBACK TO l_sv_before_load_rma_rec;
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
                                   AND headers.rma_number = dtl.rma_number)
                 WHERE     dtl.request_id = g_num_request_id
                       AND dtl.process_status = 'NEW';
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_retcode   := '2';
                    p_errbuf    :=
                           'Unexpected error while updating the sequence ids in the RMA receipt details table : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_errbuf);
                    ROLLBACK TO l_sv_before_load_rma_rec;
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
                                   AND dtl.rma_number = ser.rma_number
                                   AND dtl.line_number = ser.line_number
                                   AND dtl.item_number = ser.item_number)
                 WHERE     ser.request_id = g_num_request_id
                       AND ser.process_status = 'NEW';

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_retcode   := '2';
                    p_errbuf    :=
                           'Unexpected error while updating the sequence ids in the RMA receipt serials table : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_errbuf);
                    ROLLBACK TO l_sv_before_load_rma_rec;
            END;

            -- Error out the records which don't have parent
            lv_num_error_count   := 0;

            BEGIN
                UPDATE xxdo_ont_rma_line_stg
                   SET process_status = 'ERROR', error_message = 'No RMA Receipt Header Record in XML', last_updated_by = g_num_user_id,
                       last_update_date = SYSDATE
                 WHERE     process_status = 'NEW'
                       AND request_id = g_num_request_id
                       AND receipt_header_seq_id IS NULL;

                lv_num_error_count   := SQL%ROWCOUNT;

                UPDATE xxdo_ont_rma_line_serl_stg
                   SET process_status = 'ERROR', error_message = 'No RMA Receipt Detail Parent Record in XML', last_updated_by = g_num_user_id,
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
        END IF;
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
            -- Commit the status update
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
            ROLLBACK TO l_sv_before_load_rma_rec;

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
            ROLLBACK TO l_sv_before_load_rma_rec;

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
            ROLLBACK TO l_sv_before_load_rma_rec;
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
        lv_message_id          VARCHAR2 (50);
        ln_rec_count           NUMBER;
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
        --  SAVEPOINT lv_savepoint_before_load;
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

        /* Start of Changes for CCR CCR0007954*/
        --Get Message ID
        BEGIN
            SELECT stg.xml_document.EXTRACT ('//RAReceiptMessage/MessageHeader/MessageID/text()').getstringval () message_id
              INTO lv_message_id
              FROM xxdo_ont_rma_xml_stg stg
             WHERE     process_status = 'NEW'
                   AND file_name = p_in_chr_file_name
                   AND request_id = fnd_global.conc_request_id
                   AND ROWID =
                       (SELECT MAX (ROWID) row_id
                          FROM xxdo_ont_rma_xml_stg
                         WHERE     process_status = 'NEW'
                               AND file_name = p_in_chr_file_name
                               AND request_id = fnd_global.conc_request_id);
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Error While Extracting message id ' || SQLERRM);
                p_errbuf        := 'Error While Extracting Message ID' || SQLERRM;
                lv_message_id   := NULL;
        END;

        --Update tabe with message ID
        BEGIN
            UPDATE xxdo.xxdo_ont_rma_xml_stg
               SET message_id   = lv_message_id
             WHERE     process_status = 'NEW'
                   AND file_name = p_in_chr_file_name
                   AND request_id = fnd_global.conc_request_id
                   AND ROWID =
                       (SELECT MAX (ROWID) row_id
                          FROM xxdo_ont_rma_xml_stg
                         WHERE     process_status = 'NEW'
                               AND file_name = p_in_chr_file_name
                               AND request_id = fnd_global.conc_request_id);
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Error While Updating table With Message id ' || SQLERRM);
                p_errbuf   :=
                       'Error While Updating Staging Table With Message Id'
                    || SQLERRM;
        END;

        COMMIT;

        --Get Count of records with extracted message id
        BEGIN
            SELECT COUNT (1)
              INTO ln_rec_count
              FROM xxdo.xxdo_ont_rma_xml_stg
             WHERE message_id = lv_message_id AND process_status <> 'ERROR';
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error While Getting Count Of Records With Same Message ID '
                    || SQLERRM);
                p_errbuf   :=
                       'Error While Getting Count Of Records With Same Message ID'
                    || SQLERRM;
        END;

        --There must be only one record with message id. If there are more than one records update records to error
        IF ln_rec_count > 1
        THEN
            BEGIN
                UPDATE xxdo.xxdo_ont_rma_xml_stg
                   SET process_status = 'ERROR', error_message = 'Duplicate file with same message ID'
                 WHERE     process_status = 'NEW'
                       AND file_name = p_in_chr_file_name
                       AND request_id = fnd_global.conc_request_id
                       AND ROWID =
                           (SELECT MAX (ROWID) row_id
                              FROM xxdo_ont_rma_xml_stg
                             WHERE     process_status = 'NEW'
                                   AND file_name = p_in_chr_file_name
                                   AND request_id =
                                       fnd_global.conc_request_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error While Updating Staging Table With Duplicate File Error'
                        || SQLERRM);
                    p_errbuf   :=
                           'Error While Updating Staging Table With Duplicate File Error'
                        || SQLERRM;
            END;
        END IF;

        COMMIT;

        /*End of Changes for CCR CCR CCR0007954*/


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
            p_retcode   := 2;
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

    PROCEDURE validate_all_records (p_retcode     OUT NUMBER,
                                    p_error_buf   OUT VARCHAR2)
    IS
        l_chr_f_sql_stmt   VARCHAR2 (2000);
        l_chr_p_sql_stmt   VARCHAR2 (2000);
    BEGIN
        msg ('Validations of all RMA starting');

        /**********
        HEADER LEVEL VALIDATIONS
        **********/
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

        UPDATE xxdo_ont_rma_hdr_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'Invalid RMA'
         WHERE     request_id = g_num_request_id
               AND process_status = 'INPROCESS'
               AND x.rma_number IS NOT NULL
               AND NOT EXISTS
                       (SELECT 1
                          FROM oe_order_headers_all ooh
                         WHERE     ooh.order_number = x.rma_number
                               AND ooh.open_flag = 'Y'
                               AND ooh.booked_flag = 'Y')
               AND result_code IS NULL;

        UPDATE xxdo_ont_rma_hdr_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'RMA date cannot be null'
         WHERE     request_id = g_num_request_id
               AND process_status = 'INPROCESS'
               AND rma_receipt_date IS NULL
               AND result_code IS NULL;

        UPDATE xxdo_ont_rma_hdr_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'RMA date cannot be future date'
         WHERE     request_id = g_num_request_id
               AND process_status = 'INPROCESS'
               AND rma_receipt_date > SYSDATE /*vvap - timezone difference??*/
               AND result_code IS NULL;

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

        COMMIT;

        BEGIN
            UPDATE xxdo_ont_rma_hdr_stg x
               SET header_id   =
                       (SELECT header_id
                          FROM oe_order_headers_all ooh
                         WHERE     ooh.order_number = x.rma_number
                               AND ooh.open_flag = 'Y'
                               AND ooh.booked_flag = 'Y')
             WHERE     request_id = g_num_request_id
                   AND process_status = 'INPROCESS'
                   AND x.rma_number IS NOT NULL
                   AND result_code IS NULL;

            msg ('No of records processed are ' || SQL%ROWCOUNT);
            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg ('No records updated' || SQLERRM);
        END;

        /***************
        Line specific validations
        ***************/
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

        UPDATE xxdo_ont_rma_line_stg x
           SET ship_from_org_id   =
                   (SELECT organization_id
                      FROM mtl_parameters mp
                     WHERE mp.organization_code = x.wh_id)
         WHERE     request_id = g_num_request_id
               AND process_status = 'INPROCESS'
               AND result_code IS NULL;

        UPDATE xxdo_ont_rma_line_stg x
           SET inventory_item_id   =
                   (SELECT msi.inventory_item_id
                      FROM mtl_system_items_kfv msi --Replaced table mtl_system_items with mtl_system_items_kfv for BT Remediation
                     WHERE     msi.organization_id = x.ship_from_org_id /*commented for BT Remediation
                                                                        AND msi.segment1 || '-' || msi.segment2 || '-'
                                                                            || msi.segment3 = x.item_number */
                           AND msi.concatenated_segments = x.item_number) --Added for BT Remediation
         WHERE     request_id = g_num_request_id
               AND process_status = 'INPROCESS'
               AND result_code IS NULL;

        COMMIT;

        UPDATE xxdo_ont_rma_line_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'RMA line cannot be null'
         WHERE     request_id = g_num_request_id
               AND process_status = 'INPROCESS'
               AND type1 = 'PLANNED'
               AND line_number IS NULL
               AND result_code IS NULL;

        UPDATE xxdo_ont_rma_line_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'Item can not be null'
         WHERE     request_id = g_num_request_id
               AND process_status = 'INPROCESS'
               AND item_number IS NULL
               AND result_code IS NULL;

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
           SET process_status = 'ERROR', result_code = 'E', error_message = 'Invalid RMA line'
         WHERE     request_id = g_num_request_id
               AND process_status = 'INPROCESS'
               AND NOT EXISTS
                       (SELECT 1
                          FROM oe_order_lines_all ool
                         WHERE     ool.line_id = x.line_number
                               AND ool.ship_from_org_id = x.ship_from_org_id
                               AND ool.inventory_item_id =
                                   x.inventory_item_id)
               AND type1 = 'PLANNED'
               AND result_code IS NULL;

        UPDATE xxdo_ont_rma_line_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'Invalid type'
         WHERE     request_id = g_num_request_id
               AND process_status = 'INPROCESS'
               AND type1 NOT IN ('PLANNED', 'UNPLANNED')
               AND result_code IS NULL;

        UPDATE xxdo_ont_rma_line_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'Type is null'
         WHERE     request_id = g_num_request_id
               AND process_status = 'INPROCESS'
               AND type1 IS NULL
               AND result_code IS NULL;

        UPDATE xxdo_ont_rma_line_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'Invalid quantity'
         WHERE     request_id = g_num_request_id
               AND process_status = 'INPROCESS'
               AND NVL (qty, 0) <= 0
               AND result_code IS NULL;

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
        /*Start of FACTORY_CODE
       Begin
        l_chr_f_sql_stmt :=
                'UPDATE xxdo_ont_rma_line_stg x SET process_status ='||'''ERROR'''||',
              result_code ='||'''E'''||', error_message ='||'''Invalid factory_code values'''||
              ' WHERE request_id = g_num_request_id AND process_status = '||'''INPROCESS'''||
              ' AND factory_code NOT IN'||'( Select '|| g_chr_f_col_name  ||' from '||g_chr_f_tname_name ||' '|| g_chr_f_whr_clause

 ||')'||
             ' AND result_code IS NULL';

         EXECUTE IMMEDIATE l_chr_f_sql_stmt ;
            COMMIT;
           EXCEPTION
           WHEN OTHERS THEN
           msg('Error while updating Factory code');
           END;
        /*End of FACTORY_CODE*/

          /*Start of PROD_CODE
          BEGIN
       l_chr_p_sql_stmt :=
               'UPDATE xxdo_ont_rma_line_stg x SET process_status ='||'''ERROR'''||',
             result_code ='||'''E'''||', error_message ='||'''Invalid prod_code values'''||
             ' WHERE request_id = g_num_request_id AND process_status = '||'''INPROCESS'''||
             ' AND factory_code NOT IN'||'( Select '|| g_chr_p_col_name  ||' from '||g_chr_p_tname_name ||' '|| g_chr_p_whr_clause

||')'||
            ' AND result_code IS NULL';

        EXECUTE IMMEDIATE l_chr_p_sql_stmt ;
       COMMIT;
        EXCEPTION
          WHEN OTHERS THEN
            msg('Error while updating Prod code');
        END;
          /*Ends of PROD_CODE*/
        UPDATE xxdo_ont_rma_line_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'Invalid subinventory'
         WHERE     request_id = g_num_request_id
               AND process_status = 'INPROCESS'
               AND host_subinventory NOT IN
                       (SELECT secondary_inventory_name
                          FROM mtl_secondary_inventories msi
                         WHERE msi.organization_id = x.ship_from_org_id)
               AND result_code IS NULL;

        /*Added two below sections*
                           update   xxdo_ont_rma_line_stg lines
          set attribute10=( SELECT org_id
                       FROM oe_order_lines_all oel,
                              xxdo_ont_rma_line_stg line
                   WHERE oel.header_id = line.header_id AND ROWNUM = 1
                    and line.header_id=lines.header_id
                    and line.receipt_line_seq_id=lines.receipt_line_seq_id)
                    where lines.request_id=g_num_request_id
                    and lines.process_status='INPROCESS';

                    commit;

                     update xxdo_ont_rma_line_stg line
                  set (attribute8,attribute9)=
                  (      select  resp_k.responsibility_id,resp_k.application_id
                                     from (       select oel.org_id, (case
                                           when hou.name = 'Deckers US'
                                          then 'Order Management Super User - '||'US'
                                          when hou.name = 'Deckers US eCommerce'
                                          then 'Order Management Super User - '||'US eCommerce'
                                        end) res_name
                                       from xxdo_ont_rma_line_stg line,
                                            hr_operating_units hou,
                                            oe_order_lines_all oel
                                     where oel.org_id=hou.organization_id
                                     and line.line_number=oel.line_id
                                     and line.ship_from_org_id=oel.ship_from_org_id) x,
                                     fnd_responsibility_vl resp_k
                                     where resp_k.responsibility_name=x.res_name
                                     and x.org_id=line.attribute10)
                                     where process_status='INPROCESS'
                                     and request_id=g_num_request_id
                                     and result_code is null;
          /*Added two below sections*/


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



        BEGIN
            UPDATE xxdo_ont_rma_line_stg x
               SET header_id   =
                       (SELECT DISTINCT header_id
                          FROM xxdo_ont_rma_hdr_stg y
                         WHERE x.receipt_header_seq_id =
                               y.receipt_header_seq_id)
             WHERE     request_id = g_num_request_id
                   AND process_status = 'INPROCESS'
                   AND result_code IS NULL;

            msg ('No of records processed are ' || SQL%ROWCOUNT);
            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg ('No records updated at line level' || SQLERRM);
        END;

        BEGIN
            UPDATE xxdo_ont_rma_line_stg x
               SET rma_receipt_date   =
                       (SELECT rma_receipt_date
                          FROM xxdo_ont_rma_hdr_stg y
                         WHERE x.receipt_header_seq_id =
                               y.receipt_header_seq_id)
             WHERE     request_id = g_num_request_id
                   AND process_status = 'INPROCESS'
                   AND result_code IS NULL;

            msg ('No of records processed are for Date ' || SQL%ROWCOUNT);
            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg ('No records updated at line level' || SQLERRM);
        END;

        COMMIT;

        /*OU_BUG Issue*/
        BEGIN
            UPDATE xxdo_ont_rma_line_stg x
               SET org_id   =
                       (SELECT DISTINCT oel.org_id
                          FROM xxdo_ont_rma_hdr_stg y, oe_order_lines_all oel
                         WHERE     x.receipt_header_seq_id =
                                   y.receipt_header_seq_id
                               AND y.header_id = oel.header_id)
             WHERE     request_id = g_num_request_id
                   AND process_status = 'INPROCESS'
                   AND result_code IS NULL;

            msg ('No of records processed are ' || SQL%ROWCOUNT);
            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg ('No records updated at line level' || SQLERRM);
        END;

        /*OU_BUG Issue*/

        /*
        *********************************
        Line Serial specific validations
        *********************************
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
               SET process_status = 'ERROR', result_code = 'E', error_message = 'Serial_Number is null'
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
                         WHERE     msi.organization_id = x.organization_id /*commented for BT Remediation
                                                                           AND    msi.segment1
                                                                               || '-'
                                                                               || msi.segment2
                                                                               || '-'
                                                                               || msi.segment3 = x.item_number  */
                               AND msi.concatenated_segments = x.item_number) --Added for BT Remediation
             WHERE     request_id = g_num_request_id
                   AND process_status = 'INPROCESS'
                   AND result_code IS NULL;

            --msg ('No of records processed are for Date ' || SQL%ROWCOUNT);
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
              SELECT header.wh_id, line.host_subinventory, header.rma_number,
                     header.rma_receipt_date, line.line_number, line.item_number,
                     line.type1, line.qty, line.cust_return_reason,
                     line.employee_id, line.employee_name, line.creation_date,
                     line.last_update_date
                FROM xxdo_ont_rma_hdr_stg header, xxdo_ont_rma_line_stg line
               WHERE     HEADER.receipt_header_seq_id =
                         line.receipt_header_seq_id
                     AND line.process_status = 'HOLD'
                     AND header.rma_reference IS NULL
                     AND line.request_id = g_num_request_id
            ORDER BY header.wh_id, line.host_subinventory, header.rma_number,
                     header.rma_receipt_date, line.line_number;


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
             WHERE     flv.language = 'US'
                   AND flv.lookup_type = 'XXDO_WMS_INTERFACES_SETUP'
                   AND flv.enabled_flag = 'Y'
                   AND flv.lookup_code = g_chr_rma_receipt_prgm_name;
        EXCEPTION
            WHEN OTHERS
            THEN
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
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
                           'Unexcepted error in BULK Fetch of RMA Receipt Hold records : '
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
                send_mail_header (l_chr_from_mail_id, l_chr_to_mail_ids, l_chr_instance || ' - RMA Receipts on Hold'
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
                       'Please refer the attached file for details of RMA receipts held in '
                    || l_chr_instance
                    || '.',
                    l_num_return_Value);
                send_mail_line (
                       'These were held by the concurrent request id :  '
                    || g_num_request_id,
                    l_num_return_Value);
                send_mail_line ('', l_num_return_value);

                send_mail_line ('--boundarystring', l_num_return_value);

                send_mail_line ('Content-Type: text/xls', l_num_return_value);
                send_mail_line (
                    'Content-Disposition: attachment; filename="RMA_receipt_hold_details.xls"',
                    l_num_return_value);
                send_mail_line ('--boundarystring', l_num_return_value);

                send_mail_line (
                       'Warehouse'
                    || CHR (9)
                    || 'Subinventory'
                    || CHR (9)
                    || 'RMA Number'
                    || CHR (9)
                    || 'RMA Receipt Date'
                    || CHR (9)
                    || 'Line Number'
                    || CHR (9)
                    || 'Item Number'
                    || CHR (9)
                    || 'Type'
                    || CHR (9)
                    || 'Qty'
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
                    || l_error_records_tab (l_num_ind).rma_number
                    || CHR (9)
                    || TO_CHAR (
                           l_error_records_tab (l_num_ind).rma_receipt_date,
                           'DD-Mon-RRRR HH24:MI:SS')
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).line_number
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).item_number
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).type1
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).qty
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
                'No Interface setup to generate RMA Receipt hold report';
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
    -- PROCEDURE  : xxd_reprocess_split_err_prc
    -- Description: PROCEDURE will be called to reprocess the records which are ended
    --    in error with error message unable to split more than one line
    --    in single process
    --------------------------------------------------------------------------------

    PROCEDURE xxd_reprocess_split_err_prc (x_errbuf    OUT VARCHAR2,
                                           x_retcode   OUT VARCHAR2)
    AS
        CURSOR c_rma_number IS
              SELECT DISTINCT rma_number, line_number, SUM (qty) total_qty
                FROM apps.xxdo_ont_rma_line_stg
               WHERE     process_status = 'ERROR'
                     AND error_message =
                         'Unable to split more than one line in single process '
            GROUP BY rma_number, line_number
            ORDER BY 2;


        l_max_seq_id   NUMBER;
    BEGIN
        l_max_seq_id   := 0;

        FOR r_rma_number IN c_rma_number            --cursor to get rma_number
        LOOP
            fnd_file.put_line (fnd_file.LOG,
                               'RMA Number : ' || r_rma_number.rma_number);

            SELECT MAX (receipt_line_seq_id)
              INTO l_max_seq_id
              FROM xxdo.xxdo_ont_rma_line_stg
             WHERE     line_number = r_rma_number.line_number
                   AND error_message =
                       'Unable to split more than one line in single process '
                   AND process_status = 'ERROR';


            UPDATE xxdo_ont_rma_line_stg
               SET qty = r_rma_number.total_qty, process_status = 'NEW'
             WHERE     receipt_line_seq_id = l_max_seq_id
                   AND line_number = r_rma_number.line_number
                   AND process_status = 'ERROR'
                   AND error_message =
                       'Unable to split more than one line in single process ';

            UPDATE xxdo_ont_rma_hdr_stg
               SET process_status   = 'NEW'
             WHERE     RECEIPT_HEADER_SEQ_ID IN
                           (SELECT RECEIPT_HEADER_SEQ_ID
                              FROM xxdo_ont_rma_line_stg
                             WHERE     receipt_line_seq_id = l_max_seq_id
                                   AND line_number = r_rma_number.line_number)
                   AND process_status = 'ERROR';


            UPDATE xxdo_ont_rma_line_stg
               SET qty = 0, process_status = 'IGNORED', error_message = NULL,
                   attribute11 = 'Split line issue. Processed in Seq ID: ' || l_max_seq_id
             WHERE     error_message =
                       'Unable to split more than one line in single process '
                   AND process_status = 'ERROR'
                   AND receipt_line_seq_id <> l_max_seq_id
                   AND line_number = r_rma_number.line_number;

            UPDATE xxdo_ont_rma_hdr_stg
               SET process_status   = 'IGNORED'
             WHERE     RECEIPT_HEADER_SEQ_ID IN
                           (SELECT RECEIPT_HEADER_SEQ_ID
                              FROM xxdo_ont_rma_line_stg
                             WHERE     receipt_line_seq_id <> l_max_seq_id
                                   AND line_number = r_rma_number.line_number)
                   AND process_status = 'ERROR';

            COMMIT;
        END LOOP;                           -- end of cursor to get rma_number
    END xxd_reprocess_split_err_prc;


    --------------------------------------------------------------------------------
    -- PROCEDURE  : main_validate
    -- Description: PROCEDURE will be called to perform various validations on
    --              different rma headers and lines
    --------------------------------------------------------------------------------
    PROCEDURE main_validate (errbuf             OUT VARCHAR2,
                             retcode            OUT NUMBER,
                             p_wh_code       IN     VARCHAR2,
                             p_rma_num       IN     VARCHAR2,
                             p_source        IN     VARCHAR2 DEFAULT 'WMS',
                             p_destination   IN     VARCHAR2 DEFAULT 'EBS',
                             p_purge_days    IN     NUMBER DEFAULT 30,
                             p_debug         IN     VARCHAR2 DEFAULT 'Y')
    IS
        CURSOR c_rma_hold IS
            SELECT DISTINCT rma_number
              FROM apps.xxdo_ont_rma_line_stg
             WHERE process_status = 'HOLD';

        -----------------Declaration of Local Variables
        lv_procedure        VARCHAR2 (100) := '.main_validate';
        lv_operation_name   VARCHAR2 (100);
        lv_retcode          NUMBER;
        lv_error_buf        VARCHAR2 (2000);
        lv_count            NUMBER;
        lv_row              NUMBER := 1;
        lv_group_id         NUMBER := -1;
        lv_org              VARCHAR (5);
        lv_rma_num          VARCHAR (10);
        lv_exe_lock_err     EXCEPTION;
        lv_exe_val_err      EXCEPTION;
        lv_line_id          NUMBER;
        lv_header_id        NUMBER;
        lv_header_id_n      NUMBER;
        lv_hdr_row          NUMBER := 1;
        lv_ret_cnt          VARCHAR2 (100);
        lv_total_count      NUMBER;
        lv_un_rma           NUMBER := 0;
        lv_pro_rec          NUMBER := 0;
        lv_num_qty          NUMBER;
        /*added for version 1.1*/
        lv_col_name         VARCHAR2 (100);
        lv_table_name       VARCHAR2 (100);
        lv_whr_clause       VARCHAR2 (2000);
        lv_stmt             VARCHAR2 (2000);
    --l_line_tbl          t_line_tbl;
    --l_hdr_tbl           t_hdr_tbl;
    ----------------------------------------------
    BEGIN
        -----------------------------------------------------------------
        lv_operation_name   := 'Writing to log file';
        -----------------------------------------------------------------
        fnd_file.put_line (fnd_file.LOG, p_rma_num || TO_CHAR (SYSDATE));
        fnd_file.put_line (fnd_file.LOG, p_source || TO_CHAR (SYSDATE));
        fnd_file.put_line (fnd_file.LOG, p_destination || TO_CHAR (SYSDATE));
        fnd_file.put_line (fnd_file.LOG, p_purge_days || TO_CHAR (SYSDATE));

        /*Debug Options*/
        oe_debug_pub.initialize;
        oe_debug_pub.setdebuglevel (5);
        oe_Msg_Pub.initialize;
        fnd_file.put_line (
            fnd_file.LOG,
            'Debug File = ' || OE_DEBUG_PUB.G_DIR || '/' || OE_DEBUG_PUB.G_FILE);

        /*Debug Options*/


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
        --purge_data (p_purge_days);                      --commented and replaced with purge_archive
        /*Calling purge_archive start*/
        purge_archive (lv_retcode, lv_error_buf, p_purge_days);
        /*Calling purge_archive END*/
        -----------------------------------------------------------------
        lv_operation_name   := 'Releasing Hold on RAs based on threshold';

        -----------------------------------------------------------------
        /*Calling XXDO_ONT_RMA_HOLD_RELEASE.main start */
        BEGIN
            FOR r_rma_hold IN c_rma_hold
            LOOP
                XXDO_ONT_RMA_HOLD_RELEASE_PKG.main (lv_error_buf,
                                                    lv_retcode,
                                                    r_rma_hold.rma_number);
            END LOOP;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'There are no RA lines which are on HOLD and to be released');
        END;

        /*Calling XXDO_ONT_RMA_HOLD_RELEASE.main end */
        -----------------------------------------------------------------
        lv_operation_name   := 'Set all the records to In Process status';

        -----------------------------------------------------------------

        /*update records by setting them to INPROCESS*/
        BEGIN
            set_in_process (lv_retcode, lv_error_buf, lv_total_count,
                            p_wh_code, p_rma_num);

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

        /*Population for Factory code and Product code
        BEGIN
                       SELECT  fvt.VALUE_COLUMN_NAME,
                                       fvt.APPLICATION_TABLE_NAME,
                                      fvt.additional_where_clause
                        INTO g_chr_f_col_name, g_chr_f_tname_name, g_chr_f_whr_clause
                        FROM FND_FLEX_VALUE_SETS FVS, FND_FLEX_VALIDATION_TABLES FVT
                       WHERE FVS.FLEX_VALUE_SET_NAME = 'DO_FACTORY_CODE_V'
                             AND FVS.FLEX_VALUE_SET_ID = FVT.FLEX_VALUE_SET_ID;
         EXCEPTION
              WHEN OTHERS THEN
              g_chr_f_col_name       := NULL;
              g_chr_f_tname_name  := NULL;
               g_chr_f_whr_clause   := NULL;
        END;
    --Prod code
     BEGIN
                       SELECT fvt.VALUE_COLUMN_NAME,
                                    fvt.APPLICATION_TABLE_NAME,
                                    fvt.additional_where_clause
                        INTO g_chr_p_col_name, g_chr_p_tname_name, g_chr_p_whr_clause
                        FROM fnd_flex_value_sets fvs, FND_FLEX_VALIDATION_TABLES fvt
                       WHERE fvs.flex_value_set_name = 'DO_BOM_MONTH_YEAR_CODE_V'
                             AND fvs.FLEX_VALUE_SET_ID = fvt.FLEX_VALUE_SET_ID;
        EXCEPTION
          WHEN OTHERS THEN
          g_chr_p_col_name       :=NULL;
          g_chr_p_tname_name  :=NULL;
          g_chr_p_whr_clause    :=NULL;
        END;
        */
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

        /*Validate ALL RMA Spliting Issue*/
        BEGIN
            validate_line (lv_retcode, lv_error_buf);
        EXCEPTION
            WHEN OTHERS
            THEN
                retcode   := 2;
                errbuf    :=
                       'Unexpected error while invoking Validation for Spliting procedure : '
                    || SQLERRM;
                fnd_file.put_line (fnd_file.LOG, errbuf);
        END;

        -----------------------------------------------------------------
        lv_operation_name   := 'Processing Logic BEGINs here';

        -----------------------------------------------------------------

        /*Open RMA Header CURSOR*/
        IF NVL (lv_total_count, 0) = 0
        THEN
            msg ('There are no elligible records to process');
        -- -- retcode := 1;
        -- errbuf := 'There are no elligible records to process';
        ELSE
            msg ('Update All Values to make it process');

            --     IF rec_cur_rma_line.result_code='H' THEN
            UPDATE xxdo_ont_rma_hdr_stg
               SET result_code = 'P', retcode = '', error_message = ''
             WHERE     process_status IN ('INPROCESS')
                   AND request_id = g_num_request_id
                   AND rma_number = NVL (p_rma_num, rma_number)
                   AND wh_id = NVL (p_wh_code, wh_id);

            lv_ret_cnt       := SQL%ROWCOUNT;
            COMMIT;

            UPDATE xxdo_ont_rma_line_stg
               SET result_code = 'U', retcode = '', error_message = ''
             WHERE     process_status IN ('INPROCESS')
                   AND request_id = g_num_request_id
                   AND type1 = 'UNPLANNED'
                   AND rma_number = NVL (p_rma_num, rma_number)
                   AND wh_id = NVL (p_wh_code, wh_id);

            lv_pro_rec       := SQL%ROWCOUNT;
            COMMIT;

            UPDATE xxdo_ont_rma_line_stg
               SET result_code = 'P', retcode = '', error_message = ''
             WHERE     process_status IN ('INPROCESS')
                   AND request_id = g_num_request_id
                   AND type1 = 'PLANNED'
                   AND rma_number = NVL (p_rma_num, rma_number)
                   AND wh_id = NVL (p_wh_code, wh_id);

            UPDATE xxdo_ont_rma_line_serl_stg
               SET result_code = 'P', retcode = '', error_message = ''
             WHERE     process_status IN ('INPROCESS')
                   AND request_id = g_num_request_id;

            lv_total_count   := SQL%ROWCOUNT;
            COMMIT;
            lv_total_count   := lv_ret_cnt + lv_pro_rec + lv_total_count;
        END IF;

        BEGIN
            create_unplan_rma_line (lv_retcode, lv_error_buf);
        EXCEPTION
            WHEN OTHERS
            THEN
                msg ('Error while create_unplan_rma_line: ' || lv_error_buf);
                retcode   := 2;
                errbuf    := lv_error_buf;
        END;

        BEGIN
            check_hold_released (lv_retcode, lv_error_buf);
        EXCEPTION
            WHEN OTHERS
            THEN
                msg ('Error while check_hold_released: ' || lv_error_buf);
                retcode   := 2;
                errbuf    := lv_error_buf;
        END;

        BEGIN
            receive_return_tbl (lv_group_id, lv_retcode, lv_error_buf);
        EXCEPTION
            WHEN OTHERS
            THEN
                msg (
                       'Error while processing all Transaction Records: '
                    || lv_error_buf);
                retcode   := 2;
                errbuf    := lv_error_buf;
        END;

        IF (lv_group_id <> -1)
        THEN
            BEGIN
                process_rtp (p_group_id => lv_group_id, p_wait => 'Y', p_return_status => lv_retcode
                             , p_error_message => lv_error_buf);
            EXCEPTION
                WHEN OTHERS
                THEN
                    msg (
                           'Error During Running Transaction processor: '
                        || lv_error_buf);
                    retcode   := 2;
                    errbuf    := lv_error_buf;
            END;
        END IF;

        BEGIN
            update_all_records (lv_retcode, lv_error_buf);
        EXCEPTION
            WHEN OTHERS
            THEN
                msg ('Error while updating all records: ' || lv_error_buf);
                retcode   := 2;
                errbuf    := lv_error_buf;
        END;

        BEGIN
            fnd_file.put_line (fnd_file.LOG,
                               'Before calling procedure split reprocess');
            xxd_reprocess_split_err_prc (lv_retcode, lv_error_buf);
        EXCEPTION
            WHEN OTHERS
            THEN
                msg (
                    'Error while reprocessing the records to eliminate split line error. ');
                retcode   := 2;
        END;
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
                   'ERROR in PROCEDURE '
                || lv_procedure
                || '--'
                || retcode
                || '--'
                || errbuf);
            msg (SQLERRM);
    END main_validate;
END;
/
