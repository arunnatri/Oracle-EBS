--
-- XXD_PO_IR_RECEIPT_C_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:51 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_PO_IR_RECEIPT_C_PKG"
IS
    /************************************************************************
    * Module Name:   XXPO_PO_RECEIPT_C_PKG
    * Description:
    * Created By:    BT Technology Team
    * Creation Date: 27-JUL-2015
    *************************************************************************
    * Version  * Author                * Date             * Change Description
    *************************************************************************
    * 1.0      * BT Technology Team    * 27-JUL-2015      * Initial version
    ************************************************************************/
    TYPE hdr_batch_id_t IS TABLE OF NUMBER
        INDEX BY BINARY_INTEGER;

    TYPE request_table IS TABLE OF NUMBER
        INDEX BY BINARY_INTEGER;

    l_req_id                     request_table;
    ln_hdr_batch_id              hdr_batch_id_t;
    gn_request_id                NUMBER := apps.fnd_global.conc_request_id;
    gn_user_id                   NUMBER := apps.fnd_global.user_id;
    gn_login_id                  NUMBER := apps.fnd_global.login_id;
    gt_prog_req_id               NUMBER;
    gn_conc_request_id           NUMBER := fnd_global.conc_request_id;
    gn_org_id                    NUMBER := fnd_global.org_id;
    gn_suc_const        CONSTANT NUMBER := 0;
    gn_warn_const       CONSTANT NUMBER := 1;
    gn_err_const        CONSTANT NUMBER := 2;
    gc_warning          CONSTANT VARCHAR2 (1) := 'W';
    gc_error            CONSTANT VARCHAR2 (1) := 'E';
    gc_extract          CONSTANT VARCHAR2 (10) := 'EXTRACT';
    -- gc_all              CONSTANT VARCHAR2 (10)  := 'ALL';
    gc_validate         CONSTANT VARCHAR2 (10) := 'VALIDATE';
    gc_load             CONSTANT VARCHAR2 (10) := 'LOAD';
    gc_submit           CONSTANT VARCHAR2 (10) := 'SUBMIT';
    gn_record_error_flag         NUMBER;
    gc_no                        VARCHAR2 (1) := 'N';
    gc_invalid                   VARCHAR2 (1) := 'I';
    gc_valid                     VARCHAR2 (1) := 'V';
    gc_yes                       VARCHAR2 (1) := 'Y';
    gd_date                      DATE := SYSDATE;
    gd_date_ch                   DATE := TO_DATE ('31-MAR-2016', 'DD-MON-YY');
    gc_processing_status_code    VARCHAR2 (25) := 'PENDING';
    --constant which stores the value for processing_status_code  field in both rcv_headers_interface and rcv_transactions_interface
    gc_receipt_source_code       VARCHAR2 (25) := 'INTERNAL ORDER';
    --constant which stores the value for receipt_source_code     field in both rcv_headers_interface and rcv_transactions_interface
    gc_transaction_type          VARCHAR2 (25) := 'NEW';
    --constant which stores the value for transaction_type        field in  rcv_headers_interface
    gc_transaction_t_type        VARCHAR2 (25) := 'RECEIVE';
    --constant which stores the value for transaction_type        field in  rcv_transactions_interface
    gc_processing_mode_code      VARCHAR2 (25) := 'BATCH';
    --constant which stores the value for transaction_mode_code   field in  rcv_transactions_interface
    gc_validation_flag           VARCHAR2 (1) := 'Y';
    --constant which stores the value for validation_flag         field in both rcv_headers_interface and rcv_transactions_interface
    gc_transaction_status_code   VARCHAR2 (25) := 'PENDING';
    --constant which stores the value for transaction_status_code field in  rcv_transactions_interface
    gc_source_document_code      VARCHAR2 (25) := 'REQ';         --'RECEIPTS';
    --constant which stores the value for source_document_code    field in  rcv_transactions_interface
    gc_auto_transact_code        VARCHAR2 (25) := 'DELIVER';
    --constant which stores the value for auto_transact_code      field in  rcv_transactions_interface
    gc_interface_source_code     VARCHAR2 (25) := 'RCV';
    --constant which stores the value for interface_source_code   field in  rcv_transactions_interface
    gc_dest_lookup_type          VARCHAR2 (25) := 'DESTINATION TYPE';
    gc_destination_type_code     VARCHAR2 (25);
    gn_header_int_id             NUMBER;
    gn_group_id                  NUMBER := rcv_interface_groups_s.NEXTVAL;
    gn_transaction_int_id        NUMBER;
    gn_check_trans_ponum         NUMBER := 0;
    gc_enabled_flag              VARCHAR2 (1) := 'Y';
    gc_item_number               NUMBER;
    gn_quantity                  NUMBER;
    gc_conc_phase_complete       VARCHAR2 (10) := 'COMPLETE';
    gc_conc_status_normal        VARCHAR2 (10) := 'NORMAL';
    gc_new                       VARCHAR2 (1) := 'N';
    gc_processed                 VARCHAR2 (1) := 'P';
    gc_xxdo             CONSTANT VARCHAR2 (10) := 'XXDCONV';
    gc_receipt_num               VARCHAR2 (250);

    CURSOR cur_get_header_dtls (cp_status VARCHAR2, cp_batch_id NUMBER)
    IS
          SELECT xprhc.*
            FROM xxd_ir_rcv_headers_cnv_stg xprhc
           WHERE     xprhc.record_status = cp_status
                 AND xprhc.batch_id = NVL (cp_batch_id, xprhc.batch_id)
        ORDER BY xprhc.operating_unit, xprhc.po_number, xprhc.receipt_num;

    CURSOR cur_get_line_dtls (cp_receipt_num VARCHAR2, cp_status VARCHAR2)
    IS
          SELECT xprtc.*
            FROM xxd_ir_rcv_trans_cnv_stg xprtc
           WHERE     xprtc.record_status = cp_status
                 AND shipment_header_id =
                     NVL (cp_receipt_num, shipment_header_id)
        -- AND asn_shipment_header_id = NVL (cp_receipt_num, shipment_header_id)   -- added this to macth new header to new line in trx tables
        ORDER BY xprtc.operating_unit, xprtc.po_number, xprtc.receipt_num;

    CURSOR cur_get_header_error_dtls IS
          SELECT xprhc.*
            FROM xxd_ir_rcv_headers_cnv_stg xprhc
        ORDER BY xprhc.operating_unit, xprhc.po_number, xprhc.receipt_num;

    CURSOR cur_get_error (p_rec IN NUMBER)
    IS
        SELECT pier.error_message
          FROM po_interface_errors pier
         WHERE     pier.interface_header_id = p_rec
               AND table_name = 'RCV_HEADERS_INTERFACE'
               AND ROWNUM = 1;

    CURSOR get_line_error (p_rec IN NUMBER, p_line IN NUMBER)
    IS
        SELECT pier.error_message
          FROM po_interface_errors pier
         WHERE     pier.interface_header_id = p_rec
               AND pier.interface_line_id = p_line
               AND table_name = 'RCV_TRANSACTIONS_INTERFACE';

    /******************************************************
        * Procedure: log_recordss
        *
        * Synopsis: This procedure will call we be called by the concurrent program
         * Design:
         *
         * Notes:
         *
         * PARAMETERS:
         *   IN    : p_debug    Varchar2
         *   IN    : p_message  Varchar2
         *
         * Return Values:
         * Modifications:
         *
         ******************************************************/
    PROCEDURE log_records (p_debug VARCHAR2, p_message VARCHAR2)
    IS
    BEGIN
        DBMS_OUTPUT.put_line (p_message);

        IF p_debug = 'Y'
        THEN
            fnd_file.put_line (fnd_file.LOG, p_message);
        END IF;
    END log_records;

    PROCEDURE submit_po_rec_request (p_group_id   IN NUMBER,
                                     p_org_id     IN NUMBER)
    -- +===================================================================+
    -- | Name  : SUBMIT_PO_REQUEST                                         |
    -- | Description      : Main Procedure to submit the purchase order    |
    -- |                    request                                        |
    -- +===================================================================+
    IS
        ln_request_id              NUMBER := 0;
        lc_po_rec_hdr_phase        VARCHAR2 (50);
        lc_po_rec_hdr_status       VARCHAR2 (100);
        lc_po_rec_hdr_dev_phase    VARCHAR2 (100);
        lc_po_rec_hdr_dev_status   VARCHAR2 (100);
        lc_po_rec_hdr_message      VARCHAR2 (3000);
        lc_submit_po_rec           VARCHAR2 (10) := 'N';
        lb_po_rec_hdr_req_wait     BOOLEAN;
    BEGIN
        --fnd_client_info.set_org_context (location_dtl.TARGET_ORG);
        fnd_request.set_org_id (p_org_id);
        ln_request_id   :=
            fnd_request.submit_request (application   => 'PO',
                                        program       => 'RVCTP',
                                        description   => NULL,
                                        start_time    => NULL,
                                        sub_request   => FALSE,
                                        argument1     => 'BATCH',
                                        argument2     => p_group_id,
                                        argument3     => p_org_id);
        COMMIT;

        IF ln_request_id = 0
        THEN
            log_records ('Y', 'Po receiving Processor error ');
        ELSE
            -- wait for request to complete.
            lc_po_rec_hdr_dev_phase   := NULL;
            lc_po_rec_hdr_phase       := NULL;

            LOOP
                lb_po_rec_hdr_req_wait   :=
                    fnd_concurrent.wait_for_request (
                        request_id   => ln_request_id,
                        INTERVAL     => 1,
                        max_wait     => 1,
                        phase        => lc_po_rec_hdr_phase,
                        status       => lc_po_rec_hdr_status,
                        dev_phase    => lc_po_rec_hdr_dev_phase,
                        dev_status   => lc_po_rec_hdr_dev_status,
                        MESSAGE      => lc_po_rec_hdr_message);

                IF ((UPPER (lc_po_rec_hdr_dev_phase) = 'COMPLETE') OR (UPPER (lc_po_rec_hdr_phase) = 'COMPLETED'))
                THEN
                    lc_submit_po_rec   := 'Y';
                    log_records (
                        'Y',
                           ' Open PO Import debug: request_id: '
                        || ln_request_id
                        || ', lc_po_rec_hdr_dev_phase: '
                        || lc_po_rec_hdr_dev_phase
                        || ',lc_po_rec_hdr_phase: '
                        || lc_po_rec_hdr_phase);
                    EXIT;
                END IF;
            END LOOP;
        END IF;
    END submit_po_rec_request;

    -- +===================================================================+
    -- | Name  : truncte_stage_tables                                      |
    -- | Description      : Truncate staging tables data before extarct    |
    -- |                                                                   |
    -- +===================================================================+
    PROCEDURE truncte_stage_tables (x_ret_code      OUT VARCHAR2,
                                    x_return_mesg   OUT VARCHAR2)
    AS
        lx_return_mesg   VARCHAR2 (2000);
    BEGIN
        x_ret_code   := gn_suc_const;
        log_records ('Y',
                     'Working on truncte_stage_tables to purge the data');

        EXECUTE IMMEDIATE 'truncate table xxd_conv.xxd_ir_rcv_headers_cnv_stg';

        EXECUTE IMMEDIATE 'truncate table xxd_conv.xxd_ir_rcv_trans_cnv_stg';

        log_records ('Y', 'Truncate Stage Table Complete');
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code      := gn_err_const;
            x_return_mesg   := SQLERRM;
            log_records ('Y',
                         'Truncate Stage Table Exception t' || x_return_mesg);
            xxd_common_utils.record_error ('RECEIPTS', gn_org_id, 'XXD PO Receipts Conversion Program', --  SQLCODE,
                                                                                                        SQLERRM, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                      --   SYSDATE,
                                                                                                                                                      gn_user_id, gn_conc_request_id, 'truncte_stage_tables', NULL
                                           , x_return_mesg);
    END truncte_stage_tables;

    PROCEDURE extract_rcv_headers (p_debug_flag     IN     VARCHAR2,
                                   x_ret_code          OUT VARCHAR2,
                                   x_rec_count         OUT NUMBER,
                                   x_return_mesg       OUT VARCHAR2,
                                   p_receipt_type   IN     VARCHAR2)
    /**********************************************************************************************
    *                                                                                             *
    * Procedure Name       :   extract_records                                                    *
    *                                                                                             *
    * Description          :  This procedure will populate the Data to Stage Table                *
    *                                                                                             *
    * Parameters         Type       Description                                                   *
    * ---------------    ----       ---------------------                                         *
    * x_ret_code         OUT        Return Code                                                   *
    * x_rec_count        OUT        No of records transferred to Stage table                      *
    *                                                                                             *
    * Change History                                                                              *
    * -----------------                                                                           *
    * Version       Date            Author                 Description                            *
    * -------       ----------     -----------------      ---------------------------             *
    * 1              2-JUL-2015    BT Technology Team     Initial creation                        *
    *                                                                                             *
    **********************************************************************************************/
    IS
        TYPE type_rcv_header_t IS TABLE OF xxd_ir_rcv_headers_cnv_stg%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_rcv_header_type     type_rcv_header_t;
        ln_valid_rec_cnt       NUMBER := 0;
        ln_count               NUMBER := 0;
        l_bulk_errors          NUMBER := 0;
        ex_bulk_exceptions     EXCEPTION;
        PRAGMA EXCEPTION_INIT (ex_bulk_exceptions, -24381);
        ex_program_exception   EXCEPTION;

        --------------------------------------------------------
        --Cursor to fetch the valid records from staging table
        ----------------------------------------------------------
        CURSOR c_get_header_rec IS
            SELECT a.*, NULL asn_shipment_header_id
              FROM apps.xxd_rcv_ir_apac_headers_conv_v a;

        -----------------------------------------------------
        CURSOR c_get_header_emea_rec IS
            SELECT a.*, NULL asn_shipment_header_id
              FROM apps.xxd_rcv_ir_emea_headers_conv_v a;

        CURSOR c_get_header_japan_rec IS
            SELECT a.*, NULL asn_shipment_header_id
              FROM apps.xxd_rcv_ir_jpn_headers_conv_v a;

        TYPE lt_header_typ IS TABLE OF c_get_header_rec%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_rcv_header_data     lt_header_typ;
    BEGIN
        --x_ret_code := gn_suc_const;
        log_records (p_debug_flag, 'Start of transfer_records procedure');
        lt_rcv_header_type.DELETE;

        IF p_receipt_type = 'APAC'
        THEN
            OPEN c_get_header_rec;

            LOOP
                SAVEPOINT insert_table1;

                FETCH c_get_header_rec
                    BULK COLLECT INTO lt_rcv_header_data
                    LIMIT 5000;

                EXIT WHEN lt_rcv_header_data.COUNT = 0;
                log_records (
                    p_debug_flag,
                       'transfer_records Receipts Count => '
                    || lt_rcv_header_data.COUNT);

                IF lt_rcv_header_data.COUNT > 0
                THEN
                    log_records (
                        p_debug_flag,
                        'Assign the valus and buk insert to stage tables');
                    ln_valid_rec_cnt   := 0;

                    FOR rec_get_valid_rec IN lt_rcv_header_data.FIRST ..
                                             lt_rcv_header_data.LAST
                    LOOP
                        ln_count           := ln_count + 1;
                        ln_valid_rec_cnt   := ln_valid_rec_cnt + 1;
                        --
                        --log_records (p_debug_flag,'Row count :' || ln_valid_rec_cnt);
                        lt_rcv_header_type (ln_valid_rec_cnt).batch_id   :=
                            NULL;

                        BEGIN
                            SELECT xxd_rcv_headers_id_s.NEXTVAL
                              INTO lt_rcv_header_type (ln_valid_rec_cnt).record_id
                              FROM DUAL;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                log_records (
                                    p_debug_flag,
                                       SUBSTR (SQLERRM, 1, 150)
                                    || ' Exception fetching group id in transfer_records procedure ');
                                RAISE ex_program_exception;
                        END;

                        --   lt_rcv_header_type (ln_valid_rec_cnt).interface_header_id :=
                        --                                                            NULL;
                        -- lt_rcv_header_type (ln_valid_rec_cnt).interface_source_code :=
                        --  NULL;
                        lt_rcv_header_type (ln_valid_rec_cnt).processing_status_code   :=
                            'PENDING';
                        lt_rcv_header_type (ln_valid_rec_cnt).record_status   :=
                            'N';
                        --  lt_rcv_header_type (ln_valid_rec_cnt).group_code := NULL;
                        lt_rcv_header_type (ln_valid_rec_cnt).receipt_source_code   :=
                            lt_rcv_header_data (rec_get_valid_rec).receipt_source_code;
                        lt_rcv_header_type (ln_valid_rec_cnt).transaction_type   :=
                            lt_rcv_header_data (rec_get_valid_rec).transaction_type;
                        lt_rcv_header_type (ln_valid_rec_cnt).notice_creation_date   :=
                            lt_rcv_header_data (rec_get_valid_rec).notice_creation_date;
                        lt_rcv_header_type (ln_valid_rec_cnt).shipment_num   :=
                            lt_rcv_header_data (rec_get_valid_rec).shipment_num;
                        lt_rcv_header_type (ln_valid_rec_cnt).receipt_num   :=
                            lt_rcv_header_data (rec_get_valid_rec).receipt_num;
                        lt_rcv_header_type (ln_valid_rec_cnt).vendor_name   :=
                            lt_rcv_header_data (rec_get_valid_rec).vendor_name;
                        --     lt_rcv_header_type (ln_valid_rec_cnt).vendor_num :=
                        --          lt_rcv_header_data (rec_get_valid_rec).vendor_num;
                        lt_rcv_header_type (ln_valid_rec_cnt).from_organization_code   :=
                            lt_rcv_header_data (rec_get_valid_rec).from_organization_code;
                        lt_rcv_header_type (ln_valid_rec_cnt).po_number   :=
                            lt_rcv_header_data (rec_get_valid_rec).po_number;
                        -- check req
                        lt_rcv_header_type (ln_valid_rec_cnt).cl_ship_to_organization_code   :=
                            lt_rcv_header_data (rec_get_valid_rec).ship_to_organization_code;
                        --lt_rcv_header_type (ln_valid_rec_cnt).po_release_id := NULL;
                        --lt_rcv_header_type (ln_valid_rec_cnt).release_date := NULL;
                        lt_rcv_header_type (ln_valid_rec_cnt).freight_carrier_code   :=
                            lt_rcv_header_data (rec_get_valid_rec).freight_carrier_code;
                        lt_rcv_header_type (ln_valid_rec_cnt).shipped_date   :=
                            lt_rcv_header_data (rec_get_valid_rec).shipped_date;
                        lt_rcv_header_type (ln_valid_rec_cnt).packing_slip   :=
                            lt_rcv_header_data (rec_get_valid_rec).packing_slip;
                        lt_rcv_header_type (ln_valid_rec_cnt).bill_of_lading   :=
                            lt_rcv_header_data (rec_get_valid_rec).bill_of_lading;
                        lt_rcv_header_type (ln_valid_rec_cnt).expected_receipt_date   :=
                            lt_rcv_header_data (rec_get_valid_rec).expected_receipt_date;
                        lt_rcv_header_type (ln_valid_rec_cnt).num_of_containers   :=
                            lt_rcv_header_data (rec_get_valid_rec).num_of_containers;
                        lt_rcv_header_type (ln_valid_rec_cnt).waybill_airbill_num   :=
                            lt_rcv_header_data (rec_get_valid_rec).waybill_airbill_num;
                        lt_rcv_header_type (ln_valid_rec_cnt).comments   :=
                            lt_rcv_header_data (rec_get_valid_rec).comments;
                        lt_rcv_header_type (ln_valid_rec_cnt).gross_weight   :=
                            lt_rcv_header_data (rec_get_valid_rec).gross_weight;
                        lt_rcv_header_type (ln_valid_rec_cnt).gross_weight_uom_code   :=
                            lt_rcv_header_data (rec_get_valid_rec).gross_weight_uom_code;
                        lt_rcv_header_type (ln_valid_rec_cnt).net_weight   :=
                            lt_rcv_header_data (rec_get_valid_rec).net_weight;
                        lt_rcv_header_type (ln_valid_rec_cnt).net_weight_uom_code   :=
                            lt_rcv_header_data (rec_get_valid_rec).net_weight_uom_code;
                        lt_rcv_header_type (ln_valid_rec_cnt).tar_weight   :=
                            lt_rcv_header_data (rec_get_valid_rec).tar_weight;
                        lt_rcv_header_type (ln_valid_rec_cnt).tar_weight_uom_code   :=
                            lt_rcv_header_data (rec_get_valid_rec).tar_weight_uom_code;
                        lt_rcv_header_type (ln_valid_rec_cnt).packaging_code   :=
                            lt_rcv_header_data (rec_get_valid_rec).packaging_code;
                        lt_rcv_header_type (ln_valid_rec_cnt).carrier_method   :=
                            lt_rcv_header_data (rec_get_valid_rec).carrier_method;
                        lt_rcv_header_type (ln_valid_rec_cnt).carrier_equipment   :=
                            lt_rcv_header_data (rec_get_valid_rec).carrier_equipment;
                        lt_rcv_header_type (ln_valid_rec_cnt).special_handling_code   :=
                            lt_rcv_header_data (rec_get_valid_rec).special_handling_code;
                        lt_rcv_header_type (ln_valid_rec_cnt).hazard_code   :=
                            lt_rcv_header_data (rec_get_valid_rec).hazard_code;
                        lt_rcv_header_type (ln_valid_rec_cnt).hazard_class   :=
                            lt_rcv_header_data (rec_get_valid_rec).hazard_class;
                        lt_rcv_header_type (ln_valid_rec_cnt).hazard_description   :=
                            lt_rcv_header_data (rec_get_valid_rec).hazard_description;
                        lt_rcv_header_type (ln_valid_rec_cnt).freight_terms   :=
                            lt_rcv_header_data (rec_get_valid_rec).freight_terms;
                        lt_rcv_header_type (ln_valid_rec_cnt).freight_bill_number   :=
                            lt_rcv_header_data (rec_get_valid_rec).freight_bill_number;
                        lt_rcv_header_type (ln_valid_rec_cnt).invoice_num   :=
                            lt_rcv_header_data (rec_get_valid_rec).invoice_num;
                        lt_rcv_header_type (ln_valid_rec_cnt).invoice_date   :=
                            lt_rcv_header_data (rec_get_valid_rec).invoice_date;
                        lt_rcv_header_type (ln_valid_rec_cnt).invoice_amount   :=
                            lt_rcv_header_data (rec_get_valid_rec).invoice_amount;
                        lt_rcv_header_type (ln_valid_rec_cnt).tax_name   :=
                            lt_rcv_header_data (rec_get_valid_rec).tax_name;
                        lt_rcv_header_type (ln_valid_rec_cnt).tax_amount   :=
                            lt_rcv_header_data (rec_get_valid_rec).tax_amount;
                        lt_rcv_header_type (ln_valid_rec_cnt).freight_amount   :=
                            lt_rcv_header_data (rec_get_valid_rec).freight_amount;
                        lt_rcv_header_type (ln_valid_rec_cnt).currency_code   :=
                            lt_rcv_header_data (rec_get_valid_rec).currency_code;
                                                                /*
lt_rcv_header_type (ln_valid_rec_cnt).conversion_rate_type :=
    lt_rcv_header_data (rec_get_valid_rec).conversion_rate_type;
lt_rcv_header_type (ln_valid_rec_cnt).conversion_rate :=
         lt_rcv_header_data (rec_get_valid_rec).conversion_rate;
lt_rcv_header_type (ln_valid_rec_cnt).payment_terms_name :=
           lt_rcv_header_data (rec_get_valid_rec).payment_terms;*/
                        lt_rcv_header_type (ln_valid_rec_cnt).clone_operating_unit   :=
                            lt_rcv_header_data (rec_get_valid_rec).operating_unit;
                        lt_rcv_header_type (ln_valid_rec_cnt).from_organization_code   :=
                            lt_rcv_header_data (rec_get_valid_rec).from_organization_code;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute_category   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute_category;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute1   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute1;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute2   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute2;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute3   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute3;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute4   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute4;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute5   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute5;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute6   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute6;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute7   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute7;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute8   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute8;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute9   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute9;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute10   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute10;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute11   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute11;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute12   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute12;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute13   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute13;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute15   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute15;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute14   :=
                            lt_rcv_header_type (ln_valid_rec_cnt).record_id;
                        lt_rcv_header_type (ln_valid_rec_cnt).shipment_header_id   :=
                            lt_rcv_header_data (rec_get_valid_rec).clone_shipment_header_id;
                        -- added below for APAC
                        lt_rcv_header_type (ln_valid_rec_cnt).asn_shipment_header_id   :=
                            lt_rcv_header_data (rec_get_valid_rec).shipment_header_id;
                        -- added above for APAC
                        lt_rcv_header_type (ln_valid_rec_cnt).employee_name   :=
                            lt_rcv_header_data (rec_get_valid_rec).employee_name;
                        lt_rcv_header_type (ln_valid_rec_cnt).vendor_site_code   :=
                            lt_rcv_header_data (rec_get_valid_rec).vendor_site_code;
                        lt_rcv_header_type (ln_valid_rec_cnt).creation_date   :=
                            SYSDATE;
                        lt_rcv_header_type (ln_valid_rec_cnt).created_by   :=
                            gn_user_id;
                        lt_rcv_header_type (ln_valid_rec_cnt).asn_type   :=
                            lt_rcv_header_data (rec_get_valid_rec).asn_type;
                    --  lt_rcv_header_type (ln_valid_rec_cnt).last_update_date :=
                    --     lt_rcv_header_data (rec_get_valid_rec).last_update_date;
                    -- lt_rcv_header_type (ln_valid_rec_cnt).last_updated_by :=
                    --  lt_rcv_header_data (rec_get_valid_rec).last_updated_by;
                    --  lt_rcv_header_type (ln_valid_rec_cnt).last_update_login :=
                    -- lt_rcv_header_data (rec_get_valid_rec).last_update_login;
                    /*  lt_rcv_header_type (ln_valid_rec_cnt).request_id :=
                                                                   gn_conc_request_id;
                      lt_rcv_header_type (ln_valid_rec_cnt).program_application_id :=
                                                                                 NULL;
                      lt_rcv_header_type (ln_valid_rec_cnt).program_id := NULL;
                      lt_rcv_header_type (ln_valid_rec_cnt).program_update_date :=
                                                                                 NULL;*/
                    END LOOP;

                    -------------------------------------------------------------------
                    -- do a bulk insert into the xxd_ir_rcv_headers_cnv_stg table
                    ----------------------------------------------------------------
                    log_records (
                        p_debug_flag,
                        'Bulk Insert to xxd_ir_rcv_headers_cnv_stg ');

                    FORALL ln_cnt IN 1 .. lt_rcv_header_type.COUNT
                      SAVE EXCEPTIONS
                        INSERT INTO xxd_ir_rcv_headers_cnv_stg
                             VALUES lt_rcv_header_type (ln_cnt);
                END IF;

                COMMIT;
            END LOOP;

            IF c_get_header_rec%ISOPEN
            THEN
                CLOSE c_get_header_rec;
            END IF;

            --x_rec_count := ln_valid_rec_cnt;
            log_records (p_debug_flag, 'APAC headers extract complete ');
        ELSIF p_receipt_type = 'EMEA'
        THEN
            OPEN c_get_header_emea_rec;

            LOOP
                SAVEPOINT insert_table1;

                FETCH c_get_header_emea_rec
                    BULK COLLECT INTO lt_rcv_header_data
                    LIMIT 5000;

                EXIT WHEN lt_rcv_header_data.COUNT = 0;
                log_records (
                    p_debug_flag,
                       'transfer_records Receipts Count => '
                    || lt_rcv_header_data.COUNT);

                IF lt_rcv_header_data.COUNT > 0
                THEN
                    log_records (
                        p_debug_flag,
                        'Assign the valus and buk insert to stage tables');
                    ln_valid_rec_cnt   := 0;

                    FOR rec_get_valid_rec IN lt_rcv_header_data.FIRST ..
                                             lt_rcv_header_data.LAST
                    LOOP
                        ln_count           := ln_count + 1;
                        ln_valid_rec_cnt   := ln_valid_rec_cnt + 1;
                        --
                        --log_records (p_debug_flag,'Row count :' || ln_valid_rec_cnt);
                        lt_rcv_header_type (ln_valid_rec_cnt).batch_id   :=
                            NULL;

                        BEGIN
                            SELECT xxd_rcv_headers_id_s.NEXTVAL
                              INTO lt_rcv_header_type (ln_valid_rec_cnt).record_id
                              FROM DUAL;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                log_records (
                                    p_debug_flag,
                                       SUBSTR (SQLERRM, 1, 150)
                                    || ' Exception fetching group id in transfer_records procedure ');
                                RAISE ex_program_exception;
                        END;

                        --   lt_rcv_header_type (ln_valid_rec_cnt).interface_header_id :=
                        --                                                            NULL;
                        -- lt_rcv_header_type (ln_valid_rec_cnt).interface_source_code :=
                        --  NULL;
                        lt_rcv_header_type (ln_valid_rec_cnt).processing_status_code   :=
                            'PENDING';
                        lt_rcv_header_type (ln_valid_rec_cnt).record_status   :=
                            'N';
                        --  lt_rcv_header_type (ln_valid_rec_cnt).group_code := NULL;
                        lt_rcv_header_type (ln_valid_rec_cnt).receipt_source_code   :=
                            lt_rcv_header_data (rec_get_valid_rec).receipt_source_code;
                        lt_rcv_header_type (ln_valid_rec_cnt).transaction_type   :=
                            lt_rcv_header_data (rec_get_valid_rec).transaction_type;
                        lt_rcv_header_type (ln_valid_rec_cnt).notice_creation_date   :=
                            lt_rcv_header_data (rec_get_valid_rec).notice_creation_date;
                        lt_rcv_header_type (ln_valid_rec_cnt).shipment_num   :=
                            lt_rcv_header_data (rec_get_valid_rec).shipment_num;
                        lt_rcv_header_type (ln_valid_rec_cnt).receipt_num   :=
                            lt_rcv_header_data (rec_get_valid_rec).receipt_num;
                        lt_rcv_header_type (ln_valid_rec_cnt).vendor_name   :=
                            lt_rcv_header_data (rec_get_valid_rec).vendor_name;
                        --     lt_rcv_header_type (ln_valid_rec_cnt).vendor_num :=
                        --          lt_rcv_header_data (rec_get_valid_rec).vendor_num;
                        lt_rcv_header_type (ln_valid_rec_cnt).from_organization_code   :=
                            lt_rcv_header_data (rec_get_valid_rec).from_organization_code;
                        lt_rcv_header_type (ln_valid_rec_cnt).po_number   :=
                            lt_rcv_header_data (rec_get_valid_rec).po_number;
                        -- check req
                        lt_rcv_header_type (ln_valid_rec_cnt).cl_ship_to_organization_code   :=
                            lt_rcv_header_data (rec_get_valid_rec).ship_to_organization_code;
                        --lt_rcv_header_type (ln_valid_rec_cnt).po_release_id := NULL;
                        --lt_rcv_header_type (ln_valid_rec_cnt).release_date := NULL;
                        lt_rcv_header_type (ln_valid_rec_cnt).freight_carrier_code   :=
                            lt_rcv_header_data (rec_get_valid_rec).freight_carrier_code;
                        lt_rcv_header_type (ln_valid_rec_cnt).shipped_date   :=
                            lt_rcv_header_data (rec_get_valid_rec).shipped_date;
                        lt_rcv_header_type (ln_valid_rec_cnt).packing_slip   :=
                            lt_rcv_header_data (rec_get_valid_rec).packing_slip;
                        lt_rcv_header_type (ln_valid_rec_cnt).bill_of_lading   :=
                            lt_rcv_header_data (rec_get_valid_rec).bill_of_lading;
                        lt_rcv_header_type (ln_valid_rec_cnt).expected_receipt_date   :=
                            lt_rcv_header_data (rec_get_valid_rec).expected_receipt_date;
                        lt_rcv_header_type (ln_valid_rec_cnt).num_of_containers   :=
                            lt_rcv_header_data (rec_get_valid_rec).num_of_containers;
                        lt_rcv_header_type (ln_valid_rec_cnt).waybill_airbill_num   :=
                            lt_rcv_header_data (rec_get_valid_rec).waybill_airbill_num;
                        lt_rcv_header_type (ln_valid_rec_cnt).comments   :=
                            lt_rcv_header_data (rec_get_valid_rec).comments;
                        lt_rcv_header_type (ln_valid_rec_cnt).gross_weight   :=
                            lt_rcv_header_data (rec_get_valid_rec).gross_weight;
                        lt_rcv_header_type (ln_valid_rec_cnt).gross_weight_uom_code   :=
                            lt_rcv_header_data (rec_get_valid_rec).gross_weight_uom_code;
                        lt_rcv_header_type (ln_valid_rec_cnt).net_weight   :=
                            lt_rcv_header_data (rec_get_valid_rec).net_weight;
                        lt_rcv_header_type (ln_valid_rec_cnt).net_weight_uom_code   :=
                            lt_rcv_header_data (rec_get_valid_rec).net_weight_uom_code;
                        lt_rcv_header_type (ln_valid_rec_cnt).tar_weight   :=
                            lt_rcv_header_data (rec_get_valid_rec).tar_weight;
                        lt_rcv_header_type (ln_valid_rec_cnt).tar_weight_uom_code   :=
                            lt_rcv_header_data (rec_get_valid_rec).tar_weight_uom_code;
                        lt_rcv_header_type (ln_valid_rec_cnt).packaging_code   :=
                            lt_rcv_header_data (rec_get_valid_rec).packaging_code;
                        lt_rcv_header_type (ln_valid_rec_cnt).carrier_method   :=
                            lt_rcv_header_data (rec_get_valid_rec).carrier_method;
                        lt_rcv_header_type (ln_valid_rec_cnt).carrier_equipment   :=
                            lt_rcv_header_data (rec_get_valid_rec).carrier_equipment;
                        lt_rcv_header_type (ln_valid_rec_cnt).special_handling_code   :=
                            lt_rcv_header_data (rec_get_valid_rec).special_handling_code;
                        lt_rcv_header_type (ln_valid_rec_cnt).hazard_code   :=
                            lt_rcv_header_data (rec_get_valid_rec).hazard_code;
                        lt_rcv_header_type (ln_valid_rec_cnt).hazard_class   :=
                            lt_rcv_header_data (rec_get_valid_rec).hazard_class;
                        lt_rcv_header_type (ln_valid_rec_cnt).hazard_description   :=
                            lt_rcv_header_data (rec_get_valid_rec).hazard_description;
                        lt_rcv_header_type (ln_valid_rec_cnt).freight_terms   :=
                            lt_rcv_header_data (rec_get_valid_rec).freight_terms;
                        lt_rcv_header_type (ln_valid_rec_cnt).freight_bill_number   :=
                            lt_rcv_header_data (rec_get_valid_rec).freight_bill_number;
                        lt_rcv_header_type (ln_valid_rec_cnt).invoice_num   :=
                            lt_rcv_header_data (rec_get_valid_rec).invoice_num;
                        lt_rcv_header_type (ln_valid_rec_cnt).invoice_date   :=
                            lt_rcv_header_data (rec_get_valid_rec).invoice_date;
                        lt_rcv_header_type (ln_valid_rec_cnt).invoice_amount   :=
                            lt_rcv_header_data (rec_get_valid_rec).invoice_amount;
                        lt_rcv_header_type (ln_valid_rec_cnt).tax_name   :=
                            lt_rcv_header_data (rec_get_valid_rec).tax_name;
                        lt_rcv_header_type (ln_valid_rec_cnt).tax_amount   :=
                            lt_rcv_header_data (rec_get_valid_rec).tax_amount;
                        lt_rcv_header_type (ln_valid_rec_cnt).freight_amount   :=
                            lt_rcv_header_data (rec_get_valid_rec).freight_amount;
                        lt_rcv_header_type (ln_valid_rec_cnt).currency_code   :=
                            lt_rcv_header_data (rec_get_valid_rec).currency_code;
                                                                /*
lt_rcv_header_type (ln_valid_rec_cnt).conversion_rate_type :=
    lt_rcv_header_data (rec_get_valid_rec).conversion_rate_type;
lt_rcv_header_type (ln_valid_rec_cnt).conversion_rate :=
         lt_rcv_header_data (rec_get_valid_rec).conversion_rate;
lt_rcv_header_type (ln_valid_rec_cnt).payment_terms_name :=
           lt_rcv_header_data (rec_get_valid_rec).payment_terms;*/
                        lt_rcv_header_type (ln_valid_rec_cnt).clone_operating_unit   :=
                            lt_rcv_header_data (rec_get_valid_rec).operating_unit;
                        lt_rcv_header_type (ln_valid_rec_cnt).from_organization_code   :=
                            lt_rcv_header_data (rec_get_valid_rec).from_organization_code;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute_category   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute_category;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute1   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute1;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute2   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute2;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute3   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute3;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute4   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute4;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute5   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute5;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute6   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute6;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute7   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute7;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute8   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute8;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute9   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute9;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute10   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute10;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute11   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute11;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute12   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute12;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute13   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute13;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute15   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute15;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute14   :=
                            lt_rcv_header_type (ln_valid_rec_cnt).record_id;
                        lt_rcv_header_type (ln_valid_rec_cnt).shipment_header_id   :=
                            lt_rcv_header_data (rec_get_valid_rec).clone_shipment_header_id;
                        -- added below for APAC
                        lt_rcv_header_type (ln_valid_rec_cnt).asn_shipment_header_id   :=
                            lt_rcv_header_data (rec_get_valid_rec).shipment_header_id;
                        -- added above for APAC
                        lt_rcv_header_type (ln_valid_rec_cnt).employee_name   :=
                            lt_rcv_header_data (rec_get_valid_rec).employee_name;
                        lt_rcv_header_type (ln_valid_rec_cnt).vendor_site_code   :=
                            lt_rcv_header_data (rec_get_valid_rec).vendor_site_code;
                        lt_rcv_header_type (ln_valid_rec_cnt).creation_date   :=
                            SYSDATE;
                        lt_rcv_header_type (ln_valid_rec_cnt).created_by   :=
                            gn_user_id;
                        lt_rcv_header_type (ln_valid_rec_cnt).asn_type   :=
                            lt_rcv_header_data (rec_get_valid_rec).asn_type;
                    --  lt_rcv_header_type (ln_valid_rec_cnt).last_update_date :=
                    --     lt_rcv_header_data (rec_get_valid_rec).last_update_date;
                    -- lt_rcv_header_type (ln_valid_rec_cnt).last_updated_by :=
                    --  lt_rcv_header_data (rec_get_valid_rec).last_updated_by;
                    --  lt_rcv_header_type (ln_valid_rec_cnt).last_update_login :=
                    -- lt_rcv_header_data (rec_get_valid_rec).last_update_login;
                    /*  lt_rcv_header_type (ln_valid_rec_cnt).request_id :=
                                                                   gn_conc_request_id;
                      lt_rcv_header_type (ln_valid_rec_cnt).program_application_id :=
                                                                                 NULL;
                      lt_rcv_header_type (ln_valid_rec_cnt).program_id := NULL;
                      lt_rcv_header_type (ln_valid_rec_cnt).program_update_date :=
                                                                                 NULL;*/
                    END LOOP;

                    -------------------------------------------------------------------
                    -- do a bulk insert into the xxd_ir_rcv_headers_cnv_stg table
                    ----------------------------------------------------------------
                    log_records (p_debug_flag,
                                 'Bulk Inser to xxd_ir_rcv_headers_cnv_stg ');

                    FORALL ln_cnt IN 1 .. lt_rcv_header_type.COUNT
                      SAVE EXCEPTIONS
                        INSERT INTO xxd_ir_rcv_headers_cnv_stg
                             VALUES lt_rcv_header_type (ln_cnt);
                END IF;

                COMMIT;
            END LOOP;

            IF c_get_header_emea_rec%ISOPEN
            THEN
                CLOSE c_get_header_emea_rec;
            END IF;

            --x_rec_count := ln_valid_rec_cnt;
            log_records (p_debug_flag, 'EMEA headers extract complete ');
        ELSIF p_receipt_type = 'JAPAN'
        THEN
            OPEN c_get_header_japan_rec;

            LOOP
                SAVEPOINT insert_table1;

                FETCH c_get_header_japan_rec
                    BULK COLLECT INTO lt_rcv_header_data
                    LIMIT 5000;

                EXIT WHEN lt_rcv_header_data.COUNT = 0;
                log_records (
                    p_debug_flag,
                       'transfer_records Receipts Count => '
                    || lt_rcv_header_data.COUNT);

                IF lt_rcv_header_data.COUNT > 0
                THEN
                    log_records (
                        p_debug_flag,
                        'Assign the valus and buk insert to stage tables');
                    ln_valid_rec_cnt   := 0;

                    FOR rec_get_valid_rec IN lt_rcv_header_data.FIRST ..
                                             lt_rcv_header_data.LAST
                    LOOP
                        ln_count           := ln_count + 1;
                        ln_valid_rec_cnt   := ln_valid_rec_cnt + 1;
                        --
                        --log_records (p_debug_flag,'Row count :' || ln_valid_rec_cnt);
                        lt_rcv_header_type (ln_valid_rec_cnt).batch_id   :=
                            NULL;

                        BEGIN
                            SELECT xxd_rcv_headers_id_s.NEXTVAL
                              INTO lt_rcv_header_type (ln_valid_rec_cnt).record_id
                              FROM DUAL;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                log_records (
                                    p_debug_flag,
                                       SUBSTR (SQLERRM, 1, 150)
                                    || ' Exception fetching group id in transfer_records procedure ');
                                RAISE ex_program_exception;
                        END;

                        --   lt_rcv_header_type (ln_valid_rec_cnt).interface_header_id :=
                        --                                                            NULL;
                        -- lt_rcv_header_type (ln_valid_rec_cnt).interface_source_code :=
                        --  NULL;
                        lt_rcv_header_type (ln_valid_rec_cnt).processing_status_code   :=
                            'PENDING';
                        lt_rcv_header_type (ln_valid_rec_cnt).record_status   :=
                            'N';
                        --  lt_rcv_header_type (ln_valid_rec_cnt).group_code := NULL;
                        lt_rcv_header_type (ln_valid_rec_cnt).receipt_source_code   :=
                            lt_rcv_header_data (rec_get_valid_rec).receipt_source_code;
                        lt_rcv_header_type (ln_valid_rec_cnt).transaction_type   :=
                            lt_rcv_header_data (rec_get_valid_rec).transaction_type;
                        lt_rcv_header_type (ln_valid_rec_cnt).notice_creation_date   :=
                            lt_rcv_header_data (rec_get_valid_rec).notice_creation_date;
                        lt_rcv_header_type (ln_valid_rec_cnt).shipment_num   :=
                            lt_rcv_header_data (rec_get_valid_rec).shipment_num;
                        lt_rcv_header_type (ln_valid_rec_cnt).receipt_num   :=
                            lt_rcv_header_data (rec_get_valid_rec).receipt_num;
                        lt_rcv_header_type (ln_valid_rec_cnt).vendor_name   :=
                            lt_rcv_header_data (rec_get_valid_rec).vendor_name;
                        --     lt_rcv_header_type (ln_valid_rec_cnt).vendor_num :=
                        --          lt_rcv_header_data (rec_get_valid_rec).vendor_num;
                        lt_rcv_header_type (ln_valid_rec_cnt).from_organization_code   :=
                            lt_rcv_header_data (rec_get_valid_rec).from_organization_code;
                        lt_rcv_header_type (ln_valid_rec_cnt).po_number   :=
                            lt_rcv_header_data (rec_get_valid_rec).po_number;
                        -- check req
                        lt_rcv_header_type (ln_valid_rec_cnt).cl_ship_to_organization_code   :=
                            lt_rcv_header_data (rec_get_valid_rec).ship_to_organization_code;
                        --lt_rcv_header_type (ln_valid_rec_cnt).po_release_id := NULL;
                        --lt_rcv_header_type (ln_valid_rec_cnt).release_date := NULL;
                        lt_rcv_header_type (ln_valid_rec_cnt).freight_carrier_code   :=
                            lt_rcv_header_data (rec_get_valid_rec).freight_carrier_code;
                        lt_rcv_header_type (ln_valid_rec_cnt).shipped_date   :=
                            lt_rcv_header_data (rec_get_valid_rec).shipped_date;
                        lt_rcv_header_type (ln_valid_rec_cnt).packing_slip   :=
                            lt_rcv_header_data (rec_get_valid_rec).packing_slip;
                        lt_rcv_header_type (ln_valid_rec_cnt).bill_of_lading   :=
                            lt_rcv_header_data (rec_get_valid_rec).bill_of_lading;
                        lt_rcv_header_type (ln_valid_rec_cnt).expected_receipt_date   :=
                            lt_rcv_header_data (rec_get_valid_rec).expected_receipt_date;
                        lt_rcv_header_type (ln_valid_rec_cnt).num_of_containers   :=
                            lt_rcv_header_data (rec_get_valid_rec).num_of_containers;
                        lt_rcv_header_type (ln_valid_rec_cnt).waybill_airbill_num   :=
                            lt_rcv_header_data (rec_get_valid_rec).waybill_airbill_num;
                        lt_rcv_header_type (ln_valid_rec_cnt).comments   :=
                            lt_rcv_header_data (rec_get_valid_rec).comments;
                        lt_rcv_header_type (ln_valid_rec_cnt).gross_weight   :=
                            lt_rcv_header_data (rec_get_valid_rec).gross_weight;
                        lt_rcv_header_type (ln_valid_rec_cnt).gross_weight_uom_code   :=
                            lt_rcv_header_data (rec_get_valid_rec).gross_weight_uom_code;
                        lt_rcv_header_type (ln_valid_rec_cnt).net_weight   :=
                            lt_rcv_header_data (rec_get_valid_rec).net_weight;
                        lt_rcv_header_type (ln_valid_rec_cnt).net_weight_uom_code   :=
                            lt_rcv_header_data (rec_get_valid_rec).net_weight_uom_code;
                        lt_rcv_header_type (ln_valid_rec_cnt).tar_weight   :=
                            lt_rcv_header_data (rec_get_valid_rec).tar_weight;
                        lt_rcv_header_type (ln_valid_rec_cnt).tar_weight_uom_code   :=
                            lt_rcv_header_data (rec_get_valid_rec).tar_weight_uom_code;
                        lt_rcv_header_type (ln_valid_rec_cnt).packaging_code   :=
                            lt_rcv_header_data (rec_get_valid_rec).packaging_code;
                        lt_rcv_header_type (ln_valid_rec_cnt).carrier_method   :=
                            lt_rcv_header_data (rec_get_valid_rec).carrier_method;
                        lt_rcv_header_type (ln_valid_rec_cnt).carrier_equipment   :=
                            lt_rcv_header_data (rec_get_valid_rec).carrier_equipment;
                        lt_rcv_header_type (ln_valid_rec_cnt).special_handling_code   :=
                            lt_rcv_header_data (rec_get_valid_rec).special_handling_code;
                        lt_rcv_header_type (ln_valid_rec_cnt).hazard_code   :=
                            lt_rcv_header_data (rec_get_valid_rec).hazard_code;
                        lt_rcv_header_type (ln_valid_rec_cnt).hazard_class   :=
                            lt_rcv_header_data (rec_get_valid_rec).hazard_class;
                        lt_rcv_header_type (ln_valid_rec_cnt).hazard_description   :=
                            lt_rcv_header_data (rec_get_valid_rec).hazard_description;
                        lt_rcv_header_type (ln_valid_rec_cnt).freight_terms   :=
                            lt_rcv_header_data (rec_get_valid_rec).freight_terms;
                        lt_rcv_header_type (ln_valid_rec_cnt).freight_bill_number   :=
                            lt_rcv_header_data (rec_get_valid_rec).freight_bill_number;
                        lt_rcv_header_type (ln_valid_rec_cnt).invoice_num   :=
                            lt_rcv_header_data (rec_get_valid_rec).invoice_num;
                        lt_rcv_header_type (ln_valid_rec_cnt).invoice_date   :=
                            lt_rcv_header_data (rec_get_valid_rec).invoice_date;
                        lt_rcv_header_type (ln_valid_rec_cnt).invoice_amount   :=
                            lt_rcv_header_data (rec_get_valid_rec).invoice_amount;
                        lt_rcv_header_type (ln_valid_rec_cnt).tax_name   :=
                            lt_rcv_header_data (rec_get_valid_rec).tax_name;
                        lt_rcv_header_type (ln_valid_rec_cnt).tax_amount   :=
                            lt_rcv_header_data (rec_get_valid_rec).tax_amount;
                        lt_rcv_header_type (ln_valid_rec_cnt).freight_amount   :=
                            lt_rcv_header_data (rec_get_valid_rec).freight_amount;
                        lt_rcv_header_type (ln_valid_rec_cnt).currency_code   :=
                            lt_rcv_header_data (rec_get_valid_rec).currency_code;
                                                                /*
lt_rcv_header_type (ln_valid_rec_cnt).conversion_rate_type :=
    lt_rcv_header_data (rec_get_valid_rec).conversion_rate_type;
lt_rcv_header_type (ln_valid_rec_cnt).conversion_rate :=
         lt_rcv_header_data (rec_get_valid_rec).conversion_rate;
lt_rcv_header_type (ln_valid_rec_cnt).payment_terms_name :=
           lt_rcv_header_data (rec_get_valid_rec).payment_terms;*/
                        lt_rcv_header_type (ln_valid_rec_cnt).clone_operating_unit   :=
                            lt_rcv_header_data (rec_get_valid_rec).operating_unit;
                        lt_rcv_header_type (ln_valid_rec_cnt).from_organization_code   :=
                            lt_rcv_header_data (rec_get_valid_rec).from_organization_code;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute_category   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute_category;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute1   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute1;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute2   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute2;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute3   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute3;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute4   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute4;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute5   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute5;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute6   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute6;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute7   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute7;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute8   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute8;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute9   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute9;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute10   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute10;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute11   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute11;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute12   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute12;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute13   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute13;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute15   :=
                            lt_rcv_header_data (rec_get_valid_rec).attribute15;
                        lt_rcv_header_type (ln_valid_rec_cnt).attribute14   :=
                            lt_rcv_header_type (ln_valid_rec_cnt).record_id;
                        lt_rcv_header_type (ln_valid_rec_cnt).shipment_header_id   :=
                            lt_rcv_header_data (rec_get_valid_rec).clone_shipment_header_id;
                        -- added below for APAC
                        lt_rcv_header_type (ln_valid_rec_cnt).asn_shipment_header_id   :=
                            lt_rcv_header_data (rec_get_valid_rec).shipment_header_id;
                        -- added above for APAC
                        lt_rcv_header_type (ln_valid_rec_cnt).employee_name   :=
                            lt_rcv_header_data (rec_get_valid_rec).employee_name;
                        lt_rcv_header_type (ln_valid_rec_cnt).vendor_site_code   :=
                            lt_rcv_header_data (rec_get_valid_rec).vendor_site_code;
                        lt_rcv_header_type (ln_valid_rec_cnt).creation_date   :=
                            SYSDATE;
                        lt_rcv_header_type (ln_valid_rec_cnt).created_by   :=
                            gn_user_id;
                        lt_rcv_header_type (ln_valid_rec_cnt).asn_type   :=
                            lt_rcv_header_data (rec_get_valid_rec).asn_type;
                    --  lt_rcv_header_type (ln_valid_rec_cnt).last_update_date :=
                    --     lt_rcv_header_data (rec_get_valid_rec).last_update_date;
                    -- lt_rcv_header_type (ln_valid_rec_cnt).last_updated_by :=
                    --  lt_rcv_header_data (rec_get_valid_rec).last_updated_by;
                    --  lt_rcv_header_type (ln_valid_rec_cnt).last_update_login :=
                    -- lt_rcv_header_data (rec_get_valid_rec).last_update_login;
                    /*  lt_rcv_header_type (ln_valid_rec_cnt).request_id :=
                                                                   gn_conc_request_id;
                      lt_rcv_header_type (ln_valid_rec_cnt).program_application_id :=
                                                                                 NULL;
                      lt_rcv_header_type (ln_valid_rec_cnt).program_id := NULL;
                      lt_rcv_header_type (ln_valid_rec_cnt).program_update_date :=
                                                                                 NULL;*/
                    END LOOP;

                    -------------------------------------------------------------------
                    -- do a bulk insert into the xxd_ir_rcv_headers_cnv_stg table
                    ----------------------------------------------------------------
                    log_records (p_debug_flag,
                                 'Bulk Inser to xxd_ir_rcv_headers_cnv_stg ');

                    FORALL ln_cnt IN 1 .. lt_rcv_header_type.COUNT
                      SAVE EXCEPTIONS
                        INSERT INTO xxd_ir_rcv_headers_cnv_stg
                             VALUES lt_rcv_header_type (ln_cnt);
                END IF;

                COMMIT;
            END LOOP;

            IF c_get_header_japan_rec%ISOPEN
            THEN
                CLOSE c_get_header_japan_rec;
            END IF;

            --x_rec_count := ln_valid_rec_cnt;
            log_records (p_debug_flag, 'JAPAN headers extract complete ');
        END IF;
    EXCEPTION
        WHEN ex_program_exception
        THEN
            ROLLBACK TO insert_table1;
            x_ret_code   := gn_err_const;

            IF c_get_header_rec%ISOPEN
            THEN
                CLOSE c_get_header_rec;
            ELSIF c_get_header_emea_rec%ISOPEN
            THEN
                CLOSE c_get_header_emea_rec;
            ELSIF c_get_header_japan_rec%ISOPEN
            THEN
                CLOSE c_get_header_japan_rec;
            END IF;

            log_records (p_debug_flag,
                         'ex_program_Exception raised' || SQLERRM);
            xxd_common_utils.record_error ('PO RECEIPTS', gn_org_id, 'XXD Open Purchase Orders Conversion Program', --    SQLCODE,
                                                                                                                    SQLERRM, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                                  --     SYSDATE,
                                                                                                                                                                  gn_user_id, gn_conc_request_id, 'xxd_ir_rcv_headers_cnv_stg', NULL
                                           , 'Exception in bulk insert');
        WHEN ex_bulk_exceptions
        THEN
            ROLLBACK TO insert_table1;
            l_bulk_errors   := SQL%BULK_EXCEPTIONS.COUNT;
            x_ret_code      := gn_err_const;

            IF c_get_header_rec%ISOPEN
            THEN
                CLOSE c_get_header_rec;
            ELSIF c_get_header_emea_rec%ISOPEN
            THEN
                CLOSE c_get_header_emea_rec;
            ELSIF c_get_header_japan_rec%ISOPEN
            THEN
                CLOSE c_get_header_japan_rec;
            END IF;

            FOR l_errcnt IN 1 .. l_bulk_errors
            LOOP
                log_records (
                    p_debug_flag,
                       SQLERRM (-SQL%BULK_EXCEPTIONS (l_errcnt).ERROR_CODE)
                    || ' Exception in transfer_records procedure ');
                xxd_common_utils.record_error (
                    'PO RECEIPTS',
                    gn_org_id,
                    'XXD Open Purchase Orders RECEIPTS Conversion Program',
                    --   SQLCODE,
                    SQLERRM,
                    DBMS_UTILITY.format_error_backtrace,
                    --   DBMS_UTILITY.format_call_stack,
                    --   SYSDATE,
                    gn_user_id,
                    gn_conc_request_id,
                    'xxd_ir_rcv_headers_cnv_stg',
                    NULL,
                    SQLERRM (-SQL%BULK_EXCEPTIONS (l_errcnt).ERROR_CODE));
            END LOOP;
        WHEN OTHERS
        THEN
            ROLLBACK TO insert_table1;
            x_ret_code   := gn_err_const;
            log_records (
                p_debug_flag,
                   SUBSTR (SQLERRM, 1, 250)
                || ' Exception in transfer_records procedure');

            IF c_get_header_rec%ISOPEN
            THEN
                CLOSE c_get_header_rec;
            ELSIF c_get_header_emea_rec%ISOPEN
            THEN
                CLOSE c_get_header_emea_rec;
            ELSIF c_get_header_japan_rec%ISOPEN
            THEN
                CLOSE c_get_header_japan_rec;
            END IF;

            xxd_common_utils.record_error (
                'PO RECEIPTS',
                gn_org_id,
                'XXD Open Purchase Orders RECEIPTS Conversion Program',
                --   SQLCODE,
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --   SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'xxd_ir_rcv_headers_cnv_stg',
                NULL,
                'Unexpected Exception while inserting into xxd_ir_rcv_headers_cnv_stg');
    END extract_rcv_headers;

    PROCEDURE extract_rcv_trx (p_debug_flag     IN     VARCHAR2,
                               x_ret_code          OUT VARCHAR2,
                               x_rec_count         OUT NUMBER,
                               x_return_mesg       OUT VARCHAR2,
                               p_receipt_type   IN     VARCHAR2)
    /**********************************************************************************************
    *                                                                                             *
    * Procedure Name       :   extract_records                                                    *
    *                                                                                             *
    * Description          :  This procedure will populate the Data to Stage Table                *
    *                                                                                             *
    * Parameters         Type       Description                                                   *
    * ---------------    ----       ---------------------                                         *
    * x_ret_code         OUT        Return Code                                                   *
    * x_rec_count        OUT        No of records transferred to Stage table                      *
    * x_int_run_id       OUT        Interface Run Id                                              *
    *                                                                                             *
    * Change History                                                                              *
    * -----------------                                                                           *
    * Version       Date            Author                 Description                            *
    * -------       ----------      -----------------      ---------------------------            *
    * Draft1a                                              Initial creation                        *
    *                                                                                             *
    **********************************************************************************************/
    IS
        TYPE type_rcv_trx_t IS TABLE OF xxd_ir_rcv_trans_cnv_stg%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_rcv_trx_type        type_rcv_trx_t;
        ln_valid_trx_rec_cnt   NUMBER := 0;
        ln_count               NUMBER := 0;
        l_bulk_errors          NUMBER := 0;
        ex_bulk_exceptions     EXCEPTION;
        PRAGMA EXCEPTION_INIT (ex_bulk_exceptions, -24381);
        ex_program_exception   EXCEPTION;
        lc_retcode             VARCHAR2 (6000);

        --------------------------------------------------------
        --Cursor to fetch the valid records from staging table
        ----------------------------------------------------------
        CURSOR c_get_trx_rec IS
            SELECT                       --NULL po_header_id, NULL po_line_id,
                   a.*
              FROM apps.xxd_rcv_ir_apac_trans_conv_v a;

        CURSOR c_get_trx_emea_rec IS
            SELECT                       --NULL po_header_id, NULL po_line_id,
                   a.*
              FROM apps.xxd_rcv_ir_emea_trans_conv_v a;

        CURSOR c_get_trx_japan_rec IS
            SELECT                       --NULL po_header_id, NULL po_line_id,
                   a.*
              FROM apps.xxd_rcv_ir_japan_trans_conv_v a;

        --xxd_rcv_trans_conv_v a;
        TYPE lt_rcv_trx_typ IS TABLE OF c_get_trx_rec%ROWTYPE
            INDEX BY BINARY_INTEGER;

        TYPE lt_rcv_trx_j_typ IS TABLE OF c_get_trx_japan_rec%ROWTYPE
            INDEX BY BINARY_INTEGER;

        TYPE lt_rcv_trx_e_typ IS TABLE OF c_get_trx_emea_rec%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_rcv_trx_e_data      lt_rcv_trx_e_typ;
        lt_rcv_trx_j_data      lt_rcv_trx_j_typ;
        lt_rcv_trx_data        lt_rcv_trx_typ;
    --lt_rcv_trx_data  type_rcv_trx_t;
    BEGIN
        --x_ret_code := gn_suc_const;
        log_records (p_debug_flag, 'Start of transfer_records procedure');
        lt_rcv_trx_type.DELETE;

        IF p_receipt_type = 'APAC'
        THEN
            OPEN c_get_trx_rec;

            LOOP
                log_records (p_debug_flag,
                             'Start of transfer_records procedure1');
                SAVEPOINT insert_table2;
                lt_rcv_trx_data.DELETE;
                lt_rcv_trx_type.DELETE;

                FETCH c_get_trx_rec
                    BULK COLLECT INTO lt_rcv_trx_data
                    LIMIT 1000;

                log_records (p_debug_flag,
                             'Start of transfer_records procedure2');
                EXIT WHEN lt_rcv_trx_data.COUNT = 0;
                log_records (
                    p_debug_flag,
                    'transfer_records Count => ' || lt_rcv_trx_data.COUNT);

                IF lt_rcv_trx_data.COUNT > 0
                THEN
                    log_records (
                        p_debug_flag,
                        'Assign the valus and buk insert to stage tables 1');
                    ln_valid_trx_rec_cnt   := 0;

                    FOR rec_get_valid_rec IN lt_rcv_trx_data.FIRST ..
                                             lt_rcv_trx_data.LAST
                    LOOP
                        ln_count               := ln_count + 1;
                        ln_valid_trx_rec_cnt   := ln_valid_trx_rec_cnt + 1;
                        --
                        --log_records (p_debug_flag,'Row count :' || ln_valid_trx_rec_cnt);
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).batch_id   :=
                            NULL;

                        BEGIN
                            SELECT xxd_rcv_trx_id_s.NEXTVAL
                              INTO lt_rcv_trx_type (ln_valid_trx_rec_cnt).record_id
                              FROM DUAL;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                log_records (
                                    p_debug_flag,
                                       SUBSTR (SQLERRM, 1, 150)
                                    || ' Exception fetching group id in transfer_records procedure ');
                                RAISE ex_program_exception;
                        END;

                        --log_records ('Y', 'test loc '||lt_rcv_trx_data (rec_get_valid_rec).attribute4);
                        --   lt_rcv_trx_type (ln_valid_trx_rec_cnt).interface_header_id :=
                        --                                                            NULL;
                        -- lt_rcv_trx_type (ln_valid_trx_rec_cnt).interface_source_code :=
                        --  NULL;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).processing_status_code   :=
                            'PENDING';
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).record_status   :=
                            'N';
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).receipt_num   :=
                            lt_rcv_trx_data (rec_get_valid_rec).receipt_num;
                        --  lt_rcv_trx_type (ln_valid_trx_rec_cnt).group_code := NULL;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).receipt_source_code   :=
                            lt_rcv_trx_data (rec_get_valid_rec).receipt_source_code;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).transaction_type   :=
                            lt_rcv_trx_data (rec_get_valid_rec).transaction_type;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).transaction_date   :=
                            lt_rcv_trx_data (rec_get_valid_rec).transaction_date;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).quantity   :=
                            lt_rcv_trx_data (rec_get_valid_rec).quantity;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).item_id   :=
                            lt_rcv_trx_data (rec_get_valid_rec).item_id;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).clone_po_header_id   :=
                            lt_rcv_trx_data (rec_get_valid_rec).clone_po_header_id;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).clone_po_line_id   :=
                            lt_rcv_trx_data (rec_get_valid_rec).clone_po_line_id;
                        /*  lt_rcv_trx_type (ln_valid_trx_rec_cnt).po_header_id :=
                                          lt_rcv_trx_data (rec_get_valid_rec).attribute14;
                          lt_rcv_trx_type (ln_valid_trx_rec_cnt).po_line_id :=
                                          lt_rcv_trx_data (rec_get_valid_rec).attribute15;*/
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).unit_of_measure   :=
                            lt_rcv_trx_data (rec_get_valid_rec).unit_of_measure;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).po_unit_price   :=
                            lt_rcv_trx_data (rec_get_valid_rec).po_unit_price;
                        -- lt_rcv_trx_type (ln_valid_trx_rec_cnt).vendor_number :=
                        --     lt_rcv_trx_data (rec_get_valid_rec).vendor_number;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).uom_code   :=
                            lt_rcv_trx_data (rec_get_valid_rec).uom_code;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).currency_code   :=
                            lt_rcv_trx_data (rec_get_valid_rec).currency_code;
                        --lt_rcv_trx_type (ln_valid_trx_rec_cnt).po_release_id := NULL;
                        --lt_rcv_trx_type (ln_valid_trx_rec_cnt).release_date := NULL;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).currency_conversion_type   :=
                            lt_rcv_trx_data (rec_get_valid_rec).currency_conversion_type;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).currency_conversion_rate   :=
                            lt_rcv_trx_data (rec_get_valid_rec).currency_conversion_rate;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).currency_conversion_date   :=
                            lt_rcv_trx_data (rec_get_valid_rec).currency_conversion_date;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).substitute_unordered_code   :=
                            lt_rcv_trx_data (rec_get_valid_rec).substitute_unordered_code;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).receipt_exception_flag   :=
                            lt_rcv_trx_data (rec_get_valid_rec).receipt_exception_flag;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).accrual_status_code   :=
                            lt_rcv_trx_data (rec_get_valid_rec).accrual_status_code;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).inspection_status_code   :=
                            lt_rcv_trx_data (rec_get_valid_rec).inspection_status_code;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).rma_reference   :=
                            lt_rcv_trx_data (rec_get_valid_rec).rma_reference;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).comments   :=
                            lt_rcv_trx_data (rec_get_valid_rec).comments;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute_category :=
                        --                        lt_rcv_trx_data (rec_get_valid_rec).attribute_category;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute1 :=
                        --                                lt_rcv_trx_data (rec_get_valid_rec).attribute1;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute2 :=
                        --                                lt_rcv_trx_data (rec_get_valid_rec).attribute2;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute3 :=
                        --                                lt_rcv_trx_data (rec_get_valid_rec).attribute3;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute4 :=
                        --                                lt_rcv_trx_data (rec_get_valid_rec).attribute4;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute5 :=
                        --                                lt_rcv_trx_data (rec_get_valid_rec).attribute5;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute6 :=
                        --                                lt_rcv_trx_data (rec_get_valid_rec).attribute6;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute7 :=
                        --                                lt_rcv_trx_data (rec_get_valid_rec).attribute7;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute8 :=
                        --                                lt_rcv_trx_data (rec_get_valid_rec).attribute8;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute9 :=
                        --                                lt_rcv_trx_data (rec_get_valid_rec).attribute9;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute10 :=
                        --                               lt_rcv_trx_data (rec_get_valid_rec).attribute10;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute11 :=
                        --                               lt_rcv_trx_data (rec_get_valid_rec).attribute11;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute12 :=
                        --                               lt_rcv_trx_data (rec_get_valid_rec).attribute12;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute13 :=
                        --                               lt_rcv_trx_data (rec_get_valid_rec).attribute13;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute15 :=
                        --                               lt_rcv_trx_data (rec_get_valid_rec).attribute15;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute14   :=
                            lt_rcv_trx_type (ln_valid_trx_rec_cnt).record_id;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute1   :=
                            lt_rcv_trx_data (rec_get_valid_rec).ship_line_attribute1;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute2   :=
                            lt_rcv_trx_data (rec_get_valid_rec).ship_line_attribute2;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute3   :=
                            lt_rcv_trx_data (rec_get_valid_rec).ship_line_attribute3;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute4   :=
                            lt_rcv_trx_data (rec_get_valid_rec).ship_line_attribute4;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute5   :=
                            lt_rcv_trx_data (rec_get_valid_rec).ship_line_attribute5;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute6   :=
                            lt_rcv_trx_data (rec_get_valid_rec).ship_line_attribute6;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute7   :=
                            lt_rcv_trx_data (rec_get_valid_rec).ship_line_attribute7;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute8   :=
                            lt_rcv_trx_data (rec_get_valid_rec).ship_line_attribute8;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute9   :=
                            lt_rcv_trx_data (rec_get_valid_rec).ship_line_attribute9;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute10   :=
                            lt_rcv_trx_data (rec_get_valid_rec).ship_line_attribute10;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute11   :=
                            lt_rcv_trx_data (rec_get_valid_rec).ship_line_attribute11;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute12   :=
                            lt_rcv_trx_data (rec_get_valid_rec).ship_line_attribute12;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute13   :=
                            lt_rcv_trx_data (rec_get_valid_rec).ship_line_attribute13;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute14   :=
                            lt_rcv_trx_data (rec_get_valid_rec).ship_line_attribute14;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute15   :=
                            lt_rcv_trx_data (rec_get_valid_rec).ship_line_attribute15;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).amount :=
                        --                                    lt_rcv_trx_data (rec_get_valid_rec).amount;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).inspection_quality_code :=
                        --                     lt_rcv_trx_data (rec_get_valid_rec).inspection_quality_code;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).clone_to_organization_code :=
                        --                           lt_rcv_trx_data (rec_get_valid_rec).to_organization;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).country_of_origin_code :=
                        --                     lt_rcv_trx_data (rec_get_valid_rec).country_of_origin_code;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).mobile_txn :=
                        --                                lt_rcv_trx_data (rec_get_valid_rec).mobile_txn;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).subinventory :=
                        --                              lt_rcv_trx_data (rec_get_valid_rec).subinventory;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).deliver_to_person_name   :=
                            lt_rcv_trx_data (rec_get_valid_rec).deliver_to_person;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).primary_quantity :=
                        --                          lt_rcv_trx_data (rec_get_valid_rec).primary_quantity;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).destination_type_code :=
                        --                     lt_rcv_trx_data (rec_get_valid_rec).destination_type_code;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_to_location_code   :=
                            lt_rcv_trx_data (rec_get_valid_rec).ship_to_location;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).segment1   :=
                            lt_rcv_trx_data (rec_get_valid_rec).segment1;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).po_line_num   :=
                            lt_rcv_trx_data (rec_get_valid_rec).line_num;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).shipment_num   :=
                            lt_rcv_trx_data (rec_get_valid_rec).shipment_num;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).shipment_line_id   :=
                            lt_rcv_trx_data (rec_get_valid_rec).shipment_line_id;
                        --   lt_rcv_trx_type (ln_valid_trx_rec_cnt).distribution_num :=
                        --                  lt_rcv_trx_data (rec_get_valid_rec).distribution_num;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).freight_carrier_code   :=
                            lt_rcv_trx_data (rec_get_valid_rec).freight_carrier_code;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).bill_of_lading   :=
                            lt_rcv_trx_data (rec_get_valid_rec).bill_of_lading;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).packing_slip   :=
                            lt_rcv_trx_data (rec_get_valid_rec).packing_slip;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).shipped_date   :=
                            lt_rcv_trx_data (rec_get_valid_rec).shipped_date;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).expected_receipt_date   :=
                            lt_rcv_trx_data (rec_get_valid_rec).expected_receipt_date;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).transfer_cost   :=
                            lt_rcv_trx_data (rec_get_valid_rec).transfer_cost;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).transportation_cost   :=
                            lt_rcv_trx_data (rec_get_valid_rec).transportation_cost;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).num_of_containers   :=
                            lt_rcv_trx_data (rec_get_valid_rec).num_of_containers;
                        --   lt_rcv_trx_type (ln_valid_trx_rec_cnt).LOCATION_code :=
                        --              lt_rcv_trx_data (rec_get_valid_rec).LOCATION_CODE;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).deliver_to_person_name   :=
                            lt_rcv_trx_data (rec_get_valid_rec).deliver_to_person;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).quantity_shipped   :=
                            lt_rcv_trx_data (rec_get_valid_rec).quantity_shipped;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).clone_operating_unit   :=
                            lt_rcv_trx_data (rec_get_valid_rec).operating_unit;
                        /* lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute15 :=
                                      lt_rcv_trx_data (rec_get_valid_rec).attribute15;*/
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).employee_name :=
                        --                             lt_rcv_trx_data (rec_get_valid_rec).employee_name;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).vendor_name   :=
                            lt_rcv_trx_data (rec_get_valid_rec).vendor_name;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).vendor_site_code   :=
                            lt_rcv_trx_data (rec_get_valid_rec).vendor_site_code;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).creation_date   :=
                            SYSDATE;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).created_by   :=
                            gn_user_id;
                        --  lt_rcv_trx_type (ln_valid_trx_rec_cnt).last_update_date :=
                        --     lt_rcv_trx_data (rec_get_valid_rec).last_update_date;
                        -- lt_rcv_trx_type (ln_valid_trx_rec_cnt).last_updated_by :=
                        --  lt_rcv_trx_data (rec_get_valid_rec).last_updated_by;
                        --  lt_rcv_trx_type (ln_valid_trx_rec_cnt).last_update_login :=
                        -- lt_rcv_trx_data (rec_get_valid_rec).last_update_login;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).program_application_id   :=
                            NULL;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).program_id   :=
                            NULL;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).program_update_date   :=
                            NULL;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).asn_shipment_header_id   :=
                            lt_rcv_trx_data (rec_get_valid_rec).asn_shipment_header_id;
                        -- added below for APAC
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).shipment_header_id   :=
                            lt_rcv_trx_data (rec_get_valid_rec).shipment_header_id;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).asn_shipment_line_id   :=
                            lt_rcv_trx_data (rec_get_valid_rec).asn_shipment_line_id;
                        -- added above for APAC
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ir_type   :=
                            lt_rcv_trx_data (rec_get_valid_rec).ir_type;
                        --lt_rcv_trx_type (ln_valid_trx_rec_cnt).locator_id := lt_rcv_trx_data (rec_get_valid_rec).locator_id;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).locator_id :=
                        --                                    lt_rcv_trx_data (rec_get_valid_rec).loc_id;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).request_id   :=
                            gn_conc_request_id;
                    END LOOP;

                    -------------------------------------------------------------------
                    -- do a bulk insert into the xxd_ir_rcv_trans_cnv_stg table
                    ----------------------------------------------------------------
                    log_records (p_debug_flag,
                                 'Bulk Inser to xxd_ir_rcv_trans_cnv_stg 1');

                    FORALL ln_cnt IN 1 .. lt_rcv_trx_type.COUNT
                      SAVE EXCEPTIONS
                        INSERT INTO xxd_ir_rcv_trans_cnv_stg
                             VALUES lt_rcv_trx_type (ln_cnt);

                    lt_rcv_trx_data.DELETE;
                END IF;

                COMMIT;
            END LOOP;

            IF c_get_trx_rec%ISOPEN
            THEN
                CLOSE c_get_trx_rec;
            END IF;

            --x_rec_count := ln_valid_trx_rec_cnt;
            log_records (p_debug_flag, 'APAC transaction extract complete ');
        ELSIF p_receipt_type = 'EMEA'
        THEN
            OPEN c_get_trx_emea_rec;

            LOOP
                log_records (p_debug_flag,
                             'Start of transfer_records procedure1');
                SAVEPOINT insert_table2;
                lt_rcv_trx_e_data.DELETE;
                lt_rcv_trx_type.DELETE;

                FETCH c_get_trx_emea_rec
                    BULK COLLECT INTO lt_rcv_trx_e_data
                    LIMIT 1000;

                log_records (p_debug_flag,
                             'Start of transfer_records procedure2');
                EXIT WHEN lt_rcv_trx_e_data.COUNT = 0;
                log_records (
                    p_debug_flag,
                    'transfer_records Count => ' || lt_rcv_trx_e_data.COUNT);

                IF lt_rcv_trx_e_data.COUNT > 0
                THEN
                    log_records (
                        p_debug_flag,
                        'Assign the valus and buk insert to stage tables 1');
                    ln_valid_trx_rec_cnt   := 0;

                    FOR rec_get_valid_rec IN lt_rcv_trx_e_data.FIRST ..
                                             lt_rcv_trx_e_data.LAST
                    LOOP
                        ln_count               := ln_count + 1;
                        ln_valid_trx_rec_cnt   := ln_valid_trx_rec_cnt + 1;
                        --
                        --log_records (p_debug_flag,'Row count :' || ln_valid_trx_rec_cnt);
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).batch_id   :=
                            NULL;

                        BEGIN
                            SELECT xxd_rcv_trx_id_s.NEXTVAL
                              INTO lt_rcv_trx_type (ln_valid_trx_rec_cnt).record_id
                              FROM DUAL;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                log_records (
                                    p_debug_flag,
                                       SUBSTR (SQLERRM, 1, 150)
                                    || ' Exception fetching group id in transfer_records procedure ');
                                RAISE ex_program_exception;
                        END;

                        --log_records ('Y', 'test loc '||lt_rcv_trx_e_data (rec_get_valid_rec).attribute4);
                        --   lt_rcv_trx_type (ln_valid_trx_rec_cnt).interface_header_id :=
                        --                                                            NULL;
                        -- lt_rcv_trx_type (ln_valid_trx_rec_cnt).interface_source_code :=
                        --  NULL;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).processing_status_code   :=
                            'PENDING';
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).record_status   :=
                            'N';
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).receipt_num   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).receipt_num;
                        --  lt_rcv_trx_type (ln_valid_trx_rec_cnt).group_code := NULL;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).receipt_source_code   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).receipt_source_code;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).transaction_type   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).transaction_type;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).transaction_date   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).transaction_date;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).quantity   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).quantity;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).item_id   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).item_id;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).clone_po_header_id   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).clone_po_header_id;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).clone_po_line_id   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).clone_po_line_id;
                        /*  lt_rcv_trx_type (ln_valid_trx_rec_cnt).po_header_id :=
                                          lt_rcv_trx_e_data (rec_get_valid_rec).attribute14;
                          lt_rcv_trx_type (ln_valid_trx_rec_cnt).po_line_id :=
                                          lt_rcv_trx_e_data (rec_get_valid_rec).attribute15;*/
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).unit_of_measure   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).unit_of_measure;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).po_unit_price   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).po_unit_price;
                        -- lt_rcv_trx_type (ln_valid_trx_rec_cnt).vendor_number :=
                        --     lt_rcv_trx_e_data (rec_get_valid_rec).vendor_number;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).uom_code   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).uom_code;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).currency_code   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).currency_code;
                        --lt_rcv_trx_type (ln_valid_trx_rec_cnt).po_release_id := NULL;
                        --lt_rcv_trx_type (ln_valid_trx_rec_cnt).release_date := NULL;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).currency_conversion_type   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).currency_conversion_type;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).currency_conversion_rate   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).currency_conversion_rate;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).currency_conversion_date   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).currency_conversion_date;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).substitute_unordered_code   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).substitute_unordered_code;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).receipt_exception_flag   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).receipt_exception_flag;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).accrual_status_code   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).accrual_status_code;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).inspection_status_code   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).inspection_status_code;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).rma_reference   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).rma_reference;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).comments   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).comments;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute_category :=
                        --                        lt_rcv_trx_e_data (rec_get_valid_rec).attribute_category;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute1 :=
                        --                                lt_rcv_trx_e_data (rec_get_valid_rec).attribute1;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute2 :=
                        --                                lt_rcv_trx_e_data (rec_get_valid_rec).attribute2;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute3 :=
                        --                                lt_rcv_trx_e_data (rec_get_valid_rec).attribute3;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute4 :=
                        --                                lt_rcv_trx_e_data (rec_get_valid_rec).attribute4;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute5 :=
                        --                                lt_rcv_trx_e_data (rec_get_valid_rec).attribute5;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute6 :=
                        --                                lt_rcv_trx_e_data (rec_get_valid_rec).attribute6;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute7 :=
                        --                                lt_rcv_trx_e_data (rec_get_valid_rec).attribute7;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute8 :=
                        --                                lt_rcv_trx_e_data (rec_get_valid_rec).attribute8;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute9 :=
                        --                                lt_rcv_trx_e_data (rec_get_valid_rec).attribute9;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute10 :=
                        --                               lt_rcv_trx_e_data (rec_get_valid_rec).attribute10;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute11 :=
                        --                               lt_rcv_trx_e_data (rec_get_valid_rec).attribute11;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute12 :=
                        --                               lt_rcv_trx_e_data (rec_get_valid_rec).attribute12;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute13 :=
                        --                               lt_rcv_trx_e_data (rec_get_valid_rec).attribute13;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute15 :=
                        --                               lt_rcv_trx_e_data (rec_get_valid_rec).attribute15;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute14   :=
                            lt_rcv_trx_type (ln_valid_trx_rec_cnt).record_id;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute1   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).ship_line_attribute1;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute2   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).ship_line_attribute2;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute3   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).ship_line_attribute3;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute4   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).ship_line_attribute4;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute5   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).ship_line_attribute5;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute6   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).ship_line_attribute6;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute7   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).ship_line_attribute7;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute8   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).ship_line_attribute8;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute9   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).ship_line_attribute9;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute10   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).ship_line_attribute10;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute11   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).ship_line_attribute11;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute12   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).ship_line_attribute12;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute13   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).ship_line_attribute13;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute14   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).ship_line_attribute14;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute15   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).ship_line_attribute15;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).amount :=
                        --                                    lt_rcv_trx_e_data (rec_get_valid_rec).amount;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).inspection_quality_code :=
                        --                     lt_rcv_trx_e_data (rec_get_valid_rec).inspection_quality_code;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).clone_to_organization_code :=
                        --                           lt_rcv_trx_e_data (rec_get_valid_rec).to_organization;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).country_of_origin_code :=
                        --                     lt_rcv_trx_e_data (rec_get_valid_rec).country_of_origin_code;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).mobile_txn :=
                        --                                lt_rcv_trx_e_data (rec_get_valid_rec).mobile_txn;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).subinventory :=
                        --                              lt_rcv_trx_e_data (rec_get_valid_rec).subinventory;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).deliver_to_person_name   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).deliver_to_person;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).primary_quantity :=
                        --                          lt_rcv_trx_e_data (rec_get_valid_rec).primary_quantity;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).destination_type_code :=
                        --                     lt_rcv_trx_e_data (rec_get_valid_rec).destination_type_code;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_to_location_code   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).ship_to_location;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).segment1   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).segment1;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).po_line_num   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).line_num;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).shipment_num   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).shipment_num;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).shipment_line_id   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).shipment_line_id;
                        --   lt_rcv_trx_type (ln_valid_trx_rec_cnt).distribution_num :=
                        --                  lt_rcv_trx_e_data (rec_get_valid_rec).distribution_num;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).freight_carrier_code   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).freight_carrier_code;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).bill_of_lading   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).bill_of_lading;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).packing_slip   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).packing_slip;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).shipped_date   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).shipped_date;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).expected_receipt_date   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).expected_receipt_date;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).transfer_cost   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).transfer_cost;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).transportation_cost   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).transportation_cost;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).num_of_containers   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).num_of_containers;
                        --   lt_rcv_trx_type (ln_valid_trx_rec_cnt).LOCATION_code :=
                        --              lt_rcv_trx_e_data (rec_get_valid_rec).LOCATION_CODE;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).deliver_to_person_name   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).deliver_to_person;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).quantity_shipped   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).quantity_shipped;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).clone_operating_unit   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).operating_unit;
                        /* lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute15 :=
                                      lt_rcv_trx_e_data (rec_get_valid_rec).attribute15;*/
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).employee_name :=
                        --                             lt_rcv_trx_e_data (rec_get_valid_rec).employee_name;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).vendor_name   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).vendor_name;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).vendor_site_code   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).vendor_site_code;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).creation_date   :=
                            SYSDATE;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).created_by   :=
                            gn_user_id;
                        --  lt_rcv_trx_type (ln_valid_trx_rec_cnt).last_update_date :=
                        --     lt_rcv_trx_e_data (rec_get_valid_rec).last_update_date;
                        -- lt_rcv_trx_type (ln_valid_trx_rec_cnt).last_updated_by :=
                        --  lt_rcv_trx_e_data (rec_get_valid_rec).last_updated_by;
                        --  lt_rcv_trx_type (ln_valid_trx_rec_cnt).last_update_login :=
                        -- lt_rcv_trx_e_data (rec_get_valid_rec).last_update_login;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).program_application_id   :=
                            NULL;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).program_id   :=
                            NULL;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).program_update_date   :=
                            NULL;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).asn_shipment_header_id   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).asn_shipment_header_id;
                        -- added below for APAC
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).shipment_header_id   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).shipment_header_id;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).asn_shipment_line_id   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).asn_shipment_line_id;
                        -- added above for APAC
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ir_type   :=
                            lt_rcv_trx_e_data (rec_get_valid_rec).ir_type;
                        --lt_rcv_trx_type (ln_valid_trx_rec_cnt).locator_id := lt_rcv_trx_e_data (rec_get_valid_rec).locator_id;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).locator_id :=
                        --                                    lt_rcv_trx_e_data (rec_get_valid_rec).loc_id;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).request_id   :=
                            gn_conc_request_id;
                    END LOOP;

                    -------------------------------------------------------------------
                    -- do a bulk insert into the xxd_ir_rcv_trans_cnv_stg table
                    ----------------------------------------------------------------
                    log_records (p_debug_flag,
                                 'Bulk Inser to xxd_ir_rcv_trans_cnv_stg 1');

                    FORALL ln_cnt IN 1 .. lt_rcv_trx_type.COUNT
                      SAVE EXCEPTIONS
                        INSERT INTO xxd_ir_rcv_trans_cnv_stg
                             VALUES lt_rcv_trx_type (ln_cnt);

                    lt_rcv_trx_e_data.DELETE;
                END IF;

                COMMIT;
            END LOOP;

            IF c_get_trx_emea_rec%ISOPEN
            THEN
                CLOSE c_get_trx_emea_rec;
            END IF;

            --x_rec_count := ln_valid_trx_rec_cnt;
            log_records (p_debug_flag, 'EMEA transaction extract complete ');
        ELSIF p_receipt_type = 'JAPAN'
        THEN
            OPEN c_get_trx_japan_rec;

            LOOP
                log_records (p_debug_flag,
                             'Start of transfer_records procedure japan1');
                SAVEPOINT insert_table2;
                lt_rcv_trx_j_data.DELETE;
                lt_rcv_trx_type.DELETE;

                FETCH c_get_trx_japan_rec
                    BULK COLLECT INTO lt_rcv_trx_j_data
                    LIMIT 1000;

                log_records (p_debug_flag,
                             'Start of transfer_records procedure2');
                EXIT WHEN lt_rcv_trx_j_data.COUNT = 0;
                log_records (
                    p_debug_flag,
                    'transfer_records Count => ' || lt_rcv_trx_j_data.COUNT);

                IF lt_rcv_trx_j_data.COUNT > 0
                THEN
                    log_records (
                        p_debug_flag,
                        'Assign the valus and buk insert to stage tables 1');
                    ln_valid_trx_rec_cnt   := 0;

                    FOR rec_get_valid_rec IN lt_rcv_trx_j_data.FIRST ..
                                             lt_rcv_trx_j_data.LAST
                    LOOP
                        ln_count               := ln_count + 1;
                        ln_valid_trx_rec_cnt   := ln_valid_trx_rec_cnt + 1;
                        --
                        --log_records (p_debug_flag,'Row count :' || ln_valid_trx_rec_cnt);
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).batch_id   :=
                            NULL;

                        BEGIN
                            SELECT xxd_rcv_trx_id_s.NEXTVAL
                              INTO lt_rcv_trx_type (ln_valid_trx_rec_cnt).record_id
                              FROM DUAL;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                log_records (
                                    p_debug_flag,
                                       SUBSTR (SQLERRM, 1, 150)
                                    || ' Exception fetching group id in transfer_records procedure ');
                                RAISE ex_program_exception;
                        END;

                        log_records (
                            p_debug_flag,
                            'Start of transfer_records procedure japan1       here');
                        --log_records ('Y', 'test loc '||lt_rcv_trx_j_data (rec_get_valid_rec).attribute4);
                        --   lt_rcv_trx_type (ln_valid_trx_rec_cnt).interface_header_id :=
                        --                                                            NULL;
                        -- lt_rcv_trx_type (ln_valid_trx_rec_cnt).interface_source_code :=
                        --  NULL;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).processing_status_code   :=
                            'PENDING';
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).record_status   :=
                            'N';
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).receipt_num   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).receipt_num;
                        --  lt_rcv_trx_type (ln_valid_trx_rec_cnt).group_code := NULL;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).receipt_source_code   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).receipt_source_code;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).transaction_type   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).transaction_type;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).transaction_date   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).transaction_date;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).quantity   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).quantity;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).item_id   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).item_id;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).clone_po_header_id   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).clone_po_header_id;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).clone_po_line_id   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).clone_po_line_id;
                        /*  lt_rcv_trx_type (ln_valid_trx_rec_cnt).po_header_id :=
                                          lt_rcv_trx_j_data (rec_get_valid_rec).attribute14;
                          lt_rcv_trx_type (ln_valid_trx_rec_cnt).po_line_id :=
                                          lt_rcv_trx_j_data (rec_get_valid_rec).attribute15;*/
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).unit_of_measure   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).unit_of_measure;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).po_unit_price   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).po_unit_price;
                        -- lt_rcv_trx_type (ln_valid_trx_rec_cnt).vendor_number :=
                        --     lt_rcv_trx_j_data (rec_get_valid_rec).vendor_number;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).uom_code   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).uom_code;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).currency_code   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).currency_code;
                        --lt_rcv_trx_type (ln_valid_trx_rec_cnt).po_release_id := NULL;
                        --lt_rcv_trx_type (ln_valid_trx_rec_cnt).release_date := NULL;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).currency_conversion_type   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).currency_conversion_type;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).currency_conversion_rate   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).currency_conversion_rate;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).currency_conversion_date   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).currency_conversion_date;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).substitute_unordered_code   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).substitute_unordered_code;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).receipt_exception_flag   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).receipt_exception_flag;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).accrual_status_code   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).accrual_status_code;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).inspection_status_code   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).inspection_status_code;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).rma_reference   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).rma_reference;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).comments   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).comments;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute_category :=
                        --                        lt_rcv_trx_j_data (rec_get_valid_rec).attribute_category;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute1 :=
                        --                                lt_rcv_trx_j_data (rec_get_valid_rec).attribute1;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute2 :=
                        --                                lt_rcv_trx_j_data (rec_get_valid_rec).attribute2;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute3 :=
                        --                                lt_rcv_trx_j_data (rec_get_valid_rec).attribute3;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute4 :=
                        --                                lt_rcv_trx_j_data (rec_get_valid_rec).attribute4;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute5 :=
                        --                                lt_rcv_trx_j_data (rec_get_valid_rec).attribute5;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute6 :=
                        --                                lt_rcv_trx_j_data (rec_get_valid_rec).attribute6;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute7 :=
                        --                                lt_rcv_trx_j_data (rec_get_valid_rec).attribute7;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute8 :=
                        --                                lt_rcv_trx_j_data (rec_get_valid_rec).attribute8;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute9 :=
                        --                                lt_rcv_trx_j_data (rec_get_valid_rec).attribute9;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute10 :=
                        --                               lt_rcv_trx_j_data (rec_get_valid_rec).attribute10;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute11 :=
                        --                               lt_rcv_trx_j_data (rec_get_valid_rec).attribute11;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute12 :=
                        --                               lt_rcv_trx_j_data (rec_get_valid_rec).attribute12;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute13 :=
                        --                               lt_rcv_trx_j_data (rec_get_valid_rec).attribute13;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute15 :=
                        --                               lt_rcv_trx_j_data (rec_get_valid_rec).attribute15;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute14   :=
                            lt_rcv_trx_type (ln_valid_trx_rec_cnt).record_id;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute1   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).ship_line_attribute1;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute2   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).ship_line_attribute2;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute3   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).ship_line_attribute3;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute4   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).ship_line_attribute4;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute5   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).ship_line_attribute5;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute6   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).ship_line_attribute6;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute7   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).ship_line_attribute7;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute8   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).ship_line_attribute8;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute9   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).ship_line_attribute9;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute10   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).ship_line_attribute10;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute11   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).ship_line_attribute11;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute12   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).ship_line_attribute12;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute13   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).ship_line_attribute13;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute14   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).ship_line_attribute14;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_line_attribute15   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).ship_line_attribute15;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).amount :=
                        --                                    lt_rcv_trx_j_data (rec_get_valid_rec).amount;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).inspection_quality_code :=
                        --                     lt_rcv_trx_j_data (rec_get_valid_rec).inspection_quality_code;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).clone_to_organization_code :=
                        --                           lt_rcv_trx_j_data (rec_get_valid_rec).to_organization;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).country_of_origin_code :=
                        --                     lt_rcv_trx_j_data (rec_get_valid_rec).country_of_origin_code;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).mobile_txn :=
                        --                                lt_rcv_trx_j_data (rec_get_valid_rec).mobile_txn;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).subinventory :=
                        --                              lt_rcv_trx_j_data (rec_get_valid_rec).subinventory;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).deliver_to_person_name   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).deliver_to_person;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).primary_quantity :=
                        --                          lt_rcv_trx_j_data (rec_get_valid_rec).primary_quantity;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).destination_type_code :=
                        --                     lt_rcv_trx_j_data (rec_get_valid_rec).destination_type_code;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ship_to_location_code   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).ship_to_location;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).segment1   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).segment1;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).po_line_num   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).line_num;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).shipment_num   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).shipment_num;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).shipment_line_id   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).shipment_line_id;
                        --   lt_rcv_trx_type (ln_valid_trx_rec_cnt).distribution_num :=
                        --                  lt_rcv_trx_j_data (rec_get_valid_rec).distribution_num;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).freight_carrier_code   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).freight_carrier_code;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).bill_of_lading   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).bill_of_lading;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).packing_slip   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).packing_slip;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).shipped_date   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).shipped_date;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).expected_receipt_date   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).expected_receipt_date;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).transfer_cost   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).transfer_cost;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).transportation_cost   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).transportation_cost;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).num_of_containers   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).num_of_containers;
                        --   lt_rcv_trx_type (ln_valid_trx_rec_cnt).LOCATION_code :=
                        --              lt_rcv_trx_j_data (rec_get_valid_rec).LOCATION_CODE;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).deliver_to_person_name   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).deliver_to_person;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).quantity_shipped   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).quantity_shipped;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).clone_operating_unit   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).operating_unit;
                        /* lt_rcv_trx_type (ln_valid_trx_rec_cnt).attribute15 :=
                                      lt_rcv_trx_j_data (rec_get_valid_rec).attribute15;*/
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).employee_name :=
                        --                             lt_rcv_trx_j_data (rec_get_valid_rec).employee_name;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).vendor_name   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).vendor_name;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).vendor_site_code   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).vendor_site_code;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).creation_date   :=
                            SYSDATE;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).created_by   :=
                            gn_user_id;
                        --  lt_rcv_trx_type (ln_valid_trx_rec_cnt).last_update_date :=
                        --     lt_rcv_trx_j_data (rec_get_valid_rec).last_update_date;
                        -- lt_rcv_trx_type (ln_valid_trx_rec_cnt).last_updated_by :=
                        --  lt_rcv_trx_j_data (rec_get_valid_rec).last_updated_by;
                        --  lt_rcv_trx_type (ln_valid_trx_rec_cnt).last_update_login :=
                        -- lt_rcv_trx_j_data (rec_get_valid_rec).last_update_login;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).program_application_id   :=
                            NULL;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).program_id   :=
                            NULL;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).program_update_date   :=
                            NULL;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).asn_shipment_header_id   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).asn_shipment_header_id;
                        -- added below for APAC
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).shipment_header_id   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).shipment_header_id;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).asn_shipment_line_id   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).asn_shipment_line_id;
                        -- added above for APAC
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).ir_type   :=
                            lt_rcv_trx_j_data (rec_get_valid_rec).ir_type;
                        --lt_rcv_trx_type (ln_valid_trx_rec_cnt).locator_id := lt_rcv_trx_j_data (rec_get_valid_rec).locator_id;
                        --                  lt_rcv_trx_type (ln_valid_trx_rec_cnt).locator_id :=
                        --                                    lt_rcv_trx_j_data (rec_get_valid_rec).loc_id;
                        lt_rcv_trx_type (ln_valid_trx_rec_cnt).request_id   :=
                            gn_conc_request_id;
                        log_records (
                            p_debug_flag,
                            'Start of transfer_records procedure japan1    ending   here');
                    END LOOP;

                    -------------------------------------------------------------------
                    -- do a bulk insert into the xxd_ir_rcv_trans_cnv_stg table
                    ----------------------------------------------------------------
                    log_records (p_debug_flag,
                                 'Bulk Inser to xxd_ir_rcv_trans_cnv_stg 1');

                    FORALL ln_cnt IN 1 .. lt_rcv_trx_type.COUNT
                      SAVE EXCEPTIONS
                        INSERT INTO xxd_ir_rcv_trans_cnv_stg
                             VALUES lt_rcv_trx_type (ln_cnt);

                    lt_rcv_trx_j_data.DELETE;
                END IF;

                COMMIT;
            END LOOP;

            IF c_get_trx_japan_rec%ISOPEN
            THEN
                CLOSE c_get_trx_japan_rec;
            END IF;

            --x_rec_count := ln_valid_trx_rec_cnt;
            log_records (p_debug_flag, 'JAPAN transaction extract complete ');
        END IF;
    EXCEPTION
        WHEN ex_program_exception
        THEN
            ROLLBACK TO insert_table2;
            x_ret_code   := gn_err_const;
            log_records (p_debug_flag, 'exception1 ');

            IF c_get_trx_rec%ISOPEN
            THEN
                CLOSE c_get_trx_rec;
            ELSIF c_get_trx_emea_rec%ISOPEN
            THEN
                CLOSE c_get_trx_emea_rec;
            ELSIF c_get_trx_japan_rec%ISOPEN
            THEN
                CLOSE c_get_trx_japan_rec;
            END IF;

            log_records (p_debug_flag,
                         'ex_program_Exception raised' || SQLERRM);
            xxd_common_utils.record_error ('RECEIPTS', gn_org_id, 'XXD Open Purchase Orders Conversion Program', --    SQLCODE,
                                                                                                                 SQLERRM, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                               --     SYSDATE,
                                                                                                                                                               gn_user_id, gn_conc_request_id, 'xxd_ir_rcv_trans_cnv_stg', NULL
                                           , 'Exception in bulk insert');
        WHEN ex_bulk_exceptions
        THEN
            ROLLBACK TO insert_table2;
            l_bulk_errors   := SQL%BULK_EXCEPTIONS.COUNT;
            x_ret_code      := gn_err_const;

            IF c_get_trx_rec%ISOPEN
            THEN
                CLOSE c_get_trx_rec;
            ELSIF c_get_trx_emea_rec%ISOPEN
            THEN
                CLOSE c_get_trx_emea_rec;
            ELSIF c_get_trx_japan_rec%ISOPEN
            THEN
                CLOSE c_get_trx_japan_rec;
            END IF;

            FOR l_errcnt IN 1 .. l_bulk_errors
            LOOP
                log_records (
                    p_debug_flag,
                       SQLERRM (-SQL%BULK_EXCEPTIONS (l_errcnt).ERROR_CODE)
                    || ' Exception in transfer_records procedure ');
                xxd_common_utils.record_error (
                    'RECEIPTS',
                    gn_org_id,
                    'XXD Open Purchase Orders Conversion Program',
                    --   SQLCODE,
                    SQLERRM,
                    DBMS_UTILITY.format_error_backtrace,
                    --   DBMS_UTILITY.format_call_stack,
                    --   SYSDATE,
                    gn_user_id,
                    gn_conc_request_id,
                    'xxd_ir_rcv_trans_cnv_stg',
                    NULL,
                    SQLERRM (-SQL%BULK_EXCEPTIONS (l_errcnt).ERROR_CODE));
            END LOOP;
        WHEN OTHERS
        THEN
            ROLLBACK TO insert_table2;
            x_ret_code   := gn_err_const;
            log_records (
                p_debug_flag,
                   SUBSTR (SQLERRM, 1, 250)
                || ' Exception in transfer_records procedure');

            IF c_get_trx_rec%ISOPEN
            THEN
                CLOSE c_get_trx_rec;
            ELSIF c_get_trx_emea_rec%ISOPEN
            THEN
                CLOSE c_get_trx_emea_rec;
            ELSIF c_get_trx_japan_rec%ISOPEN
            THEN
                CLOSE c_get_trx_japan_rec;
            END IF;

            xxd_common_utils.record_error (
                'RECEIPTS',
                gn_org_id,
                'XXD Open Purchase Orders Conversion Program',
                --   SQLCODE,
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --   SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'xxd_ir_rcv_trans_cnv_stg',
                NULL,
                'Unexpected Exception while inserting into xxd_ir_rcv_trans_cnv_stg');
    END extract_rcv_trx;

    PROCEDURE extract_recpts_1206_records (p_debug_flag IN VARCHAR2, x_ret_code OUT VARCHAR2, x_return_mesg OUT VARCHAR2
                                           , p_receipt_type IN VARCHAR2)
    AS
        lx_return_mesg    VARCHAR2 (2000);
        ln_header_cnt     NUMBER := 0;
        ln_lines_cnt      NUMBER := 0;
        ln_location_cnt   NUMBER := 0;
        ln_dist_cnt       NUMBER := 0;
        ln_line_cnt       NUMBER := 0;
    BEGIN
        --x_return_status:= 'P';
        -- Extract Open Purchase Order Header Records from 1206
        log_records (
            p_debug_flag,
            'Calling extract_rcv_headers Procedure to extract the 1206 data to stage');
        extract_rcv_headers (p_debug_flag     => p_debug_flag,
                             x_ret_code       => x_ret_code,
                             x_rec_count      => ln_header_cnt,
                             x_return_mesg    => lx_return_mesg,
                             p_receipt_type   => p_receipt_type);
        log_records (
            p_debug_flag,
            'extract_rcv_headers Procedure Completed  extracting  1206 data to stage');
        --- Extract Open Purchase Order  Lines  Records from 1206
        log_records (
            p_debug_flag,
            'Calling extract_rcv_trx Procedure to extract the 1206 data to stage');
        extract_rcv_trx (p_debug_flag     => p_debug_flag,
                         x_ret_code       => x_ret_code,
                         x_rec_count      => ln_line_cnt,
                         x_return_mesg    => lx_return_mesg,
                         p_receipt_type   => p_receipt_type);
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code   := gn_err_const;
            x_return_mesg   :=
                   'When others error When loading the data from 1206 '
                || SQLERRM;
            log_records (
                p_debug_flag,
                   'When others error while loading the data from 1206 => '
                || SQLERRM);
            xxd_common_utils.record_error ('PO RECEIPTS', gn_org_id, 'XXD Receipts Conversion Program', --      SQLCODE,
                                                                                                        SQLERRM, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                      --    SYSDATE,
                                                                                                                                                      gn_user_id, gn_conc_request_id, 'extract_recpts_1206_records', NULL
                                           , NULL);
    END extract_recpts_1206_records;

    PROCEDURE validate_data (p_batch_id       IN     NUMBER,
                             p_debug_flag     IN     VARCHAR2,
                             x_retcode           OUT VARCHAR2,
                             x_errbuf            OUT VARCHAR2,
                             p_receipt_type   IN     VARCHAR2)
    IS
        CURSOR cur_get_loc_id (cp_ship_to_loc VARCHAR2)
        IS
            SELECT location_id
              FROM hr_locations
             WHERE location_code = cp_ship_to_loc;

        CURSOR cur_get_ename (cp_ename IN VARCHAR2)
        IS
            SELECT ppf2.person_id
              FROM per_all_people_f ppf2
             WHERE     UPPER (ppf2.full_name) = UPPER (cp_ename)
                   AND TRUNC (SYSDATE) BETWEEN NVL (
                                                   TRUNC (
                                                       ppf2.effective_start_date),
                                                   TRUNC (SYSDATE - 1))
                                           AND NVL (
                                                   TRUNC (
                                                       ppf2.effective_end_date),
                                                   TRUNC (SYSDATE + 1));

        CURSOR cur_get_to_orgid (cp_to_org_code VARCHAR2)
        IS
            SELECT organization_id
              FROM org_organization_definitions
             WHERE organization_code = cp_to_org_code;

        CURSOR cur_get_to_sorgid (cp_to_org_id NUMBER)
        IS
            SELECT organization_code
              FROM org_organization_definitions
             WHERE organization_id = cp_to_org_id;

        CURSOR cur_get_req_id (cp_req_line_id NUMBER)
        IS
            SELECT requisition_line_id, rl.to_person_id, rh.preparer_id,
                   rl.org_id, rl.destination_organization_id, rl.source_organization_id
              FROM po_requisition_headers_all rh, po_requisition_lines_all rl
             WHERE     rh.requisition_header_id = rl.requisition_header_id
                   AND TO_CHAR (rl.attribute15) = TO_CHAR (cp_req_line_id); --'162';

        -- AND rl.attribute15 = cp_req_line_id;
        CURSOR cur_get_nreq_id (cp_req_line_id NUMBER)
        IS
            /*     SELECT requisition_line_id, rl.to_person_id, rh.preparer_id,
                        rl.org_id, rl.destination_organization_id,
                        rl.source_organization_id
                   FROM po_requisition_headers_all rh, po_requisition_lines_all rl
                  WHERE rh.requisition_header_id = rl.requisition_header_id
                    AND TO_CHAR (rl.attribute14) = TO_CHAR (cp_req_line_id);*/
            SELECT requisition_line_id, rl.to_person_id, rh.preparer_id,
                   rl.org_id, rl.destination_organization_id, rl.source_organization_id
              FROM po_requisition_headers_all rh, po_requisition_lines_all rl, po_lines_all pla
             WHERE     rh.requisition_header_id = rl.requisition_header_id
                   AND TO_CHAR (rl.attribute14) = TO_CHAR (pla.attribute15)
                   --AND pla.po_line_id = cp_req_line_id;
                   AND pla.attribute15 = cp_req_line_id;

        CURSOR cur_get_sh_line (cp_shp_line NUMBER)
        IS
            SELECT COUNT (attribute15)
              FROM rcv_shipment_lines
             WHERE attribute15 = cp_shp_line;

        CURSOR cur_get_receipt (cp_nrec VARCHAR2, cp_lid NUMBER)
        IS
            SELECT COUNT (*)
              FROM rcv_shipment_headers
             WHERE receipt_num = cp_nrec AND ship_to_org_id = cp_lid;

        lt_xxpo_header_stg_tbl   gt_xxpo_rct_hdr_tbl_type;
        lt_xxpo_line_stg_tbl     gt_xxpo_trxline_stg_tbl_type;
        lt_xxpo_line_stg_tbl2    gt_xxpo_trxline_stg_tbl_type;
        --  lc_valid_flag              VARCHAR2 (10) := NULL;
        lc_error_message         VARCHAR2 (6000) := NULL;
        ln_flag                  NUMBER := 0;
        lc_phase                 VARCHAR2 (6000);
        lc_phase2                VARCHAR2 (6000);
        ln_row_count             NUMBER := 0;
        ln_row_line_count        NUMBER := 0;
        lc_header_err_flag       VARCHAR2 (1);
        ex_no_lines              EXCEPTION;
        ln_sloc_id               NUMBER;
        ln_error_line_count      NUMBER := 0;
        lc_line_err_flag         VARCHAR2 (1);
        lc_line_err_flag2        VARCHAR2 (1);
        lc_line_error_message    VARCHAR2 (6000) := NULL;
        ln_eid                   NUMBER;
        ln_line_flag             NUMBER := 0;
        ln_forgid                NUMBER;
        ln_torgid                NUMBER;
        lc_retcode               VARCHAR2 (6000);
        lc_errbuf                VARCHAR2 (6000);
        ln_org_id                NUMBER;
        ln_org_id1               NUMBER;
        ln_line_cnt              NUMBER;
        --ln_sloc_id                 NUMBER;
        lc_rec                   VARCHAR2 (100);
        lc_org_name              VARCHAR2 (100);
        lc_h_ou                  VARCHAR2 (100);
        lc_h_ou_n                VARCHAR2 (100);
        ln_trx_vid               NUMBER;
        ln__trx_site_id          NUMBER;
        ln_po_hid                NUMBER;
        ln_po_lid                NUMBER;
        l_sh_code                VARCHAR2 (100);
        l_ln_sh_code             VARCHAR2 (100);
        ln_org_id_n              NUMBER;
        ln_rcp_cnt               NUMBER;
        ln_sh_cnt                NUMBER;
        lc_locator_name          VARCHAR2 (100);
        ln_locator_id            NUMBER;
        lc_subinventory          VARCHAR2 (100);
        ln_person_id             NUMBER;
        ln_pid                   NUMBER;
        ln_agent_id              NUMBER;
        ln_preparer_id           NUMBER;
        lc_sh_code               VARCHAR2 (100);
        lc_closing_status        VARCHAR2 (10);
    BEGIN
        --lc_valid_flag := 'Y';
        OPEN cur_get_header_dtls (gc_new, p_batch_id);

        LOOP
            FETCH cur_get_header_dtls
                BULK COLLECT INTO lt_xxpo_header_stg_tbl
                LIMIT 1000;

            --CLOSE cur_get_header_dtls;
            ln_row_count   := lt_xxpo_header_stg_tbl.COUNT ();
            log_records (
                p_debug_flag,
                'Number of new PO receipt records: ' || ln_row_count);

            IF NVL (ln_row_count, 0) = 0
            THEN
                x_retcode   := 'W';                              --gc_warning;
                x_errbuf    :=
                    'No new PO receipts found that needs validation ';
                RETURN;
            END IF;

            FOR i IN 1 .. ln_row_count
            LOOP
                --Validating organization_name
                lc_phase                                 := NULL;
                --   log_records (p_debug_flag, 'here1');
                lc_error_message                         := NULL;
                lc_phase                                 := NULL;
                lc_header_err_flag                       := gc_yes;
                lc_line_err_flag2                        := gc_yes;

                /* IF lt_xxpo_header_stg_tbl (i).cl_ship_to_organization_code IS NULL
                   THEN
                      lc_phase := ' organization code can not be NULL ';
                   ELSE

                      OPEN cur_get_to_orgid
                                (lt_xxpo_header_stg_tbl (i).cl_ship_to_organization_code
                                );

                      FETCH cur_get_to_orgid
                       INTO ln_torgid;

                      CLOSE cur_get_to_orgid;

                      IF ln_torgid IS NULL
                      THEN
                         lc_phase :=
                               ' organization code is invalid'
                            || lt_xxpo_header_stg_tbl (i).cl_ship_to_organization_code;
                      END IF;
                   END IF;

                   IF lc_phase IS NOT NULL
                   THEN
                      lt_xxpo_header_stg_tbl (i).processing_status_code :=
                                                                          'REJECTED';
                      lt_xxpo_header_stg_tbl (i).record_status := gc_invalid;
                      --gc_invalid;
                      lc_header_err_flag := gc_no;
                      ln_flag := ln_flag + 1;
                      lc_error_message :=
                            lc_error_message
                         || TO_CHAR (ln_flag)
                         || '. '
                         || lc_phase
                         || ' ';
                   END IF;

                   lt_xxpo_header_stg_tbl (i).ship_to_organization_id := ln_torgid;
                   */
                IF lt_xxpo_header_stg_tbl (i).employee_name IS NOT NULL
                THEN
                    OPEN cur_get_ename (
                        lt_xxpo_header_stg_tbl (i).employee_name);

                    FETCH cur_get_ename INTO ln_eid;

                    CLOSE cur_get_ename;

                    IF ln_eid IS NULL
                    THEN
                        lc_phase   := 'Employee name is invalid  ';
                    END IF;
                END IF;

                --log_records (p_debug_flag, '3 ');
                IF     lc_phase IS NOT NULL
                   AND lt_xxpo_header_stg_tbl (i).employee_name IS NOT NULL
                -- uncomment second condition as well
                THEN
                    /* lt_xxpo_header_stg_tbl (i).processing_status_code :=
                                                                         'REJECTED';
                     lt_xxpo_header_stg_tbl (i).record_status := gc_invalid;
                     lc_header_err_flag := gc_no;
                     ln_flag := ln_flag + 1;
                     lc_error_message :=
                                        TO_CHAR (ln_flag) || '. ' || lc_phase
                                        || ' ';
                     xxd_common_utils.record_error
                                              ('PO RECEIPTS',
                                               gn_org_id,
                                               'XXD Receipts Conversion Program',
                                               --      SQLCODE,
                                               lc_phase,
                                               DBMS_UTILITY.format_error_backtrace,
                                                --   DBMS_UTILITY.format_call_stack,
                                               --    SYSDATE,
                                               gn_user_id,
                                               gn_conc_request_id,
                                               'Employee name',
                                               NULL,
                                               NULL
                                              );*/
                    -- uncomment it later  -- imp
                    NULL;

                    SELECT ppf2.person_id
                      INTO ln_eid
                      FROM per_all_people_f ppf2
                     WHERE     UPPER (ppf2.full_name) =
                               UPPER ('Stewart, Celene')
                           AND TRUNC (SYSDATE) BETWEEN NVL (
                                                           TRUNC (
                                                               ppf2.effective_start_date),
                                                           TRUNC (
                                                               SYSDATE - 1))
                                                   AND NVL (
                                                           TRUNC (
                                                               ppf2.effective_end_date),
                                                           TRUNC (
                                                               SYSDATE + 1));
                -- need to change this when all employee and deliver are moved
                --ln_eid := 86;
                END IF;

                lt_xxpo_header_stg_tbl (i).employee_id   := ln_eid;
                lt_xxpo_header_stg_tbl (i).error_message   :=
                    lc_error_message;

                BEGIN
                    OPEN cur_get_line_dtls (
                        lt_xxpo_header_stg_tbl (i).shipment_header_id,
                        --- added in the view extract for APAC and did this to check if headers and lines are same
                        'N');

                    --  LOOP
                    FETCH cur_get_line_dtls
                        BULK COLLECT INTO lt_xxpo_line_stg_tbl; -- LIMIT 1000;

                    CLOSE cur_get_line_dtls;

                    --Closing the line cursor
                    ln_row_line_count   := lt_xxpo_line_stg_tbl.COUNT ();

                    IF NVL (ln_row_line_count, 0) = 0
                    THEN
                        RAISE ex_no_lines;
                    END IF;

                    --Validating each line record
                    FOR j IN 1 .. ln_row_line_count
                    LOOP
                        lc_line_err_flag        := gc_yes;
                        lc_line_error_message   := NULL;
                        lc_phase2               := NULL;
                        ln_eid                  := NULL;
                        ln_pid                  := NULL;

                        IF lt_xxpo_line_stg_tbl (j).deliver_to_person_name
                               IS NOT NULL
                        THEN
                            --lc_phase2 := 'deliver_to_person_name cannot be null for the receipt';  -- should uncomment later
                            --  NULL;
                            -- ELSE
                            OPEN cur_get_ename (
                                lt_xxpo_line_stg_tbl (j).deliver_to_person_name);

                            FETCH cur_get_ename INTO ln_pid;

                            CLOSE cur_get_ename;

                            IF ln_pid IS NULL
                            THEN
                                lc_phase2   :=
                                    'deliver_to_person_name is invalid for the PO : ';
                            END IF;
                        END IF;

                        IF lc_phase2 IS NOT NULL
                        THEN
                            --Checking employee_number is present or not
                            /*   lt_xxpo_line_stg_tbl (j).processing_status_code :=
                                                                             'REJECTED';
                               lt_xxpo_line_stg_tbl (j).record_status := gc_invalid;
                               lc_line_err_flag := gc_no;
                               ln_line_flag := ln_line_flag + 1;
                               lc_line_error_message :=
                                           TO_CHAR (ln_flag) || '. ' || lc_phase2
                                           || ' ';
                               xxd_common_utils.record_error
                                                  ('PO RECEIPTS',
                                                   gn_org_id,
                                                   'XXD Receipts Conversion Program',
                                                   --      SQLCODE,
                                                   lc_phase,
                                                   DBMS_UTILITY.format_error_backtrace,
                                                    --   DBMS_UTILITY.format_call_stack,
                                                   --    SYSDATE,
                                                   gn_user_id,
                                                   gn_conc_request_id,
                                                   'deliver_to_person',
                                                   NULL,
                                                   NULL
                                                  );*/
                            NULL;

                            -- commented to add some employee name if empoloyee name is not available  -- need to unccomment
                            SELECT ppf2.person_id
                              INTO ln_pid
                              FROM per_all_people_f ppf2
                             WHERE     UPPER (ppf2.full_name) =
                                       UPPER ('Stewart, Celene')
                                   AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                   TRUNC (
                                                                       ppf2.effective_start_date),
                                                                   TRUNC (
                                                                         SYSDATE
                                                                       - 1))
                                                           AND NVL (
                                                                   TRUNC (
                                                                       ppf2.effective_end_date),
                                                                   TRUNC (
                                                                         SYSDATE
                                                                       + 1));
                        END IF;

                        lt_xxpo_line_stg_tbl (j).deliver_to_person_id   :=
                            ln_pid;
                        lc_phase2               :=
                            NULL;

                        -- commented to get agent value from PO
                        IF lt_xxpo_line_stg_tbl (j).employee_name IS NOT NULL
                        THEN
                            -- lc_phase2 := 'employee name cannot be null for the receipt';  -- should uncomment later
                            -- ELSE
                            OPEN cur_get_ename (
                                lt_xxpo_line_stg_tbl (j).employee_name);

                            FETCH cur_get_ename INTO ln_eid;

                            CLOSE cur_get_ename;

                            IF ln_eid IS NULL
                            THEN
                                lc_phase2   :=
                                    'employee is invalid for the PO : ';
                            END IF;
                        END IF;

                        IF lc_phase2 IS NOT NULL
                        THEN
                            --Checking employee_number is present or not
                            --Checking employee_number is present or not
                            /*   lt_xxpo_line_stg_tbl (j).processing_status_code :=
                                                                             'REJECTED';
                               lt_xxpo_line_stg_tbl (j).record_status := gc_invalid;
                               lc_line_err_flag := gc_no;
                               ln_line_flag := ln_line_flag + 1;
                               lc_line_error_message :=
                                           TO_CHAR (ln_flag) || '. ' || lc_phase2
                                           || ' ';
                               xxd_common_utils.record_error
                                                  ('PO RECEIPTS',
                                                   gn_org_id,
                                                   'XXD Receipts Conversion Program',
                                                   --      SQLCODE,
                                                   lc_phase,
                                                   DBMS_UTILITY.format_error_backtrace,
                                                    --   DBMS_UTILITY.format_call_stack,
                                                   --    SYSDATE,
                                                   gn_user_id,
                                                   gn_conc_request_id,
                                                   'employee_name',
                                                   NULL,
                                                   NULL
                                                  );*/
                            -- uncomment it later  -- imp
                            NULL;

                            SELECT ppf2.person_id
                              INTO ln_eid
                              FROM per_all_people_f ppf2
                             WHERE     UPPER (ppf2.full_name) =
                                       UPPER ('Stewart, Celene')
                                   AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                   TRUNC (
                                                                       ppf2.effective_start_date),
                                                                   TRUNC (
                                                                         SYSDATE
                                                                       - 1))
                                                           AND NVL (
                                                                   TRUNC (
                                                                       ppf2.effective_end_date),
                                                                   TRUNC (
                                                                         SYSDATE
                                                                       + 1));
                        END IF;

                        lt_xxpo_line_stg_tbl (j).employee_id   :=
                            ln_eid;
                        lc_phase2               :=
                            NULL;
                        log_records (
                            p_debug_flag,
                               'PO Line'
                            || lt_xxpo_line_stg_tbl (j).clone_po_line_id);
                        ln_po_lid               :=
                            NULL;

                        IF lt_xxpo_line_stg_tbl (j).clone_po_line_id IS NULL
                        THEN
                            lc_phase2   := 'Requisition cannot be null ';
                        ELSE
                            IF lt_xxpo_line_stg_tbl (j).ir_type = 'APAC' --'OLD_IR'
                            THEN
                                OPEN cur_get_req_id (
                                    lt_xxpo_line_stg_tbl (j).clone_po_line_id);

                                FETCH cur_get_req_id
                                    INTO ln_po_lid, ln_person_id, ln_preparer_id, ln_org_id,
                                         ln_torgid, ln_forgid;

                                --, ln_sloc_id, ln_torgid;

                                --- added to get loc and org from PO
                                CLOSE cur_get_req_id;

                                log_records (p_debug_flag,
                                             'ln_torgid' || ln_torgid);
                                log_records (p_debug_flag,
                                             'preparer' || ln_preparer_id);
                                log_records (p_debug_flag,
                                             'ln_org_id' || ln_org_id);
                                log_records (p_debug_flag,
                                             'ln_po_lid' || ln_po_lid);
                                log_records (
                                    p_debug_flag,
                                       'requisition Line id after assignment'
                                    || ln_po_lid);
                            ELSIF lt_xxpo_line_stg_tbl (j).ir_type IN
                                      ('EMEA', 'JAPAN')
                            --'NEW_IR'
                            THEN
                                OPEN cur_get_nreq_id (
                                    lt_xxpo_line_stg_tbl (j).clone_po_line_id);

                                FETCH cur_get_nreq_id
                                    INTO ln_po_lid, ln_person_id, ln_preparer_id, ln_org_id,
                                         ln_torgid, ln_forgid;

                                --, ln_sloc_id, ln_torgid;

                                --- added to get loc and org from PO
                                CLOSE cur_get_nreq_id;

                                log_records (p_debug_flag,
                                             'ln_torgid' || ln_torgid);
                                log_records (p_debug_flag,
                                             'preparer' || ln_preparer_id);
                                log_records (p_debug_flag,
                                             'ln_org_id' || ln_org_id);
                                log_records (p_debug_flag,
                                             'ln_po_lid' || ln_po_lid);
                                log_records (
                                    p_debug_flag,
                                       'requisition Line id after assignment'
                                    || ln_po_lid);
                            END IF;

                            IF ln_po_lid IS NULL
                            THEN
                                lc_phase2   := 'IR name is invalid  ';
                            END IF;
                        END IF;

                        --log_records (p_debug_flag, '3 ');
                        IF lc_phase2 IS NOT NULL
                        THEN
                            lt_xxpo_line_stg_tbl (j).processing_status_code   :=
                                'REJECTED';
                            lt_xxpo_line_stg_tbl (j).record_status   :=
                                gc_invalid;
                            lc_line_err_flag   := gc_no;
                            ln_line_flag       := ln_line_flag + 1;
                            lc_line_error_message   :=
                                TO_CHAR (ln_flag) || '. ' || lc_phase2 || ' ';
                            xxd_common_utils.record_error ('PO RECEIPTS', gn_org_id, 'XXD Receipts Conversion Program', --      SQLCODE,
                                                                                                                        lc_phase2, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                                        --    SYSDATE,
                                                                                                                                                                        gn_user_id, gn_conc_request_id, 'PO name', NULL
                                                           , NULL);
                        END IF;

                        -- ORG
                        lc_phase2               :=
                            NULL;

                        IF ln_org_id IS NULL
                        THEN
                            lc_phase2   :=
                                   'organization name can not be NULL for the document'
                                || lt_xxpo_line_stg_tbl (j).receipt_num;
                        ELSE
                            BEGIN
                                SELECT hou.organization_id, hou.NAME
                                  INTO ln_org_id, lc_org_name
                                  FROM hr_operating_units hou
                                 WHERE hou.organization_id = ln_org_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    ln_org_id     := 0;
                                    lc_org_name   := NULL;
                                    lc_phase2     := 'ORG name is invalid : ';
                            END;

                            lt_xxpo_line_stg_tbl (j).org_id   := ln_org_id;
                            lt_xxpo_line_stg_tbl (j).operating_unit   :=
                                lc_org_name;

                            IF ln_org_id = 0
                            THEN
                                lc_phase2   :=
                                       'ORG name is invalid for the PO : '
                                    || lt_xxpo_line_stg_tbl (j).receipt_num;
                                xxd_common_utils.record_error ('PO RECEIPTS', gn_org_id, 'XXD Receipts Conversion Program', --      SQLCODE,
                                                                                                                            lc_phase2, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                                            --    SYSDATE,
                                                                                                                                                                            gn_user_id, gn_conc_request_id, 'org_id', NULL
                                                               , NULL);
                            END IF;
                        END IF;

                        IF lc_phase2 IS NOT NULL
                        THEN
                            lt_xxpo_line_stg_tbl (j).processing_status_code   :=
                                'REJECTED';
                            lt_xxpo_line_stg_tbl (j).record_status   :=
                                gc_invalid;
                            lc_line_err_flag   := gc_no;
                            ln_line_flag       := ln_line_flag + 1;
                            lc_line_error_message   :=
                                TO_CHAR (ln_flag) || '. ' || lc_phase2 || ' ';
                            xxd_common_utils.record_error ('PO RECEIPTS', gn_org_id, 'XXD Receipts Conversion Program', --      SQLCODE,
                                                                                                                        lc_phase, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                                       --    SYSDATE,
                                                                                                                                                                       gn_user_id, gn_conc_request_id, 'ORG_NAME', NULL
                                                           , NULL);
                        END IF;

                        lc_phase2               :=
                            NULL;
                        lc_closing_status       :=
                            NULL;
                        lt_xxpo_line_stg_tbl (j).transaction_date   :=
                            TO_DATE ('31-MAR-2016', 'DD-MON-YY');

                        IF lt_xxpo_line_stg_tbl (j).transaction_date IS NULL
                        THEN
                            lc_phase2   := 'TRANSACTION_DATE cannot be null ';
                        ELSE
                            BEGIN
                                SELECT ps.closing_status
                                  INTO lc_closing_status
                                  FROM gl_period_statuses ps
                                 WHERE     ps.application_id =
                                           (SELECT application_id
                                              FROM apps.fnd_application
                                             WHERE application_short_name =
                                                   'PO')
                                       AND ps.adjustment_period_flag = 'N'
                                       AND ps.set_of_books_id =
                                           (SELECT set_of_books_id
                                              FROM hr_operating_units
                                             WHERE organization_id =
                                                   ln_org_id)
                                       AND TRUNC (
                                               lt_xxpo_line_stg_tbl (j).transaction_date) BETWEEN TRUNC (
                                                                                                      NVL (
                                                                                                          ps.start_date,
                                                                                                          lt_xxpo_line_stg_tbl (
                                                                                                              j).transaction_date))
                                                                                              AND TRUNC (
                                                                                                      NVL (
                                                                                                          ps.end_date,
                                                                                                          lt_xxpo_line_stg_tbl (
                                                                                                              j).transaction_date))
                                       AND ps.adjustment_period_flag = 'N';

                                -- AND ps.closing_status != 'O';
                                IF lc_closing_status != 'O'
                                THEN
                                    lc_phase2   := 'period is not open ';
                                END IF;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    lc_phase2          := 'period is not open ';
                                    lt_xxpo_line_stg_tbl (j).processing_status_code   :=
                                        'REJECTED';
                                    lt_xxpo_line_stg_tbl (j).record_status   :=
                                        gc_invalid;
                                    lc_line_err_flag   := gc_no;
                                    ln_line_flag       := ln_line_flag + 1;
                                    lc_line_error_message   :=
                                           lc_line_error_message
                                        || TO_CHAR (ln_flag)
                                        || '. '
                                        || lc_phase2
                                        || ' ';
                            END;
                        END IF;

                        IF lc_phase2 IS NOT NULL
                        THEN
                            lt_xxpo_line_stg_tbl (j).processing_status_code   :=
                                'REJECTED';
                            lt_xxpo_line_stg_tbl (j).record_status   :=
                                gc_invalid;
                            lc_line_err_flag   := gc_no;
                            ln_line_flag       := ln_line_flag + 1;
                            lc_line_error_message   :=
                                   lc_line_error_message
                                || TO_CHAR (ln_flag)
                                || '. '
                                || lc_phase2
                                || ' ';
                        END IF;

                        --- ship org
                        lc_phase2               :=
                            NULL;
                        ln_locator_id           :=
                            NULL;
                        fnd_file.put_line (fnd_file.LOG,
                                           'ln_torgid' || ln_torgid);

                        IF ln_torgid IS NULL
                        THEN
                            lc_phase2   :=
                                'PO is invalid , organization code can not be NULL ';
                        ELSE
                            BEGIN
                                OPEN cur_get_to_sorgid (ln_torgid);

                                FETCH cur_get_to_sorgid INTO l_sh_code;

                                CLOSE cur_get_to_sorgid;

                                IF l_sh_code IS NULL
                                THEN
                                    lc_phase2   :=
                                           ' organization code is invalid'
                                        || lt_xxpo_line_stg_tbl (j).to_organization_code;
                                END IF;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    lc_phase2   :=
                                           ' organization code is invalid'
                                        || lt_xxpo_line_stg_tbl (j).to_organization_code;
                            END;
                        END IF;

                        lt_xxpo_line_stg_tbl (j).to_organization_code   :=
                            l_sh_code;

                        IF lc_phase2 IS NOT NULL
                        THEN
                            lt_xxpo_line_stg_tbl (j).processing_status_code   :=
                                'REJECTED';
                            lt_xxpo_line_stg_tbl (j).record_status   :=
                                gc_invalid;
                            lc_line_err_flag   := gc_no;
                            ln_line_flag       := ln_line_flag + 1;
                            lc_line_error_message   :=
                                   lc_line_error_message
                                || TO_CHAR (ln_flag)
                                || '. '
                                || lc_phase2
                                || ' ';
                            xxd_common_utils.record_error ('PO RECEIPTS', gn_org_id, 'XXD Receipts Conversion Program', --      SQLCODE,
                                                                                                                        lc_phase, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                                       --    SYSDATE,
                                                                                                                                                                       gn_user_id, gn_conc_request_id, 'INV_ORG', NULL
                                                           , NULL);
                        END IF;

                        lt_xxpo_header_stg_tbl (i).ship_to_organization_id   :=
                            ln_torgid;
                        lt_xxpo_line_stg_tbl (j).requisition_line_id   :=
                            ln_po_lid;
                        lt_xxpo_line_stg_tbl (j).from_organization_id   :=
                            ln_forgid;
                        ln_locator_id           :=
                            NULL;

                        IF lt_xxpo_line_stg_tbl (j).to_organization_code IN
                               ('MC1', 'MC2')
                        THEN
                            lc_subinventory   := 'FACTORY';
                        ELSE
                            lc_subinventory   := 'RECEIVING';
                        END IF;

                        IF lt_xxpo_line_stg_tbl (j).to_organization_code IN
                               ('US2', 'US3')
                        THEN
                            /* SELECT inventory_location_id
                               INTO ln_locator_id
                               FROM mtl_item_locations
                              WHERE organization_id =
                                           lt_xxpo_line_stg_tbl (j).to_organization_id
                                AND subinventory_code = 'RECEIVING'
                                AND segment1 = 'CONV'
                                AND segment2 = 'RECEIVING';*/
                            BEGIN
                                SELECT inventory_location_id
                                  INTO ln_locator_id
                                  FROM mtl_item_locations
                                 WHERE     organization_id =
                                           lt_xxpo_line_stg_tbl (j).to_organization_id
                                       AND subinventory_code = 'RECEIVING'
                                       AND segment1 = 'CONV'
                                       AND segment2 = 'RECEIVING';
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    lt_xxpo_line_stg_tbl (j).processing_status_code   :=
                                        'REJECTED';
                                    lt_xxpo_line_stg_tbl (j).record_status   :=
                                        gc_invalid;
                                    lc_line_err_flag   := gc_no;
                                    ln_flag            := ln_flag + 1;
                                    lc_line_error_message   :=
                                           lc_line_error_message
                                        || TO_CHAR (ln_flag)
                                        || '. '
                                        || 'Locator is Invalid';
                            END;
                        END IF;

                        -- worked for SIT

                        --to get new locator and subinventory value

                        -- locator and subinventory
                        lt_xxpo_line_stg_tbl (j).error_message   :=
                            lc_line_error_message;

                        IF lc_line_err_flag = gc_no
                        THEN
                            lc_line_err_flag2   := lc_line_err_flag;
                        END IF;

                        IF lt_xxpo_line_stg_tbl (j).record_status <>
                           gc_invalid
                        THEN
                            lt_xxpo_line_stg_tbl (j).record_status   :=
                                gc_valid;
                        END IF;

                        IF lc_header_err_flag = gc_no
                        THEN
                            lt_xxpo_line_stg_tbl (j).record_status   :=
                                gc_invalid;
                            lt_xxpo_line_stg_tbl (j).error_message   :=
                                   lc_line_error_message
                                || ' header record has failed validation';
                            lt_xxpo_line_stg_tbl (j).processing_status_code   :=
                                'REJECTED';
                        END IF;

                        --  header marking as invalid even if only one line is invalid
                        IF lc_line_err_flag2 = gc_no
                        -- need to change to lc_line_err_flag2
                        THEN
                            lt_xxpo_header_stg_tbl (i).record_status   :=
                                gc_invalid;
                            lt_xxpo_header_stg_tbl (i).error_message   :=
                                   lc_error_message
                                || ' Child record has failed validation ';
                            lt_xxpo_header_stg_tbl (i).processing_status_code   :=
                                'REJECTED';
                        END IF;

                        /*    FOR m IN 1 .. lt_xxpo_line_stg_tbl.COUNT
                              LOOP
                                 ln_line_cnt := lt_xxpo_line_stg_tbl2.COUNT;
                                 lt_xxpo_line_stg_tbl2 (ln_line_cnt + 1) :=
                                                                    lt_xxpo_line_stg_tbl (m);
                              END LOOP;*/

                        --  END LOOP;
                        --  EXIT WHEN cur_get_line_dtls%NOTFOUND;-- CLOSE cur_get_line_dtls;
                        UPDATE xxd_conv.xxd_ir_rcv_trans_cnv_stg
                           SET record_status = lt_xxpo_line_stg_tbl (j).record_status, processing_status_code = lt_xxpo_line_stg_tbl (j).processing_status_code, error_message = lt_xxpo_line_stg_tbl (j).error_message,
                               last_updated_by = gn_user_id, last_update_login = gn_login_id, org_id = ln_org_id,
                               --lt_xxpo_line_stg_tbl (j).org_id,
                               last_update_date = SYSDATE, ship_to_location_id = lt_xxpo_line_stg_tbl (j).ship_to_location_id, from_organization_id = lt_xxpo_line_stg_tbl (j).from_organization_id,
                               to_organization_id = ln_torgid, -- lt_xxpo_line_stg_tbl (j).to_organization_id,
                                                               operating_unit = NULL, -- lt_xxpo_line_stg_tbl (j).operating_unit,
                                                                                      --  vendor_id = lt_xxpo_line_stg_tbl (j).vendor_id,
                                                                                      -- vendor_site_id =
                                                                                      --          lt_xxpo_line_stg_tbl (j).vendor_site_id,
                                                                                      --   po_header_id = lt_xxpo_line_stg_tbl (j).po_header_id,
                                                                                      requisition_line_id = lt_xxpo_line_stg_tbl (j).requisition_line_id,
                               GROUP_ID = gn_group_id, --lt_xxpo_line_stg_tbl (j).GROUP_ID,
                                                       to_organization_code = NULL, --lt_xxpo_line_stg_tbl (j).to_organization_code,
                                                                                    batch_id = p_batch_id,
                               locator_id = ln_locator_id, deliver_to_person_id = ln_person_id, --ln_agent_id,
                                                                                                -- ln_pid -- is commeneted as taking value from PO
                                                                                                employee_id = ln_agent_id,
                               employee_name = NULL, deliver_to_person_name = NULL, subinventory = lc_subinventory
                         WHERE record_id = lt_xxpo_line_stg_tbl (j).record_id;
                    END LOOP;
                EXCEPTION
                    WHEN ex_no_lines
                    THEN
                        x_retcode   := gc_invalid;               --gc_invalid;
                        x_errbuf    :=
                               'No PO Line records present for PO receipt '
                            || lt_xxpo_header_stg_tbl (i).receipt_num;
                        lt_xxpo_header_stg_tbl (i).record_status   :=
                            x_retcode;
                        lt_xxpo_header_stg_tbl (i).error_message   :=
                            x_errbuf;
                END;

                IF lt_xxpo_header_stg_tbl (i).record_status <> gc_invalid
                THEN
                    lt_xxpo_header_stg_tbl (i).record_status   := gc_valid;
                    lt_xxpo_header_stg_tbl (i).error_message   := NULL;
                END IF;

                UPDATE xxd_conv.xxd_ir_rcv_headers_cnv_stg
                   SET record_status = lt_xxpo_header_stg_tbl (i).record_status, processing_status_code = lt_xxpo_header_stg_tbl (i).processing_status_code, error_message = lt_xxpo_header_stg_tbl (i).error_message,
                       last_updated_by = gn_user_id, last_update_login = gn_login_id, org_id = ln_org_id, --lt_xxpo_header_stg_tbl (i).org_id,
                       last_update_date = SYSDATE, --   vendor_id = lt_xxpo_header_stg_tbl (i).vendor_id,
                                                   --   vendor_site_id = lt_xxpo_header_stg_tbl (i).vendor_site_id,
                                                   operating_unit = NULL, --lt_xxpo_header_stg_tbl (i).operating_unit,
                                                                          ship_to_organization_id = ln_torgid,
                       --   lt_xxpo_header_stg_tbl (i).ship_to_organization_id,
                       employee_id = ln_preparer_id,            --ln_agent_id,
                                                     --lt_xxpo_header_stg_tbl (i).employee_id,   commenting this as taking value from PO
                                                     employee_name = NULL, GROUP_ID = gn_group_id,
                       --lt_xxpo_header_stg_tbl (i).GROUP_ID,
                       ship_to_organization_code = NULL, --  lt_xxpo_header_stg_tbl (i).ship_to_organization_code,
                                                         from_organization_code = NULL, from_organization_id = ln_forgid,
                       batch_id = p_batch_id
                 WHERE record_id = lt_xxpo_header_stg_tbl (i).record_id;

                COMMIT;
            END LOOP;

            EXIT WHEN cur_get_header_dtls%NOTFOUND;
            lt_xxpo_header_stg_tbl.DELETE;
        END LOOP;

        CLOSE cur_get_header_dtls;

        IF lc_retcode <> gn_suc_const
        THEN
            x_retcode   := lc_retcode;
            x_errbuf    :=
                   'Error while updating po header staging table during import: '
                || lc_errbuf;
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_retcode   := gn_err_const;
            x_errbuf    :=
                   'Unknown error from (XXPO_PURCHASE_ORDER_C_PK.validate_data)'
                || lc_rec
                || SQLCODE
                || SQLERRM;

            CLOSE cur_get_header_dtls;
    END validate_data;

    PROCEDURE import (p_batch_id IN NUMBER, p_debug_flag IN VARCHAR2, --     p_grp_s        IN       NUMBER,
                                                                      x_retcode OUT VARCHAR2
                      , x_errbuf OUT VARCHAR2, p_receipt_type IN VARCHAR2)
    IS
        lt_rcv_header_stg_tbl           gt_xxpo_rct_hdr_tbl_type;
        lt_rcv_trx_stg_tbl              gt_xxpo_trxline_stg_tbl_type;
        lt_rcv_trx_stg_tbl2             gt_xxpo_trxline_stg_tbl_type;
        lc_po_number                    po_headers_all.segment1%TYPE;
        ln_serial_number_control_code   NUMBER;
        ln_lot_control_code             NUMBER;
        lc_fm_serial_number             NUMBER;
        lc_to_serial_number             NUMBER;
        gn_location_control_code        NUMBER;
        lc_phase                        VARCHAR2 (80);
        lc_status                       VARCHAR2 (80);
        lc_dev_phase                    VARCHAR2 (30);
        lc_dev_status                   VARCHAR2 (30);
        lc_message                      VARCHAR2 (240);
        ln_request_id                   NUMBER;
        lb_wait                         BOOLEAN;
        ln_header_count_er              NUMBER;
        lc_header_flag                  VARCHAR2 (1);
        lc_retcode                      VARCHAR2 (200);
        lc_header_status                VARCHAR2 (30);
        ln_header_interface_id          NUMBER;
        ln_line_interface_id            NUMBER;
        lc_reject_code                  VARCHAR2 (2000);
        lc_line_flag2                   VARCHAR2 (1);
        lc_line_err_flag                VARCHAR2 (1);
        ln_line_count_er                NUMBER;
        lc_reject_line_code             VARCHAR2 (6000);
        ln_index                        NUMBER := 0;
        ex_line_import                  EXCEPTION;
        lc_line_status                  VARCHAR2 (30);
        lc_line_flag                    VARCHAR2 (1);
        ln_line_cnt                     NUMBER;
        --ln_int_grp_s                    NUMBER;
        ln_int_s                        NUMBER;
        ln_hdr_group_id                 hdr_batch_id_t;
        ln_cntr                         NUMBER;
    BEGIN
        OPEN cur_get_header_dtls (gc_valid, p_batch_id);

        LOOP
            FETCH cur_get_header_dtls
                BULK COLLECT INTO lt_rcv_header_stg_tbl
                LIMIT 1000;

            gd_date      := SYSDATE;
            gd_date_ch   := TO_DATE ('31-MAR-2016', 'DD-MON-YY');

            --  ln_int_grp_s := rcv_interface_groups_s.NEXTVAL;
            --  log_records ('Y', ln_int_grp_s);
            FOR header_v IN 1 .. lt_rcv_header_stg_tbl.COUNT () --cur_get_header_dtls (gc_valid,p_file_identifier)
            LOOP
                BEGIN
                    log_records (
                        p_debug_flag,
                        'header count' || lt_rcv_header_stg_tbl.COUNT);
                    ln_int_s   := rcv_headers_interface_s.NEXTVAL;
                    log_records (p_debug_flag, ln_int_s);

                    IF p_receipt_type IN ('APAC', 'EMEA')
                    THEN
                        gc_auto_transact_code      := 'DELIVER';
                        gc_transaction_t_type      := 'RECEIVE';
                        gc_destination_type_code   := 'INVENTORY';     --NULL;
                        gc_transaction_type        := 'NEW';
                    /*   ELSIF p_receipt_type = 'ASN'
                       THEN
                          gc_auto_transact_code := 'SHIP';
                          gc_transaction_t_type := 'SHIP';
                          gc_transaction_type := 'NEW';
                          gc_destination_type_code := NULL;            --'INVENTORY';
                          lt_rcv_header_stg_tbl (header_v).receipt_num := NULL;
                       ELSIF p_receipt_type = 'ASN_RPT'
                       THEN
                          /*  gc_auto_transact_code := 'DELIVER';
                            --gc_transaction_t_type := 'RECEIVE';
                             gc_transaction_t_type := 'SHIP';
                            gc_destination_type_code := 'INVENTORY';
                            lt_rcv_header_stg_tbl (header_v).asn_type := 'ASN';  --NULL;*/
                                                                    /*
    gc_auto_transact_code := 'DELIVER';            --RECEIVE';
    gc_transaction_t_type := 'RECEIVE';
    lt_rcv_header_stg_tbl (header_v).asn_type := NULL;
    gc_transaction_type := 'NEW';                 -- added this
    gc_destination_type_code := 'INVENTORY';      -- added this
*/
                    END IF;

                    INSERT INTO rcv_headers_interface (
                                    header_interface_id,
                                    GROUP_ID,
                                    --  edi_control_num,
                                    processing_status_code,
                                    receipt_source_code,
                                    asn_type,
                                    transaction_type,
                                    auto_transact_code,
                                    --  test_flag,
                                    last_update_date,
                                    last_updated_by,
                                    last_update_login,
                                    creation_date,
                                    created_by,
                                    notice_creation_date,
                                    shipment_num,
                                    receipt_num,
                                    receipt_header_id,
                                    --        vendor_name,
                                    --       vendor_num,
                                    --          vendor_id,
                                    --          vendor_site_code,
                                    --        vendor_site_id,
                                    from_organization_code,
                                    from_organization_id,
                                    ship_to_organization_code,
                                    ship_to_organization_id,
                                    --    location_code, location_id,
                                    -- bill_of_lading,
                                    -- packing_slip,
                                    shipped_date,
                                    freight_carrier_code,
                                    expected_receipt_date,
                                    receiver_id,
                                    -- num_of_containers,
                                    waybill_airbill_num,
                                    comments,
                                    gross_weight,
                                    gross_weight_uom_code,
                                    net_weight,
                                    net_weight_uom_code,
                                    tar_weight,
                                    tar_weight_uom_code,
                                    packaging_code,
                                    carrier_method,
                                    carrier_equipment,
                                    special_handling_code,
                                    hazard_code,
                                    hazard_class,
                                    hazard_description,
                                    freight_terms,
                                    freight_bill_number,
                                    invoice_num,
                                    invoice_date,
                                    total_invoice_amount,
                                    tax_name,
                                    tax_amount,
                                    freight_amount,
                                    currency_code,
                                    conversion_rate_type,
                                    conversion_rate,
                                    conversion_rate_date,
                                    payment_terms_name,
                                    payment_terms_id,
                                    attribute_category,
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
                                    usggl_transaction_code,
                                    employee_name,
                                    employee_id,
                                    invoice_status_code,
                                    processing_request_id,
                                    customer_account_number,
                                    customer_id,
                                    customer_site_id,
                                    customer_party_name,
                                    remit_to_site_id,
                                    -- operating_unit
                                    org_id,
                                    validation_flag)
                             VALUES (
                                        ln_int_s, --rcv_headers_interface_s.NEXTVAL,
                                        lt_rcv_header_stg_tbl (header_v).GROUP_ID,
                                        -- ln_int_grp_s,
                                        --rcv_interface_groups_s.NEXTVAL,
                                        --  lt_rcv_header_stg_tbl (header_v).edi_control_num,
                                        gc_processing_status_code,
                                        gc_receipt_source_code,        --NULL,
                                        lt_rcv_header_stg_tbl (header_v).asn_type,
                                        'NEW',
                                        --gc_transaction_t_type,                  --'DELIVER',
                                        gc_auto_transact_code,
                                        --commented for ASN
                                        --  lt_rcv_header_stg_tbl (header_v).test_flag,
                                        gd_date,
                                        gn_user_id,
                                        gn_user_id,
                                        gd_date,
                                        gn_user_id,
                                        lt_rcv_header_stg_tbl (header_v).notice_creation_date,
                                        lt_rcv_header_stg_tbl (header_v).shipment_num,
                                        lt_rcv_header_stg_tbl (header_v).receipt_num,
                                        --     lt_rcv_header_stg_tbl (header_v).receipt_num,
                                        lt_rcv_header_stg_tbl (header_v).asn_shipment_header_id,
                                        -- new shipment id
                                        --lt_rcv_header_stg_tbl (header_v).receipt_header_id,
                                        --   lt_rcv_header_stg_tbl (header_v).vendor_name,
                                        --  lt_rcv_header_stg_tbl (header_v).vendor_num,
                                        --  lt_rcv_header_stg_tbl (header_v).vendor_id,
                                        --   lt_rcv_header_stg_tbl (header_v).vendor_site_code,
                                        --    lt_rcv_header_stg_tbl (header_v).vendor_site_id,
                                        lt_rcv_header_stg_tbl (header_v).from_organization_code,
                                        lt_rcv_header_stg_tbl (header_v).from_organization_id,
                                        -- 3/fev/2015    'US3',
                                        lt_rcv_header_stg_tbl (header_v).ship_to_organization_code,
                                        lt_rcv_header_stg_tbl (header_v).ship_to_organization_id,
                                        --   lt_rcv_header_stg_tbl (header_v).location_code, 1,
                                        -- lt_rcv_header_stg_tbl (header_v).ship_to_location_id,
                                        --   lt_rcv_header_stg_tbl (header_v).bill_of_lading,
                                        --   lt_rcv_header_stg_tbl (header_v).packing_slip,
                                        gd_date_ch,
                                        lt_rcv_header_stg_tbl (header_v).freight_carrier_code,
                                        --  NVL (NULL,
                                        --lt_rcv_header_stg_tbl (header_v).expected_receipt_date,
                                        --      SYSDATE + 1                        --gd_date
                                        --               ),
                                        gd_date_ch,
                                        lt_rcv_header_stg_tbl (header_v).receiver_id,
                                        --  lt_rcv_header_stg_tbl (header_v).num_of_containers,
                                        lt_rcv_header_stg_tbl (header_v).waybill_airbill_num,
                                        lt_rcv_header_stg_tbl (header_v).comments,
                                        lt_rcv_header_stg_tbl (header_v).gross_weight,
                                        lt_rcv_header_stg_tbl (header_v).gross_weight_uom_code,
                                        lt_rcv_header_stg_tbl (header_v).net_weight,
                                        lt_rcv_header_stg_tbl (header_v).net_weight_uom_code,
                                        lt_rcv_header_stg_tbl (header_v).tar_weight,
                                        lt_rcv_header_stg_tbl (header_v).tar_weight_uom_code,
                                        lt_rcv_header_stg_tbl (header_v).packaging_code,
                                        lt_rcv_header_stg_tbl (header_v).carrier_method,
                                        lt_rcv_header_stg_tbl (header_v).carrier_equipment,
                                        lt_rcv_header_stg_tbl (header_v).special_handling_code,
                                        lt_rcv_header_stg_tbl (header_v).hazard_code,
                                        lt_rcv_header_stg_tbl (header_v).hazard_class,
                                        lt_rcv_header_stg_tbl (header_v).hazard_description,
                                        lt_rcv_header_stg_tbl (header_v).freight_terms,
                                        lt_rcv_header_stg_tbl (header_v).freight_bill_number,
                                        lt_rcv_header_stg_tbl (header_v).invoice_num,
                                        lt_rcv_header_stg_tbl (header_v).invoice_date,
                                        lt_rcv_header_stg_tbl (header_v).total_invoice_amount,
                                        lt_rcv_header_stg_tbl (header_v).tax_name,
                                        lt_rcv_header_stg_tbl (header_v).tax_amount,
                                        lt_rcv_header_stg_tbl (header_v).freight_amount,
                                        lt_rcv_header_stg_tbl (header_v).currency_code,
                                        lt_rcv_header_stg_tbl (header_v).conversion_rate_type,
                                        lt_rcv_header_stg_tbl (header_v).conversion_rate,
                                        lt_rcv_header_stg_tbl (header_v).conversion_rate_date,
                                        lt_rcv_header_stg_tbl (header_v).payment_terms_name,
                                        lt_rcv_header_stg_tbl (header_v).payment_terms_id,
                                        lt_rcv_header_stg_tbl (header_v).attribute_category,
                                        lt_rcv_header_stg_tbl (header_v).attribute1,
                                        lt_rcv_header_stg_tbl (header_v).attribute2,
                                        lt_rcv_header_stg_tbl (header_v).attribute3,
                                        lt_rcv_header_stg_tbl (header_v).attribute4,
                                        lt_rcv_header_stg_tbl (header_v).attribute5,
                                        lt_rcv_header_stg_tbl (header_v).attribute6,
                                        lt_rcv_header_stg_tbl (header_v).attribute7,
                                        lt_rcv_header_stg_tbl (header_v).attribute8,
                                        lt_rcv_header_stg_tbl (header_v).attribute9,
                                        lt_rcv_header_stg_tbl (header_v).attribute10,
                                        lt_rcv_header_stg_tbl (header_v).attribute11,
                                        --lt_rcv_header_stg_tbl (header_v).attribute12,
                                        lt_rcv_header_stg_tbl (header_v).shipment_header_id,
                                        lt_rcv_header_stg_tbl (header_v).attribute13,
                                        lt_rcv_header_stg_tbl (header_v).record_id,
                                        lt_rcv_header_stg_tbl (header_v).attribute15,
                                        --lt_rcv_header_stg_tbl (header_v).attribute14,
                                        -- lt_rcv_header_stg_tbl (header_v).attribute15,
                                        lt_rcv_header_stg_tbl (header_v).usggl_transaction_code,
                                        -- 3/fev/2015 'Stewart, Celene',
                                        -- 'Stewart, Celene',
                                        lt_rcv_header_stg_tbl (header_v).employee_name,
                                        lt_rcv_header_stg_tbl (header_v).employee_id,
                                        lt_rcv_header_stg_tbl (header_v).invoice_status_code,
                                        lt_rcv_header_stg_tbl (header_v).processing_request_id,
                                        lt_rcv_header_stg_tbl (header_v).customer_account_number,
                                        lt_rcv_header_stg_tbl (header_v).customer_id,
                                        lt_rcv_header_stg_tbl (header_v).customer_site_id,
                                        lt_rcv_header_stg_tbl (header_v).customer_party_name,
                                        lt_rcv_header_stg_tbl (header_v).remit_to_site_id,
                                        -- lt_rcv_header_stg_tbl (header_v).operating_unit
                                        lt_rcv_header_stg_tbl (header_v).org_id,
                                        --'Deckers US OU' --
                                        gc_validation_flag);

                    COMMIT;
                    log_records (p_debug_flag, 'commit done header');
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        x_retcode   := gn_err_const;
                        x_errbuf    :=
                               'Error while inserting into PO receipts Interface table: '
                            || SQLCODE
                            || SQLERRM;
                        log_records (gc_yes, x_errbuf);
                        ROLLBACK;
                END;

                OPEN cur_get_line_dtls --(lt_rcv_header_stg_tbl (header_v).receipt_num,
                                       (
                    lt_rcv_header_stg_tbl (header_v).shipment_header_id,
                    gc_valid);

                --line cursor
                FETCH cur_get_line_dtls BULK COLLECT INTO lt_rcv_trx_stg_tbl;

                CLOSE cur_get_line_dtls;

                --    lt_rcv_trx_stg_tbl.COUNT () := 1;
                FOR line_v IN 1 .. lt_rcv_trx_stg_tbl.COUNT ()
                LOOP
                    BEGIN
                        log_records (
                            p_debug_flag,
                            'line count' || lt_rcv_trx_stg_tbl.COUNT);

                        INSERT INTO rcv_transactions_interface (
                                        interface_transaction_id,
                                        GROUP_ID,
                                        transaction_type,
                                        processing_status_code,
                                        processing_mode_code,
                                        transaction_status_code,
                                        packing_slip,
                                        transaction_date,
                                        quantity,
                                        unit_of_measure,
                                        uom_code,
                                        --   po_header_id,
                                        requisition_line_id,
                                        --    item_id,
                                        item_description,
                                        --    vendor_id,
                                        interface_source_code,
                                        auto_transact_code,
                                        receipt_source_code,
                                        source_document_code,
                                        validation_flag,
                                        header_interface_id,
                                        --    po_line_location_id,
                                        to_organization_id,
                                        -- po_distribution_id,
                                        -- charge_account_id,
                                        --  vendor_site_id,
                                        destination_type_code,
                                        last_updated_by,
                                        created_by,
                                        creation_date,
                                        last_update_date,
                                        last_update_login,
                                        -- deliver_to_location_id,
                                        locator_id,
                                        -- document_num,
                                        -- document_line_num,
                                        --   subinventory,
                                        --    location_id,
                                        employee_id,
                                        ship_to_location_id,
                                        ship_to_location_code,
                                        deliver_to_person_id,
                                        operating_unit,
                                        --  lpn_group_id,
                                        --   transfer_license_plate_number
                                        org_id,
                                        currency_code,
                                        deliver_to_person_name,            --,
                                        -- document_line_num,
                                        subinventory,
                                        attribute_category,
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
                                        ship_line_attribute12,
                                        ship_line_attribute14, --shipment_header_id,
                                        ship_line_attribute15, --shipment_line_id
                                        shipment_header_id,
                                        shipment_line_id)
                                 VALUES (
                                            rcv_transactions_interface_s.NEXTVAL,
                                            lt_rcv_trx_stg_tbl (line_v).GROUP_ID,
                                            --ln_int_grp_s,    --rcv_interface_groups_s.currval,
                                            --'RECEIVE',
                                            gc_transaction_t_type, -- commented for ASN
                                            gc_processing_status_code,
                                            gc_processing_mode_code,
                                            gc_transaction_status_code,
                                            lt_rcv_trx_stg_tbl (line_v).packing_slip,
                                            gd_date_ch,
                                            -- lt_rcv_trx_stg_tbl (line_v).transaction_date,
                                            lt_rcv_trx_stg_tbl (line_v).quantity,
                                            lt_rcv_trx_stg_tbl (line_v).unit_of_measure,
                                            lt_rcv_trx_stg_tbl (line_v).uom_code,
                                            --   lt_rcv_trx_stg_tbl (line_v).po_header_id,
                                            lt_rcv_trx_stg_tbl (line_v).requisition_line_id,
                                            --  lt_rcv_trx_stg_tbl (line_v).item_id,
                                            lt_rcv_trx_stg_tbl (line_v).item_description,
                                            --     lt_rcv_trx_stg_tbl (line_v).vendor_id,
                                            gc_interface_source_code, --'DELIVER',
                                            gc_auto_transact_code, -- uncommented for ASN
                                            gc_receipt_source_code,
                                            gc_source_document_code,
                                            gc_validation_flag,
                                            ln_int_s,
                                            -- rcv_headers_interface_s.NEXTVAL,
                                            --   lt_rcv_trx_stg_tbl (line_v).po_line_location_id,
                                            lt_rcv_trx_stg_tbl (line_v).to_organization_id,
                                            -- lt_rcv_trx_stg_tbl (line_v).po_distribution_id,
                                            --  lt_rcv_trx_stg_tbl (line_v).charge_account_id,
                                            --    lt_rcv_trx_stg_tbl (line_v).vendor_site_id,
                                            gc_destination_type_code,
                                            --  lt_rcv_trx_stg_tbl (line_v).destination_type_code,
                                            gn_user_id,
                                            gn_user_id,
                                            gd_date,
                                            gd_date,
                                            gn_user_id,
                                            -- 3/fev/2015172,
                                            -- lt_rcv_trx_stg_tbl (line_v).ship_to_location_id,
                                            --  select * from hr_locations where location_code='US - DC1 Ventura';
                                            -- lt_rcv_trx_stg_tbl (line_v).ship_to_location_id,
                                            --246669,
                                            lt_rcv_trx_stg_tbl (line_v).locator_id,
                                            --  lt_rcv_trx_stg_tbl (line_v).po_number,
                                            -- lt_rcv_trx_stg_tbl (line_v).segment1,
                                            -- lt_rcv_trx_stg_tbl (line_v).document_line_num,
                                            -- lt_rcv_trx_stg_tbl (line_v).subinventory,
                                            --   76,
                                            lt_rcv_trx_stg_tbl (line_v).employee_id,
                                            lt_rcv_trx_stg_tbl (line_v).ship_to_location_id,
                                            lt_rcv_trx_stg_tbl (line_v).ship_to_location_code,
                                            lt_rcv_trx_stg_tbl (line_v).deliver_to_person_id,
                                            lt_rcv_trx_stg_tbl (line_v).operating_unit,
                                            -- 'Deckers US OU'--
                                            -- xxmi_po_receipts_main_cnv_pk.gn_lpn_group_id,
                                            -- xxmi_po_receipts_main_cnv_pk.gc_lpn_number
                                            -- passing lpn to transfer lpn
                                            -- 3/fev/2015 87,
                                            lt_rcv_trx_stg_tbl (line_v).org_id,
                                            lt_rcv_trx_stg_tbl (line_v).currency_code,
                                            lt_rcv_trx_stg_tbl (line_v).deliver_to_person_name,
                                            --,

                                            -- lt_rcv_trx_stg_tbl (line_v).po_line_num
                                            lt_rcv_trx_stg_tbl (line_v).subinventory,
                                            --'RECEIVING',
                                            lt_rcv_trx_stg_tbl (line_v).attribute_category,
                                            lt_rcv_trx_stg_tbl (line_v).attribute1,
                                            lt_rcv_trx_stg_tbl (line_v).attribute2,
                                            lt_rcv_trx_stg_tbl (line_v).attribute3,
                                            lt_rcv_trx_stg_tbl (line_v).attribute4,
                                            lt_rcv_trx_stg_tbl (line_v).attribute5,
                                            lt_rcv_trx_stg_tbl (line_v).attribute6,
                                            lt_rcv_trx_stg_tbl (line_v).attribute7,
                                            lt_rcv_trx_stg_tbl (line_v).attribute8,
                                            lt_rcv_trx_stg_tbl (line_v).attribute9,
                                            lt_rcv_trx_stg_tbl (line_v).attribute10,
                                            lt_rcv_trx_stg_tbl (line_v).attribute11,
                                            lt_rcv_trx_stg_tbl (line_v).attribute12,
                                            lt_rcv_trx_stg_tbl (line_v).attribute13,
                                            lt_rcv_trx_stg_tbl (line_v).attribute14,
                                            lt_rcv_trx_stg_tbl (line_v).attribute15,
                                            -- lt_rcv_trx_stg_tbl (line_v).attribute14,
                                            --lt_rcv_trx_stg_tbl (line_v).attribute15
                                            lt_rcv_trx_stg_tbl (line_v).record_id,
                                            lt_rcv_trx_stg_tbl (line_v).shipment_header_id,
                                            lt_rcv_trx_stg_tbl (line_v).shipment_line_id,
                                            lt_rcv_trx_stg_tbl (line_v).asn_shipment_header_id,
                                            lt_rcv_trx_stg_tbl (line_v).asn_shipment_line_id);

                        COMMIT;
                        log_records (p_debug_flag,
                                     'commit done for transaction');
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            x_retcode   := gn_err_const;
                            x_errbuf    :=
                                   'Error while inserting into RCV Transaction Interface table: '
                                || SQLCODE
                                || SQLERRM;
                            log_records (gc_yes, x_errbuf);
                            ROLLBACK;
                    --RETURN;  need to check
                    END;

                    log_records (p_debug_flag,
                                 'End of inserting into  tables');
                END LOOP;
            END LOOP;

            EXIT WHEN cur_get_header_dtls%NOTFOUND;

            CLOSE cur_get_header_dtls;
        END LOOP;

        -- updating staging table
        UPDATE xxd_ir_rcv_headers_cnv_stg
           SET record_status   = 'P'
         WHERE record_id IN (SELECT attribute14
                               FROM rcv_headers_interface
                              WHERE processing_status_code = 'PENDING');

        UPDATE xxd_ir_rcv_trans_cnv_stg
           SET record_status   = 'P'
         WHERE record_id IN (SELECT ship_line_attribute12       ---attribute14
                               FROM rcv_transactions_interface
                              WHERE processing_status_code = 'PENDING');

        COMMIT;

        BEGIN
            FOR i IN (SELECT DISTINCT GROUP_ID
                        FROM xxd_ir_rcv_headers_cnv_stg
                       WHERE GROUP_ID IS NOT NULL AND record_status = 'P')
            LOOP
                ln_cntr                     := ln_cntr + 1;
                ln_hdr_group_id (ln_cntr)   := i.GROUP_ID;
            END LOOP;

            COMMIT;
            log_records (p_debug_flag,
                         'group count' || ln_hdr_group_id.COUNT);
        /*
                 IF ln_hdr_group_id.COUNT > 0
                 THEN
                    log_records (p_debug_flag,
                                    'Calling XXDPORECCONVCHILD in batch '
                                 || ln_hdr_group_id.COUNT
                                );

                    FOR i IN ln_hdr_group_id.FIRST .. ln_hdr_group_id.LAST
                    LOOP
                       log_records (p_debug_flag, 'group val' || ln_hdr_group_id (i));

                       SELECT COUNT (*)
                         INTO ln_cntr
                         FROM xxd_ir_rcv_headers_cnv_stg
                        WHERE GROUP_ID = ln_hdr_group_id (i);

                       IF ln_cntr > 0
                       THEN
                          log_records ('Y', 'Group Val' || ln_hdr_group_id (i));
                       /*submit_po_rec_request (
                       p_group_id        => ln_hdr_group_id (i)
                       p_org_id          =>
                       );*/
          /*
      END IF;
   END LOOP;
END IF;*/
        EXCEPTION
            WHEN OTHERS
            THEN
                x_retcode   := gn_err_const;
                x_errbuf    :=
                       'Unknown error from import program)'
                    || SQLCODE
                    || SQLERRM;
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_retcode   := gn_err_const;
            x_errbuf    :=
                'Unknown error fromimport_data)' || SQLCODE || SQLERRM;
    END;

    PROCEDURE main (x_errbuf            OUT VARCHAR2,
                    x_retcode           OUT NUMBER,
                    p_action_type    IN     VARCHAR2,
                    p_batch_cnt      IN     NUMBER,
                    p_debug_flag     IN     VARCHAR2,
                    p_receipt_type   IN     VARCHAR2)
    IS
        lc_errbuf                VARCHAR2 (6000);
        lc_retcode               VARCHAR2 (6000);
        lc_load_retcode          VARCHAR2 (600);
        lc_valid_retcode         VARCHAR2 (600);
        lc_all_errbuf            VARCHAR2 (6000);
        ln_valid_rec_cnt         NUMBER := 0;
        ln_cntr                  NUMBER := 0;
        ln_request_id            NUMBER := 0;
        lc_phase                 VARCHAR2 (2000);
        lc_status                VARCHAR2 (2000);
        lc_dev_phase             VARCHAR2 (2000);
        lc_dev_status            VARCHAR2 (2000);
        lc_message               VARCHAR2 (2000);
        lb_wait                  BOOLEAN;
        lc_header_flag           VARCHAR2 (1);
        lc_line_flag             VARCHAR2 (1);
        ln_header_count_er       NUMBER;
        ln_line_count_er         NUMBER;
        lt_rcv_header_stg_tbl    gt_xxpo_rct_hdr_tbl_type;
        lt_rcv_trx_stg_tbl       gt_xxpo_trxline_stg_tbl_type;
        lt_rcv_trx_stg_tbl2      gt_xxpo_trxline_stg_tbl_type;
        --   lc_header_status         VARCHAR2 (30);
        ln_header_interface_id   NUMBER;
        ln_line_interface_id     NUMBER;
        lc_reject_code           VARCHAR2 (2000);
        ex_line_import           EXCEPTION;
        lc_line_status           VARCHAR2 (30);
        lc_header_status         VARCHAR2 (30);
        lc_reject_line_code      VARCHAR2 (6000);
        ln_line_cnt              NUMBER;
        l_min                    NUMBER;
        l_max                    NUMBER;
        ln_cntr_gr               NUMBER := 0;
        ln_hdr_group_id          hdr_batch_id_t;
        ln_hdr_org_id            hdr_batch_id_t;
        ln_cntr_org              NUMBER := 0;
        ln_row_count             NUMBER := 0;
        lc_error_message         VARCHAR2 (2000);
    BEGIN
        log_records (p_debug_flag, 'Start Main');
        log_records (p_debug_flag, 'Action Type :' || p_action_type);
        lc_retcode   := gn_suc_const;

        IF p_action_type = gc_extract
        THEN
            -- Calling extract_recpts_1206_records procedure if p_action_type is EXTRACT
            log_records (p_debug_flag, 'Calling Load Program');
            truncte_stage_tables (x_ret_code      => lc_retcode,
                                  x_return_mesg   => lc_errbuf);
            extract_recpts_1206_records (p_debug_flag => p_debug_flag, x_ret_code => lc_retcode, x_return_mesg => lc_errbuf
                                         , p_receipt_type => p_receipt_type);
            log_records (p_debug_flag, 'Return error code :' || lc_retcode);
            log_records (p_debug_flag, 'Return error message :' || lc_errbuf);

            IF lc_retcode = gc_warning
            THEN
                x_retcode   := gn_warn_const;
                x_errbuf    := lc_errbuf;
            ELSIF lc_retcode = gc_error
            THEN
                x_retcode   := gn_err_const;
                x_errbuf    := lc_errbuf;
                RETURN;
            END IF;

            log_records (p_debug_flag, 'b4' || ln_hdr_batch_id.COUNT);
        ELSIF p_action_type = gc_validate
        THEN
            UPDATE xxd_ir_rcv_headers_cnv_stg
               SET batch_id = NULL, record_status = gc_new, processing_status_code = 'PENDING',
                   error_message = NULL;

            UPDATE xxd_ir_rcv_trans_cnv_stg
               SET batch_id = NULL, record_status = gc_new, processing_status_code = 'PENDING',
                   error_message = NULL;

            SELECT COUNT (*)
              INTO ln_valid_rec_cnt
              FROM xxd_ir_rcv_headers_cnv_stg
             WHERE batch_id IS NULL AND record_status IN (gc_new, gc_invalid);

            log_records (
                p_debug_flag,
                'Creating Batch id and update  xxd_ir_rcv_headers_cnv_stg');

            -- Create batches of records and assign batch id
            FOR i IN 1 .. p_batch_cnt
            LOOP
                SELECT xxd_po_receipt_batch_stg_s.NEXTVAL
                  INTO ln_hdr_batch_id (i)
                  FROM DUAL;

                log_records (p_debug_flag,
                             ' ln_valid_rec_cnt := ' || ln_valid_rec_cnt);
                log_records (
                    p_debug_flag,
                       'ceil( ln_valid_rec_cnt/p_batch_cnt) := '
                    || CEIL (ln_valid_rec_cnt / p_batch_cnt));

                UPDATE xxd_ir_rcv_headers_cnv_stg
                   SET batch_id = ln_hdr_batch_id (i), request_id = gn_request_id
                 WHERE     batch_id IS NULL
                       AND ROWNUM <= CEIL (ln_valid_rec_cnt / p_batch_cnt)
                       AND record_status IN (gc_new, gc_invalid);
            END LOOP;

            log_records (
                p_debug_flag,
                'completed updating Batch id in  xxd_ir_rcv_headers_cnv_stg');
        ELSIF p_action_type = gc_load
        THEN
            log_records (
                p_debug_flag,
                'Fetching batch id from xxd_ir_rcv_headers_cnv_stg stage to call worker process');

            --ln_cntr := 0;

            /*              SELECT min(batch_id),max(batch_id)
                            into l_min,l_max
                            FROM xxd_ir_rcv_headers_cnv_stg
                           WHERE batch_id IS NOT NULL
                             AND RECORD_STATUS = gc_validate;

                   FOR i IN 43 .. 44*/
            FOR i
                IN (SELECT DISTINCT batch_id
                      FROM xxd_ir_rcv_headers_cnv_stg
                     WHERE batch_id IS NOT NULL AND record_status = gc_valid)
            LOOP
                ln_cntr                     := ln_cntr + 1;
                ln_hdr_batch_id (ln_cntr)   := i.batch_id;
            END LOOP;
        END IF;

        COMMIT;

        -- log_records (p_debug_flag, 'here' || ln_hdr_batch_id.COUNT);
        IF ln_hdr_batch_id.COUNT > 0
        THEN
            log_records (
                p_debug_flag,
                'Calling XXDPORECCONVCHILD in batch ' || ln_hdr_batch_id.COUNT);

            FOR i IN ln_hdr_batch_id.FIRST .. ln_hdr_batch_id.LAST
            LOOP
                log_records (p_debug_flag,
                             'batch val' || ln_hdr_batch_id (i));

                SELECT COUNT (*)
                  INTO ln_cntr
                  FROM xxd_ir_rcv_headers_cnv_stg
                 WHERE batch_id = ln_hdr_batch_id (i);

                IF ln_cntr > 0
                THEN
                    BEGIN
                        log_records (
                            p_debug_flag,
                               'Calling Worker process for batch id ln_hdr_batch_id(i) := '
                            || ln_hdr_batch_id (i));
                        ln_request_id   :=
                            apps.fnd_request.submit_request (
                                gc_xxdo,
                                'XXD_IR_RECEIPTS_CNV_WRK',
                                -- 'XXDPORECCONVCHILD',
                                '',
                                '',
                                FALSE,
                                p_debug_flag,
                                p_action_type,
                                ln_hdr_batch_id (i),
                                gn_request_id,
                                p_receipt_type);
                        log_records (p_debug_flag,
                                     'v_request_id := ' || ln_request_id);

                        IF ln_request_id > 0
                        THEN
                            l_req_id (i)   := ln_request_id;
                            COMMIT;
                        ELSE
                            ROLLBACK;
                        END IF;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            lc_retcode   := 2;
                            lc_errbuf    := lc_errbuf || SQLERRM;
                            log_records (
                                p_debug_flag,
                                   'Calling WAIT FOR REQUEST XXDPORECCONVCHILD error'
                                || SQLERRM);
                        WHEN OTHERS
                        THEN
                            lc_retcode   := 2;
                            lc_errbuf    := lc_errbuf || SQLERRM;
                            log_records (
                                p_debug_flag,
                                   'Calling WAIT FOR REQUEST XXDPORECCONVCHILD error'
                                || SQLERRM);
                    END;
                END IF;
            END LOOP;

            log_records (
                p_debug_flag,
                'Calling XXDPORECCONVCHILD in batch ' || ln_hdr_batch_id.COUNT);
            log_records (
                p_debug_flag,
                'Calling WAIT FOR REQUEST XXDPORECCONVCHILD to complete');

            IF l_req_id.COUNT > 0
            THEN
                FOR rec IN l_req_id.FIRST .. l_req_id.LAST
                LOOP
                    IF l_req_id (rec) IS NOT NULL
                    THEN
                        LOOP
                            lc_dev_phase    := NULL;
                            lc_dev_status   := NULL;
                            lb_wait         :=
                                fnd_concurrent.wait_for_request (
                                    request_id   => l_req_id (rec)--ln_concurrent_request_id
                                                                  ,
                                    INTERVAL     => 1,
                                    max_wait     => 1,
                                    phase        => lc_phase,
                                    status       => lc_status,
                                    dev_phase    => lc_dev_phase,
                                    dev_status   => lc_dev_status,
                                    MESSAGE      => lc_message);

                            IF ((UPPER (lc_dev_phase) = 'COMPLETE') OR (UPPER (lc_phase) = 'COMPLETED'))
                            THEN
                                EXIT;
                            END IF;
                        END LOOP;
                    END IF;
                END LOOP;
            END IF;
        END IF;

        IF p_action_type = 'SUBMIT'
        THEN
            log_records (p_debug_flag, 'Standard Import Program');

            --ln_cntr := 0;

            /*              SELECT min(batch_id),max(batch_id)
                            into l_min,l_max
                            FROM xxd_ir_rcv_headers_cnv_stg
                           WHERE batch_id IS NOT NULL
                             AND RECORD_STATUS = gc_validate;

                   FOR i IN 43 .. 44*/
            FOR i IN (SELECT DISTINCT GROUP_ID
                        FROM xxd_ir_rcv_headers_cnv_stg
                       WHERE record_status = 'P')
            LOOP
                ln_cntr_gr                     := ln_cntr_gr + 1;
                ln_hdr_group_id (ln_cntr_gr)   := i.GROUP_ID;
            END LOOP;

            log_records (p_debug_flag, 'Calling STD Import in batch ');

            IF ln_hdr_group_id.COUNT > 0
            THEN
                log_records (
                    p_debug_flag,
                    'Calling STD Import in batch ' || ln_hdr_group_id.COUNT);

                FOR i IN ln_hdr_group_id.FIRST .. ln_hdr_group_id.LAST
                LOOP
                    log_records (p_debug_flag,
                                 'group_id val' || ln_hdr_group_id (i));

                    SELECT COUNT (*)
                      INTO ln_cntr
                      FROM xxd_ir_rcv_headers_cnv_stg
                     WHERE GROUP_ID = ln_hdr_group_id (i);

                    IF ln_cntr > 0
                    THEN
                        log_records (
                            p_debug_flag,
                               'Calling Standard import program ln_hdr_group_id(i) := '
                            || ln_hdr_group_id (i));
                        ln_cntr_org   := 0;

                        FOR j
                            IN (SELECT DISTINCT org_id
                                  FROM xxd_ir_rcv_headers_cnv_stg
                                 WHERE     record_status = 'P'
                                       AND GROUP_ID = ln_hdr_group_id (i))
                        LOOP
                            ln_cntr_org                   := ln_cntr_org + 1;
                            ln_hdr_org_id (ln_cntr_org)   := j.org_id;
                        END LOOP;

                        IF ln_hdr_org_id.COUNT > 0
                        THEN
                            log_records (
                                p_debug_flag,
                                   'Calling STD Import in batch '
                                || ln_hdr_org_id.COUNT);

                            FOR j IN ln_hdr_org_id.FIRST ..
                                     ln_hdr_org_id.LAST
                            LOOP
                                log_records (
                                    p_debug_flag,
                                    'org_id val' || ln_hdr_org_id (j));

                                SELECT COUNT (*)
                                  INTO ln_cntr_org
                                  FROM xxd_ir_rcv_headers_cnv_stg
                                 WHERE     record_status = 'P'
                                       AND org_id = ln_hdr_org_id (j);

                                IF ln_cntr_org > 0
                                THEN
                                    /*  BEGIN
                                         log_records
                                            (p_debug_flag,
                                                'Calling Standard import program ln_hdr_org_id(j) := '
                                             || ln_hdr_org_id (j)
                                            );
                                         submit_po_rec_request (ln_hdr_group_id (i),
                                                                ln_hdr_org_id (j)
                                                               );
                                      EXCEPTION
                                         WHEN OTHERS
                                         THEN
                                            lc_retcode := 2;
                                            lc_errbuf := lc_errbuf || SQLERRM;
                                            log_records
                                               (p_debug_flag,
                                                   'Calling WAIT FOR REQUEST STD Import error'
                                                || SQLERRM
                                               );
                                      END;*/
                                    BEGIN
                                        fnd_request.set_org_id (
                                            ln_hdr_org_id (j));
                                        ln_request_id   :=
                                            fnd_request.submit_request (
                                                application   => 'PO',
                                                program       => 'RVCTP',
                                                description   => NULL,
                                                start_time    => NULL,
                                                sub_request   => FALSE,
                                                argument1     => 'BATCH',
                                                argument2     =>
                                                    ln_hdr_group_id (i),
                                                argument3     =>
                                                    ln_hdr_org_id (j));
                                        COMMIT;

                                        IF ln_request_id > 0
                                        THEN
                                            l_req_id (i)   := ln_request_id;
                                            COMMIT;
                                        ELSE
                                            ROLLBACK;
                                        END IF;
                                    END;
                                END IF;
                            END LOOP;
                        END IF;
                    END IF;
                END LOOP;

                IF l_req_id.COUNT > 0
                THEN
                    FOR rec IN l_req_id.FIRST .. l_req_id.LAST
                    LOOP
                        IF l_req_id (rec) IS NOT NULL
                        THEN
                            LOOP
                                lc_dev_phase    := NULL;
                                lc_dev_status   := NULL;
                                lb_wait         :=
                                    fnd_concurrent.wait_for_request (
                                        request_id   => l_req_id (rec)--ln_concurrent_request_id
                                                                      ,
                                        INTERVAL     => 1,
                                        max_wait     => 1,
                                        phase        => lc_phase,
                                        status       => lc_status,
                                        dev_phase    => lc_dev_phase,
                                        dev_status   => lc_dev_status,
                                        MESSAGE      => lc_message);

                                IF ((UPPER (lc_dev_phase) = 'COMPLETE') OR (UPPER (lc_phase) = 'COMPLETED'))
                                THEN
                                    EXIT;
                                END IF;
                            END LOOP;
                        END IF;
                    END LOOP;
                END IF;
            END IF;

            log_records (p_debug_flag, 'Finish main');

            OPEN cur_get_header_error_dtls;

            LOOP
                FETCH cur_get_header_error_dtls
                    BULK COLLECT INTO lt_rcv_header_stg_tbl
                    LIMIT 1000;

                --CLOSE cur_get_header_error_dtls;
                ln_row_count   := lt_rcv_header_stg_tbl.COUNT ();
                log_records (
                    p_debug_flag,
                    'Number of new PO receipt records: ' || ln_row_count);

                FOR i IN 1 .. ln_row_count
                LOOP
                    --Validating organization_name
                    lc_phase           := NULL;
                    --   log_records (p_debug_flag, 'here1');
                    lc_error_message   := NULL;
                    lc_phase           := NULL;

                    BEGIN
                        lc_header_status         := NULL;
                        lc_reject_code           := NULL;
                        ln_header_interface_id   := NULL;

                        SELECT processing_status_code, header_interface_id
                          INTO lc_header_status, ln_header_interface_id
                          FROM (  SELECT phi.processing_status_code, phi.header_interface_id
                                    FROM rcv_headers_interface phi
                                   WHERE     phi.receipt_num =
                                             lt_rcv_header_stg_tbl (i).receipt_num
                                         AND phi.attribute14 =
                                             lt_rcv_header_stg_tbl (i).record_id
                                ORDER BY 2 DESC)
                         WHERE ROWNUM = 1;

                        IF lc_header_status = 'ERROR'
                        THEN
                            BEGIN
                                FOR i
                                    IN cur_get_error (ln_header_interface_id)
                                LOOP
                                    lc_reject_code   :=
                                           i.error_message
                                        || ' '
                                        || lc_reject_code;
                                END LOOP;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    x_retcode   := gn_err_const;
                                    x_errbuf    :=
                                           ' Error while fetching RCV interface error table for header'
                                        || SQLCODE
                                        || SQLERRM;
                            END;

                            lt_rcv_header_stg_tbl (i).record_status   := 'E';
                            lt_rcv_header_stg_tbl (i).error_message   :=
                                lc_reject_code;
                        END IF;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            NULL;
                    END;

                    UPDATE xxd_ir_rcv_headers_cnv_stg
                       SET record_status = 'E', error_message = lc_reject_code
                     WHERE record_id = lt_rcv_header_stg_tbl (i).record_id;
                END LOOP;

                EXIT WHEN cur_get_header_error_dtls%NOTFOUND;

                CLOSE cur_get_header_error_dtls;
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_retcode   := gn_err_const;
            x_errbuf    :=
                   'Unknown error from (XXPO_PO_RECEIPT_C_PK.main)'
                || SQLCODE
                || SQLERRM;
    END main;

    PROCEDURE open_po_child (x_errbuf OUT VARCHAR2, x_retcode OUT VARCHAR2, p_debug_flag IN VARCHAR2 DEFAULT 'N', p_action IN VARCHAR2, p_batch_id IN NUMBER, p_parent_request_id IN NUMBER
                             , p_receipt_type IN VARCHAR2)
    AS
        le_invalid_param         EXCEPTION;
        -- ln_new_ou_id             hr_operating_units.organization_id%TYPE;
        --:= fnd_profile.value('ORG_ID');
        -- This is required in release 12 R12
        ln_request_id            NUMBER := 0;
        lc_username              fnd_user.user_name%TYPE;
        lc_operating_unit        hr_operating_units.NAME%TYPE;
        lc_cust_num              VARCHAR2 (5);
        lc_pri_flag              VARCHAR2 (1);
        ld_start_date            DATE;
        ln_ins                   NUMBER := 0;
        lc_phase                 VARCHAR2 (200);
        lc_delc_phase            VARCHAR2 (200);
        lc_delc_status           VARCHAR2 (200);
        lc_message               VARCHAR2 (200);
        lc_retcode               VARCHAR2 (1000);
        lc_errbuf                VARCHAR2 (1000);
        ln_count                 NUMBER;
        ln_submit_openpo         VARCHAR2 (50);
        lc_status                VARCHAR2 (80);
        lc_dev_phase             VARCHAR2 (30);
        lc_dev_status            VARCHAR2 (30);
        lc_header_flag           VARCHAR2 (1);
        lc_line_flag             VARCHAR2 (1);
        ln_header_count_er       NUMBER;
        ln_line_count_er         NUMBER;
        lb_wait                  BOOLEAN;
        lt_rcv_header_stg_tbl    gt_xxpo_rct_hdr_tbl_type;
        lt_rcv_trx_stg_tbl       gt_xxpo_trxline_stg_tbl_type;
        lt_rcv_trx_stg_tbl2      gt_xxpo_trxline_stg_tbl_type;
        lc_header_status         VARCHAR2 (30);
        ln_header_interface_id   NUMBER;
        ln_line_interface_id     NUMBER;
        lc_reject_code           VARCHAR2 (2000);
        ex_line_import           EXCEPTION;
        lc_line_status           VARCHAR2 (30);
        lc_reject_line_code      VARCHAR2 (6000);
        ln_line_cnt              NUMBER;
        ln_int_grp_s             NUMBER;
    BEGIN
        --g_err_tbl_type.delete;
        BEGIN
            SELECT user_name
              INTO lc_username
              FROM fnd_user
             WHERE user_id = fnd_global.user_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_username   := NULL;
        END;

        BEGIN
            SELECT NAME
              INTO lc_operating_unit
              FROM hr_operating_units
             WHERE organization_id = fnd_profile.VALUE ('ORG_ID');
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_operating_unit   := NULL;
        END;

        IF p_action = gc_validate
        THEN
            log_records (p_debug_flag, 'Calling validate_receipt :');
            validate_data (p_batch_id       => p_batch_id,
                           p_debug_flag     => p_debug_flag,
                           x_retcode        => lc_retcode,
                           x_errbuf         => lc_errbuf,
                           p_receipt_type   => p_receipt_type);
            log_records (p_debug_flag, 'Return error code :' || lc_retcode);
            log_records (p_debug_flag, 'Return error message :' || lc_errbuf);
        ELSIF p_action = gc_load
        THEN
            log_records (p_debug_flag, 'Calling transfer_receipt_records :');
            log_records (p_debug_flag, 'Calling Import Program');
            --ln_int_grp_s := rcv_interface_groups_s.NEXTVAL;
            import (p_batch_id => p_batch_id, p_debug_flag => p_debug_flag, --  p_grp_s           => ln_int_grp_s,
                                                                            x_retcode => lc_retcode
                    , x_errbuf => lc_errbuf, p_receipt_type => p_receipt_type);
            log_records (p_debug_flag, 'Return error code :' || lc_retcode);
            log_records (p_debug_flag, 'Return error message :' || lc_errbuf);

            IF lc_retcode = gc_warning
            THEN
                x_retcode   := gn_warn_const;
                x_errbuf    := lc_errbuf;
            ELSIF lc_retcode = gc_error
            THEN
                x_retcode   := gn_err_const;
                x_errbuf    := lc_errbuf;
                RETURN;
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (p_debug_flag,
                         'Exception Raised During open_po_child  Program');
            lc_retcode   := gn_err_const;
            lc_errbuf    := lc_errbuf || SQLERRM;
    END open_po_child;
END xxd_po_ir_receipt_c_pkg;
/
