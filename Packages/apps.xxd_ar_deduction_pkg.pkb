--
-- XXD_AR_DEDUCTION_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:30 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_AR_DEDUCTION_PKG"
AS
    /************************************************************************************************
    * Package         : APPS.XXD_AR_DEDUCTION_PKG
    * Author         : BT Technology Team
    * Created         : 03-APR-2015
    * Program Name  : XXD_AR_DEDUCTION_PKG
    * Description     : Pogram for claim updates
    *
    * Modification  :
    *-----------------------------------------------------------------------------------------------
    *     Date         Developer             Version     Description
    *-----------------------------------------------------------------------------------------------
    *     03-Apr-2015 BT Technology Team     V1.1         Development    Pogram for claim updates
    ************************************************************************************************/

    PROCEDURE Xxd_Set_Approver_Details (itemtype    IN            VARCHAR2,
                                        itemkey     IN            VARCHAR2,
                                        actid       IN            NUMBER,
                                        funcmode    IN            VARCHAR2,
                                        resultout      OUT NOCOPY VARCHAR2)
    AS
        l_name                    VARCHAR2 (100);
        l_org_id                  NUMBER;
        l_claim_amount            NUMBER;
        l_owner_id                NUMBER;
        l_cust_account_id         NUMBER;
        l_site_id                 NUMBER;
        l_created_by              NUMBER;
        l_return_status           VARCHAR2 (10);
        l_flag                    VARCHAR2 (10);
        l_brand                   VARCHAR2 (100);
        l_appr_lkdetail_id        NUMBER;
        l_approver_id             NUMBER;
        l_approver                VARCHAR2 (100);
        l_approver_display_name   VARCHAR2 (1000);
        l_object_approver_id      NUMBER;
        l_activity_id             NUMBER;
        l_claim_type_id           NUMBER;
        l_code_name               VARCHAR2 (100);
        l_type_name               VARCHAR2 (100);
        l_reason_code_id          NUMBER;
        l_update_req              NUMBER;
        l_cash_approver           VARCHAR2 (100);
        l_resource_id             NUMBER;
        l_display_name            VARCHAR2 (100);
        l_approver_name           VARCHAR2 (1000);
        l_set_flag                VARCHAR2 (10) := 'N';
    BEGIN
        IF (funcmode = 'RUN')
        THEN
            l_activity_id   :=
                wf_engine.GetItemAttrText (itemtype   => itemtype,
                                           itemkey    => itemkey,
                                           aname      => 'AMS_ACTIVITY_ID');

            l_approver_id   :=
                wf_engine.GetItemAttrText (itemtype   => itemtype,
                                           itemkey    => itemkey,
                                           aname      => 'AMS_APPROVER_ID');


            l_approver_name   :=
                wf_engine.GetItemAttrText (itemtype   => itemtype,
                                           itemkey    => itemkey,
                                           aname      => 'AMS_APPROVER');

            l_approver_display_name   :=
                wf_engine.GetItemAttrText (
                    itemtype   => itemtype,
                    itemkey    => itemkey,
                    aname      => 'AMS_APPROVER_DISPLAY_NAME');


            BEGIN
                SELECT oct.NAME, OCR.name, OCR.reason_code_id,
                       oct.claim_type_id, oct.org_id, oca.amount,
                       oca.owner_id, oca.cust_account_id, oca.cust_billto_acct_site_id,
                       oca.created_by
                  INTO l_type_name, l_code_name, l_reason_code_id, l_claim_type_id,
                                  l_org_id, l_claim_amount, l_owner_id,
                                  l_cust_account_id, l_site_id, l_created_by
                  FROM ozf_claim_types_all_tl oct, ozf_claims_all oca, OZF_REASON_CODES_ALL_TL OCR
                 WHERE     oct.claim_type_id = oca.claim_type_id
                       AND ocr.reason_code_id = oca.reason_code_id
                       AND OCR.language = USERENV ('LANG')
                       AND oct.language = USERENV ('LANG')
                       AND claim_id = l_activity_id;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    l_name              := NULL;
                    l_cust_account_id   := NULL;
                    l_site_id           := NULL;
            END;

            BEGIN
                SELECT user_name, ajt.resource_id, ajt.full_name
                  INTO l_approver, l_resource_id, l_display_name
                  FROM fnd_user FU, ams_jtf_rs_emp_v AJT
                 WHERE AJT.user_id = FU.user_id AND fu.user_id = l_created_by;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_approver   := NULL;
            END;

            BEGIN
                SELECT user_name
                  INTO l_cash_approver
                  FROM fnd_user FU, ams_jtf_rs_emp_v AJT
                 WHERE     AJT.user_id = FU.user_id --AND AJT.resource_id = l_approver_id
                       AND AJT.FULL_NAME LIKE 'Application%Cash%';
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_cash_approver   := NULL;
                    l_resource_id     := NULL;
            END;

            IF UPPER (l_approver_name) = UPPER ('Researcher')
            THEN
                l_approver_id   := l_owner_id;
                l_set_flag      := 'Y';
            ELSIF UPPER (l_approver_name) = UPPER (l_cash_approver)
            THEN
                l_approver_id   := l_resource_id;
                l_set_flag      := 'Y';
            END IF;


            IF l_set_flag = 'Y'
            THEN
                wf_engine.SetItemAttrText (itemtype => itemtype, itemkey => itemkey, aname => 'AMS_APPROVER_ID'
                                           , avalue => l_approver_id);
                wf_engine.SetItemAttrText (itemtype => itemtype, itemkey => itemkey, aname => 'AMS_APPROVER'
                                           , avalue => l_approver);
                wf_engine.SetItemAttrText (itemtype => itemtype, itemkey => itemkey, aname => 'AMS_APPROVER_DISPLAY_NAME'
                                           , avalue => l_display_name);

                UPDATE AMS_APPROVAL_HISTORY
                   SET approver_id   = l_approver_id
                 WHERE object_id = l_activity_id AND action_code = 'PENDING';
            END IF;

            resultout   := 'COMPLETE:ERROR';
        ELSE
            resultout   := 'COMPLETE:SUCCESS';
        END IF;

        resultout   := 'COMPLETE:SUCCESS';
    EXCEPTION
        WHEN OTHERS
        THEN
            wf_core.context ('xxd_set_approver_details', 'xxd_set_approver_details', itemtype
                             , itemkey, TO_CHAR (actid), SQLERRM);
            -- RAISE;
            resultout   := 'COMPLETE:ERROR';
    END;

    PROCEDURE XXD_FIND_RESEARCHER (p_brand               IN     VARCHAR2,
                                   p_reason_code_id      IN     NUMBER,
                                   p_org_id              IN     NUMBER,
                                   p_major_customer_id   IN     NUMBER,
                                   p_cust_account_id     IN     NUMBER,
                                   p_acct_site_id        IN     NUMBER,
                                   p_state               IN     VARCHAR2,
                                   x_researcher_id          OUT VARCHAR2)
    AS
        l_researcher_id     NUMBER;
        l_researcher_type   VARCHAR2 (100);
        l_party_dff         VARCHAR2 (100);
        l_resource_id       NUMBER;
        l_reassighn_user    VARCHAR2 (100);
    BEGIN
        BEGIN
            SELECT attribute5
              INTO l_researcher_id
              FROM fnd_lookup_values
             WHERE     lookup_type = 'XXDO_CLM_MAJOR_ACCT_MATRIX'
                   AND enabled_flag = 'Y'
                   AND SYSDATE BETWEEN START_DATE_ACTIVE
                                   AND NVL (END_DATE_ACTIVE, SYSDATE)
                   AND language = USERENV ('LANG')
                   AND attribute1 = p_org_id
                   AND attribute3 = p_reason_code_id
                   AND attribute4 = p_major_customer_id
                   AND attribute2 = p_brand;          -- Added for defect 3304

            x_researcher_id   := l_researcher_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                -- Start Added for defect 3304
                BEGIN
                    SELECT attribute5
                      INTO l_researcher_id
                      FROM fnd_lookup_values
                     WHERE     lookup_type = 'XXDO_CLM_MAJOR_ACCT_MATRIX'
                           AND enabled_flag = 'Y'
                           AND SYSDATE BETWEEN START_DATE_ACTIVE
                                           AND NVL (END_DATE_ACTIVE, SYSDATE)
                           AND language = USERENV ('LANG')
                           AND attribute1 = p_org_id
                           AND attribute3 = p_reason_code_id
                           AND attribute4 = p_major_customer_id
                           AND attribute2 = 'ALL BRAND'; -- Added for defect 3304

                    x_researcher_id   := l_researcher_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        l_researcher_id   := NULL;
                END;
        -- End Added for defect 3304


        END;

        IF l_researcher_id IS NULL
        THEN
            BEGIN
                SELECT attribute5, attribute4, attribute7
                  INTO l_researcher_id, l_researcher_type, l_party_dff
                  FROM fnd_lookup_values
                 WHERE     lookup_type = 'XXDO_CLM_MST_RESEARCHER_MATRIX'
                       AND enabled_flag = 'Y'
                       AND SYSDATE BETWEEN START_DATE_ACTIVE
                                       AND NVL (END_DATE_ACTIVE, SYSDATE)
                       AND language = USERENV ('LANG')
                       AND attribute1 = p_org_id
                       AND attribute2 = p_brand
                       AND attribute3 = p_reason_code_id
                       AND attribute6 IS NULL;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    BEGIN
                        SELECT attribute5, attribute4, attribute7
                          INTO l_researcher_id, l_researcher_type, l_party_dff
                          FROM fnd_lookup_values
                         WHERE     lookup_type =
                                   'XXDO_CLM_MST_RESEARCHER_MATRIX'
                               AND enabled_flag = 'Y'
                               AND SYSDATE BETWEEN START_DATE_ACTIVE
                                               AND NVL (END_DATE_ACTIVE,
                                                        SYSDATE)
                               AND language = USERENV ('LANG')
                               AND attribute1 = p_org_id
                               AND attribute2 = p_brand
                               AND attribute3 = p_reason_code_id
                               AND attribute6 = p_state;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            BEGIN
                                SELECT attribute5, attribute4, attribute7
                                  INTO l_researcher_id, l_researcher_type, l_party_dff
                                  FROM fnd_lookup_values
                                 WHERE     lookup_type =
                                           'XXDO_CLM_MST_RESEARCHER_MATRIX'
                                       AND enabled_flag = 'Y'
                                       AND SYSDATE BETWEEN START_DATE_ACTIVE
                                                       AND NVL (
                                                               END_DATE_ACTIVE,
                                                               SYSDATE)
                                       AND language = USERENV ('LANG')
                                       AND attribute1 = p_org_id
                                       AND attribute2 = p_brand
                                       AND attribute6 = p_state;
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    l_researcher_id     := NULL;
                                    l_researcher_type   := NULL;
                                    l_party_dff         := NULL;
                            END;
                    END;
            END;

            IF l_researcher_type IS NOT NULL
            THEN
                IF l_researcher_type = 'Team'
                THEN
                    x_researcher_id   := l_researcher_id;
                ELSIF l_researcher_type = 'Person'
                THEN
                    x_researcher_id   := l_researcher_id;
                ELSIF    l_researcher_type = 'Collector'
                      OR l_researcher_type = 'Salesrep'
                THEN
                    SELECT DECODE (l_researcher_type,  'Collector', ac.collector_id,  'Salesrep', sr.salesrep_id)
                      INTO l_researcher_id
                      FROM hz_cust_accounts ca, hz_customer_profiles cp, ar_collectors ac,
                           JTF_RS_SALESREPS sr, hz_cust_acct_sites_all cas, hz_cust_site_uses_all csu
                     WHERE     ca.cust_account_id = cas.cust_account_id
                           AND cp.site_use_id = csu.site_use_id
                           AND csu.site_use_code = 'BILL_TO'
                           AND csu.cust_acct_site_id = cas.cust_acct_site_id
                           AND ac.collector_id = cp.collector_id
                           AND ca.cust_account_id = p_cust_account_id
                           AND csu.primary_salesrep_id = sr.SALESREP_ID;

                    x_researcher_id   := l_researcher_id;
                ELSIF l_researcher_type = 'Party DFF'
                THEN
                    SELECT DECODE (l_party_dff,  'ATTRIBUTE4', hp.ATTRIBUTE4,  'ATTRIBUTE5', hp.ATTRIBUTE5,  'ATTRIBUTE9', hp.ATTRIBUTE9,  'ATTRIBUTE10', hp.ATTRIBUTE10,  'ATTRIBUTE11', hp.ATTRIBUTE11,  NULL)
                      INTO l_researcher_id
                      FROM hz_parties hp, HZ_CUST_ACCOUNTS hca
                     --                           hz_cust_site_uses_all hcu,
                     --                           HZ_CUST_ACCT_SITES_ALL hcs ,
                     --                           hz_party_sites hps,
                     --                           hz_locations loc
                     -- OZF_CLAIMS_ALL oca
                     WHERE  /* hcu.cust_acct_site_id = hcs.cust_acct_site_id
--                        AND  hca.cust_account_id = hcs.cust_account_id
--                        AND  hcs.party_site_id = hps.party_site_id
--                        AND  hps.location_id = loc.location_id*/
                               hp.party_id = hca.party_id
                           AND hca.cust_account_id = p_cust_account_id;

                    --                                AND  hcu.SITE_USE_ID= p_acct_site_id;

                    x_researcher_id   := l_researcher_id;
                END IF;
            ELSE
                BEGIN
                    SELECT ac.collector_id
                      INTO l_researcher_id
                      FROM hz_cust_accounts ca, hz_customer_profiles cp, ar_collectors ac,
                           JTF_RS_SALESREPS sr, hz_cust_acct_sites_all cas, hz_cust_site_uses_all csu
                     WHERE     ca.cust_account_id = cas.cust_account_id
                           AND cp.site_use_id = csu.site_use_id
                           AND csu.site_use_code = 'BILL_TO'
                           AND csu.cust_acct_site_id = cas.cust_acct_site_id
                           AND ac.collector_id = cp.collector_id
                           AND ca.cust_account_id = p_cust_account_id
                           AND csu.primary_salesrep_id = sr.SALESREP_ID;

                    x_researcher_id   := l_researcher_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        x_researcher_id   := NULL;
                END;
            END IF;
        END IF;

        ---WF Routing Role query
        BEGIN
            SELECT wrr.ACTION_ARGUMENT
              INTO l_reassighn_user
              FROM WF_LOCAL_ROLES wr, WF_ROUTING_RULES wrr, ams_jtf_rs_emp_v ajr
             WHERE     wr.name = wrr.role
                   AND wr.orig_system_id = ajr.employee_id
                   AND SYSDATE BETWEEN wrr.begin_date AND wrr.end_date
                   AND SYSDATE BETWEEN ajr.start_date_active
                                   AND NVL (ajr.end_date_active, SYSDATE)
                   AND ajr.resource_id = l_researcher_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_reassighn_user   := NULL;
        END;

        IF l_reassighn_user IS NOT NULL
        THEN
            BEGIN
                SELECT ajr.resource_id
                  INTO l_resource_id
                  FROM WF_LOCAL_ROLES wr, ams_jtf_rs_emp_v ajr
                 WHERE     wr.orig_system_id = ajr.employee_id
                       AND SYSDATE BETWEEN ajr.start_date_active
                                       AND NVL (ajr.end_date_active, SYSDATE)
                       AND wr.name = l_reassighn_user;

                x_researcher_id   := l_resource_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_resource_id   := NULL;
            END;
        END IF;
    /*select * from apps.WF_ROUTING_RULES
     where role='<USER NAME>'*/

    EXCEPTION
        WHEN OTHERS
        THEN
            x_researcher_id   := NULL;
    END;

    PROCEDURE XXD_DERIVE_THRESHOLD (p_brand                  IN     VARCHAR2,
                                    p_reason_code_id         IN     NUMBER,
                                    p_org_id                 IN     NUMBER,
                                    p_cust_account_id        IN     NUMBER,
                                    p_claim_amount           IN     NUMBER,
                                    p_receipt_id             IN     NUMBER,
                                    p_source_object          IN     VARCHAR2,
                                    p_source_object_number   IN     VARCHAR2,
                                    x_witeoff_flag              OUT VARCHAR2,
                                    x_threshold_amount          OUT NUMBER,
                                    x_under_threshold           OUT VARCHAR2)
    AS
        l_customer            VARCHAR2 (100);
        l_cap_amount          NUMBER;
        l_major_acc_check     VARCHAR2 (10);
        l_writeoff_val        NUMBER;
        l_writeoff_per_type   VARCHAR2 (100);
        l_customer_flag       VARCHAR2 (10);
        l_writeoff_amount     NUMBER;
        l_trx_amount          NUMBER;
        l_writeoffcust_val    NUMBER;
        l_writeoffcust_flag   VARCHAR2 (10) := NULL;
    BEGIN
        BEGIN
            SELECT ATTRIBUTE6, ATTRIBUTE7, ATTRIBUTE4,
                   ATTRIBUTE5
              INTO l_customer, l_cap_amount, l_writeoffcust_val, l_writeoff_per_type
              FROM fnd_lookup_values
             WHERE     lookup_type = 'XXDO_CLM_WO_THRESHOLD_MATRIX'
                   AND enabled_flag = 'Y'
                   AND SYSDATE BETWEEN START_DATE_ACTIVE
                                   AND NVL (END_DATE_ACTIVE, SYSDATE)
                   AND language = USERENV ('LANG')
                   AND attribute1 = p_org_id
                   --- and attribute2 = p_brand
                   AND attribute3 = p_reason_code_id
                   AND attribute6 = p_cust_account_id
                   AND attribute9 = p_source_object;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                BEGIN
                    SELECT ATTRIBUTE6, ATTRIBUTE7, NVL (ATTRIBUTE10, 'N'),
                           ATTRIBUTE4, ATTRIBUTE5
                      INTO l_customer, l_cap_amount, l_major_acc_check, l_writeoff_val,
                                     l_writeoff_per_type
                      FROM fnd_lookup_values
                     WHERE     lookup_type = 'XXDO_CLM_WO_THRESHOLD_MATRIX'
                           AND enabled_flag = 'Y'
                           AND SYSDATE BETWEEN START_DATE_ACTIVE
                                           AND NVL (END_DATE_ACTIVE, SYSDATE)
                           AND language = USERENV ('LANG')
                           AND attribute1 = p_org_id
                           AND attribute2 = p_brand
                           AND attribute3 = p_reason_code_id
                           --- and attribute6 IS NULL;
                           AND attribute9 = p_source_object;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        SELECT ATTRIBUTE6, ATTRIBUTE7, NVL (ATTRIBUTE10, 'N'),
                               ATTRIBUTE4, ATTRIBUTE5
                          INTO l_customer, l_cap_amount, l_major_acc_check, l_writeoff_val,
                                         l_writeoff_per_type
                          FROM fnd_lookup_values
                         WHERE     lookup_type =
                                   'XXDO_CLM_WO_THRESHOLD_MATRIX'
                               AND enabled_flag = 'Y'
                               AND SYSDATE BETWEEN START_DATE_ACTIVE
                                               AND NVL (END_DATE_ACTIVE,
                                                        SYSDATE)
                               AND language = USERENV ('LANG')
                               AND attribute1 = p_org_id
                               AND attribute2 LIKE 'ALL%'              --'ALL'
                               AND attribute3 = p_reason_code_id        --'21'
                               AND attribute9 = p_source_object;
                ---  and attribute6 IS NULL;

                END;

                IF NVL (l_major_acc_check, 'N') = 'Y'
                THEN
                    --check in lookup 'XXDO_CLM_MAJOR_ACCT_MATRIX '
                    BEGIN
                        SELECT 'Y'
                          INTO l_customer_flag
                          FROM fnd_lookup_values
                         WHERE     lookup_type = 'XXDO_CLM_MAJOR_ACCT_MATRIX'
                               AND enabled_flag = 'Y'
                               AND SYSDATE BETWEEN START_DATE_ACTIVE
                                               AND NVL (END_DATE_ACTIVE,
                                                        SYSDATE)
                               AND language = USERENV ('LANG')
                               AND attribute1 = p_org_id
                               AND attribute4 = p_cust_account_id;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            l_customer_flag   := 'N';
                    END;
                END IF;

                IF NVL (l_customer_flag, 'N') <> 'Y'
                THEN
                    IF l_cap_amount IS NOT NULL
                    THEN
                        IF l_cap_amount > ABS (p_claim_amount)
                        THEN
                            l_writeoffcust_flag   := 'Y';
                        ELSE
                            l_writeoffcust_flag   := 'N';
                        END IF;
                    ELSE
                        l_writeoffcust_flag   := 'Y';
                    END IF;
                END IF;
        END;

        IF    l_writeoffcust_val IS NOT NULL
           OR NVL (l_writeoffcust_flag, 'N') = 'Y'
        THEN
            IF l_writeoff_per_type = 'Invoice'
            THEN
                /* select SUM(rl.extended_amount)
                 into l_trx_amount
                 from ra_customer_trx_lines_all rl,ra_customer_trx_all ra,
                 (
                 SELECT  distinct ra.customer_trx_id
                 FROM ra_customer_trx_all ra , --ra_customer_trx_lines_all rl,
                 ar_cash_receipts_all ac ,
                 ar_receivable_applications_all aaa
                 --ozf_claims_all oca
                 WHERE aaa.application_type = 'CASH' --and  ac.status='APP'
                 AND aaa.cash_receipt_id = ac.cash_receipt_id
                 --AND oca.receipt_id = ac.cash_receipt_id
                 --and oca.claim_class in ('OVERPAYMENT','DEDUCTION')
                 AND aaa.applied_customer_trx_id = ra.customer_trx_id
                 and ac.cash_receipt_id  = p_receipt_id
                 )rct
                 where rl.customer_trx_id = rct.customer_trx_id
                 and rct.customer_trx_id =ra.customer_trx_id;*/

                SELECT SUM (rl.extended_amount)
                  INTO l_trx_amount
                  FROM ra_customer_trx_lines_all rl, ra_customer_trx_all ra
                 WHERE     rl.customer_trx_id = ra.customer_trx_id
                       AND ra.trx_number = p_source_object_number;

                l_writeoff_amount   :=
                      (NVL (l_writeoffcust_val, l_writeoff_val) * l_trx_amount)
                    / 100;
            ELSIF l_writeoff_per_type = 'Receipt'
            THEN
                SELECT ar.amount
                  INTO l_trx_amount
                  FROM ar_cash_receipts_all AR
                 WHERE AR.cash_receipt_id = p_receipt_id;


                l_writeoff_amount   :=
                      (NVL (l_writeoffcust_val, l_writeoff_val) * l_trx_amount)
                    / 100;
            ELSIF l_writeoff_per_type = 'SALESORDER'
            THEN
                SELECT SUM (ol.ORDERED_QUANTITY * ol.UNIT_LIST_PRICE)
                  INTO l_trx_amount
                  FROM ra_customer_trx_all ra,
                       OE_ORDER_headers_ALl oh,
                       OE_ORDER_LINES_ALL ol,
                       (SELECT DISTINCT ra.customer_trx_id
                          FROM ra_customer_trx_all ra, ar_cash_receipts_all ac, ar_receivable_applications_all aaa
                         WHERE     ac.status = 'APP'
                               AND aaa.application_type = 'CASH'
                               AND aaa.cash_receipt_id = ac.cash_receipt_id
                               --AND oca.receipt_id = ac.cash_receipt_id
                               AND aaa.applied_customer_trx_id =
                                   ra.customer_trx_id
                               AND ac.cash_receipt_id = p_receipt_id) rct
                 WHERE     rct.customer_trx_id = ra.customer_trx_id
                       AND ra.INTERFACE_HEADER_ATTRIBUTE1 =
                           TO_CHAR (oh.ORDER_NUMBER)
                       AND ra.INTERFACE_HEADER_ATTRIBUTE1 IS NOT NULL
                       AND oh.header_id = ol.header_id;

                l_writeoff_amount   :=
                      (NVL (l_writeoffcust_val, l_writeoff_val) * l_trx_amount)
                    / 100;
            ELSIF l_writeoff_per_type = 'Constant'
            THEN
                l_writeoff_amount   :=
                    NVL (l_writeoffcust_val, l_writeoff_val);
            END IF;
        END IF;

        IF l_writeoff_amount > ABS (p_claim_amount)
        THEN
            x_witeoff_flag       := 'T';
            x_threshold_amount   := l_writeoff_amount;
            x_under_threshold    := 'UNDER';
        ELSE
            x_witeoff_flag       := NULL;
            x_threshold_amount   := NULL;
            x_under_threshold    := NULL;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_witeoff_flag       := NULL;
            x_threshold_amount   := NULL;
            x_under_threshold    := NULL;
    END;

    PROCEDURE XXD_MAIN_UPDATE_CLAIM (X_ERRBUF OUT VARCHAR2, X_RETCODE OUT VARCHAR2, P_ORG_ID IN NUMBER)
    AS
        CURSOR cur_claim_rec (p_org_id IN NUMBER)
        IS
            SELECT claim_number, owner_id
              FROM XXD_OZF_CLAIM_TB
             WHERE STATUS = 'N' AND org_id = p_org_id;
    BEGIN
        FOR i IN cur_claim_rec (P_ORG_ID)
        LOOP
            XXD_UPDATE_CLAIM (i.claim_number, i.owner_id);
        END LOOP;
    END;


    PROCEDURE XXD_UPDATE_CLAIM (p_claim_number   IN VARCHAR2,
                                P_OWNER_ID       IN NUMBER)
    AS
        l_return_status           VARCHAR2 (1);
        l_msg_count               NUMBER;
        l_msg_data                VARCHAR2 (20000);

        --l_resp_name VARCHAR2(100) := 'Oracle Trade Management Super User - US';
        l_owner_id                NUMBER := P_OWNER_ID;
        l_appl_id                 NUMBER;
        l_resp_id                 NUMBER := FND_GLOBAL.resp_id;
        l_user_id                 NUMBER;
        l_org_id                  NUMBER;

        l_claim_pub_rec           OZF_Claim_PUB.claim_rec_type;
        l_claim_line_pub_tbl      OZF_Claim_PUB.claim_line_tbl_type;

        l_x_claim_id              NUMBER;
        l_claim_id                NUMBER;

        l_api_version    CONSTANT NUMBER := 1.0;
        l_object_version_number   NUMBER := 1.0;



        CURSOR csr_claim_id (cv_claim_number IN VARCHAR2)
        IS
            SELECT claim_id, org_id, Object_version_number
              FROM ozf_claims_all
             WHERE claim_number = cv_claim_number;
    BEGIN
        ------------------------------------------
        -- Initialization
        ------------------------------------------
        OPEN csr_claim_id (p_claim_number);

        FETCH csr_claim_id INTO l_claim_id, l_org_id, l_object_version_number;

        CLOSE csr_claim_id;

        FND_FILE.PUT_LINE (fnd_file.LOG, 'Claim ID: ' || l_claim_id);
        FND_FILE.PUT_LINE (fnd_file.LOG, 'Org ID: ' || l_org_id);
        FND_FILE.PUT_LINE (
            fnd_file.LOG,
            'Object Version Number From DB: ' || l_object_version_number);

        SELECT application_id
          INTO l_appl_id
          FROM fnd_responsibility_vl
         WHERE responsibility_id = l_resp_id;

        l_user_id                               := FND_GLOBAL.USER_ID;

        FND_GLOBAL.APPS_INITIALIZE (l_user_id, l_resp_id, l_appl_id);
        MO_GLOBAL.init ('OZF');
        MO_GLOBAL.set_policy_context ('S', l_org_id);

        FND_FILE.PUT_LINE (fnd_file.LOG,
                           '==================================');
        FND_FILE.PUT_LINE (fnd_file.LOG, 'INITIALIZATION');
        FND_FILE.PUT_LINE (
            fnd_file.LOG,
            'ORG : ' || SUBSTR (USERENV ('CLIENT_INFO'), 1, 10));
        FND_FILE.PUT_LINE (fnd_file.LOG,
                           '==================================');

        FND_MSG_PUB.G_msg_level_threshold       := 1;


        l_claim_pub_rec.owner_id                := l_owner_id;
        l_claim_pub_rec.claim_id                := l_claim_id;
        l_claim_pub_rec.object_version_number   := l_object_version_number;


        -- 3. update claim
        OZF_CLAIM_PUB.Update_Claim (
            p_api_version_number      => l_api_version,
            p_init_msg_list           => FND_API.G_FALSE,
            p_commit                  => FND_API.G_FALSE,
            p_validation_level        => FND_API.G_VALID_LEVEL_FULL,
            x_return_status           => l_return_status,
            x_msg_count               => l_msg_count,
            x_msg_data                => l_msg_data,
            p_claim_rec               => l_claim_pub_rec,
            p_claim_line_tbl          => l_claim_line_pub_tbl,
            x_object_version_number   => l_object_version_number);



        DBMS_OUTPUT.PUT_LINE ('Success ? ' || l_return_status);


        IF l_return_status = FND_API.G_RET_STS_SUCCESS
        THEN
            FND_FILE.PUT_LINE (fnd_file.LOG,
                               '----- Update of Claim sucessfull-----');

            UPDATE XXD_OZF_CLAIM_TB
               SET status   = 'Y'
             WHERE CLAIM_NUMBER = p_claim_number;

            FND_FILE.PUT_LINE (fnd_file.LOG, '----- Line -----');
        END IF;



        FND_MSG_PUB.count_and_get (p_encoded   => FND_API.g_false,
                                   p_count     => l_msg_count,
                                   p_data      => l_msg_data);



        FOR I IN 1 .. l_msg_count
        LOOP
            FND_FILE.PUT_LINE (
                fnd_file.LOG,
                SUBSTR (FND_MSG_PUB.GET (P_MSG_INDEX => I, P_ENCODED => 'F'),
                        1,
                        254));
        END LOOP;

        FND_FILE.PUT_LINE (fnd_file.LOG, '========= END =========');
        COMMIT;
    END;
END;
/
