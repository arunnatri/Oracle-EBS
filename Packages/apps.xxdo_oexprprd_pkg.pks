--
-- XXDO_OEXPRPRD_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:16:39 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.XXDO_OEXPRPRD_PKG
IS
    P_SOB_ID                  VARCHAR2 (30);
    P_ORGANIZATION_ID         VARCHAR2 (30);
    P_ITEM_FLEX_CODE          VARCHAR2 (30);
    P_PRINT_DESCRIPTION       VARCHAR2 (30);
    P_MIN_PRECISION           VARCHAR2 (30);
    P_ORDER_NUM_LOW           NUMBER (15);
    P_ORDER_NUM_HIGH          NUMBER (15);
    P_CUSTOMER_NAME_LOW       VARCHAR2 (30);
    P_CUSTOMER_NUM_LOW        VARCHAR2 (30);
    P_ORDER_DATE_LOW          VARCHAR2 (100);
    P_ORDER_DATE_HIGH         VARCHAR2 (100);
    P_ORDER_TYPE_LOW          VARCHAR2 (30);
    P_ORDER_TYPE_HIGH         VARCHAR2 (30);
    P_LINE_TYPE_LOW           VARCHAR2 (30);
    P_LINE_TYPE_HIGH          VARCHAR2 (30);
    P_ITEM_LOW                VARCHAR2 (30);
    P_SALESREP_LOW            VARCHAR2 (30);
    P_BRAND                   VARCHAR2 (30);
    P_ITEM_NUMBER             VARCHAR2 (30);
    p_operating_unit          VARCHAR2 (50);
    P_REGION                  VARCHAR2 (100);
    P_SORT_BY                 VARCHAR2 (80);
    P_CUSTOMER_NAME_HIGH      VARCHAR2 (30);
    P_CUSTOMER_NUM_HIGH       VARCHAR2 (3000);
    LP_ORDER_NUM              VARCHAR2 (3000);
    ORDER_NUMBER_PARMS        VARCHAR2 (200);
    ORDER_NUMBER_PARMS_LOW    VARCHAR2 (300);
    ORDER_NUMBER_PARMS_HIGH   VARCHAR2 (300);
    L_LINE_TYPE_LOW           VARCHAR2 (3000);
    L_LINE_TYPE_HIGH          VARCHAR2 (3000);
    P_SALESREP_HIGH           VARCHAR2 (30);
    LP_SORT_BY                VARCHAR2 (3000);
    LP_CUSTOMER_NAME          VARCHAR2 (3000);
    CUSTOMER_PARMS            VARCHAR2 (300);
    CUSTOMER_PARMS_LOW        VARCHAR2 (300);
    CUSTOMER_PARMS_HIGH       VARCHAR2 (300);
    LP_CUSTOMER_NUM           VARCHAR2 (3000);
    CUSTOMER_NUM_PARMS        VARCHAR2 (300);
    CUSTOMER_NUM_PARMS_LOW    VARCHAR2 (300);
    CUSTOMER_NUM_PARMS_HIGH   VARCHAR2 (300);
    LP_ORDER_DATE             VARCHAR2 (3000);
    ORDER_DATE_PARMS          VARCHAR2 (3000);
    ORDER_DATE_PARMS_LOW      VARCHAR2 (3000);
    ORDER_DATE_PARMS_HIGH     VARCHAR2 (3000);
    LP_ORDER_TYPE             VARCHAR2 (3000);
    L_ORDER_TYPE_LOW          VARCHAR2 (3000);
    L_ORDER_TYPE_HIGH         VARCHAR2 (3000);
    ORDER_TYPE_PARMS          VARCHAR2 (300);
    ORDER_TYPE_PARMS_LOW      VARCHAR2 (300);
    ORDER_TYPE_PARMS_HIGH     VARCHAR2 (300);
    P_ITEM_HI                 VARCHAR2 (30);
    LINE_TYPE_PARMS           VARCHAR2 (3000);
    LINE_TYPE_PARMS_LOW       VARCHAR2 (3000);
    LINE_TYPE_PARMS_HIGH      VARCHAR2 (3000);
    LP_SALESREP               VARCHAR2 (3000);
    SALESREP_PARMS            VARCHAR2 (300);
    SALESREP_PARMS_LOW        VARCHAR2 (300);
    SALESREP_PARMS_HIGH       VARCHAR2 (300);
    P_OPEN_FLAG               VARCHAR2 (80);
    LP_OPEN_FLAG              VARCHAR2 (3000);
    P_ORDER_CATEGORY          VARCHAR2 (30);
    P_LINE_CATEGORY           VARCHAR2 (30);
    LP_ORDER_CATEGORY         VARCHAR2 (3000);
    LP_LINE_CATEGORY          VARCHAR2 (3000);
    LP_LINE_TYPE              VARCHAR2 (3000);
    LP_ITEM                   VARCHAR2 (3000);
    lp_where_clause           VARCHAR2 (3000);
    lp_brand                  VARCHAR2 (30);
    lp_item_number            VARCHAR2 (50);
    lp_operating_unit         VARCHAR2 (50);


    FUNCTION AfterPForm (P_ORDER_NUM_LOW        IN NUMBER,
                         P_ORDER_NUM_HIGH       IN NUMBER,
                         P_CUSTOMER_NAME_LOW    IN VARCHAR2,
                         P_CUSTOMER_NUM_LOW     IN VARCHAR2,
                         P_ORDER_DATE_LOW       IN VARCHAR2,
                         P_ORDER_DATE_HIGH      IN VARCHAR2,
                         P_ORDER_TYPE_LOW       IN VARCHAR2,
                         P_ORDER_TYPE_HIGH      IN VARCHAR2,
                         P_LINE_TYPE_LOW        IN VARCHAR2,
                         P_LINE_TYPE_HIGH       IN VARCHAR2,
                         P_ITEM_LOW             IN VARCHAR2,
                         P_SALESREP_LOW         IN VARCHAR2,
                         P_SORT_BY              IN VARCHAR2,
                         P_CUSTOMER_NAME_HIGH   IN VARCHAR2,
                         P_CUSTOMER_NUM_HIGH1   IN VARCHAR2,
                         P_ITEM_HI              IN VARCHAR2,
                         P_SALESREP_HIGH        IN VARCHAR2,
                         P_OPEN_FLAG            IN VARCHAR2,
                         P_ORDER_CATEGORY       IN VARCHAR2,
                         P_LINE_CATEGORY        IN VARCHAR2,
                         P_BRAND                IN VARCHAR2,
                         P_ITEM_NUMBER          IN VARCHAR2,
                         p_operating_unit       IN VARCHAR2)
        RETURN BOOLEAN;
END XXDO_OEXPRPRD_PKG;
/
