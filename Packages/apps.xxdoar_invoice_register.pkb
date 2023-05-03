--
-- XXDOAR_INVOICE_REGISTER  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:16 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOAR_INVOICE_REGISTER"
AS
    /*
    REM $HEADER: xxdoar_invoice_register.PKB 1.0 18-JUN-2014 $
    REM ===================================================================================================
    REM             (C) COPYRIGHT DECKERS OUTDOOR CORPORATION
    REM                       ALL RIGHTS RESERVED
    REM ===================================================================================================
    REM
    REM NAME          : xxdoar_invoice_register.PKB
    REM
    REM PROCEDURE     :
    REM SPECIAL NOTES :
    REM
    REM PROCEDURE     :
    REM SPECIAL NOTES :
    REM
    REM         CR #  :
    REM ===================================================================================================
    REM HISTORY:  CREATION DATE :27-JUN-2014, CREATED BY : Srinath Siricilla
    REM
    REM MODIFICATION HISTORY
    REM PERSON                  DATE              VERSION              COMMENTS AND CHANGES MADE
    REM -------------------    ----------         ----------           ------------------------------------
    REM INFOSYS                07-SEP-17          1.1                 Modified for CCR0006538
    REM Madhav Dhurjaty        05-OCT-17          1.2                 Modified update_payment_term for CCR0006649
    REM Kranthi Bollam         04-Dec-2017        1.3                 Modified update_payment_term for CCR0006692
    REM                                                               to update Print Option and Printing Pending
    REM                                                               columns in RA_CUSTOMER_TRX_ALL
    REM ===================================================================================================
    */
    PROCEDURE update_factored_flag (errbuff                OUT VARCHAR2,
                                    retcode                OUT VARCHAR2,
                                    p_org_id            IN     NUMBER,
                                    p_order_header_id   IN     VARCHAR2,
                                    p_factored_flag     IN     CHAR)
    IS
        l_order_number   apps.oe_order_headers_all.order_number%TYPE;
    BEGIN
        SELECT order_number
          INTO l_order_number
          FROM apps.oe_order_headers_all
         WHERE header_id = p_order_header_id;

        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG, 'p_org_id = ' || p_org_id);
        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                'p_order_number = ' || l_order_number);
        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                'p_factored_flag = ' || p_factored_flag);

        UPDATE apps.oe_order_headers_all
           SET attribute13   = p_factored_flag
         WHERE header_id = p_order_header_id AND org_id = p_org_id;

        COMMIT;
        APPS.FND_FILE.PUT_LINE (
            APPS.FND_FILE.LOG,
            'Updated the factored flag for the Order# ' || l_order_number);
    EXCEPTION
        WHEN OTHERS
        THEN
            retcode   := 1;
            errbuff   :=
                'There is an unexpected error occured while processing your request.';
            APPS.FND_FILE.PUT_LINE (
                APPS.FND_FILE.LOG,
                'There is an unexpected error occured while processing your request.');
    END update_factored_flag;

    PROCEDURE update_payment_term (errbuff OUT VARCHAR2, retcode OUT VARCHAR2, p_account_number IN VARCHAR2, p_sales_order IN VARCHAR2, p_trx_id IN VARCHAR2, p_old_term_id IN NUMBER
                                   , p_term_id IN NUMBER)
    IS
        CURSOR c_transaction_number IS
            SELECT rcta.trx_number
              FROM ra_customer_trx_all rcta, RA_CUSTOMERS RC, ar_payment_schedules_all apsa
             WHERE     Apsa.Customer_Trx_Id = Rcta.Customer_Trx_Id
                   AND RC.CUSTOMER_ID = RCTA.SOLD_TO_CUSTOMER_ID
                   AND RC.CUSTOMER_NUMBER = p_account_number
                   AND apsa.class = 'INV'
                   AND apsa.status = 'OP'
                   AND rcta.interface_header_attribute1 =
                       NVL (p_sales_order, rcta.interface_header_attribute1)
                   AND Rcta.Customer_Trx_Id =
                       NVL (p_trx_id, rcta.Customer_Trx_Id)
                   --    AND rcta.Batch_Source_Id in (SELECT distinct Batch_Source_Id FROM RA_BATCH_SOURCES_ALL rbsa where name like '%Order Management%')  --Commented as a part of INC0364321
                   AND rcta.Customer_Trx_Id IN
                           (SELECT Customer_Trx_Id
                              FROM ra_customer_trx_lines_all
                             WHERE interface_line_context = 'ORDER ENTRY')
                   AND rcta.org_id = Mo_Global.Get_Current_Org_Id;

        --v_trx_date DATE;
        due_days       NUMBER;
        l_trx_number   apps.ra_customer_trx_all.trx_number%TYPE;
        l_org_id       apps.ra_customer_trx_all.org_id%TYPE;
    BEGIN
        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                'Account Number = ' || p_account_number);
        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                'Sales Order = ' || p_sales_order);
        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                'Invoice Number = ' || p_trx_id);
        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                'Old Payment Term = ' || p_old_term_id);
        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                'p_term_id = ' || p_term_id);

        IF p_old_term_id IS NULL
        THEN
            APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG, 'old term id is null');

            IF p_sales_order IS NULL AND p_trx_id IS NULL
            THEN
                /* SELECT DISTINCT org_id
                INTO l_org_id
                FROM ra_customer_trx_all rcta ,
                RA_CUSTOMERS RC
                WHERE RC.CUSTOMER_ID   = RCTA.BILL_TO_CUSTOMER_ID
                AND RC.customer_number = p_account_number;
                */
                l_org_id   := mo_global.get_current_org_id;

                BEGIN
                    SELECT due_days
                      INTO due_days
                      FROM apps.ra_terms_lines
                     WHERE relative_amount = 100 AND term_id = p_term_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        retcode   := 1;
                        errbuff   := 'There is no data for this Term.';
                        APPS.FND_FILE.PUT_LINE (
                            APPS.FND_FILE.LOG,
                            'There is no data for this Term.');
                    WHEN OTHERS
                    THEN
                        retcode   := 1;
                        errbuff   :=
                            'There is an unexpected error occured while getting due days for the Term.';
                        APPS.FND_FILE.PUT_LINE (
                            APPS.FND_FILE.LOG,
                            'There is an unexpected error occured while getting due days for the Term.');
                END;

                APPS.FND_FILE.PUT_LINE (
                    APPS.FND_FILE.LOG,
                    'sysdate:' || SYSDATE || ' User ID:' || FND_GLOBAL.USER_ID);

                UPDATE apps.ra_customer_trx_all
                   SET term_id = p_term_id, term_due_date = trx_date + due_days, last_update_date = SYSDATE, --Added for CCR0006649
                       last_updated_by = FND_GLOBAL.USER_ID --Added for CCR0006649
                                                           , printing_option = 'PRI' --Added for CCR0006692
                                                                                    , printing_pending = 'Y' --Added for CCR0006692
                 WHERE     bill_to_customer_id =
                           (SELECT customer_id
                              FROM ra_customers
                             WHERE customer_number = p_account_number)
                       AND Customer_Trx_Id IN
                               (SELECT Customer_Trx_Id
                                  FROM apps.ar_payment_schedules_all
                                 WHERE class = 'INV' AND status = 'OP')
                       --         AND Batch_Source_Id in (SELECT distinct Batch_Source_Id FROM RA_BATCH_SOURCES_ALL where name like '%Order Management%')    --Commented as a part of INC0364321
                       AND Customer_Trx_Id IN
                               (SELECT Customer_Trx_Id
                                  FROM ra_customer_trx_lines_all
                                 WHERE interface_line_context = 'ORDER ENTRY')
                       AND org_id = Mo_Global.Get_Current_Org_Id;

                UPDATE apps.ar_payment_schedules_all
                   SET term_id = p_term_id, due_date = trx_date + due_days, last_update_date = SYSDATE, --Added for CCR0006649
                       last_updated_by = FND_GLOBAL.USER_ID --Added for CCR0006649
                 WHERE     class = 'INV'
                       AND status = 'OP'
                       AND customer_id =
                           (SELECT customer_id
                              FROM ra_customers
                             WHERE customer_number = p_account_number)
                       --        AND Customer_Trx_Id in (select Customer_Trx_Id from ra_customer_trx_all where Batch_Source_Id in (SELECT distinct Batch_Source_Id FROM RA_BATCH_SOURCES_ALL where name like '%Order Management%'))    --Commented as a part of INC0364321
                       AND Customer_Trx_Id IN
                               (SELECT Customer_Trx_Id
                                  FROM ra_customer_trx_lines_all
                                 WHERE interface_line_context = 'ORDER ENTRY')
                       AND org_id = Mo_Global.Get_Current_Org_Id;

                IF SQL%ROWCOUNT > 0
                THEN
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        LPAD ('Update AR Invoice Payment Term - Deckers',
                              60,
                              ' '));
                    APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT, '');
                    APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT,
                                            'Org ID = ' || l_org_id);
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        'Account Number = ' || p_account_number);
                    --APPS.FND_FILE.PUT_LINE(APPS.FND_FILE.OUTPUT, 'p_sales_order = ' || p_sales_order);
                    --APPS.FND_FILE.PUT_LINE(APPS.FND_FILE.OUTPUT, 'Invoice Number = ' || l_trx_number);
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        'New Payment Term = ' || p_term_id);
                    APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT, '');
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        'Invoice Number  ' || LPAD ('Update Status', 15, ' '));

                    FOR l_trx_num IN c_transaction_number
                    LOOP
                        APPS.FND_FILE.PUT_LINE (
                            APPS.FND_FILE.OUTPUT,
                            l_trx_num.trx_number || LPAD ('Updated', 15, ' '));
                    END LOOP;
                ELSE
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.LOG,
                        'Account Number = ' || p_account_number);
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.LOG,
                        'p_sales_order = ' || p_sales_order);
                    --APPS.FND_FILE.PUT_LINE(APPS.FND_FILE.LOG, 'Invoice Number = ' || l_trx_number);
                    APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                            'p_term_id = ' || p_term_id);
                END IF;

                COMMIT;
                APPS.FND_FILE.PUT_LINE (
                    APPS.FND_FILE.LOG,
                    'Updated the Term for the Customer# ' || p_account_number);
            ELSIF p_trx_id IS NULL
            THEN
                /*SELECT DISTINCT org_id
                INTO l_org_id
                FROM ra_customer_trx_all rcta ,
                RA_CUSTOMERS RC
                WHERE RC.CUSTOMER_ID                 = RCTA.BILL_TO_CUSTOMER_ID
                AND RC.customer_number               = p_account_number
                AND RCTA.INTERFACE_HEADER_ATTRIBUTE1 = p_sales_order;*/
                l_org_id   := mo_global.get_current_org_id;

                BEGIN
                    SELECT due_days
                      INTO due_days
                      FROM apps.ra_terms_lines
                     WHERE relative_amount = 100 AND term_id = p_term_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        retcode   := 1;
                        errbuff   := 'There is no data for this Term.';
                        APPS.FND_FILE.PUT_LINE (
                            APPS.FND_FILE.LOG,
                            'There is no data for this Term.');
                    WHEN OTHERS
                    THEN
                        retcode   := 1;
                        errbuff   :=
                            'There is an unexpected error occured while getting due days for the Term.';
                        APPS.FND_FILE.PUT_LINE (
                            APPS.FND_FILE.LOG,
                            'There is an unexpected error occured while getting due days for the Term.');
                END;

                UPDATE apps.ra_customer_trx_all
                   SET term_id = p_term_id, term_due_date = trx_date + due_days, last_update_date = SYSDATE, --Added for CCR0006649
                       last_updated_by = FND_GLOBAL.USER_ID --Added for CCR0006649
                                                           , printing_option = 'PRI' --Added for CCR0006692
                                                                                    , printing_pending = 'Y' --Added for CCR0006692
                 WHERE     customer_trx_id IN
                               (SELECT customer_trx_id
                                  FROM ra_customer_trx_lines_all
                                 WHERE sales_order = p_sales_order)
                       --        AND Batch_Source_Id in (SELECT distinct Batch_Source_Id FROM RA_BATCH_SOURCES_ALL where name like '%Order Management%')    --Commented as a part of INC0364321
                       AND Customer_Trx_Id IN
                               (SELECT Customer_Trx_Id
                                  FROM ra_customer_trx_lines_all
                                 WHERE interface_line_context = 'ORDER ENTRY')
                       AND org_id = Mo_Global.Get_Current_Org_Id;

                UPDATE apps.ar_payment_schedules_all
                   SET term_id = p_term_id, due_date = trx_date + due_days, last_update_date = SYSDATE, --Added for CCR0006649
                       last_updated_by = FND_GLOBAL.USER_ID --Added for CCR0006649
                 WHERE     class = 'INV'
                       AND status = 'OP'
                       AND customer_trx_id IN
                               (SELECT customer_trx_id
                                  FROM ra_customer_trx_lines_all
                                 WHERE sales_order = p_sales_order)
                       --        AND Customer_Trx_Id in (select Customer_Trx_Id from ra_customer_trx_all where Batch_Source_Id in (SELECT distinct Batch_Source_Id FROM RA_BATCH_SOURCES_ALL where name like '%Order Management%'))    --Commented as a part of INC0364321
                       AND Customer_Trx_Id IN
                               (SELECT Customer_Trx_Id
                                  FROM ra_customer_trx_lines_all
                                 WHERE interface_line_context = 'ORDER ENTRY')
                       AND org_id = Mo_Global.Get_Current_Org_Id;

                IF SQL%ROWCOUNT > 0
                THEN
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        LPAD ('Update AR Invoice Payment Term - Deckers',
                              60,
                              ' '));
                    APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT, '');
                    APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT,
                                            'Org ID = ' || l_org_id);
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        'Account Number = ' || p_account_number);
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        'Sales Order = ' || p_sales_order);
                    --APPS.FND_FILE.PUT_LINE(APPS.FND_FILE.OUTPUT, 'Invoice Number = ' || l_trx_number);
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        'New Payment Term = ' || p_term_id);
                    APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT, '');
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        'Invoice Number  ' || LPAD ('Update Status', 15, ' '));

                    FOR l_trx_num IN c_transaction_number
                    LOOP
                        APPS.FND_FILE.PUT_LINE (
                            APPS.FND_FILE.OUTPUT,
                            l_trx_num.trx_number || LPAD ('Updated', 15, ' '));
                    END LOOP;
                ELSE
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.LOG,
                        'Account Number = ' || p_account_number);
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.LOG,
                        'p_sales_order = ' || p_sales_order);
                    --APPS.FND_FILE.PUT_LINE(APPS.FND_FILE.LOG, 'Invoice Number = ' || l_trx_number);
                    APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                            'p_term_id = ' || p_term_id);
                END IF;

                COMMIT;
                APPS.FND_FILE.PUT_LINE (
                    APPS.FND_FILE.LOG,
                    'Updated the Term for the Sales Order# ' || p_sales_order);
            ELSIF p_sales_order IS NULL
            THEN
                SELECT trx_number
                  INTO l_trx_number
                  FROM ra_customer_trx_all rcta, RA_CUSTOMERS RC
                 WHERE     RC.CUSTOMER_ID = RCTA.BILL_TO_CUSTOMER_ID
                       AND RCTA.customer_trx_id = p_trx_id
                       AND rcta.org_id = Mo_Global.Get_Current_Org_Id;

                /*SELECT DISTINCT org_id
                INTO l_org_id
                FROM ra_customer_trx_all rcta ,
                RA_CUSTOMERS RC
                WHERE RC.CUSTOMER_ID     = RCTA.BILL_TO_CUSTOMER_ID
                AND RC.customer_number   = p_account_number
                AND Rcta.Customer_Trx_Id = p_trx_id;*/
                l_org_id   := mo_global.get_current_org_id;

                BEGIN
                    SELECT due_days
                      INTO due_days
                      FROM apps.ra_terms_lines
                     WHERE relative_amount = 100 AND term_id = p_term_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        retcode   := 1;
                        errbuff   := 'There is no data for this Term.';
                        APPS.FND_FILE.PUT_LINE (
                            APPS.FND_FILE.LOG,
                            'There is no data for this Term.');
                    WHEN OTHERS
                    THEN
                        retcode   := 1;
                        errbuff   :=
                            'There is an unexpected error occured while getting due days for the Term.';
                        APPS.FND_FILE.PUT_LINE (
                            APPS.FND_FILE.LOG,
                            'There is an unexpected error occured while getting due days for the Term.');
                END;

                UPDATE apps.ra_customer_trx_all
                   SET term_id = p_term_id, term_due_date = trx_date + due_days, last_update_date = SYSDATE, --Added for CCR0006649
                       last_updated_by = FND_GLOBAL.USER_ID --Added for CCR0006649
                                                           , printing_option = 'PRI' --Added for CCR0006692
                                                                                    , printing_pending = 'Y' --Added for CCR0006692
                 WHERE     customer_trx_id = p_trx_id
                       --        AND Batch_Source_Id in (SELECT distinct Batch_Source_Id FROM RA_BATCH_SOURCES_ALL where name like '%Order Management%')    --Commented as a part of INC0364321
                       AND Customer_Trx_Id IN
                               (SELECT Customer_Trx_Id
                                  FROM ra_customer_trx_lines_all
                                 WHERE interface_line_context = 'ORDER ENTRY')
                       AND org_id = Mo_Global.Get_Current_Org_Id;

                UPDATE apps.ar_payment_schedules_all
                   SET term_id = p_term_id, due_date = trx_date + due_days, last_update_date = SYSDATE, --Added for CCR0006649
                       last_updated_by = FND_GLOBAL.USER_ID --Added for CCR0006649
                 WHERE     class = 'INV'
                       AND status = 'OP'
                       AND customer_trx_id = p_trx_id
                       --        AND Customer_Trx_Id in (select Customer_Trx_Id from ra_customer_trx_all where Batch_Source_Id in (SELECT distinct Batch_Source_Id FROM RA_BATCH_SOURCES_ALL where name like '%Order Management%'))    --Commented as a part of INC0364321
                       AND Customer_Trx_Id IN
                               (SELECT Customer_Trx_Id
                                  FROM ra_customer_trx_lines_all
                                 WHERE interface_line_context = 'ORDER ENTRY')
                       AND org_id = Mo_Global.Get_Current_Org_Id;

                IF SQL%ROWCOUNT > 0
                THEN
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        LPAD ('Update AR Invoice Payment Term - Deckers',
                              60,
                              ' '));
                    APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT, '');
                    APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT,
                                            'Org ID = ' || l_org_id);
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        'Account Number = ' || p_account_number);
                    --APPS.FND_FILE.PUT_LINE(APPS.FND_FILE.OUTPUT, 'p_sales_order = ' || p_sales_order);
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        'Invoice Number = ' || l_trx_number);
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        'New Payment Term = ' || p_term_id);
                    APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT, '');
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        'Invoice Number  ' || LPAD ('Update Status', 15, ' '));

                    FOR l_trx_num IN c_transaction_number
                    LOOP
                        APPS.FND_FILE.PUT_LINE (
                            APPS.FND_FILE.OUTPUT,
                            l_trx_num.trx_number || LPAD ('Updated', 15, ' '));
                    END LOOP;
                ELSE
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.LOG,
                        'Account Number = ' || p_account_number);
                    --APPS.FND_FILE.PUT_LINE(APPS.FND_FILE.LOG, 'p_sales_order = ' || p_sales_order);
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.LOG,
                        'Invoice Number = ' || l_trx_number);
                    APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                            'p_term_id = ' || p_term_id);
                END IF;

                COMMIT;
                APPS.FND_FILE.PUT_LINE (
                    APPS.FND_FILE.LOG,
                    'Updated the Term for the Transaction# ' || l_trx_number);
            ELSE
                SELECT trx_number
                  INTO l_trx_number
                  FROM ra_customer_trx_all rcta, RA_CUSTOMERS RC
                 WHERE     RC.CUSTOMER_ID = RCTA.BILL_TO_CUSTOMER_ID
                       AND RCTA.customer_trx_id = p_trx_id
                       AND rcta.org_id = Mo_Global.Get_Current_Org_Id;

                /* SELECT DISTINCT org_id
                INTO l_org_id
                FROM ra_customer_trx_all rcta ,
                RA_CUSTOMERS RC
                WHERE RC.CUSTOMER_ID     = RCTA.BILL_TO_CUSTOMER_ID
                AND RC.customer_number   = p_account_number
                AND Rcta.Customer_Trx_Id = p_trx_id;*/
                l_org_id   := mo_global.get_current_org_id;

                BEGIN
                    SELECT due_days
                      INTO due_days
                      FROM apps.ra_terms_lines
                     WHERE relative_amount = 100 AND term_id = p_term_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        retcode   := 1;
                        errbuff   := 'There is no data for this Term.';
                        APPS.FND_FILE.PUT_LINE (
                            APPS.FND_FILE.LOG,
                            'There is no data for this Term.');
                    WHEN OTHERS
                    THEN
                        retcode   := 1;
                        errbuff   :=
                            'There is an unexpected error occured while getting due days for the Term.';
                        APPS.FND_FILE.PUT_LINE (
                            APPS.FND_FILE.LOG,
                            'There is an unexpected error occured while getting due days for the Term.');
                END;

                UPDATE apps.ra_customer_trx_all
                   SET term_id = p_term_id, term_due_date = trx_date + due_days, last_update_date = SYSDATE, -- Added for CCR0006649
                       last_updated_by = FND_GLOBAL.USER_ID -- Added for CCR0006649
                                                           , printing_option = 'PRI' --Added for CCR0006692
                                                                                    , printing_pending = 'Y' --Added for CCR0006692
                 WHERE     customer_trx_id = p_trx_id
                       --        AND Batch_Source_Id in (SELECT distinct Batch_Source_Id FROM RA_BATCH_SOURCES_ALL where name like '%Order Management%')    --Commented as a part of INC0364321
                       AND Customer_Trx_Id IN
                               (SELECT Customer_Trx_Id
                                  FROM ra_customer_trx_lines_all
                                 WHERE interface_line_context = 'ORDER ENTRY')
                       AND org_id = Mo_Global.Get_Current_Org_Id;

                UPDATE apps.ar_payment_schedules_all
                   SET term_id = p_term_id, due_date = trx_date + due_days, last_update_date = SYSDATE, -- Added for CCR0006649
                       last_updated_by = FND_GLOBAL.USER_ID -- Added for CCR0006649
                 WHERE     class = 'INV'
                       AND status = 'OP'
                       AND customer_trx_id = p_trx_id
                       --        AND Customer_Trx_Id in (select Customer_Trx_Id from ra_customer_trx_all where Batch_Source_Id in (SELECT distinct Batch_Source_Id FROM RA_BATCH_SOURCES_ALL where name like '%Order Management%'))    --Commented as a part of INC0364321
                       AND Customer_Trx_Id IN
                               (SELECT Customer_Trx_Id
                                  FROM ra_customer_trx_lines_all
                                 WHERE interface_line_context = 'ORDER ENTRY')
                       AND org_id = Mo_Global.Get_Current_Org_Id;

                IF SQL%ROWCOUNT > 0
                THEN
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        LPAD ('Update AR Invoice Payment Term - Deckers',
                              60,
                              ' '));
                    APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT, '');
                    APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT,
                                            'Org ID = ' || l_org_id);
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        'Account Number = ' || p_account_number);
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        'Sales Order = ' || p_sales_order);
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        'Invoice Number = ' || l_trx_number);
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        'New Payment Term = ' || p_term_id);
                    APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT, '');
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        'Invoice Number  ' || LPAD ('Update Status', 15, ' '));

                    FOR l_trx_num IN c_transaction_number
                    LOOP
                        APPS.FND_FILE.PUT_LINE (
                            APPS.FND_FILE.OUTPUT,
                            l_trx_num.trx_number || LPAD ('Updated', 15, ' '));
                    END LOOP;
                ELSE
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.LOG,
                        'Account Number = ' || p_account_number);
                    --APPS.FND_FILE.PUT_LINE(APPS.FND_FILE.LOG, 'p_sales_order = ' || p_sales_order);
                    --APPS.FND_FILE.PUT_LINE(APPS.FND_FILE.LOG, 'Invoice Number = ' || l_trx_number);
                    APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                            'p_term_id = ' || p_term_id);
                END IF;

                COMMIT;
                APPS.FND_FILE.PUT_LINE (
                    APPS.FND_FILE.LOG,
                    'Updated the Term for the Transaction# ' || l_trx_number);
            END IF;
        ELSE
            IF p_sales_order IS NULL AND p_trx_id IS NULL
            THEN
                /* SELECT DISTINCT org_id
                INTO l_org_id
                FROM ra_customer_trx_all rcta ,
                RA_CUSTOMERS RC
                WHERE RC.CUSTOMER_ID   = RCTA.BILL_TO_CUSTOMER_ID
                AND RC.customer_number = p_account_number
                AND term_id     = p_old_term_id;*/
                l_org_id   := mo_global.get_current_org_id;
                APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                        'Org ID = ' || l_org_id);

                BEGIN
                    SELECT due_days
                      INTO due_days
                      FROM apps.ra_terms_lines
                     WHERE relative_amount = 100 AND term_id = p_term_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        retcode   := 1;
                        errbuff   := 'There is no data for this Term.';
                        APPS.FND_FILE.PUT_LINE (
                            APPS.FND_FILE.LOG,
                            'There is no data for this Term.');
                    WHEN OTHERS
                    THEN
                        retcode   := 1;
                        errbuff   :=
                            'There is an unexpected error occured while getting due days for the Term.';
                        APPS.FND_FILE.PUT_LINE (
                            APPS.FND_FILE.LOG,
                            'There is an unexpected error occured while getting due days for the Term.');
                END;

                UPDATE apps.ra_customer_trx_all
                   SET term_id = p_term_id, term_due_date = trx_date + due_days, last_update_date = SYSDATE, --Added for CCR0006649
                       last_updated_by = FND_GLOBAL.USER_ID --Added for CCR0006649
                                                           , printing_option = 'PRI' --Added for CCR0006692
                                                                                    , printing_pending = 'Y' --Added for CCR0006692
                 WHERE     bill_to_customer_id =
                           (SELECT customer_id
                              FROM ra_customers
                             WHERE customer_number = p_account_number)
                       AND Customer_Trx_Id IN
                               (SELECT Customer_Trx_Id
                                  FROM apps.ar_payment_schedules_all
                                 WHERE class = 'INV' AND status = 'OP')
                       AND term_id = p_old_term_id
                       --          AND Batch_Source_Id in (SELECT distinct Batch_Source_Id FROM RA_BATCH_SOURCES_ALL where name like '%Order Management%')    --Commented as a part of INC0364321
                       AND Customer_Trx_Id IN
                               (SELECT Customer_Trx_Id
                                  FROM ra_customer_trx_lines_all
                                 WHERE interface_line_context = 'ORDER ENTRY')
                       AND org_id = Mo_Global.Get_Current_Org_Id;

                UPDATE apps.ar_payment_schedules_all
                   SET term_id = p_term_id, due_date = trx_date + due_days, last_update_date = SYSDATE, --Added for CCR0006649
                       last_updated_by = FND_GLOBAL.USER_ID --Added for CCR0006649
                 WHERE     class = 'INV'
                       AND status = 'OP'
                       AND customer_id =
                           (SELECT customer_id
                              FROM ra_customers
                             WHERE customer_number = p_account_number)
                       AND term_id = p_old_term_id
                       --        AND Customer_Trx_Id in (select Customer_Trx_Id from ra_customer_trx_all where Batch_Source_Id in (SELECT distinct Batch_Source_Id FROM RA_BATCH_SOURCES_ALL where name like '%Order Management%'))    --Commented as a part of INC0364321
                       AND Customer_Trx_Id IN
                               (SELECT Customer_Trx_Id
                                  FROM ra_customer_trx_lines_all
                                 WHERE interface_line_context = 'ORDER ENTRY')
                       AND org_id = Mo_Global.Get_Current_Org_Id;

                IF SQL%ROWCOUNT > 0
                THEN
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        LPAD ('Update AR Invoice Payment Term - Deckers',
                              60,
                              ' '));
                    APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT, '');
                    APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT,
                                            'Org ID = ' || l_org_id);
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        'Account Number = ' || p_account_number);
                    --APPS.FND_FILE.PUT_LINE(APPS.FND_FILE.OUTPUT, 'p_sales_order = ' || p_sales_order);
                    --APPS.FND_FILE.PUT_LINE(APPS.FND_FILE.OUTPUT, 'Invoice Number = ' || l_trx_number);
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        'Old Payment Term = ' || p_old_term_id);
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        'New Payment Term = ' || p_term_id);
                    APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT, '');
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        'Invoice Number  ' || LPAD ('Update Status', 15, ' '));

                    FOR l_trx_num IN c_transaction_number
                    LOOP
                        APPS.FND_FILE.PUT_LINE (
                            APPS.FND_FILE.OUTPUT,
                            l_trx_num.trx_number || LPAD ('Updated', 15, ' '));
                    END LOOP;
                ELSE
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.LOG,
                        'Account Number = ' || p_account_number);
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.LOG,
                        'p_sales_order = ' || p_sales_order);
                    --APPS.FND_FILE.PUT_LINE(APPS.FND_FILE.LOG, 'Invoice Number = ' || l_trx_number);
                    APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                            'p_term_id = ' || p_term_id);
                END IF;

                COMMIT;
                APPS.FND_FILE.PUT_LINE (
                    APPS.FND_FILE.LOG,
                    'Updated the Term for the Customer# ' || p_account_number);
            ELSIF p_trx_id IS NULL
            THEN
                /*SELECT DISTINCT org_id
                INTO l_org_id
                FROM ra_customer_trx_all rcta ,
                RA_CUSTOMERS RC
                WHERE RC.CUSTOMER_ID   = RCTA.BILL_TO_CUSTOMER_ID
                AND RC.customer_number = p_account_number
                AND term_id     = p_old_term_id;*/
                l_org_id   := mo_global.get_current_org_id;

                BEGIN
                    SELECT due_days
                      INTO due_days
                      FROM apps.ra_terms_lines
                     WHERE relative_amount = 100 AND term_id = p_term_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        retcode   := 1;
                        errbuff   := 'There is no data for this Term.';
                        APPS.FND_FILE.PUT_LINE (
                            APPS.FND_FILE.LOG,
                            'There is no data for this Term.');
                    WHEN OTHERS
                    THEN
                        retcode   := 1;
                        errbuff   :=
                            'There is an unexpected error occured while getting due days for the Term.';
                        APPS.FND_FILE.PUT_LINE (
                            APPS.FND_FILE.LOG,
                            'There is an unexpected error occured while getting due days for the Term.');
                END;

                UPDATE apps.ra_customer_trx_all
                   SET term_id = p_term_id, term_due_date = trx_date + due_days, last_update_date = SYSDATE, --Added for CCR0006649
                       last_updated_by = FND_GLOBAL.USER_ID --Added for CCR0006649
                                                           , printing_option = 'PRI' --Added for CCR0006692
                                                                                    , printing_pending = 'Y' --Added for CCR0006692
                 WHERE     customer_trx_id IN
                               (SELECT customer_trx_id
                                  FROM ra_customer_trx_lines_all
                                 WHERE sales_order = p_sales_order)
                       AND term_id = p_old_term_id
                       --        AND Batch_Source_Id in (SELECT distinct Batch_Source_Id FROM RA_BATCH_SOURCES_ALL where name like '%Order Management%')    --Commented as a part of INC0364321
                       AND Customer_Trx_Id IN
                               (SELECT Customer_Trx_Id
                                  FROM ra_customer_trx_lines_all
                                 WHERE interface_line_context = 'ORDER ENTRY')
                       AND org_id = Mo_Global.Get_Current_Org_Id;

                UPDATE apps.ar_payment_schedules_all
                   SET term_id = p_term_id, due_date = trx_date + due_days, last_update_date = SYSDATE, --Added for CCR0006649
                       last_updated_by = FND_GLOBAL.USER_ID --Added for CCR0006649
                 WHERE     class = 'INV'
                       AND status = 'OP'
                       AND customer_trx_id IN
                               (SELECT customer_trx_id
                                  FROM ra_customer_trx_lines_all
                                 WHERE sales_order = p_sales_order)
                       AND term_id = p_old_term_id
                       --        AND Customer_Trx_Id in (select Customer_Trx_Id from ra_customer_trx_all where Batch_Source_Id in (SELECT distinct Batch_Source_Id FROM RA_BATCH_SOURCES_ALL where name like '%Order Management%'))    --Commented as a part of INC0364321
                       AND Customer_Trx_Id IN
                               (SELECT Customer_Trx_Id
                                  FROM ra_customer_trx_lines_all
                                 WHERE interface_line_context = 'ORDER ENTRY')
                       AND org_id = Mo_Global.Get_Current_Org_Id;

                IF SQL%ROWCOUNT > 0
                THEN
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        LPAD ('Update AR Invoice Payment Term - Deckers',
                              60,
                              ' '));
                    APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT, '');
                    APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT,
                                            'Org ID = ' || l_org_id);
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        'Account Number = ' || p_account_number);
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        'Sales Order = ' || p_sales_order);
                    --APPS.FND_FILE.PUT_LINE(APPS.FND_FILE.OUTPUT, 'Invoice Number = ' || l_trx_number);
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        'Old Payment Term = ' || p_old_term_id);
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        'New Payment Term = ' || p_term_id);
                    APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT, '');
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        'Invoice Number  ' || LPAD ('Update Status', 15, ' '));

                    FOR l_trx_num IN c_transaction_number
                    LOOP
                        APPS.FND_FILE.PUT_LINE (
                            APPS.FND_FILE.OUTPUT,
                            l_trx_num.trx_number || LPAD ('Updated', 15, ' '));
                    END LOOP;
                ELSE
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.LOG,
                        'Account Number = ' || p_account_number);
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.LOG,
                        'p_sales_order = ' || p_sales_order);
                    --APPS.FND_FILE.PUT_LINE(APPS.FND_FILE.LOG, 'Invoice Number = ' || l_trx_number);
                    APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                            'p_term_id = ' || p_term_id);
                END IF;

                COMMIT;
                APPS.FND_FILE.PUT_LINE (
                    APPS.FND_FILE.LOG,
                    'Updated the Term for the Order# ' || p_sales_order);
            ELSIF p_sales_order IS NULL
            THEN
                SELECT trx_number
                  INTO l_trx_number
                  FROM ra_customer_trx_all rcta, RA_CUSTOMERS RC
                 WHERE     RC.CUSTOMER_ID = RCTA.BILL_TO_CUSTOMER_ID
                       AND RCTA.customer_trx_id = p_trx_id
                       AND rcta.term_id = p_old_term_id
                       AND rcta.org_id = Mo_Global.Get_Current_Org_Id;

                /*SELECT DISTINCT org_id
                INTO l_org_id
                FROM ra_customer_trx_all rcta , RA_CUSTOMERS RC
                WHERE RC.CUSTOMER_ID     = RCTA.BILL_TO_CUSTOMER_ID
                AND RC.customer_number   = p_account_number
                AND Rcta.Customer_Trx_Id = p_trx_id
                AND rcta.term_id         = p_old_term_id;*/
                l_org_id   := mo_global.get_current_org_id;

                BEGIN
                    SELECT due_days
                      INTO due_days
                      FROM apps.ra_terms_lines
                     WHERE relative_amount = 100 AND term_id = p_term_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        retcode   := 1;
                        errbuff   := 'There is no data for this Term.';
                        APPS.FND_FILE.PUT_LINE (
                            APPS.FND_FILE.LOG,
                            'There is no data for this Term.');
                    WHEN OTHERS
                    THEN
                        retcode   := 1;
                        errbuff   :=
                            'There is an unexpected error occured while getting due days for the Term.';
                        APPS.FND_FILE.PUT_LINE (
                            APPS.FND_FILE.LOG,
                            'There is an unexpected error occured while getting due days for the Term.');
                END;

                UPDATE apps.ra_customer_trx_all
                   SET term_id = p_term_id, term_due_date = trx_date + due_days, last_update_date = SYSDATE, --Added for CCR0006649
                       last_updated_by = FND_GLOBAL.USER_ID --Added for CCR0006649
                                                           , printing_option = 'PRI' --Added for CCR0006692
                                                                                    , printing_pending = 'Y' --Added for CCR0006692
                 WHERE     customer_trx_id = p_trx_id
                       AND term_id = p_old_term_id
                       --        AND Batch_Source_Id in (SELECT distinct Batch_Source_Id FROM RA_BATCH_SOURCES_ALL where name like '%Order Management%')    --Commented as a part of INC0364321
                       AND Customer_Trx_Id IN
                               (SELECT Customer_Trx_Id
                                  FROM ra_customer_trx_lines_all
                                 WHERE interface_line_context = 'ORDER ENTRY')
                       AND org_id = Mo_Global.Get_Current_Org_Id;

                UPDATE apps.ar_payment_schedules_all
                   SET term_id = p_term_id, due_date = trx_date + due_days, last_update_date = SYSDATE, --Added for CCR0006649
                       last_updated_by = FND_GLOBAL.USER_ID --Added for CCR0006649
                 WHERE     class = 'INV'
                       AND status = 'OP'
                       AND customer_trx_id = p_trx_id
                       AND term_id = p_old_term_id
                       --        AND Customer_Trx_Id in (select Customer_Trx_Id from ra_customer_trx_all where Batch_Source_Id in (SELECT distinct Batch_Source_Id FROM RA_BATCH_SOURCES_ALL where name like '%Order Management%'))    --Commented as a part of INC0364321
                       AND Customer_Trx_Id IN
                               (SELECT Customer_Trx_Id
                                  FROM ra_customer_trx_lines_all
                                 WHERE interface_line_context = 'ORDER ENTRY')
                       AND org_id = Mo_Global.Get_Current_Org_Id;

                IF SQL%ROWCOUNT > 0
                THEN
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        LPAD ('Update AR Invoice Payment Term - Deckers',
                              60,
                              ' '));
                    APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT, '');
                    APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT,
                                            'Org ID = ' || l_org_id);
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        'Account Number = ' || p_account_number);
                    --APPS.FND_FILE.PUT_LINE(APPS.FND_FILE.OUTPUT, 'p_sales_order = ' || p_sales_order);
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        'Invoice Number = ' || l_trx_number);
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        'Old Payment Term = ' || p_old_term_id);
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        'New Payment Term = ' || p_term_id);
                    APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT, '');
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        'Invoice Number  ' || LPAD ('Update Status', 15, ' '));

                    FOR l_trx_num IN c_transaction_number
                    LOOP
                        APPS.FND_FILE.PUT_LINE (
                            APPS.FND_FILE.OUTPUT,
                            l_trx_num.trx_number || LPAD ('Updated', 15, ' '));
                    END LOOP;
                ELSE
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.LOG,
                        'Account Number = ' || p_account_number);
                    --APPS.FND_FILE.PUT_LINE(APPS.FND_FILE.LOG, 'p_sales_order = ' || p_sales_order);
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.LOG,
                        'Invoice Number = ' || l_trx_number);
                    APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                            'p_term_id = ' || p_term_id);
                END IF;

                COMMIT;
                APPS.FND_FILE.PUT_LINE (
                    APPS.FND_FILE.LOG,
                    'Updated the Term for the Transaction# ' || l_trx_number);
            ELSE
                SELECT trx_number
                  INTO l_trx_number
                  FROM ra_customer_trx_all rcta, RA_CUSTOMERS RC
                 WHERE     RC.CUSTOMER_ID = RCTA.BILL_TO_CUSTOMER_ID
                       AND RCTA.customer_trx_id = p_trx_id
                       AND rcta.term_id = p_old_term_id
                       AND rcta.org_id = Mo_Global.Get_Current_Org_Id;

                /* SELECT DISTINCT org_id
                INTO l_org_id
                FROM ra_customer_trx_all rcta ,
                RA_CUSTOMERS RC
                WHERE RC.CUSTOMER_ID     = RCTA.BILL_TO_CUSTOMER_ID
                AND RC.customer_number   = p_account_number
                AND Rcta.Customer_Trx_Id = p_trx_id
                AND rcta.term_id         = p_old_term_id;*/
                l_org_id   := mo_global.get_current_org_id;

                BEGIN
                    SELECT due_days
                      INTO due_days
                      FROM apps.ra_terms_lines
                     WHERE relative_amount = 100 AND term_id = p_term_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        retcode   := 1;
                        errbuff   := 'There is no data for this Term.';
                        APPS.FND_FILE.PUT_LINE (
                            APPS.FND_FILE.LOG,
                            'There is no data for this Term.');
                    WHEN OTHERS
                    THEN
                        retcode   := 1;
                        errbuff   :=
                            'There is an unexpected error occured while getting due days for the Term.';
                        APPS.FND_FILE.PUT_LINE (
                            APPS.FND_FILE.LOG,
                            'There is an unexpected error occured while getting due days for the Term.');
                END;

                UPDATE apps.ra_customer_trx_all
                   SET term_id = p_term_id, term_due_date = trx_date + due_days, last_update_date = SYSDATE, --Added for CCR0006649
                       last_updated_by = FND_GLOBAL.USER_ID --Added for CCR0006649
                                                           , printing_option = 'PRI' --Added for CCR0006692
                                                                                    , printing_pending = 'Y' --Added for CCR0006692
                 WHERE     customer_trx_id = p_trx_id
                       AND term_id = p_old_term_id
                       --        AND Batch_Source_Id in (SELECT distinct Batch_Source_Id FROM RA_BATCH_SOURCES_ALL where name like '%Order Management%')    --Commented as a part of INC0364321
                       AND Customer_Trx_Id IN
                               (SELECT Customer_Trx_Id
                                  FROM ra_customer_trx_lines_all
                                 WHERE interface_line_context = 'ORDER ENTRY')
                       AND org_id = Mo_Global.Get_Current_Org_Id;

                UPDATE apps.ar_payment_schedules_all
                   SET term_id = p_term_id, due_date = trx_date + due_days, last_update_date = SYSDATE, --Added for CCR0006649
                       last_updated_by = FND_GLOBAL.USER_ID --Added for CCR0006649
                 WHERE     class = 'INV'
                       AND status = 'OP'
                       AND customer_trx_id = p_trx_id
                       AND term_id = p_old_term_id
                       --        AND Customer_Trx_Id in (select Customer_Trx_Id from ra_customer_trx_all where Batch_Source_Id in (SELECT distinct Batch_Source_Id FROM RA_BATCH_SOURCES_ALL where name like '%Order Management%'))    --Commented as a part of INC0364321
                       AND Customer_Trx_Id IN
                               (SELECT Customer_Trx_Id
                                  FROM ra_customer_trx_lines_all
                                 WHERE interface_line_context = 'ORDER ENTRY')
                       AND org_id = Mo_Global.Get_Current_Org_Id;

                IF SQL%ROWCOUNT > 0
                THEN
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        LPAD ('Update AR Invoice Payment Term - Deckers',
                              60,
                              ' '));
                    APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT, '');
                    APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT,
                                            'Org ID = ' || l_org_id);
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        'Account Number = ' || p_account_number);
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        'Sales Order = ' || p_sales_order);
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        'Invoice Number = ' || l_trx_number);
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        'Old Payment Term = ' || p_old_term_id);
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        'New Payment Term = ' || p_term_id);
                    APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT, '');
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                        'Invoice Number  ' || LPAD ('Update Status', 15, ' '));

                    FOR l_trx_num IN c_transaction_number
                    LOOP
                        APPS.FND_FILE.PUT_LINE (
                            APPS.FND_FILE.OUTPUT,
                            l_trx_num.trx_number || LPAD ('Updated', 15, ' '));
                    END LOOP;
                ELSE
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.LOG,
                        'Account Number = ' || p_account_number);
                    --APPS.FND_FILE.PUT_LINE(APPS.FND_FILE.LOG, 'p_sales_order = ' || p_sales_order);
                    --APPS.FND_FILE.PUT_LINE(APPS.FND_FILE.LOG, 'Invoice Number = ' || l_trx_number);
                    APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                            'p_term_id = ' || p_term_id);
                END IF;

                COMMIT;
                APPS.FND_FILE.PUT_LINE (
                    APPS.FND_FILE.LOG,
                    'Updated the Term for the Transaction# ' || l_trx_number);
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            retcode   := 1;
            errbuff   :=
                'There is an unexpected error occured while processing your request.';
            APPS.FND_FILE.PUT_LINE (
                APPS.FND_FILE.LOG,
                'There is an unexpected error occured while processing your request.');
    END update_payment_term;
END xxdoar_invoice_register;
/
