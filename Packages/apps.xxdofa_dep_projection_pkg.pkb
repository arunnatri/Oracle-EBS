--
-- XXDOFA_DEP_PROJECTION_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:40:48 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOFA_DEP_PROJECTION_PKG"
AS
    /******************************************************************************
       NAME:       XXDOFA_DEP_PROJECTION_PKG
       PURPOSE:

       REVISIONS:
       Ver              Date           Author                     Description
       ---------      ----------    -----------------     ------------------------------------
       1.0            6/03/2008           Shibu        1. Created this package for FA
                                                          Depreciation Projection Process
       1.1            28/08/2014    BT TechnologyTeam     Retrofit for BT project
       1.2           05/01/2015    BT TechnologyTeam      Added code for "CIP Depreciation
                                                          Projection Section" in the report
      1.3          26/11/2015    BT TechnologyTeam        Added code for "CIP Depreciation
                                                          Projection Section" in the report
                                                          to calculate Depreciation amount.
    ****************************************************************************************/
    FUNCTION fa_projection_process (p_cal         IN VARCHAR2,
                                    p_periods     IN VARCHAR2,
                                    p_per_start   IN VARCHAR2,
                                    p_book        IN VARCHAR2,
                                    p_currency    IN VARCHAR2--Added by BT Technology Team on 28-Aug-2014  - v1.1
                                                             )
        RETURN BOOLEAN
    IS
        dummy_default   BOOLEAN DEFAULT FALSE;
        v_wait          BOOLEAN;
        v_req_phase     VARCHAR2 (100);
        v_req_status    VARCHAR2 (100);
        v_dev_phase     VARCHAR2 (100);
        v_dev_status    VARCHAR2 (100);
        v_req_message   VARCHAR2 (1000);
    BEGIN
        g_proj_req_id   :=
            apps.fnd_request.submit_request ('OFA', 'FAPROJ', 'FA Projections', '', dummy_default, p_cal, p_per_start, TO_CHAR (p_periods), p_currency, --Added by BT Technology Team on 28-Aug-2014 - v1.1
                                                                                                                                                        p_book, CHR (0), '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', ''
                                             , '', '', '');
        -- Starts changes by BT Technology Team on 28-Aug-2014 - v1.1

        --g_table  := 'FA_PROJ_INTERIM_'||TO_CHAR(g_proj_req_id);
        g_table         := 'FA_PROJ_INTERIM_RPT';
        g_dummy_table   := 'FA_PROJ_INTERIM_' || TO_CHAR (g_proj_req_id);
        --End changes by BT Technology Team on 28-Aug-2014  - v1.1
        fnd_file.put_line (fnd_file.LOG, g_table);
        COMMIT;
        RETURN (TRUE);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN TRUE;
            fnd_file.put_line (fnd_file.LOG,
                               'Error with the before report I');
    END fa_projection_process;

    --------------------------------------------------------------------------------------
    -- Start of Changes by BT Technology Team on 05-Jan-2015 - V1.2
    --------------------------------------------------------------------------------------
    FUNCTION fa_period_range (p_period_name VARCHAR2, p_num_period NUMBER)
        RETURN VARCHAR2
    IS
        l_init_period_name   VARCHAR2 (10);
        l_num_periods        NUMBER;
        l_init_period_num    NUMBER;
        l_init_period_year   NUMBER;
        l_period_year        NUMBER;
        l_period_num         NUMBER;
        l_period_string      VARCHAR2 (4000);
        l_temp               VARCHAR2 (10);
    BEGIN
        l_init_period_name   := p_period_name;
        l_num_periods        := p_num_period;

        -- Get the period year and Period Number of the Start Period
        SELECT period_year, period_num
          INTO l_init_period_year, l_init_period_num
          FROM gl_periods
         WHERE     period_set_name = 'DO_FY_CALENDAR'
               AND period_name = l_init_period_name;

        l_period_string      :=
            'AND PERIOD_NAME IN (''' || l_init_period_name || '';

        FOR i IN 1 .. l_num_periods - 1
        LOOP
            IF (l_init_period_num + i) > 12
            THEN
                --------------------------------------------------------------------------------------
                -- Start of Changes by BT Technology Team on 26-Nov-2015 - V1.3
                --------------------------------------------------------------------------------------
                SELECT DECODE (MOD (l_init_period_num + i, 12), 0, 12, MOD (l_init_period_num + i, 12))
                  INTO l_period_num
                  FROM DUAL;

                l_period_year   :=
                    l_init_period_year + TRUNC ((l_init_period_num + i) / 12);

                IF l_period_num = 12
                THEN
                    l_init_period_num   := l_init_period_num - 1;
                    l_period_year       :=
                          l_init_period_year
                        + TRUNC ((l_init_period_num + i) / 12);
                    l_init_period_num   := l_init_period_num + 1;
                ELSE
                    l_period_year   :=
                          l_init_period_year
                        + TRUNC ((l_init_period_num + i) / 12);
                END IF;
            ELSE
                l_period_num    := (l_init_period_num + i);
                l_period_year   := l_init_period_year;
            END IF;

            --------------------------------------------------------------------------------------
            -- End of Changes by BT Technology Team on 26-Nov-2015 - V1.3
            --------------------------------------------------------------------------------------
            SELECT period_name
              INTO l_temp
              FROM gl_periods
             WHERE     period_set_name = 'DO_FY_CALENDAR'
                   AND period_num = l_period_num
                   AND period_year = l_period_year;

            l_period_string   := l_period_string || ''',''' || l_temp;
        END LOOP;

        l_period_string      := l_period_string || ''')';
        RETURN l_period_string;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'In Exception : While Extracting the Period Range');
            fnd_file.put_line (
                fnd_file.LOG,
                'Error Details : ' || SQLERRM || ' , ' || SQLCODE);
            RETURN 'AND 1 = 2';
    END fa_period_range;

    --------------------------------------------------------------------------------------
    -- End of Changes by  by BT Technology Team on 05-Jan-2015 - V1.2
    --------------------------------------------------------------------------------------
    --------------------------------------------------------------------------------------
    -- Start of Changes by BT Technology Team on 26-Nov-2015 - V1.3
    --------------------------------------------------------------------------------------
    FUNCTION cip_depreciation_amount (p_estimated_service_date DATE, p_life_month NUMBER, p_period_name VARCHAR2
                                      , p_estimated_cost NUMBER, p_book VARCHAR2, p_category_id NUMBER)
        RETURN NUMBER
    IS
        lv_period_name   VARCHAR (20);
        ln_period_name   VARCHAR (20);
        ln_dep_amt       NUMBER;
        p_period_num     NUMBER;
        ln_period_num    NUMBER;
        ld_new_date      DATE;
        ld_start_date    DATE;
    BEGIN
        SELECT period_name
          INTO ln_period_name
          FROM gl_periods
         WHERE     period_set_name = 'DO_FY_CALENDAR'
               AND p_estimated_service_date BETWEEN start_date AND end_date;

        SELECT start_date
          INTO ld_start_date
          FROM gl_periods
         WHERE     period_set_name = 'DO_FY_CALENDAR'
               AND period_name = ln_period_name;

        ld_new_date   := ADD_MONTHS (ld_start_date, p_life_month - 1);

        SELECT period_name, period_num
          INTO lv_period_name, ln_period_num
          FROM gl_periods
         WHERE     period_set_name = 'DO_FY_CALENDAR'
               AND ld_new_date BETWEEN start_date AND end_date;

        SELECT period_num
          INTO p_period_num
          FROM gl_periods
         WHERE     period_set_name = 'DO_FY_CALENDAR'
               AND period_name = p_period_name;

        IF     TO_CHAR (TO_DATE (p_period_name, 'mon-yy'), 'yy') =
               TO_CHAR (TO_DATE (lv_period_name, 'mon-yy'), 'yy')
           AND p_period_num > ln_period_num
        THEN
            ln_dep_amt   := 0;
        ELSE
            IF TO_DATE (p_period_name, 'MON-YY') <=
               TO_DATE (lv_period_name, 'MON-YY')
            THEN
                SELECT ROUND (p_estimated_cost / fcbd.life_in_months, 2)
                  INTO ln_dep_amt
                  FROM fa_category_book_defaults fcbd
                 WHERE     book_type_code = p_book
                       AND fcbd.category_id = p_category_id;
            ELSE
                ln_dep_amt   := 0;
            END IF;
        END IF;

        RETURN ln_dep_amt;
    EXCEPTION
        WHEN OTHERS
        THEN
            ln_dep_amt   := -9999999999;
            fnd_file.put_line (
                fnd_file.LOG,
                'In Exception : While finding CIP depreciation cost');
            fnd_file.put_line (
                fnd_file.LOG,
                'Error Details : ' || SQLERRM || ' , ' || SQLCODE);
            RETURN ln_dep_amt;
    END cip_depreciation_amount;

    --------------------------------------------------------------------------------------
    -- End of Changes by BT Technology Team on 26-Nov-2015 - V1.3
    --------------------------------------------------------------------------------------
    FUNCTION fa_beforereport
        RETURN BOOLEAN
    IS
        v_wait          BOOLEAN;
        v_req_phase     VARCHAR2 (100);
        v_req_status    VARCHAR2 (100);
        v_dev_phase     VARCHAR2 (100);
        v_dev_status    VARCHAR2 (100);
        v_req_message   VARCHAR2 (1000);
    BEGIN
        --p_req_id:=fnd_global.conc_request_id;
        v_wait           :=
            fnd_concurrent.wait_for_request (g_proj_req_id, 20, 0,
                                             v_req_phase, v_req_status, v_dev_phase
                                             , v_dev_status, v_req_message);
        -- Start of Changes by BT Technology Team on 05-Jan-2015 - V1.2
        v_where_period   := fa_period_range (p_per_start, p_periods);
        -- End of Changes by BT Technology Team on 05-Jan-2015 - V1.2
        RETURN (v_wait);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN (v_wait);
            fnd_file.put_line (fnd_file.LOG,
                               'Error with the before report II');
    END fa_beforereport;

    -- Starts changes by BT Technology Team on 28-Aug-2014 - v1.1
    --Function fa_afterreport(g_table Varchar2) Return boolean is
    FUNCTION fa_afterreport (g_dummy_table VARCHAR2)
        RETURN BOOLEAN
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        --FND_FILE.put_line(FND_FILE.LOG,'Drop table'||g_table);
        fnd_file.put_line (fnd_file.LOG, 'Drop table' || g_dummy_table);

        --EXECUTE IMMEDIATE 'Drop table '||g_table;
        EXECUTE IMMEDIATE 'Drop table ' || g_dummy_table;

        --End changes by BT Technology Team on 28-Aug-2014  - v1.1
        RETURN (TRUE);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN TRUE;
            fnd_file.put_line (fnd_file.LOG,
                               'Error with the DROP TABLE function');
    END fa_afterreport;
END xxdofa_dep_projection_pkg;
/
