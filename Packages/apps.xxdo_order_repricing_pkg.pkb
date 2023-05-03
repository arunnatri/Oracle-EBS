--
-- XXDO_ORDER_REPRICING_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:13 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_ORDER_REPRICING_PKG"
AS
    g_request_id   NUMBER := fnd_global.conc_request_id;

    PROCEDURE POPULATE_REPRICE_STG (
        p_out_chr_ret_message      OUT NOCOPY VARCHAR2,
        p_out_num_ret_status       OUT NOCOPY NUMBER,
        pn_org_id                             NUMBER,
        pn_cust_acct_id                       NUMBER,
        pv_from_ord_no                        VARCHAR2,
        pv_to_ord_no                          VARCHAR2,
        pd_from_req_dt                        VARCHAR2,
        pd_to_req_dt                          VARCHAR2,
        -- pd_from_schdl_dt VARCHAR2,--Commented By Infosys for PRB0040923
        --  pd_to_schdl_dt   VARCHAR2,--Commented By Infosys for PRB0040923
        pn_order_src_id                       NUMBER,
        pn_brand                              VARCHAR2,
        pn_no_of_workers                      NUMBER --Added by Infosys on 14-Nov-2016
                                                    )
    AS
        l_batch_id           NUMBER;
        l_parent_req_id      NUMBER := g_request_id;
        l_child_req_id       NUMBER;
        l_no_of_workers      NUMBER := pn_no_of_workers;
        l_batch_size         NUMBER := 0;
        l_status_code        VARCHAR2 (30) := 'IN PROCESS';
        l_error_message      VARCHAR2 (30) := NULL;
        l_insert_count       NUMBER := 0;



        TYPE conc_ids IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        conc                 conc_ids;
        phase                VARCHAR2 (240);
        status               VARCHAR2 (240);
        dev_phase            VARCHAR2 (240);
        dev_status           VARCHAR2 (240);
        MESSAGE              VARCHAR2 (240);
        req_status           BOOLEAN;


        CURSOR c_order_header IS
            SELECT ord.header_id,
                   ord.org_id,
                   ord.order_number,
                   ord.attribute5 brand,
                   (SELECT COUNT (1)
                      FROM apps.oe_order_lines_all line
                     WHERE line.header_id = ord.header_id) lines_count,
                   (SELECT oos.name
                      FROM apps.oe_order_sources oos
                     WHERE oos.order_source_id = ord.order_source_id) order_source
              FROM apps.oe_order_headers_all ord
             WHERE     (   (    EXISTS
                                    (SELECT 1
                                       FROM apps.oe_order_lines_all line
                                      WHERE     ord.header_id =
                                                line.header_id
                                            AND ord.org_id = line.org_id
                                            AND line.request_date BETWEEN NVL (
                                                                              fnd_date.canonical_to_date (
                                                                                  pd_from_req_dt),
                                                                                SYSDATE
                                                                              - 5)
                                                                      AND NVL (
                                                                              fnd_date.canonical_to_date (
                                                                                  pd_to_req_dt),
                                                                                SYSDATE
                                                                              + 5)-- AND TRUNC(line.schedule_ship_date) BETWEEN NVL(fnd_date.canonical_to_date(pd_from_schdl_dt),SYSDATE-5) AND NVL(fnd_date.canonical_to_date(pd_to_schdl_dt), SYSDATE+5)
                                                                                  )
                            AND (pv_from_ord_no IS NULL AND pv_to_ord_no IS NULL))
                        OR (pv_from_ord_no IS NOT NULL AND pv_to_ord_no IS NOT NULL))
                   AND ord.org_id = pn_org_id
                   AND ord.order_source_id =
                       NVL (pn_order_src_id, ord.order_source_id)
                   AND ord.sold_to_org_id =
                       NVL (pn_cust_acct_id, ord.sold_to_org_id)
                   AND ord.Order_number BETWEEN NVL (pv_from_ord_no,
                                                     ord.Order_number)
                                            AND NVL (pv_to_ord_no,
                                                     ord.Order_number)
                   AND ord.attribute5 = NVL (pn_brand, ord.attribute5)
                   AND ord.open_flag = 'Y'
                   AND EXISTS
                           (SELECT 1
                              FROM apps.oe_order_lines_all line
                             WHERE     ord.header_id = line.header_id
                                   AND ord.org_id = line.org_id
                                   AND line.flow_status_code NOT IN
                                           ('CLOSED', 'CANCELLED'));

        TYPE c_order_header_row IS TABLE OF c_order_header%ROWTYPE;

        l_order_header_row   c_order_header_row;

        v_count              NUMBER := 0;
    BEGIN
        fnd_global.apps_initialize (user_id        => FND_GLOBAL.USER_ID,
                                    resp_id        => FND_GLOBAL.RESP_ID,
                                    resp_appl_id   => FND_GLOBAL.RESP_APPL_ID);
        mo_global.set_policy_context ('S', pn_org_id);
        mo_global.init ('ONT');

        FND_FILE.put_line (FND_FILE.LOG,
                           'Starting Procedure:POPULATE_REPRICE_STG');

        BEGIN
            FND_FILE.put_line (FND_FILE.LOG,
                               'START PURGING XXD_BATCH_REPRICING_STG :');

            DELETE FROM
                APPS.XXD_BATCH_REPRICING_STG
                  WHERE     STATUS_CODE = 'PROCESSED'
                        AND TRUNC (CREATION_DATE) < TRUNC (SYSDATE - 90);

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_num_ret_status   := 1;
                p_out_chr_ret_message   :=
                       'ERROR WHILE PURGING XXD_BATCH_REPRICING_STG : '
                    || ' -ERROR : '
                    || SQLERRM;
                FND_FILE.put_line (
                    FND_FILE.LOG,
                    'ERROR WHILE PURGING XXD_BATCH_REPRICING_STG :');
        END;

        --IF (l_process_status = 'ALL') THEN

        SELECT COUNT (1)
          INTO l_insert_count
          FROM apps.oe_order_headers_all ord
         WHERE     (   (    EXISTS
                                (SELECT 1
                                   FROM apps.oe_order_lines_all line
                                  WHERE     ord.header_id = line.header_id
                                        AND ord.org_id = line.org_id
                                        AND line.request_date BETWEEN NVL (
                                                                          fnd_date.canonical_to_date (
                                                                              pd_from_req_dt),
                                                                            SYSDATE
                                                                          - 5)
                                                                  AND NVL (
                                                                          fnd_date.canonical_to_date (
                                                                              pd_to_req_dt),
                                                                            SYSDATE
                                                                          + 5)-- AND TRUNC(line.schedule_ship_date) BETWEEN NVL(fnd_date.canonical_to_date(pd_from_schdl_dt),SYSDATE-5) AND NVL(fnd_date.canonical_to_date(pd_to_schdl_dt), SYSDATE+5)
                                                                              )
                        AND (pv_from_ord_no IS NULL AND pv_to_ord_no IS NULL))
                    OR (pv_from_ord_no IS NOT NULL AND pv_to_ord_no IS NOT NULL))
               AND ord.org_id = pn_org_id
               AND ord.order_source_id =
                   NVL (pn_order_src_id, ord.order_source_id)
               AND ord.sold_to_org_id =
                   NVL (pn_cust_acct_id, ord.sold_to_org_id)
               AND ord.Order_number BETWEEN NVL (pv_from_ord_no,
                                                 ord.Order_number)
                                        AND NVL (pv_to_ord_no,
                                                 ord.Order_number)
               AND ord.attribute5 = NVL (pn_brand, ord.attribute5)
               AND ord.open_flag = 'Y'
               AND EXISTS
                       (SELECT 1
                          FROM apps.oe_order_lines_all line
                         WHERE     ord.header_id = line.header_id
                               AND ord.org_id = line.org_id
                               AND line.flow_status_code NOT IN
                                       ('CLOSED', 'CANCELLED'));

        FND_FILE.put_line (FND_FILE.LOG,
                           'l_insert_count :' || l_insert_count);


        FND_FILE.put_line (FND_FILE.LOG,
                           'Total no of rows fetched : ' || l_insert_count);

        BEGIN
            IF (l_insert_count > 0)
            THEN
                l_batch_size   := CEIL (l_insert_count / l_no_of_workers);

                FND_FILE.PUT_LINE (FND_FILE.LOG,
                                   'Batch size - ' || l_batch_size);
            ELSE
                RETURN;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_num_ret_status   := 1;
                p_out_chr_ret_message   :=
                       'ERROR WHILE MAKING BATCHES : '
                    || ' -ERROR : '
                    || SQLERRM;
        END;



        FOR indx IN c_order_header
        LOOP
            BEGIN
                IF v_count = 0
                THEN
                    l_batch_id   := xxd_batch_reprice_seq.NEXTVAL; --v_count 0 indicates new batch
                END IF;

                v_count   := v_count + 1; --Increment v_count by 1 after insertion

                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                    'v_count after incrementing : ' || v_count);



                FND_FILE.PUT_LINE (FND_FILE.LOG, 'Before Insert ');

                INSERT INTO APPS.XXD_BATCH_REPRICING_STG (BATCH_ID, PARENT_REQUEST_ID, CHILD_REQUEST_ID, HEADER_ID, ORG_ID, ORDER_NUMBER, NO_OF_LINES, BRAND, ORDER_SOURCE, CREATION_DATE, CREATED_BY, LAST_UPDATE_DATE, LAST_UPDATED_BY, LAST_UPDATE_LOGIN, STATUS_CODE
                                                          , ERROR_MESSAGE)
                     VALUES (l_batch_id, l_parent_req_id, l_child_req_id,
                             indx.header_id, indx.org_id, indx.order_number,
                             indx.lines_count, indx.brand, indx.order_source,
                             SYSDATE, fnd_global.user_id, SYSDATE,
                             fnd_global.user_id, fnd_global.login_id, l_status_code
                             , l_error_message);
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_out_num_ret_status   := 1;
                    p_out_chr_ret_message   :=
                           'Unexpected Error while inserting : '
                        || '-Error : '
                        || SQLERRM;
                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                        'Inside  Insert Exception: ' || SQLERRM);
            END;


            IF (v_count >= l_batch_size) --If no of records inserted reaches batch size then reset v_count to zero
            THEN
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                    'Setting v_count to zero for batch ID next val generation : ');
                v_count   := 0;
                COMMIT;
            END IF;
        END LOOP;                                      -- insert for indx loop

        FND_FILE.PUT_LINE (FND_FILE.LOG,
                           'Parent Request Id: ' || g_request_id);



        FOR i IN (SELECT DISTINCT batch_id, PARENT_REQUEST_ID
                    FROM APPS.XXD_BATCH_REPRICING_STG
                   WHERE PARENT_REQUEST_ID = g_request_id)
        LOOP
            --FND_FILE.PUT_LINE (FND_FILE.LOG,'Batch ID- '||i.batch_id);
            BEGIN
                l_child_req_id          := NULL;

                l_child_req_id          :=
                    fnd_request.submit_request (
                        application   => 'XXDO',
                        program       => 'XXDO_REPRICE_ORDERS_IN_BATCHES',
                        description   => NULL,
                        start_time    => NULL,
                        sub_request   => FALSE,
                        argument1     => i.parent_request_id,
                        argument2     => i.batch_id,
                        argument3     => 'ALL');

                conc (l_child_req_id)   := l_child_req_id;

                COMMIT;

                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                    'Batch Repricing program submitted for the batch : ' || i.batch_id);

                UPDATE APPS.XXD_BATCH_REPRICING_STG
                   SET CHILD_REQUEST_ID   = conc (l_child_req_id)
                 WHERE     BATCH_ID = i.batch_id
                       AND PARENT_REQUEST_ID = i.parent_request_id;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_out_num_ret_status   := 1;
                    p_out_chr_ret_message   :=
                           'UNEXPECTED ERROR OCCURRED WHILE TRIGGERING BATCH REPRICING PROGRAM: '
                        || ' ERROR : '
                        || SQLERRM;
            END;
        END LOOP;

        /*FOR i IN 1..conc.count
        LOOP
  req_status :=
                 fnd_concurrent.wait_for_request (conc (i),
                                                  10,
                                                  0,
                                                  phase,
                                                  status,
                                                  dev_phase,
                                                  dev_status,
                                                  MESSAGE);
            COMMIT;

           END LOOP;*/

        BEGIN
            l_child_req_id   := NVL (conc.FIRST, 0);

            WHILE l_child_req_id <> 0
            LOOP
                req_status       :=
                    fnd_concurrent.wait_for_request (
                        request_id   => l_child_req_id,
                        INTERVAL     => 10,
                        max_wait     => 0,
                        phase        => phase,
                        status       => status,
                        dev_phase    => dev_phase,
                        dev_status   => dev_status,
                        MESSAGE      => MESSAGE);
                COMMIT;
                l_child_req_id   := NVL (conc.NEXT (l_child_req_id), 0);
            END LOOP;
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_num_ret_status   := 2;
            p_out_chr_ret_message   :=
                'Unexpected Error in POPULATE_REPRICE_STG: ' || SQLERRM;
    END POPULATE_REPRICE_STG;



    PROCEDURE REPRICE_ORDER (P_ERR_BUFF OUT NOCOPY VARCHAR2, P_RET_CODE OUT NOCOPY NUMBER, p_parent_req_id NUMBER
                             , p_batch_id NUMBER, p_process_status VARCHAR2)
    AS
        v_api_version_number       NUMBER := 1;
        v_init_msg_list            VARCHAR2 (30) := FND_API.G_FALSE;
        v_return_values            VARCHAR2 (30) := FND_API.G_FALSE;
        v_action_commit            VARCHAR2 (30) := FND_API.G_FALSE;

        v_line_tab                 oe_order_pub.line_tbl_type;
        x_line_tab                 oe_order_pub.line_tbl_type;
        v_Line_Adj_tbl             oe_order_pub.Line_Adj_Tbl_Type;
        v_Header_Adj_tbl           oe_order_pub.Header_Adj_Tbl_Type;
        x_return_status            VARCHAR2 (10);
        x_msg_count                NUMBER;
        x_msg_data                 VARCHAR2 (2000);
        v_oe_msg_data              VARCHAR2 (2000);

        x_header_rec               oe_order_pub.Header_Rec_Type;
        x_header_val_rec           oe_order_pub.Header_Val_Rec_Type;
        x_Header_price_Att_tbl     oe_order_pub.Header_Price_Att_Tbl_Type;
        x_Header_Adj_val_tbl       oe_order_pub.Header_Adj_Val_Tbl_Type;
        x_Header_Adj_Att_tbl       oe_order_pub.Header_Adj_Att_Tbl_Type;
        x_Header_Adj_Assoc_tbl     oe_order_pub.Header_Adj_Assoc_Tbl_Type;
        x_Header_Scredit_tbl       oe_order_pub.Header_Scredit_Tbl_Type;
        x_Header_Scredit_val_tbl   oe_order_pub.Header_Scredit_Val_Tbl_Type;
        x_line_tbl                 oe_order_pub.Line_Tbl_Type;
        x_line_val_tbl             oe_order_pub.Line_Val_Tbl_Type;
        x_Line_Adj_tbl             oe_order_pub.Line_Adj_Tbl_Type;
        x_Line_Adj_val_tbl         oe_order_pub.Line_Adj_Val_Tbl_Type;
        x_Line_price_Att_tbl       oe_order_pub.Line_Price_Att_Tbl_Type;
        x_Line_Adj_Att_tbl         oe_order_pub.Line_Adj_Att_Tbl_Type;
        x_Line_Adj_Assoc_tbl       oe_order_pub.Line_Adj_Assoc_Tbl_Type;
        x_Line_Scredit_tbl         oe_order_pub.Line_Scredit_Tbl_Type;
        x_Line_Scredit_val_tbl     oe_order_pub.Line_Scredit_Val_Tbl_Type;
        x_Lot_Serial_tbl           oe_order_pub.Lot_Serial_Tbl_Type;
        x_Lot_Serial_val_tbl       oe_order_pub.Lot_Serial_Val_Tbl_Type;
        v_action_request_tbl       oe_order_pub.request_tbl_type;
        v_action_request_tbl_out   oe_order_pub.request_tbl_type;

        CURSOR c_reprice_orders IS
            SELECT XBR.header_id, XBR.org_id, XBR.order_number
              FROM apps.XXD_BATCH_REPRICING_STG XBR
             WHERE     XBR.batch_id = p_batch_id
                   AND XBR.PARENT_REQUEST_ID = p_parent_req_id
                   -- and XBR.status_code =decode(p_process_status,'ALL','IN PROCESS','ERROR');
                   AND ((p_process_status = 'ALL' AND XBR.status_code IN ('IN PROCESS', 'ERROR')) --If process_status is 'ALL',then pick 'IN PROCESS' and 'ERROR' records
                                                                                                  OR (p_process_status = 'ERROR' AND XBR.status_code = 'ERROR')) --If process_status is 'ERROR',then pick only 'ERROR' records
                   AND XBR.status_code NOT IN 'PROCESSED'; --In all cases ignore 'PROCESSED' records
    BEGIN
        fnd_global.apps_initialize (user_id        => FND_GLOBAL.USER_ID,
                                    resp_id        => FND_GLOBAL.RESP_ID,
                                    resp_appl_id   => FND_GLOBAL.RESP_APPL_ID);

        -- mo_global.set_policy_context ('S', pn_org_id);
        mo_global.init ('ONT');
        FND_FILE.put_line (FND_FILE.LOG, 'Starting Procedure');
        fnd_file.put_line (
            fnd_file.LOG,
            'At :' || TO_CHAR (SYSDATE, 'MM/DD/YYYY HH:MI:SS AM'));



        FOR rec_reprice IN c_reprice_orders
        LOOP
            BEGIN                          -- Added by Infosys for PRB0040923.
                v_action_request_tbl (1)             := oe_order_pub.g_miss_request_rec;
                v_action_request_tbl (1).entity_id   := rec_reprice.header_id;
                v_action_request_tbl (1).entity_code   :=
                    oe_globals.G_ENTITY_HEADER;
                v_action_request_tbl (1).request_type   :=
                    oe_globals.G_PRICE_ORDER;

                UPDATE apps.XXD_BATCH_REPRICING_STG
                   SET START_PROCESS_TIME = TO_CHAR (SYSDATE, 'MM/DD/YYYY HH:MI:SS AM')
                 WHERE     BATCH_ID = p_batch_id
                       AND PARENT_REQUEST_ID = p_parent_req_id
                       AND ORDER_NUMBER = rec_reprice.order_number;


                oe_order_pub.Process_Order (
                    p_org_id                   => rec_reprice.org_id,
                    p_operating_unit           => NULL,
                    p_api_version_number       => v_api_version_number,
                    p_init_msg_list            => v_init_msg_list,
                    p_return_values            => v_return_values,
                    p_action_commit            => v_action_commit,
                    x_return_status            => x_return_status,
                    x_msg_count                => x_msg_count,
                    x_msg_data                 => x_msg_data,
                    p_line_tbl                 => v_line_tab,
                    p_line_adj_tbl             => v_Line_Adj_tbl,
                    p_action_request_tbl       => v_action_request_tbl,
                    x_header_rec               => x_header_rec,
                    x_header_val_rec           => x_header_val_rec,
                    x_Header_Adj_tbl           => v_Header_Adj_tbl,
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
                    x_action_request_tbl       => v_action_request_tbl_out);



                IF x_return_status != FND_API.G_RET_STS_SUCCESS
                THEN
                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                           'Order Number - '
                        || rec_reprice.order_number
                        || 'has issues while repricing'
                        || 'x_return_status'
                        || x_return_status);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'At :' || TO_CHAR (SYSDATE, 'MM/DD/YYYY HH:MI:SS AM'));

                    FOR i IN 1 .. x_msg_count
                    LOOP
                        v_oe_msg_data   :=
                            oe_msg_pub.get (p_msg_index => i, p_encoded => 'F');
                        FND_FILE.PUT_LINE (FND_FILE.LOG, v_oe_msg_data);
                    END LOOP;

                    UPDATE apps.XXD_BATCH_REPRICING_STG
                       SET STATUS_CODE = 'ERROR', ERROR_MESSAGE = SUBSTR (v_oe_msg_data, 1, 4000), END_PROCESS_TIME = TO_CHAR (SYSDATE, 'MM/DD/YYYY HH:MI:SS AM')
                     WHERE     BATCH_ID = p_batch_id
                           AND PARENT_REQUEST_ID = p_parent_req_id
                           AND ORDER_NUMBER = rec_reprice.order_number;

                    COMMIT;

                    ROLLBACK;
                ELSE
                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                           'Order Number - '
                        || rec_reprice.order_number
                        || 'has been repriced sucessfully'
                        || 'x_return_status'
                        || x_return_status);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'At :' || TO_CHAR (SYSDATE, 'MM/DD/YYYY HH:MI:SS AM'));


                    UPDATE apps.XXD_BATCH_REPRICING_STG
                       SET STATUS_CODE = 'PROCESSED', END_PROCESS_TIME = TO_CHAR (SYSDATE, 'MM/DD/YYYY HH:MI:SS AM')
                     WHERE     BATCH_ID = p_batch_id
                           AND PARENT_REQUEST_ID = p_parent_req_id
                           AND ORDER_NUMBER = rec_reprice.order_number;

                    COMMIT;

                    fnd_file.put_line (fnd_file.LOG, 'After Update');
                END IF;
            -- BEGIN : Added by Infosys for PRB0040923.
            EXCEPTION
                WHEN OTHERS
                THEN
                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                        'Order Number - ' || rec_reprice.order_number || '.');
                    fnd_file.put_line (fnd_file.LOG,
                                       'SQL Error Code :' || SQLCODE);

                    fnd_file.put_line (fnd_file.LOG,
                                       'SQL Error Message :' || SQLERRM);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'At :' || TO_CHAR (SYSDATE, 'MM/DD/YYYY HH:MI:SS AM'));

                    p_ret_code   := 1;                               --warning
                    p_err_buff   := 'Unexpected Error : ' || SQLERRM;

                    UPDATE apps.XXD_BATCH_REPRICING_STG
                       SET STATUS_CODE = 'ERROR', ERROR_MESSAGE = SUBSTR (v_oe_msg_data, 1, 4000), END_PROCESS_TIME = TO_CHAR (SYSDATE, 'MM/DD/YYYY HH:MI:SS AM')
                     WHERE     BATCH_ID = p_batch_id
                           AND PARENT_REQUEST_ID = p_parent_req_id
                           AND ORDER_NUMBER = rec_reprice.order_number;

                    COMMIT;
            END;
        -- END : Added by Infosys for PRB0040923.

        END LOOP;
    -- BEGIN : Added by Infosys for PRB0040923.
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'SQL Error Code : ' || SQLCODE);

            fnd_file.put_line (fnd_file.LOG,
                               'SQL Error Message : ' || SQLERRM);
            fnd_file.put_line (
                fnd_file.LOG,
                'At :' || TO_CHAR (SYSDATE, 'MM/DD/YYYY HH:MI:SS AM'));
    -- END : Added by Infosys for PRB0040923.
    END REPRICE_ORDER;
END XXDO_ORDER_REPRICING_PKG;
/
