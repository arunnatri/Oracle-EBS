--
-- XXDOOM_CIT_REMITPROC_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:14:35 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOOM_CIT_REMITPROC_PKG"
AS
    --------------------------------------------------------------------------------
    -- Created By              : BT Technology Team
    -- Creation Date           : 31-Mar-2015
    -- File Name               : XXDOOM_CIT_REMITPROC_PKG.pks
    -- INCIDENT                : CIT Process Remittance - Deckers
    --
    -- Description             :
    -- Latest Version          : 1.0
    --
    -- Revision History:
    -- =============================================================================
    -- Date               Version#    Name                 Remarks
    -- =============================================================================
    -- 31-MAR-2015        1.0         BT Technology Team  Initial development.
    -------------------------------------------------------------------------------

    G_DEBUG_FLAG   VARCHAR2 (10);

    PROCEDURE MAIN (P_ERRBUF OUT VARCHAR2, P_RETCODE OUT VARCHAR2, P_FILE_NAME IN VARCHAR2, P_ACTIVITY_DATE IN VARCHAR2, P_EMAIL IN VARCHAR2, P_DUMMYEMAIL IN VARCHAR2, P_EMAIL_FROM_ADDRESS IN VARCHAR2, P_EMAIL_TO_ADDRESS IN VARCHAR2, P_HELPDESK_EMAIL IN VARCHAR2
                    , P_DEBUG IN VARCHAR2);

    PROCEDURE UPDATE_STG_DATA;

    PROCEDURE VALIDATE_STG_DATA (P_STATUS OUT VARCHAR2);

    PROCEDURE UPDATE_STATUS (P_TYPE IN VARCHAR2, P_STATUS IN VARCHAR2, P_MESSAGE IN VARCHAR2
                             , P_ITEM_REF IN VARCHAR2, P_AR_TRANSACTION_CODE IN VARCHAR2, P_ACTIVITY_IND IN VARCHAR2);

    PROCEDURE CREATE_RECEIPT (P_RECEIPT_NUM     IN     VARCHAR2,
                              P_RECEIPT_DATE    IN     DATE,
                              P_GL_DATE         IN     DATE,
                              P_RECEIPT_AMT     IN     NUMBER,
                              P_CUST_NUM        IN     VARCHAR2,
                              P_CURR_CODE       IN     VARCHAR2,
                              P_ORG_ID          IN     NUMBER,
                              P_COMMENTS        IN     VARCHAR2,
                              P_STATUS             OUT VARCHAR2,
                              P_ERROR_MESSAGE      OUT VARCHAR2,
                              P_RECEIPT_ID         OUT NUMBER);

    PROCEDURE APPLY_RECEIPT (P_RECEIPT_ID       IN     NUMBER,
                             P_TRX_NUMBER       IN     VARCHAR2,
                             P_AMOUNT_APPLIED   IN     NUMBER,
                             P_APPLY_DATE       IN     DATE,
                             P_APPLY_GL_DATE    IN     DATE,
                             P_REASON_CODE      IN     VARCHAR2,
                             P_STATUS              OUT VARCHAR2,
                             P_ERROR_MESSAGE       OUT VARCHAR2);

    PROCEDURE CREATE_ADJUSTMENT (P_CUST_TRX_ID IN NUMBER, P_REC_TRX_ID IN NUMBER, P_PAY_SCHD_ID IN NUMBER, P_AMOUNT IN NUMBER, P_APPLY_DATE IN DATE, P_APPLY_GL_DATE IN DATE, P_LINE_TYPE IN VARCHAR2, P_ORG_ID IN NUMBER, P_STATUS OUT VARCHAR2
                                 , P_ERROR_MESSAGE OUT VARCHAR2);

    PROCEDURE CIT_DATA_FILE_ALERT (P_FROM_EMAIL IN VARCHAR2, P_TO_EMAIL IN VARCHAR2, P_FILE_NAME IN VARCHAR2);

    PROCEDURE CIT_DATA_DUP_ALERT (P_FROM_EMAIL IN VARCHAR2, P_TO_EMAIL IN VARCHAR2, P_FILE_NAME IN VARCHAR2);

    PROCEDURE CIT_REMITTANCE_REPORT (P_ERRBUF OUT VARCHAR2, P_RET_CODE OUT NUMBER, P_FROM_EMAIL IN VARCHAR2
                                     , P_TO_EMAIL IN VARCHAR2);

    PROCEDURE PROCESS_DATA (p_activity_date IN VARCHAR2);

    PROCEDURE RECEIPT_WRITE_OFF (p_Cash_Receipt_ID   IN     NUMBER,
                                 p_Amt_Applied       IN     NUMBER,
                                 p_activity_date     IN     DATE,
                                 p_Brand             IN     VARCHAR2,
                                 x_Error_Msg            OUT VARCHAR2);

    PROCEDURE CREATE_MISC_RECEIPT (p_currency_code   IN     VARCHAR2,
                                   p_amount          IN     NUMBER,
                                   p_activity_date   IN     DATE,
                                   p_brand           IN     VARCHAR2,
                                   p_message            OUT VARCHAR2);

    FUNCTION FORMAT_AMOUNT (P_AMOUNT IN NUMBER)
        RETURN NUMBER;

    PROCEDURE CLAIM_INVESTIGATION (p_receipt_id IN NUMBER, p_activity_date IN DATE, p_amount IN NUMBER, p_reason_code IN VARCHAR2, p_brand IN VARCHAR2, p_status OUT VARCHAR2
                                   , p_message OUT VARCHAR2);

    PROCEDURE APPLY_RECPT_ON_RCPT (p_receipt_id IN NUMBER, p_appl_receipt_id IN NUMBER, p_amount_applied IN NUMBER
                                   , p_activity_date IN DATE, p_status OUT VARCHAR2, p_message OUT VARCHAR2);

    PROCEDURE PURGE_DATA (p_errbuff                 OUT VARCHAR2,
                          p_retcode                 OUT VARCHAR2,
                          p_activity_date_low    IN     VARCHAR2,
                          p_activity_date_high   IN     VARCHAR2,
                          p_status               IN     VARCHAR2);
END XXDOOM_CIT_REMITPROC_PKG;
/
