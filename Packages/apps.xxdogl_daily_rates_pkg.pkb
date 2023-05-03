--
-- XXDOGL_DAILY_RATES_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:40:44 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.XXDOGL_DAILY_RATES_PKG
AS
    --------------------------------------------------------------------------------
    -- Created By              : Vijaya Reddy ( Suneara Technologies )
    -- Creation Date           : 25-APR-2011
    -- File Name               : XXDOGL009.pks
    -- INCIDENT                : INC0110283 Auto Population and modification of Exchange Rate
    --                           ENHC0010763
    -- Program                 : Daily Rates Import and Calculation - Deckers
    --
    -- Description             :
    -- Latest Version          : 1.0
    --
    -- Revision History:
    -- =============================================================================
    -- Date               Version#    Name            Remarks
    -- =============================================================================
    -- 25-APR-2012       1.0         Vijaya Reddy         Initial development.
    --
    -------------------------------------------------------------------------------
    ---------------------------
    -- Declare Input Parameters
    ---------------------------

    --------------------
    -- GLOBAL VARIABLES
    --------------------


    PROCEDURE GET_GL_DAILY_RATES (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_src_conv_type VARCHAR2, pd_src_date DATE, pv_src_from_cur VARCHAR2, pv_src_to_cur VARCHAR2, pv_trg_conv_type VARCHAR2, pd_trg_from_date DATE, pd_trg_to_date DATE
                                  , pv_dec_precision NUMBER)
    IS
        CURSOR c_crate_inv_cur (cp_src_cnv_type VARCHAR2, cp_src_date DATE, cp_src_from_cur VARCHAR2
                                , cp_src_to_cur VARCHAR2)
        IS
            SELECT gldv.conversion_rate, gldv.inverse_conversion_rate, gldv.conversion_type,
                   gldv.from_currency, gldv.to_currency, gldv.conversion_date
              FROM apps.gl_daily_rates_v gldv
             WHERE     conversion_type = cp_src_cnv_type
                   AND conversion_date = cp_src_date
                   AND from_currency = NVL (cp_src_from_cur, from_currency)
                   AND to_currency = NVL (cp_src_to_cur, to_currency);

        ----------------------------------------------------------------------------------------
        --cursor to fetch   data from temp table to avoid duplicate rows
        ----------------------------------------------------------------------------------------

        CURSOR c_crate_temp_cur (cp_src_cnv_type VARCHAR2, cp_src_date DATE, cp_src_from_cur VARCHAR2
                                 , cp_src_to_cur VARCHAR2)
        IS
            SELECT gldt.conversion_rate, gldt.inverse_conversion_rate, gldt.conversion_type,
                   gldt.from_currency, gldt.to_currency, gldt.conversion_date
              FROM xxdogl_daily_rates_temp gldt
             WHERE     conversion_type = cp_src_cnv_type
                   AND conversion_date = cp_src_date
                   AND from_currency = NVL (cp_src_from_cur, from_currency)
                   AND to_currency = NVL (cp_src_to_cur, to_currency);

        ln_conv_rate         NUMBER;
        ln_inv_conv_rate     NUMBER;
        ld_first_date        DATE;
        ld_last_date         DATE;
        lv_trg_conv_type     VARCHAR2 (100);
        lv_mode_flag         VARCHAR2 (10) := 'I';
        ln_dec_pre_cnt       NUMBER;
        ln_upd_dec_pre_cnt   NUMBER;
        ln_tot_dec_pre_cnt   NUMBER;
        ln_intf_cnt          NUMBER;

        lv_request_id        NUMBER;
        ln_exists            NUMBER;
        ln_updated           NUMBER;

        lv_error_message     VARCHAR2 (2000);
    BEGIN
        ln_dec_pre_cnt       := 0;
        ln_upd_dec_pre_cnt   := 0;
        ln_tot_dec_pre_cnt   := 0;

        APPS.FND_FILE.PUT_LINE (
            APPS.FND_FILE.OUTPUT,
            'GL_DAILY_RATES_INTERFACE Before Update Conversion Rate and Inverse Conversion Rate ');

        APPS.FND_FILE.PUT_LINE (
            APPS.FND_FILE.OUTPUT,
            '                                                                                   ');

        APPS.FND_FILE.PUT_LINE (
            APPS.FND_FILE.OUTPUT,
               RPAD ('From Currency', 17, ' ')
            || RPAD ('To Currency', 30, ' ')
            || RPAD ('Source Covnersion Date', 20, ' ')
            || RPAD ('User Conversion Type', 20, ' ')
            || RPAD ('Conversion Rate', 20, ' ')
            || RPAD ('Inverse Conversion Rate', 25, ' '));
        APPS.FND_FILE.PUT_LINE (
            APPS.FND_FILE.OUTPUT,
               RPAD ('***************', 17, ' ')
            || RPAD ('*************', 30, ' ')
            || RPAD ('*****************', 20, ' ')
            || RPAD ('******************', 20, ' ')
            || RPAD ('******************', 20, ' ')
            || RPAD ('*************', 25, ' '));
        APPS.FND_FILE.PUT_LINE (
            APPS.FND_FILE.OUTPUT,
            '                                                                                                                                                                                                                                                                                 ');

        BEGIN
            DELETE FROM xxdogl_daily_rates_temp;

            COMMIT;
        END;

        FOR j IN c_crate_inv_cur (cp_src_cnv_type => pv_src_conv_type, cp_src_date => pd_src_date, cp_src_from_cur => pv_src_from_cur
                                  , cp_src_to_cur => pv_src_to_cur)
        LOOP
            BEGIN
                BEGIN
                    SELECT 1
                      INTO ln_exists
                      FROM xxdogl_daily_rates_temp
                     WHERE     from_currency = j.to_currency
                           AND to_currency = j.from_currency
                           AND conversion_date = j.conversion_date;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        INSERT INTO xxdogl_daily_rates_temp (
                                        FROM_CURRENCY,
                                        TO_CURRENCY,
                                        CONVERSION_DATE,
                                        CONVERSION_TYPE,
                                        CONVERSION_RATE,
                                        INVERSE_CONVERSION_RATE)
                                 VALUES (j.from_currency,
                                         j.to_currency,
                                         j.conversion_date,
                                         j.conversion_type,
                                         j.conversion_rate,
                                         j.inverse_conversion_rate);

                        COMMIT;
                END;
            END;
        END LOOP;

        FOR i IN c_crate_temp_cur (cp_src_cnv_type => pv_src_conv_type, cp_src_date => pd_src_date, cp_src_from_cur => pv_src_from_cur
                                   , cp_src_to_cur => pv_src_to_cur)
        LOOP
            APPS.FND_FILE.PUT_LINE (
                APPS.FND_FILE.OUTPUT,
                   RPAD (i.from_currency, 17, ' ')
                || RPAD (i.to_currency, 30, ' ')
                || RPAD (i.conversion_date, 20, ' ')
                || RPAD (i.conversion_type, 20, ' ')
                || RPAD (TO_CHAR (i.conversion_rate, '9999999.999999'),
                         20,
                         ' ')
                || RPAD (i.inverse_conversion_rate, 25, ' '));

            -----------------------------------------------------------------------------------------------
            -- Updating the conversion rate and inverse conversion rate to the input decimal presision
            -----------------------------------------------------------------------------------------------
            GV_ERROR_POSITION   :=
                'GET_GL_DAILY_RATES - Updating Conversion rate and Inverse Conversion rate Based on Input Parameter';

            BEGIN
                ln_conv_rate       := NULL;
                ln_inv_conv_rate   := NULL;
                ln_updated         := NULL;

                IF     SUBSTR (i.conversion_rate,
                               INSTR (i.conversion_rate, '.', 1) + 1,
                               pv_dec_precision) !=
                       RPAD ('0', pv_dec_precision, '0')
                   AND SUBSTR (i.inverse_conversion_rate,
                               INSTR (i.inverse_conversion_rate, '.', 1) + 1,
                               pv_dec_precision) !=
                       RPAD ('0', pv_dec_precision, '0')
                THEN
                    IF    (LENGTH (SUBSTR (i.conversion_rate, INSTR (i.conversion_rate, '.', 1) + 1)) != pv_dec_precision)
                       OR (LENGTH (SUBSTR (i.inverse_conversion_rate, INSTR (i.inverse_conversion_rate, '.', 1) + 1)) != pv_dec_precision)
                    THEN
                        SELECT SUBSTR (i.conversion_rate, 1, INSTR (i.conversion_rate, '.', 1) + pv_dec_precision), SUBSTR (i.inverse_conversion_rate, 1, INSTR (i.inverse_conversion_rate, '.', 1) + pv_dec_precision)
                          INTO ln_conv_rate, ln_inv_conv_rate
                          FROM DUAL;

                        ln_updated           := 1;

                        ln_upd_dec_pre_cnt   := ln_upd_dec_pre_cnt + 1;
                    ELSE
                        ln_dec_pre_cnt     := ln_dec_pre_cnt + 1;
                        ln_conv_rate       := i.conversion_rate;
                        ln_inv_conv_rate   := i.inverse_conversion_rate;
                    END IF;
                ELSE
                    ln_dec_pre_cnt     := ln_dec_pre_cnt + 1;
                    ln_conv_rate       := i.conversion_rate;
                    ln_inv_conv_rate   := i.inverse_conversion_rate;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_message   := SQLERRM;
                    apps.FND_FILE.PUT_LINE (
                        apps.FND_FILE.LOG,
                        'Following Error Occured At ' || GV_ERROR_POSITION);
                    RAISE_APPLICATION_ERROR (-20501, lv_error_message);
                    RAISE;
            END;

            -----------------------------------------------------------------------------------
            -- Fetching first date and last date if target from and to dates are not provided
            -----------------------------------------------------------------------------------
            GV_ERROR_POSITION   :=
                'GET_GL_DAILY_RATES - Fetching Target first date and last date';

            BEGIN
                IF    (pd_trg_from_date IS NULL AND pd_trg_to_date IS NULL)
                   OR (pd_trg_from_date IS NULL)
                   OR (pd_trg_to_date IS NULL)
                THEN
                    SELECT ADD_MONTHS (LAST_DAY (ADD_MONTHS (pd_src_date, 1)), -1) + 1 firstdate, LAST_DAY (ADD_MONTHS (pd_src_date, 1)) lastdate
                      INTO ld_first_date, ld_last_date
                      FROM DUAL;
                ELSE
                    ld_first_date   := pd_trg_from_date;
                    ld_last_date    := pd_trg_to_date;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_message   := SQLERRM;
                    apps.FND_FILE.PUT_LINE (
                        apps.FND_FILE.LOG,
                        'Following Error Occured At ' || GV_ERROR_POSITION);
                    RAISE_APPLICATION_ERROR (-20501, lv_error_message);
                    RAISE;
            END;

            -----------------------------------------------------------------
            -- Fetching Target Conversion Type
            -----------------------------------------------------------------
            GV_ERROR_POSITION   :=
                'GET_GL_DAILY_RATES - Fetching Target Conversion Type';

            BEGIN
                SELECT user_conversion_type
                  INTO lv_trg_conv_type
                  FROM apps.gl_daily_conversion_types
                 WHERE UPPER (conversion_type) = UPPER (pv_trg_conv_type);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_message   := SQLERRM;
                    apps.FND_FILE.PUT_LINE (
                        apps.FND_FILE.LOG,
                        'Following Error Occured At ' || GV_ERROR_POSITION);
                    RAISE_APPLICATION_ERROR (-20501, lv_error_message);
                    RAISE;
            END;


            APPS.FND_FILE.PUT_LINE (
                APPS.FND_FILE.OUTPUT,
                '                                                                                   ');

            APPS.FND_FILE.PUT_LINE (
                APPS.FND_FILE.OUTPUT,
                'GL_DAILY_RATES_INTERFACE After Update Conversion Rate and Inverse Conversion Rate ');

            APPS.FND_FILE.PUT_LINE (
                APPS.FND_FILE.OUTPUT,
                '                                                                                   ');

            APPS.FND_FILE.PUT_LINE (
                APPS.FND_FILE.OUTPUT,
                   RPAD ('From Currency', 17, ' ')
                || RPAD ('To Currency', 30, ' ')
                || RPAD ('From Covnersion Date', 20, ' ')
                || RPAD ('To Conversion Date', 20, ' ')
                || RPAD ('User Conversion Type', 20, ' ')
                || RPAD ('Conversion Rate', 20, ' ')
                || RPAD ('Inverse Conversion Rate', 25, ' ')
                || RPAD ('Mode Flag', 20, ' '));
            APPS.FND_FILE.PUT_LINE (
                APPS.FND_FILE.OUTPUT,
                   RPAD ('***************', 17, ' ')
                || RPAD ('*************', 30, ' ')
                || RPAD ('*****************', 20, ' ')
                || RPAD ('*****', 20, ' ')
                || RPAD ('******************', 20, ' ')
                || RPAD ('******************', 20, ' ')
                || RPAD ('*************', 25, ' ')
                || RPAD ('*************', 20, ' '));

            -----------------------------------------------------------------
            -- Inserting into GL_DAILY_RATES_INTERFACE table
            -----------------------------------------------------------------
            GV_ERROR_POSITION   :=
                'GET_GL_DAILY_RATES - Inserting into GL_DAILY_RATES_INTERFACE table';

            BEGIN
                APPS.FND_FILE.PUT_LINE (
                    APPS.FND_FILE.OUTPUT,
                    '                                                                                                                                                                                                                                                                                 ');
                APPS.FND_FILE.PUT_LINE (
                    APPS.FND_FILE.OUTPUT,
                       RPAD (i.from_currency, 17, ' ')
                    || RPAD (i.to_currency, 30, ' ')
                    || RPAD (ld_first_date, 20, ' ')
                    || RPAD (ld_last_date, 20, ' ')
                    || RPAD (lv_trg_conv_type, 20, ' ')
                    || RPAD (ln_conv_rate, 20, ' ')
                    || RPAD (ln_inv_conv_rate, 25, ' ')
                    || RPAD (lv_mode_flag, 20, ' '));

                INSERT INTO GL.GL_DAILY_RATES_INTERFACE (
                                FROM_CURRENCY,
                                TO_CURRENCY,
                                FROM_CONVERSION_DATE,
                                TO_CONVERSION_DATE,
                                USER_CONVERSION_TYPE,
                                CONVERSION_RATE,
                                INVERSE_CONVERSION_RATE,
                                MODE_FLAG,
                                USER_ID)
                         VALUES (i.from_currency,
                                 i.to_currency,
                                 ld_first_date,
                                 ld_last_date,
                                 lv_trg_conv_type,
                                 ln_conv_rate,
                                 ln_inv_conv_rate,
                                 lv_mode_flag,
                                 APPS.FND_GLOBAL.USER_ID);

                IF ln_updated = 1
                THEN
                    INSERT INTO APPS.GL_DAILY_RATES_INTERFACE (
                                    FROM_CURRENCY,
                                    TO_CURRENCY,
                                    FROM_CONVERSION_DATE,
                                    TO_CONVERSION_DATE,
                                    USER_CONVERSION_TYPE,
                                    CONVERSION_RATE,
                                    INVERSE_CONVERSION_RATE,
                                    MODE_FLAG,
                                    USER_ID)
                             VALUES (i.from_currency,
                                     i.to_currency,
                                     i.conversion_date,
                                     i.conversion_date,
                                     i.conversion_type,
                                     ln_conv_rate,
                                     ln_inv_conv_rate,
                                     lv_mode_flag,
                                     APPS.FND_GLOBAL.USER_ID);
                END IF;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_message   := SQLERRM;
                    apps.FND_FILE.PUT_LINE (
                        apps.FND_FILE.LOG,
                        'Following Error Occured At ' || GV_ERROR_POSITION);
                    RAISE_APPLICATION_ERROR (-20501, lv_error_message);
                    RAISE;
            END;
        END LOOP;

        ln_tot_dec_pre_cnt   := ln_upd_dec_pre_cnt + ln_dec_pre_cnt;
        apps.FND_FILE.PUT_LINE (
            apps.FND_FILE.OUTPUT,
               'Total number of records updated with decimal precision '
            || pv_dec_precision
            || ' for Conversion type '
            || pv_src_conv_type
            || ' - '
            || ln_upd_dec_pre_cnt);
        apps.FND_FILE.PUT_LINE (
            apps.FND_FILE.LOG,
               'Total number of records that were not updated with decimal precision '
            || pv_dec_precision
            || ' for Conversion type '
            || pv_src_conv_type
            || ' - '
            || ln_dec_pre_cnt);
        apps.FND_FILE.PUT_LINE (
            apps.FND_FILE.LOG,
            'Total number of records ' || ' - ' || ln_tot_dec_pre_cnt);

        BEGIN
            SELECT COUNT (*)
              INTO ln_intf_cnt
              FROM APPS.GL_DAILY_RATES_INTERFACE
             WHERE     USER_CONVERSION_TYPE IN
                           (lv_trg_conv_type, pv_src_conv_type)
                   AND mode_flag = lv_mode_flag
                   AND ((from_conversion_date >= ld_first_date AND to_conversion_date <= ld_last_date) OR (from_conversion_date = pd_src_date AND to_conversion_date = pd_src_date));
        END;

        -- apps.FND_FILE.PUT_LINE(apps.FND_FILE.OUTPUT,'Total number of records inserted into the GL Daily Rates Interface table '||' - '||ln_intf_cnt);

        BEGIN
            -- APPS.FND_FILE.PUT_LINE(FND_FILE.LOG,'Submit standard interface program: '||'Program - Daily Rates Import and Calculation');

            APPS.FND_GLOBAL.APPS_INITIALIZE (APPS.FND_GLOBAL.USER_ID,
                                             APPS.FND_GLOBAL.RESP_ID,
                                             APPS.FND_GLOBAL.RESP_APPL_ID);

            lv_request_id   :=
                FND_REQUEST.SUBMIT_REQUEST (
                    application   => 'SQLGL',
                    program       => 'GLDRICCP',
                    description   =>
                        'Program - Daily Rates Import and Calculation',
                    start_time    => SYSDATE,
                    sub_request   => FALSE);


            COMMIT;
        --APPS.FND_FILE.PUT_LINE(FND_FILE.LOG, 'Submitted Request :'||lv_request_id );


        END;
    --  apps.FND_FILE.PUT_LINE(apps.FND_FILE.OUTPUT,'Total number of records updated for Conversion type '||pv_trg_conv_type||' - ');

    END GET_GL_DAILY_RATES;
END XXDOGL_DAILY_RATES_PKG;
/
