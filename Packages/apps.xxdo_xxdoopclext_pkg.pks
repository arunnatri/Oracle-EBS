--
-- XXDO_XXDOOPCLEXT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:18:08 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_XXDOOPCLEXT_PKG"
IS
    P_OPERATING_UNIT       VARCHAR2 (100);
    P_CLAIM_TYPE           VARCHAR2 (100);
    P_BRAND                VARCHAR2 (100);
    P_CLAIM_STATUS         VARCHAR2 (100);
    P_CUSTOMER_NAME_FROM   VARCHAR2 (100);
    P_CUSTOMER_NAME_TO     VARCHAR2 (100);
    P_GL_DATE_FROM         DATE;
    P_GL_DATE_TO           DATE;
    P_TRX_DATE_FROM        DATE;
    P_TRX_DATE_TO          DATE;
    P_TRX_NUMBER_FROM      VARCHAR2 (100);
    P_TRX_NUMBER_TO        VARCHAR2 (100);
    P_CLAIM_DATE_FROM      DATE;
    P_CLAIM_DATE_TO        DATE;
    P_CLAIM_NUMBER_FROM    VARCHAR2 (100);
    P_CLAIM_NUMBER_TO      VARCHAR2 (100);
    P_CLAIM_REASON_CODE    VARCHAR2 (100);
    P_SETTLEMENT_METHOD    VARCHAR2 (100);
    P_EMAIL                VARCHAR2 (100);
    P_EMAIL_FROM_ADDRESS   VARCHAR2 (100);
    P_EMAIL_TO_ADDRESS     VARCHAR2 (100);
    P_RESEARCHER           VARCHAR2 (100);             -- Added for CCR0007639
    P_APPRV_PENDING_WITH   VARCHAR2 (100);             -- Added for CCR0007639
    P_ACT_CLAIM_TYPE       VARCHAR2 (100);             -- Added for CCR0007639

    FUNCTION afterReport (P_EMAIL IN VARCHAR2, RELATED_CLAIM_NUMBER VARCHAR2)
        RETURN BOOLEAN;

    -- Added Function for CCR0007639
    FUNCTION BeforeReport
        RETURN BOOLEAN;

    FUNCTION SMTP_HOST
        RETURN VARCHAR2;

    FUNCTION XXDO_GET_SETTLEMENT_DETAILS (p_settlement_number NUMBER, p_org_id NUMBER, p_column VARCHAR2
                                          , p_pay_method VARCHAR2)
        RETURN VARCHAR2;
END XXDO_XXDOOPCLEXT_PKG;
/
