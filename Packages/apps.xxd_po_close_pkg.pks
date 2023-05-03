--
-- XXD_PO_CLOSE_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:24:29 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_PO_CLOSE_PKG"
AS
    /***********************************************************************************
     *$header :                                                                        *
     *                                                                                 *
     * AUTHORS : Srinath Siricilla                                                     *
     *                                                                                 *
     * PURPOSE : Deckers iProc  Finally Close PO Lines                                 *
     *                                                                                 *
     * PARAMETERS :                                                                    *
     *                                                                                 *
     * DATE : 03-JUN-2022                                                              *
     *                                                                                 *
     * Assumptions:                                                                    *
     *                                                                                 *
     *                                                                                 *
     * History                                                                         *
     * Vsn   Change Date Changed By          Change      Description                   *
     * ----- ----------- ------------------- ----------  ---------------------------   *
     * 1.0   03-JUN-2022 Srinath Siricilla   CCR0009986  Initial Creation              *
     **********************************************************************************/

    gn_user_id        NUMBER := fnd_global.user_id;
    gn_resp_id        NUMBER := FND_GLOBAL.resp_id;
    gn_resp_appl_id   NUMBER := FND_GLOBAL.RESP_APPL_ID;
    gd_date           DATE := SYSDATE;
    gn_request_id     NUMBER := fnd_global.conc_request_id;
    gn_ret_code       NUMBER;
    gn_ret_msg        VARCHAR2 (4000);
    g_ignore          VARCHAR2 (1) := 'I';
    g_errored         VARCHAR2 (1) := 'E';
    g_validated       VARCHAR2 (1) := 'V';
    g_processed       VARCHAR2 (1) := 'P';
    g_created         VARCHAR2 (1) := 'C';
    g_new             VARCHAR2 (1) := 'N';

    PROCEDURE insert_data_into_tbl;

    PROCEDURE validate_staging_prc (pn_org_id          IN NUMBER,
                                    pv_update_status   IN VARCHAR2);

    PROCEDURE main_prc (pv_err_buf OUT VARCHAR2, pv_ret_code OUT VARCHAR2, pn_org_id IN NUMBER, pv_update_status IN VARCHAR2, pv_dummy1 IN VARCHAR2, pd_cutoff_date IN VARCHAR2, pv_dummy2 IN VARCHAR2, pv_po_list1 IN VARCHAR2, pv_po_list2 IN VARCHAR2, pv_po_list3 IN VARCHAR2, pv_po_list4 IN VARCHAR2, pv_po_list5 IN VARCHAR2, pv_po_list6 IN VARCHAR2, pv_po_list7 IN VARCHAR2, pv_po_list8 IN VARCHAR2
                        , pv_po_list9 IN VARCHAR2, pv_po_list10 IN VARCHAR2);

    FUNCTION validate_po_fnc (p_po_number          IN     VARCHAR2,
                              p_org_id             IN     NUMBER,
                              x_po_header_id          OUT NUMBER,
                              x_auth_status           OUT VARCHAR2,
                              x_closed_code           OUT VARCHAR2,
                              x_vendor_id             OUT VARCHAR2,
                              x_type_lookup_code      OUT VARCHAR2,
                              x_err_msg               OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION check_inv_fnc (p_po_header_id IN NUMBER, x_invoice_num OUT VARCHAR2, x_invoice_amt OUT NUMBER
                            , x_err_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_po_amt (pn_po_header_id IN NUMBER, pn_po_org_id IN NUMBER, x_po_amt OUT VARCHAR2
                         , x_err_msg OUT VARCHAR2)
        RETURN BOOLEAN;
END XXD_PO_CLOSE_PKG;
/
