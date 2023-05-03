--
-- XXDOEC_CA_SETTLEMENT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:12:39 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOEC_CA_SETTLEMENT_PKG"
AS
    -- Author  : VIJAY.REDDY
    -- Created : 1/7/2012 6:27:51 PM
    -- Purpose :

    PROCEDURE insert_header (P_WEBSITE_ID IN VARCHAR2, P_SETTLEMENT_ID IN VARCHAR2, P_CURRENCY_CODE IN VARCHAR2, P_TOTAL_AMOUNT IN NUMBER, P_DEPOSIT_DATE IN DATE, P_TRANS_START_DATE IN DATE, P_TRANS_END_DATE IN DATE, X_STLMNT_HEADER_ID IN OUT NUMBER, X_RTN_STATUS OUT VARCHAR2
                             , X_RTN_MESSAGE OUT VARCHAR2);

    PROCEDURE insert_line (P_STLMNT_HEADER_ID IN NUMBER, P_SETTLEMENT_ID IN VARCHAR2, P_TRANSACTION_TYPE IN VARCHAR2, P_SELLER_ORDER_ID IN VARCHAR2, P_MERCHANT_ORDER_ID IN VARCHAR2, P_POSTED_DATE IN DATE, P_SELLER_ITEM_CODE IN VARCHAR2, P_MERCHANT_ADJ_ITEM_ID IN VARCHAR2, P_SKU IN VARCHAR2, P_QUANTITY IN NUMBER, P_PRINCIPAL_AMOUNT IN NUMBER, P_COMMISSION_AMOUNT IN NUMBER, P_FREIGHT_AMOUNT IN NUMBER, P_TAX_AMOUNT IN NUMBER, P_PROMO_AMOUNT IN NUMBER
                           , X_STLMNT_LINE_ID IN OUT NUMBER, X_RTN_STATUS OUT VARCHAR2, X_RTN_MESSAGE OUT VARCHAR2);

    PROCEDURE process_settlements (x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER, p_settlement_id IN VARCHAR2
                                   , p_website_id IN VARCHAR2);

    PROCEDURE apply_cm_to_invoice (x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER, p_header_id IN NUMBER);
END xxdoec_ca_settlement_pkg;
/
