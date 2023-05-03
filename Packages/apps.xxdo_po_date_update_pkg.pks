--
-- XXDO_PO_DATE_UPDATE_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:17:21 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.xxdo_po_date_update_pkg
AS
    PROCEDURE XXDO_UPDATE_REQ_DATE (P_HEADER_ID IN NUMBER, P_NEW_REQUEST_DATE IN DATE, P_ERROR_CODE OUT VARCHAR2
                                    , P_ERROR_TEXT OUT VARCHAR2);

    PROCEDURE XXDO_UPDATE_NEEDBY_DATE (
        p_po_num                      IN     VARCHAR2,
        P_PO_HEADER_ID                IN     NUMBER,
        P_STYLE                       IN     VARCHAR2,
        P_COLOR                       IN     VARCHAR2,
        P_SHIP_TO_LOCATION_ID         IN     NUMBER,
        P_SALES_ORDER_HEADER_ID       IN     NUMBER,
        P_PROMISED_DATE_OLD           IN     VARCHAR2,
        P_NEED_BY_DATE_OLD            IN     DATE,
        P_EX_FACTORY_DATE_OLD         IN     VARCHAR2,
        P_CONF_EX_FACTORY_DATE_OLD    IN     VARCHAR2,
        P_ORIG_FACTORY_DATE_OLD              VARCHAR2,
        --start of changes by BT Tech for factory finished date--29-May-2015 ver 1.2
        P_FACTORY_FINISHED_DATE_OLD          VARCHAR2,
        --end of changes by BT Tech for factory finished date--29-May-2015 ver 1.2
        p_new_promised_date           IN     VARCHAR2,
        p_new_needby_date             IN     VARCHAR2,
        p_org_id                      IN     NUMBER,
        p_error_code                     OUT VARCHAR2,
        p_error_num                      OUT NUMBER);

    PROCEDURE FACTORY_DATE_UPDATE (p_po_num IN VARCHAR2, P_PO_HEADER_ID IN NUMBER, P_STYLE VARCHAR2, P_COLOR VARCHAR2, P_SHIP_TO_LOCATION_ID NUMBER, P_SALES_ORDER_HEADER_ID NUMBER, P_PROMISED_DATE_OLD VARCHAR2, P_NEED_BY_DATE_OLD DATE, P_EX_FACTORY_DATE_OLD DATE, P_CONF_EX_FACTORY_DATE_OLD DATE, P_ORIG_FACTORY_DATE_OLD DATE, --start of changes by BT Tech for factory finished date--29-May-2015 ver 1.2
                                                                                                                                                                                                                                                                                                                                       P_FACTORY_FINISHED_DATE DATE, P_FACTORY_FINISHED_DATE_OLD DATE, --end of changes by BT Tech for factory finished date--29-May-2015 ver 1.2
                                                                                                                                                                                                                                                                                                                                                                                                       P_EX_FACTORY_DATE IN DATE, P_CONF_EX_FACTORY_DATE IN DATE, P_ORIG_CONF_EX_FACTORY_DATE IN DATE, p_org_id IN NUMBER, p_error_code OUT VARCHAR2
                                   , p_error_num OUT NUMBER);

    PROCEDURE XXDO_PO_APPROVAL (p_po_num IN VARCHAR2, P_org_id IN NUMBER, p_error_code OUT VARCHAR2
                                , P_ERROR_TEXT OUT VARCHAR2);
END xxdo_po_date_update_pkg;
/
