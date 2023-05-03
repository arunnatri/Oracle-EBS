--
-- XXD_FA_VT_INTEGRATION_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:30:27 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_FA_VT_INTEGRATION_PKG"
AS
    /****************************************************************************************
     * Package      : XXD_FA_VT_INTEGRATION_PKG
     * Design       : This package will be used for FA and VT integration
     * Notes        :
     * Modification :
     -- ======================================================================================
     -- Date         Version#   Name                    Comments
     -- ======================================================================================
     -- 27-DEC-2020  1.0        Tejaswi Gangumalla      Initial Version
     ******************************************************************************************/
    gn_request_id   NUMBER := fnd_global.conc_request_id;
    gn_user_id      NUMBER := fnd_global.user_id;
    gn_login_id     NUMBER := fnd_profile.VALUE ('LOGIN_ID');

    PROCEDURE insert_into_stg
    AS
    BEGIN
        INSERT INTO xxdo.xxd_fa_vt_int_stg (asset_id, book_type_code, process_history_id, description, category_id, location_id, units, accounted_cr, expense_account_id, transaction_date, status, request_id, created_by, creation_date, last_updated_by
                                            , last_updated_date)
            SELECT cpta.transaction_ref1, fb.book_type_code, ph.process_history_id,
                   'VT Integration ' || fa.asset_number, fa.asset_category_id, fdh.location_id,
                   1, ph.accounted_cr, fdh.code_combination_id,
                   ph.accounting_date, 'N', gn_request_id,
                   gn_user_id, SYSDATE, gn_user_id,
                   SYSDATE
              FROM apps.xxcp_process_history ph, apps.xxcp_account_rules car, apps.xxcp_transaction_attributes cpta,
                   apps.fa_books_v fb, fa_distribution_history fdh, fa_additions_b fa
             WHERE     ph.rule_id = car.rule_id(+)
                   AND car.rule_name = 'MTD Unrecoverable'
                   AND cpta.attribute_id = ph.attribute_id
                   AND TO_CHAR (fb.asset_id) = cpta.transaction_ref1
                   AND fdh.asset_id = cpta.transaction_ref1
                   AND fa.asset_id = fdh.asset_id
                   AND NVL (ph.accounted_cr, 0) <> 0
                   AND ph.segment1 =
                       (SELECT partner_short
                          FROM apps.xxcp_transaction_attrib_hdr_v
                         WHERE header_id = cpta.header_id AND ROWNUM = 1)
                   AND NOT EXISTS
                           (SELECT 1
                              FROM xxdo.xxd_fa_vt_int_stg xxd
                             WHERE     xxd.process_history_id =
                                       ph.process_history_id
                                   AND status = 'S')
            UNION
            SELECT cpta.transaction_ref1, fb.book_type_code, ph.process_history_id,
                   'VT Integration ' || fa.asset_number, fa.asset_category_id, fdh.location_id,
                   1, ph.accounted_cr, fdh.code_combination_id,
                   ph.accounting_date, 'N', gn_request_id,
                   gn_user_id, SYSDATE, gn_user_id,
                   SYSDATE
              FROM apps.xxcp_process_history_arc ph, apps.xxcp_account_rules car, apps.xxcp_trans_attributes_arc cpta,
                   apps.fa_books_v fb, fa_distribution_history fdh, fa_additions_b fa
             WHERE     ph.rule_id = car.rule_id(+)
                   AND car.rule_name = 'MTD Unrecoverable'
                   AND cpta.attribute_id = ph.attribute_id
                   AND TO_CHAR (fb.asset_id) = cpta.transaction_ref1
                   AND TO_CHAR (fdh.asset_id) = cpta.transaction_ref1
                   AND fa.asset_id = fdh.asset_id
                   AND NVL (ph.accounted_cr, 0) <> 0
                   AND ph.segment1 =
                       (SELECT partner_short
                          FROM apps.xxcp_transaction_attrib_hdr_v
                         WHERE header_id = cpta.header_id AND ROWNUM = 1)
                   AND NOT EXISTS
                           (SELECT 1
                              FROM xxdo.xxd_fa_vt_int_stg xxd
                             WHERE     xxd.process_history_id =
                                       ph.process_history_id
                                   AND status = 'S');

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'exception while inserting data into staging table'
                || SQLERRM);
    END insert_into_stg;

    PROCEDURE insert_into_interface
    AS
        lv_err_flag   VARCHAR2 (5) := 'N';
    BEGIN
        BEGIN
            INSERT INTO fa_mass_additions (mass_addition_id, book_type_code, description, asset_number, asset_category_id, fixed_assets_cost, expense_code_combination_id, location_id, queue_name, posting_status, asset_type, date_placed_in_service, fixed_assets_units, create_batch_date, created_by, creation_date, last_update_date, last_updated_by
                                           , last_update_login)
                SELECT fa_mass_additions_s.NEXTVAL, book_type_code, description,
                       asset_id, category_id, accounted_cr,
                       expense_account_id, location_id, 'NEW',
                       'NEW', 'CAPITALIZED', transaction_date,
                       units, SYSDATE, gn_user_id,
                       SYSDATE, SYSDATE, gn_user_id,
                       gn_login_id
                  FROM xxdo.xxd_fa_vt_int_stg
                 WHERE status = 'N' AND request_id = gn_request_id;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_err_flag   := 'Y';
                fnd_file.put_line (
                    fnd_file.LOG,
                       'exception while inserting data into fa_mass_additions '
                    || SQLERRM);
        END;

        IF lv_err_flag = 'N'
        THEN
            UPDATE xxdo.xxd_fa_vt_int_stg
               SET status   = 'S'
             WHERE request_id = gn_request_id;
        ELSE
            UPDATE xxdo.xxd_fa_vt_int_stg
               SET status   = 'E'
             WHERE request_id = gn_request_id;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'exception in insert_into_interface' || SQLERRM);
    END insert_into_interface;

    PROCEDURE main (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY NUMBER)
    AS
    BEGIN
        insert_into_stg ();
        insert_into_interface ();
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'exception in main program' || SQLERRM);
    END main;
END;
/
