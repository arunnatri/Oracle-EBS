--
-- XXDOEC_PRODUCT_CUSTOMIZATION  (Package Body) 
--
/* Formatted on 4/26/2023 4:40:52 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOEC_PRODUCT_CUSTOMIZATION"
AS
    PROCEDURE insert_ship_confimation (p_order_id            IN     VARCHAR2,
                                       p_currency_code       IN     VARCHAR2,
                                       p_carrier             IN     VARCHAR2,
                                       p_service_level       IN     VARCHAR2,
                                       p_waybill             IN     VARCHAR2,
                                       p_tracking_number     IN     VARCHAR2,
                                       p_status              IN     VARCHAR2,
                                       p_shipped_date        IN     DATE,
                                       p_fluid_recipe_id     IN     VARCHAR2,
                                       p_order_line_number   IN     NUMBER,
                                       p_item_code           IN     VARCHAR2,
                                       p_shipped_quantity    IN     NUMBER,
                                       p_unit_price          IN     NUMBER,
                                       p_item_description    IN     VARCHAR2,
                                       p_sender_id           IN     VARCHAR2,
                                       p_retCode                OUT NUMBER,
                                       p_errBuf                 OUT VARCHAR2)
    IS
        ln_shipment_id   NUMBER;
        l_dummy          NUMBER;

        CURSOR c_dup_check IS
            SELECT shipment_id
              FROM xxdo.xxdoec_cp_shipment_dtls_stg
             WHERE     order_id = p_order_id
                   AND fluid_recipe_id = p_fluid_recipe_id;
    BEGIN
        OPEN c_dup_check;

        FETCH c_dup_check INTO l_dummy;

        IF c_dup_check%FOUND
        THEN
            CLOSE c_dup_check;

            p_retcode   := 1;
            p_errbuf    :=
                   'Duplicate Shipment Record. Order ID: '
                || p_order_id
                || ' Recipe ID: '
                || p_fluid_recipe_id;
        ELSE
            CLOSE c_dup_check;

            -- Insert Shipment record
            SELECT xxdo.xxdoec_cp_shipment_dtls_stg_s.NEXTVAL
              INTO ln_shipment_id
              FROM DUAL;

            INSERT INTO xxdo.xxdoec_cp_shipment_dtls_stg (shipment_id, order_id, currency_code, carrier, service_level, waybill, tracking_number, status, shipped_date, fluid_recipe_id, order_line_number, item_code, shipped_quantity, unit_price, item_description
                                                          , sender_id)
                 VALUES (ln_shipment_id, p_order_id, p_currency_code,
                         p_carrier, p_service_level, p_waybill,
                         p_tracking_number, p_status, p_shipped_date,
                         p_fluid_recipe_id, p_order_line_number, p_item_code,
                         p_shipped_quantity, p_unit_price, p_item_description
                         , p_sender_id);

            p_errbuf    := '';
            p_retcode   := 0;
        --    COMMIT;
        END IF;                                             -- duplicate check
    EXCEPTION
        WHEN OTHERS
        THEN
            p_retcode   := 1;
            p_errbuf    := 'Unexpected Error occured ' || SQLERRM;

            ROLLBACK;
    END;

    PROCEDURE insert_ship_confimation_bulk (p_shipment_data_tbl IN xxdoec_product_customization.shipment_rec_tbl_type, p_retCode OUT NUMBER, p_errBuf OUT VARCHAR2)
    IS
        ln_shipment_id   NUMBER;
    BEGIN
        FOR i IN p_shipment_data_tbl.FIRST .. p_shipment_data_tbl.LAST
        LOOP
            SELECT xxdo.xxdoec_cp_shipment_dtls_stg_s.NEXTVAL
              INTO ln_shipment_id
              FROM DUAL;

            INSERT INTO xxdo.xxdoec_cp_shipment_dtls_stg (shipment_id, order_id, currency_code, carrier, service_level, waybill, tracking_number, status, shipped_date, fluid_recipe_id, order_line_number, item_code, shipped_quantity, unit_price, item_description
                                                          , sender_id)
                 VALUES (ln_shipment_id, p_shipment_data_tbl (i).order_id, p_shipment_data_tbl (i).currency_code, p_shipment_data_tbl (i).carrier, p_shipment_data_tbl (i).service_level, p_shipment_data_tbl (i).waybill, p_shipment_data_tbl (i).tracking_number, p_shipment_data_tbl (i).status, p_shipment_data_tbl (i).shipped_date, p_shipment_data_tbl (i).fluid_recipe_id, p_shipment_data_tbl (i).order_line_number, p_shipment_data_tbl (i).item_code, p_shipment_data_tbl (i).shipped_quantity, p_shipment_data_tbl (i).unit_price, p_shipment_data_tbl (i).item_description
                         , p_shipment_data_tbl (i).sender_id);
        END LOOP;

        p_errbuf    := '';
        p_retcode   := 0;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_retcode   := 1;
            p_errbuf    := 'Unexpected Error occured ' || SQLERRM;
            ROLLBACK;
    END;

    PROCEDURE update_ship_conf_status (p_shipment_id       IN     NUMBER,
                                       p_tracking_number   IN     VARCHAR2,
                                       p_status            IN     VARCHAR2,
                                       p_retCode              OUT NUMBER,
                                       p_errBuf               OUT VARCHAR2)
    IS
    BEGIN
        IF p_shipment_id IS NULL
        THEN
            UPDATE xxdo.xxdoec_cp_shipment_dtls_stg
               SET so_ship_confirm_flag   = 'R'
             WHERE tracking_number = p_tracking_number;
        ELSE
            UPDATE xxdo.xxdoec_cp_shipment_dtls_stg
               SET so_ship_confirm_flag   = 'R'
             WHERE shipment_id = p_shipment_id;
        END IF;
    END;

    PROCEDURE insert_invoice_data (
        p_sender_id              IN     VARCHAR2,
        p_invoice_number         IN     VARCHAR2,
        p_invoice_date           IN     DATE,
        p_invoice_currency       IN     VARCHAR2,
        p_period_start_date      IN     DATE,
        p_period_end_date        IN     DATE,
        p_total_units_shipped    IN     NUMBER,
        p_total_invoice_amount   IN     NUMBER,
        p_invoice_data_tbl       IN     xxdoec_product_customization.invoice_rec_tbl_type,
        p_retCode                   OUT NUMBER,
        p_errBuf                    OUT VARCHAR2)
    IS
        -- Declare, initialize internal variables
        ln_invoice_id          NUMBER;
        ln_invoice_dtl_id      NUMBER;
        ln_invoice_dtl_count   NUMBER := 0;
        ln_debug               NUMBER := 0;
        ln_rc                  NUMBER := 0;

        -- Set up the log object
        dcdlog                 dcdlog_type
            := dcdlog_type (p_code => -30001, p_application => g_application, p_logeventtype => 2
                            , p_tracelevel => 1, p_debug => ln_debug);
    BEGIN
        -- Initialize output parameters
        p_retCode   := 0;
        p_errBuf    := '';

        BEGIN
            SELECT xxdoec_factory_invoices_stg_s.NEXTVAL
              INTO ln_invoice_id
              FROM DUAL;

            -- Insert the invoice header record
            INSERT INTO xxdo.xxdoec_factory_invoices_stg (
                            invoice_id,
                            sender_id,
                            invoice_number,
                            invoice_date,
                            invoice_currency,
                            period_start_date,
                            period_end_date,
                            total_units_shipped,
                            total_invoice_amount)
                     VALUES (ln_invoice_id,
                             p_sender_id,
                             p_invoice_number,
                             p_invoice_date,
                             p_invoice_currency,
                             p_period_start_date,
                             p_period_end_date,
                             p_total_units_shipped,
                             p_total_invoice_amount);

            -- Log the invoice header insert result
            dcdlog.addparameter ('Start time',
                                 CURRENT_TIMESTAMP,
                                 'TIMESTAMP');
            dcdlog.addparameter ('Invoice_id', ln_invoice_id, 'NUMBER');
            ln_rc   := dcdlog.LogInsert ();
        --COMMIT;

        EXCEPTION
            WHEN OTHERS
            THEN
                p_retcode   := 1;
                p_errbuf    := 'Unexpected Error occured ' || SQLERRM;
                -- Log errors for invoice header insert
                dcdlog.changecode (p_code => -30002, p_application => g_application, p_logeventtype => 1
                                   , p_tracelevel => 1, p_debug => ln_debug);
                dcdlog.addparameter ('Invoice Id', ln_invoice_id, 'VARCHAR2');
                dcdlog.addparameter ('Error message', p_errbuf, 'VARCHAR2');
                ln_rc       := dcdlog.LogInsert ();
                ROLLBACK;
        END;

        IF p_retcode <> 1
        THEN
            BEGIN
                -- Reset output parameters
                p_retCode   := 0;
                p_errBuf    := '';

                FOR i IN p_invoice_data_tbl.FIRST .. p_invoice_data_tbl.LAST
                LOOP
                    SELECT xxdoec_factory_inv_dtls_stg_s.NEXTVAL
                      INTO ln_invoice_dtl_id
                      FROM DUAL;

                    -- Insert the invoice details
                    INSERT INTO xxdo.xxdoec_factory_inv_dtls_stg (
                                    invoice_detail_id,
                                    invoice_id,
                                    order_id,
                                    fluid_recipe_id,
                                    order_line_number,
                                    actual_shipment_date,
                                    awb_number,
                                    tracking_number,
                                    item_upc,
                                    item_code,
                                    item_description,
                                    quantity,
                                    unit_cost)
                         VALUES (ln_invoice_dtl_id, ln_invoice_id, p_invoice_data_tbl (i).order_id, p_invoice_data_tbl (i).fluid_recipe_id, p_invoice_data_tbl (i).order_line_number, p_invoice_data_tbl (i).actual_shipment_date, p_invoice_data_tbl (i).awb_number, p_invoice_data_tbl (i).tracking_number, p_invoice_data_tbl (i).item_upc, p_invoice_data_tbl (i).item_code, p_invoice_data_tbl (i).item_description, p_invoice_data_tbl (i).quantity
                                 , p_invoice_data_tbl (i).unit_cost);

                    ln_invoice_dtl_count   := ln_invoice_dtl_count + 1;
                END LOOP;

                -- Log the count of inserted invoice detail records
                dcdlog.changecode (p_code => -30001, p_application => g_application, p_logeventtype => 2
                                   , p_tracelevel => 1, p_debug => ln_debug);
                dcdlog.addparameter ('Inserted invoice detail count',
                                     ln_invoice_dtl_count,
                                     'NUMBER');
                ln_rc       := dcdlog.LogInsert ();
            -- COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_retcode   := 1;
                    p_errbuf    := 'Unexpected Error occured ' || SQLERRM;
                    dcdlog.changecode (p_code           => -30002,
                                       p_application    => g_application,
                                       p_logeventtype   => 1,
                                       p_tracelevel     => 1,
                                       p_debug          => ln_debug);
                    dcdlog.addparameter ('Error message',
                                         p_errbuf,
                                         'VARCHAR2');
                    dcdlog.addparameter ('Invoice Id',
                                         ln_invoice_id,
                                         'VARCHAR2');
                    ln_rc       := dcdlog.LogInsert ();
                    ROLLBACK;
            END;
        END IF;
    END;
END xxdoec_product_customization;
/


--
-- XXDOEC_PRODUCT_CUSTOMIZATION  (Synonym) 
--
CREATE OR REPLACE SYNONYM SOA_INT.XXDOEC_PRODUCT_CUSTOMIZATION FOR APPS.XXDOEC_PRODUCT_CUSTOMIZATION
/


GRANT EXECUTE ON APPS.XXDOEC_PRODUCT_CUSTOMIZATION TO SOA_INT
/
