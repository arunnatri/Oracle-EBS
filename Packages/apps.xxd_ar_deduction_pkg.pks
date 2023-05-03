--
-- XXD_AR_DEDUCTION_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:18:57 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.XXD_AR_DEDUCTION_PKG
AS
    /************************************************************************************************
    * Package   : APPS.XXD_AR_DEDUCTION_PKG
    * Author   : BT Technology Team
    * Created   : 03-APR-2015
    * Program Name  : XXD_AR_DEDUCTION_PKG
    * Description  : Pogram for claim updates
    *
    * Modification  :
    *-----------------------------------------------------------------------------------------------
    *  Date   Developer    Version  Description
    *-----------------------------------------------------------------------------------------------
    *  03-Apr-2015 BT Technology Team  V1.1   Development    Pogram for claim updates
    ************************************************************************************************/

    PROCEDURE XXD_SET_APPROVER_DETAILS (itemtype    IN            VARCHAR2,
                                        itemkey     IN            VARCHAR2,
                                        actid       IN            NUMBER,
                                        funcmode    IN            VARCHAR2,
                                        resultout      OUT NOCOPY VARCHAR2);

    PROCEDURE XXD_FIND_RESEARCHER (p_brand               IN     VARCHAR2,
                                   p_reason_code_id      IN     NUMBER,
                                   p_org_id              IN     NUMBER,
                                   p_major_customer_id   IN     NUMBER,
                                   p_cust_account_id     IN     NUMBER,
                                   p_acct_site_id        IN     NUMBER,
                                   p_state               IN     VARCHAR2,
                                   x_researcher_id          OUT VARCHAR2);

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
                                    x_under_threshold           OUT VARCHAR2);

    PROCEDURE XXD_MAIN_UPDATE_CLAIM (x_errbuf OUT VARCHAR2, x_retcode OUT VARCHAR2, p_org_id IN NUMBER);

    PROCEDURE XXD_UPDATE_CLAIM (p_claim_number   IN VARCHAR2,
                                P_OWNER_ID       IN NUMBER);
END;
/
