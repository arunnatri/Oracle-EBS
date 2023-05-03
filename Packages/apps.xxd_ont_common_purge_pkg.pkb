--
-- XXD_ONT_COMMON_PURGE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:54 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_COMMON_PURGE_PKG"
AS
    /*****************************************************************************************************
    * Package      : XXD_ONT_COMMON_PURGE_PKG
    * Design       : This package will be used to purge integration/customization tables
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 24-Jun-2019  1.0        Viswanathan Pandian     Initial Version
    -- 22-Apr-2020  1.1        Shivanshu Talwar        CCR0008417 - Purge the DeckersB2B Transnational Error table
    -- 22-Jun-2020  1.2        Shivanshu Talwar        CCR0008641 - Purge the DeckersB2B Master Error table
    -- 22-Aug-2020  1.3        Shivanshu Talwar        CCR0008880 - Purge the Product Integration tables
    -- 11-Dec-2020  1.4        Aravind Kannuri         CCR0009027 - Purge the Pricelist Integration tables
 -- 05-Dec-2022  1.5        Aravind Kannuri         CCR0009828 - Purge the 3PL LC Interface Debug table
    ******************************************************************************************************/
    PROCEDURE purge_so_batch_hist (x_retcode      OUT NOCOPY VARCHAR2,
                                   x_errbuf       OUT NOCOPY VARCHAR2)
    IS
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
            'Start Time: ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

        DELETE FROM
            xxdo.xxd_om_salesord_upd_bat_hist
              WHERE batch_date <
                      SYSDATE
                    - NVL (fnd_profile.VALUE ('XXD_CUST_BATCH_PURG_DAYS'),
                           20);

        fnd_file.put_line (fnd_file.LOG,
                           'Deleted Record Count = ' || SQL%ROWCOUNT);

        fnd_file.put_line (
            fnd_file.LOG,
            'End Time SO: ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));


        DELETE FROM
            xxdo.xxdoint_om_salesord_upd_batch             --W.r.t Verion  1.3
              WHERE batch_date <
                      SYSDATE
                    - NVL (fnd_profile.VALUE ('XXD_PRODUCT_BATCH_PURG_DAYS'),
                           20);

        fnd_file.put_line (fnd_file.LOG,
                           'Deleted Record Count = ' || SQL%ROWCOUNT);

        fnd_file.put_line (
            fnd_file.LOG,
            'End Time SO: ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

        purge_deckersb2b_error_tab (x_retcode   => x_retcode, --W.r.t version 1.1
                                    x_errbuf    => x_errbuf);

        purge_product_batch_hist (x_retcode => x_retcode,  --W.r.t version 1.3
                                                          x_errbuf => x_errbuf);

        purge_3pl_lc_debug (x_retcode => x_retcode,        --W.r.t version 1.5
                                                    x_errbuf => x_errbuf);
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            x_retcode   := '2';
            x_errbuf    := SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                'OTHERS Exception in PURGE_SO_BATCH_HIST:' || x_errbuf);
    END purge_so_batch_hist;


    PROCEDURE purge_deckersb2b_error_tab (x_retcode   OUT VARCHAR2, --Start W.r.t 1.1
                                          x_errbuf    OUT VARCHAR2)
    IS
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
               'Start Purging deckersb2b error table at '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

        DELETE FROM
            xxdo.xxd_ont_deckersb2b_error_t
              WHERE creation_date <
                      SYSDATE
                    - NVL (
                          fnd_profile.VALUE (
                              'XXD_ONT_DECKERSB2B_ERR_PURG_DAYS'),
                          10);

        fnd_file.put_line (
            fnd_file.LOG,
            'Deleted Transnational Error table Count = ' || SQL%ROWCOUNT);

        DELETE FROM
            xxdo.xxd_ont_b2b_master_data_err_t             --W.r.t version 1.2
              WHERE creation_date <
                      SYSDATE
                    - NVL (
                          fnd_profile.VALUE (
                              'XXD_ONT_DECKERSB2B_ERR_PURG_DAYS'),
                          10);

        fnd_file.put_line (
            fnd_file.LOG,
            'Deleted Master table Record Count = ' || SQL%ROWCOUNT);
        fnd_file.put_line (
            fnd_file.LOG,
               'End Purging deckersb2b error table at'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            x_retcode   := '2';
            x_errbuf    := SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                   'OTHERS Exception in PURGE_DECKERSB2B ERROR TABLE :'
                || x_errbuf);
    END purge_deckersb2b_error_tab;                            --End W.r.t 1.1

    PROCEDURE purge_product_batch_hist (x_retcode      OUT NOCOPY VARCHAR2, --Start W.r.t 1.3
                                        x_errbuf       OUT NOCOPY VARCHAR2)
    IS
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
               'Start Time Product Purge: '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

        DELETE FROM
            xxdo.xxdoint_inv_prd_cat_upd_batch
              WHERE batch_date <
                      SYSDATE
                    - NVL (fnd_profile.VALUE ('XXD_PRODUCT_BATCH_PURG_DAYS'),
                           10);

        fnd_file.put_line (
            fnd_file.LOG,
            'Product NC deleted Record Count = ' || SQL%ROWCOUNT);

        DELETE FROM
            xxdo.xxd_inv_prd_cat_upd_bat_hist_t
              WHERE batch_date <
                      SYSDATE
                    - NVL (
                          fnd_profile.VALUE ('XXD_PRD_BATCH_PURG_DAYS_HIST'),
                          45);


        fnd_file.put_line (
            fnd_file.LOG,
            'Product History Deleted Record Count = ' || SQL%ROWCOUNT);

        fnd_file.put_line (
            fnd_file.LOG,
               'End Purging Time for Product: '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            x_retcode   := '2';
            x_errbuf    := SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                'OTHERS Exception in PURGE_PRODUCT_BATCH_HIST:' || x_errbuf);
    END purge_product_batch_hist;                              --End W.r.t 1.3

    --Start Added as per CCR0009027
    PROCEDURE purge_price_batch_hist (x_retcode      OUT NOCOPY VARCHAR2,
                                      x_errbuf       OUT NOCOPY VARCHAR2)
    IS
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
               'Start Time Pricelist Purge: '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

        DELETE FROM
            xxdo.xxd_hbs_price_nc_batch
              WHERE batch_date <
                      SYSDATE
                    - NVL (fnd_profile.VALUE ('XXD_ONT_PL_BATCH_PURG_DAYS'),
                           15);

        fnd_file.put_line (
            fnd_file.LOG,
            'Pricelist NC deleted Record Count = ' || SQL%ROWCOUNT);

        fnd_file.put_line (
            fnd_file.LOG,
               'End Purging Time for Pricelist: '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));


        DELETE FROM
            xxdo.xxd_hbs_price_nc_batch_arch
              WHERE batch_date <
                      SYSDATE
                    - NVL (fnd_profile.VALUE ('XXD_ONT_PL_BATCH_PURG_DAYS'),
                           30);

        fnd_file.put_line (
            fnd_file.LOG,
            'Pricelist Arch NC deleted Record Count = ' || SQL%ROWCOUNT);

        fnd_file.put_line (
            fnd_file.LOG,
               'End Purging Time for Pricelist Archive : '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            x_retcode   := '2';
            x_errbuf    := SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                'OTHERS Exception in purge_price_batch_hist:' || x_errbuf);
    END purge_price_batch_hist;

    --End Added as per CCR0009027

    --Start Added as per CCR0009828
    PROCEDURE purge_3pl_lc_debug (x_retcode      OUT NOCOPY VARCHAR2,
                                  x_errbuf       OUT NOCOPY VARCHAR2)
    IS
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
               'Start Purging Time for 3PL LC Interface: '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

        DELETE FROM
            xxdo.xxd_3pl_lc_int_debug_t
              WHERE TRUNC (creation_date) <
                      SYSDATE
                    - NVL (fnd_profile.VALUE ('XXD_3PL_LC_INT_PURGE_DAYS'),
                           15);

        fnd_file.put_line (
            fnd_file.LOG,
            '3PL LC Interface Deleted Record Count = ' || SQL%ROWCOUNT);

        fnd_file.put_line (
            fnd_file.LOG,
               'End Purging Time for 3PL LC Interface: '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            x_retcode   := '2';
            x_errbuf    := SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                'OTHERS Exception in purge_3pl_lc_debug:' || x_errbuf);
    END purge_3pl_lc_debug;
--End Added as per CCR0009828

END xxd_ont_common_purge_pkg;
/
