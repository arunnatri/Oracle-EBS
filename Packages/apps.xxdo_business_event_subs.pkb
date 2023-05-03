--
-- XXDO_BUSINESS_EVENT_SUBS  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:12 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_BUSINESS_EVENT_SUBS"
IS
    /*******************************************************************************
    * Program Name : xxdo_business_event_subs
    * Language     : PL/SQL
    * Description  :
    *
    * History      :
    *
    * WHO                    WHAT               Desc                             DATE
    * -------------- ---------------------------------------------- ---------------
    * BT Technology Team    1.0
    * Infosys               2.0     SOA - EDI810 changes -:(CCR0007021)  07-MAR-2018
    * Showkath Ali          2.1     SOA - EDI810 changes (CCR0008488)    21-Jul-2020
    * Elaine Yang           2.2     SOA - EDI810 changes (CCR0009959)    04-Dec-2022
    * --------------------------------------------------------------------------- */
    FUNCTION user_subscription (
        p_subscription_quid   IN            RAW,
        p_event               IN OUT NOCOPY wf_event_t)
        RETURN VARCHAR2
    IS
    BEGIN
        do_Debug_tools.msg ('User Sub key: ' || p_event.getEventKey ());
        RETURN 'SUCCESS';
    EXCEPTION
        WHEN OTHERS
        THEN
            wf_event.setErrorInfo (p_event, 'ERROR');
            RETURN 'ERROR';
    END;

    FUNCTION invoice_subscription (
        p_subscription_quid   IN            RAW,
        p_event               IN OUT NOCOPY wf_event_t)
        RETURN VARCHAR2
    IS
        l_edi_customer   NUMBER;
    BEGIN
        do_Debug_tools.msg (
            'Invoice Subscription Key: ' || p_event.getEventKey ());
        do_debug_tools.msg (
            'Invoice Subscription Key: ' || p_event.getvalueforparameter ('CUSTOMER_TRX_ID'));

        /*  SELECT COUNT (*)
            INTO l_edi_customer
            FROM fnd_lookup_values flv,
                 hz_cust_accounts hca,
                 ra_customer_trx_all rcta
           WHERE     rcta.customer_trx_id =
                        p_event.getvalueforparameter ('CUSTOMER_TRX_ID')
                 AND hca.cust_account_id = rcta.bill_to_customer_id
                 AND flv.lookup_code = hca.account_number
                 AND flv.lookup_type = 'XXDO_SOA_EDI_CUSTOMERS'
                 AND flv.language = 'US'; */

        SELECT COUNT (*)
          INTO l_edi_customer
          FROM fnd_lookup_values flv, hz_cust_accounts hca, ra_customer_trx_all rcta
         WHERE     rcta.customer_trx_id =
                   p_event.getvalueforparameter ('CUSTOMER_TRX_ID')
               AND hca.cust_account_id = rcta.bill_to_customer_id
               AND flv.lookup_code = hca.account_number
               AND flv.lookup_type = 'XXD_EDI_810_CUSTOMERS'
               AND flv.enabled_flag = 'Y'
               AND flv.language = 'US';

        IF NVL (l_edi_customer, 0) > 0
        THEN
            wf_event.raise (
                p_event_name   => 'oracle.apps.xxdo.inv_complete',
                p_event_key    =>
                    p_event.getvalueforparameter ('CUSTOMER_TRX_ID'));

            FOR shipment
                IN (SELECT DISTINCT ship.shipment_id
                      FROM do_edi.do_edi856_pick_tickets tick, do_edi.do_edi856_shipments ship, fnd_lookup_values flv,
                           hz_cust_accounts hca
                     WHERE     flv.lookup_type = 'XXDO_SOA_EDI_CUSTOMERS'
                           AND hca.account_number = flv.lookup_code
                           AND hca.cust_account_id = ship.customer_id
                           AND ship.shipment_id IN
                                   (SELECT DISTINCT tick.shipment_id
                                      FROM ra_customer_trx_lines_all rctla, wsh_delivery_details wdd, wsh_delivery_assignments wda,
                                           do_edi.do_edi856_pick_tickets tick
                                     WHERE     rctla.customer_trx_id =
                                               p_event.GETVALUEFORPARAMETER (
                                                   'CUSTOMER_TRX_ID')
                                           AND rctla.interface_line_context =
                                               'ORDER ENTRY'
                                           AND wdd.source_line_id =
                                               TO_NUMBER (
                                                   rctla.interface_line_attribute6)
                                           AND wda.delivery_detail_id =
                                               wdd.delivery_detail_id
                                           AND tick.delivery_id =
                                               wda.delivery_id)
                           AND ship.invoice_Date IS NULL
                           AND tick.shipment_id = ship.shipment_id
                           AND NOT EXISTS
                                   (SELECT NULL
                                      FROM wsh_delivery_assignments wda, wsh_delivery_details wdd
                                     WHERE     wda.delivery_id =
                                               tick.delivery_id
                                           AND wdd.delivery_detail_id =
                                               wda.delivery_detail_id
                                           AND wdd.source_code = 'OE'
                                           AND NOT EXISTS
                                                   (SELECT NULL
                                                      FROM ra_customer_trx_lines_all
                                                     WHERE     interface_line_context =
                                                               'ORDER ENTRY'
                                                           AND interface_line_attribute6 =
                                                               TO_CHAR (
                                                                   wdd.source_line_id))))
            LOOP
                UPDATE do_edi.do_edi856_shipments ship
                   SET invoice_Date   = TRUNC (SYSDATE)
                 WHERE shipment_id = shipment.shipment_id;

                wf_event.raise (
                    p_event_name   =>
                        'oracle.apps.xxdo.consolidated_asn_inv_complete',
                    p_event_key   => shipment.shipment_id);
            END LOOP;
        END IF;

        RETURN 'SUCCESS';
    EXCEPTION
        WHEN OTHERS
        THEN
            wf_event.setErrorInfo (p_event, 'ERROR');
            RETURN 'ERROR';
    END;

    FUNCTION autoinvoice_subscription (
        p_subscription_quid   IN            RAW,
        p_event               IN OUT NOCOPY wf_event_t)
        RETURN VARCHAR2
    IS
        l_edi_customer       NUMBER;
        l_edi_810_customer   NUMBER;
        l_sps_customer       VARCHAR2 (10);
    BEGIN
        do_Debug_tools.msg (
            'AutoInvoice Subscription Key: ' || p_event.getEventKey ());
        do_Debug_tools.msg (
            'AutoInvoice request id: ' || p_event.getvalueforparameter ('REQUEST_ID'));

        FOR trx
            IN (SELECT customer_trx_id
                  FROM ra_customer_Trx_all
                 WHERE request_id =
                       p_event.getvalueforparameter ('REQUEST_ID'))
        LOOP
            /*SELECT COUNT (*)
              INTO l_edi_customer
              FROM fnd_lookup_values flv,
                   hz_cust_accounts hca,
                   ra_customer_trx_all rcta
             WHERE     rcta.customer_trx_id = trx.customer_trx_id
                   AND hca.cust_account_id = rcta.bill_to_customer_id
                   AND flv.lookup_code = hca.account_number
                   AND flv.lookup_type = 'XXDO_SOA_EDI_CUSTOMERS'
                   AND flv.language = 'US';*/
            -- 2.2 changes start revert the xxd_edi_810_customers flag
            BEGIN
                SELECT COUNT (*)
                  INTO l_edi_customer
                  FROM fnd_lookup_values flv, hz_cust_accounts hca, ra_customer_trx_all rcta
                 WHERE     rcta.customer_trx_id = trx.customer_trx_id
                       AND hca.cust_account_id = rcta.bill_to_customer_id
                       AND flv.lookup_code = hca.account_number
                       AND flv.lookup_type = 'XXD_EDI_810_CUSTOMERS'
                       AND flv.enabled_flag = 'Y'
                       AND NVL (TRUNC (flv.start_date_active),
                                TRUNC (SYSDATE)) <=
                           TRUNC (SYSDATE)
                       AND NVL (TRUNC (flv.end_date_active), TRUNC (SYSDATE)) >=
                           TRUNC (SYSDATE)
                       AND flv.language = 'US';                          --2.1
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    l_edi_customer   := NULL;
                WHEN OTHERS
                THEN
                    l_edi_customer   := NULL;
            END;

            -- 2.1 changes start  --2.2 changes end
            BEGIN
                SELECT NVL (flv.attribute1, 'N')
                  INTO l_sps_customer
                  FROM fnd_lookup_values flv, hz_cust_accounts hca, ra_customer_trx_all rcta
                 WHERE     rcta.customer_trx_id = trx.customer_trx_id
                       AND hca.cust_account_id = rcta.bill_to_customer_id
                       AND flv.lookup_code = hca.account_number
                       AND flv.lookup_type = 'XXDO_EDI_CUSTOMERS'
                       AND flv.enabled_flag = 'Y'
                       AND NVL (TRUNC (flv.start_date_active),
                                TRUNC (SYSDATE)) <=
                           TRUNC (SYSDATE)
                       AND NVL (TRUNC (flv.end_date_active), TRUNC (SYSDATE)) >=
                           TRUNC (SYSDATE)
                       AND flv.language = 'US';
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_sps_customer   := NULL;
            END;

            --IF NVL (l_edi_customer, 0) > 0
            -- THEN
            IF l_sps_customer = 'N'
            THEN
                --2.1 changes end
                --2.2 changes start
                IF NVL (l_edi_customer, 0) > 0
                THEN
                    do_Debug_tools.msg (
                        'Raising invoice complete for id: ' || trx.customer_trx_id);
                    wf_event.raise (
                        p_event_name   => 'oracle.apps.xxdo.inv_complete',
                        p_event_key    => TO_CHAR (trx.customer_trx_id));
                    do_Debug_tools.msg (
                        'Raised invoice complete for id: ' || trx.customer_trx_id);
                END IF;

                --2.2 changes end
                FOR shipment
                    IN (SELECT DISTINCT ship.shipment_id
                          FROM do_edi.do_edi856_pick_tickets tick, do_edi.do_edi856_shipments ship, fnd_lookup_values flv,
                               hz_cust_accounts hca
                         WHERE     flv.lookup_type = 'XXDO_SOA_EDI_CUSTOMERS'
                               AND hca.account_number = flv.lookup_code
                               AND hca.cust_account_id = ship.customer_id
                               AND ship.shipment_id IN
                                       (SELECT DISTINCT tick.shipment_id
                                          FROM ra_customer_trx_lines_all rctla, wsh_delivery_details wdd, wsh_delivery_assignments wda,
                                               do_edi.do_edi856_pick_tickets tick
                                         WHERE     rctla.customer_trx_id =
                                                   trx.customer_trx_id
                                               AND rctla.interface_line_context =
                                                   'ORDER ENTRY'
                                               AND wdd.source_line_id =
                                                   TO_NUMBER (
                                                       rctla.interface_line_attribute6)
                                               AND wda.delivery_detail_id =
                                                   wdd.delivery_detail_id
                                               AND tick.delivery_id =
                                                   wda.delivery_id)
                               AND ship.invoice_Date IS NULL
                               AND tick.shipment_id = ship.shipment_id
                               AND NOT EXISTS
                                       (SELECT NULL
                                          FROM wsh_delivery_assignments wda, wsh_delivery_details wdd
                                         WHERE     wda.delivery_id =
                                                   tick.delivery_id
                                               AND wdd.delivery_detail_id =
                                                   wda.delivery_detail_id
                                               AND wdd.source_code = 'OE'
                                               AND NOT EXISTS
                                                       (SELECT NULL
                                                          FROM ra_customer_trx_lines_all
                                                         WHERE     interface_line_context =
                                                                   'ORDER ENTRY'
                                                               AND interface_line_attribute6 =
                                                                   TO_CHAR (
                                                                       wdd.source_line_id))))
                LOOP
                    UPDATE do_edi.do_edi856_shipments ship
                       SET invoice_Date   = TRUNC (SYSDATE)
                     WHERE shipment_id = shipment.shipment_id;

                    wf_event.raise (
                        p_event_name   =>
                            'oracle.apps.xxdo.consolidated_asn_inv_complete',
                        p_event_key   => shipment.shipment_id);
                END LOOP;
            --2.1 changes start
            ELSIF l_sps_customer = 'Y'
            THEN
                --2.2 changes start
                IF NVL (l_edi_customer, 0) > 0
                THEN
                    do_Debug_tools.msg (
                        'Raising invoice complete for id: ' || trx.customer_trx_id);
                    wf_event.raise (
                        p_event_name   => 'oracle.apps.xxdo.sps_inv_complete',
                        p_event_key    => TO_CHAR (trx.customer_trx_id));
                    do_Debug_tools.msg (
                        'Raised invoice complete for id: ' || trx.customer_trx_id);
                END IF;

                --2.2 changes end
                FOR shipment
                    IN (SELECT DISTINCT ship.shipment_id
                          FROM do_edi.do_edi856_pick_tickets tick, do_edi.do_edi856_shipments ship, fnd_lookup_values flv,
                               hz_cust_accounts hca
                         WHERE     flv.lookup_type = 'XXDO_SOA_EDI_CUSTOMERS'
                               AND hca.account_number = flv.lookup_code
                               AND hca.cust_account_id = ship.customer_id
                               AND ship.shipment_id IN
                                       (SELECT DISTINCT tick.shipment_id
                                          FROM ra_customer_trx_lines_all rctla, wsh_delivery_details wdd, wsh_delivery_assignments wda,
                                               do_edi.do_edi856_pick_tickets tick
                                         WHERE     rctla.customer_trx_id =
                                                   trx.customer_trx_id
                                               AND rctla.interface_line_context =
                                                   'ORDER ENTRY'
                                               AND wdd.source_line_id =
                                                   TO_NUMBER (
                                                       rctla.interface_line_attribute6)
                                               AND wda.delivery_detail_id =
                                                   wdd.delivery_detail_id
                                               AND tick.delivery_id =
                                                   wda.delivery_id)
                               AND ship.invoice_Date IS NULL
                               AND tick.shipment_id = ship.shipment_id
                               AND NOT EXISTS
                                       (SELECT NULL
                                          FROM wsh_delivery_assignments wda, wsh_delivery_details wdd
                                         WHERE     wda.delivery_id =
                                                   tick.delivery_id
                                               AND wdd.delivery_detail_id =
                                                   wda.delivery_detail_id
                                               AND wdd.source_code = 'OE'
                                               AND NOT EXISTS
                                                       (SELECT NULL
                                                          FROM ra_customer_trx_lines_all
                                                         WHERE     interface_line_context =
                                                                   'ORDER ENTRY'
                                                               AND interface_line_attribute6 =
                                                                   TO_CHAR (
                                                                       wdd.source_line_id))))
                LOOP
                    UPDATE do_edi.do_edi856_shipments ship
                       SET invoice_Date   = TRUNC (SYSDATE)
                     WHERE shipment_id = shipment.shipment_id;

                    wf_event.raise (
                        p_event_name   =>
                            'oracle.apps.xxdo.sps_consolidated_asn_inv_complete',
                        p_event_key   => shipment.shipment_id);
                END LOOP;
            --2.1 changes end
            ELSE
                do_Debug_tools.msg (
                    'Not Raising invoice complete for id: ' || trx.customer_trx_id);
            END IF;
        END LOOP;

        RETURN 'SUCCESS';
    EXCEPTION
        WHEN OTHERS
        THEN
            do_Debug_tools.msg ('Exception ' || SQLERRM);
            wf_event.setErrorInfo (p_event, 'ERROR');
            RETURN 'ERROR';
    END;
END xxdo_business_event_subs;
/
