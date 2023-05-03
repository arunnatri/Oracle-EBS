--
-- XXDO_XXDOOPCLEXT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:32:00 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_XXDOOPCLEXT_PKG"
IS
    FUNCTION AFTERREPORT (P_EMAIL IN VARCHAR2, RELATED_CLAIM_NUMBER VARCHAR2)
        RETURN BOOLEAN
    IS
        L_RESULT   BOOLEAN;
        L_REQ_ID   NUMBER;
        LN_COUNT   NUMBER;
    BEGIN
        COMMIT;
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'Inside POST START');


        IF P_EMAIL = 'Yes' AND RELATED_CLAIM_NUMBER IS NOT NULL
        THEN
            L_REQ_ID   :=
                FND_REQUEST.SUBMIT_REQUEST (
                    APPLICATION   => 'XDO',                     -- APPLICATION
                    PROGRAM       => 'XDOBURSTREP',                 -- PROGRAM
                    DESCRIPTION   => 'Bursting',                -- DESCRIPTION
                    ARGUMENT1     => 'N',
                    ARGUMENT2     => FND_GLOBAL.CONC_REQUEST_ID,
                    -- ARGUMENT1
                    ARGUMENT3     => 'Y'                          -- ARGUMENT2
                                        );
        END IF;

        RETURN TRUE;
    END AFTERREPORT;

    -- Added Function for CCR0007639

    FUNCTION BeforeReport
        RETURN BOOLEAN
    IS
        l_request_id       NUMBER;
        l_req_boolean      BOOLEAN;
        l_req_phase        VARCHAR2 (30);
        l_req_status       VARCHAR2 (30);
        l_req_dev_phase    VARCHAR2 (30);
        l_req_dev_status   VARCHAR2 (30);
        l_req_message      VARCHAR2 (4000);
    BEGIN
        COMMIT;
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'Inside Before Report Function');


        l_request_id   :=
            fnd_request.submit_request (application => 'XXDO',  -- APPLICATION
                                                               program => 'XXD_OZF_CLAIM_APPRV_SETTLEMENT', -- PROGRAM
                                                                                                            description => 'Claim Approver with Settlement Method - Deckers'
                                        ,                       -- DESCRIPTION
                                          start_time => SYSDATE);

        IF l_request_id <> 0
        THEN
            COMMIT;
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'Claim Approver Update Request ID = ' || l_request_id);
        ELSIF l_request_id = 0
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'Request Not Submitted due to "'
                || apps.fnd_message.get
                || '".');
        END IF;

        --===IF successful RETURN ar customer trx id as OUT parameter;
        IF l_request_id > 0
        THEN
            LOOP
                l_req_boolean   :=
                    apps.fnd_concurrent.wait_for_request (l_request_id,
                                                          15,
                                                          0,
                                                          l_req_phase,
                                                          l_req_status,
                                                          l_req_dev_phase,
                                                          l_req_dev_status,
                                                          l_req_message);
                EXIT WHEN    UPPER (l_req_phase) = 'COMPLETED'
                          OR UPPER (l_req_status) IN
                                 ('CANCELLED', 'ERROR', 'TERMINATED');
            END LOOP;

            IF     UPPER (l_req_phase) = 'COMPLETED'
               AND UPPER (l_req_status) = 'ERROR'
            THEN
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                       'The Claim approver update Request completed in error. See log for request id:'
                    || l_request_id);
                apps.fnd_file.put_line (apps.fnd_file.LOG, SQLERRM);
            ELSIF     UPPER (l_req_phase) = 'COMPLETED'
                  AND UPPER (l_req_status) = 'NORMAL'
            THEN
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                    'Claim approver update request id: ' || l_request_id);
            ELSE
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                       'Claim approver update request failed.Review log for Oracle request id '
                    || l_request_id);
                apps.fnd_file.put_line (apps.fnd_file.LOG, SQLERRM);
            END IF;
        END IF;

        RETURN TRUE;
    END BeforeReport;

    -- End of Change

    FUNCTION SMTP_HOST
        RETURN VARCHAR2
    IS
        SMPT_SERVER   VARCHAR2 (200);
    BEGIN
        SELECT FSCPV.PARAMETER_VALUE SMTP_HOST
          INTO SMPT_SERVER
          FROM FND_SVC_COMP_PARAMS_TL FSCPT, FND_SVC_COMP_PARAM_VALS FSCPV, FND_SVC_COMPONENTS FSC
         WHERE     FSCPT.PARAMETER_ID = FSCPV.PARAMETER_ID
               AND FSCPV.COMPONENT_ID = FSC.COMPONENT_ID
               AND FSCPT.DISPLAY_NAME = 'Outbound Server Name'
               AND FSC.COMPONENT_NAME = 'Workflow Notification Mailer';

        RETURN SMPT_SERVER;
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.PUT_LINE (
                'Unable to get SMTP Server Name for emailing');
    END SMTP_HOST;

    FUNCTION XXDO_GET_SETTLEMENT_DETAILS (P_SETTLEMENT_NUMBER NUMBER, P_ORG_ID NUMBER, P_COLUMN VARCHAR2
                                          , P_PAY_METHOD VARCHAR2)
        RETURN VARCHAR2
    AS
        --RET_VALUE   VARCHAR2 (100);
        RET_VALUE   VARCHAR2 (2000);
    BEGIN
        IF P_COLUMN = 'TRX_NUMBER' AND P_PAY_METHOD <> 'ADJUSTMENT'
        THEN
            SELECT TRX_NUMBER
              INTO RET_VALUE
              FROM RA_CUSTOMER_TRX_ALL
             WHERE     CUSTOMER_TRX_ID = P_SETTLEMENT_NUMBER
                   AND ORG_ID = P_ORG_ID;
        ELSIF P_COLUMN = 'TRX_NUMBER' AND P_PAY_METHOD = 'ADJUSTMENT'
        THEN
            SELECT ADJUSTMENT_NUMBER
              INTO RET_VALUE
              FROM AR_ADJUSTMENTS_ALL
             WHERE     ADJUSTMENT_NUMBER = P_SETTLEMENT_NUMBER
                   AND ORG_ID = P_ORG_ID;
        ELSIF P_COLUMN = 'STATUS_TRX' AND P_PAY_METHOD <> 'ADJUSTMENT'
        THEN
            SELECT flv.meaning
              INTO RET_VALUE
              FROM RA_CUSTOMER_TRX_ALL, FND_LOOKUP_VALUES FLV
             WHERE     CUSTOMER_TRX_ID = P_SETTLEMENT_NUMBER
                   AND ORG_ID = P_ORG_ID
                   AND FLV.LOOKUP_CODE(+) = STATUS_TRX
                   AND FLV.ENABLED_FLAG(+) = 'Y'
                   AND FLV.LANGUAGE(+) = USERENV ('LANG')
                   AND FLV.LOOKUP_TYPE(+) = 'INVOICE_TRX_STATUS';
        ELSIF P_COLUMN = 'STATUS_TRX' AND P_PAY_METHOD = 'ADJUSTMENT'
        THEN
            SELECT FLV.meaning
              INTO RET_VALUE
              FROM AR_ADJUSTMENTS_ALL, FND_LOOKUP_VALUES FLV
             WHERE     ADJUSTMENT_NUMBER = P_SETTLEMENT_NUMBER
                   AND ORG_ID = P_ORG_ID
                   AND FLV.LOOKUP_CODE(+) = STATUS
                   AND FLV.ENABLED_FLAG(+) = 'Y'
                   AND FLV.LANGUAGE(+) = USERENV ('LANG')
                   AND FLV.LOOKUP_TYPE(+) = 'APPROVAL_TYPE';
        ELSIF P_COLUMN = 'TRX_DATE' AND P_PAY_METHOD <> 'ADJUSTMENT'
        THEN
            SELECT TRX_DATE
              INTO RET_VALUE
              FROM RA_CUSTOMER_TRX_ALL
             WHERE     CUSTOMER_TRX_ID = P_SETTLEMENT_NUMBER
                   AND ORG_ID = P_ORG_ID;
        ELSIF P_COLUMN = 'TRX_DATE' AND P_PAY_METHOD = 'ADJUSTMENT'
        THEN
            SELECT APPLY_DATE
              INTO RET_VALUE
              FROM AR_ADJUSTMENTS_ALL
             WHERE     ADJUSTMENT_NUMBER = P_SETTLEMENT_NUMBER
                   AND ORG_ID = P_ORG_ID;
        ELSIF P_COLUMN = 'REASON_CODE' AND P_PAY_METHOD <> 'ADJUSTMENT'
        THEN
            SELECT REASON_CODE
              INTO RET_VALUE
              FROM RA_CUSTOMER_TRX_ALL
             WHERE     CUSTOMER_TRX_ID = P_SETTLEMENT_NUMBER
                   AND ORG_ID = P_ORG_ID;
        ELSIF P_COLUMN = 'REASON_CODE' AND P_PAY_METHOD = 'ADJUSTMENT'
        THEN
            SELECT REASON_CODE
              INTO RET_VALUE
              FROM AR_ADJUSTMENTS_ALL
             WHERE     ADJUSTMENT_NUMBER = P_SETTLEMENT_NUMBER
                   AND ORG_ID = P_ORG_ID;
        ELSIF P_COLUMN = 'COMMENTS' AND P_PAY_METHOD <> 'ADJUSTMENT'
        THEN
            SELECT COMMENTS
              INTO RET_VALUE
              FROM RA_CUSTOMER_TRX_ALL
             WHERE     CUSTOMER_TRX_ID = P_SETTLEMENT_NUMBER
                   AND ORG_ID = P_ORG_ID;
        ELSIF P_COLUMN = 'COMMENTS' AND P_PAY_METHOD = 'ADJUSTMENT'
        THEN
            SELECT COMMENTS
              INTO RET_VALUE
              FROM AR_PAYMENT_SCHEDULES_ALL APS, RA_CUSTOMER_TRX_ALL RCTA
             WHERE     APS.CUSTOMER_TRX_ID = RCTA.CUSTOMER_TRX_ID
                   AND RCTA.CUSTOMER_TRX_ID = P_SETTLEMENT_NUMBER
                   AND RCTA.ORG_ID = P_ORG_ID;
        ELSIF P_COLUMN = 'DUE_DATE'
        THEN
            SELECT DUE_DATE
              INTO RET_VALUE
              FROM AR_PAYMENT_SCHEDULES_ALL APS, RA_CUSTOMER_TRX_ALL RCTA
             WHERE     APS.CUSTOMER_TRX_ID = RCTA.CUSTOMER_TRX_ID
                   AND RCTA.CUSTOMER_TRX_ID = P_SETTLEMENT_NUMBER
                   AND RCTA.ORG_ID = P_ORG_ID;
        ELSIF P_COLUMN = 'AMOUNT_DUE_ORIGINAL'
        THEN
            SELECT AMOUNT_DUE_ORIGINAL
              INTO RET_VALUE
              FROM AR_PAYMENT_SCHEDULES_ALL APS, RA_CUSTOMER_TRX_ALL RCTA
             WHERE     APS.CUSTOMER_TRX_ID = RCTA.CUSTOMER_TRX_ID
                   AND RCTA.CUSTOMER_TRX_ID = P_SETTLEMENT_NUMBER
                   AND RCTA.ORG_ID = P_ORG_ID;
        ELSIF P_COLUMN = 'AMOUNT_APPLIED'
        THEN
            SELECT AMOUNT_APPLIED
              INTO RET_VALUE
              FROM AR_PAYMENT_SCHEDULES_ALL APS, RA_CUSTOMER_TRX_ALL RCTA
             WHERE     APS.CUSTOMER_TRX_ID = RCTA.CUSTOMER_TRX_ID
                   AND RCTA.CUSTOMER_TRX_ID = P_SETTLEMENT_NUMBER
                   AND RCTA.ORG_ID = P_ORG_ID;
        ELSIF P_COLUMN = 'AMOUNT_ADJUSTED'
        THEN
            SELECT AMOUNT_ADJUSTED
              INTO RET_VALUE
              FROM AR_PAYMENT_SCHEDULES_ALL APS, RA_CUSTOMER_TRX_ALL RCTA
             WHERE     APS.CUSTOMER_TRX_ID = RCTA.CUSTOMER_TRX_ID
                   AND RCTA.CUSTOMER_TRX_ID = P_SETTLEMENT_NUMBER
                   AND RCTA.ORG_ID = P_ORG_ID;
        ELSIF P_COLUMN = 'AMOUNT_IN_DISPUTE'
        THEN
            SELECT AMOUNT_IN_DISPUTE
              INTO RET_VALUE
              FROM AR_PAYMENT_SCHEDULES_ALL APS, RA_CUSTOMER_TRX_ALL RCTA
             WHERE     APS.CUSTOMER_TRX_ID = RCTA.CUSTOMER_TRX_ID
                   AND RCTA.CUSTOMER_TRX_ID = P_SETTLEMENT_NUMBER
                   AND RCTA.ORG_ID = P_ORG_ID;
        ELSIF P_COLUMN = 'AMOUNT_CREDITED'
        THEN
            SELECT AMOUNT_CREDITED
              INTO RET_VALUE
              FROM AR_PAYMENT_SCHEDULES_ALL APS, RA_CUSTOMER_TRX_ALL RCTA
             WHERE     APS.CUSTOMER_TRX_ID = RCTA.CUSTOMER_TRX_ID
                   AND RCTA.CUSTOMER_TRX_ID = P_SETTLEMENT_NUMBER
                   AND RCTA.ORG_ID = P_ORG_ID;
        ELSIF P_COLUMN = 'AMOUNT_DUE_REMAINING'
        THEN
            SELECT AMOUNT_DUE_REMAINING
              INTO RET_VALUE
              FROM AR_PAYMENT_SCHEDULES_ALL APS, RA_CUSTOMER_TRX_ALL RCTA
             WHERE     APS.CUSTOMER_TRX_ID = RCTA.CUSTOMER_TRX_ID
                   AND RCTA.CUSTOMER_TRX_ID = P_SETTLEMENT_NUMBER
                   AND RCTA.ORG_ID = P_ORG_ID;
        ELSIF P_COLUMN = 'ACTUAL_DATE_CLOSED'
        THEN
            SELECT ACTUAL_DATE_CLOSED
              INTO RET_VALUE
              FROM AR_PAYMENT_SCHEDULES_ALL APS, RA_CUSTOMER_TRX_ALL RCTA
             WHERE     APS.CUSTOMER_TRX_ID = RCTA.CUSTOMER_TRX_ID
                   AND RCTA.CUSTOMER_TRX_ID = P_SETTLEMENT_NUMBER
                   AND RCTA.ORG_ID = P_ORG_ID;
        ELSIF P_COLUMN = 'ACTUAL_DATE_CLOSED'
        THEN
            SELECT ACTUAL_DATE_CLOSED
              INTO RET_VALUE
              FROM AR_PAYMENT_SCHEDULES_ALL APS, RA_CUSTOMER_TRX_ALL RCTA
             WHERE     APS.CUSTOMER_TRX_ID = RCTA.CUSTOMER_TRX_ID
                   AND RCTA.CUSTOMER_TRX_ID = P_SETTLEMENT_NUMBER
                   AND RCTA.ORG_ID = P_ORG_ID;
        ELSIF     P_COLUMN = 'CONCATENATED_SEGMENTS'
              AND P_PAY_METHOD <> 'ADJUSTMENT'
        THEN
            SELECT GLCCK.CONCATENATED_SEGMENTS
              INTO RET_VALUE
              FROM GL_CODE_COMBINATIONS_KFV GLCCK, RA_CUST_TRX_TYPES_ALL RCTT, RA_CUSTOMER_TRX_ALL RCTA
             WHERE     RCTA.CUSTOMER_TRX_ID = P_SETTLEMENT_NUMBER
                   AND RCTT.CUST_TRX_TYPE_ID = RCTA.CUST_TRX_TYPE_ID
                   AND RCTT.GL_ID_REV = GLCCK.CODE_COMBINATION_ID
                   AND RCTA.ORG_ID = P_ORG_ID;
        ELSIF     P_COLUMN = 'CONCATENATED_SEGMENTS'
              AND P_PAY_METHOD = 'ADJUSTMENT'
        THEN
            SELECT GLCCK.CONCATENATED_SEGMENTS
              INTO RET_VALUE
              FROM GL_CODE_COMBINATIONS_KFV GLCCK, AR_ADJUSTMENTS_ALL ARA
             WHERE     ARA.ADJUSTMENT_NUMBER = P_SETTLEMENT_NUMBER
                   AND ARA.CODE_COMBINATION_ID = GLCCK.CODE_COMBINATION_ID
                   AND ARA.ORG_ID = P_ORG_ID;
        ELSIF P_COLUMN = 'ORDER_NUMBER'
        THEN
            SELECT INTERFACE_HEADER_ATTRIBUTE1
              INTO RET_VALUE
              FROM RA_CUSTOMER_TRX_ALL
             WHERE     CUSTOMER_TRX_ID = P_SETTLEMENT_NUMBER
                   AND ORG_ID = P_ORG_ID;
        ELSIF P_COLUMN = 'PURCHASE_ORDER'
        THEN
            SELECT PURCHASE_ORDER
              INTO RET_VALUE
              FROM RA_CUSTOMER_TRX_ALL
             WHERE     CUSTOMER_TRX_ID = P_SETTLEMENT_NUMBER
                   AND ORG_ID = P_ORG_ID;
        ELSIF P_COLUMN = 'TERMS'
        THEN
            SELECT RT.NAME
              INTO RET_VALUE
              FROM RA_TERMS RT, RA_CUSTOMER_TRX_ALL RCTA
             WHERE     RCTA.TERM_ID = RT.TERM_ID
                   AND RCTA.CUSTOMER_TRX_ID = P_SETTLEMENT_NUMBER
                   AND RCTA.ORG_ID = P_ORG_ID;
        END IF;

        RETURN RET_VALUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RET_VALUE   := ' ';
            RETURN RET_VALUE;
    END XXDO_GET_SETTLEMENT_DETAILS;
END XXDO_XXDOOPCLEXT_PKG;
/
