--
-- XXD_OZF_CLAIM_APPR_UPDATE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:03 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_OZF_CLAIM_APPR_UPDATE_PKG"
AS
    /***********************************************************************************
      *$header     :                                                                   *
      *                                                                                *
      * AUTHORS    :  Srinath Siricilla                                                *
      *                                                                                *
      * PURPOSE    :  New program to Update the Approver ame along with Settlement     *
      *               Method                                                           *
      *                                                                                *
      * PARAMETERS :                                                                   *
      *                                                                                *
      * DATE       :  16-NOV-2018                                                      *
      *                                                                                *
      * Assumptions:                                                                   *
      *                                                                                *
      *                                                                                *
      * History                                                                        *
      * Vsn     Change Date  Changed By            Change Description                  *
      * -----   -----------  ------------------    ------------------------------------*
      * 1.0     16-NOV-2018  Srinath Siricilla     Initial Change as part of CCR0007639*
      * 2.0     09-DEC-2020  Greg Jensen           CCR0009019                          *
      *********************************************************************************/
    PROCEDURE MAIN (p_ret_code OUT VARCHAR2, p_err_msg OUT VARCHAR2)
    IS
        CURSOR cur_claims IS
            SELECT oz.claim_id, oz.claim_number, oz.status_code,
                   oz.creation_date, oz.payment_method, wf.recipient_role,
                   wf.notification_id, jre.source_name
              FROM apps.ozf_claims_all oz, apps.wf_notifications wf, apps.JTF_RS_RESOURCE_EXTNS_VL jre
             WHERE     1 = 1
                   AND oz.appr_wf_item_key = wf.item_key
                   AND wf.MESSAGE_TYPE = 'AMSGAPP'
                   AND wf.message_name = 'AMS_APPROVAL_REQUIRED'
                   AND jre.category = 'EMPLOYEE'
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (
                                                       jre.start_date_active,
                                                       SYSDATE))
                                           AND TRUNC (
                                                   NVL (jre.end_date_active,
                                                        SYSDATE))
                   AND jre.user_name = wf.recipient_role
                   --     AND  oz.appr_wf_item_key IS NOT NULL
                   AND wf.status <> 'CLOSED' --Added by Madhav to fix UAT defect
                   AND Oz.Group_Claim_Id IS NULL --Added by Madhav to fix UAT defect
                   AND status_code = 'PENDING_APPROVAL'
            -----------------------------
            --Added by Madhav for Mass settlement
            ------------------------------
            UNION
            SELECT oz1.claim_id, oz1.claim_number, oz1.status_code,
                   oz1.creation_date, NVL (osd.payment_method, oz1.payment_method), wf.recipient_role,
                   wf.notification_id, jre.source_name
              FROM apps.ozf_claims_all oz, apps.wf_notifications wf, apps.JTF_RS_RESOURCE_EXTNS_VL jre,
                   apps.ozf_claims_all oz1, apps.OZF_SETTLEMENT_DOCS_ALL osd
             WHERE     1 = 1
                   AND oz.appr_wf_item_key = wf.item_key
                   AND wf.MESSAGE_TYPE = 'AMSGAPP'
                   AND wf.message_name = 'AMS_APPROVAL_REQUIRED'
                   AND jre.category = 'EMPLOYEE'
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (
                                                       jre.start_date_active,
                                                       SYSDATE))
                                           AND TRUNC (
                                                   NVL (jre.end_date_active,
                                                        SYSDATE))
                   AND jre.user_name = wf.recipient_role
                   --     AND  oz.appr_wf_item_key IS NOT NULL
                   AND wf.status <> 'CLOSED' --Added by Madhav to fix UAT defect
                   AND Oz.Group_Claim_Id IS NULL --Added by Madhav to fix UAT defect
                   AND oz.status_code = 'PENDING_APPROVAL'
                   AND oz.claim_id = oz1.Group_Claim_Id
                   AND oz1.claim_id = osd.claim_id(+)
                   AND Oz1.Group_Claim_Id IS NOT NULL --FOR UPDATE SKIP LOCKED
                                                     ;

        ln_count   NUMBER;
    BEGIN
        ln_count   := 0;

        FOR i IN cur_claims
        LOOP
            BEGIN
                UPDATE apps.ozf_claims_all ozf
                   SET ozf.attribute1   = i.source_name,
                       ozf.attribute2   =
                           (SELECT meaning
                              FROM apps.ozf_lookups
                             WHERE     lookup_type = 'OZF_PAYMENT_METHOD'
                                   AND lookup_code = i.payment_method)
                 WHERE     1 = 1
                       --AND  NVL(ozf.group_claim_id,ozf.claim_id) = i.claim_id
                       AND ozf.claim_id = i.claim_id
                       AND ozf.status_code = 'PENDING_APPROVAL';

                --     AND ozf.attribute2 IS NULL;---Removed per CCR0009019

                /*      OR ozf.attribute2 <>---Removed per CCR0009019
                            (SELECT meaning
                               FROM apps.ozf_lookups
                              WHERE     lookup_type = 'OZF_PAYMENT_METHOD'
                                    AND lookup_code = i.payment_method));*/

                --fnd_file.put_line(fnd_file.log,'Claim Number = '||i.claim_number||' Payment Method = '||i.payment_method);
                ln_count   := ln_count + SQL%ROWCOUNT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ROLLBACK;
            END;
        END LOOP;

        fnd_file.put_line (
            fnd_file.LOG,
               'The Total Number of Pending_approval Records updates are = '
            || ln_count);

        BEGIN
            --For regular settlements
            UPDATE apps.ozf_claims_all ozf
               SET attribute1   = NULL,
                   attribute2   =
                       (SELECT meaning
                          FROM apps.ozf_lookups
                         WHERE     lookup_type = 'OZF_PAYMENT_METHOD'
                               AND lookup_code = ozf.payment_method)
             WHERE     status_code <> 'PENDING_APPROVAL'
                   AND OzF.Group_Claim_Id IS NULL
                   AND OZF.PAYMENT_METHOD IS NOT NULL
                   AND (   ozf.attribute2 IS NULL
                        OR ozf.attribute2 <>
                           (SELECT meaning
                              FROM apps.ozf_lookups
                             WHERE     lookup_type = 'OZF_PAYMENT_METHOD'
                                   AND lookup_code = ozf.payment_method)) --FOR UPDATE SKIP LOCKED
                                                                         ;

            fnd_file.put_line (
                fnd_file.LOG,
                   'The Total Number of Records NON-PENDING_APPROVAL NON-MASS-SETTLEMENT updates are = '
                || SQL%ROWCOUNT);

            --For Mass settlements
            UPDATE apps.ozf_claims_all ozf
               SET attribute1   = NULL,
                   attribute2   =
                       (SELECT MAX (meaning)
                          FROM apps.ozf_lookups ozl, apps.OZF_SETTLEMENT_DOCS_ALL osd
                         WHERE     ozl.lookup_type = 'OZF_PAYMENT_METHOD'
                               AND osd.claim_id = ozf.claim_id
                               AND ozl.lookup_code =
                                   NVL (osd.payment_method,
                                        ozf.payment_method))
             WHERE     status_code <> 'PENDING_APPROVAL'
                   AND OzF.Group_Claim_Id IS NOT NULL
                   AND (   ozf.attribute2 IS NULL
                        OR attribute2 <>
                           (SELECT MAX (meaning)
                              FROM apps.ozf_lookups ozl, apps.OZF_SETTLEMENT_DOCS_ALL osd
                             WHERE     ozl.lookup_type = 'OZF_PAYMENT_METHOD'
                                   AND osd.claim_id = ozf.claim_id
                                   AND ozl.lookup_code =
                                       NVL (osd.payment_method,
                                            ozf.payment_method))) --FOR UPDATE SKIP LOCKED
                                                                 ;

            fnd_file.put_line (
                fnd_file.LOG,
                   'The Total Number of Records NON-PENDING_APPROVAL MASS-SETTLEMENT updates are = '
                || SQL%ROWCOUNT);
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Exception updating non-Pending approval = ' || SQLERRM);
                ROLLBACK;
        END;

        COMMIT;
    END MAIN;
END XXD_OZF_CLAIM_APPR_UPDATE_PKG;
/
