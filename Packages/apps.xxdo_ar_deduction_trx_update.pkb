--
-- XXDO_AR_DEDUCTION_TRX_UPDATE  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:19 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_AR_DEDUCTION_TRX_UPDATE"
IS
    FUNCTION update_transaction (p_subscription_guid   IN     RAW,
                                 p_event               IN OUT wf_event_t)
        RETURN VARCHAR2
    IS
        l_plist              wf_parameter_list_t := p_event.getparameterlist ();
        lc_brand             hz_cust_accounts.attribute1%TYPE;
        Ln_CUSTOMER_TRX_ID   NUMBER;
        ln_payment_sch_id    NUMBER;
        ln_request_id        NUMBER;

        CURSOR GET_INV_BRAND_ATTRIBUTE (p_payment_schedule_id NUMBER)
        IS
            SELECT hca.attribute1 brand, rcta.customer_trx_id customer_trx_id
              FROM ar_payment_schedules_all apsa, ra_customer_trx_all rcta, hz_cust_accounts hca
             -- ra_batch_sources_all rbsa
             WHERE     apsa.customer_trx_id = rcta.customer_trx_id
                   --AND rcta.attribute5 IS NULL
                   -- AND rcta.batch_source_id = rbsa.batch_source_id
                   AND hca.cust_account_id = apsa.CUSTOMER_ID
                   AND interface_header_context = 'CLAIM'
                   --AND rbsa.name = 'Trade Management'
                   AND apsa.payment_schedule_id = p_payment_schedule_id;

        -- AND rbsa.org_id = rcta.org_id;

        CURSOR GET_TRX_BRAND_ATTRIBUTE (p_customer_trx_id NUMBER)
        IS
            SELECT hca.attribute1 brand
              FROM ra_customer_trx_all rcta, hz_cust_accounts hca
             -- ra_batch_sources_all rbsa
             WHERE     interface_header_context = 'CLAIM' --  rcta.attribute5 IS NULL
                   --AND
                   -- rcta.batch_source_id = rbsa.batch_source_id
                   AND hca.cust_account_id = rcta.BILL_TO_CUSTOMER_ID
                   -- AND rbsa.name = 'Trade Management'
                   AND rcta.customer_trx_id = p_customer_trx_id;

        -- AND rbsa.org_id = rcta.org_id;

        CURSOR get_trx_from_reqid (p_request_id IN NUMBER)
        IS
            SELECT *
              FROM ra_customer_trx_all
             WHERE request_id = p_request_id;
    BEGIN
        ln_customer_trx_id   :=
            p_event.GetValueForParameter ('CUSTOMER_TRX_ID');
        ln_payment_sch_id   :=
            p_event.GetValueForParameter ('PAYMENT_SCHEDULE_ID');
        ln_request_id   := p_event.getvalueforparameter ('REQUEST_ID');

        IF ln_request_id IS NOT NULL
        THEN
            FOR i IN get_trx_from_reqid (ln_request_id)
            LOOP
                OPEN GET_TRX_BRAND_ATTRIBUTE (i.customer_trx_id);

                FETCH GET_TRX_BRAND_ATTRIBUTE INTO lc_brand;

                IF GET_TRX_BRAND_ATTRIBUTE%NOTFOUND
                THEN
                    lc_brand   := NULL;
                END IF;

                CLOSE GET_TRX_BRAND_ATTRIBUTE;

                IF lc_brand IS NOT NULL
                THEN
                    UPDATE ra_customer_trx_all rcta
                       SET attribute5   = lc_brand
                     WHERE rcta.customer_trx_id = i.customer_trx_id;
                END IF;
            END LOOP;
        END IF;

        --P_INSERT('ln_customer_trx_id IS '||ln_customer_trx_id||' AND ln_payment_sch_id IS  '||ln_payment_sch_id||'  bEGIN '||SYSDATE);

        IF p_event.geteventname () =
           'oracle.apps.ar.transaction.Invoice.modify'
        THEN
            OPEN GET_INV_BRAND_ATTRIBUTE (ln_payment_sch_id);

            FETCH GET_INV_BRAND_ATTRIBUTE INTO lc_brand, ln_customer_trx_id;

            IF GET_INV_BRAND_ATTRIBUTE%NOTFOUND
            THEN
                lc_brand   := NULL;
            END IF;

            CLOSE GET_INV_BRAND_ATTRIBUTE;
        ELSE
            OPEN GET_TRX_BRAND_ATTRIBUTE (ln_customer_trx_id);

            FETCH GET_TRX_BRAND_ATTRIBUTE INTO lc_brand;

            IF GET_TRX_BRAND_ATTRIBUTE%NOTFOUND
            THEN
                lc_brand   := NULL;
            END IF;

            CLOSE GET_TRX_BRAND_ATTRIBUTE;
        END IF;

        IF lc_brand IS NOT NULL
        THEN
            UPDATE ra_customer_trx_all rcta
               SET attribute5   = lc_brand
             WHERE rcta.customer_trx_id = ln_customer_trx_id;
        END IF;

        COMMIT;
        --P_INSERT('ln_customer_trx_id IS '||ln_customer_trx_id||' AND ln_payment_sch_id IS  '||ln_payment_sch_id||'  After Commit '||SYSDATE);
        RETURN 'SUCCESS';
    EXCEPTION
        WHEN OTHERS
        THEN
            wf_core.context ('xxdo_creditMemo_BusinessEvent', 'creditMemo_BusinessEvent', p_event.geteventname ()
                             , p_subscription_guid);
            wf_event.seterrorinfo (p_event, 'ERROR');
            RETURN 'ERROR';
    END update_transaction;
END XXDO_AR_DEDUCTION_TRX_UPDATE;
/
