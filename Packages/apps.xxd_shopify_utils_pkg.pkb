--
-- XXD_SHOPIFY_UTILS_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:11 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_SHOPIFY_UTILS_PKG"
IS
    /****************************************************************************************
    * Package      :XXD_SHOPIFY_UTILS_PKG
    * Design       : This package is used for the SHOPIFY process
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name               Comments
    -- ===============================================================================
    -- 09-May-2022  1.0      Shivanshu         Initial Version
    ******************************************************************************************/
    gn_user_id      NUMBER := fnd_global.user_id;
    gn_login_id     NUMBER := fnd_global.login_id;
    gn_request_id   NUMBER := fnd_global.conc_request_id;

    --Set the last SO extract date in the lookup
    PROCEDURE update_shopify_ret_ord (pv_errbuf OUT NOCOPY VARCHAR2, pn_retcode OUT NOCOPY NUMBER, pn_number_of_days IN NUMBER)
    IS
        ln_row_cnt   NUMBER;
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           'Input Parameter ******************');
        fnd_file.put_line (fnd_file.LOG,
                           'Number of days ' || pn_number_of_days);
        fnd_file.put_line (fnd_file.LOG,
                           '                ******************');

        UPDATE oe_order_lines_all
           SET credit_invoice_line_id = NULL, reference_customer_trx_line_id = NULL
         WHERE     header_id IN
                       (SELECT header_id
                          FROM oe_order_headers_all oh, apps.oe_order_sources os
                         WHERE     os.order_source_id = oh.order_source_id
                               AND oh.booked_flag = 'Y'
                               AND os.name = '3rd Party eCommerce'
                               AND oh.creation_date >
                                   SYSDATE - NVL (pn_number_of_days, 5))
               AND line_category_code = 'RETURN'
               AND actual_shipment_date IS NULL
               AND open_flag = 'Y'
               AND credit_invoice_line_id IS NOT NULL
               AND reference_customer_trx_line_id IS NOT NULL;

        ln_row_cnt   := SQL%ROWCOUNT;

        fnd_file.put_line (fnd_file.LOG, 'Rows Updated: ' || ln_row_cnt);

        pn_retcode   := 0;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            pn_retcode   := 2;
            pv_errbuf    := SUBSTR (SQLERRM, 1, 2000);

            fnd_file.put_line (fnd_file.LOG, 'Unecpcted Error ' || pv_errbuf);
    END update_shopify_ret_ord;
END XXD_SHOPIFY_UTILS_PKG;
/
