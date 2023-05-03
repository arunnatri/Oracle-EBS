--
-- XXD_PO_BUY_SEASON_MTH_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:55 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_PO_BUY_SEASON_MTH_PKG"
IS
    /****************************************************************************************
      * Package      : XXD_PO_BUY_SEASON_MTH_PKG
      * Design       : WebADI package to update PO Buy Month and Buy Season
      * Notes        :
      * Modification :
      -- ===============================================================================
      -- Date         Version#   Name                    Comments
      -- ===============================================================================
      -- 18-Dec-2020  1.0        Greg Jensen             Initial Version
      ******************************************************************************************/

    --Global Variables
    --Constants
    gv_package_name      CONSTANT VARCHAR2 (30) := 'XXD_PO_UPDATE_BUY_DATE_PKG';
    gn_user_id           CONSTANT NUMBER := fnd_global.user_id;
    gn_login_id          CONSTANT NUMBER := fnd_global.login_id;
    gn_conc_request_id   CONSTANT NUMBER := fnd_global.conc_request_id;

    PROCEDURE purge_stg_data (pn_no_days IN NUMBER:= 180)
    IS
    BEGIN
        DELETE FROM XXDO.XXD_PO_BUY_SEASON_MTH_STG_T
              WHERE creation_date <= TRUNC (SYSDATE) - pn_no_days;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END;

    PROCEDURE insert_into_stg_table (pv_po_number IN VARCHAR2, pn_po_header_id IN NUMBER, pv_buy_season IN VARCHAR2
                                     , pv_buy_month IN VARCHAR2, pv_error_message IN VARCHAR2, xv_error_message OUT VARCHAR2)
    IS
        ln_seq_id         NUMBER := 0;
        ln_inv_org_id     NUMBER;
        ln_po_header_id   NUMBER;
    BEGIN
        BEGIN
            SELECT XXDO.XXD_PO_BUY_SEASON_MTH_STG_S.NEXTVAL
              INTO ln_seq_id
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                xv_error_message   :=
                    SUBSTR (
                           'Error while getting seq id from XXD_SHIP_TO_MOQ_STG_SEQ_NO_S sequence. Error is: '
                        || SQLERRM,
                        1,
                        2000);
        END;

        INSERT INTO XXDO.XXD_PO_BUY_SEASON_MTH_STG_T (seq_no, po_number, po_header_id, buy_season, buy_month, status, error_message, request_id, creation_date, created_by, last_update_date, last_updated_by
                                                      , last_update_login)
             VALUES (ln_seq_id, pv_po_number, pn_po_header_id,
                     pv_buy_season, pv_buy_month, 'N',
                     NULL, gn_conc_request_id, SYSDATE,
                     gn_user_id, SYSDATE, gn_user_id,
                     gn_login_id);
    EXCEPTION
        WHEN OTHERS
        THEN
            xv_error_message   :=
                SUBSTR (
                       'Error while inserting data into staging table. Error is: '
                    || SQLERRM,
                    1,
                    2000);
    END;

    PROCEDURE upload_proc (pv_po_number IN VARCHAR2, pv_buy_season IN VARCHAR2, pv_buy_month IN VARCHAR2)
    IS
        lv_error_message      VARCHAR2 (2000) := NULL;
        lv_return_status      VARCHAR2 (1) := NULL;
        lv_create_err_msg     VARCHAR2 (2000) := NULL;
        ln_po_header_id       NUMBER;
        lv_buy_season         VARCHAR2 (40);
        lv_buy_month          VARCHAR2 (40);

        --PO data for PO validation
        lv_closed_code        VARCHAR2 (20);
        lv_trade_loc          VARCHAR2 (10);

        ln_Count              NUMBER;
        --User Defined Exceptions
        le_webadi_exception   EXCEPTION;
    BEGIN
        --Begin data validation

        --1. NULL Values
        --2. PO number PO is Trade, Open and has no received qty
        --3. Buy season is in lookup
        --4. Buy Month is in lookup

        --Check Required Parameters
        IF    pv_po_number IS NULL
           OR (pv_buy_season IS NULL AND pv_buy_month IS NULL)
        THEN
            lv_error_message   := 'One or more required fields are missing. ';
            RAISE le_webadi_exception;
        END IF;

        --Data Validation
        --1) PO number PO is Trade, Open and has no received qty
        --This should also resolve to a single PO_HEADER_ID
        BEGIN
              SELECT pha.po_header_id, pha.attribute8 buy_season, pha.attribute9 buy_month,
                     mp.attribute13 trade_loc, pha.closed_code closed_code
                INTO ln_po_header_id, lv_buy_season, lv_buy_month, lv_trade_loc,
                                    lv_closed_code
                FROM po_headers_all pha, po_line_locations_all plla, mtl_parameters mp
               WHERE     pha.segment1 = pv_po_number
                     AND pha.po_header_id = plla.po_header_id
                     AND plla.ship_to_organization_id = mp.organization_id
            GROUP BY pha.po_header_id, mp.attribute13, pha.closed_code,
                     pha.attribute8, pha.attribute9;

            --Check if PO is open
            IF NVL (lv_closed_code, 'OPEN') != 'OPEN'
            THEN
                lv_error_message   := 'PO is closed';
                RAISE le_webadi_exception;
            END IF;

            --Check if PO is destined to a TRADE location
            IF NVL (lv_trade_loc, '1') = '1'
            THEN
                lv_error_message   := 'PO is not a trade PO';
                RAISE le_webadi_exception;
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lv_error_message   := 'PO Not found';
                RAISE le_webadi_exception;
            WHEN TOO_MANY_ROWS
            THEN
                --Multiple PO header IDs found
                lv_error_message   :=
                    'Multiple PO Headers returned for PO number';
                RAISE le_webadi_exception;
            WHEN le_webadi_exception
            THEN
                RAISE le_webadi_exception;
        END;

        IF pv_buy_season IS NOT NULL
        THEN
            --2) Buy season is in lookup
            SELECT COUNT (*)
              INTO ln_count
              FROM fnd_flex_value_sets fvs, fnd_flex_values fv
             WHERE     flex_value_set_name = 'DO_PO_BUY_SEASONS'
                   AND fvs.flex_value_set_id = fv.flex_value_set_id
                   AND fv.flex_value = pv_buy_season;

            IF ln_count = 0
            THEN
                lv_error_message   := 'Buy season is not valid';
                RAISE le_webadi_exception;
            END IF;
        END IF;

        IF pv_buy_month IS NOT NULL
        THEN
            --3) Buy Month is in lookup
            SELECT COUNT (*)
              INTO ln_count
              FROM fnd_flex_value_sets fvs, fnd_flex_values fv
             WHERE     flex_value_set_name = 'DO_BUY_MONTH_YEAR'
                   AND fvs.flex_value_set_id = fv.flex_value_set_id
                   AND fv.flex_value = pv_buy_month;

            IF ln_count = 0
            THEN
                lv_error_message   := 'Buy month is not valid';
                RAISE le_webadi_exception;
            END IF;
        END IF;

        IF     NVL (pv_buy_season, lv_buy_season) = lv_buy_season
           AND NVL (pv_buy_month, lv_buy_month) = lv_buy_month
        THEN
            lv_error_message   := 'No update needed';
            RAISE le_webadi_exception;
        END IF;

        --End data validation
        IF lv_error_message IS NULL
        THEN
            --Insert the record into the staging table
            insert_into_stg_table (pv_po_number       => pv_po_number,
                                   pn_po_header_id    => ln_po_header_id,
                                   pv_buy_season      => pv_buy_season,
                                   pv_buy_month       => pv_buy_month,
                                   pv_error_message   => NULL --lv_error_message
                                                             ,
                                   xv_error_message   => lv_create_err_msg);
        ELSE
            RAISE le_webadi_exception;                      -- Raise exception
        END IF;

        IF lv_create_err_msg IS NOT NULL
        THEN
            lv_return_status   := gv_ret_error;
            lv_error_message   := lv_error_message || lv_create_err_msg;
            RAISE le_webadi_exception; -- Raise exception as we cannot proceed with out inserting the record into the staging table
        END IF;

        UPDATE po_headers_all
           SET attribute8 = NVL (pv_buy_season, attribute8), attribute9 = NVL (pv_buy_month, attribute9), last_update_date = SYSDATE,
               last_updated_by = gn_user_id
         WHERE     po_header_id = ln_po_header_id
               AND (attribute8 != NVL (pv_buy_season, attribute8) OR attribute9 != NVL (pv_buy_month, attribute9));


        UPDATE XXDO.XXD_PO_BUY_SEASON_MTH_STG_T
           SET status   = 'P'
         WHERE po_header_id = ln_po_header_id AND status = 'N';
    EXCEPTION
        WHEN le_webadi_exception
        THEN
            lv_error_message   := SUBSTR (lv_error_message, 1, 2000);
            fnd_message.set_name ('XXDO', 'XXD_PO_UPD_BUY_SEAS_WEBADI_MSG');
            fnd_message.set_token ('ERROR_MESSAGE', lv_error_message);
            lv_error_message   := fnd_message.get ();
            raise_application_error (-20000, lv_error_message);
        WHEN OTHERS
        THEN
            lv_error_message   :=
                SUBSTR (lv_error_message || '.' || SQLERRM, 1, 2000);
            fnd_message.set_name ('XXDO', 'XXD_PO_UPD_BUY_SEAS_WEBADI_MSG');
            fnd_message.set_token ('ERROR_MESSAGE', lv_error_message);
            lv_error_message   := fnd_message.get ();
            raise_application_error (-20001, lv_error_message);
    END upload_proc;

    --Use importer to do purge of old data as we only want this run once

    PROCEDURE importer_proc (pv_errbuf       OUT NOCOPY VARCHAR2,
                             pn_retcode      OUT NOCOPY NUMBER)
    IS
        --Local Variables
        lv_proc_name      VARCHAR2 (30) := 'IMPORTER_PROC';
        lv_program_name   VARCHAR2 (30) := '<Program name>';
        --        lv_error_message            VARCHAR2(2000)  :=  NULL;
        --lv_return_status            VARCHAR2(1)     :=  NULL;
        lv_err_msg        VARCHAR2 (4000) := NULL;
        ln_rec_cnt        NUMBER := 0;                      --Added for change
    BEGIN
        purge_stg_data;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_err_msg   :=
                   'In When others exception <program name>. Error in Package '
                || gv_package_name
                || '.'
                || lv_proc_name;
            lv_err_msg   :=
                SUBSTR (lv_err_msg || '. Error is : ' || SQLERRM, 1, 2000);

            --xxd_ascp_jg_util_pkg.msg (lv_err_msg); --Print the error message to log file
            --xxd_ascp_jg_util_pkg.debug_proc (lv_program_name, lv_err_msg);
            pn_retcode   := gn_error;
            pv_errbuf    := SUBSTR (lv_err_msg, 1, 2000);
    END importer_proc;
END XXD_PO_BUY_SEASON_MTH_PKG;
/
