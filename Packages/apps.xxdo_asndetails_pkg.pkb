--
-- XXDO_ASNDETAILS_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:16 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.xxdo_asndetails_pkg
IS
    FUNCTION afterReport
        RETURN BOOLEAN
    IS
        l_result   BOOLEAN := TRUE;
        --    l_proc_name   VARCHAR2 (240) := 'post';
        l_req_id   NUMBER;
        ln_count   NUMBER;
    BEGIN
        SELECT COUNT (*)
          INTO ln_count
          FROM WSH_DELIVERY_DETAILS WDD, WSH_DELIVERY_ASSIGNMENTS WDA, WSH_NEW_DELIVERIES WND,
               APPS.OE_ORDER_LINES_ALL OOL, HZ_CUST_ACCOUNTS HCA_SHIP
         WHERE     WDD.SOURCE_HEADER_ID = OOL.HEADER_ID
               AND WDD.SOURCE_LINE_ID = OOL.LINE_ID
               AND WDA.DELIVERY_DETAIL_ID = WDD.DELIVERY_DETAIL_ID
               AND WDA.DELIVERY_ID = WND.DELIVERY_ID
               AND OOL.SOLD_TO_ORG_ID = HCA_SHIP.CUST_ACCOUNT_ID
               AND HCA_SHIP.ATTRIBUTE14 = 'Y'
               AND WND.DELIVERY_ID IS NOT NULL
               AND OOL.FLOW_STATUS_CODE IN
                       ('SHIPPED', 'CLOSED', 'INTERFACED')
               AND WND.LAST_UPDATE_DATE >=
                   (SELECT MAX (FCR.REQUESTED_START_DATE)
                      FROM FND_CONCURRENT_REQUESTS FCR, FND_CONCURRENT_PROGRAMS FCP
                     WHERE     FCR.CONCURRENT_PROGRAM_ID =
                               FCP.CONCURRENT_PROGRAM_ID
                           AND CONCURRENT_PROGRAM_NAME = 'XXDOASNDETAILS'
                           AND request_id <> fnd_global.conc_request_id);

        fnd_file.put_line (fnd_file.LOG, 'Inside POST START');

        IF ln_count >= 1
        THEN
            l_req_id   :=
                fnd_request.submit_request (
                    application   => 'XDO',                     -- application
                    program       => 'XDOBURSTREP',                 -- Program
                    description   => 'Bursting',                -- description
                    argument1     => 'Y',
                    argument2     => fnd_global.conc_request_id,  -- argument1
                    argument3     => 'Y'                          -- argument2
                                        );

            IF l_req_id != 0
            THEN
                l_result   := TRUE;
            ELSE
                -- Put message in log
                fnd_file.put_line (fnd_file.LOG,
                                   'Failed to launch bursting request');

                -- Return false to trigger error result
                l_result   := FALSE;
            END IF;
        END IF;

        RETURN l_result;
    END afterReport;

    FUNCTION SMTP_HOST
        RETURN VARCHAR2
    IS
        SMPT_SERVER   VARCHAR2 (200);
    BEGIN
        SELECT fscpv.parameter_value smtp_host
          INTO SMPT_SERVER
          FROM fnd_svc_comp_params_tl fscpt, fnd_svc_comp_param_vals fscpv, fnd_svc_components fsc
         WHERE     fscpt.parameter_id = fscpv.parameter_id
               AND fscpv.component_id = fsc.component_id
               AND fscpt.display_name = 'Outbound Server Name'
               AND fsc.component_name = 'Workflow Notification Mailer';

        RETURN SMPT_SERVER;
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.put_line (
                'Unable to get SMTP Server Name for emailing');
    END SMTP_HOST;
END xxdo_asndetails_pkg;
/
