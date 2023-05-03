--
-- XXD_ONT_BO_RD_GATE_UPDT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:03 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_BO_RD_GATE_UPDT_PKG"
IS
    /****************************************************************************************
    * Package      : XXD_ONT_BO_RD_GATE_UPDT_PKG
    * Design       : The concurrent program to process the parameters from the lookup
                     and to update the sales order headers table
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 10-Feb-2021  1.0        Damodara Gupta          Initial Version
    -- 18-Jul-2022  1.1        Aravind Kannuri         Updated for CCR0010075
    -- 12-JAN-2023  1.2        Srinath Siricilla       CCR0010040
    ******************************************************************************************/

    PROCEDURE write_log_prc (pv_msg IN VARCHAR2)
    IS
        /****************************************************
        -- PROCEDURE write_log_prc
        -- PURPOSE: This Procedure write the log messages
        *****************************************************/
        lv_msg   VARCHAR2 (4000) := pv_msg;
    BEGIN
        IF gn_user_id = -1
        THEN
            DBMS_OUTPUT.put_line (pv_msg);
        ELSE
            apps.fnd_file.put_line (apps.fnd_file.LOG, pv_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'Error in write_log_prc Procedure -' || SQLERRM);
            DBMS_OUTPUT.put_line (
                'Error in write_log_prc Procedure -' || SQLERRM);
    END write_log_prc;

    --Start Added for CCR0010075
    --Exclusion date range to Bulk Orders based on blackout dates lookup
    --Exlcusion RD start date <= Order attr18 value <= RD end date
    FUNCTION excl_bo_attr18_dt_exist (p_threshold IN VARCHAR2, p_rd_gate_lkp_code IN VARCHAR2, p_attr18_19_dt IN VARCHAR2)
        RETURN NUMBER
    IS
        ln_exists    NUMBER := 0;

        -- Commented and added as per CCR0010040

        --ld_to_date   DATE := TO_DATE (p_attr18_19_dt, 'YYYY/MM/DD');
        ld_to_date   DATE
                         := TO_DATE (p_attr18_19_dt, 'RRRR/MM/DD HH24:MI:SS'); -- CCR0010040

        CURSOR lkp_cur IS
            SELECT 1   ret_value
              FROM fnd_lookup_values
             WHERE     lookup_type = 'XXD_ONT_BO_RD_GATE_BO_DT'
                   AND language = 'US'
                   AND enabled_flag = 'Y'
                   AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE - 1)
                                   AND NVL (end_date_active, SYSDATE + 1)
                   AND attribute1 = p_rd_gate_lkp_code
                   AND ((NVL (attribute2, 'RD_START') = NVL (p_threshold, 'RD_START') AND NVL (TO_DATE (attribute3, 'RRRR/MM/DD HH24:MI:SS'), TRUNC (SYSDATE)) <= ld_to_date --attribute18 check
                                                                                                                                                                             AND NVL (TO_DATE (attribute4, 'RRRR/MM/DD HH24:MI:SS'), TRUNC (SYSDATE)) >= ld_to_date) OR (NVL (attribute2, 'RD_START') = NVL (p_threshold, 'RD_START') AND NVL (TO_DATE (attribute3, 'RRRR/MM/DD HH24:MI:SS'), TRUNC (SYSDATE)) <= ld_to_date AND NVL (TO_DATE (attribute4, 'RRRR/MM/DD HH24:MI:SS'), TRUNC (SYSDATE)) >= ld_to_date));
    BEGIN
        --write_log_prc('Exclusion RD Start\End date- ld_to_date : '||ld_to_date);
        IF p_attr18_19_dt IS NOT NULL
        THEN
            FOR i IN lkp_cur
            LOOP
                ln_exists   := ln_exists + i.ret_value;
            END LOOP;

            IF ln_exists > 0
            THEN
                --write_log_prc('Exclusion of p_attr18_19_dt :'||ld_to_date ||' Returns : 0');
                RETURN 0;
            ELSE
                --write_log_prc('Inclusion of p_attr18_19_dt :'||ld_to_date ||' Returns : 1');
                RETURN 1;
            END IF;
        ELSE
            RETURN 1;                                  --No Exclusion required
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            --write_log_prc('Inclusion If no configurations in lookup :'||ld_to_date ||' Returns : 1');
            ln_exists   := 1;
            RETURN ln_exists;
    END;

    --Exclusion date range to Bulk Orders based on blackout dates lookup
    --Exlcusion RD start date <= Order attr19 value <= RD end date
    FUNCTION excl_bo_attr19_dt_exist (p_threshold IN VARCHAR2, p_rd_gate_lkp_code IN VARCHAR2, p_attr18_19_dt IN VARCHAR2)
        RETURN NUMBER
    IS
        ln_exists    NUMBER := 0;

        -- Commented and added as per CCR0010040

        -- ld_to_date   DATE := TO_DATE (p_attr18_19_dt, 'YYYY/MM/DD');
        ld_to_date   DATE
                         := TO_DATE (p_attr18_19_dt, 'RRRR/MM/DD HH24:MI:SS'); -- CCR0010040


        CURSOR lkp_cur IS
            SELECT 1   ret_value
              FROM fnd_lookup_values
             WHERE     lookup_type = 'XXD_ONT_BO_RD_GATE_BO_DT'
                   AND language = 'US'
                   AND enabled_flag = 'Y'
                   AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE - 1)
                                   AND NVL (end_date_active, SYSDATE + 1)
                   AND attribute1 = p_rd_gate_lkp_code
                   AND ((NVL (attribute2, 'RD_END') = NVL (p_threshold, 'RD_END') AND NVL (TO_DATE (attribute3, 'RRRR/MM/DD HH24:MI:SS'), TRUNC (SYSDATE)) <= ld_to_date AND NVL (TO_DATE (attribute4, 'RRRR/MM/DD HH24:MI:SS'), TRUNC (SYSDATE)) >= ld_to_date) OR (NVL (attribute2, 'RD_END') = NVL (p_threshold, 'RD_END') AND NVL (TO_DATE (attribute3, 'RRRR/MM/DD HH24:MI:SS'), TRUNC (SYSDATE)) <= ld_to_date --attribute19 check
                                                                                                                                                                                                                                                                                                                                                                                                                     AND NVL (TO_DATE (attribute4, 'RRRR/MM/DD HH24:MI:SS'), TRUNC (SYSDATE)) >= ld_to_date));
    BEGIN
        --write_log_prc('Exclusion RD Start\End date- ld_to_date : '||ld_to_date);
        IF p_attr18_19_dt IS NOT NULL
        THEN
            FOR i IN lkp_cur
            LOOP
                ln_exists   := ln_exists + i.ret_value;
            END LOOP;

            IF ln_exists > 0
            THEN
                --write_log_prc('Exclusion of p_attr18_19_dt :'||ld_to_date ||' Returns : 0');
                RETURN 0;
            ELSE
                --write_log_prc('Inclusion of p_attr18_19_dt :'||ld_to_date ||' Returns : 1');
                RETURN 1;
            END IF;
        ELSE
            RETURN 1;                                  --No Exclusion required
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            --write_log_prc('Inclusion If no configurations in lookup :'||ld_to_date ||' Returns : 1');
            ln_exists   := 1;
            RETURN ln_exists;
    END;

    --End Added for CCR0010075

    /***************************************************************************
 -- PROCEDURE main_prc
 -- PURPOSE: This Procedure is Concurrent Program.
 ****************************************************************************/

    PROCEDURE main_prc (errbuf                  OUT NOCOPY VARCHAR2,
                        retcode                 OUT NOCOPY VARCHAR2,
                        pv_org_id            IN            NUMBER,
                        pv_brand             IN            VARCHAR2,
                        pv_order_type_id     IN            VARCHAR2,
                        pv_cust_account_id   IN            VARCHAR2)
    IS
        CURSOR lkp_cur IS
              SELECT attribute1 org_id, attribute2 brand, attribute3 order_type_id,
                     attribute4 cust_account_id, attribute5 num_of_days, lookup_code rd_gate_lkp_code,
                     TO_DATE (attribute6, 'RRRR/MM/DD HH24:MI:SS') rd_start_dt, TO_DATE (attribute7, 'RRRR/MM/DD HH24:MI:SS') rd_end_dt
                FROM fnd_lookup_values
               WHERE     lookup_type = 'XXD_ONT_BO_RD_GATE_RANGE'
                     AND language = 'US'
                     AND enabled_flag = 'Y'
                     AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE - 1)
                                     AND NVL (end_date_active, SYSDATE + 1)
                     AND attribute1 = pv_org_id
                     AND attribute2 = NVL (pv_brand, attribute2)
                     AND NVL (attribute3, 'X2X') =
                         NVL (pv_order_type_id, NVL (attribute3, 'X2X'))
                     AND NVL (attribute4, 'Y2Y') =
                         NVL (pv_cust_account_id, NVL (attribute4, 'Y2Y'))
            ORDER BY attribute4 DESC;

        TYPE rec_18 IS RECORD
        (
            header_id          oe_order_headers_all.header_id%TYPE,
            request_date       oe_order_headers_all.request_date%TYPE,
            new_attribute18    apps.oe_order_headers_all.attribute18%TYPE,
            old_attribute18    apps.oe_order_headers_all.attribute18%TYPE
        );

        TYPE col_rec_18 IS TABLE OF rec_18;

        v_rec_18   col_rec_18;

        TYPE rec_19 IS RECORD
        (
            header_id          oe_order_headers_all.header_id%TYPE,
            request_date       oe_order_headers_all.request_date%TYPE,
            new_attribute19    apps.oe_order_headers_all.attribute19%TYPE,
            old_attribute19    apps.oe_order_headers_all.attribute19%TYPE
        );

        TYPE col_rec_19 IS TABLE OF rec_19;

        v_rec_19   col_rec_19;
    BEGIN
        write_log_prc (CHR (10));
        write_log_prc (
               'Main Process Begins...'
            || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
        write_log_prc ('Parameters:');
        write_log_prc ('-----------');
        write_log_prc ('Operating Unit:-' || pv_org_id);
        write_log_prc ('Brand:-' || pv_brand);
        write_log_prc ('Order Type ID:-' || pv_order_type_id);
        write_log_prc ('Customer Account ID:-' || pv_cust_account_id);
        write_log_prc (CHR (10));

        FOR i IN lkp_cur
        LOOP
            write_log_prc ('Lookup Values:');
            write_log_prc ('--------------');
            write_log_prc ('Operating Unit:-' || i.org_id);
            write_log_prc ('Brand:-' || i.brand);
            write_log_prc ('Order Type ID:-' || i.order_type_id);
            write_log_prc ('Customer Account ID:-' || i.cust_account_id);
            write_log_prc ('Num_of_days:-' || i.num_of_days);
            write_log_prc (
                'Request Date Range For Start Date:-' || i.rd_start_dt);
            write_log_prc (
                'Request Date Range For End Date:-' || i.rd_end_dt);
            write_log_prc (CHR (10));

            BEGIN
                write_log_prc ('Before ATTRIBUTE18 update');

                   UPDATE (SELECT ooha.*, (SELECT ooha.attribute18 FROM DUAL) AS old_attribute18
                             FROM apps.oe_order_headers_all ooha)
                      SET attribute18 = TO_CHAR (TRUNC (request_date) - i.num_of_days, 'RRRR/MM/DD'), last_updated_by = gn_user_id, last_update_date = SYSDATE
                    WHERE     1 = 1
                          AND org_id = i.org_id
                          AND attribute5 = i.brand
                          AND NVL (attribute18, '2000/01/01') !=
                              TO_CHAR ((TRUNC (request_date) - i.num_of_days),
                                       'RRRR/MM/DD')
                          AND (   (order_type_id = i.order_type_id AND i.order_type_id IS NOT NULL)
                               OR     (order_type_id IN
                                           (SELECT otta.transaction_type_id
                                              FROM oe_transaction_types_all otta, oe_transaction_types_tl ott
                                             WHERE     ott.transaction_type_id =
                                                       otta.transaction_type_id
                                                   AND otta.attribute5 = 'BO'
                                                   AND ott.language = 'US'
                                                   AND UPPER (ott.name) NOT LIKE
                                                           '%SHADOW%'
                                                   AND NVL (
                                                           TRUNC (
                                                               otta.end_date_active),
                                                           TRUNC (SYSDATE + 1)) >=
                                                       TRUNC (SYSDATE)
                                                   AND otta.org_id = i.org_id))
                                  AND i.order_type_id IS NULL)
                          AND (   (sold_to_org_id = i.cust_account_id AND i.cust_account_id IS NOT NULL)
                               OR     sold_to_org_id IN
                                          (SELECT cust_account_id
                                             FROM hz_cust_accounts hca
                                            WHERE     hca.attribute1 =
                                                      NVL (i.brand,
                                                           hca.attribute1)
                                                  AND hca.status = 'A'
                                                  AND EXISTS
                                                          (SELECT 1
                                                             FROM hz_cust_acct_sites_all hcas
                                                            WHERE     hcas.cust_account_id =
                                                                      hca.cust_account_id
                                                                  AND hcas.status =
                                                                      'A'
                                                                  AND hcas.org_id =
                                                                      i.org_id))
                                  AND i.cust_account_id IS NULL)
                          AND TRUNC (request_date) >= TO_DATE (i.rd_start_dt)
                          --Start Added for CCR0010075
                          AND excl_bo_attr18_dt_exist (
                                  p_threshold          => 'RD_START', --RD_START\RD_END
                                  p_rd_gate_lkp_code   => i.rd_gate_lkp_code,
                                  p_attr18_19_dt       => attribute18) =
                              1
                          AND excl_bo_attr19_dt_exist (
                                  p_threshold          => 'RD_END', --RD_START\RD_END
                                  p_rd_gate_lkp_code   => i.rd_gate_lkp_code,
                                  p_attr18_19_dt       => attribute19) =
                              1
                --End Added for CCR0010075
                RETURNING header_id, request_date, attribute18,
                          old_attribute18
                     BULK COLLECT INTO v_rec_18;

                write_log_prc (
                       SQL%ROWCOUNT
                    || ' Records Updated in OE ORDER HEADERS ALL TABLE - ATTRIBUTE18');
                COMMIT;
            -- ROLLBACK;
            EXCEPTION
                WHEN OTHERS
                THEN
                    write_log_prc (
                           'Failed to update ATTRIBUTE18 For Org- '
                        || i.org_id
                        || 'Brand- '
                        || i.brand
                        || 'Order Type ID- '
                        || i.order_type_id
                        || ' with error_code- '
                        || SQLERRM);

                    retcode   := 2;
                    ROLLBACK;
            END;

            IF v_rec_18.COUNT > 0
            THEN
                FOR i IN v_rec_18.FIRST .. v_rec_18.LAST
                LOOP
                    write_log_prc (
                           'Order Header ID => '
                        || v_rec_18 (i).header_id
                        || '- Request Date=> '
                        || v_rec_18 (i).request_date
                        || '- Old attribute18 => '
                        || v_rec_18 (i).old_attribute18
                        || '- New attribute18 => '
                        || v_rec_18 (i).new_attribute18);
                END LOOP;
            END IF;

            v_rec_18.DELETE;
            write_log_prc (CHR (10));
            write_log_prc (CHR (10));

            write_log_prc ('Num_of_days:-' || i.num_of_days);
            write_log_prc ('Request Date For End Date:-' || i.rd_end_dt);
            write_log_prc (CHR (10));

            BEGIN
                write_log_prc ('Before ATTRIBUTE19 update');

                   UPDATE (SELECT ooha.*, (SELECT ooha.attribute19 FROM DUAL) AS old_attribute19
                             FROM apps.oe_order_headers_all ooha)
                      SET attribute19 = TO_CHAR (TRUNC (request_date) + i.num_of_days, 'RRRR/MM/DD'), last_updated_by = gn_user_id, last_update_date = SYSDATE
                    WHERE     1 = 1
                          AND org_id = i.org_id
                          AND attribute5 = i.brand
                          AND NVL (attribute19, '2000/01/01') !=
                              TO_CHAR ((TRUNC (request_date) + i.num_of_days),
                                       'RRRR/MM/DD')
                          AND (   (order_type_id = i.order_type_id AND i.order_type_id IS NOT NULL)
                               OR     (order_type_id IN
                                           (SELECT otta.transaction_type_id
                                              FROM oe_transaction_types_all otta, oe_transaction_types_tl ott
                                             WHERE     ott.transaction_type_id =
                                                       otta.transaction_type_id
                                                   AND otta.attribute5 = 'BO'
                                                   AND ott.language = 'US'
                                                   AND UPPER (ott.name) NOT LIKE
                                                           '%SHADOW%'
                                                   AND NVL (
                                                           TRUNC (
                                                               otta.end_date_active),
                                                           TRUNC (SYSDATE + 1)) >=
                                                       TRUNC (SYSDATE)
                                                   AND otta.org_id = i.org_id))
                                  AND i.order_type_id IS NULL)
                          AND (   (sold_to_org_id = i.cust_account_id AND i.cust_account_id IS NOT NULL)
                               OR     sold_to_org_id IN
                                          (SELECT cust_account_id
                                             FROM hz_cust_accounts hca
                                            WHERE     hca.attribute1 =
                                                      NVL (i.brand,
                                                           hca.attribute1)
                                                  AND hca.status = 'A'
                                                  AND EXISTS
                                                          (SELECT 1
                                                             FROM hz_cust_acct_sites_all hcas
                                                            WHERE     hcas.cust_account_id =
                                                                      hca.cust_account_id
                                                                  AND hcas.status =
                                                                      'A'
                                                                  AND hcas.org_id =
                                                                      i.org_id))
                                  AND i.cust_account_id IS NULL)
                          AND TRUNC (request_date) >= i.rd_end_dt
                          --Start Added for CCR0010075
                          AND excl_bo_attr18_dt_exist (
                                  p_threshold          => 'RD_START', --RD_START\RD_END
                                  p_rd_gate_lkp_code   => i.rd_gate_lkp_code,
                                  p_attr18_19_dt       => attribute18) =
                              1
                          AND excl_bo_attr19_dt_exist (
                                  p_threshold          => 'RD_END', --RD_START\RD_END
                                  p_rd_gate_lkp_code   => i.rd_gate_lkp_code,
                                  p_attr18_19_dt       => attribute19) =
                              1
                --End Added for CCR0010075
                RETURNING header_id, request_date, attribute19,
                          old_attribute19
                     BULK COLLECT INTO v_rec_19;

                write_log_prc (
                       SQL%ROWCOUNT
                    || ' Records Updated in OE ORDER HEADERS ALL TABLE - ATTRIBUTE19');
                COMMIT;
            -- ROLLBACK;
            EXCEPTION
                WHEN OTHERS
                THEN
                    write_log_prc (
                           'Failed to update ATTRIBUTE19 For Org- '
                        || i.org_id
                        || 'Brand- '
                        || i.brand
                        || 'Order Type ID- '
                        || i.order_type_id
                        || ' with error_code- '
                        || SQLERRM);

                    ROLLBACK;
                    retcode   := 2;
            END;

            IF v_rec_19.COUNT > 0
            THEN
                FOR i IN v_rec_19.FIRST .. v_rec_19.LAST
                LOOP
                    write_log_prc (
                           'Order Header ID => '
                        || v_rec_19 (i).header_id
                        || '- Request Date=> '
                        || v_rec_19 (i).request_date
                        || '- Old attribute19 => '
                        || v_rec_19 (i).old_attribute19
                        || '- New attribute19 => '
                        || v_rec_19 (i).new_attribute19);
                END LOOP;
            END IF;

            v_rec_19.DELETE;
            write_log_prc (CHR (10));
        END LOOP;

        write_log_prc (
               'Main Process Ends...'
            || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
    EXCEPTION
        WHEN OTHERS
        THEN
            retcode   := 2;
            write_log_prc ('Exception Occurred in Main_Prc-' || SQLERRM);
    END main_prc;
END xxd_ont_bo_rd_gate_updt_pkg;
/
